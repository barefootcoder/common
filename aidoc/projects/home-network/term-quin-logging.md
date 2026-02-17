# SSH Connection Logging for term-quin

## Problem
The `term-quin` command (local to Avalir) launches a terminal window that connects to the current AWS sandbox via `cessh` (or Tailscale direct SSH). When the SSH connection drops unexpectedly, the entire terminal window disappears, making it impossible to see error messages or diagnose the cause of the disconnection.

**The real pain:** The remote host runs `screen` with 20+ windows. Each window holds a reference to the SSH agent socket (`$SSH_AUTH_SOCK`) from the original connection. When the connection drops and is re-established, the new SSH session gets a *new* agent socket path, but all existing screen windows still point at the old (now dead) socket. This means every window loses the ability to do SSH operations (git push, ssh to other hosts, etc.) until manually fixed with `ssh-sock-reset` — multiplied across 20+ windows.

## Root Cause Identified (2026-02-09)

SSH debug logging revealed the drops are caused by **SSM tunnel data corruption**, not timeouts:
```
Bad packet length 2782525878.
ssh_dispatch_run_fatal: Connection to UNKNOWN port 65535: Connection corrupted
```

The AWS SSM `session-manager-plugin` (used as SSH ProxyCommand) intermittently delivers corrupted data to the SSH stream. This is a [known issue](https://github.com/aws/amazon-ssm-agent/issues/274) with no fix — the plugin is already at the latest version (1.2.764.0, Nov 2025).

Key evidence:
- Session lifetimes varied wildly (2 hours to 3+ days) — consistent with intermittent corruption, not a fixed timeout
- `ServerAliveInterval` had no effect (not a timeout issue)
- The `AWS-StartSSHSession` document has no configurable timeout settings
- All drops showed exit code 255

## Solution: Tailscale Direct SSH

Since Tailscale VPN is already running on both Avalir and the EC2 sandbox (for Syncthing sync), `term-quin` now connects directly via the Tailscale IP, bypassing SSM entirely.

### How It Works

The wrapper auto-detects the sandbox's Tailscale IP:
1. Queries `tailscale status` for a `quin-*` host
2. If found, connects directly via `ssh -A -p 8822` to the Tailscale IP
3. If Tailscale is unavailable, falls back to `cessh` (SSM path)

### Implementation Details

**File Modified:** `/export/proj/common/local/avalir/bin/term-quin`

**Approach:** Create a temporary wrapper script on-the-fly that:
1. Auto-detects Tailscale IP for the quin sandbox
2. Connects via direct SSH (preferred) or cessh/SSM (fallback)
3. Logs which connection method was used
4. Captures SSH verbose debug output to the log file via `2>> $logfile`
5. Logs connection end with timestamp and exit code
6. Cleans itself up

**SSH options** are built in a shared `ssh_opts` array:
- `-v` is common to both paths (verbose debug logging)
- Tailscale path adds: `-A` (agent forwarding), `-p 8822`, keepalive options
- SSM fallback path passes options through to `cessh`

### Technical Notes

**SSH `-E` flag gotcha:**
SSH's `-E log_file` flag opens the file by *inode*, not by path. If you `mv` the log file while SSH is running, SSH keeps writing to the moved file (old inode). The next `echo >> /tmp/term-quin.log` creates a *new* file at the original path. Result: the log appears to have only the echo line. Use `2>> $logfile` instead — it's evaluated per-write by the shell and always targets the path.

**SSH debug flag pass-through (cessh path):**
The `-v` flag successfully passes through the command chain:
- `cessh` → `archer-ssh` → `ssh`
- Verified by checking that `archer-ssh`'s option processing doesn't intercept `-v`
- It correctly gets added to the `opts` array and passed to the final `ssh` call

**Tailscale connection details:**
- Connection goes through Tailscale relay ("iad"), not direct P2P
- Consider `tailscale update` (1.68.1 → 1.94.1) for potential direct P2P improvements
- Tailscale IPs are per-device; new sandboxes get new IPs, but auto-detect handles this

**Log File Location:**
- `/tmp/term-quin.log` - Contains connection method, SSH debug output, and exit codes
- Using `/tmp` instead of `~/tmp` because the latter may not exist
- Logs are also saved to `/var/tmp/term-quin-YYYYMMDD.log` for post-mortem analysis

## Tailscale Connection Drops (2026-02-14/15)

After switching to Tailscale direct SSH, connections are much more stable than SSM but still experience drops. Analysis of logs from Feb 14-15 revealed two distinct failure modes:

### Failure Mode 1: Keepalive Timeout
```
Timeout, server 100.119.161.9 not responding.
```
- Observed twice: after ~4.7 days (Feb 9 → Feb 14, 8:16 AM) and after ~4.5 hours (Feb 15, 4:49 AM → 9:17 AM)
- Both occurred in **early morning hours**, possibly correlating with Tailscale relay maintenance or rotation
- With `ServerAliveInterval=60, ServerAliveCountMax=3`, SSH kills the connection after just 3 minutes of unresponsiveness
- The connection routes through a Tailscale DERP relay ("iad"), not direct P2P — relay hiccups can cause transient unresponsiveness

### Failure Mode 2: Terminal Death (SIGHUP)
```
tcsetattr: Input/output error
Killed by signal 1.
```
- The local terminal emulator (kitty) was killed or crashed, sending SIGHUP to SSH
- Not an SSH or network issue — the host process disappeared
- Observed on Feb 14 ~7:54 PM (session lasted ~30 min) and in the earlier SSM era

### Key Observations
- Tailscale sessions last **much longer** than SSM (days vs hours), confirming the SSM corruption fix worked
- No "Bad packet length" or corruption errors on the Tailscale path
- Clean exits (exit 0) do occur, confirming the connection mechanism is fundamentally sound
- Session lifetimes still vary: 30 minutes to 4.7 days

## Usage

### Normal Use
Just run `term-quin` as usual. Logging happens automatically and silently.

### When Connection Drops

1. **Check the log file:**
   ```bash
   cat /tmp/term-quin.log
   ```
   Look for:
   - Which connection method was used (Tailscale vs SSM)
   - SSH debug output showing disconnect reason
   - Pattern of when disconnections occur (time of day, duration)
   - Exit codes (0 = clean exit, 255 = SSH error, others = various failures)

2. **Key diagnostic messages:**
   - `Bad packet length` / `Connection corrupted` — SSM data corruption (switch to Tailscale)
   - `Connection closed by ...` — remote side closed
   - `client_loop: send disconnect: Broken pipe` — network issue
   - `Connection reset by peer` — network/firewall issue
   - `Killed by signal 1` — SIGHUP (terminal window closed)

### Common Exit Codes
- `0` - Clean logout/exit
- `255` - Generic SSH error (connection refused, timeout, auth failure, etc.)
- `130` - Terminated by Ctrl+C (SIGINT)
- Other codes - Check SSH man page or specific error messages

### Forcing SSM (if needed)
To bypass Tailscale and force the SSM path (e.g., for testing), temporarily stop Tailscale:
```bash
sudo tailscale down
term-quin
# ... then bring it back up:
sudo tailscale up
```

Or set `CE_USE_GATEWAY=true` in the environment to force the SSH gateway instead of SSM.

## Planned Improvements

Solutions are prioritized by how well they address the core problem: 20+ screen windows with dead agent sockets after a reconnection.

### Priority 1: Agent Socket Symlink (eliminates the pain)

Even if drops can't be fully prevented, this makes reconnection seamless. Instead of fixing `$SSH_AUTH_SOCK` in 20+ screen windows after every drop, a stable symlink lets all windows automatically pick up the new agent socket.

**Concept:**
1. Create a stable symlink: `~/.ssh/agent-socket`
2. On each SSH login (before reattaching screen), update the symlink:
   ```bash
   if [[ $SSH_AUTH_SOCK && $SSH_AUTH_SOCK != ~/.ssh/agent-socket ]]; then
       ln -sf "$SSH_AUTH_SOCK" ~/.ssh/agent-socket
   fi
   export SSH_AUTH_SOCK=~/.ssh/agent-socket
   ```
3. All screen windows use the symlink path in `$SSH_AUTH_SOCK`
4. When reconnecting, updating the symlink fixes ALL windows at once

**Setup Steps (when ready to implement):**
1. Add the symlink logic to `~/.bash_profile` (or equivalent) on the remote EC2
2. Set `SSH_AUTH_SOCK=~/.ssh/agent-socket` in screen windows
3. After first setup, run `ssh-sock-reset` once per window to switch to the symlink
4. Future reconnections only need the symlink update (automatic via profile)

**Considerations:**
- One-time setup per screen window to switch to the symlink path
- After setup, all reconnections are seamless — no per-window intervention
- Works regardless of connection method (Tailscale, SSM, gateway)
- The remote shell is tcsh, so profile logic may need adaptation

### Priority 2: Reduce Drop Frequency (connectivity hardening)

These make drops less likely in the first place, complementing Priority 1:

**Upgrade Tailscale (1.68.1 → current):**
- Newer versions have significantly improved NAT traversal
- May enable direct P2P connection instead of DERP relay, eliminating relay as a failure point
- After upgrading, verify with `tailscale ping <quin-ip>` to check if path is direct
- Upgrade needed on both Avalir and the EC2 sandbox

**Increase keepalive tolerance:**
- Current: `ServerAliveInterval=60, ServerAliveCountMax=3` — kills after 3 minutes of unresponsiveness
- Proposed: `ServerAliveCountMax=10` — tolerates up to 10 minutes of relay hiccups
- Tradeoff: slower detection of genuinely dead connections, but brief DERP relay blips won't kill a 4-day session

### Priority 3: Auto-reconnect wrapper (convenience)

A reconnect loop in the `term-quin` wrapper script so the terminal doesn't vanish on disconnect. This is helpful but lower priority — without the agent socket symlink (Priority 1), reconnecting still leaves 20+ screen windows broken. Most useful *after* Priority 1 is in place, making the full recovery automatic: reconnect SSH → symlink updates → all screen windows work.

## Files Involved

- `/export/proj/common/local/avalir/bin/term-quin` - Launch script with Tailscale auto-detect
- `/tmp/term-quin.log` - Connection lifecycle and SSH debug log
- Temporary wrapper script (auto-created/cleaned up)

## Related Documentation

See also:
- `~/workproj/archer-boot/lib/bash/ssh` - SSH library implementation (defines `archer-ssh`, `CE_USE_GATEWAY`)
- `~/workproj/CE/devtools/cessh` - CE-specific SSH wrapper
- `~/workproj/archer-boot/devtools/archer-ssh` - Archer SSH implementation
- [SSM agent issue #274](https://github.com/aws/amazon-ssm-agent/issues/274) - Known SSM SSH corruption issue

---
*Documented: 2026-01-13*
*Updated: 2026-02-09 — Root cause diagnosis (SSM corruption), Tailscale direct SSH solution, agent socket symlink notes*
*Updated: 2026-02-16 — Tailscale drop analysis (Feb 14-15 logs), prioritized solutions around agent socket problem*
*Contributors: buddy, Claude Code (Sonnet 4.5)*

# SSH Connection Logging for term-quin

## Problem
The `term-quin` command (local to Avalir) launches a terminal window that connects to the current AWS sandbox via `cessh`. When the SSH connection drops unexpectedly, the entire terminal window disappears, making it impossible to see error messages or diagnose the cause of the disconnection.

## Solution Implemented
Added simple logging to `term-quin` to capture connection lifecycle events and enable post-mortem diagnosis.

### Implementation Details

**File Modified:** `/export/proj/common/local/avalir/bin/term-quin`

**Approach:** Create a temporary wrapper script on-the-fly that:
1. Logs connection start with timestamp and target sandbox
2. Runs `cessh -v` (with SSH verbose debugging enabled)
3. Captures the exit code when connection terminates
4. Logs connection end with timestamp and exit code
5. Waits for keypress before closing window (so debug output is visible)
6. Cleans itself up after keypress

**Why this approach:**
- Avoids quoting nightmares with nested bash commands
- No permanent wrapper file to maintain
- Automatic cleanup via `rm -f $0`
- SSH debug output (`-v`) remains on stdout/stderr for real-time viewing
- Only logging metadata (timestamps, exit codes) goes to the log file

### Technical Notes

**SSH Debug Flag Pass-through:**
The `-v` flag successfully passes through the command chain:
- `cessh` → `archer-ssh` → `ssh`
- Verified by checking that `archer-ssh`'s option processing doesn't intercept `-v`
- It correctly gets added to the `opts` array and passed to the final `ssh` call

**Log File Location:**
- `/tmp/term-quin.log` - Contains timestamps and exit codes
- Using `/tmp` instead of `~/tmp` because the latter may not exist

## Usage

### Normal Use
Just run `term-quin` as usual. Logging happens automatically and silently.

### When Connection Drops

1. **Check the log file:**
   ```bash
   cat /tmp/term-quin.log
   ```
   Look for:
   - Pattern of when disconnections occur (time of day, duration)
   - Exit codes (0 = clean exit, 255 = SSH error, others = various failures)

2. **SSH debug output:**
   - If the window stays open (via keypress wait), read the debug output before closing
   - Look for lines like:
     - `debug1: Connection closed by ...` (remote side closed)
     - `debug1: client_loop: send disconnect: Broken pipe` (network issue)
     - `Connection reset by peer` (network/firewall issue)
     - `Timeout` or `keepalive` messages (idle timeout)

### Common Exit Codes
- `0` - Clean logout/exit
- `255` - Generic SSH error (connection refused, timeout, auth failure, etc.)
- `130` - Terminated by Ctrl+C (SIGINT)
- Other codes - Check SSH man page or specific error messages

## Files Involved

- `/export/proj/common/local/avalir/bin/term-quin` - Modified launch script
- `/tmp/term-quin.log` - Connection lifecycle log
- Temporary wrapper script (auto-created/cleaned up)

## Future Enhancements

If needed, could add:
- Rotation of log files (currently appends indefinitely)
- Capture full SSH debug output to file (careful: might affect TTY/PTY allocation)
- Network quality metrics (packet loss, latency)
- Automatic pattern analysis of disconnection events

## Related Documentation

See also:
- `~/workproj/archer-boot/lib/bash/ssh` - SSH library implementation
- `~/workproj/CE/devtools/cessh` - CE-specific SSH wrapper
- `~/workproj/archer-boot/devtools/archer-ssh` - Archer SSH implementation

---
*Documented: 2026-01-13*
*Contributors: buddy, Claude Code (Sonnet 4.5)*

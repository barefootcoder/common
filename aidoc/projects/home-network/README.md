# Home Network Project

This project contains documentation and management information for the home network infrastructure.

## Project Overview

This is a mixed-platform home network with Linux systems, NAS storage, and smart home devices. The network is currently undergoing upgrades, particularly the replacement of a Synology NAS with a more powerful QNAP system.

## CRITICAL: System Environment Notes

### Shell Environment
- **Interactive shell on Linux systems**: `tcsh` (NOT bash)
- **Remote command execution**: Commands via SSH execute in tcsh by default
- **Use `bash -c` for complex remote commands**: 
  ```bash
  # CORRECT: ssh haven 'bash -c "ls -l 2>/dev/null | grep foo"'
  # WRONG:   ssh haven "ls -l 2>/dev/null | grep foo"  # tcsh syntax error
  ```

### Linux Mint Filesystem Structure  
- **UsrMerge implementation**: On Haven and Avalir (Linux Mint 21.1), these are symlinks:
  - `/bin` → `/usr/bin`
  - `/sbin` → `/usr/sbin`
  - `/lib*` → `/usr/lib*`
- **Important**: `/bin/foo` and `/usr/bin/foo` are the SAME file - don't compare them
- **Package queries**: Use `/usr/bin/*` paths (e.g., `dpkg -S /usr/bin/python3`)

## Key Documentation

### Core Network Documentation
- **[home-network-description.md](home-network-description.md)**: Complete technical description of the network infrastructure
  - Hardware components (Eero mesh WiFi, switches, modem)
  - Machine inventory (Haven, Avalir, Zadash, Caemlyn Linux systems)
  - Current and planned NAS systems (Synology Taaveren → QNAP Nakama)
  - Network services (Tailscale VPN, Syncthing file sync)
  - Security configuration and user management

### Project Planning
- **[qnap-upgrade-decisions.md](qnap-upgrade-decisions.md)**: Decision rationale and implementation plan for upgrading from Synology DS220j to QNAP TS-264-8G-US
  - Performance requirements and migration considerations
  - Service setup priorities (Syncthing, Backblaze B2 backup)
  - Security and future expansion planning

### Desktop Workflow
- **[desktop-switching-shortcuts.md](desktop-switching-shortcuts.md)**: Interlocking `Ctrl+Alt+Up` / `Ctrl+Alt+Down` MATE shortcuts that switch between paired desktops (Haven↔Avalir, Zadash↔Caemlyn) via NoMachine. Documents the `show-desktop` script, the `WORK`/`HOME` symbolic targets, and the full behavior matrix.

### Sync Maintenance
- **[syncthing-troubleshooting.md](syncthing-troubleshooting.md)**: Symptom→fix guide for the Syncthing cluster (out-of-sync states, inotify-drop case studies, connectivity, `synudge` helper).
- **[quin-syncthing-downgrade.md](quin-syncthing-downgrade.md)**: Standalone agent-runnable brief for rolling quin back from Syncthing v2.1.0 to v1.30.0 and disabling auto-upgrade. Hand this to a quin-side session when it's time to realign the cluster.

## Private Data (Local Only)

The `private/` directory contains sensitive information that is excluded from version control:

- **[private/network-details.md](private/network-details.md)**: Actual IP addresses, Tailscale VPN IPs, specific firewall port configurations, hardware model numbers, and ISP details
- **[private/credentials.md](private/credentials.md)**: System usernames, UIDs/GIDs, administrator account names, and group memberships

## Historical Context (AI Session Summaries)

The following files contain summaries from previous AI collaboration sessions. These provide context for ongoing issues but should only be referenced when specifically relevant:

- `summary:haven-may13-vivmon-fix-and-nomachine-profile.md` - **[START HERE for Haven crash issues — most recent]** May 13 2026: another silent power-off, this time during a workspace switch onto a fullscreen video with NoMachine active. Three takeaways. (a) `viv-mon`'s `pkg=` and `gpu=` columns have been silently zero for the entire May 11→13 window — RAPL energy counters are root-only by default (PLATYPUS / CVE‑2020‑8694) and `rd()` swallowed the failure. Fixed: termstart now `chmod a+r`s them at boot; `viv-mon` rewritten to pick RAPL subdomains by name, add `gfreq=cur/act` and `rc6=Δms` columns from `/sys/class/drm/card1/`, add `tp=on/off` touchpad-state column and a periodic `BROWSERS` snapshot line listing distinct browser profiles, and rename the misleading `gpu=` field to `unc=`. (b) Captured the user's full NoMachine usage profile (servers, fullscreen-only, sound-on-Avalir, both clipboard modes; the per-host switching hotkeys are MATE+`show-desktop`, NOT a NoMachine feature) and assessed `xpra shadow` as a possible replacement — covers the functional surface, but the assessment ends with a **defer recommendation**: the crash data doesn't actually point at NoMachine, crashes happen without it, real root cause is hardware, switching cost is non-trivial. Revisit only if the next crash's new viv-mon data shows GPU climbing + RC6 collapsing in the final seconds. (c) Mystery: intermittent ~1-sec truncated audio clip the user has been chasing for weeks; logged for future correlation.
- `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md` - May 11 2026: another silent power-off after 3-day uptime (longest since May 8); the May 8 limp-along config is working but had to be made *persistent and idempotent* via `termstart`; forensic monitor relocated from lost `/tmp/viv-mon2.sh` to `~/local/bin/viv-mon` with log rotation; `bin/vivaldi-guard` now injects `--disable-gpu` on Haven; touchpad applet got `off`/`on` startup modes; new variable to watch is the NoMachine 8→9 upgrade on May 9
- `summary:vivaldi-7.9-upgrade-and-haven-instability.md` - May 2026: Vivaldi 6.1→7.9 upgrade + Haven crashes now triggered by routine load (not just GPU bursts); MV2 extension recovery; CSS-modding migrated to chrome://flags + Custom UI Modifications folder
- `summary:haven-kernel-upgrade-and-gpu-fix.md` - Kernel upgrade that resolved the i915 driver bugs causing Haven crashes (February 2026)
- `summary:haven-fstab-uuid-and-vivaldi-guard.md` - April 2026 follow-up: NVMe enumeration flip broke `/export` mount (fixed with UUID in fstab); Vivaldi + NoMachine combo still crashes Haven post-kernel-fix (guarded by `~/common/bin/vivaldi-guard` wrapper)
- `summary:ec2-syncthing.html` - Syncthing configuration for EC2 servers
- `summary:haven-crash-diagnosis-summary.md` - *(Superseded)* Earlier diagnosis of Haven system crashes
- `summary:haven-thermal-diagnosis-and-resolution.md` - *(Partially superseded)* Haven thermal issue resolution
- `summary:intermittent-shutdowns-diagnosis.md` - *(Historical)* Analysis of system shutdown problems
- `summary:intermittent-shutdowns.html` - *(Historical)* HTML version of shutdown diagnostics

## EC2 Sandbox ("Quin") Connection Details

**⚠️ IMPORTANT FOR AI AGENTS**: Read this section whenever the user mentions their "quin", "quin terminal", or EC2 sandbox — including connectivity issues, terminal lockups, or debugging remote sessions.

### How the User Connects to the Quin

The quin is an **EC2 instance** (not a local Vagrant VM — do not confuse with the local Vagrant sandbox on 127.0.0.1:2222). Connection details:

- **Script**: `local/avalir/bin/term-quin` launches the terminal window
- **Method**: SSH over **Tailscale VPN on port 8822** (not port 22)
- **Username**: `$CE_REMOTE_USERNAME` (currently `bburden`) — NOT `vagrant`, NOT `buddy`
- **Tailscale hostname**: Check `tailscale status` output for `quin-*` entry
- **Connection log**: `/tmp/term-quin.log` (verbose SSH debug output, check tail for recent events)
- **Session multiplexing**: GNU Screen runs inside the SSH session with many windows (tcsh shells)
- **Keepalive**: `ServerAliveInterval=60`, `ServerAliveCountMax=3`

To SSH to the quin from Avalir:
```bash
ssh -p 8822 bburden@<tailscale-hostname-or-ip>
```

### Known Connectivity Issues

- The Tailscale connection may go through a **DERP relay** (check `tailscale status` for "relay" in the output). Relay connections can cause intermittent freezes/lockups.
- Previous incidents show `tcsetattr: Input/output error` in the connection log when the connection path degrades.
- **Recurring "wedge" failure mode**: the SSH session can lock up entirely (no Ctrl-C, no Ctrl-A, no keystroke gets through) while TCP keepalives continue to round-trip normally — `ServerAliveInterval`/`CountMax` won't catch it because the keepalives *are* succeeding. Diagnostic signature: `ss -tnpi` shows `lastsnd`/`lastrcv` cycling at the keepalive interval, ssh sleeping in `do_poll`, `/tmp/term-quin.log` (the `-v` output) silent for hours. Suspected cause: WireGuard/Tailscale state desync that black-holes data-channel traffic but lets SSH-level keepalive control messages through. Tightening keepalive timing **does not** fix this; the keepalives are working.

### Agent Forwarding Constraints (CRITICAL for any reconnect-based fix)

The user's quin workflow has hard constraints around SSH agent forwarding that rule out several "obvious" solutions. Any AI agent proposing transport-level fixes must respect these:

- **Agent forwarding is non-negotiable.** The user uses a forwarded ssh-agent on quin for (a) GitHub access via `git`/`gh` and (b) SSH'ing from quin to other work machines. Removing agent forwarding stops development cold.
- **Keys cannot live on quin.** Don't suggest "just put the keys on the EC2 instance and run a local agent there" as a general solution. Treat it as off-limits unless the user explicitly raises it.
- **20–30 screen windows hold cached `SSH_AUTH_SOCK` values.** Each tcsh shell inside the remote screen session captured the agent socket path at the moment the SSH session was first established. A naïve reconnect with `ssh -A` allocates a *new* socket path, instantly invalidating every cached value. Schemes like plain `autossh` are non-starters in that form.
- **Solutions must use a stable agent socket path.** The right pattern is `RemoteForward /home/bburden/.ssh/agent.sock $SSH_AUTH_SOCK` on the client + `StreamLocalBindUnlink yes` in sshd + `setenv SSH_AUTH_SOCK /home/bburden/.ssh/agent.sock` in `~/.tcshrc`. Reconnects re-bind the same path, existing shells continue to work.
- **`mosh` does not forward ssh-agent.** Plain mosh is therefore a non-starter. Mosh-based solutions need a separate, dedicated ssh side-channel (with the stable socket-path setup above) whose only job is agent forwarding.

### Companion Failure: Screen IPC Wedge ("`sr` hangs on reattach")

The user has a *separate* recurring quin issue that often shows up at the same time as the SSH wedge: after relaunching `term-quin`, the `sr` alias (`screen -x`) hangs. The user's standard fix is `screen-cleanup`, then `sr` works.

What's actually going on (verified, not speculation):

- A long-running screen master on quin (uptime measured in *months* — last seen at 226 days) is the parent SCREEN session. There is **only ever one** screen session; the user's 20–30 "windows" are all inside it.
- Cron has `10 * * * * $HOME/bin/launch-perl screen-bufsave -Aq` — an hourly buffer save that calls `screen-windowlist`, which calls `screen -X msgwait 0` and `screen -p N -Q title` for windows 0..50.
- When something wedges screen's IPC (the master ends up blocked in `unix_stream_data_wait` reading a partial request from a previous client), every subsequent `screen -X` / `screen -Q` hangs forever. The hourly cron then **stacks one new zombie per hour** indefinitely.
- New `screen -x` attaches block in `unix_wait_for_peer` — they're trying to connect to a master whose accept loop isn't running.
- `screen-cleanup` (`~/common/bin/screen-cleanup`) `kill TERM`s all the zombie `screen-windowlist` / `screen-bufsave` / `msgwait` / `screen ... -Q` processes; the master then drains its queue and starts accepting again.

Diagnostic shortcut: `ps -eo pid,stat,etime,cmd | grep -E 'screen -X msgwait|screen -p .*-Q'` — if you see a clean arithmetic progression of `etime` values one hour apart, you're looking at this.

The `screen-bufsave` script already has a `-C` flag that runs `screen-cleanup` when ≥20 stale screen procs exist. **The cron line does not pass it** — that's the easy fix. A second cron entry running `screen-cleanup` unconditionally on a tighter cadence is even more robust.

**Identified trigger (Apr 2026):** the screen IPC wedge correlates strongly with `claude` usage because the user's `claude` wrapper at `bin/claude` runs `screen -X msgwait 0`, `screen -Q info`, `screen -X msgwait 3` on every invocation (to capture terminal size). Under load, that `screen -Q info` occasionally leaves the screen master stuck in `recvmsg()` on the client connection, which deadlocks IPC for everything downstream (including the hourly `screen-bufsave` cron). This explains the Avalir+quin (heavy claude usage) vs Haven (rare claude usage) asymmetry.

**Mitigation:** wrap the IPC call with `timeout 2 screen -Q info` so a wedged query self-clears (kill closes the socket → master gets EOF → master proceeds). Better long-term: replace with `tput cols` / `tput lines` / `$COLUMNS` / `stty size` and stop using screen IPC for terminal sizing.

Possible (but unproven) link to the SSH wedge: a stuck `claude` output stream inside screen could fill the per-window buffer, blocking screen's main select loop, which then doesn't service IPC; meanwhile the same backpressure could contribute to the SSH data-channel collapse. Treat this as a hypothesis, not established fact. What *is* established: both wedges are aggravated by very-long-uptime sessions accumulating exotic state.

### Possible Causes Worth Investigating Before Transport-Level Fixes

The wedge correlates with `claude` activity, but the actual mechanism appears to be **heavy ssh-agent-forwarding traffic** — the connection log routinely shows thousands of `auth-agent@openssh.com` channel opens (~1 per 100 seconds, sustained for days). That polling pattern is suspicious; it suggests *something* on quin is hammering the agent unnecessarily. Candidates to investigate before papering over the symptom:

- A tmux/screen status bar or shell prompt running `git` on every refresh
- A backgrounded watcher / language server / IDE plugin doing periodic git operations
- An MCP server (configured via project-scoped `.mcp.json`) polling git or gh
- A cron job using forwarded keys

Diagnostic approach (when the session is healthy): `lsof -U +c0 | grep "$SSH_AUTH_SOCK"` sampled a few times, or interpose a logging `socat` in front of the agent socket and watch what connects.

## EC2 Sandbox Sync Integration

**⚠️ IMPORTANT FOR AI AGENTS**: Only read this section if the user specifically mentions EC2 sandboxes, syncing with EC2, or working with "quin" instances. Otherwise, skip this section.

### Overview
EC2 sandboxes ("quin" instances) can be configured for bidirectional file sync with Avalir (desktop) using Tailscale VPN and Syncthing. This allows seamless development with automatic sync of `~/common`, `~/work`, and `~/CE` directories.

### Key Documentation Files (When Working on EC2 Sync)
- **[EC2-sync-proof-of-concept.md](EC2-sync-proof-of-concept.md)**: Complete test results and current setup
- **[EC2-sync-automation-roadmap.md](EC2-sync-automation-roadmap.md)**: Detailed automation implementation guide
- **[syncthing-troubleshooting.md](syncthing-troubleshooting.md)**: Troubleshooting guide for Syncthing sync issues
- **[ec2-sync-bootstrap.sh](ec2-sync-bootstrap.sh)**: Bootstrap script for new EC2 instances
- **[/export/proj/common/bin/sandbox-setup](/export/proj/common/bin/sandbox-setup)**: Local script to setup tunnels

### Private Files (When Needed)
- **[private/ec2-sync-credentials.md](private/ec2-sync-credentials.md)**: Current EC2 instance ID, Tailscale auth key, device IDs

### Quick Start for AI Agents
If user asks about EC2 sandbox sync:
1. Read `EC2-sync-proof-of-concept.md` for current state
2. Check `private/ec2-sync-credentials.md` for instance ID
3. Run `sandbox-setup <instance-id>` to establish connections
4. Access Syncthing UI at http://localhost:8388
5. If sync issues occur, consult `syncthing-troubleshooting.md` for diagnosis and solutions
6. For Claude Code: MCP servers are configured via project-scoped `.mcp.json` files
   - After initial sync, restart Claude Code to load the configuration
   - Authenticate with `/mcp` command if using OAuth services

## Current Status

- **NAS Migration Complete**: QNAP Nakama (TS-364) deployed and operational (August 2025)
  - Single 4TB disk configuration with snapshot support
  - SSH/rsync access configured with key-based authentication
  - Backup directories created at `/share/backup`, `/share/archive`, `/share/personal`, `/share/proj`, `/share/work`
  - Daily IHM (IronWolf Health Management) scans running at 03:29 AM
- **EC2 Sandbox Sync**: Operational with Tailscale + Syncthing (September 2025)
  - Proof-of-concept complete, semi-automated setup available
  - See EC2 Sandbox Sync Integration section if working on this
- **Haven GPU/Crash Issues Resolved** (February 2026): Kernel upgrade from 6.1-oem to 6.8-generic fixed the i915 GPU driver bugs causing crashes. Haven now runs modesetting + iris + glamor with proper hardware acceleration. See `summary:haven-kernel-upgrade-and-gpu-fix.md` for details.
- **Haven NoMachine + Vivaldi Combo Still Crashes** (April 2026): Kernel fix raised the crash threshold but didn't eliminate it — running Vivaldi's heavy GPU load while NoMachine streams the display is still beyond this hardware's margin. Mitigated by `~/common/bin/vivaldi-guard` wrapper on Haven's Vivaldi panel launchers, which refuses to launch Vivaldi when a NoMachine session is active. Same session fixed an unrelated `/export` mount failure caused by NVMe probe-order flip vs. hardcoded device paths in fstab. See `summary:haven-fstab-uuid-and-vivaldi-guard.md`.
- **Haven Crashes Now on Routine Load** (May 2026): Crash threshold has dropped further — Vivaldi 7.9 launches and even bare `termstart` now trigger silent power-offs without GPU bursts or NoMachine. Pattern points to mainboard component aging (VRMs/decoupling caps). Hardware intervention (battery replacement + CPU/GPU repaste + visual cap inspection) pending. Limp-along: Vivaldi must launch from terminal with `--disable-gpu`; Docker/Insync disabled; CPU governor on powersave; suspend rather than reboot. Same session: Vivaldi 6.1→7.9 upgrade succeeded; CSS modding migrated from `/opt/vivaldi/`-patch style to the official `chrome://flags/#vivaldi-css-mods` + Custom UI Modifications folder approach pointing at `~/common/vivaldi-patch/`. See `summary:vivaldi-7.9-upgrade-and-haven-instability.md`.
- **Haven Limp-Along Made Persistent** (May 11 2026): Another silent power-off after a 3-day uptime — the longest since May 8, confirming the limp-along config works. Made persistent and idempotent: forensic monitor relocated from lost `/tmp/viv-mon2.sh` to `~/local/bin/viv-mon` with 50 MB log rotation; `termstart` now sets the powersave governor and auto-starts the monitor (gated by pidfile); the touchpad applet got `off`/`on` startup modes and `termstart` passes `off`; `bin/vivaldi-guard` now injects `--disable-gpu` automatically on Haven. Only new software variable since May 8: NoMachine self-updated `8.22.1→9.5.7` on May 9 — flagged for watch, not yet downgrading. See `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md`.
- **Haven viv-mon Made Functional + NoMachine Profile Captured** (May 13 2026): Another silent power-off (workspace switch onto fullscreen video with NoMachine active). Investigation discovered that `viv-mon`'s `pkg=` and `gpu=` columns had been logging zeros the entire May 11→13 window — RAPL energy counters default to `0400 root` (PLATYPUS / CVE‑2020‑8694 mitigation) and the script silently fell back to 0. Fix: `termstart` now `sudo chmod a+r`s `/sys/class/powercap/intel-rapl*/energy_uj` at boot, and `viv-mon` was rewritten to pick RAPL subdomains by name (Raptor Lake has no GPU-only domain — `gpu=` was always `uncore=`, now renamed accordingly), probe the i915 DRM card path (`card1` because `simpledrm` claimed `card0`), add `gfreq=cur/act` + `rc6=Δms` columns from `/sys/class/drm/card1/`, add a `tp=on/off` touchpad-state column (via `xinput`), and emit a periodic `BROWSERS` snapshot line listing distinct browser profiles by their `--user-data-dir` basenames. Same session: full NoMachine usage profile captured and `xpra shadow` mode assessed as a possible replacement — assessment concludes **defer the swap** (crash data doesn't actually point at NoMachine, crashes happen without it, real root cause is hardware degradation, switching cost is non-trivial); revisit only if the next crash's new viv-mon data implicates the framebuffer-capture path. Open mystery: intermittent ~1-sec truncated audio for weeks, possibly correlated with browser sessions, probably unrelated but logged for future tracking. See `summary:haven-may13-vivmon-fix-and-nomachine-profile.md`.
- **Graymoor Setup In Progress** (April 2026): New headless server (Debian 13.2) to replace Zadash
  - OS installed; not yet connected to network
  - IP-KVM purchased: Sipeed NanoKVM Lite (E variant), pending assembly
    - 3D-printed case planned (Bambu Lab A1 printer available)
  - Next steps: assemble NanoKVM, flash SD, connect to office hub, configure SSH/Tailscale/Syncthing
- **Network Stability**: Core infrastructure stable with Tailscale VPN and Eero mesh WiFi

## Tools and Scripts

### parse-nakama-alerts.pl
Parses QNAP Nakama email alerts to extract the actual alert messages from MIME-encoded emails.

**Usage:**
```bash
# Parse individual alert emails
./parse-nakama-alerts.pl "/path/to/alert-email.eml"

# Parse multiple emails
./parse-nakama-alerts.pl email1.eml email2.eml

# Verbose mode for debugging
./parse-nakama-alerts.pl --verbose email.eml

# Show summary of alert types (when processing multiple files)
./parse-nakama-alerts.pl --all *.eml
```

**Common Alert Types:**
- `[Storage & Snapshots] [IHM]` - IronWolf Health Management disk checks (daily at 03:29-03:30)
- `[Critical Log Alert]` - System critical events

## Key Network Details

- **IP Range**: Private RFC1918 range (DHCP managed by Eero router)
- **VPN Network**: Tailscale subnet for secure remote access
- **Primary User**: [see private/credentials.md] across all Linux systems
- **Security**: UFW firewalls on Linux systems, no external port forwarding
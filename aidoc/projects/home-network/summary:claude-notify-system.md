# Claude Code Notification System (opt-in, per-host)

Built 2026-06-09. Lets the user opt in -- per host -- to being told when a Claude
Code session is waiting for input, with all notifications surfacing on **Avalir**
(the hub) as short blinking lines like `Claude [haven:common]` in the existing
"Notifications" window, and the loud Haven zenity popup still firing whenever
Avalir is "blinking".

## What problem it solves

The old behavior: Avalir's Notifications window showed *its own* local Claude
markers unconditionally (no control), and Claude on Haven or quin couldn't notify
at all. The user wanted **opt-in** (nothing notifies until you ask), **per-host**
control, notifications from *any* host shown on Avalir, and shorter lines that
name the host and project dir.

## Mental model: Avalir is the hub and the sole connection initiator

Everything hangs off one principle: **Avalir reaches OUT; nothing reaches back
in.** Avalir holds the subscription registry, polls subscribed hosts for their
markers, renders the window, and answers the Haven cron's "is anything pending?"
check. The ephemeral EC2 sandbox (quin) is *never* asked to connect back to the
home network -- that would be fragile (quin is relaunched with new identity) and
poor security posture (no standing cloud->home SSH path).

## The subscription registry

- Lives on the hub: `~/.claude/notify-enabled/` (one empty file per enabled
  host). Empty dir / no dir = the default = **nothing notifies anywhere**.
- It is **host-local runtime state, NOT in the repo** -- do not expect it under
  version control, and it has no bearing on commits.
- Managed by `claude-notify` (below).

## Components

### `bin/claude-notify` (bash)
- `claude-notify [on]` (bare = `on`), `off`, `status`, and internal `emit`.
- `on`/`off` take an optional host arg; default is this host's friendly name.
- Routing by where it runs:
  - **On the hub (avalir):** edits `~/.claude/notify-enabled/` directly.
  - **On a persistent home box** (one listed by `friendly-hosts`, e.g. haven):
    re-invokes itself on the hub over ssh with `BatchMode=yes` (fail fast, never
    a password prompt) -- these boxes have key auth to Avalir.
  - **On the sandbox (quin)** (NOT in `friendly-hosts`): it has no ssh path back
    in, so it prints guidance ("manage it from avalir: `claude-notify on quin`")
    and exits non-zero. **You manage quin's subscription from the hub**, e.g.
    `claude-notify on quin` typed on Avalir. (You're never physically at quin
    anyway -- you reach it via a terminal from Avalir.)
- `emit` is purely local: prints one `basename(cwd)` line per pending marker
  (`/tmp/claude-code-notification-*.json`). It is what the monitor runs on each
  enabled host to pull its waiting-session list. No hub interaction; safe to run
  anywhere (incl. quin, over ssh).

### `bin/monitor-notifications` (perl, myperl::Pxb) -- reworked
- **Display mode** (what Avalir's `watch -tc monitor-notifications` runs): keeps
  the Pidgin urgency check and webcapture check **unconditional** (always-on),
  and replaces the old local-only Claude block with an **opt-in aggregation**:
  read the registry; for each enabled host, gather its pending markers via
  `claude-notify emit` -- run locally if the host is us, else pulled over ssh --
  and print one `Claude [host:projdir]` line per waiting session. `host` is the
  registry/friendly name; `projdir` is `basename(cwd)` from the marker.
- **Pull transport:** `capture()` fork-execs (no shell, so the literal `~` in the
  remote command reaches the far shell unexpanded and expands against the *remote*
  home) and redirects the child's STDERR to `/dev/null` (so ssh chatter -- a raced
  control socket, a timeout -- can never pollute the window). autodie is off in
  `capture()` so a down host yields no lines instead of killing the tick.
- **ssh options** for pulls: `BatchMode=yes`, `ConnectTimeout=2`, ServerAlive
  keepalives, and `ControlMaster=auto`/`ControlPersist=30` for cheap connection
  reuse (kind to fragile Haven). Concurrent invocations (a watch tick racing the
  Haven cron's hub-check) can collide on the control socket and "disable
  multiplexing" -- harmless, and now silent thanks to the stderr redirect.
- **Routing** (which ssh target for an enabled remote host): if the host is in
  `friendly-hosts` -> plain `ssh <host>`; otherwise it's the sandbox -> use
  `sandbox-ssh-target <host>`. Skip the host this tick if the target can't be
  resolved/reached.
- **Popup branch** (`monitor-notifications <remote>`): UNCHANGED in shape. The
  Haven cron runs `monitor-notifications avalir`, which sshes Avalir and runs
  `monitor-notifications -q` there; non-empty output (Pidgin OR any subscribed
  Claude, as aggregated on Avalir) means "Avalir is blinking" -> pop the URGENT
  zenity on Haven. Because the `-q` aggregation is now opt-in-aware, the popup
  automatically covers exactly what the window shows. No recursion: the pull runs
  `claude-notify emit` on the remote, not the monitor.

### `bin/sandbox-ssh-target` (bash)
Resolves the current EC2 sandbox's ssh target via Tailscale (`tailscale status`
-> `<name>-<launchid>` -> `-p 8822 $CE_REMOTE_USERNAME@<ip>`), the same mechanism
term-quin uses. Prints the target args, or exits non-zero if the sandbox isn't up
(caller skips it). Extracted from term-quin so there's one definition of "how to
reach the current sandbox". (Deferred: point term-quin itself at this -- see
TODO.)

### `bin/friendly-hosts` (bash, pre-existing WIP, now in use)
Lists the persistent home boxes by enumerating `local/<host>/` dirs. Used as the
**routing oracle**: a host in this list is a normal box (plain ssh); a host NOT in
it (the sandbox) needs the Tailscale target. Note it deliberately does NOT list
quin (sandboxes have no `local/<host>/` dir) -- that absence is the signal.

### `root/lbin/localhostname` -- gained a `-f`/`--friendly` flag
`-f` trims an EC2 sandbox instance suffix (`quin-i-05db6a...` -> `quin`). WITHOUT
the flag the raw name is unchanged, **on purpose**: makeln keys sandbox detection
off the full `$LOCALHOSTNAME == "quin-"*` form and would misclassify quin if this
trimmed by default. The trim now lives in exactly one place; callers that want the
friendly name pass `-f` (claude-notify, monitor-notifications). NB: `$LOCALHOSTNAME`
the env var is only set by interactive tcsh, so cron-safe code must call the
`localhostname` script, not read the var.

### `rc/tcshrc` -- `ack-claude` alias fixed
Was hardcoded to `rm /tmp/claude-code-notification-avalir-*` (only worked on
Avalir). Now `rm -f /tmp/claude-code-notification-*` -- inherently local to
whatever host you run it on (each host only ever holds its own markers; the pull
reads remote markers over ssh, never copies them). This is the **per-notification
dismissal** (clears the marker), distinct from `claude-notify off` (per-host
subscription toggle; leaves the marker, so re-subscribing shows it again).

### `conf/crontab/haven.cron` -- popup check via launch-perl
The minute cron now runs `launch-perl monitor-notifications avalir` (per the
launch-perl doctrine for cron). Applies on Haven at its next makeln.

## Marker lifecycle (unchanged, shared across all hosts)

The Claude Code hooks in the synced `~/.claude/settings.json` (symlinked into the
repo, identical on every host) write `/tmp/claude-code-notification-<hostname>-<session>.json`
on the `Notification` event and remove it on `UserPromptSubmit`/`SessionEnd`/
`PostToolUse`. Verified present + functional on avalir, haven, AND quin. The
`Notification` event fires immediately on a permission prompt, but only after
**~60s idle** for a plain "waiting for your input" -- so a Claude that *just*
finished a turn won't show for up to a minute (not a bug).

## How to use

- `claude-notify on <host>` (on Avalir) / `claude-notify on` (on a home box) to
  subscribe; `off` to unsubscribe; `status` to list.
- Manage **quin from Avalir**: `claude-notify on quin`.
- `ack-claude` (on the host with the waiting Claude) to silence one notification
  you've seen but aren't answering yet.

## Key gotchas (recorded so the next agent doesn't relearn)

- **tcsh quoting:** remote commands are invoked as bare full paths
  (`~/common/bin/claude-notify emit`) with no shell metacharacters, so the remote
  tcsh can't mangle them. For anything with pipes/redirects/loops, use a
  `bash -s` heredoc (see the README "Shell Environment" section).
- **No reverse SSH from quin** -- by design. Subscriptions for quin are managed
  on the hub.
- **quin's `hostname -s`** is the long `quin-i-<id>`; display/registry use the
  friendly `quin` via `localhostname -f`. The monitor labels remote markers with
  the *registry key*, so quin's ugly hostname never reaches the window.
- **stderr discipline:** the monitor must never let a subprocess's stderr reach
  the watch window; `capture()` enforces this.

## Deferred work (in TODO.md)

- Add a "delay before popup" option (escalate a subscribed Claude to the Haven
  popup only after it's been waiting > ~30-60s; uses the marker `timestamp`).
- DRY up `bin/term-quin` to use `bin/sandbox-ssh-target` (it still has its own
  inline copy of the Tailscale lookup).

## Verification done (2026-06-09, live across all three hosts)

- `claude-notify` on/off/status/emit on the hub; emit pulled over ssh from haven
  (plain) and quin (sandbox target); registration from haven (BatchMode ssh);
  graceful guidance (no password prompt) from quin.
- Monitor: empty registry -> nothing (no ssh); enabled hosts aggregate as
  `Claude [host:projdir]`; `off` drops a host's line on the next tick while its
  marker persists, `on` restores it; ssh stderr noise confirmed suppressed across
  runs racing the live watch.

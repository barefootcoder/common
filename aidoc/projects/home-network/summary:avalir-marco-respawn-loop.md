# Avalir marco respawn loop -> xdg-desktop-portal 7 GB swap blowup

**Date:** 2026-06-23
**Host:** Avalir (uptime ~199 days at the time, boot 2025-12-05)
**Symptom that surfaced it:** low memory; `topswap` showed
`xdg-desktop-portal` (PID 3867) holding **6 GB / ~7 GB of swap** -- a process
the user had never seen on the list in ~7 years of watching it.

## TL;DR

The portal was the *victim*, not the cause. A **marco (window manager) respawn
loop firing ~18 times a second** flooded the session D-Bus with
connect/disconnect churn; `xdg-desktop-portal` tracks every client connection,
so it leaked a sliver per event and compounded to ~7 GB of swap over weeks. The
loop was set up by the "Reset Window Manager" panel launcher (`marco --replace`)
and ignited ~2026-05-29 by a marco crash. Fixed by breaking the loop, restarting
the portal, and replacing the launcher with a safer `fix-wm` script.

## Diagnosis chain

1. `topswap` PID 3867 = `/usr/libexec/xdg-desktop-portal`, `VmSwap` ~7.0 GB +
   `VmRSS` ~1 GB, ~all private dirty anon (real leak). Running since the
   2025-12-05 boot (not a mid-uptime restart; package unchanged since 2022, so
   **not** a recent upgrade regression). It holds ~44% of the 16 GB swap.
2. Live D-Bus check: portal receives almost no traffic, BUT the session bus is a
   firehose -- **~45,700 dbus-monitor lines in 8 s** (~5,700/s). In 8 s: **153
   `Hello`** (new connections), **154 `NameAcquired` + 154 `NameLost`**, **307
   `NameOwnerChanged`**, plus matching gnome/mate-session `ClientAdded/Removed`
   and gvfs `MountTracker` queries = the fingerprint of ~18 short-lived
   GTK/GNOME processes spawning+dying per second. Transient bus names were near
   `:1.42951732` (~43M connections since boot; ~2.5/s lifetime avg vs ~18/s now
   = recent ramp).
3. Process sampling: **73 distinct fresh `marco` PIDs in ~4 s**, parent =
   mate-session (PID 3462), alongside one stable marco (3468550). The stable WM
   3468550 is a child of `mate-panel --replace` (from a Mar 7 launcher click),
   **not** the marco mate-session manages.
4. Repeating message in `~/.xsession-errors`: *"Screen 0 ... already has a window
   manager; try using the --replace option"*. The log had grown to **15.4 GB**
   (~567 MB/day) -> dates the loop onset to **~2026-05-29**, matching a marco
   coredump in `meta_display_set_cursor_theme` logged **May 28**.

## Root cause / mechanism

- The "Reset Window Manager" panel launcher was a bare **`marco --replace`**
  (`~/.config/mate/panel2.d/default/launchers/marco.desktop`). It creates an
  **unmanaged** marco that grabs the screen.
- mate-session manages *its own* marco and, when in an active relaunch state,
  relaunches it on exit. That relaunch finds the screen already owned by the
  unmanaged instance and exits **cleanly (status 0)** "already has a window
  manager". A clean exit does **not** trip mate-session's crash-throttle, so it
  relaunches again immediately -> ~18/s forever.
- **mate-session does NOT reliably respawn marco on its own** -- confirmed both
  empirically (a `pkill -x marco` produced no respawn) and by the user (the
  manual reset launcher exists precisely because marco death otherwise leaves no
  WM). So the loop is a *pathological* state, not normal respawn behavior.
- Dormant for months (the Mar 7 `--replace` did not loop), it ignited
  ~2026-05-29, almost certainly kicked off by the May 28 marco crash putting
  mate-session into the active-relaunch state.
- Why the portal: every one of the ~18/s marco launches opens then drops a D-Bus
  connection; the bus broadcasts `NameOwnerChanged` for each; `xdg-desktop-portal`
  tracks client connections and leaks a little per event (~1.6M events/day).
  The 2022 binary never changed -- its *callers* went haywire.

## Fixes applied (2026-06-23)

- **Reclaimed the swap:** `systemctl --user restart xdg-desktop-portal.service`
  -> portal dropped from ~7 GB swap + 1 GB RSS to 13 MB RSS / 0 swap; system
  swap-used fell ~6 GB.
- **Broke the loop:** `pkill -x marco`. The SIGTERM (abnormal death) trips
  mate-session's crash-throttle, so it backed off instead of relaunching. Since
  mate-session would NOT bring marco back on its own, a single `marco --replace`
  was launched to restore the WM. Result verified: single stable marco, 0
  `Hello`/8 s (was 153), `.xsession-errors` flat.
- **Reclaimed disk:** truncated the 15.4 GB `~/.xsession-errors` (after the loop
  stopped, so it would not just refill). Freed ~15 GB.
- **Durable launcher fix:** new **`root/sbin/fix-wm`** (deploys to
  `/usr/local/sbin/fix-wm` via root's `psync`+`makeln`, with the other `fix-*`
  scripts). It does `pkill -x marco` (SIGTERM) *then* `marco --replace` -- never
  handing mate-session a clean exit to chase. Guards on `$DISPLAY`, verifies a WM
  came back. The panel launcher's `Exec` and `bin/dtop-gaming` line 31 (which
  also did a bare `marco --replace`) were both repointed at `fix-wm`.

## Residuals / watch-items

- **mate-panel caches launcher .desktop data**, so the launcher's new `Exec`
  may not take effect until the panel reloads / next login (Avalir rarely
  relogs). Until then a click may still run the old `marco --replace`. Verify by
  clicking and checking no `Hello` storm follows. (TODO captured.)
- **`fix-wm` stops the user re-igniting the loop, but a spontaneous marco crash
  could still kick mate-session into it** (that is how this started).
  **-> If you are reading this because the problem recurred: the first move is to
  extend `fix-wm` into a self-healing watchdog** (pidfile-gated, viv-mon/keymap-mon
  style -- detect the marco PID churn or a D-Bus `Hello` storm and auto-run
  `fix-wm`), or something similar -- rather than hand-fixing it again. (TODO
  captured.)
- The portal leak is loop-driven, not standalone; with the loop gone it should
  not recur. A periodic portal restart is only warranted if a loop comes back.
- The May 28 `meta_display_set_cursor_theme` crash itself was a single event and
  was not re-investigated; the stable marco has run that init path fine for 100+
  days, so it is treated as transient unless it recurs.

# Haven June 4, 2026 Crash: GPU Ramp on Browser Restart

## Summary

Silent power-off at approximately **17:00:43 PDT** on June 4, 2026.  Haven had
been running for ~12 days 13 hours since the May 22 double-crash recovery boot.

**User-confirmed trigger:** Setting up a video call in ungoogled-chromium
(default profile -- light: one window, ~a dozen tabs); microphone wasn't
working, so the user exited and restarted ungoogled-chromium.  The crash hit
within a second of the restart.

**New finding:** The Intel integrated GPU frequency ramped from a constant
300 MHz to **1083/1100 MHz** in the final viv-mon sample before the crash --
the first time a GPU ramp has been visible in viv-mon data at a crash moment
(May 11-13 had zeroed GPU data; earlier crashes had no per-sample GPU freq).
The ramp is the browser's GPU-process init at startup (GL context creation,
first composite, plus the meeting page's camera preview reloading).  The
RAPL cap (PL1=20W / PL2=27W) was confirmed in place but did NOT prevent the
crash -- measured pkg peaked at only ~24W, *within* the cap.  The killing
mechanism is therefore the **inrush current transient of the GPU
idle-to-max ramp**, not sustained power.

Key implication: workload size is irrelevant.  A light browser restart
crashes the box because *any* GPU wake-from-idle ramp is now beyond what the
aging power-delivery hardware tolerates.  This is consistent with May 13
(workspace switch onto fullscreen video = GPU ramp) and the April
Vivaldi+NoMachine pattern.  Note that Vivaldi on Haven runs `--disable-gpu`
(via vivaldi-guard), so it never ramps the GPU -- ungoogled-chromium has no
equivalent guard and does use the GPU.

**Timeshift is exonerated for this crash** (see below) -- but investigating
it solved the May 17 cron-revert mystery as a side effect.

---

## Timeline

| Time (PDT) | Event |
|---|---|
| 14:00:01 | Timeshift daily snapshot `2026-06-04_14-00-01 D` created -- heavy rsync, **survived fine** |
| 16:49:21 | User connects ECOXGEAR Bluetooth speaker (unusual midweek; normally Saturdays) |
| 16:49:21 | Keymap wipe: kc91 colon mapping reverted (Xorg re-adds AVRCP "keyboard", recompiles keymap) |
| 16:50-16:58 | Normal idle, pkg=3-8W, load=0.6-1.2, gfreq=300MHz constant |
| ~16:59 | User exits ungoogled-chromium; teardown (tab processes exiting, profile flush) raises load to ~4 |
| 17:00:01 | Timeshift hourly `--check` fires -- **no-op, done in ~200ms** (daily already created at 14:00) |
| 17:00:02-03 | Brief 20W blip (check process spawn); recovers immediately |
| 17:00:03-38 | Load decaying 4.0→3.1 (teardown aftermath), pkg 7-18W oscillating |
| 17:00:39.300 | `app-org.chromium.Chromium-3750543.scope` cleanup logged (1h52m CPU over its lifetime) |
| **17:00:43.060** | User restarts ungoogled-chromium; new scope starts |
| **17:00:43.122** | viv-mon: pkg=23.92W, gfreq=300/0, rc6=161ms, tz4=64C |
| **17:00:43.358** | viv-mon: pkg=20.49W, **gfreq=1083/1100 MHz**, rc6=145ms, **tz4=76C** -- last sample |
| ~17:00:43 | **CRASH** (silent power-off) |
| 19:13 | Haven reboots |
| 19:23:18 | Boot snapshot `B` fires (timeshift-boot cron: `@reboot sleep 10m`) -- survived |

---

## viv-mon Signals at Crash

```
2026-06-04T17:00:39.260 pkg=22.45W unc=0.09W gfreq=300/300 rc6=187ms ... tz=60 20 47 61  load=3.32
2026-06-04T17:00:40.539 pkg=24.78W unc=0.02W gfreq=300/0   rc6=214ms ... tz=60 20 47 75  load=3.13
2026-06-04T17:00:42.880 pkg=10.57W unc=0.00W gfreq=300/300 rc6=208ms ... tz=60 20 47 60  load=3.13
2026-06-04T17:00:43.122 pkg=23.92W unc=0.03W gfreq=300/0   rc6=161ms ... tz=60 20 47 64  load=3.13
2026-06-04T17:00:43.358 pkg=20.49W unc=0.08W gfreq=1083/1100 rc6=145ms ... tz=60 20 47 76 load=3.13
                                               ^^^^^^^^^^^^^   ^^^^^^^^                ^^
                                               GPU ramped      rc6 collapsing         tz4 spiked 16C
```

- **gfreq 300→1083 MHz** coincides exactly (within ~300ms) with the new
  Chromium scope starting.
- **tz4 60→76C in one 200ms sample**: a sudden heat burst, consistent with a
  large current transient through a VRM rail or the GPU die.
- **pkg never exceeded ~25W** -- inside the RAPL PL2=27W limit.  RAPL's
  averaging window (~2.4ms for PL2) cannot react to, nor does viv-mon's 200ms
  sampling show, a sub-millisecond inrush spike.
- **bat=100%/Full, 0.000A**: on AC throughout; no AC-event flapping in the
  kernel journal at the crash second (contrast with May 22 crash #1).

---

## What Was Running at Crash Time

- `c:chromium-gsheets` (UC gsheets profile) + the default-profile UC the user
  was restarting; `v:vivaldi-media` (Vivaldi).
- Vivaldi had a YouTube tab that **played earlier in the day but was paused
  and not fullscreen at crash time** (user-confirmed; the constant
  gfreq=300MHz through 16:50-17:00 corroborates -- no video decode running).
- NoMachine: **no active streaming at crash time** (user-confirmed).  The user
  had killed all Avalir-side NoMachine clients before the call -- necessary to
  get sound out of the Bluetooth speaker, since Avalir otherwise hoards the
  audio.  The two `nxserver --list` entries in the 16:49 keymap-mon snapshot
  are server-side session records (likely suspended/disconnected); at most an
  idle, minimized client may have existed on the Haven side.
- ECOXGEAR Bluetooth speaker connected (since 16:49).  **Not a meaningful
  crash contributor**: 11.4 minutes before the crash, steady-state A2DP
  draw is well under a watt, and idle pkg (3-8W) through 16:50-16:59 was
  completely normal.  Its significance is the keymap wipe (below).

---

## Why the RAPL Cap Did Not Prevent This Crash

The May 22 caps (PL1=20W / PL2=27W) were active the entire boot and
re-confirmed on the recovery boot.  The crash happened at ~24W measured pkg.

Mechanism: **sub-sample inrush transient from the GPU ramp**.  When the GPU
steps from 300MHz to 1083MHz (and its voltage rail steps up with it), the
instantaneous current demand spikes for microseconds-to-milliseconds.
Healthy decoupling capacitors absorb this; on a degraded board they don't,
and the resulting rail droop trips the power-off.  RAPL limits *average*
power over its windows and simply never sees a transient this fast.

A contributing-alternative framing: total board draw (CPU at ~20W + GPU ramp
+ display + radios) may have briefly exceeded what the suspect office AC
adapter path could deliver (see the ac-mode analysis in
`summary:haven-may22-double-crash.md`).  Either way the fix class is the
same: **prevent the GPU from ramping**, since RAPL alone can't gate it.

Supporting evidence that sustained load is NOT the problem: the 14:00 daily
Timeshift snapshot -- a heavy multi-minute rsync -- completed without
incident the same afternoon.

**Crucial refinement (post-analysis): the GPU ramp did not come from the
browser process.**  Both UC panel launchers (default profile and gsheets)
already carry `--disable-gpu --disable-gpu-compositing
--disable-hardware-video-decode --enable-unsafe-swiftshader ...`, and the
user launches browsers exclusively via launchers.  The ramp therefore came
from the **X server itself**: Haven runs modesetting+iris+glamor (since the
February kernel fix), so X accelerates 2D rendering on the GPU -- and
painting a freshly-opened browser window (plus the meeting page's camera
preview) is a big burst of glamor work.  A fully software-rendered browser
still ramps the GPU through X.  Consequences: (a) a per-app `--disable-gpu`
guard for UC would be redundant -- it's already in place and didn't help;
(b) the **GPU frequency cap is the only software lever that actually covers
this path**, because it caps the X server's GPU use too.  Also worth noting:
the post-crash boot's own UC relaunch (~19:15, GPU still uncapped) did NOT
crash -- these transients are probabilistic near the threshold, so surviving
one ramp proves nothing.

---

## Timeshift Findings (side investigation)

The user noted the hourly top-of-hour `--check` is particularly unfortunate
timing (meetings start on the hour).  Investigating yielded three findings:

1. **The May 17 cron-revert mystery is solved.**  `/etc/cron.d/timeshift-hourly`
   has mtime **2026-05-17 14:00:02.092** -- two seconds into the 14:00 hourly
   check, 12 minutes after the 13:48 ionice edit.  Timeshift rewrites the cron
   files it owns (`timeshift-hourly`, `timeshift-boot`) to match its settings
   whenever it runs.  The "unknown actor" was timeshift itself.  Corollary:
   **direct edits to those two files will never stick.**
2. **A custom `/etc/cron.d/timeshift-daily` (mtime Jan 12 2025) has survived
   17 months untouched** -- `0 7 * * * root ionice -c3 nice -n 19 timeshift
   --check --scripted`.  Timeshift leaves files it doesn't own alone.  This is
   the proven pattern for adding our own scheduling.
3. **The daily snapshot time drifts into midday.**  Today's fired at 14:00.
   The due-logic is >24h-since-last-daily (not calendar-date), so each crash/
   reboot and each drift compounds; on this box the daily lands at arbitrary
   top-of-hour times, currently mid-afternoon.  Also `schedule_boot=true` +
   `timeshift-boot` cron means a **full snapshot creation fires 10 minutes
   after every boot** -- inside Haven's most vulnerable window (May 22 crash
   #2 was 34s into boot).  Both of tonight's B snapshots survived, but it's
   an unnecessary hazard on this machine.

Current settings: schedule_boot/daily/weekly/monthly all true, hourly false;
counts B=2 D=1 W=2 M=2.  Remediation options are in TODO.md (decision
pending: pin the daily create at a quiet fixed time via an unconditional
`--create --tags D` cron in a file timeshift doesn't own; optionally disable
boot snapshots).

---

## Bluetooth-Triggered Keymap Wipe -- Mechanism #2 Identified

keymap-mon captured the kc91 revert at 16:49:21, coinciding with the ECOXGEAR
speaker connecting.  Xorg.0.log.old then confirmed the mechanism: **every**
ECOXGEAR (AVRCP) connect makes X add it as a *keyboard* input device and
apply `xkb_model pc105 / xkb_layout us` -- the exact "mechanism #2" recompile
signature from the keypad investigation.  The historical mechanism-#2 dates
(May 23 x3, May 24, May 30) were all weekend days, matching the user's
Saturday speaker habit; June 4 was an unusual midweek connect.

This gives the keypad investigation an **on-demand reproducer** (connect the
speaker, watch the wipe).  Full details and fix plan moved to
`keypad-colon-investigation.md`.  Note this does NOT explain the *silent*
mechanism #1 (May 28 Haven, and Avalir) -- that trigger is still unknown.

---

## Mitigations Applied This Session (June 4 evening)

1. **GPU frequency cap -- APPLIED, live + persistent.**  `gt_max_freq_mhz`
   and `gt_boost_freq_mhz` both set to 400 (from stock 1500) on
   `/sys/class/drm/card1/`, applied live at ~20:50 and added to
   `local/haven/bin/termstart` right after the RAPL writes (idempotent, like
   the rest of the block).  Hardware range is RPn=100 / RP0=1500; boost is a
   separate knob that bypasses gt_max if left at stock -- both must be set.
   Downsides accepted by user: slower rendering/WebGL; fixed-function video
   decode mostly unaffected at 1080p; Vivaldi unaffected (`--disable-gpu`
   already); slight average-energy increase in exchange for killing the peak
   transient.  Tunable live -- try 700 if 400 proves too sluggish.
2. **keymap-mon self-heal -- DEPLOYED on both boxes.**  The watcher now
   reapplies `xmodmap ~/.Xmodmap` whenever it sees kc91 lose the colon
   mapping, logging a `REAPPLY` line after the usual forensic `CHANGE`
   snapshot (so trigger-hunting for mechanism #1 is unimpaired).  Broken
   window shrinks to ~5s.  Restarted on Haven (the crash had killed it) and
   on Avalir.  Note: `~/local/bin` on BOTH machines is a symlink into
   `~/common/local/<host>/bin`, so the repo edit deploys itself; only the
   watcher restart is manual.
3. **Timeshift rescheduling -- MOSTLY APPLIED.**  New
   `/etc/cron.d/timeshift-local` (a file timeshift does not own and will not
   rewrite; source-controlled at `conf/crontab/haven-timeshift.cron-d`) does
   unconditional niced creates at quiet hours: daily 04:23 (D), Sunday 04:43
   (W), 1st-of-month 05:03 (M).  Since the snapshots are then always fresh,
   timeshift's hourly --check grid never finds one due and stays a ~200ms
   no-op -- no more midday top-of-hour snapshot drift, for W/M as well as D.
   The pre-existing custom 07:00 niced `--check` (`timeshift-daily`, Jan
   2025) was left in place as a harmless backstop.  **Boot snapshot moved
   from +10m to +45m** (user wanted boot snapshots kept -- reboots are rare
   and crash-adjacent, so they're valuable -- just not in the vulnerable
   early window): `schedule_boot` set to false (user-approved json edit;
   backup at `timeshift.json.bak.pre-jun4`), a `--check` run let timeshift
   remove its own `timeshift-boot` cron, and the `@reboot sleep 45m ...
   --tags B` line in `timeshift-local` took over.  The 10m delay was a
   hardcoded string in the timeshift binary -- not configurable any other
   way.  Verification TODO covers pruning behavior for B with the schedule
   off, plus one-time borderline W/M self-creates on June 6/7 (~05:00,
   quiet hour, harmless) before the new W/M cron lines take over.
4. **UC launcher `--disable-gpu`: no action needed** -- discovered already
   present on both UC launchers (see the X/glamor refinement above).

## Verification / Watch Items

- After the next few boots: confirm termstart applied the GPU cap
  (`cat /sys/class/drm/card1/gt_max_freq_mhz` -> 400) and viv-mon's `gfreq=`
  column never exceeds ~400.
- After 2026-06-05 04:23: confirm the daily snapshot timestamp is 04-23 and
  the D count stays at 1 (pruning on the --create path).
- If 400MHz feels sluggish in daily use (video calls, page rendering), bump
  to 700 live and update termstart.
- Keymap: next ECOXGEAR connect should produce CHANGE + REAPPLY pairs in
  `/var/tmp/keymap-mon.log` and the colon mapping should survive (minus a
  <=5s window).  That doubles as the reproducer test for the eventual
  TWO_LEVEL fix.

## System Status at End of Session (June 4 ~22:10)

- Haven up since 19:13, stable
- RAPL: PL1=20W, PL2=27W; governor powersave; GPU max/boost capped to 400MHz
- viv-mon: running; keymap-mon: running with self-heal (Haven pid 1054508,
  Avalir pid 2732703)
- ac-mode: office-ac since 13:48, 0.55/hr (normal)
- Boot snapshot 19:23 completed without incident; snapshot schedule now
  pinned to 04:23/04:43/05:03 quiet-hour creates

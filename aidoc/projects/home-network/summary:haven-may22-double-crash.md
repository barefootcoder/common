# Haven: May 22 Double Crash, RAPL Power Cap, AC-Mode Tool

## Session Context

Triggered by **two silent power-offs on Haven on 2026-05-22**, ~15 minutes
apart:

- **Crash #1: 17:07:23 PDT**, after a 3 d 19 h 34 m uptime (longest of
  the May series). User was actively using a browser over NoMachine in
  windowed mode (not fullscreen).
- **Crash #2: 17:21:58 PDT**, **34 seconds into the recovery boot**,
  during `termstart`.

This is a sequel to:

- `summary:haven-may17-timeshift-snapshot-crash.md` (May 17)
- `summary:haven-may13-vivmon-fix-and-nomachine-profile.md` (May 13)
- `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md` (May 11)
- `summary:vivaldi-7.9-upgrade-and-haven-instability.md` (May 8/9)
- `summary:haven-fstab-uuid-and-vivaldi-guard.md` (April)
- `summary:haven-kernel-upgrade-and-gpu-fix.md` (February)

This crash matters because (a) it's the first time we've seen back-to-back
crashes, with the second one happening during a routine boot's
self-launching processes; (b) the new viv-mon data localized the trigger
to a CPU package-power threshold rather than thermal/GPU/IO-starvation;
and (c) the journalctl AC-online history surfaced a previously
unrecognized signal — Haven has been logging **~18 spurious AC-online
transitions per day** for at least a week, with three of them firing at
the *exact second* of crash #1.

## Crash Forensics

### Crash #1 — 17:07:23 PDT (browser load, AC wobble)

Final ~30 seconds of viv-mon trace (selected lines):

```
17:07:20.179 pkg=21.01W ... bat=8.28V/0.000A/0.00W/88%/Charging tz=63 20 49 79 load=2.29 tp=off
17:07:20.912 pkg=33.38W ... tz=65 20 49 70
17:07:21.448 pkg=12.81W ... bat=8.28V/0.572A/4.74W/88%/Discharging tz=65 20 49 63
17:07:22.003 pkg=31.63W ... bat=8.28V/0.572A/4.74W/88%/Discharging
17:07:22.505 pkg=12.75W ... bat=8.28V/0.000A/0.00W/88%/Charging
17:07:27.466 pkg=37.55W ... tz=65 20 49 80
17:07:28.461 pkg=35.67W ... tz=65 20 49 76
17:07:28.719 pkg=15.95W ... tz=80 20 49 65
17:07:29.221 pkg=38.69W ... tz=80 20 49 80
17:07:30.466 pkg=36.06W ... tz=80 20 50 75
17:07:33.272 pkg=39.22W ... tz=68 20 50 81
17:07:42.221 pkg=37.90W ... tz=67 20 50 80    ← last line
```

Concurrent journalctl events:

```
17:07:21 systemd-udevd[2929889]: AC: Process '/usr/sbin/powertop --auto-tune' failed with exit code 1.
17:07:22 systemd-udevd[2929889]: AC: Process '/usr/bin/powerprofilesctl set power-saver' failed with exit code 1.
17:07:23 systemd-udevd[2929889]: AC: Process '/usr/bin/powerprofilesctl set balanced' failed with exit code 1.
```

Three AC udev events (one rule invocation, three commands) in the same
second the system died. Both `set power-saver` (AC went offline) and
`set balanced` (AC came back online) fired in the same PID — a rapid
back-and-forth bounce.

Conclusions:

- **Not thermal-overrun.** tz4 peaked at 88 °C briefly but spent most
  of the window in the 60s/70s.
- **Not GPU.** `gfreq` and `rc6` were unremarkable (frequent 300-MHz
  idles, rc6 ~250 ms/sample).
- **CPU package power was the load.** Sustained 30–40 W draw for 30+ s
  before the kill, with the May 13 summary's no-dedicated-GPU-domain
  insight still holding (so the spike is genuinely CPU + uncore).
- **AC adapter wobbled into the failure.** Battery state cycled
  Charging → Discharging at 0 A → Charging multiple times in the final
  5 seconds. Three `AC:`-tagged udev firings landed in the crash
  second. This is the first crash where the journal records an external
  power-path event coincident with the kill.

### Crash #2 — 17:21:58 PDT (boot self-immolation during termstart)

The recovery boot completed in 1 min 9 s (`Startup finished in 8.313 s
(firmware) + 7.430 s (loader) + 19.248 s (kernel) + 34.360 s
(userspace)`). The system died exactly at the "userspace done" instant.

viv-mon's first 1.4 s of post-boot samples (it started polling at
17:21:56.875, after `cpupower` and `chmod`-RAPL ran):

```
17:21:57.005 pkg=29.64W ... bat=8.36V/0.516A/4.31W/92%/Charging tz=69 20 39 74 load=2.56 tp=on
17:21:57.257 pkg=15.09W ...
17:21:57.503 pkg=14.45W ...
17:21:57.746 pkg=13.88W ...
17:21:57.990 pkg=18.34W ...
17:21:58.227 pkg=24.24W ...
17:21:58.457 pkg=32.28W ...
17:21:58.694 pkg=38.34W tz=69 20 39 79 load=2.56 tp=on    ← last line
```

No `AC:` events this time; battery state stable at Charging at 0.5 A.
What killed it was the parallel-startup burst:

- `juno-pp` (systemd service) finished at 17:21:57
- `TLP` started 17:21:57, finished 17:21:58
- The MATE session restore was lighting up XDG autostart in parallel
- All converged into the final 500 ms with pkg climbing 18 → 38 W

**Same pkg-power threshold as crash #1** (sustained ~30 W, peak ~38 W).
The crash-trigger threshold has now dropped low enough that a routine
boot's own self-launching processes can cross it.

### Common cause

Both crashes died as the CPU package crossed ~30 W sustained, with peaks
in the high 30s. This is a *lower* threshold than the May series has
shown before (May 11/13 crashes were on Vivaldi+NoMachine GPU-heavy
loads; May 17 was on Timeshift IO-starvation; this one is **CPU package
power alone**, with no GPU or IO component). The hardware-degradation
trajectory previously called out in `home-network/README.md` ("crashes
now on routine load") has continued.

### Battery state for the record

```
POWER_SUPPLY_CHARGE_FULL_DESIGN = 9600 mAh
POWER_SUPPLY_CHARGE_FULL        = 3884 mAh   → 40.5% of design
POWER_SUPPLY_CYCLE_COUNT        = 0          (firmware not reporting)
```

A 40%-of-design battery has nowhere to bridge from when a wobbly AC
adapter blinks under a 38-W demand. This is the load-power side of the
May-19 fire-evac event preparation reality check: the laptop's local
backup-power margin is gone.

## The AC-Events Anomaly

`journalctl | grep "AC: Process"` shows the udev rule that fires on
every AC online/offline transition. Per-day counts for the past week:

| Date  | Events |
|---|---|
| 05-15 | 15 |
| 05-16 | 18 |
| 05-17 | 13 |
| 05-18 |  7 |
| 05-19 | 18 |
| 05-20 | 20 |
| 05-21 | 23 |
| 05-22 | 15 (and crashed) |

**129 events in 7 days, ~18/day.** User's actual plug/unplug rate is
~3 unplug + ~3 plug-back-in per day, i.e. ~6/day max. So **roughly 12
events/day are spurious AC-online flickers** — physical-path issues
(cable wiggle, jack, adapter undervoltage, EC bug) that the user is
*not* causing.

The fact that three of them landed in the crash second of crash #1 is
the smoking-gun coincidence that made this worth investigating.

## Mitigations Applied This Session

### 1. termstart de-burst (`local/haven/bin/termstart`)

Two new pauses added to slow down the parallel-burst at boot:

- **`sleep 1`** between the early sudo block (cpupower / chmod-RAPL /
  tee /sys/power/mem_sleep / tee /proc/acpi/wakeup) and the viv-mon
  launch. Lets MATE session restore + juno-pp + TLP + ssh-add settle
  before viv-mon's 5 Hz poll adds load on top.
- **`sleep 0.5` + `sleep 0.7`** sleeps between the three `myterm` calls
  (Haven / Avalir / Zadash) and the music-player + kid3 launches. Each
  `myterm` forks a `kitty` + (often) `ssh` handshake + `screen` attach;
  doing all three back-to-back was the burst that caused crash #2.

Total added latency: ~3.6 s on the path to fully-up. Cheap insurance
given that crash #2 *was* an instant boot-time crash.

### 2. RAPL package-power cap

Stock values on Haven were:

- `constraint_0_power_limit_uw` (long_term / PL1, ~32 s window):
  **200000000** (200 W — effectively unconstrained)
- `constraint_1_power_limit_uw` (short_term / PL2, ~2.4 ms window):
  **61000000** (61 W)

Clamped (idempotently, from termstart) to:

- **PL1 = 20 W** (`20000000` uW)
- **PL2 = 27 W** (`27000000` uW)

Below the empirical ~30 W crash zone with a small headroom. This is
the hardware-side mitigation that should prevent the crash-#1 and
crash-#2 pkg-power threshold crossings entirely, until the actual
hardware intervention happens.

Trade-offs accepted:

- Sustained CPU-bound work will be ~30–40 % slower vs. stock. Not
  relevant for Haven's actual workload (browser + NoMachine + media).
- Short interactive bursts still allowed under the 27 W PL2 ceiling.
- NoMachine framebuffer compression and video playback might stutter
  if they need >27 W. Raise PL2 in steps if observed.
- Same total joules per task, just spread over more wall time. Net
  thermal effect roughly neutral (lower peak, longer tail).

PL2 is the actually-crash-preventing cap — PL1's 32-s averaging window
doesn't help against a 1-second burst, but PL2's 2.4-ms window does.

### 3. `ac-mode` tool (`common/bin/ac-mode`)

New Perl script for localizing the AC-events anomaly across charging
methods. The hypothesis: maybe one path (office barrel jack, office
USB-C charging, or the den AC outlet) is materially steadier than
another, in which case avoiding the bad one buys back overnight
stability.

Subcommands:

- `ac-mode <label>` — shortcut for `ac-mode mark <label>`. Run this
  before plugging in at a new location / via a new method.
- `ac-mode mark <label> [at <ISO-ts>]` — explicit form (used for
  backdating).
- `ac-mode tail [N]` — last N AC events with mode annotation.
- `ac-mode report [since]` — events/hr tally per mode, with directional
  in/out/bounce counts.
- `ac-mode modes`, `ac-mode labels` — log dump, valid-label list.

Valid labels (per user request): `office-ac`, `office-usb`, `office-both`,
`den-ac`. Extensible by editing `@LABELS` in the script.

The script groups raw journal lines by `systemd-udevd[PID]` (each
transition fires one udev invocation that runs multiple commands);
infers direction from which `powerprofilesctl` variant was called
(`set balanced` → AC IN; `set power-saver` → AC OUT; both → bounce).

tcsh tab completion added to `rc/tcshrc`:

```tcsh
complete ac-mode 'p/1/(mark tail report modes labels `ac-mode labels`)/' 'n/mark/`ac-mode labels`/'
```

### Initial data point

User moved laptop to the den ~21:43 PDT, marked `den-ac`, plugged in.
First 10 minutes in den: **zero AC events**, vs. office-ac's baseline
of ~0.75 events/hr (3 events captured in the 1 h 6 min between boot
and the move). Small-N caveat applies, but the qualitative direction
already favors "the office AC path is the flakier one" over "the
laptop's internal AC handling is the flakier one."

## What Remains Pending

The hardware-intervention list from the README is unchanged but more
urgent:

1. **AC adapter swap** — cheapest test; user has a spare. ac-mode
   monitoring should help localize whether the issue is the adapter,
   the cable, or the laptop's jack.
2. **Battery replacement** — 40.5% of design capacity. Means even with
   a perfect AC adapter, any spike that exceeds the adapter's supply
   capacity has no usable bridge.
3. **CPU/GPU repaste + cap-inspection** — case opening. User has
   flagged this as the daunting part; "hopefully this weekend" but
   no commitment.

The RAPL cap is the bandage that should let Haven survive until those
happen. If we still see crashes with PL1=20W / PL2=27W, that argues
strongly that the crash mechanism is *not* package-power threshold
crossing but something deeper (mainboard VRM aging, decoupling-cap
ESR drift, etc.) — useful information either way.

## Open Threads

- `ac-mode` data after a few days at multiple labels — does den-ac
  stay clean? Does office-usb behave differently from office-ac?
- viv-mon should now show PL2 capping in action (pkg should rarely
  cross ~27 W). If it does anyway, the kernel may be ignoring the
  RAPL clamp; need to verify.
- The boot-time burst at 17:21 might still cross PL2 transiently
  during the kernel-startup window before termstart sets the cap.
  If crash #3 happens during a boot, we'll need to set RAPL from a
  systemd unit ordered before juno-pp/TLP rather than from termstart.

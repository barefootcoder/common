# Haven: May 13 Crash + viv-mon Real-Data Fix + NoMachine Usage Profile

## Session Context

Triggered by **another silent power-off on Haven on 2026-05-13 ~18:11:30**,
this time while switching MATE workspaces *to* a workspace that had a
fullscreen video playing, with an active NoMachine session in the
background. This is a sequel to:

- `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md` (May 11)
- `summary:vivaldi-7.9-upgrade-and-haven-instability.md` (May 8/9)
- `summary:haven-fstab-uuid-and-vivaldi-guard.md` (April)
- `summary:haven-kernel-upgrade-and-gpu-fix.md` (February)

The investigation produced three concrete deliverables:

1. Discovered that `viv-mon`'s `pkg=` and `gpu=` columns have been logging
   **zeros for the entire 2-day May 11 → May 13 window** — the RAPL energy
   counters are root-only by default (PLATYPUS / CVE‑2020‑8694 mitigation)
   and `rd()` silently fell back to 0.
2. Fixed it: termstart now relaxes those perms at boot, and `viv-mon` was
   rewritten to report real package and uncore power plus new
   GPU-frequency and RC6-residency columns.
3. Captured the user's full NoMachine usage profile so a future agent can
   evaluate replacement remote-desktop tools without losing functionality.

## Crash Forensics — Same Pattern, Still Silent

### What the monitors said (and didn't)

- **journalctl `-b -1`**: nothing graphical anywhere in the boot. Last
  entries at 18:11:30 are routine UFW blocks + tailscaled chatter. Zero
  `i915`/`drm`/`hang`/`reset`/`panic`/`oops` messages the entire boot.
  No coredumps queued after reboot.
- **`/var/log/system-monitor/20260513-1810.log`** (≈45 s before death):
  load 1.35, all CPU cores at 400–1400 MHz, mem 7.6 G of 62 G, swap 1 MB,
  no i915 errors, ACPI quiet, battery charging at 10 W. **System was idle
  and cool right before the crash.**
- **`~/viv-mon.log.prev` last lines (18:11:36 → 18:11:42)**: tz=54 °C,
  battery draw 10.3 W and *decreasing*, load drifting **down** from
  1.37 → 1.16 in the last six seconds. Then writes just stop. Crash
  boundary is between 18:11:30 (last journal line) and 18:11:42 (last
  viv-mon line). New `viv-mon` (PID 3367) restarted at 18:16:05 via
  termstart.
- **Process snapshot 18:01:35** (last "less frequent" `system-monitor`
  capture, ≈10 min before crash): Vivaldi running with `--use-gl=disabled
  --disable-gpu-compositing` (so `vivaldi-guard`'s `--disable-gpu`
  injection worked); ungoogled-chromium on SwiftShader/ANGLE (software);
  `/usr/NX/bin/nxcodec.bin` running (NoMachine session live, as user
  reported).

So at crash time everything graphical was *already* on a software path,
the box was idle, and the journal had no warning. Consistent with the
documented mainboard-aging / VRM / decoupling-cap hypothesis: a kernel
hang that takes the journal with it before it can write a thing. The
"workspace switch to fullscreen video while NoMachine is capturing" path
is plausible as the triggering display-pipeline transition but is not
provable from the data we have.

### termstart verification (this session)

All four hooks from the May 11 change landed and survived this reboot:

| Hook | Expected | Observed |
|---|---|---|
| `cpupower -g powersave` | governor=powersave | ✓ confirmed via `cpupower frequency-info` and sysmon log |
| viv-mon gate-launch | one process, pidfile alive | ✓ PID 3367 started at 18:16:05, logging cleanly |
| viv-mon log rotation (`rotate_if_big`) | rotates near 50 MB | ✓ `.prev` exists at 68 MB (overshoots because check runs every 500 iter ≈ 100 s — cap is "50 MB + one 100 s window") |
| `touchpad-toggle off` | touchpads detached | ✓ both `ETPS/2 Elantech` and `ELAN0412:01` show `[floating slave]` in `xinput list` |

`vivaldi-guard`'s Haven-gated `--disable-gpu` injection: confirmed from
the running Vivaldi command line in the process snapshot.

## The viv-mon Silent-Zero Bug

### Discovery

```
/sys/class/powercap/intel-rapl:0/energy_uj       Permission denied
/sys/class/powercap/intel-rapl:0:0/energy_uj     Permission denied (core)
/sys/class/powercap/intel-rapl:0:1/energy_uj     Permission denied (uncore)
```

All energy counters are `-r-------- root` by default — PLATYPUS
mitigation (CVE‑2020‑8694, Linux 5.10+). `viv-mon`'s `rd()` uses
`cat "$1" 2>/dev/null || echo 0`, so the script faithfully logged
`pkg=0.00W gpu=0.00W` 5×/sec for two days without complaining. The
entire forensic purpose of the monitor — catching a power spike right
before a crash — has been inoperative since first launch.

Also discovered: on Raptor Lake the integrated GPU isn't its own RAPL
domain. The subdomains are `core` and `uncore`, with GPU rolled into
`uncore` alongside the system agent, memory controller, and display
engine. So the old `gpu=` label was wrong from day one — it was always
measuring `uncore`, not GPU specifically. Even with perms fixed, RAPL
can't isolate GPU power on this platform; the right metric for
GPU-lockup forensics is `gt_act_freq_mhz` + RC6 residency from
`/sys/class/drm/cardN/`, which are world-readable.

### Fix

**`local/haven/bin/termstart`** — add chmod relaxation just before the
viv-mon launch (`sudo` is already NOPASSWD on Haven):

```bash
# Open RAPL energy counters for unprivileged reads. PLATYPUS mitigation
# (CVE-2020-8694) leaves them 0400 root by default, which silently zeroed
# viv-mon's pkg= and gpu= columns for the entire May 11–13 window.
sudo chmod a+r /sys/class/powercap/intel-rapl*/energy_uj 2>/dev/null
```

**`local/haven/bin/viv-mon`** — rewritten setup + main loop:

- Pick RAPL paths by subdomain *name* (look for `name == "uncore"`)
  instead of grabbing the first `intel-rapl:0:*`.
- Probe `/sys/class/drm/card*` for `gt_cur_freq_mhz` — on Haven, the
  real i915 device is `card1` because `simpledrm` grabbed `card0`. Probe
  rather than hardcode in case it shifts.
- Add `gfreq=<cur>/<act>` and `rc6=<Δms>` columns. `gt_act_freq_mhz` is
  the hardware-reported actual frequency (0 when parked in RC6);
  `gt_cur_freq_mhz` is the requested frequency. RC6 delta in ms is
  derivable as a percentage (interval ≈ 200–260 ms).
- Rename `gpu=` → `unc=` (since that's what it really measures).
- Add `tp=on/off` column — the `tp` toggle script floats touchpads off
  the master pointer rather than disabling the kernel device, so
  "floating slave" in `xinput list` means OFF and any touchpad listed
  without that tag means ON. Polled via cached value updated every 25
  iterations (~5 s) to keep `xinput` shell-out cost negligible. Returns
  `?` if X isn't reachable (e.g. after the user logs out and back in
  and viv-mon's `DISPLAY`/`XAUTHORITY` become stale).
- Add periodic `BROWSERS` snapshot line — every 150 iterations (~30 s),
  emit a separate marker line listing distinct browser profiles
  currently running (`v:profile-basename` for Vivaldi,
  `c:profile-basename` for Chromium/Chrome). The user runs multiple
  Vivaldi and Ungoogled-Chromium instances against different
  `--user-data-dir` profiles, and which were live at crash time is
  important context. Uses `pgrep -af 'vivaldi-bin|chromium'` rather
  than scanning `ps -eww -o cmd` to avoid the snapshot's own
  `grep --user-data-dir=…` subprocess matching itself.
- Add a startup-line indicator showing whether RAPL pkg is currently
  readable, so a missing chmod is visible in the log header instead of
  silently zeroing the data.

New log line format (per-poll, 5 Hz):

```
2026-05-13T19:17:05.594 pkg=12.34W unc=0.02W gfreq=1050/0 rc6=243ms bat=8.37V/0.000A/0.00W/100%/Full tz=57 20 41 57  load=1.34 tp=off
```

Periodic marker line (every ~30 s):

```
2026-05-13T19:17:04.322 BROWSERS v:vivaldi v:vivaldi-PROFILE1 c:chromium-PROFILE2 c:chromium-PROFILE3
```

(Or `BROWSERS none` when nothing matching is up. Each token is
`<browser-code>:<basename-of-user-data-dir>`. The user runs several
distinct profiles per browser; the basenames are not meaningful to
forensics beyond "these were the live sessions at the time".)

Sample run (idle desktop right after restart):

```
RAPL pkg readable: yes
RAPL uncore path:  /sys/class/powercap/intel-rapl:0:1/energy_uj
GPU DRM dir:       /sys/class/drm/card1
```

`gfreq=300/0` interspersed with `gfreq=300/300` plus `rc6=240–251ms` per
200 ms interval = GPU parked >95 % of the time, exactly what's expected
for an idle desktop. The numbers move now.

### Field reference (for future grep/awk)

| Field | Meaning |
|---|---|
| `pkg=N.NNW` | Package power, RAPL package domain (CPU+uncore total) |
| `unc=N.NNW` | Uncore power, RAPL uncore subdomain (system agent + memory controller + display + GPU rolled together — there is no GPU-only RAPL on Raptor Lake) |
| `gfreq=C/A` | GPU frequency: `C` = requested (`gt_cur_freq_mhz`), `A` = actual (`gt_act_freq_mhz`, 0 when parked in RC6) |
| `rc6=Nms` | Milliseconds spent in RC6 (deepest GPU power-down) since last poll. Interval is ≈200–260 ms, so values near 250 = fully parked |
| `bat=V/A/W/%/state` | Battery voltage, current, power, capacity, status |
| `tz=…` | Thermal zones 0–3 in °C |
| `load=N.NN` | 1-min load average |
| `tp=on\|off\|?` | Touchpad attached to master pointer (on), detached as floating slave (off), or X11 unreachable (?). Refreshed ≈1 Hz from cached `xinput` snapshot. |
| `BROWSERS …` | Separate marker line emitted ≈every 30 s listing distinct browser profiles (`v:basename` Vivaldi, `c:basename` Chromium). Not embedded in poll lines to keep them compact. |

## NoMachine Usage Profile (Per User Request)

Captured for future remote-desktop-tool evaluation. The user is **open
to alternatives** if reasons are compelling — primary motivation being
that NoMachine's GPU-accelerated framebuffer capture is a plausible
contributor to Haven's recurring crashes.

### Deployment

- NoMachine **server** runs on Avalir and Haven; theoretically also on
  Zadash, but almost never used there.
- Always used as a **client-to-server** session from the user's primary
  seat, never headless or scripted.

### Hotkey workflow

- Per-host direct shortcuts (`Ctrl+Alt+a` for Avalir, `Ctrl+Alt+h`
  for Haven, etc.) and a paired-desktop "WORK/HOME" up/down system
  (`Ctrl+Alt+Up` / `Ctrl+Alt+Down`).
- **These hotkeys are NOT a NoMachine feature.** They're MATE dconf
  bindings that call `~/common/bin/show-desktop` (Perl); only the
  "press-the-opposite-direction-to-minimize-back" half of the dance
  uses NoMachine's own per-machine `Minimize window shortcut`
  setting. Full details + behavior matrix in
  `desktop-switching-shortcuts.md`. This matters for the xpra
  evaluation: the switcher is client-agnostic by design and would
  not need to be rebuilt from scratch.

### Session hygiene

- User attempts to kill all NoMachine connections each night before bed.
  Imperfect; sessions sometimes survive overnight.

### Display config

- **Always fullscreen** — the user works "in" one machine or another, no
  windowed mode, no flipping between local and remote windows.
- Resize-to-fit-fullscreen: enabled on both ends. The remote
  desktop's resolution matches the local window when attached.

### Input config

- Capture keyboard **and** mouse fullscreen — all keystrokes/mouse
  events go to the remote while connected.

### Clipboard

- **Frequent** cross-machine copy/paste is essential.
- Uses **both** clipboard modes:
  - `<Ctrl+C>` / `<Ctrl+V>` (X CLIPBOARD selection)
  - Select / middle-click (X PRIMARY selection)

### Audio routing

- Sound always plays on **Avalir** — it has the decent speakers.
- Sound from Haven, when in a NoMachine session: must **redirect to
  Avalir, not stay on Haven**. Local-only audio on Haven during a
  session is not desired.

### Known historical pain points (not workflow-affecting)

- NoMachine writes a very large server log buried somewhere under
  `/usr/` that blows up `timeshift` backups. The user excluded it long
  ago; the 8.x → 9.x upgrade silently renamed the logfile and the old
  exclusion stopped applying, refilling the disk until the user tracked
  it down again. Other than that incident the user describes NoMachine
  as "quite frictionless".

### Otherwise the user reports no functional complaints.

## xpra Assessment vs. This Profile

The user agreed to **try xpra** as the most likely-low-friction
swap-out candidate (subject to confirming functionality coverage). The
hypothesis being tested: NoMachine's always-on framebuffer capture
(`nxcodec.bin` polling X DAMAGE + GPU-assisted encode) interacting with
i915 power-state transitions is contributing to the crash pattern.
xpra's capture path is similar at the X11 layer but its encoder pipeline
is CPU-only by default and configurable, which would isolate this
variable.

| Requirement | xpra coverage |
|---|---|
| Server on multiple hosts | ✓ `xpra start :100` per host |
| Fullscreen / shadow-entire-screen mode | ✓ `xpra shadow ssh:host` (this is the NoMachine-like mode; xpra's default is rootless single-window forwarding, which is **not** what the user wants here) |
| Fullscreen-and-resize-to-fit | ✓ xpra auto-matches remote resolution to local window — actually one of its strengths |
| Capture keyboard + mouse fullscreen | ✓ `--keyboard-sync` + grab on fullscreen |
| Clipboard CLIPBOARD selection | ✓ `--clipboard=yes` (default) |
| Clipboard PRIMARY selection (middle-click) | ✓ supports both — `--clipboards=CLIPBOARD,PRIMARY` |
| Sound forwarding to client | ✓ `--speaker=on` (PulseAudio-based) |
| Sound *suppression* at host while session attached | ⚠ depends on PulseAudio config. xpra forwards audio via a routing module; whether Haven's local speakers play is controlled by PulseAudio default sinks, not xpra. Will need explicit setup. |
| Hotkey-driven host-switcher (`Ctrl+Alt+a` etc.) | ✓ Already client-agnostic — `~/common/bin/show-desktop` is the entry point for the existing MATE-bound hotkeys; teach it to dispatch to `xpra attach` instead of `nxplayer` (likely a per-target flag in the same script, not a rebuild). The Up/Down WORK/HOME pair would work the same. |
| "Press-the-opposite-direction-to-minimize-back" half of the dance | ⚠ Currently uses NoMachine client's per-machine `Minimize window shortcut` config in `~/.nx/config/player.cfg` (intercepts the keystroke while the fullscreen client is grabbing the keyboard). xpra doesn't have that exact mechanism — would need an equivalent (xpra's own keyboard-shortcut system, an `xdotool`/`wmctrl` watcher, or a window-manager-level binding gated on "fullscreen xpra window is focused"). Doable, not free. |
| Session survives client disconnect/reconnect | ✓ xpra detach/attach is its core feature |
| Quiet logging that doesn't blow up `timeshift` | ✓ logs go to `~/.xpra/`; exclude path is stable |

**Likely real gaps:**

- **Fullscreen video performance.** NoMachine has years of codec
  tuning for desktop streaming; xpra's x264-CPU pipeline may stutter
  more on 1080p+ video. Worth testing with the same kind of content
  that was on screen during the crash.
- **No built-in "session switcher" UI.** User scripts the hotkey
  mapping. Likely a half-day of work to make this feel as smooth as
  NoMachine's switcher.

**Likely real wins:**

- All-CPU encode path avoids touching the i915 hardware encoder /
  framebuffer-decoder routes that NoMachine uses, which is exactly the
  variable we want to isolate.
- Plain-text config (no GUI lock-in), so customization survives
  upgrades better than NoMachine's GUI-based config.
- Apt-packaged + active upstream.

**Concrete first step (not done this session):** install xpra on Avalir
and Haven, set up `xpra shadow` mode on Avalir, configure
`Ctrl+Shift+A` to launch an attach, and live with it for a couple of
days. Reserve judgment on the crash hypothesis; the real test is
whether crashes stop after sufficient uptime under xpra rather than
NoMachine.

### Recommendation: defer the swap

**Don't switch to xpra right now.** The user invited a "compelling
reasons" assessment; the reasons here are not compelling enough to
justify the cost. Reasoning:

1. **The crash data doesn't actually implicate NoMachine.** The May 13
   process snapshot at 18:01:35 (≈10 min before crash) showed Vivaldi
   on `--use-gl=disabled --disable-gpu-compositing`, ungoogled-chromium
   on SwiftShader/ANGLE, and the system idle through 18:10:56 (load
   1.35, CPUs at 400–1400 MHz, no thermal stress). NoMachine's
   `nxcodec.bin` was running, but the GPU was *not* meaningfully
   active in the seconds before the crash — `viv-mon`'s new `gfreq`
   and `rc6` columns will tell us this directly next time, but
   nothing in the existing data points specifically at NoMachine.
2. **Crashes happen without NoMachine.** The May 8 summary
   (`summary:vivaldi-7.9-upgrade-and-haven-instability.md`) established
   that the crash threshold has dropped below routine load — bare
   `termstart` invocations and Vivaldi 7.9 launches have triggered
   silent power-offs with no NoMachine involvement. Removing NoMachine
   removes one variable; it does not remove the failure mode.
3. **The real root cause is hardware.** Mainboard aging (VRMs /
   decoupling caps) plus a 40 %-of-design battery is the documented
   hypothesis (see `summary:haven-fstab-uuid-and-vivaldi-guard.md`
   and the May 8 summary). Battery replacement + CPU/GPU repaste +
   visual cap inspection has been on the open-items list for months
   and would address the actual cause. No software swap will fix
   degraded power delivery.
4. **Switching cost is non-trivial.** Server config on Avalir + Haven
   + Zadash; rewriting the `Ctrl+Shift+A`-family hotkeys to call
   `xpra attach` (and the up/down system); PulseAudio routing to keep
   "no sound on Haven during session" working; live-with-it period to
   find the new quirks. Realistic estimate: a half-day of setup plus a
   few weeks of small irritations as the user adapts. Possible
   regression on fullscreen-video smoothness.
5. **The current state is well-monitored.** With the May 13 viv-mon
   fixes (real RAPL data, GPU freq + RC6, touchpad state, browser
   profile snapshots), the next crash should produce enough signal to
   either confirm or rule out a GPU/display-pipeline trigger. Better
   to wait for one more crash with the improved telemetry before
   committing to a software swap that might not help.

**When to revisit:** if the next crash log shows `gfreq` actually
climbing and `rc6` dropping in the final seconds before the cut-off
(i.e. the GPU *was* being woken up at crash time), the
framebuffer-capture hypothesis gains weight and xpra becomes worth
trying. Until then, the hardware intervention should leapfrog this on
the priority list. The xpra path stays on the open-items roster as a
deferred software-side experiment.

## Mystery: Unidentifiable Truncated Audio

Flagged by the user (probably unrelated to crashes but worth recording):

- A truncated audio clip plays at "annoyingly irregular intervals,
  never more often than once an hour or so". Under 1 s long.
- User suspects it might be "part of a shouted word" — but it's too
  short and clipped to identify the source.
- Has been happening for **weeks to months**, roughly coinciding with
  the period during which Haven crashes got more frequent.
- User's belief (uncertain): doesn't happen with no browsers running.
- Almost certainly not causally related to the crashes — but the
  temporal coincidence is logged here in case a future agent finds the
  source and wants to correlate.

Plausible candidate sources to investigate when the sound next occurs
(if the user wants to chase it):

- Any browser tab with notification audio enabled — a closed tab
  *might* still hold a service worker that fires occasionally.
- Vivaldi/Chromium PWA notifications.
- Discord/Slack-style apps running as a web app behind a window.
- A messaging app's "new message" sound being prefix-clipped by
  PulseAudio buffer underrun on first wake from a suspended audio
  stream.
- `apt`/`unattended-upgrades` GUI notifications, especially around the
  hourly mark.

Diagnostic approach (when it next happens):

- Tail `pactl subscribe` in a terminal — every audio stream
  open/close logs there with the client name.
- `wireplumber` / `pipewire` (if installed) also expose stream
  metadata.
- A simple `pactl list short clients` snapshot during the noise window
  identifies what app currently has an output stream.
- If the user wants ongoing capture: `parec --record-stream` looped to
  a small ring buffer, then save the last few seconds on demand.

## Files Changed This Session

In repo:

- `local/haven/bin/termstart` — add `sudo chmod a+r
  /sys/class/powercap/intel-rapl*/energy_uj`
- `local/haven/bin/viv-mon` — pick RAPL subdomain by name, probe DRM
  card path, add `gfreq=` + `rc6=` columns, rename `gpu=` to `unc=`,
  add startup readability indicator
- `aidoc/projects/home-network/summary:haven-may13-vivmon-fix-and-nomachine-profile.md`
  — this doc
- `aidoc/projects/home-network/README.md` — reference to this summary;
  Current Status entry updated

## Open Items After This Session

1. **Hardware intervention on Haven** (battery / repaste / cap
   inspection) — still the most important and most-delayed next step.
   Battery at 40 % of design as of May 8.
2. **xpra as NoMachine replacement — deferred.** Assessment in this
   doc concludes the swap isn't compellingly motivated right now (no
   smoking-gun evidence implicating NoMachine, crashes happen without
   it, real root cause is hardware, switching cost is real). Revisit
   if the next crash's `viv-mon` log shows `gfreq` climbing + `rc6`
   collapsing in the final seconds — that would actually point at the
   framebuffer-capture path.
3. **Track down the mystery truncated audio** — only if the user
   wants. `pactl subscribe` running during the noise window is the
   first move.
4. **Watch for the next crash** with the now-functional viv-mon data
   — `pkg=`, `unc=`, `gfreq=`, `rc6=` columns will all be populated.
   The pre-crash log window should now actually show whether the GPU
   was spinning up (gfreq jumping from 300 → 800+ MHz, rc6 dropping to
   near zero) or whether it stayed parked.

## Conventions / Workflow Notes Carried Forward

(Unchanged from `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md`:
`/x-commit` for commits; termstart for reboot-persistence work; Perl
default for ad-hoc scripts; never use `git -C` on cwd; `tp` alias for
touchpad toggle.)

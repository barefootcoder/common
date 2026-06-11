# Haven Crash -- June 10 2026 (Video + NoMachine, hard bulk-charge on office-ac)

## Summary

Silent power-off at 14:53:07 PDT after ~6 days uptime (boot: June 4 19:12 PDT).
User context: vivaldi-media profile playing a video (not fullscreen), NoMachine
active, just plugged into office-ac. Chromium (chromium-gsheets) also running.

**This crash had three legs that stacked; remove any one and it likely doesn't
happen:**

1. **Deeply-discharged battery -> hard bulk-charge.** The battery was at **16%
   and discharging** when office-ac was plugged in at 14:26 (down from running on
   battery through the day; 40%-health pack, ~30Wh effective, drains fast). A
   near-flat battery charges at maximum current: it pulled a constant ~2.5-2.8A
   / ~21-23W the entire 26 minutes from plug-in to crash (16% -> 64%, still in
   constant-current bulk mode, no taper). That ~21W of charging load stacked on
   top of everything else.

2. **Video over NoMachine -> sustained CPU+iGPU display load.** pkg (CPU package,
   which includes the integrated GPU) ran sustained-high, peaking 27.86W (>PL2=
   27W) at 14:53:06. See "Why the GPU/CPU was loaded" below -- this is NOT the
   browser's GPU acceleration (that was disabled; see leg analysis).

3. **Flaky office-ac adapter.** The known-suspect office-ac adapter+cable
   (per the May/June ac-mode analysis: ~18 AC events/day vs ~13/day floor; the
   adapter, not the barrel jack, is the suspect path since den-ac shares the jack
   and is clean) carrying a combined draw that frequently exceeded ~40W and
   peaked near ~48W (pkg ~27W + charging ~21W).

The crash is sustained combined load exceeding what the degraded adapter / power
delivery could supply -- NOT the sub-millisecond GPU-idle->max transient that
killed it on June 4. Different mechanism, same underlying hardware fragility.

## CORRECTION to first-pass analysis

My initial write-up claimed vivaldi-media was "launched directly, bypassing
vivaldi-guard's --disable-gpu injection." **That was wrong on every point**, and
the user corrected it:

- **vivaldi-media DOES have a launcher and it WAS used.** The MATE panel launcher
  (`~/.config/mate/panel2.d/default/launchers/vivaldi-stable-1.desktop`) runs:
  `Exec=/home/buddy/common/bin/vivaldi-guard --user-data-dir=/home/buddy/.config/vivaldi-media`
  -- i.e. it routes through vivaldi-guard, which injects `--disable-gpu` on Haven.
  So GPU acceleration WAS disabled in the browser. The user never launches Vivaldi
  by hand under any circumstances.

- **The browser did NOT restart.** vivaldi-media appears in **every** viv-mon
  BROWSERS snapshot (3276 consecutive) from June 9 02:31 through the crash, with
  zero gaps. It had been running continuously since shortly after the June 4
  reboot, as the user does with all browser profiles (the laptop's primary use).
  The "07:33 launch" I cited was a **viv-mon log-rotation marker** (the log
  crossed its 50 MB cap and rotated), not a browser event. The user was asleep
  at 07:33.

The "did it restart without the right flags?" hypothesis is also ruled out by the
continuous BROWSERS presence: no restart of the main process, and a restarted
child renderer/GPU process inherits the parent's --disable-gpu anyway.

## Why the GPU/CPU was loaded despite --disable-gpu

`--disable-gpu` only stops *Vivaldi's own* GPU use. It does nothing for the
display path downstream of the browser, which is where the load actually is:

- **marco compositing is ON** (`org.mate.Marco.general compositing-manager =
  true`). With compositing enabled, every frame of the playing video forces marco
  to recomposite that screen region through the iGPU at the video's frame rate.
- **NoMachine is capturing + encoding the framebuffer.** `nxnode.bin` runs at
  **realtime priority** (confirmed in the process table: `nxexec ... --priority
  realtime`), continuously grabbing Haven's :0 framebuffer and H.264/VP8-encoding
  it to stream to the remote viewer (Avalir). That capture+encode is significant
  CPU load, at realtime priority, on top of everything.
- **Software video decode.** Because --disable-gpu forces software decode, the
  video frames are decoded on the CPU -- ironically raising pkg power vs hardware
  decode. (Hardware decode would lower CPU power but reintroduce the GPU-ramp
  transient that killed June 4. It's a genuine trade-off, not a free win.)

So the sustained pkg load = software video-decode (CPU) + marco compositing
(iGPU) + NoMachine capture/encode (CPU, realtime). viv-mon confirms real GPU
activity: `gfreq=600/600` with rc6 well below the poll interval and pkg elevated,
repeatedly through the session -- these are genuine (distinct from the 600/0
RC6-idle readout artifacts noted after June 4).

Caveat: viv-mon can't attribute GPU/CPU cycles to a specific process, so the
per-component split above is inference, not direct measurement. But the
combination (--disable-gpu confirmed in effect + marco compositing on + NoMachine
realtime capture + a continuously-updating video region) makes the display+capture
path the clear dominant consumer, and it matches the long-documented "Vivaldi +
NoMachine combo crashes Haven" pattern (April 2026 vivaldi-guard doc; May 13
crash was also a workspace switch onto fullscreen video with NoMachine active).

## Why vivaldi-guard does not prevent this class of crash

vivaldi-guard does two things on Haven: (a) blocks *launching* Vivaldi when
NoMachine is active, and (b) injects --disable-gpu. Neither helps here:

- (a) is launch-time only. Vivaldi was already running for days before this
  NoMachine session connected, so the launch block never fired.
- (b) only disables the browser's GPU use. The crash load is the compositor +
  NoMachine capture path, which --disable-gpu doesn't touch.
- **NEW blind spot found 2026-06-10:** even at launch time, (a) would NOT have
  fired for the user's actual NoMachine usage. vivaldi-guard detects NoMachine
  via `pgrep -f 'nxagent|nxplayer\.bin'`. But the user views Haven's *physical*
  desktop over NoMachine (a shadow/physical-desktop session), which runs through
  `nxnode` + the real Xorg `:0` -- **no `nxagent`** (that's only for virtual
  sessions) and **no `nxplayer.bin`** (that's the client, on Avalir, not Haven).
  Confirmed live: an active session (`nxnode -H 31`) was running with zero
  nxagent/nxplayer on Haven. So the guard's NoMachine block has never fired for
  this session type. Fix would be to also detect `nxnode.bin -H` (a served
  session) -- captured in TODO.

So the guard worked as coded but is aimed at the wrong signals for this usage.
No launcher fix is needed (my first-pass TODO to "create a vivaldi-media
launcher" was moot -- it already exists and routes through the guard).

## Applied 2026-06-10 (this session)

- **marco compositing turned OFF** (`gsettings set org.mate.Marco.general
  compositing-manager false`; persists in dconf). Removes the per-frame iGPU
  recomposite of the playing-video region -- mitigation #4 below. Effect to be
  quantified via viv-mon during a video-over-NoMachine reproducer.
- **`bulk-charge-mon` built + enhanced** -- see mitigation #2. Now has a
  persistent onset notification (stays up until taper) and a `status`
  subcommand for manual checks. Verified firing on a real plug-in: the 2026-06-10
  log shows `BULK on pct=31% charge=17.3W` (17:11) -> `BULK off pct=79%
  charge=9.2W` (18:01), with hysteresis (enter 15W / exit 10W) working cleanly.

## Evidence (viv-mon, from ~/viv-mon.log)

- **Battery before plug-in:** 14:20:00 `7.33V .../23%/Discharging`; 14:26:50
  `7.20V/2.389A/.../16%/Discharging` -- critically low, on battery.
- **office-ac plugged in ~14:26-14:27** (`ac-mode mark office-ac` at 14:26:58;
  AC udev event at 14:27:03, with `AC: Process 'powerprofilesctl set balanced'
  failed exit code 1`).
- **Hard bulk-charge through crash:** 14:50-14:53 readings show `~2.5-2.8A /
  ~21W / 60-64% / Charging` -- constant-current, no taper, from 16% up.
- **Final escalation:** 14:52:55 pkg jumps ~4W -> 18W; 14:53:00-07 sustained
  13-27.86W, load 1.09-1.80, tz peak 65C. Last entry 14:53:07.304 at 22.72W ->
  hard power-off. No journal entries 14:53:07-15:04.
- **No thermal/OOM/i915 errors** in the crash window. Temp peak 65C (elevated,
  not the killer).

## State after this crash (recovery boot, June 10 15:05)

- viv-mon running (writes `~/viv-mon.log`, prev at `~/viv-mon.log.prev`, rotates
  at 50 MB). NOT in `~/local/log/`.
- keymap-mon restarted (it dies on every crash; last pre-crash log line confirmed
  it auto-fixed the documented June 6 wipe).
- GPU freq cap 400/400 and RAPL 20W/27W re-applied by termstart.
- BROWSERS: none yet (user relaunches profiles gradually over the hours post-boot).

## Mitigations

In rough order of leverage-per-effort:

### 1. Switch office charging to office-usb (USB-C) -- recommended, low PITA
The user asked whether to stop using office-ac entirely. Don't have to go that
far: **office-usb** is the better middle path, and the data already supports it.
- It bypasses the suspect office-ac adapter+cable entirely (USB-C PD path; the
  barrel jack is shared with the clean den-ac, so the jack isn't the suspect).
- USB-C PD typically caps at lower wattage, which directly limits the bulk-charge
  current spike that was leg #1 of this crash.
So office-usb is doubly good: avoids the suspect adapter AND lowers peak combined
draw. Much less of a PITA than not charging at all.

### 2. Don't let the battery run to ~16% before plugging in
The hard bulk-charge of a near-flat 40%-health battery was the swing factor: it
added ~21W exactly when video+NoMachine was already loading the system. If the
pack is kept topped up (plug in earlier / keep it plugged), charging stays in
trickle/taper and the combined-draw spike never forms -- regardless of adapter.
This is a behavior change, not a code change.

**Built 2026-06-10 to support this: `bulk-charge-mon`** (`local/haven/bin/`,
launched from termstart, pidfile-guarded like viv-mon). Since "keep it topped
up" is hard to do reliably by hand, this watcher fires a desktop notification
when bulk-charging starts (charge power >= 15 W on BAT0) so the user can hold
off on video-over-NoMachine until it tapers, and an all-clear when it does. Log
at `~/local/log/bulk-charge-mon.log`. See the README "Tools and Scripts" entry.

### 3. Configure TLP to enforce the GPU freq cap on AC events (durable cap)
Still valid and worth doing -- termstart's 400/400 cap is volatile across
mid-session AC plug/unplug, but TLP applies on every AC event. In
`/etc/tlp.d/juno-tlp.conf`, uncomment/set:
```
INTEL_GPU_MAX_FREQ_ON_AC=400
INTEL_GPU_BOOST_FREQ_ON_AC=400
INTEL_GPU_MAX_FREQ_ON_BAT=400
INTEL_GPU_BOOST_FREQ_ON_BAT=400
```
Verify with `tlp-stat -g`. (This caps the iGPU regardless of what drives it --
browser, compositor, or nxagent -- so it helps this class too, not just June 4's.)

### 4. Reduce the GPU work marco + NoMachine generate (the "disable GPU for them" ask)
Important framing: the `gt_max_freq_mhz=400` cap is **global to the iGPU**, not
per-process. So marco and NoMachine are ALREADY capped at 400 MHz -- there is no
per-process GPU cap in Linux. What's left is reducing how much GPU work they
*generate*. Two concrete "disable GPU"-style knobs exist:

- **marco compositing OFF** (`gsettings set org.mate.Marco.general
  compositing-manager false`; currently `true`). Removes the per-frame iGPU
  recomposite of the playing-video region. Clean net GPU reduction, low visual
  cost over NoMachine (loses shadows/transparency/smooth fades), no root, fully
  reversible. Best single lever; recommend trying + measuring.
- **NoMachine `EnableEGLCapture 0`** in `/usr/NX/etc/node.cfg` (currently `1`).
  Disables GPU-accelerated (EGL/OpenGL) framebuffer capture, falling back to
  software/X11 capture. CAVEAT: this *shifts* capture load from iGPU to CPU, and
  the crash was pkg power (CPU+iGPU combined), so it may not reduce total pkg --
  could even raise it. Measure before committing. Pairs better with a frame-rate
  / quality reduction (fewer captures+encodes per second = net reduction of both
  CPU and GPU), which is the better NoMachine lever than the EGL toggle alone.

**MEASURED 2026-06-10** (compositing off applied, then a controlled sweep: 45s
off / 45s on / back off, same video over NoMachine, viv-mon as the instrument
since intel_gpu_top isn't installed):

| state           | pkg mean | GPU idle (rc6) | gfreq cur>300 | act>=600 |
|-----------------|----------|----------------|---------------|----------|
| compositing OFF | 10.63 W  | 221 ms (~85%)  | 0%            | 0%       |
| compositing ON  | 10.56 W  | 196 ms (~75%)  | 15%           | 0%       |

Findings: compositing-off is a real but MODEST GPU win -- GPU idle up ~10 pts,
GPU clock-up requests 15% -> 0% (helps the GPU-transient crash mode, and it's
free) -- but **pkg power is unchanged** (10.63 vs 10.56 W is noise). Package
power, the variable that crossed the limit in this crash, is CPU-dominated
during video-over-NoMachine (software decode forced by --disable-gpu + NoMachine
capture/encode); the GPU was 75-85% idle throughout and never the bottleneck.
So: **keep compositing off** (free GPU-clock-up trim, no power cost), but it is
NOT a lever against the sustained-power crash mode.

Corollary -- the `EnableEGLCapture 0` idea is RULED OUT: capture currently runs
on a mostly-idle GPU; moving it to the already-loaded CPU would raise pkg. The
only NoMachine lever that would actually cut pkg is a **frame-rate / quality
cap** (fewer captures+encodes per second). Not yet tried.

- Last-resort: avoid playing video over NoMachine on Haven entirely (the
  documented hazard since April 2026), but that's the laptop's primary use.

### 5. The real fix: hardware intervention
Battery replacement (the 40%-health pack is the root of leg #1) + repaste + cap
inspection, plus replacing the office-ac adapter. Now higher priority per the
user. Tracked at 2026-08-03 re-check (gated on acquiring the replacement battery).

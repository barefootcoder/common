# Avalir Trackball Lag -- Intermittent Freeze-then-Jump (June 2026)

**Status: diagnosis confirmed at the layer level; root cause (which interferer)
not yet identified; no fix verified. Passive monitor deployed, awaiting the
next episode.**

## Symptom

Avalir's pointer intermittently freezes: the user moves the trackball, nothing
happens; moves again, nothing; moves a third time, then the pointer leaps
"halfway across the screen." Recent onset (started ~early June 2026), and
intermittent -- happens some days/sessions and not others (e.g. absent the
whole of June 11 after being active June 10). The user first described it as a
"Bluetooth mouse"; that was wrong (see below).

## The hardware (don't trust the "Bluetooth" framing)

- Device: Logitech **MX Ergo** trackball, USB id `046d:406f`.
- Link: Logitech **Unifying Receiver**, USB id `046d:c52b` -- a proprietary
  **2.4GHz** radio, NOT Bluetooth. (The "USB receiver you re-pair to swap which
  mouse it serves" is the Unifying model. The MX Ergo *can* also run over
  Bluetooth via Easy-Switch, but here it's on the Unifying receiver.)
- evdev node: `/dev/input/event6` (name "Logitech MX Ergo"). Readable by the
  `buddy` user (group `input`), so no root needed to watch it.
- Receiver enumerates at 12Mbit/s (full speed) on a USB 2.0 root hub (Bus 01,
  port 3). Not directly on a SuperSpeed bus.

## Confirmed diagnosis: the 2.4GHz link, not the host

The fault is on the **wireless link between trackball and receiver** -- the one
layer Linux can't see, because the receiver presents a stable USB HID endpoint
and handles the radio internally. When packets drop over the air, the device
firmware BUFFERS the motion and the receiver flushes the accumulated delta in
one report once a packet gets through -- which is exactly the visible "jump."

Evidence captured during a live episode (June 10, while the user was actively
moving the ball and it was lagging):

- **solaar reported the device "offline" 3x over 6s** during the lag. (A merely
  idle-asleep device reads offline too, but the user was actively moving it, so
  this is a genuine link drop. Re-probed later while behaving: online 5/5,
  HID++ 4.5, battery steady.)
- **Kernel logged zero USB/HID events** for the receiver across the whole
  186-day uptime and during the episode window (only UFW firewall noise). A USB
  transport fault always logs; silence places the fault above USB.
- **Receiver never autosuspended**: `runtime_suspended_time` flat at ~81.6s
  total over 186 days, status `active` throughout.

### Ruled out

| Suspect | Verdict | Why |
|---|---|---|
| USB autosuspend | out | ~81s suspend in 186 days; symptom is mid-active-use, when autosuspend isn't engaged. (TLP has `USB_AUTOSUSPEND=1`, receiver not in denylist, but it barely ever fires.) |
| USB disconnect / cable / port | out | those always log to the kernel; nothing logged in 186 days |
| Recent software/kernel/TLP change | out | uptime 186 days (booted 2025-12-05, no reboot); TLP config untouched since 2023 |
| Low / dying battery | out | solaar reads 90% discharging normally a day after a full charge; healthy curve |
| Host 2.4GHz radios (this PC) | mostly cleared | Avalir's WiFi is OFF (wired via eno1); Bluetooth was powered but had zero connections / not discovering |

## Why "recent onset" + "intermittent by day" matters

Placement hasn't changed, so relocation can't be the *cause* (only a margin-
restoring *fix*). A sudden onset on an unchanged, likely-marginal link plus
day-to-day variability points at an **intermittent external 2.4GHz interferer**
rather than static misconfig or hardware degradation (which would worsen
monotonically). What changed in the RF environment ~early June is the open
question. The user's own candidate: Haven's trackball (another 2.4GHz Logitech
device, same room, usually powered but not in use) -- weak as a *new* variable
since its presence isn't new, but cheap to test (power switch on the base).

## Actions taken (2026-06-11)

- **Bluetooth radio soft-blocked** (`sudo rfkill block bluetooth`) as a free
  elimination (user doesn't use BT). Low expected yield since it was already
  near-silent, but removes a variable. Reverse with `sudo rfkill unblock
  bluetooth`. Avalir rarely reboots, so the soft-block effectively persists.
- **Deployed `~/oneoff/trackball-mon`** (Perl, core modules only): event-driven
  evdev watcher that logs the jump signature (large |dx|+|dy| after a motion
  silence gap), samples solaar link state when a jump fires (rate-limited), and
  logs the input node going absent/present (logitech-hidpp drops the device on
  a link loss). Log: `~/local/log/trackball-mon.log` (host-local, non-syncing).
  Started detached; thresholds tunable via `TBMON_GAP`/`TBMON_JUMP`, and
  `TBMON_DEBUG=1` logs sub-threshold post-gap reports for calibration. Draft in
  `~/oneoff` per the one-off-scripts convention; promote to `local/avalir/bin/`
  + termstart (pidfile-gated, like viv-mon) if it proves its worth.

## Next steps / open threads

1. **Read `trackball-mon.log` after the next episode.** Confirm the jump
   signature (gap + oversized delta) and whether solaar shows `offline` / the
   node goes `absent` at that instant. Tune thresholds if it misses or
   false-positives.
2. **Haven-mouse test** (user): power off Haven's trackball at the base switch
   for a day; see if Avalir's lag stops. Zero cost.
3. **Bluetooth-disabled experiment**: if the lag doesn't recur for a good while,
   BT can't be cleanly credited (it was near-silent) but note it. If it does
   recur with BT off, BT is exonerated -- consider re-enabling.
4. **Characterize the 2.4GHz neighborhood** (optional, needs briefly enabling
   the deliberately-off WiFi radio): `iw dev wlp3s0 scan` to enumerate nearby
   APs/channels/signal. Won't see non-WiFi interferers (BT, microwave, other
   Logitech), but shows band congestion.
5. **Fallback fixes if it's confirmed RF-on-a-marginal-link**: USB extension
   cable to bring the receiver into line-of-sight near the ball; try a spare
   Unifying receiver (re-pair via solaar -- user may have an older one lying
   around but doesn't want to cannibalize an in-use one); or move the MX Ergo to
   Bluetooth via Easy-Switch as an A/B (different radio stack, same band).

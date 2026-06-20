# Avalir Trackball Lag -- Intermittent Freeze-then-Jump (June 2026)

**Status: diagnosis confirmed at the layer level; root cause (which interferer)
not yet identified; no fix verified. Monitor deployed 2026-06-11 and PROVEN --
caught its first full episode 2026-06-17 (see "Episode: 2026-06-17" below).
Bluetooth and Avalir's own WiFi are both now exonerated. The Haven-mouse test is
now running long-term as a permanent physical-separation test (M570 moved to the
den, 3-4 rooms from Haven, 2026-06-17) but carries a LOW prior -- it coexisted
with months of no-jumping before the ~6/10 onset (see "Next steps" #2). Leading
open hypotheses: an external 2.4GHz emitter, or the Avalir link hardware degrading.
First readout 2026-06-18 was clean but inconclusive (base rate too low); re-check
~2026-07-02.**

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
| Host WiFi (this PC) | out | `wlp3s0` radio off / disconnected (wired via eno1); reconfirmed off during the 2026-06-17 episode |
| Host Bluetooth (this PC) | out | **exonerated 2026-06-17** -- the lag recurred while BT was still soft-blocked (since 2026-06-11), so BT cannot be the interferer |
| `powertop --auto-tune` udev storm | out (symptom, not cause) | a 2023 Juno vendor rule (`juno-powertop.rules`) fires `powertop --auto-tune` on every `power_supply` event, and the trackball's `hidpp_battery_0` is a power_supply device -- so each link flap triggers it (dozens of times per episode). But the rule predates onset by years, and the companion `powertop-usb-mouse` helper keeps the receiver's `power/control` at `on` (verified), so it never actually suspends the link. Useful as a secondary episode marker, nothing more. |

## Why "recent onset" + "intermittent by day" matters

Placement hasn't changed, so relocation can't be the *cause* (only a margin-
restoring *fix*). A sudden onset on an unchanged, likely-marginal link plus
day-to-day variability points at an **intermittent external 2.4GHz interferer**
rather than static misconfig or hardware degradation (which would worsen
monotonically). What changed in the RF environment ~early June is the open
question. The user's own candidate: Haven's trackball (another 2.4GHz Logitech
device, same room, usually powered but not in use) -- weak as a *new* variable
since its presence isn't new, but cheap to test (power switch on the base).

**Narrowing from the user (2026-06-17):** nothing changed on Avalir's side
~Jun 9-10, and the Haven-trackball arrangement is NOT new -- Haven and its mouse
have been brought into this room for *months or years*. So neither an Avalir-side
change nor a new Haven habit can be the trigger. That leaves two live
possibilities for a real early-June onset: (1) an **external** RF source outside
the user's gear (a neighbor's device, a newly-installed appliance, anything that
appeared in the band ~Jun 9-10), or (2) the **Avalir link hardware itself
degrading intermittently** -- which would dent the "would worsen monotonically"
argument above, but intermittent/marginal RF hardware faults are real and don't
have to ramp smoothly. The Haven-mouse test still earns its keep despite the low
prior: a long-tolerated emitter can cross from harmless to harmful once the link
goes marginal, so confirming or clearing it is worth the zero cost.

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

## Episode: 2026-06-17 (first full monitor capture)

The user reported the stutter live; `trackball-mon` (pid 164896, up since the
2026-06-11 deploy) had been quietly waiting and caught it. First fully
timestamped capture. (Note for future readers: the monitor is a Perl script, so
its process `comm` is `perl` -- find it with `pgrep -af trackball-mon`, NOT bare
`pgrep trackball-mon`, which matches on `comm` and finds nothing.)

Timeline from `~/local/log/trackball-mon.log`:

```
15:24:08  JUMP gap=0.48s dx=116 dy=-88 mag=204   LINK offline (device is offline)
15:27:28  JUMP gap=0.68s dx=103 dy=-82 mag=185   LINK online 4s later, battery 90%
15:28:12  JUMP gap=0.71s dx=-179 dy=-7 mag=186   LINK online, battery 90%
~15:29:30 user: "mostly stopped"; a few minor jumps trickling after
```

The `offline` read coincident with the 15:24:08 jump is the **same signature as
June 10** -- the link drops, motion buffers, flushes as the leap. Reconfirmed.

What this episode established:

- **Bluetooth exonerated.** It recurred with BT still soft-blocked (`rfkill list
  bluetooth` = `Soft blocked: yes`, in place since 2026-06-11). So BT is not the
  interferer, and the soft-block is no longer doing anything useful -- safe to
  `sudo rfkill unblock bluetooth` (and drop the BT entry from the README
  "Deliberately disabled" section once re-enabled).
- **Local WiFi exonerated.** `wlp3s0` confirmed off/disconnected during the
  episode (Avalir is wired on `eno1`).
- **The `powertop` udev storm is a symptom, not the cause** (see the ruled-out
  table). Worth knowing because the journal's `powertop --auto-tune ... failed`
  lines are a *free* secondary episode marker that predates the monitor.

Attempt to date onset from that free marker (powertop failures/day across the
full journal back to Mar 7): inconclusive, because routine HID++ battery polling
keeps a steady ~7-15/day baseline the whole time (so the udev rule firing is not
new). BUT the two highest days in three months are **Jun 9 = 84 and Jun 10 =
80** (next-highest any day: 45), squarely in the documented onset window. Weak
corroboration of an early-June intensification, not proof.

## Next steps / open threads

1. ~~**Read `trackball-mon.log` after the next episode.**~~ DONE 2026-06-17 (above);
   signature confirmed, default thresholds (gap=0.3s / jump=150) caught it cleanly,
   no tuning needed yet.
2. **Haven-mouse test -- ONGOING, upgraded to permanent physical separation
   (2026-06-18).** First readout (2026-06-18, ~27h after the M570 went off
   2026-06-17 ~15:30): zero JUMP episodes, monitor confirmed alive throughout --
   but INCONCLUSIVE, because the baseline is only ~1 episode per ~6 days (the
   monitor ran Jun 11->17 with nothing before the first cluster), so one clean day
   is what an unchanged setup would show too. The 02:50 reminder fired + was
   dismissed 04:53 as designed. The user has now returned to the pre-investigation
   arrangement: Haven's M570 lives **permanently in the den, 3-4 rooms from Haven**
   (full physical separation, not just a power-off at the base switch), and no
   longer travels with Haven -- so the bedtime reminder is **retired** (obsolete:
   there is no overnight re-enable left to catch; the one-shot already fired and
   finished, not re-armed). Zero cost, because the M570 was only ever brought into
   the office to let the user keep Haven's *touchpad* disabled (an old crash
   suspect, since superseded by the AC-adapter theory). **Timeline confound
   (sharpens the already-low prior):** the user was bringing the M570 into the
   office *well before* the ~6/10 onset, so its presence demonstrably coexisted
   with months of no-jumping -- it survives as a suspect only in the weak
   "long-tolerated emitter turns harmful once the link goes marginal" form.
   Re-check after a multi-day clean stretch (dated 2026-07-02 TODO); the read is
   just `~/local/log/trackball-mon.log` JUMP lines after 2026-06-17 15:30, plus a
   `pgrep -af trackball-mon` liveness check. Log of the (now finished) reminder:
   `~/local/log/trackball-test-reminder.log`.
3. ~~**Bluetooth-disabled experiment.**~~ RESOLVED 2026-06-17: lag recurred with BT
   off, so BT is exonerated; `sudo rfkill unblock bluetooth` run, README updated.
4. **Characterize the 2.4GHz neighborhood** (optional; WiFi radio is off, would
   need briefly enabling it): `iw dev wlp3s0 scan` to enumerate nearby
   APs/channels/signal. Won't see non-WiFi interferers (BT, microwave, other
   Logitech), but shows band congestion. More attractive now that an external RF
   source is one of only two live root-cause hypotheses.
5. **Fallback fixes if it's confirmed RF-on-a-marginal-link**: USB extension
   cable to bring the receiver into line-of-sight near the ball; try a spare
   Unifying receiver (re-pair via solaar -- user may have an older one lying
   around but doesn't want to cannibalize an in-use one); or move the MX Ergo to
   Bluetooth via Easy-Switch as an A/B (different radio stack, same band).

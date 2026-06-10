# Keypad-Colon Mapping Investigation (Haven)

**Status:** OPEN as of 2026-06-01. The keycode mystery is solved; the *revert
trigger* is not. **Avalir is no longer the stable counter-example** — after 178
days of stability its kc91 also reverted (sometime in the last few days; exact
timing not yet captured because the Avalir watcher only came up 2026-06-01).
Watchers are now running on **both** machines to catch the next wipe in rich
context.

---

## ⚠️ If you are reading this right after a Haven crash

The Haven watcher is a detached process — it **dies on every Haven crash/reboot**
(the box otherwise stays up indefinitely). The log file survives; the process does
not. **Avalir's watcher is independent** and is unaffected by a Haven crash. To
resume the Haven hunt:

```bash
# 1. See anything it caught before the crash (esp. the last CHANGE line):
cat /var/tmp/keymap-mon.log

# 2. Restart it (must run with access to :0):
DISPLAY=:0 setsid ~/local/bin/keymap-mon </dev/null >/dev/null 2>&1 &
```

A revert that happens *during* the dead-watcher window (boot/startup) is a prime
suspect, so restart it as early as possible.

---

## Verified facts (don't re-derive these)

- **Haven's keypad-`.` emits keycode 91** (`<KPDL>`, the *standard* code) — NOT
  129, despite the April 2026 commit and an old memory note that claimed `<KPPT>`
  / `<I129>`. Proven by `xinput test-xi2 --root` capture of the physical key:
  four presses → four `91`s, zero `129`s. **The `keycode 129` line in
  `rc/Xmodmap` is dead code for this key.** The line that actually does the work
  is the `keycode 91` one — identical to Avalir.
- **kc91 is KEYPAD type, and on this box the type is reduced** to just
  `map[NumLock] = Level2` — meaning **Shift selects nothing; only NumLock picks
  the level.** This is the source of all the confusing behavior.
- Behavior matrix, with the working mapping `keycode 91 = colon KP_Decimal KP_Decimal colon`:

  | NumLock | keypad-`.` | Shift+keypad-`.` |
  |---|---|---|
  | **ON** (normal) | `.` | `:` |
  | **OFF** | `:` | `:` |

- **"Broken" = kc91 reverted to its default** (`KP_Delete KP_Decimal KP_Delete
  KP_Decimal`). With NumLock on: plain = `.`, Shift = `KP_Delete` →
  Del-with-nothing-to-delete → `<BEL>`. That beep is the tell, and it matches the
  reported symptom exactly.

## The two distinct problems

1. **Revert trigger — UNKNOWN.** Something reverts kc91's colon mapping to default
   on both machines now (Avalir's symmetry broke around late May 2026 after 178
   days of stability). Haven's first watcher-captured wipe is 2026-05-28 02:17:47
   — see "What the watchers have caught" below for the captured context and the
   two-trigger picture that emerged from it. (When found: the original
   `termstart`-loads-`~/.Xmodmap` fix only covers *boot-time* application, so a
   mid-session reverter still needs handling — e.g. re-apply on the trigger, or
   move the mapping into XKB so it survives a recompile.)
2. **NumLock fragility.** Because Shift is inert on this key type, keypad-`.`
   behavior is hostage to NumLock state — when NumLock silently flips off, you get
   `:` always and *can't type a decimal point*. Durable fix: make kc91 genuinely
   `TWO_LEVEL` (an XKB-level change, not `xmodmap`), so Shift chooses the level and
   NumLock becomes irrelevant. **Decision still open** — not yet chosen whether/when
   to do this.

Notes for whenever the `TWO_LEVEL` fix is taken up: it's an XKB-rules-level edit
(`xmodmap` can't set a key's type). Two-birds possibility — **if the revert trigger
turns out to be a keymap *recompile*** (`setxkbmap`/`xkbcomp`), fixing it at the
XKB-rules level would likely survive that recompile and solve problem (1) as well.
Suggested sequencing: let the watcher reveal the trigger first, then implement with
the user at the keyboard to test (press `.` and Shift+`.` under both NumLock states).

## What the watchers have caught

**Haven, 2026-06-04 16:49:21** (second capture; crash killed the watcher 11 min later):

```
CHANGE kc91:[colon KP_Decimal KP_Decimal colon]->[KP_Delete KP_Decimal KP_Delete KP_Decimal]
       numlock:[on/00000002]->[on/00000002]
  kc129(ref): KP_Decimal KP_Decimal KP_Decimal KP_Decimal       <-- kc129 state not shown, journal was:
  journal-tail:
    bluetoothd: btd_service_connect() a2dp-sink profile connect failed for 7C:96:D2:6B:6D:71: Device or resource busy
    kernel: input: ECOXGEAR (AVRCP) as /devices/virtual/input/input48
    systemd-logind: Watching system buttons on /dev/input/event16 (ECOXGEAR (AVRCP))
    bluetoothd: /org/bluez/hci0/.../fd5: fd(41) ready
  active-window: Is Britain Headed For DICTATORSHIP? - YouTube - Vivaldi
```

**CONFIRMED: this IS mechanism #2, and the ECOXGEAR Bluetooth speaker is its
trigger.** Xorg.0.log.old (the May 22 boot's log) shows that **every** ECOXGEAR
connect follows the same sequence: udev tags the speaker's AVRCP profile (its
media buttons) as a *keyboard*; X adds `ECOXGEAR (AVRCP)` as an extended input
device of type KEYBOARD; and the add applies `Option "xkb_model" "pc105"` /
`"xkb_layout" "us"` -- the exact mechanism-#2 recompile signature.  Four such
adds appear in the log, and the timestamp arithmetic maps the earlier ones onto
**May 23 (Sat), May 24 (Sun), May 30 (Sat)** -- matching the user's
once-a-week (Saturday) speaker habit exactly.  June 4 was an unusual midweek
connect, and keymap-mon caught the resulting wipe live at 16:49:21.

Implications:

- **Mechanism #2 is solved**: BT-speaker connect → AVRCP "keyboard" hotplug →
  XKB recompile from rules → xmodmap layer wiped.  It's Haven-specific because
  only Haven gets the speaker.  Any future BT device presenting media keys
  would do the same.
- **We now have an on-demand reproducer**: connect the ECOXGEAR and watch
  keymap-mon.  Fix-test cycles drop from weeks to minutes.
- **Mechanism #1 (the silent wipe -- May 28 Haven, and Avalir's) remains
  unsolved** and is NOT this: the May 28 event had no BT activity, no Xorg
  lines, and Avalir's 178-day-uptime Xorg log has no pc105 lines at all.

### Fix plan (now concrete)

1. **Durable fix -- the TWO_LEVEL/XKB change** (already sketched above): move
   kc91's colon mapping into the XKB-rules layer that mate-settings-daemon
   reapplies automatically after every recompile (the same self-healing layer
   that makes `compose:caps` survive every wipe).  Fixes NumLock fragility AND
   immunizes against both mechanisms.  Test with the reproducer: apply, connect
   speaker, verify kc91 survives.
2. **Quick band-aid (optional, also covers mechanism #1 and Avalir)**: teach
   `keymap-mon` to re-run `xmodmap ~/.Xmodmap` whenever it detects a CHANGE,
   in addition to logging it.  Self-heals within its poll interval.  Doesn't
   fix NumLock fragility; purely a stopgap until (1).
3. **Source-level option (mechanism #2 only, probably unnecessary)**: a udev
   rule / libinput quirk to ignore the ECOXGEAR AVRCP input device entirely.
   Would cost the speaker's play/pause buttons and does nothing for
   mechanism #1.

**Status (2026-06-09): band-aid (2) shipped and now PROVEN; durable fix (1)
deferred by user decision.**  keymap-mon's self-heal caught its first
in-the-wild wipe on 2026-06-06 15:22:55 (kc91 colon -> KP_Delete) and reapplied
it ~1s later (15:22:56); the user confirms using the ECOXGEAR since with no
noticeable colon breakage.  The stopgap holds, so we are NOT doing the
TWO_LEVEL fix yet -- wait for the wipe to recur *despite* the stopgap, or for
NumLock fragility to actually bite, before more XKB surgery.  Two refinements
for whenever (1) is taken up:

- **Prefer `~/.config/xkb/` over editing `/usr/share/X11/xkb/`** -- the per-user
  XKB config dir is upgrade-safe and root-free.  First verify Haven's Xorg
  server honors it for the *physical* keyboard (solid in libxkbcommon, spottier
  in classic Xorg); only fall back to the system dir (plus a documented
  reinstall-after-upgrade note) if it doesn't.
- **Prove survival with the reproducer; don't assume it.**  Apply the mapping,
  test the four NumLock x Shift combos at the keyboard, then connect the
  ECOXGEAR and confirm keymap-mon logs NO `CHANGE` for kc91 (it rode the
  recompile).  Keep keymap-mon running as a backstop even afterward -- defense
  in depth is free.

**Haven, 2026-05-28 02:17:47** (the first capture):

```
CHANGE kc91:[colon KP_Decimal KP_Decimal colon]->[KP_Delete KP_Decimal KP_Delete KP_Decimal]
       numlock:[on/00000002]->[on/00000002]
  kc129(ref): KP_Decimal KP_Decimal KP_Decimal KP_Decimal       <-- ALSO wiped, same instant
  active-window: Avalir - NoMachine
  (journal 25s around the event: only network noise — no setxkbmap, no xkbcomp)
```

So **both** customized keycodes wiped to default at the same instant, with no
`setxkbmap`/`xkbcomp` activity in the entire journal (10 days of it). That's the
signature of a programmatic X-protocol call (likely `XkbSetMap` style) rather than
a shell-invoked tool. NumLock didn't change. The user was viewing Avalir via
NoMachine on Haven at the moment.

**Two distinct trigger mechanisms exist:**

1. The silent one above -- **no Xorg log entry**, no journal hit. This is what's
   currently affecting both machines.
2. A separate, *visible* mechanism — Xorg's log shows occasional
   `Option "xkb_model" "pc105"` / `"xkb_layout" "us"` lines (with
   `(WW) Option "xkb_variant" requires a string value` warnings about empty
   strings), indicating an `XkbGetKbdByName`-style recompile from rules.
   Haven gets these sporadically (e.g. **May 23 ×3, May 24, May 30** since the May
   22 boot). **Avalir's Xorg log shows NONE** in its full 178-day uptime. So
   mechanism #2 is Haven-specific — but it's *not* what bit Avalir.
   **IDENTIFIED 2026-06-04: the trigger is the ECOXGEAR Bluetooth speaker
   connecting** (its AVRCP media buttons enumerate as a "keyboard"; the
   device-add recompiles the keymap). See the June 4 capture below for the
   evidence and the now-concrete fix plan.

## Why compose survives the wipes but `xmodmap` doesn't

User observation (2026-06-01): `compose:caps` still works on both boxes even
while kc91 is wiped. Verified — `setxkbmap -query` on both shows
`options: altwin:left_meta_win,compose:caps` active, and Multi_key is bound to
keycode 66 (CapsLock). The two settings live in different layers:

- **`compose:caps` and the other layout options** live in **dconf**
  (`/org/mate/desktop/peripherals/keyboard/kbd/options`) and are managed by
  **mate-settings-daemon's keyboard plugin**, which watches XKB state and
  reapplies the dconf-stored options on any keymap change. If a wipe blows them
  away, msd restores them within milliseconds — too fast to observe.
- **`xmodmap` keysym customizations** (kc91, the dead kc129 line) live **only in
  the X server's runtime keysym table**. Nothing watches them; nothing restores
  them. When the wipe hits, they're gone and stay gone.

**Big corollary for the fix:** moving the colon mapping into the **XKB-rules
layer** (the `TWO_LEVEL` change in problem 2) would put it on the same
self-healing layer as `compose:caps` — msd's automatic reapply would carry it
through every wipe. So `TWO_LEVEL` is a stronger "two-birds" fix than originally
framed: it solves the NumLock fragility *and* immunizes against the silent
wipes, because the wipes' mechanism is "recompile from rules" and an
XKB-rules-level mapping lives in those rules.

## Ruled out (with evidence)

- **NoMachine** xkbcomp-on-connect: Avalir took the same `physical-shadow`
  connections constantly for months and didn't break; a live disconnect/reconnect
  into Haven did **not** reset kc129/kc91. (Avalir eventually broke anyway —
  but not via NoMachine connect.)
- **AccessX / MouseKeys / StickyKeys / SlowKeys / BounceKeys**: dconf on both
  machines shows all of these `enable=false` (`/org/mate/desktop/accessibility/keyboard/`).
  Not a contributor. (Earlier MouseKeys speculation was wrong.)
- **Screen lock/unlock** (user never locks), **suspend/resume** (none since the
  May 22 Haven boot, none since the Dec 5 Avalir boot), **daystart** (defunct
  since 2020).
- **The keycode-129 assumption** — the original red herring that derailed the
  whole first pass.

## Already shipped

- `termstart-common` in `bin/bash_funcs` loads `~/.Xmodmap` at session start
  (commit `75cea2a`). Correct for boot-time application; does nothing for a
  mid-session revert.
- **Self-heal stopgap (2026-06-04), both machines**: `keymap-mon` now
  reapplies `xmodmap ~/.Xmodmap` whenever it detects kc91 losing the colon
  mapping, logging a `REAPPLY` line after the forensic `CHANGE` snapshot
  (trigger-hunting for mechanism #1 is unimpaired). Broken window is now
  ~5s (the poll interval) on both boxes, for BOTH wipe mechanisms. **Live test
  PASSED 2026-06-06**: a real wipe at 15:22:55 (kc91 colon -> KP_Delete) was
  reapplied one second later at 15:22:56, and the user reports normal ECOXGEAR
  use since with no noticeable colon breakage. Does not address the NumLock
  fragility -- that still needs the TWO_LEVEL fix.

## The watchers

Both machines now instrumented:
- **Haven** `~/local/bin/keymap-mon` (= `local/haven/bin/keymap-mon`) — deployed
  2026-05-26, polling since then; caught the 2026-05-28 02:17:47 event.
- **Avalir** `~/local/bin/keymap-mon` (= `local/avalir/bin/keymap-mon`) — deployed
  2026-06-01 (after Avalir's first observed wipe — exact timing missed).

Each polls keycode 91 + NumLock every 5s and logs every transition with a context
snapshot (NoMachine session list, journal tail, active window) to the local
`/var/tmp/keymap-mon.log`. The two are independent — a Haven crash kills only
Haven's watcher; Avalir's persists. Throwaway tools — delete them and this doc
once the trigger is identified.

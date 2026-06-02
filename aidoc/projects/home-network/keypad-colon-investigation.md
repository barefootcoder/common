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

1. The silent one above — **no Xorg log entry**, no journal hit. This is what's
   currently affecting both machines.
2. A separate, *visible* mechanism — Xorg's log shows occasional
   `Option "xkb_model" "pc105"` / `"xkb_layout" "us"` lines (with
   `(WW) Option "xkb_variant" requires a string value` warnings about empty
   strings), indicating an `XkbGetKbdByName`-style recompile from rules.
   Haven gets these sporadically (e.g. **May 23 ×3, May 24, May 30** since the May
   22 boot). **Avalir's Xorg log shows NONE** in its full 178-day uptime. So
   mechanism #2 is Haven-specific (CLEVO module? a Haven-only X client?) — but
   it's *not* what bit Avalir.

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

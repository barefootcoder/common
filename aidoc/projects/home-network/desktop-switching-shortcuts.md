# Desktop Switching Shortcuts

A small, interlocking set of MATE keyboard shortcuts that "switch" between paired
desktops by driving NoMachine connections. The shortcuts are bound identically on
every machine in a pair, so the *same* keystroke does the right thing regardless
of which machine the user is currently sitting at.

This document describes the **observable behavior** plus the implementation
hooks, so future work on bugs or extensions has a stable starting point.

## Paired Desktops

Two pairs exist today, configured in the `$WORK_DESKTOP` / `$HOME_DESKTOP`
hashes inside `~/common/bin/show-desktop`:

| "Home" machine | "Work" machine |
| -------------- | -------------- |
| Haven (laptop) | Avalir (desktop) |
| Zadash         | Caemlyn        |

`$WORK_DESKTOP` maps `{ haven => avalir, zadash => caemlyn }`. `$HOME_DESKTOP`
is its reverse. The two directional keybindings rely on these mappings.

## The Two Interlocking Shortcuts

Both bindings live in MATE's custom keybindings (`dconf` path
`/org/mate/desktop/keybindings/`) and are bound the same way on Haven and
Avalir (and presumably Zadash/Caemlyn):

| Shortcut         | Action invoked                                  | Intent       |
| ---------------- | ----------------------------------------------- | ------------ |
| `Ctrl+Alt+Up`    | `~/bin/launch-perl show-desktop WORK`           | "go to work" |
| `Ctrl+Alt+Down`  | `~/bin/launch-perl show-desktop HOME`           | "go home"    |

The argument is a *symbolic* target (`WORK` / `HOME`), not a literal hostname.
`show-desktop` resolves it against the hash tables using the current hostname:

- `WORK` on a home machine → the paired work machine (e.g., `WORK` on Haven → `avalir`).
- `WORK` on a machine that *is* a work machine → resolves to self (triggers the
  "already on …" branch below).
- `HOME` is the mirror.

So a single, fixed keystroke means "go to your work desktop" or "go home" from
*either* side of the pair.

## Behavior Matrix

Using Haven↔Avalir as the canonical pair. "Switched" below means a NoMachine
session is currently displaying the paired machine.

| Where you are    | Keystroke       | What happens                                          |
| ---------------- | --------------- | ----------------------------------------------------- |
| Haven (not switched) | `Ctrl+Alt+Up` (WORK)   | Open or focus NoMachine to Avalir (fullscreen, current workspace) |
| Haven (switched to Avalir) | `Ctrl+Alt+Up` (WORK) | NoMachine window already exists → brought to current workspace + re-fullscreened + activated |
| Haven (switched to Avalir) | `Ctrl+Alt+Down` | NoMachine (grabbing keyboard in fullscreen) catches the keystroke via its *Minimize window shortcut*, minimizes itself, and the user is back on Haven. The MATE binding never fires. |
| Haven (not switched) | `Ctrl+Alt+Down` (HOME) | "Already on haven's desktop" notification — no-op (NoMachine not running, so MATE catches it) |
| Avalir (not switched) | `Ctrl+Alt+Up` (WORK) | "Already on avalir's desktop" notification — no-op |
| Avalir (switched to Haven) | `Ctrl+Alt+Up` | NoMachine (which is grabbing the keyboard in fullscreen) catches the keystroke first via its own *Minimize window shortcut*, minimizes itself, and the user is back on Avalir. The MATE binding never fires. *(See "Why minimize-on-return works" below.)* |
| Avalir (not switched) | `Ctrl+Alt+Down` (HOME) | Open or focus NoMachine to Haven (fullscreen, current workspace) |
| Avalir (switched to Haven) | `Ctrl+Alt+Down` (HOME) | NoMachine window already exists → re-focused/re-fullscreened on current workspace |

The Zadash↔Caemlyn pair behaves identically with the same shortcuts.

## Implementation

### `~/common/bin/show-desktop`

The workhorse. Takes a single argument: a literal hostname, or one of the
symbolic targets `WORK`, `HOME`, `PREVIOUS`.

Key logic, in order:

1. **Stale-window cleanup.** Iterates `wmctrl -l` and closes any window whose
   title is exactly `NoMachine` (i.e., a disconnected/dead player window with
   no host suffix). Prevents stray windows from accumulating.
2. **Resolve the target.**
   - `WORK` / `HOME` → look up the current hostname in `$WORK_DESKTOP` /
     `$HOME_DESKTOP`. If the hostname is on the *opposite* side of the pair
     (e.g., `WORK` from Avalir), `$host` is set to `$me` so the "already on"
     branch fires.
   - `PREVIOUS` → read `/tmp/previously-shown-desktop` (set on each successful
     switch; see step 4).
3. **Already-on check.** If `$host eq $me`:
   - If the currently active window matches `/(\w+) - NoMachine/` →
     `notify(ERROR => "This should not be possible!")`.
   - Otherwise → `notify(INFO => "Already on <host>'s desktop.")` and exit.
4. **Record + activate.** Save `$host` to `/tmp/previously-shown-desktop`, then:
   - If an `<Host> - NoMachine` window already exists (note the capitalized
     hostname — `xdotool search --name` matches case-sensitively against the
     pattern `"\u$host - NoMachine"`): move it to the current workspace,
     re-fullscreen it (`wmctrl -b add,fullscreen`), activate it, and
     synthesize a click into it.
   - Otherwise: launch `nxplayer` with the saved profile
     `~/NoMachine/<Host>.nxs`.

> **Title-format gotcha:** NoMachine 9.x flipped its window-title order from
> `NoMachine - haven` (8.x and earlier) to `Haven - NoMachine` (host first,
> capitalized). The script was updated for 9.x in May 2026; if it ever fails
> to recognize an existing session and starts launching duplicates on every
> invocation, suspect a future title-format change and check `wmctrl -l`
> against the patterns on lines 97 and 111.

### `~/common/bin/nxkill`

Hard-kill helper for stuck NoMachine clients (`nxplayer.bin`). Two-phase
TERM-then-KILL with a 3-second pause and process display at each phase. Useful
when the show-desktop window-search/cleanup isn't enough to recover from a
broken player.

### MATE keybindings (per-machine)

Live in dconf — not checked into the repo. Confirmed identical on Haven and
Avalir as of May 2026:

```
[custom0]
action='/home/buddy/bin/launch-perl show-desktop WORK'
binding='<Primary><Alt>Up'
name='Work Desktop'

[custom19]
action='/home/buddy/bin/launch-perl show-desktop HOME'
binding='<Primary><Alt>Down'
name='Home Desktop'
```

Related bindings using the same script:

| Shortcut             | Argument   | Purpose                                       |
| -------------------- | ---------- | --------------------------------------------- |
| `Ctrl+Alt+BackSpace` | `PREVIOUS` | Reopen the last desktop switched to           |
| `Ctrl+Alt+a`         | `avalir`   | Direct: avalir                                |
| `Ctrl+Alt+h`         | `haven`    | Direct: haven                                 |
| `Ctrl+Alt+c`         | `caemlyn`  | Direct: caemlyn                               |
| `Ctrl+Alt+z`         | `zadash`   | Direct: zadash                                |

> **Caveat:** `~/common/setup/dconf-load-custom` looks like it could be the
> source-of-truth setup script, but it is **out of date** (e.g., it still binds
> `Ctrl+Alt+Up` to `show-desktop PREVIOUS`, which is now bound to
> `Ctrl+Alt+BackSpace`). Treat live `dconf dump` output as authoritative when
> diagnosing.

### Why `launch-perl`?

MATE keybindings run from a desktop-launcher context that doesn't inherit the
user's interactive shell environment, so a bare `#! /usr/bin/env perl` would
pick up system perl and miss the perlbrew CPAN modules `show-desktop` depends
on (`myperl::Pxb`, `autodie ':all'`, `List::AllUtils`). `launch-perl` sets up
PATH / PERL5LIB / `local::lib` and redirects stderr to
`/tmp/launch-perl/<pid>.error` so silent failures stay diagnosable. See the
"Launching Perl from constrained environments" section in `CLAUDE.md`.

## State

- `/tmp/previously-shown-desktop` — single-line file with the hostname of the
  last machine successfully switched to. Used by `show-desktop PREVIOUS` and
  written on every non-already-on invocation.

## Why Minimize-on-Return Works

The "press the *opposite* direction to come back" half of the dance is **not**
implemented by `show-desktop` at all. It's implemented by NoMachine's own
in-client keyboard shortcuts, configured per machine in `~/.nx/config/player.cfg`:

| Machine | `Minimize window shortcut` |
| ------- | -------------------------- |
| Haven   | `Ctrl+Alt+Down`            |
| Avalir  | `Ctrl+Alt+Up`              |

When NoMachine is fullscreen, it grabs the keyboard, so its internal hotkey
fires *before* MATE's global hotkey gets a chance — that's why the same
keystroke means different things depending on whether a NoMachine session is
currently in front of you. The asymmetric setting is intentional:

- **On Haven** (the home machine of the pair), the minimize shortcut is
  `Ctrl+Alt+Down`. Combined with MATE's `Ctrl+Alt+Up` = "WORK", the user can
  always go "up to work" and "down to home" — even when "down" really means
  "minimize the fullscreen NoMachine showing Avalir."
- **On Avalir** (the work machine), it's mirrored: minimize is `Ctrl+Alt+Up`,
  so "up to work" still works when "work" is *this* machine and the only
  thing in the way is a NoMachine session showing Haven.

The directional metaphor (Up = work, Down = home) holds across both halves:
the show-desktop side *opens* the destination; the NoMachine internal hotkey
*dismisses* an existing view to expose the destination.

The relevant `player.cfg` options:

```
<option key="Enable minimize window shortcut" value="true" />
<option key="Minimize window shortcut" value="Ctrl+Alt+Down" />   <!-- on Haven -->
<option key="Minimize window shortcut" value="Ctrl+Alt+Up"   />   <!-- on Avalir -->
```

These are part of the NoMachine client's `<group name="NXClient">` block in
`player.cfg` and survive across upgrades.

## NoMachine Client Policy

The switching mechanics above assume a specific NoMachine *client-side*
configuration. These choices are stable user preferences, not part of the
switching mechanism itself, but the mechanism only behaves as described
above when they're in effect:

- **Display: always fullscreen.** The user works *in* one machine at a time;
  there is no windowed mode and no flipping between local and remote windows
  on the same screen. (Required for the keyboard-grab → in-client-minimize
  half of the dance to fire.)
- **Display: resize-to-fit-fullscreen.** The remote desktop's resolution is
  matched to the local screen on attach.
- **Input: capture keyboard and mouse on fullscreen.** This is what lets
  NoMachine's `Minimize window shortcut` intercept the bound keystroke
  before MATE sees it.
- **Audio: always route to Avalir, regardless of which host has the focus.**
  Avalir has the decent speakers. Sound originating on Haven during a
  session must redirect to Avalir, never stay local on Haven.
- **Clipboard: both selections enabled.** Cross-machine copy/paste uses
  both `Ctrl+C`/`Ctrl+V` (X CLIPBOARD selection) and select / middle-click
  (X PRIMARY selection); both directions of cut-and-paste are routine.

If a future client upgrade or alternative tool (e.g. `xpra`) is evaluated,
match these policies — that's the floor on functionality.

## Files Involved

- `~/common/bin/show-desktop` — main script (Perl, `myperl::Pxb`).
- `~/common/bin/nxkill` — kill stuck NoMachine clients.
- `~/NoMachine/<Host>.nxs` — per-host NoMachine connection profiles (not in repo).
- `~/.nx/config/player.cfg` — per-machine NoMachine client config; holds the
  asymmetric `Minimize window shortcut` setting that makes the
  press-the-opposite-direction-to-return half of the dance work. **Not in repo,
  and the two values are different on Haven vs Avalir — don't sync them.**
- `/tmp/previously-shown-desktop` — runtime state.
- `~/common/setup/dconf-load-custom` — stale; do not trust without auditing.
- Live dconf at `/org/mate/desktop/keybindings/` on each machine — authoritative.

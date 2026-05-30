# Vim Control-Key Mapping Heisenbug — Investigation & Instrumentation

**Date:** 2026-05-27
**Status:** Root cause *narrowed but unconfirmed*; instrumentation installed to
catch the next occurrence. Cure remains "restart vim."

## Symptom (precise signature)

In a long-running vim session (observed on a ~7-day-old `vi -u ~/.vim-timer
timer-new` session), **all `<C-x>` (control-byte) mappings silently stop
firing**. Distinguishing features, all confirmed live this session:

- Printable single-key maps (`g`→`G`, `Y`→`y$`) still work.
- `<Esc>`-led / Alt maps (`<Esc>n`, `<Esc>c`, and by extension function keys)
  still work.
- **No** control-key map works — including non-prefix ones like `<C-Y>`→`:files`.
- Redefining a control map (`:map` *or* `:nnoremap`) does **not** restore it.
- Exiting and restarting vim fixes it completely.

## What it is NOT (ruled out this session)

- **Not `paste` mode.** `:set paste?` = `nopaste`. (The original hypothesis;
  led to the `pastetoggle=<Ins>` + `ruler` additions in commit `3d3fbbf` —
  still worth keeping as general safety, but not this bug.)
- **Not terminal / modifyOtherKeys / CSI-u re-encoding.** `:echo getchar()`
  then Ctrl-T returns **20** (0x14) — vim receives the *raw* control byte, not
  an escape sequence. `^V^T` inserts a literal `^T`; insert-mode `i_CTRL-T`
  (built-in indent) works.
- **Not the RHS.** `%` (mapped to `:up<CR>:!fake_timerchk %<CR>` — the *same*
  `:up`+shell-out pattern as the broken control maps) works perfectly.
  `fake_timer` resolves on vim's `$PATH` (`/home/buddy/bin/fake_timer`).
- **Not the remap path.** A fresh `:nnoremap <C-K>` beeps as if unmapped, same
  as `:nmap <C-K>`. Both flavors fail identically.
- **Not stuck-interrupt state.** Mashing `<C-C>` then retrying a control map:
  no change.
- **Not timeout/prefix-hang.** `timeout` on, `timeoutlen=1000`; non-prefix
  control maps fail too.
- **Map table is intact.** `:map` lists every control map correctly; no
  autocommand does `mapclear`/`unmap`. `langmap=`, `keymap=` empty;
  `iminsert=0`; `cpoptions=aABceFs` (default).

## Mechanism (best available explanation, unconfirmed)

The byte arrives, the built-in fires, the map table is intact, yet **both**
`:map` and `:nnoremap` fail to fire for control bytes. The only thing
consistent with all of that is that **typed control bytes are entering vim's
typeahead buffer flagged "do not remap"** (`RM_NONE` internally) — vim then
skips map lookup entirely for them and runs the built-in. Printable and
`<Esc>`-led keys keep their normal mappable flag, so they're unaffected. ESC
(0x1b) is spared because it's the lead byte for key-code/termcode parsing,
which is below the remap layer.

This is a **vim-internal runtime state**, not config — which is exactly why
config-level fixes (redefine, re-source) can't touch it, and only restart
cures it. The trigger is unknown; it manifests after long uptime + heavy
control-key + `:!` shell-out usage (the timer workflow).

## Why we can't just gdb it

Running binary is `/usr/bin/vim.basic`, **stripped** (no named globals like
`no_mapping`/`RM_*`), and `ptrace_scope=1` (attaching to a non-child needs
root). Even with sudo, reading internals from a stripped binary isn't
practical without matching debug symbols. So live introspection is out — hence
the keystroke/event capture approach below.

## Instrumentation installed (2026-05-27) — TEMPORARY

Scope: **timer vim only** (where it reproduces — most `<C-x>` usage). All logs
land in `~/local/log/vimkeys/` (host-local, unsynced, like `ac-mode.log`).

1. **Keystroke log** — `-W ~/local/log/vimkeys/timer.keys` added to the `timer`
   alias (`rc/tcshrc`) and `local/tyr/rc/screenrc.timer`. Records every typed
   key for the session (overwrites per launch; the alias rotates the prior
   session to `timer.keys.prev` first, so a restart-without-capture still keeps
   the just-broken session's trail).
2. **Event log** — autocmds in `rc/vim-timer` (`TimerTrace` augroup → `TLog()`)
   append timestamped lines to `timer-events.log` for async events the keylog
   can't see: `VimEnter`/`VimLeave`, `VimResized`, `Focus{Gained,Lost}`,
   `Vim{Suspend,Resume}`, `ShellCmdPost` (with the command).
3. **One-key state dump** — `\d` (and `:TimerDump`) in `rc/vim-timer` snapshot
   `:map`/`:map!`/`:set all`/`:scriptnames` to `broken-<ts>.txt` and copy the
   live keylog to `broken-<ts>.keys`. `\d` is a **printable** sequence
   (backslash leader) so it survives the bug; `:TimerDump` is the always-works
   fallback (command line is never affected).

## When the bug next trips — DO THIS

1. **Don't restart yet.** Press `\d` (or type `:TimerDump`). Note the wall time.
2. That writes `~/local/log/vimkeys/broken-<ts>.txt` (full `:map`/`:set`/state,
   written unbuffered) and `broken-<ts>.keys` (keystroke trail). **Caveat:**
   vim's `-W` scriptout is stdio-buffered, so `broken-<ts>.keys` may lag the
   last few KB of keystrokes. The **complete** keystroke trail lands in
   `timer.keys.prev` after step 4 (exit flushes the full file; the next `timer`
   launch rotates it to `.prev` before truncating). `timer-events.log` is also
   unbuffered (each `writefile(...,'a')` flushes), so events are always current.
3. Restart vim to clear it (this is what produces the complete `timer.keys.prev`).
4. Analyze: replay with `vim -s timer.keys.prev -u ~/.vim-timer <scratch>` to try
   to reproduce deterministically, and correlate the tail against
   `timer-events.log` around the noted time to spot the triggering operation
   (resize? focus? a specific `:!`?). A clean repro → file an upstream vim bug.

## Activating the keylog

The `timer` alias change only takes effect in a **fresh tcsh** (or after
re-sourcing). The `rc/vim-timer` changes (`\d`, `:TimerDump`, event log) take
effect on the **next vim launch** regardless of shell. To start a logged timer
vim immediately from an existing shell:
`vi -W ~/local/log/vimkeys/timer.keys -u ~/.vim-timer timer-new`

## Removing it once caught

Delete the `TimerTrace`/`TLog`/`TimerDump`/`\d` block at the end of
`rc/vim-timer`, revert the `timer` alias in `rc/tcshrc` and the two `stuff`
lines in `local/tyr/rc/screenrc.timer`, and (optionally) the
`~/local/log/vimkeys/` tree.

## 2026-05-29 update — first real capture; instrumentation hardened

The bug recurred on 2026-05-29 in the same long-uptime session.  `\d` captured
state (`broken-20260529T161007.txt`); on restart, the 47-hour keystroke log
flushed to `timer.keys.prev` (1437 bytes — sparse but complete).  Findings:

- **The map table and `TimerTrace` augroup were 100% intact at break-time**;
  `eventignore=` was empty.  Static state during the bug looks identical to
  normal — consistent with the `RM_NONE`-on-typed-control-bytes hypothesis
  (the entry exists, the lookup is being skipped).
- **The bug-onset window is narrow.**  Cross-referencing keylog vs.
  `fake_timer daybreak today` (which shows real successful timer ops), the
  last known-good Ctrl-mapping was `<C-T>` starting `timer-fixes` at 15:57:53.
  Between that and the first failing `<C-L>` a few keystrokes later, the only
  activity was a manual screen-pasted `pto` entry (timestamps + ", Summer
  Fridays" + a stray UTF-8 `»`) and a second `i<timestamps>,<Esc>` insertion.
  **No bracketed-paste markers (`\e[200~`/`\e[201~`) anywhere in the keylog**
  — screen is sending plain bytes, so a bracketed-paste-handler bug is ruled
  out.
- **A deterministic replay does NOT reproduce.**  Running
  `vim -u ~/.vim-timer -s timer.keys.prev <copy>` plus a Ctrl-K-map probe at
  the end yields `fire=42` — the map fired normally.  So the trigger is
  **not** a pure function of the typed bytes; it requires at least one of:
  long-running session state accumulation, real-tty terminal state
  (modifyOtherKeys / kitty keyboard protocol negotiation that `-s` skips),
  or inter-byte timing.  An upstream bug report will need a long-uptime
  real-tty repro.

### Instrumentation gaps caught this round (now fixed)

- **`ShellCmdPost` doesn't fire for `:%!filter` commands** (only for `:!cmd`).
  Your `<C-T>`/`<C-F>`/`<C-P>` mappings all use `:%!fake_timer ...`, so all
  start/pause/half operations were invisible to the event log.  The entire
  31-hour 5/27→5/29 "gap" was a logging blind spot, *not* bug evidence.
  **Fix:** added `CmdlineLeave :` autocmd that logs `'Cmd ' . getcmdline()`
  for every non-aborted `:` command, mapped or typed, filter or bang.
- **`TimerDump` originally missed autocmds.**  The first `\d` dump didn't
  include `:autocmd`, so we couldn't verify the augroup was intact without
  appending via `:redir >>` manually.  **Fix:** TimerDump now also captures
  `:autocmd`, `:verbose nmap <C-T>`, `:verbose imap <C-T>`, `:set
  eventignore?`, `mode()`, `state()`, `&t_BE/&t_TI/&t_TE`, `getreg(':')`,
  and the last 10 messages.
- **Idle heartbeat added.**  `CursorHold,CursorHoldI → TimerHeartbeat()`
  with a 60-second throttle.  CursorHold fires only *once* per idle period
  (not periodically while idle), so absence of heartbeats over an active
  workday would directly prove autocmds weren't firing.
- **`-W` scriptout is stdio-buffered and never flushes mid-session.**  The
  live `\d`'s keylog snapshot is therefore near-empty when the bug hits.
  The complete trail is only available after exit, when the alias rotates
  it to `timer.keys.prev`.  Documented; no clean fix from vimscript.

### Wild-goose chase findings (worth recording so we don't re-chase)

After the user pointed out that `fake_timer daybreak yesterday` proved
Ctrl-mappings were firing through 5/28 (the "gap" was the filter-vs-bang
ShellCmdPost blind spot, not bug-evidence), the bug-onset window narrowed
dramatically: between `<C-T>` starting `timer-fixes` at **5/29 15:57:53**
(last known-good Ctrl-map) and the first failing `<C-L>` a few keystrokes
later — call it the 13 minutes before `\d` fired at 16:10:07.  The suspect
keystrokes in between are visible in `timer.keys.prev`:

```
^_pto^MA1780081200-1780102800,^[nA, Summer Fridays^[<UTF8 0xC2 0xBB>:w^M{bbi1780081200-1780110000,^[^L^L^L^L^L^B
```

That stray `M-BM-;` (UTF-8 `»` = `0xC2 0xBB`) lands in *normal* mode (after
the `<Esc>` post-`Summer Fridays`).  Looked like a "burnt matchhead near
an arson investigation" per the user.  Hypotheses checked:

- **`~/.screenrc` paste wrapping.**  `register [/]` defines a
  `<Esc>:se paste<CR>a<paste><Esc>:se nopaste<CR>a` wrap bound to
  `<C-A><C-]>`; plain `<C-A>]` is screen's unwrapped paste.  The keylog
  around the pto entry shows **no `:se paste` wrap**, so the wrapped form
  was *not* used here.  Either typed or plain-pasted.  Not the trigger.
- **`»` triggering vim state corruption.**  Tested
  `<Esc>U+00BB<Ctrl-K>` in isolation against `rc/vim-timer` — Ctrl-K map
  fires (`fire=42`).  Not a trigger by itself.
- **`0xFF`** (the other unusual high byte in the keylog) — same test
  shape, `fire=42`.  Not a trigger.
- **`»` not actually inserted into `timer-new`.**  Confirmed by `grep`.
  In normal mode, `»` is an unmapped command → no-op → no buffer effect.
  Whatever its source in the screen paste buffer (a Vivaldi tab title
  fragment, a UI breadcrumb), it was harmless.
- **Bracketed-paste markers**: still zero (`\e[200~`/`\e[201~`) in the
  entire keylog.

So the trigger really does seem to need something beyond typed bytes —
plausibly long-running session state, real-tty terminal-protocol state,
or inter-byte timing.  Standalone replay can't get there.  **Conclusion:
the byte sequence alone is a wild goose.  Wait for the next occurrence
with the now-much-better instrumentation (CmdlineLeave will capture every
`:` command — mapped, typed, filter, or bang — so the next break's keylog
+ events.log will let us see *exactly* the operation that went sideways).**

### Bugfix to the CmdlineLeave autocmd

Initial form was `if !v:event.abort` — but `v:event` doesn't always have
the `abort` key on this vim, raising `E716: Key not present in Dictionary`.
Replaced with `if !get(v:event,'abort',0)` (safe default to "not aborted").

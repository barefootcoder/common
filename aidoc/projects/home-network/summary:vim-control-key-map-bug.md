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

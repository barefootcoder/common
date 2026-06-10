# SSH Remote-View Color Loss (washed-out Claude Code prompt tint)

**Date**: June 10, 2026
**Systems**: Avalir + Haven (in fact all boxes, via the synced `rc/login` and `bin/myterm`)
**Issue**: Claude Code renders each submitted user prompt with a faint background
tint (256-color index 237, a dark grey) so it stands out when scrolling back.
Viewed locally the tint is crisp; viewed over `ssh` from another box it collapses
into the surrounding background and is nearly invisible.

## Symptom

The discriminator is local vs `ssh` *viewing*, NOT which machine runs Claude. One
single `screen` session, holding the same already-rendered cells, looks good on the
box it runs on and washed-out when reattached over `ssh` from elsewhere. Walk from
one room to the other and the *same already-typed prompt* changes appearance; walk
back and it changes again. It is symmetric: whichever box is local looks right, the
remote one looks wrong, in both directions.

That framing is the whole key to the bug. Nothing is re-queried or re-decided per
view: Claude emits its colors once, upstream, into `tmux` then `screen`. What differs
is only how `screen` renders its (identical) grid to a locally-attached display vs an
`ssh`-attached one.

## Ruled out: OSC 11 / theme detection (the false trail)

The leading hypothesis was that Claude queries the terminal background via OSC 11 and
that the query/response round-trip doesn't survive the `ssh` + `screen` + `tmux`
chain, so Claude picks a contrast color that ends up matching the background. Wrong,
for a structural reason: the washed-out prompts are *historical* (you scroll back to
them). They are static stored cells. No startup query can explain a difference that
appears and disappears purely by changing the viewing terminal. (An earlier session
had likewise ruled out `$COLORTERM` and GNU screen's truecolor setting, which doesn't
exist before screen 5.0 anyway.)

Confirmed by reading the cells straight out of tmux's grid (`tmux capture-pane -p
-e`): the only background-fill Claude emits is `ESC[48;5;237m`, a 256-*indexed* grey,
never a 24-bit `48;2;r;g;b` value. So there is no truecolor to quantize; it is a plain
palette index that should render identically anywhere with 256 colors.

## Root cause: TERM clobbered to vt100 on the ssh display

`screen` renders its grid to whatever display attaches, using that display's terminfo.
If the display claims to be a no-color terminal, `screen` strips color out, and the
index-237 grey collapses into the background.

A three-way `TERM` measurement nailed it:

| Path | `TERM` | `COLORTERM` | `tput colors` |
|------|--------|-------------|---------------|
| Local kitty shell      | `xterm-kitty` | `truecolor`  | 256 |
| `ssh -t avalir 'cmd'`  | `xterm-kitty` | *(unset)*    | 256 |
| Interactive `ssh avalir` | **`vt100`** | *(unset)*    | **-1** |

The interactive login forces `vt100` (no color). Two synced files were doing it, at
two different layers:

1. **`rc/login`**: a bare, unconditional `set term=vt100`. `.login` runs for *login*
   shells, which an interactive `ssh` is, but a local kitty window is not (kitty here
   starts a non-login shell), and `ssh host 'cmd'` is not either. That is exactly the
   asymmetry in the table: local and command-mode keep `xterm-kitty`; interactive ssh
   gets clobbered to `vt100`.

2. **`bin/myterm`**: `faux_cmd="env TERM=vt100"`, prepended whenever the launched
   command contains `ssh` (so `ssh avalir`, `ssh zadash`, even `cessh dirk`). The
   window therefore runs `env TERM=vt100 ssh ...`, forwarding `vt100` to the remote
   from the start. This is why fixing only `rc/login` was not enough for windows
   launched by `termstart`: `.login` was correctly *preserving* the inherited `TERM`,
   but the inherited value was already `vt100` because `myterm` had set it.

`myterm`'s `vt100` is a fossil. It was introduced (see
`summary:claude-code-terminal-corruption.md`) back when the local emulator was
urxvt/Eterm with an exotic `TERM` that remote boxes lacked in their terminfo db, and
`vt100` guaranteed a universally-known type. With kitty (and a modern remote that has
`xterm-kitty` terminfo) it only throws color away.

## Fix

**`rc/login`**: gate the fallback. Keep an inherited real `TERM`; drop to `vt100` only
when there genuinely isn't one.

```tcsh
if ( ! $?term ) then
	set term=vt100
else if ( "$term" == "" || "$term" == "unknown" || "$term" == "dumb" ) then
	set term=vt100
endif
```

The unset check and the value check MUST be separate statements: tcsh expands `$term`
at parse time, so a single combined condition errors with "Undefined variable" when
`TERM` is unset.

**`bin/myterm`**: choose the `faux_cmd` `TERM` per emulator instead of forcing `vt100`.

```bash
case $termprog in
	kitty|urxvt|gnome-terminal) faux_cmd="env TERM=xterm-256color" ;;
	*) faux_cmd="env TERM=vt100" ;;
esac
```

`xterm-256color` was chosen over the alternatives because:

- It is present in essentially every remote's terminfo (more universal than
  `xterm-kitty`), keeping the original "guarantee a known type" intent while restoring
  256-color, so the prompt grey survives.
- Removing the override entirely would forward bare `xterm-kitty`, which can break
  remotes that lack that terminfo entry (some work boxes, zadash).
- kitty and urxvt both render standard 256-color SGR correctly. Eterm's 256-color
  support is unreliable and its terminfo is rarely on remotes, so Eterm (and anything
  unrecognized) keeps the safe `vt100`: no color, but no regression from before.
- Bonus: `rc/screenrc`'s `termcapinfo xterm* ...` tweaks (including `ut` / bce) match
  `xterm-256color`; they did not match `vt100`.

## Verification

Takes effect on a *fresh* login + reattach; an already-attached display keeps the
`TERM` it grabbed at attach time.

- Interactive `ssh avalir`, then `printenv TERM ; tput colors` gives `xterm-256color`
  / `256` (was `vt100` / `-1`).
- A freshly `termstart`-launched Avalir window, reattaching the screen session, shows
  the prompt-bar tint as crisply over `ssh` as locally. User-confirmed fixed.

This also restores color for the other `ssh`/`cessh` windows `termstart` launches
(zadash, work boxes), not just the Avalir<->Haven pair.

## Notes

- `COLORTERM` is still not forwarded over `ssh` (OpenSSH doesn't, by default), but it
  is irrelevant here: the tint is a 256-indexed color and GNU screen 4.09 has no
  truecolor path. Real 24-bit over `ssh` would be a separate change
  (`SendEnv`/`AcceptEnv COLORTERM` + screen 5.0).
- Related: `summary:claude-code-terminal-corruption.md` (origin of the `env
  TERM=vt100` faux-term line and the kitty + screen + tmux stack), `conf/tmux-claude.conf`,
  `rc/screenrc`, `conf/kitty/kitty.conf`.

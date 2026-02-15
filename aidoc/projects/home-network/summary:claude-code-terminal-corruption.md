# Claude Code Terminal Corruption Investigation

**Date**: February 9, 2026
**System**: Avalir (Linux Mint, urxvt + GNU screen)
**Issue**: Persistent screen corruption and rendering artifacts when running Claude Code

## Environment

- **Terminal emulator**: urxvt (rxvt-unicode)
  - Font: Inconsolata, pixelsize 16
  - Background image: `~/local/data/term-bg/avalir-on-fire.png`
  - Launched via `bin/myterm` wrapper
- **Multiplexer**: GNU screen 4.09 (`screen -S base`), 30+ windows typical
- **$TERM**: `screen-256color` (set explicitly in `bin/claude` wrapper; base screen windows use `screen`)
- **Terminal size**: 125x50 (urxvt geometry), though `tput` inside Claude Code sometimes reports 80x24
- **Claude Code wrapper**: `bin/claude` (Perl script using PerlX::bash)
- **Screen buffer tooling**: `screen-bufsave`, `screen-bufgrep`, `screen-bufless`, `screen-bufcmp` -- all rely on `screen -X hardcopy -h` to capture scrollback

## Problem Description

Claude Code exhibits significant rendering corruption when running inside urxvt + GNU screen:
- Null byte blocks (`^@^@^@...`) appearing in the display
- Overlapping/duplicated text regions from full-screen redraws
- Mangled Unicode: box-drawing characters render as `<90><9b><88>` etc.
- Repeated content blocks in saved screen buffers, making them harder to search
- Screenshot captured: `~/docs/ai/screenshots/claude-code-redraw-issues-20260209.png`

## Root Cause Analysis

The corruption stems from the full rendering stack:

1. **Claude Code** (Ink/React TUI) emits complex, rapid escape sequences -- often 5000+ line full-screen redraws when only 50 lines are visible
2. **GNU screen** intercepts and re-interprets all escape sequences through its own 1980s-era VT100 emulator, which can desync under heavy load
3. **urxvt** renders the final output but has limited Unicode/emoji support, causing character mangling

Each layer strips or mangles something. The key missing technology is **DEC mode 2026 (Synchronized Output)**, which batches screen updates atomically. Neither urxvt nor GNU screen supports it.

### Terminal size mismatch (possibly contributing)

`tput` inside Claude Code's Bash tool reports 80x24 (default PTY size) while the actual screen window is 125x50. This may be Claude Code's internal subprocess PTY rather than what its rendering engine uses, so impact is uncertain. The user reports this issue "comes and goes" and fixing it previously "didn't seem to do much."

## Solutions Investigated

### 1. claude-chill (PTY proxy) -- RECOMMENDED TO TRY

- **What**: A Rust-based PTY proxy ([github.com/davidbeesley/claude-chill](https://github.com/davidbeesley/claude-chill)) that sits between Claude Code and the terminal, performing differential rendering
- **How it helps**: Intercepts Claude Code's massive redraws and sends only changed lines to screen, reducing the escape sequence storm by ~85%
- **Install**: `cargo install --git https://github.com/davidbeesley/claude-chill`
- **Concern**: Differential rendering could affect what `screen -X hardcopy -h` captures. However, saved buffers are already degraded (mangled Unicode, null bytes, repeated blocks), so the risk is manageable
- **Testing approach**: Run claude-chill in one screen window, regular claude in another, do the same task, compare buffers with `screen-bufsave` + `screen-bufcmp`
- **Status**: Not yet tested

### 2. Terminal emulator replacement -- RECOMMENDED

urxvt lacks GPU acceleration, DEC 2026 support, and has limited Unicode/emoji rendering. Three alternatives were evaluated:

| Terminal   | Background images | Unicode/emoji | DEC 2026 | GPU | CLI overrides (for myterm) |
|------------|-------------------|---------------|----------|-----|----------------------------|
| **Kitty**  | Yes (`-o background_image=`) | Excellent | Unclear | Yes | Excellent (`-o key=value`) |
| **WezTerm** | Yes (Lua config) | Good | Yes | Yes | Limited (config-file-centric) |
| **Ghostty** | Yes (v1.2.0+) | Best | Yes | Yes | Moderate |

**Decision: Kitty** was selected for `myterm` integration because its `-o key=value` CLI pattern maps cleanly to how `myterm` constructs per-instance terminal launch commands. WezTerm's Lua-config-centric approach would require generating temp configs or environment-variable switching. Ghostty was considered but is less mature.

**Note on DEC 2026 through screen**: Even with a DEC 2026-capable terminal, GNU screen likely does not pass these sequences through. The benefit is limited to smoother rendering of screen's own output bursts to the outer terminal.

### 3. Terminal size propagation fix -- IMPLEMENTED

Added to `bin/claude` wrapper to ensure `$COLUMNS` and `$LINES` are set from screen's actual geometry before launching Claude Code.

## Changes Made

### bin/claude (wrapper script)

Added terminal size propagation before the `exec`:

```perl
# Ensure terminal size is correctly propagated through screen
# screen -Q info format: (cursor_col,cursor_row)/(width,height)+scrollback
chomp(my $screen_info = `screen -Q info 2>/dev/null`);
if ($screen_info =~ m{/\((\d+),(\d+)\)})
{
    $ENV{COLUMNS} = $1;
    $ENV{LINES} = $2;
}
```

`$TERM` remains `screen-256color` (correct for screen with 256-color support; `screen` loses colors, `xterm-256color` lies about capabilities).

### bin/myterm (terminal launcher)

Added a `kitty)` case block to the `$termprog` case statement:

- Font: converts pixel size to point size (`pixels * 0.75` at 96 DPI)
- Background image: `-o background_image=<path> -o background_image_layout=scaled`
- Geometry: parses `WxH` from X11 geometry string, uses `-o initial_window_width=Wc -o initial_window_height=Hc`; position handled by `xrestore`
- Title/class: `--title $title --class $title`
- Colors: `-o foreground=white -o background=black`
- Icon: skipped (Kitty uses `.desktop` files)

To activate: change line 4 of `myterm` from `termprog=urxvt` to `termprog=kitty`. **Status**: Done.

## Known Issues / Watch Items

- **Font size conversion**: The `pixels * 0.75` conversion assumes 96 DPI. May need adjustment depending on display. Kitty also does its own DPI scaling.
- **SSH faux_term**: Resolved. Changed from urxvt-specific `-tn vt100` to terminal-agnostic `env TERM=vt100` command prefix. This works with any terminal emulator and is actually an improvement: the local terminal retains full rendering capabilities while only the remote host sees `vt100`.
- **Background tint**: May need `-o background_tint=0.3` or similar added to the Kitty args if text readability suffers over the background image.
- **claude-chill + screen buffer interaction**: Needs empirical testing before committing to regular use.
- **GNU screen DEC 2026 passthrough**: Watch for future screen patches that add support. This would be the most impactful single fix if it ever lands.

## Next Steps

1. ~~Install Kitty, test with `myterm` by changing `termprog=kitty`~~ Done
2. Tweak font size and background tint as needed
3. Install and test `claude-chill` with the side-by-side buffer comparison approach
4. If Kitty + claude-chill together resolve the worst corruption, consider making Kitty the default in `myterm`
5. Verify `env TERM=vt100` SSH title suppression works on remote terminals

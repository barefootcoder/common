# Timer App

## Overview
A personal time-tracking system built on Perl/myperl. The main script (`fake_timer`) manipulates a tab-delimited data file to start/stop/pause timers, total hours, break down time chunks, and generate reports. Supporting scripts compute averages, look up ticket-based time, and validate data integrity.

Sessions in this project typically focus on updating the code (bug fixes or new features), though agents may occasionally be asked to diagnose or fix problems in the data file itself.

## Repository Files

### Core Script
- `bin/fake_timer` -- Main timer engine. Reads/writes the timer data file via line-by-line processing. Commands: `start`, `half`, `pause`, `new-week`, `total`, `eod`, `breakdown`, `daybreak`, `review`.

### Supporting Scripts
- `bin/fake_timeravg` -- Calculates average hours over N archived weekly timer files. Calls `fake_timer total` as a subprocess.
- `bin/fake_timerdavg` -- Advanced daily averaging with week-by-week summaries (`-s`), target-seeking (`-W`), hours-to-goal (`-H`), and outlier detection (`-O`). Also calls `fake_timer` as a subprocess.
- `bin/fake_timerttl` -- Looks up all timer entries matching a Jira/Trac ticket number across one or more timer files. Pipes results through `fake_timer total`.
- `bin/fake_timerchk` -- Validates timer data file integrity: checks for negative/overlapping chunks, missing comments, and Monday lunch-gap detection.

## Data File

### Location
- **Active file**: `~/timer/timer-new` -- the current working timer file (read/written by `fake_timer`)
- **Backup**: `~/timer/timer-new.bak`
- **Pre-new-week snapshot**: `~/timer/timer-pre-new-week`
- **Archives**: `~/timer/archive/timer-new.YYYYMMDD` -- periodic snapshots

### Format
The data file is tab-delimited with a repeating three-section structure per week, separated by blank lines:

1. **Timer names** (one per line): `email`, `review`, `monday-mtg`, etc. Special timer `:AVAILABILITY` tracks total available hours.
2. **Timer data** (one per line): `<name>\t<chunks>` where chunks are comma-separated epoch pairs like `1775507983-1775508354,1775520102-1775520765,`. A trailing `-` means the timer is currently running. Prefix `2/` on a chunk means half-time mode.
3. **Comment lines** (one per line): `<name>:\t<description>\t<ticket>` where `<ticket>` is a Jira ticket (e.g., `CLASS-956`), Trac number, or `SAVE`/`SAVEp` marker.

Weeks are ordered newest-first in the file. The `new-week` command creates a new week at the top, carrying forward timer names and any comments tagged with tickets or `SAVE`.

## Key Concepts

- **Chunks**: Time segments stored as `<epoch_start>-<epoch_end>`. Running timers have no end: `<epoch_start>-`. Half-time chunks are prefixed `2/`.
- **Week boundaries**: Blank lines separate the three sections of each week; a double blank line separates weeks.
- **`:AVAILABILITY`**: A special pseudo-timer that tracks total hours available (not just hours worked). Always the last timer in each week.
- **`-a` / `-w` / `-k` flags**: Control which weeks are included in multi-week operations. `-a` = all weeks, `-w N` = N weeks back, `-k` = skip current week.
- **`SAVE` / `SAVEp` markers**: Comments tagged `SAVE` are preserved across `new-week`. `SAVEp` preserves the comment but clears the parenthetical description portion.
- **6am day boundary**: Times before 6:00 AM are considered part of the previous day (see `get_date()`).

## Development Patterns

- All scripts use `myperl::Script` (or `myperl`) which provides `opts`, `debuggit`, `Date::Easy`, `List::Util`, and other standard imports.
- `fake_timer` processes the data file line-by-line via `<>` (ARGV filehandle), printing modified lines to stdout. The caller is expected to redirect output back to the file (e.g., via a wrapper).
- The averaging scripts (`fake_timeravg`, `fake_timerdavg`) call `fake_timer` as a subprocess via `open(IN, "... |")`.
- `fake_timerttl` pipes data *into* `fake_timer` via `open(PIPE, "| fake_timer ...")`.
- Options are parsed via `opts` (from `myperl::Script`), accessed as `$OPT{flag}`.
- `const` is used for compile-time constants.
- The smartmatch operator (`~~`) is used in several places for command dispatch.

## Testing Approach

There are currently no automated tests for the timer scripts. Testing is manual:
- Run commands against `~/timer/timer-new` and verify output
- Use `fake_timerchk` to validate data file integrity after changes
- Use `-D` (debug) flag on most scripts for verbose diagnostic output
- The `~/timer/timer-test` file can be used for safe experimentation

## Dependencies

Key CPAN modules used across the scripts:
- `Date::Easy` (via myperl) -- date/time handling
- `Perl6::Form` -- formatted output (used by `fake_timerdavg`)
- `Date::Gregorian::Business` -- weekday counting (used by `fake_timerdavg`)
- `PerlX::Maybe` -- conditional hash pairs (used by `fake_timerchk`)
- `Perl6::Slurp` -- file slurping (used by `fake_timerttl`)
- `Time::ParseDate` -- flexible date parsing (used by `fake_timeravg`)

## Troubleshooting

- **"negative chunk" warnings from `fake_timerchk`**: A timer's end epoch is less than its start epoch -- usually a data entry error or corruption. Fix by editing the chunk in the data file.
- **"needs a comment" warnings**: A timer had time logged but no corresponding comment line. Add the comment section entry.
- **Future date errors from `fake_timerdavg`**: Usually indicates corrupt epoch data. Use `-w<N>` to isolate which week has the bad data.
- **Dangling timer warnings**: A timer chunk ending with `-` (still running) found in an archived file. Should only appear in `timer-new`.

[Created and submitted by AI: Claude]

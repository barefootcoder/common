# NAS Migration — Agent Guide

This document is for AI agents (Claude Code or similar) picking up the NAS
migration and backup verification project.  Read this first, then read
`state-of-affairs-20260404.md` for the most recent inventory.


## What This Project Is

The user is consolidating data from a decommissioned Synology NAS (Taaveren)
and several Linux backup servers onto a new QNAP NAS (Nakama).  The critical
constraint is: **no data can be lost**.  Files get copied to Nakama, then
verified, and only after verification can the source copy be deleted to free
space.  The verification toolchain in this repo exists to make that safe.

The data totals roughly 2TB spread across 10 top-level shares (archive,
backup, camera, homes, music, personal, proj, rpg, sync_hist, work).


## Server Access — The Hard-Won Details

### Nakama (QNAP NAS)
```
ssh -p 2322 nami@nakama
```
- **Shell**: bash (natively — no `bash -c` wrapper needed)
- **Base path**: `/share/<sharename>` (e.g., `/share/archive`, `/share/proj`)
- **CRITICAL GOTCHA**: The `/share/<name>` paths are **symlinks** to
  `/share/CACHEDEV1_DATA/<name>`.  The symlinks work fine for `ls`, `find`,
  `rsync`, and most operations, **but `du` reports 0 on the symlinks**.
  Always use `/share/CACHEDEV1_DATA/<name>` when running `du`.
- **BusyBox**: Nakama runs BusyBox for some coreutils.  `sort -h` (human
  numeric sort) is **not available**.  Use `sort -n` or `sort -rn` instead.
- `du --max-depth=N` works fine.
- The user's rsync helper script is at `~/common/bin/nasupdate`.  It wraps
  rsync with the right SSH port and user, and does a dry-run preview before
  the real transfer.  Study it before doing any data movement.

### Haven (Linux laptop)
```
ssh haven
```
- **Shell**: tcsh (interactive).  **You must wrap complex commands**:
  `ssh haven 'bash -c "your command here"'`
- **Data path**: `/export/<sharename>`
- **Syncthing-synced with Avalir**: backup, camera, music, personal, proj,
  rpg, work (all confirmed via `.stfolder` markers).  These are live data
  and must NOT be deleted.
- **Taaveren leftovers** (NOT synced, `synology-` prefix):
  `synology-sync_hist` (12G, verified, deletable).
  `synology-homes` was deleted 2026-04-04 after migration to Nakama.
- **`/var/tmp`**: 72G of old staging/backup/test data (see state-of-affairs
  for full inventory).  All appears safe to delete after user review.
- Disk: 938GB total, ~364GB used as of 2026-04-04

### Avalir (Linux desktop — the local machine)
```
(local — no SSH needed)
```
- **Shell**: tcsh (interactive), bash for scripts
- **Data path**: `/export/<sharename>`
- Has: proj, personal, backup, music, rpg, camera, work (all Syncthing-synced with Haven)
- Does NOT have: archive, sync_hist
- Disk: 913GB total, ~555GB used as of 2026-04-04

### Zadash (Linux — unreliable hardware)
```
ssh zadash
```
- **Shell**: tcsh.  Same `bash -c` wrapper needed as Haven.
- **Data path**: `/srv/sync_hist` (the only significant data)
- This machine is unreliable and is scheduled for replacement by Graymoor.
  **Treat any data that exists only on Zadash as at-risk.**
- Disk: 915GB total, ~612GB used as of 2026-04-03

### Caemlyn and Taaveren
**Both are gone.**  Do not attempt to reach them.  Historical references to
these machines in scripts and listing files are from the earlier phases of
this project.

### Graymoor
Not yet on the network.  Built from Caemlyn's hardware.  Intended as the
Zadash replacement.  Don't try to SSH to it.


## The tcsh Trap

This is the single biggest gotcha.  Haven, Avalir, and Zadash all use tcsh
as the interactive shell.  When you `ssh haven 'some command'`, tcsh
interprets it.  This means:

- **No `for` loops** — tcsh uses `foreach`, not `for ... do ... done`
- **No `$(...)` subshells** — tcsh uses backticks
- **No `2>/dev/null`** — tcsh redirects stderr differently
- **No `{a,b,c}` brace expansion** in the same way

The fix is always: `ssh <host> 'bash -c "your command"'`

Be careful with quoting.  The outer quotes are for your local shell, the
inner quotes are for tcsh passing to bash.  For complex commands with
internal quotes, use heredoc-style or escape carefully.

Nakama is the exception — its default shell is bash, so you can send
commands directly.


## The Verification Toolchain

### dir-listing
Generates a file listing: `<epoch_timestamp> <size_in_bytes> <relative_path>`

```bash
./dir-listing [-vD] <dir>              # local
./dir-listing [-vD] <remote>:<dir>     # remote via SSH
```

Creates `<dirname>-<hostname>.list`.  These files can be very large (the
full Taaveren volume1 listing was 488MB).

### review-dir-listings
Compares two listings.  Reports files where the right (backup) is missing,
older, or smaller than the left (source).

```bash
./review-dir-listings :<include_path> -<exclude_path> <from>=<to> \
    --no-conflicts <source.list> <backup.list>
```

Key details:
- `:path/` means "only check files under this path"
- `-path/` means "exclude files under this path"
- `from=to` translates paths (e.g., `synology-Dropbox/=personal/Dropbox/`)
- Automatically skips Synology metadata (`@eaDir`, `#recycle`)
- `--no-conflicts` skips Syncthing/Dropbox conflict files

### verify-copies
Orchestrator script that runs ~15 review-dir-listings comparisons.  **This
script is currently configured for the OLD topology** (comparing
volume1-taaveren.list against various server listings).  It will need to be
updated or replaced for the current Nakama-centric topology.

### size-missing-files
Pipe review-dir-listings output through this to get totals:
```bash
./review-dir-listings ... | ./size-missing-files
```

### nasupdate (~/common/bin/nasupdate)
The user's rsync wrapper for Nakama transfers.  Handles SSH port, user,
excludes, and does a dry-run preview before acting.  **Always use this
instead of raw rsync when moving data to/from Nakama.**

Usage:
```bash
nasupdate <sharename>              # sync Nakama -> local /export/<sharename>
nasupdate -R <sharename>           # REVERSE: local -> Nakama (dangerous!)
nasupdate -d /path/to/dir [share]  # direct mode
nasupdate nas:/path /localpath     # explicit path-to-path
nasupdate /localpath nas:/path     # explicit path-to-path (reverse)
```


## Directory Layout

```
nas-xfer/
├── CLAUDE.md                 # Project instructions (loaded by Claude Code)
├── assessment/               # Current state analysis (created 2026-04-03)
│   ├── state-of-affairs-20260403.md   # Comprehensive inventory
│   ├── agent-guide.md        # THIS FILE
│   ├── nakama-du.txt         # Raw du output from Nakama
│   ├── haven-du.txt          # Raw du output from Haven
│   ├── zadash-du.txt         # Raw du output from Zadash
│   └── avalir-du.txt         # Raw du output from Avalir
├── pre/                      # Phase 1 data (Jan-Feb 2025, Taaveren era)
│   ├── volume1-taaveren.list # Master source listing (488MB!)
│   ├── *-taaveren.list       # Per-share source listings
│   ├── export-*.list         # Backup server listings
│   ├── *-verify.log          # Verification results
│   └── nas-transfer.txt      # Original migration planning doc
├── post/                     # Phase 2 data (Sep-Dec 2025, Nakama era)
│   ├── *-nakama.list         # Nakama listings
│   ├── *-haven.list          # Updated Haven listings
│   └── first-try/            # Failed early attempts (ignore)
├── dir-listing               # Listing generator script
├── review-dir-listings       # Comparison script
├── verify-copies             # Orchestrator (NEEDS UPDATE for new topology)
├── size-missing-files        # Size summarizer
├── df-mon                    # Disk space checker (NEEDS UPDATE: remove caemlyn)
└── new                       # 504MB file — appears to be another volume listing
```

### Snapshots
Before modifying this tree, always take a snapshot:
```bash
rsync -av /export/personal/technical/nas-xfer/ \
    /export/backup/snapshots/nas-xfer/$(date +%Y%m%d)/
```
Existing snapshots: `20250917`, `20260403`


## What State Things Are In (April 2026)

Read `state-of-affairs-20260404.md` for the full breakdown.  The short version:

### Already on Nakama (verified)
- **archive** (1.1TB) — fully migrated
- **homes** (156G) — migrated from Haven, verified, Haven copy deleted
- **camera** (69G) — on Nakama + Syncthing-synced (Haven/Avalir)
- **music** (154G) — on Nakama + Syncthing-synced (Haven/Avalir)
- **proj** (1.1G) — on Nakama + Syncthing-synced (Haven/Avalir)
- **rpg** (33G) — on Nakama + Syncthing-synced (Haven/Avalir)
- **work** (6.8G) — only on Nakama now
- **sync_hist** (510G) — verified against Zadash and Haven

### Partially on Nakama (gaps to close)
- **backup** — 40G on Nakama, 86G on Haven.  Gap is in `snapshots/` (46G),
  plus `git/` (58M) and `proj/` (2M) absent from Nakama
- **personal** — 7.7G on Nakama vs 9.3G on Haven.  ~1.5G gap, mostly
  nas-xfer listing files + small thunderbird/ai/financial deltas

### Haven cleanup needed
- `/export/synology-sync_hist` — 12G, Taaveren leftover (verified, deletable)
- `/var/tmp` — 72G of old staging/backup/test data (all appears deletable)

### Important: Syncthing-synced shares stay on Haven
backup, camera, music, personal, proj, rpg, work are all Syncthing-synced
between Haven and Avalir.  These are live data — do NOT delete from Haven.


## Recommended Next Steps

In priority order:

### 1. ~~Migrate homes to Nakama~~ DONE (2026-04-04)
Transferred 108,487 files (166.8GB) from Haven to Nakama.  Verified with
`review-dir-listings synology-homes-haven.list homes-nakama.list` — 0 gaps.
Haven's `/export/synology-homes` has been deleted.

### 2. ~~Verify sync_hist: Nakama vs Zadash~~ DONE (2026-04-04)
Filled personal gap (1,335 files, 9.9GB) and proj gap (7,220 files, 160MB)
from Zadash.  Both verified clean.

### 3. ~~Verify sync_hist: Nakama vs Haven~~ DONE (2026-04-04)
Compared Haven's synology-sync_hist (7,031 files) against Nakama's sync_hist
(388,757 files).  51 files (336M) missing from Nakama — all Syncthing
`.stversions` of music files (non-critical).  Haven's copy is deletable.

### 4. Clean Haven /var/tmp (~72G)
Old staging and test data.  The big items:
- `synology-camera/` (60G) — migration staging, camera already on Nakama
- `nas-backup/homes` (3.3G) — homes migration staging
- `avalir-backup/` (3.9G), `sandbox-test/` (3.3G), `braavos-backup/` (1.1G)
- Various smaller items (~1G combined)

### 5. Delete `/export/synology-sync_hist` on Haven (12G)
Verified — only 336M of music stversions not on Nakama.

### 6. Close the backup/snapshots gap (~46G)
```bash
# From Haven or Avalir:
rsync -avzh --progress \
    -e "ssh -p 2322 -l nami" \
    /export/backup/snapshots/ nakama:/share/backup/snapshots/
```
Also transfer `backup/git/` (58M) and `backup/proj/` (2M).

### 7. Top up personal (~1.5G)
Use `nasupdate` from Avalir:
```bash
nasupdate -R personal
```

### 8. Update the toolchain
- `verify-copies` is configured for the old Taaveren topology — needs rewriting
- `df-mon` still references Caemlyn — should be updated
- `dir-listing` doesn't handle Nakama's SSH port (2322) — either add support
  or document the workaround


## Safety Rules

1. **Never delete without verification.**  Always generate listings and run
   comparisons before removing any data.
2. **Snapshot this tree before modifying it.**  The scripts, listings, and
   logs are the audit trail.
3. **Dry-run first.**  `nasupdate` does this automatically.  For raw rsync,
   always add `-n` first.
4. **Check disk space before large transfers.**  Use `df -h` on both source
   and destination.  Nakama has ~911G free as of 2026-04-03, but verify.
5. **Zadash is unreliable.**  Don't count on it being available.  If you
   need data from Zadash, grab it sooner rather than later.
6. **The user must approve any destructive action.**  Copying data to Nakama
   is constructive and safe.  Deleting from Haven/Avalir is destructive and
   requires explicit approval.


## Gotchas Summary

| Gotcha | Details |
|--------|---------|
| tcsh on remote shells | Haven/Avalir/Zadash use tcsh.  Wrap in `bash -c` |
| Nakama du reports 0 | Use `/share/CACHEDEV1_DATA/...` not `/share/...` for `du` |
| Nakama SSH port | Port 2322, user nami: `ssh -p 2322 nami@nakama` |
| BusyBox on Nakama | No `sort -h`.  Use `sort -n` or `sort -rn` |
| Large listing files | volume1-taaveren.list is 488MB.  Don't `cat` it. |
| QNAP metadata dirs | `@Recently-Snapshot`, `@Recycle` — filter these out like Synology's `@eaDir` and `#recycle` |
| verify-copies is stale | Configured for old topology.  Don't run as-is. |
| Syncthing .stfolder | Empty marker dirs in synced shares.  Ignore them. |
| Path mismatches | Haven uses `synology-` prefixes (e.g., `/export/synology-homes`); Nakama uses bare names (`/share/homes`).  review-dir-listings `from=to` args handle this. |

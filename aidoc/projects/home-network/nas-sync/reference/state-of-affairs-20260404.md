# NAS Migration State of Affairs — 2026-04-04

Previous: [state-of-affairs-20260403.md](state-of-affairs-20260403.md)

## What Changed Today

### homes: MIGRATED to Nakama (was CRITICAL)
- **108,487 files, 166.8GB** transferred from Haven to Nakama
- rsync ran on Haven directly to Nakama (LAN, ~10 MB/s, 4h 30m)
- rsync flags: `-a --no-o --no-g --no-p -u` with standard excludes (cribbed from nasupdate)
- **Verified: 0 missing files** via `review-dir-listings synology-homes-haven.list homes-nakama.list`
- Haven's `/export/synology-homes` can be deleted after manual re-verification (~156G freeable)

### sync_hist/personal: GAP CLOSED (was HIGH)
- **1,335 files, 9.9GB** transferred from Zadash to Nakama
- Pre-transfer comparison showed 8.8G gap (mostly Thunderbird `.stversions`)
- **Post-transfer verified: 0 missing files**

### sync_hist/proj: GAP CLOSED
- **7,220 files, 160MB** transferred from Zadash to Nakama
- **Post-transfer verified: 244 bytes** of `.stfolder` markers (intentionally excluded)

### Nakama disk space
- Before: 911G free (68% used)
- After: **746G free (74% used)**
- homes: 156G, sync_hist: 510G (was 501G)

## Listing Files Created

All in `/export/personal/technical/nas-xfer/`:
- `synology-homes-haven.list` — Haven homes pre-transfer (108,487 lines)
- `homes-nakama.list` — Nakama homes post-transfer (108,494 lines, +7 QNAP system files)
- `homes-verify.log` — Verification output (empty = clean)
- `personal-zadash.list` — Zadash sync_hist/personal (13,015 lines)
- `personal-nakama.list` — Nakama sync_hist/personal post-transfer (13,015 lines)
- `personal-sync_hist-verify-post.log` — Verification output (empty = clean)
- `proj-zadash.list` — Zadash sync_hist/proj (64,242 lines)
- `proj-nakama.list` — Nakama sync_hist/proj post-transfer (57,499+ lines)
- `proj-sync_hist-verify-post.log` — Verification output (244 bytes .stfolder only)

## Updated Per-Share Overview

| Share | Orig | Nakama | Haven | Avalir | Zadash | Status |
|-------|------|--------|-------|--------|--------|--------|
| archive | 305 | 1,100 | — | — | — | ON NAKAMA |
| backup | 248 | 40 | 86 | 86 | — | PARTIAL — snapshots gap (47G) |
| camera | 67 | 69 | 69 | — | — | ON NAKAMA + Haven |
| **homes** | 345 | **156** | 156 | — | — | **MIGRATED** — verified on Nakama |
| music | 145 | 154 | 155 | 156 | — | ON NAKAMA + Haven + Avalir |
| personal | 3.1 | 7.7 | 9.2 | 9.2 | — | PARTIAL — ~1.5G gap |
| proj | 1.8 | 1.1 | 1.1 | 1.1 | — | ON NAKAMA + Haven + Avalir |
| rpg | 25 | 33 | 33 | 33 | — | ON NAKAMA + Haven + Avalir |
| **sync_hist** | 898 | **510** | 12 | — | 504 | **VERIFIED** — Nakama ≥ Zadash |
| work | 5.7 | 6.8 | ~0 | — | — | ON NAKAMA |

## Updated Risk Assessment

### RESOLVED
- ~~**homes** — migrated and verified on Nakama~~
- ~~**sync_hist gaps** — personal and proj gaps filled and verified~~

### MEDIUM — Incomplete Migration
1. **backup** — Only 40G on Nakama vs 86G on Haven. Gap is in `snapshots/` (~47G).
2. **personal** — 7.7G on Nakama vs 9.2G on Haven/Avalir. Missing ~1.5G.

### LOW — Redundant (freeable space)
3. **homes on Haven** — 156G now redundant, freeable after manual verification
4. **music** — on all three servers (~155G each). Could free on Haven or Avalir.
5. **camera** — on Nakama and Haven (69G each). Could free on Haven.
6. **proj, rpg** — on all three servers. Could free ~34G each.
7. **sync_hist on Zadash** — 504G now redundant (Nakama has 510G, verified)

### synology-sync_hist on Haven: VERIFIED (mostly)
- Compared Haven's `/export/synology-sync_hist` (7,031 files, 12G) against Nakama's `/share/sync_hist` (388,757 files, 510G)
- **51 files (336M) missing from Nakama** — all Syncthing `.stversions` under `music/stversions/`
- These are version history files (old versions of music tracks), not primary data
- The current music files themselves are safe in the music share on all servers
- Haven's synology-sync_hist is safe to delete (or transfer the 336M of stversions first if desired)
- Listing files: `synology-sync_hist-haven.list`, `sync_hist-nakama.list`, `synology-sync_hist-verify.log`

### synology-homes on Haven: DELETED
- User already removed `/export/synology-homes` after earlier verification
- 156G freed on Haven

## Haven Directory Classification

**Key insight**: All directories under `/export/` that DON'T have a `synology-` prefix
are **Syncthing-synced** between Haven and Avalir (confirmed via `.stfolder` markers).
These are live data and should NOT be deleted from Haven.

| Directory | Size | Syncthing? | Disposition |
|-----------|------|------------|-------------|
| `/export/music` | 155G | YES | Stays on Haven |
| `/export/backup` | 85G | YES | Stays on Haven |
| `/export/camera` | 68G | YES | Stays on Haven |
| `/export/rpg` | 33G | YES | Stays on Haven |
| `/export/synology-sync_hist` | 12G | NO | **Deletable** (Taaveren leftover, verified) |
| `/export/personal` | 9.3G | YES | Stays on Haven |
| `/export/proj` | 1.1G | YES | Stays on Haven |
| `/export/work` | ~0 | YES | Stays (empty shell) |

Only item remaining to clean from `/export/`: `synology-sync_hist` (12G).

## Haven /var/tmp Cleanup

72G of old staging/backup/test data in `/var/tmp/` on Haven:

| Directory | Size | Date | Contents | Notes |
|-----------|------|------|----------|-------|
| `synology-camera/` | 60G | Feb 2025 | Camera photos by year | Migration staging area; camera already on Nakama + Syncthing-synced |
| `avalir-backup/` | 3.9G | Jun 2025 | Chrome config backups | |
| `nas-backup/` | 3.3G | Feb 2025 | `homes` subdirectory | Homes migration staging; homes already on Nakama |
| `sandbox-test/` | 3.3G | Jun 2024 | archer-boot, aws, CE, cheops, perl-cpm | Work test artifacts |
| `braavos-backup/` | 1.1G | Jul 2020 | `etc` directory | Ancient backup of decommissioned server |
| `compare/` | 627M | Mar 2024 | common/leadpipe/slides comparisons (bb2 vs zadash) | Old comparison work |
| `launch-projects/` | 351M | Jun 2024 | Launch project data | |
| `VCtools-extlib/` | 22M | Oct 2023 | | |
| `CR/` | 18M | Nov 2023 | | |
| Small files & systemd dirs | ~1M | Various | okular, swap files, misc | |

**Total freeable**: ~72G (all appear safe to delete after user review)

## Updated Per-Share Overview

| Share | Orig | Nakama | Haven | Avalir | Zadash | Status |
|-------|------|--------|-------|--------|--------|--------|
| archive | 305 | 1,100 | — | — | — | ON NAKAMA |
| backup | 248 | 40 | 86 | 86 | — | PARTIAL — snapshots gap (~46G) |
| camera | 67 | 69 | 69 | 69 | — | ON NAKAMA + Syncthing (Haven/Avalir) |
| **homes** | 345 | **156** | **gone** | — | — | **ON NAKAMA** — Haven copy deleted |
| music | 145 | 154 | 155 | 156 | — | ON NAKAMA + Syncthing (Haven/Avalir) |
| personal | 3.1 | 7.7 | 9.3 | 9.2 | — | PARTIAL — ~1.5G gap to Nakama |
| proj | 1.8 | 1.1 | 1.1 | 1.1 | — | ON NAKAMA + Syncthing (Haven/Avalir) |
| rpg | 25 | 33 | 33 | 33 | — | ON NAKAMA + Syncthing (Haven/Avalir) |
| **sync_hist** | 898 | **510** | 12 | — | 504 | **VERIFIED** — Haven 51 files (336M stversions) not on Nakama |
| work | 5.7 | 6.8 | ~0 | — | — | ON NAKAMA |

## Updated Risk Assessment

### RESOLVED
- ~~**homes** — migrated, verified, Haven copy deleted~~
- ~~**sync_hist gaps** — personal and proj gaps filled from Zadash; Haven verified (51 stversion files, 336M, non-critical)~~

### MEDIUM — Incomplete Migration to Nakama
1. **backup/snapshots** — 17.8G on Nakama vs 63.6G on Haven. ~46G gap. Breakdown of Haven snapshots:
   - screen-buflog: 23.8G
   - config: 18.0G
   - nas-xfer: 9.8G (snapshots of this project)
   - camera: 5.7G
   - thunderbird: 3.4G
   - purple: 1.9G
   - proj: 828M
   - caemlyn-20260224: 171M (last snapshot of decommissioned server)
   - chrome-export: 34M, notes/etc/common: ~6M
2. **backup/git** (58M) and **backup/proj** (2M) — exist on Haven only, absent from Nakama
3. **personal** — 7.7G on Nakama vs 9.3G on Haven. ~1.5G gap, mostly nas-xfer listing files (1.4G) plus small deltas in thunderbird (95M), ai (22M), financial (19M), blog (5M), medical (4M)

### LOW — Cleanup (freeable space)
4. **Haven `/export/synology-sync_hist`** — 12G, deletable (verified, only 336M stversions gap)
5. **Haven `/var/tmp`** — 72G of old staging/backup/test data, all appears deletable
6. **Zadash `/srv/sync_hist`** — 504G, redundant with Nakama (once Graymoor replaces Zadash)

## Recommended Next Steps

1. **Clean Haven `/var/tmp`** — 72G freeable, all old staging data. User should review and approve deletions.
2. **Delete `/export/synology-sync_hist`** on Haven — 12G, verified (optionally transfer 336M of music stversions to Nakama first)
3. **Transfer backup/snapshots** from Haven to Nakama (~46G) to close the biggest remaining gap
4. **Sync personal to Nakama** — `nasupdate -R personal` from Avalir (~1.5G)
5. **Transfer backup/git and backup/proj** to Nakama (~60M)
6. Eventually: free Zadash sync_hist (504G) once Graymoor replaces Zadash

## Server Inventory (updated)

| Server | Disk | Used | Free | Notes |
|--------|------|------|------|-------|
| **Nakama** | 2.8TB | 2.1TB | **744GB** | homes + sync_hist gaps filled |
| **Haven** | 938GB | **364GB** | **527GB** | synology-homes deleted (+156G); 84G more freeable (sync_hist + /var/tmp) |
| **Avalir** | 913GB | 555GB | 312GB | Unchanged |
| **Zadash** | 915GB | 612GB | 257GB | sync_hist now redundant with Nakama |

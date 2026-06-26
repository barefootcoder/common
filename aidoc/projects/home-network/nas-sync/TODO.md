# NAS Sync -- Outstanding Tasks

Deferred work for the [nas-sync](README.md) subproject. **The master sequence
is [roadmap.md](roadmap.md); run `bin/whats-next` to see the next action.**
This file holds items that don't slot cleanly into the phase order, plus dated
items.

This TODO is deliberately separate from `home-network/TODO.md` so NAS-sync work
doesn't churn that hot, multi-agent file. **Put new NAS-sync deferred work
here, not there.**

## Outstanding

- **anytime (gates Phase 2 execution in auto mode)** -- Build `bin/nas-reclaim`,
  a verified-deletion tool. Auto-mode blocks raw `rm`, so every reclamation
  (Phase 2 Haven cleanups, and later source-deletion after a verified migration)
  must go through one allowlisted script that (a) accepts only internally
  allowlisted targets, (b) re-runs the appropriate verification for that target,
  (c) deletes only if it passes, (d) honors `--noaction` as the first arg
  (preview, deletes nothing) per the repo's command-safety convention, (e) logs
  everything. Then allowlist it in settings so it runs un-prompted. See README
  "Verified deletion". _(added 2026-06-19 at session establishing the plan)_

- **2026-06-22** -- Deep-archival B2 change-scan cost (part of roadmap P4): once
  the Nakama->B2 rclone job exists, measure how long an `archive` (~1.1TB)
  change-scan takes. Cheap -> nightly; slow enough to crowd active syncs ->
  weekly/monthly. _(added 2026-06-19)_

- **anytime** -- Toolchain debt in `bin/`: `verify-copies` is still wired for the
  dead Taaveren topology (rewrite for Nakama-centric, or retire in favor of
  per-share `review-dir-listings`); `df-mon` still pings decommissioned Caemlyn
  (drop it, add Graymoor when up); `dir-listing` doesn't know Nakama's SSH port
  2322 (add support or document the workaround). _(added 2026-06-19)_

- **anytime** -- Decide archival-share versioning: Zadash versions `camera` but
  not `backup`. When Graymoor is built, decide whether to add `backup` to the
  staggered-versioning set (cheap -- it changes rarely -- and protective).
  _(added 2026-06-19)_

- **anytime** -- Confirm the Linux-mesh cadence for archival shares
  (`backup`,`camera`): leave them continuous Syncthing (current, ~free when
  idle) or set them periodic (fsWatcher off + long rescan) to match the tier
  spec literally. README "Sync mechanisms" flags this as the user's call.
  _(added 2026-06-19)_

- **anytime** -- Evidence-dir cleanup at `/export/personal/technical/nas-xfer/`:
  `new` (504M) is a stale listing of the dead Taaveren Synology -- safe to delete
  or gzip to keep the historical record small; `.tester.swp` is a stray vim swap
  (disposable). Both are cruft, not data. Route through `nas-reclaim` or hand to
  the user (auto-mode can't `rm`). _(added 2026-06-19)_

- **blocked on Graymoor** -- Read Graymoor's disk capacity (the gating unknown
  for Phase 6): it must hold the important + camera shares live plus the full
  `sync_hist` version history (504G+ and growing). Can't be checked until it's
  on the network. _(added 2026-06-19)_

### Migrated from home-network/TODO.md (2026-06-20)

Full entries moved here from the hot file so main-project agents don't contend
over them.

- **anytime** -- Nightly rclone cron Nakama -> B2 (`barefoot-common/nakama/...`).
  Approach agreed: rclone + QNAP `/etc/config/crontab` (NOT makeln). Script +
  cron entry version-controlled under `conf/crontab/`, plus a one-time manual
  install on Nakama. Excludes `**/@Recently-Snapshot/**`, `**/.@__thumb/**`,
  `**/.qpkg/**`. rclone.conf already on Nakama (fire-evac-recovery.md). **==
  roadmap P4.** _(added 2026-05-24 fire-evac; migrated 2026-06-20)_

- **anytime** -- Back up remaining Avalir survey gaps (identified 2026-05-22):
  `~/.config/` (minus vivaldi), `~/.local/` (1.8 GB), `~/Downloads/`,
  `~/.thunderbird-fresh/`, `/root/`, `/etc/`, Haven host-unique (`~/Insync/`
  35 GB, `~/local/`, `~/.ssh/`, `~/.mozilla/`), `/var/lib/docker/` if unique.
  `~/.purple/` already done. Sources that should reach Nakama then B2. **== P4
  scope.** _(added 2026-05-24 fire-evac; migrated 2026-06-20)_

- **anytime** -- `~/.config/` cleanup: delete `vivaldi-install/` (115 MB, 2023,
  defunct), likely-safe `chromium-crippled/` (464 MB), borderline
  `google-chrome/` (176 MB); user confirms before deletion. A reclamation
  candidate -- could become a `nas-reclaim` target. _(added 2026-05-24 fire-evac;
  migrated 2026-06-20)_

- **anytime** -- Nakama `/share/{music,camera,rpg}` B2 sweep: extra subdirs on
  Nakama (`music/{Christy,Danny,Dreamtime}`) not on Avalir, so not yet uploaded;
  sweep under `barefoot-common/nakama/` eventually. **== P4 scope.** _(added
  2026-05-24 fire-evac; migrated 2026-06-20)_

- **anytime** -- Nakama firmware update to 5.2.9.3499 (build 20260514) is FAILING:
  it reverts to 5.2.7 on reboot but still breaks the `/share/homes` symlink (full
  key-auth lockout) on each attempt. NOT blocking Phase 3 -- Container Station
  installs to the data volume and runs fine on 5.2.7. Before retrying: read
  QuLog Center -> System Event Log for the failure reason and free space on
  `/mnt/ext` (was 92% full). Full writeup: home-network
  `nakama-firmware-update-fixes.md` Issue 3. _(added 2026-06-20 during Container
  Station prep)_

### Phase 3 (Nakama receive-only Syncthing mirror) -- COMPLETE 2026-06-25

**Phase 3 is DONE.** Container Station (QTS 5.2.7) + official Syncthing **v1.30.0**
container is up on Nakama: host network, receive-only, `PUID/PGID=0`, mounts
`/share/CACHEDEV1_DATA`->`/shares` and `.../.syncthing`->`/var/syncthing`,
`restart: unless-stopped`; joined to Haven + Avalir; GUI `http://nakama:8384`
(password set). All **7 shares** (music, personal, proj, rpg, work, backup, camera)
are added Receive Only at `/shares/<name>`, Ignore Permissions on, ignores `@Recycle`
/ `@Recently-Snapshot` / `.@__thumb` -- and **all 7 are now clean Up-to-Date
receive-only mirrors (0 local additions, 0 errors).** Full writeup:
[reference/nakama-syncthing-mirror-setup.md](reference/nakama-syncthing-mirror-setup.md).

The per-folder reconcile pattern that got us there (add ignores; characterize the
receive-only "local additions" as cruft vs real; **VERIFY before reverting** anything
real -- `work` held real 2021 clickout logs, only safe to drop because they're in B2;
then "Revert Local Changes" or a targeted `rm` to match the cluster) and every key
finding -- including the security finding about the unencrypted `Dropbox/sensitive/`
tree lingering on Nakama and in the B2 cleartext bucket -- are recorded in the
reference doc. The follow-ups it surfaced are the items below.

#### Phase 3 follow-ups + Phase 4 prep

- **NEXT** -- B2 deduplication cleanup (real recurring cost). Fire-evac backed up each
  machine independently, so synced shares sit in B2 twice: `barefoot-common/<share>`
  (Avalir) + `barefoot-common/nakama/<share>` (Nakama) -- ~250G of media duplication.
  Media dominates (music/camera/rpg, byte-identical -> prune one copy = the win);
  personal/work/proj differ (moved taxes, deleted clickout logs) so audit before
  pruning. Mind B2 versioning (hidden versions also bill). Run from Avalir (`b2`
  remote). _(added 2026-06-20)_

- Install rclone **persistently** on Nakama for Phase-4 B2 sync (QPKG / Container Station
  container / data-volume binary -- NOT the RAM-disk root; rclone was a bare binary in the
  RAM-disk root, which is rebuilt from firmware on every boot, so it vanished on reboot).
  _(added 2026-06-20)_

- Phase 4: back up Nakama->B2 as the **single source** (not per-machine) to stop
  re-creating the duplication. _(added 2026-06-20)_

- **security** -- verify the B2 plaintext `Dropbox/sensitive` purge removed all VERSIONS,
  not just current (`rclone lsf --b2-versions` / B2 web console). The unencrypted tree
  (scanned checks, browser passwords, google-auth, ec2 creds, backup keys) was found
  still on Nakama and in the B2 cleartext paths `barefoot-common/personal/` and
  `barefoot-common/nakama/personal/`; it was removed/purged, but B2 keeps versions, so
  confirm none survive. The intended encrypted copy at `b2-crypt:personal-dropbox-sensitive`
  is retained. _(added 2026-06-20)_

- Clean the ~211 cluster-resident `.sync-conflict` files on the **source** shares
  (Avalir/Haven). These are years of Haven<->Avalir conflict cruft living on the live
  `personal` share (so they ride along to Nakama + B2); a source-side cleanup, not a
  Nakama issue. _(added 2026-06-25)_

- Relocate the `nas-xfer` migration-evidence dir (~600M incl. the 527M `new` file) out of
  the synced `personal` share into `backup/`/`archive/`. As long as it lives in `personal`
  it rides to Nakama + B2 -- bulky regenerable tooling that doesn't belong there. (See also
  the older "Evidence-dir cleanup" item above for the per-file cruft within it.)
  _(added 2026-06-25)_

- Audit "what else went missing from the live shares?" -- the receive-only mirror surfaces
  deleted/moved content (clickout logs [in B2], Taxes [moved, fine], ballot/drafts files
  [moved], Skyrim soundtrack [renamed], incoming zips [unpacked+filed], Dropbox/sensitive
  [intentional]); everything found so far was explainable, but confirm nothing important
  was actually lost from live. _(added 2026-06-20)_

- Optional: normalize Nakama share ownership (music/camera admin-owned vs rest nami;
  cosmetic migration artifact, harmless). _(added 2026-06-20)_

## Done

- ~~2026-06-19~~ -- Establish the nas-sync subproject: end-state architecture
  (README), phased roadmap (roadmap.md), the `whats-next` probe (hybrid model),
  this TODO, toolchain copied to `bin/`, reference snapshots preserved. Replaces
  the one-off `/export/personal/technical/nas-xfer/` workspace (now demoted to a
  non-versioned evidence dir). _(added + completed 2026-06-19)_

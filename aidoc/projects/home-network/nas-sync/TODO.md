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

## Done

- ~~2026-06-19~~ -- Establish the nas-sync subproject: end-state architecture
  (README), phased roadmap (roadmap.md), the `whats-next` probe (hybrid model),
  this TODO, toolchain copied to `bin/`, reference snapshots preserved. Replaces
  the one-off `/export/personal/technical/nas-xfer/` workspace (now demoted to a
  non-versioned evidence dir). _(added + completed 2026-06-19)_

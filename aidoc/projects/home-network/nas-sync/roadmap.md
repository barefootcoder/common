# NAS Sync Roadmap

The ordered plan from where we are to the [end-state](README.md). This is the
**map** that `bin/whats-next` walks: each step lists a *cheap probe signal* for
done/not-done and any *gating*. Keep this file and reality in agreement -- when
a step's situation changes, edit its **Reading** line (and let `whats-next`
confirm via probe).

`whats-next` reports the highest-priority step that is both **incomplete** and
**unblocked** as the single NEXT action, and lists the rest for context.

Priority order (the canonical sequence the script uses):
**P1 -> P4 -> P3 -> P5 -> P1c -> P2 -> P6 -> P7.** Rationale: complete the
on-NAS dataset first (P1), get it offsite (P4, the disaster keystone), make NAS
currency automatic (P3), then watch it (P5); space reclaim (P2) is a low-urgency
quick win gated on P1 verification; Graymoor (P6/P7) is blocked until it is on
the network.

Legend: **[DONE]** **[TODO]** **[BLOCKED]** -- status as of **2026-06-25**
(Phase 3 complete; per-step *Reading* lines below still dated 2026-06-19).

---

## Phase 0 -- Foundation [DONE 2026-06-19]

Establish this subproject (README, roadmap, `whats-next`, TODO), copy the
toolchain, tidy the old evidence dir. Done in the session that created this file.

---

## Phase 1 -- Complete the Nakama dataset  [TODO]

**Goal:** Nakama holds a full, current copy of every share, so B2 (Phase 4) then
captures everything. Constructive (copy-only), no approval needed. Unblocks
Phase 2.

### P1a -- backup/snapshots -> Nakama  [TODO]
- **Step:** transfer `/export/backup/snapshots/` (Haven) to
  `nakama:/share/backup/snapshots/`. Prefer initiating detached on the source
  box (Haven or Avalir, both hold it via Syncthing).
- **Probe:** `du -sb` of `backup/snapshots` on Haven vs
  `/share/CACHEDEV1_DATA/backup/snapshots` on Nakama; DONE when Nakama >= ~95%
  of Haven.
- **Reading 2026-06-19:** Haven 72G, Nakama 18G -> **~54G gap**. Largest bits:
  `config` 26G, `screen-buflog` 24G, `nas-xfer` 9.8G.

### P1b -- backup/git + backup/proj -> Nakama  [TODO]
- **Step:** copy `/export/backup/git` (~58M) and `/export/backup/proj` (~2M) to
  Nakama.
- **Probe:** presence + nonzero size of `/share/CACHEDEV1_DATA/backup/{git,proj}`.
- **Reading 2026-06-19:** absent from Nakama (its `backup/` has install,
  browser-sessions, snapshots, music, local, sandbox-repo only).

### P1c -- personal top-up  [TODO, low priority]
- **Step:** close the real `personal` delta to Nakama (thunderbird ~95M, ai
  ~22M, financial ~19M, etc.). **Exclude the nas-xfer listing files** -- most of
  the headline "1.5G gap" is those, and they do not belong on Nakama.
- **Probe:** cheap size probe is misleading here (listing-file noise); confirm
  with the toolchain (`review-dir-listings` on `personal`) before acting.
- **Reading 2026-06-19:** Nakama 7.7G vs Avalir/Haven ~9.3G; real delta small.
- **Note:** once Phase 3 makes Nakama a live peer, `personal` stays current
  automatically and this step disappears. Low priority for that reason.

---

## Phase 2 -- Reclaim Haven space  [TODO, needs user approval]

**Goal:** free the redundant/stale data on Haven. Destructive -> explicit
approval required. **Gated on Phase 1 verification** for anything that overlaps
(snapshots), but the two big items below are already verified-redundant.
Low urgency (Haven has 519G free). **All deletes below run through
`nas-reclaim` (P2-pre), not raw `rm`.**

### P2-pre -- build & allowlist `nas-reclaim`  [TODO]
- Prerequisite for executing *any* deletion in auto/background mode (the safety
  classifier blocks raw `rm`). The verified-deletion tool from README "Verified
  deletion": allowlisted targets only, re-verifies at delete time, `--noaction`
  first, logs everything. Until it exists, Phase 2 deletes can only be done by
  the user by hand.
- **Probe:** `bin/nas-reclaim` exists and is executable.

### P2a -- delete `/export/synology-sync_hist` (Haven, ~12G)  [TODO]
- Verified deletable (only 336M of music `.stversions` were ever missing from
  Nakama; optionally push those first). Taaveren leftover, not synced.
- **Probe:** directory absent on Haven.
- **Reading 2026-06-19:** still present, 12G.

### P2b -- clean Haven `/var/tmp` (~73G)  [TODO]
- Old staging/test data: `synology-camera` 60G (camera long since on Nakama),
  `avalir-backup` 3.9G, `sandbox-test` 3.3G, `nas-backup` 3.3G,
  `braavos-backup` 2.2G, plus smaller. All flagged deletable-after-review.
- **Probe:** `du -sb /var/tmp` on Haven below a sane floor (say < 5G).
- **Reading 2026-06-19:** 73G.

---

## Phase 3 -- Nakama as a live receive-only peer  [DONE 2026-06-25]

**Goal:** the important shares reach Nakama near-real-time (not just via manual
`nasupdate`). Unblocked.

- **Decision (see README "Sync mechanisms"):** stand up **Syncthing in
  Container Station** on the TS-364 as a **receive-only** peer for the
  important + archival shares (recommended); fall back to a short-interval
  `nasupdate`/rsync cron if containerized Syncthing proves heavy or
  version-fragile. The rsync cron is also the acceptable interim.
- **Steps:** install Container Station via QTS App Center (**user; GUI step**),
  then create the Syncthing container; add Nakama to the cluster receive-only;
  share the folders; verify completion. (Container creation is GUI; ongoing
  Syncthing config is SSH/docker-manageable afterward.)
- **Probe:** a Syncthing process (or container) running on Nakama, **or** an
  installed `nasupdate` sync cron in Nakama's `/etc/config/crontab`.
- **Reading 2026-06-19:** neither present (no Syncthing, no Container Station;
  only QPKG is MalwareRemover). Nakama is fed only by manual `nasupdate`.

**[DONE 2026-06-25]** Container Station (QTS 5.2.7, App Center) plus an official
`syncthing/syncthing:1.30.0` container is up on Nakama -- pinned to v1.30.0 to
match the cluster's deliberate `noupgrade` pin (a `latest` would have
reintroduced the documented v1<->v2 split). Container: `network_mode: host`,
`PUID=0`/`PGID=0` (root, since music/camera are admin-owned and the rest
nami-owned), `STGUIADDRESS=0.0.0.0:8384`, volumes
`/share/CACHEDEV1_DATA`->`/shares` and `.../.syncthing`->`/var/syncthing`,
`restart: unless-stopped`, GUI password set; joined to Haven + Avalir. All 7
shares (music, personal, proj, rpg, work, backup, camera) are added as **Receive
Only** at `/shares/<name>`, Ignore Permissions on, ignore patterns
`@Recycle`/`@Recently-Snapshot`/`.@__thumb`. Each folder was reconciled from its
months-old rsync-seed (characterize local-additions, verify-before-revert, then
revert/delete to match the cluster); all 7 are now clean Up-to-Date receive-only
mirrors (0 local additions, 0 errors). Full writeup:
[reference/nakama-syncthing-mirror-setup.md](reference/nakama-syncthing-mirror-setup.md).
Open follow-ups (B2 dedup, persistent rclone, single-source Phase-4, security
version-purge verification, source-side `.sync-conflict` cleanup) are tracked in
[TODO.md](TODO.md).

---

## Phase 4 -- Nakama -> B2 ongoing sync  [TODO]  *(disaster keystone)*

**Goal:** everything on Nakama is pushed to B2 on a schedule, never-delete
semantics. The fire-evac backup (May 2026) was a one-time push; this makes it
continuous. Long-standing item on the home-network TODO. Unblocked.

- **Steps:**
  1. rclone job per the README "B2 policy": `rclone sync` against
     lifecycle-keep-all buckets (so nothing is ever truly deleted), reusing
     `barefoot-common` (cleartext) and `barefoot-encrypted` (crypt). `personal`
     -> cleartext for now.
  2. Excludes: `**/@Recently-Snapshot/**`, `**/.@__thumb/**`, `**/.qpkg/**`,
     `**/@Recycle/**`.
  3. **Measure the deep-archival change-scan cost** (`archive` ~1.1TB): if
     cheap, sync nightly; if slow enough to crowd out important syncs, drop
     `archive`/`homes` to weekly/monthly. Active shares: no less than daily.
  4. Script + cron entry version-controlled under `conf/crontab/`; install on
     Nakama via QNAP `/etc/config/crontab` (**not** makeln). rclone.conf already
     present on Nakama per `fire-evac-recovery.md`.
- **Probe:** an rclone sync cron present in Nakama's `/etc/config/crontab` and a
  recent successful run in its log.
- **Reading 2026-06-19:** no recurring cron (fire-evac was manual/one-time).

---

## Phase 5 -- Monitoring + verification  [TODO, incremental]

**Goal:** catch sync/backup degradation before it bites. Can land piecemeal.
Unblocked.

- **P5a -- Syncthing health check:** poll each node's folder-completion via the
  REST API; alert on a folder stuck out-of-sync. Build on `synudge` /
  `syncthing-troubleshooting.md`.
- **P5b -- B2 cron health:** alert on failed/missed nightly run.
- **P5c -- QNAP email triage:** surface IHM/critical Nakama alert emails out of
  the noise (now that email access is wired up); `parse-nakama-alerts.pl`
  already extracts the message body.
- **P5d -- scheduled test-restore:** periodically pull a sample from B2 and diff
  against source.
- **P5e -- Nakama disk-threshold watch** against the 80% line.
- **Probe:** presence of the respective scripts/crons. Partial credit allowed.
- **Reading 2026-06-19:** none automated (manual Syncthing-UI checks; QNAP
  emails ignored as noise).

---

## Phase 6 -- Graymoor: the version authority  [BLOCKED: Graymoor not on network]

**Goal:** Graymoor replaces Zadash as the Syncthing version-history holder and
joins the mesh. Tracked for network-bring-up in the **main home-network
project** (NanoKVM assembly, SSH/Tailscale/Syncthing). This phase begins once
Graymoor answers on the network.

- **Gate probe:** Graymoor reachable (`ssh graymoor true`).
- **Steps (once reachable):**
  1. **Read its disk capacity** (the deferred unknown). It must hold the
     important + camera shares *live* plus the full staggered version history
     (`sync_hist` is 504G+ and only grows). ~900G expected; confirm.
  2. Install Syncthing **receive-only** + `staggered` versioning `maxAge=0`,
     replicating Zadash's folder set (5 important + camera). Receive-only is the
     one improvement over Zadash's `sendreceive` (Graymoor is never hand-edited).
  3. **Migrate the version history Zadash -> Graymoor** (user's choice; Nakama's
     verified 510G copy is the fallback if Zadash dies first).
  4. Add Graymoor to the mesh and stand up the periodic
     `sync_hist` Graymoor -> Nakama rsync leg.
- **Probe:** Graymoor reachable + Syncthing folders present + `sync_hist`->Nakama
  leg installed.
- **Reading 2026-06-19:** Graymoor not on the network. **Keep Zadash alive and
  collecting** in the meantime (it was up 34 days at last check) so the data to
  migrate keeps existing.

---

## Phase 7 -- Retire Zadash  [BLOCKED: depends on Phase 6 complete + verified]

**Goal:** decommission Zadash's sync role once Graymoor demonstrably holds the
full version history; then assess Zadash's (unreliable) hardware for any reuse.

- **Gate probe:** Phase 6 complete and Graymoor's version history verified
  against Zadash/Nakama.
- **Steps:** stop Syncthing on Zadash; confirm nothing relies on it; evaluate
  hardware reliability for a possible second life.
- **Reading 2026-06-19:** blocked; Zadash remains the live authority.

---

## Steady state (all phases complete)

`whats-next` reports "steady state": ongoing monitoring (Phase 5), periodic
re-verification and test-restores, and capacity watch (the RAID-1 second-drive
contingency if Nakama tightens against 80%). No structural work outstanding.

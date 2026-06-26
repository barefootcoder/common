# Nakama Receive-Only Syncthing Mirror -- Setup + Reconcile (Phase 3)

**Status:** DONE 2026-06-25. All 7 shares are clean receive-only mirrors of the
live cluster (0 local additions, 0 errors).

This is the record of roadmap **Phase 3**: turning the QNAP NAS **Nakama** into
a receive-only Syncthing mirror of the live shares, so the important + archival
shares reach it near-real-time instead of via manual `nasupdate`. It covers what
was stood up (2026-06-20), the per-folder reconcile pattern and its hard lesson,
the key findings (including a security finding), and where the open follow-ups
live.

Parent docs: [../README.md](../README.md) (target architecture),
[../roadmap.md](../roadmap.md) (Phase 3 step), [../TODO.md](../TODO.md)
(follow-ups).

---

## What was stood up (2026-06-20)

Container Station was installed on Nakama via the QTS App Center (QTS 5.2.7, GUI
step). On top of it, an official `syncthing/syncthing:1.30.0` container:

- **Pinned to v1.30.0**, deliberately, to match the rest of the cluster's
  `noupgrade`-pinned v1.30.0. Using the `latest` tag would have pulled a v2
  Syncthing and reintroduced the documented v1<->v2 cluster split.
- `network_mode: host`
- `PUID=0` / `PGID=0` -- runs as **root**. Needed because the shares have mixed
  ownership: `music` and `camera` are admin-owned, the rest are nami-owned.
- `STGUIADDRESS=0.0.0.0:8384` so the GUI is reachable (`http://nakama:8384`,
  password set).
- Volumes: `/share/CACHEDEV1_DATA` -> `/shares` and
  `/share/CACHEDEV1_DATA/.syncthing` -> `/var/syncthing`.
- `restart: unless-stopped`.
- Joined to **Haven + Avalir**.

All **7 shares** were added as **Receive Only**:

| Share | Path | Notes |
|---|---|---|
| music | `/shares/music` | admin-owned on Nakama |
| personal | `/shares/personal` | |
| proj | `/shares/proj` | |
| rpg | `/shares/rpg` | |
| work | `/shares/work` | Avalir + Nakama only (Haven has no `work` copy) |
| backup | `/shares/backup` | |
| camera | `/shares/camera` | admin-owned on Nakama |

Each folder: **Ignore Permissions** on, with ignore patterns `@Recycle`,
`@Recently-Snapshot`, `.@__thumb` (the QNAP-side metadata dirs).

A note on the firmware: the attempted Nakama firmware update to 5.2.9.3499 keeps
failing and reverting to 5.2.7, but that did **not** block Phase 3 -- Container
Station installs to the data volume and runs fine on 5.2.7.

---

## The reconcile pattern (and the hard lesson)

Nakama's folders were not empty when added: they had been seeded months earlier
from an rsync migration copy. So when each was added receive-only, Syncthing
reported "local additions" -- files present on Nakama that are no longer on the
live cluster, because they had been moved, deleted, or cleaned up on the cluster
in the months since that migration snapshot.

A blind "Revert Local Changes" would have made Nakama match the cluster -- but it
also deletes anything in those local additions that is genuinely only-on-Nakama.
The hard lesson: **verify before reverting.** `proj`'s local additions were pure
cruft, safe to revert blindly. But `work` held real 2021 `ce/clickout-2022/` logs
that a blind revert would have destroyed -- they were only safe to drop once
confirmed preserved in B2.

The established per-folder pattern:

1. Add the QNAP ignore patterns (`@Recycle` / `@Recently-Snapshot` / `.@__thumb`).
2. Characterize the local-additions: cruft vs real data.
3. For anything **real**, verify it is preserved elsewhere (filed/moved on the
   cluster, or in B2) **before** touching it. This is a last-copy check.
4. Then reconcile to the cluster: "Revert Local Changes", or a targeted delete
   for a known-cruft subset.

`.sync-conflict` files are the common one-time reconciliation cruft. The ignore
patterns do not (and should not) catch them; Revert clears them. In general,
"migration leftovers" = whatever was moved/deleted/cleaned on the live cluster
since the rsync migration snapshot Nakama was seeded from.

---

## Key findings

Every migration-leftover turned out explainable. Nothing was lost.

- **work `ce/clickout-2022/` 2021 logs:** deleted from the live cluster, but
  preserved in B2 -> safe to drop from Nakama.
- **personal `financial/Taxes-20XX`:** MOVED on the cluster to
  `financial/Taxes/` -> the old per-year locations were stale.
- **personal `family/ballot.*.txt`:** MOVED to `family/vote-research/`.
- **music "Elder Scrolls V: Skyrim [Soundtrack]":** RENAMED on the cluster.
- **music `incoming/*.zip`:** the albums had already been unpacked and filed into
  `Albums/`, so the zips were redundant.

### Security finding (important)

The plaintext `Dropbox/sensitive/` tree -- scanned checks, browser passwords,
google-auth, ec2 creds, backup keys -- which the earlier crypt-vault migration had
*encrypted and wiped from the live cluster* -- was found **still lingering
UNENCRYPTED** in two places, both stale migration copies:

1. On **Nakama** (the months-old rsync seed still had it).
2. In the **B2 cleartext** bucket, at `barefoot-common/personal/` and
   `barefoot-common/nakama/personal/`.

It was removed from Nakama and purged from those B2 cleartext paths. **Open
caveat:** B2 keeps versions, so a follow-up must confirm the purge removed all
versions, not just the current ones. The intended encrypted copy at
`b2-crypt:personal-dropbox-sensitive` was retained -- that one is correct and
stays.

### Other observations surfaced along the way

- The live `personal` share carries ~211 accumulated `.sync-conflict` files --
  cluster-resident cruft from years of Haven<->Avalir conflicts. This is a
  separate **source-side** cleanup (on Avalir/Haven), not a Nakama issue; they
  ride along to Nakama + B2 only because they are on the live share.
- **rclone vanished from Nakama.** It had been a bare binary in the RAM-disk
  root, which is rebuilt from firmware on every boot. So the Phase-4 Nakama->B2
  sync must install rclone **persistently** (QPKG / Container Station container /
  data-volume binary).
- **B2 holds the synced shares twice.** The May 2026 fire-evac backed up each
  machine independently, leaving both `barefoot-common/<share>` (from Avalir) and
  `barefoot-common/nakama/<share>` (from Nakama) -- about 250 GB of media
  duplication. A prioritized cleanup.
- The `nas-xfer` migration-evidence dir (~600 MB, including a 527 MB `new` file)
  lives **inside** the synced `personal` share, so it rides along to Nakama and
  B2. Bulky regenerable tooling; should eventually be relocated out of `personal`
  into `backup/`/`archive/`.

---

## Final state

All 7 shares (music, personal, proj, rpg, work, backup, camera) are clean,
Up-to-Date, receive-only mirrors on Nakama: **0 local additions, 0 errors.**
Phase 3 is complete.

---

## Open follow-ups (tracked in TODO.md)

See [../TODO.md](../TODO.md) for the live list. In priority order, the items this
phase surfaced:

- **B2 deduplication cleanup (NEXT)** -- prune the doubled `barefoot-common/<share>`
  vs `barefoot-common/nakama/<share>` copies (~250 GB media), mindful of B2
  versioning.
- **Install rclone persistently on Nakama** for the Phase-4 B2 sync (not the
  RAM-disk root).
- **Phase 4: single-source Nakama->B2** -- back up from Nakama only, not
  per-machine, so the duplication stops recurring.
- **(security) Verify the B2 plaintext `Dropbox/sensitive` purge removed all
  versions**, not just the current ones.
- **Clean the ~211 cluster-resident `.sync-conflict` files at the source**
  (Avalir/Haven).
- **Relocate the `nas-xfer` evidence dir out of `personal`** into
  `backup/`/`archive/`.
- **Audit "what else went missing from the live shares"** -- confirm nothing
  important was actually lost (everything found so far was explainable).

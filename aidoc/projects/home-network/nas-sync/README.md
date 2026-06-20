# NAS Sync + Backup Architecture (`nas-sync`)

**Status**: target architecture + roadmap, established 2026-06-19.
**Parent project**: [home-network](../README.md). This is a deliberately
separate subdir so its `README.md`/`TODO.md` don't contend with the heavily
edited top-level home-network files (multiple agents touch those at once).

This subproject owns the home data-sync and backup topology: the end-state we
are building toward, the phased roadmap to get there, and a `whats-next` probe
that tells any agent the next thing to do. It supersedes the old one-off
verification workspace at `/export/personal/technical/nas-xfer/` (which started
as Taaveren migration tracking and is now demoted to a non-versioned *evidence
dir* holding the bulky `.list`/`.log` artifacts -- see "Where things live").

---

## TL;DR for an agent picking this up

1. Read this file (the target) and skim [roadmap.md](roadmap.md) (the plan).
2. Run **`bin/whats-next`**. It probes live state cheaply and prints the next
   unblocked action, with the reasoning.
3. Ask the user any clarifying questions **up front**, then run the work
   long and detached. These are long-running jobs; the goal is minimal
   interruption (see "Operating discipline").

---

## The goal, in one paragraph

Every important file lives in enough places that no single failure (a dead
laptop, a dead NAS drive, or the house burning down) loses it. Active data
syncs near-real-time across the working machines and the NAS; archival data
syncs less often; deep-archival data rests on the NAS only; file-level version
history accumulates on a dedicated box; and **everything that reaches the NAS
is periodically pushed to Backblaze B2** as the offsite disaster copy. We never
delete from B2.

## Tiers and shares

Shares are grouped by how actively they change and therefore how aggressively
they sync.

| Tier | Shares | Lives on | Sync cadence among nodes |
|---|---|---|---|
| **Important** | `music`, `personal`, `proj`, `rpg`, `work` | Haven, Avalir, Graymoor, Nakama | near-real-time |
| **Archival** | `backup`, `camera` | Haven, Avalir, Graymoor, Nakama | periodic |
| **Deep archival** | `archive`, `incrementals`, `homes` | Nakama only | n/a (hand-populated) |
| **Versioning store** | `sync_hist` | Graymoor (authority) + Nakama | periodic (Graymoor -> Nakama) |

And the universal rule: **everything on Nakama is periodically synced to B2.**

### The placement invariant and its exceptions

> Every non-deep share must live on **at least two nodes, at least one of them
> not Nakama.** (So a catastrophic NAS failure never leaves a share with only a
> cloud copy to restore from.)

The tiers above state the *general* placement (all four nodes). Two deliberate
exceptions, both already true today:

- **`work` need not be on Haven.** It is a live Syncthing folder on Avalir
  (4.8G, edited daily, and bound up in Claude skills that break without it),
  present on Nakama, and versioned on the version node. Haven's `/export/work`
  is an empty 4K shell with no `.stfolder`, and that is fine.
- **`rpg` need not be on Avalir.** It happens to be there now, which is also
  fine; the point is it isn't required.

Document new exceptions here rather than special-casing them elsewhere.

### Per-share reality as of 2026-06-19

Syncthing `.stfolder` presence and live process confirmed by probe this date.

| Share | Haven | Avalir | Zadash (`/srv/sync_hist`) | Nakama | Notes |
|---|---|---|---|---|---|
| music | sync | sync | sync + versioned | yes | |
| personal | sync | sync | sync + versioned | yes | `crypt/` sub-vault is age-encrypted in place |
| proj | sync | sync | sync + versioned | yes | |
| rpg | sync | sync | sync + versioned | yes | |
| work | -- (empty) | sync | sync + versioned | yes | not on Haven (by exception) |
| camera | sync | sync | sync + versioned | yes | only *archival* share currently versioned |
| backup | sync | sync | -- | yes | not versioned anywhere yet |
| archive | -- | -- | -- | yes | deep archival, ~1.1TB |
| incrementals | -- | -- | -- | yes | snapshot dropzone (see below) |
| homes | -- | -- | -- | yes | ex-Synology home dirs, ~156G, frozen |
| sync_hist | -- | -- | **authority** | yes (mirror) | version history; Zadash -> Graymoor |

`incrementals` is a Nakama-only dropzone for incremental/snapshot backups pushed
*to* the NAS (currently just the nightly Pidgin `~/.purple` snapshot from
Avalir via `bin/purple-snapshot` -> `nakama:/share/incrementals/avalir/purple/`).
It is not a synced share and is not expected to live anywhere but Nakama.

## Machines

Always confirm which box you are on before host work (`aidoc/check-environment`
or `hostname`); these all mount the same Syncthing tree so the filesystem looks
identical everywhere. Full per-host gotchas live in the home-network README;
the sync-relevant facts:

- **Haven** -- Linux laptop (Mint), data at `/export` (ext4, *unencrypted* at
  rest). tcsh. Syncthing node for 6 shares (all but `work`). Historically
  crash-prone, improving (no crash since the 2026-06-15 AC-adapter swap).
  Personal-primary trajectory. The user's **default session host** (keeps
  Avalir free for work sessions).
- **Avalir** -- Linux desktop (Mint), data at `/export` (LUKS-encrypted at
  rest). tcsh. Syncthing node for all 7 shares. Stable (uptime in months).
  Work-trajectory. Origin of the verification toolchain and `nasupdate`.
- **Graymoor** -- **future**, not on the network yet (NanoKVM assembly pending).
  Built on ex-Caemlyn hardware, lean headless OS (Debian 13.2). Will **replace
  Zadash as the version-history authority.** Disk capacity unknown (~900G
  ballpark, since Caemlyn once did Avalir's job) -- a gating unknown until it is
  reachable. See roadmap Phase 6.
- **Nakama** -- QNAP **TS-364** NAS, QTS 5.2.7, x86 (Celeron N5095). Single 4TB
  drive, ext4 thin volume, 2.8TB usable, ~740G free, 80% alert threshold, 20%
  snapshot reserve. SSH **port 2322, user `nami`**, bash. Base `/share/<name>`
  (symlinks; **use `/share/CACHEDEV1_DATA/<name>` for `du`** or it reports 0).
  BusyBox coreutils (`sort -n`, not `sort -h`). **No Syncthing and no Container
  Station installed** (only QPKG is MalwareRemover). The consolidation hub and
  the staging point for B2.
- **Zadash** -- Linux, *unreliable hardware*, data at `/srv/sync_hist`. tcsh.
  **Current** version-history authority: Syncthing `sendreceive` + `staggered`
  versioning, `maxAge=0` (keep versions forever), 6 folders (the 5 important +
  camera, not backup). Up 34 days at last check. To be retired once Graymoor
  takes over.
- **Quin** -- EC2 sandbox; not part of the data mesh, but the git source of
  truth for dev repos in a disaster (see home-network fire-evac doc).
- **B2** -- Backblaze cloud, reached by `rclone` from Nakama. Offsite disaster
  copy. Buckets: `barefoot-common` (cleartext bulk), `barefoot-encrypted`
  (rclone-crypt), `barefoot-caemlyn` (legacy, ignore). Keys + crypt passphrase
  per the home-network `fire-evac-recovery.md`.

## Sync mechanisms

**Syncthing is the spine.** It already runs continuously on Haven and Avalir
and works well; the user is fluent in it and wants to keep it. Design choices
layered on top:

- **Linux mesh (Haven / Avalir / Graymoor):** Syncthing. Important shares run
  near-real-time (fsWatcher on). For *archival* shares (`backup`, `camera`),
  **"periodic" is a minimum-frequency floor, not a cap** (user decision
  2026-06-20): they stay on continuous Syncthing like everything else (it costs
  ~nothing while idle), and we throttle them (fsWatcher off + long
  `rescanIntervalS`) only if they ever prove to eat noticeable resources.
  "Periodic" really governs the Nakama and B2 legs, where the cadence saves
  real work.

- **Nakama (receive side):** Nakama must never be hand-edited (receive-only),
  but the user occasionally copies files *into* the deep-archival shares by
  hand. Nakama has no Syncthing today, so there is a genuine fork:
  - **(chosen)** stand up Syncthing in **Container Station** (the TS-364 is
    x86 and supports it) as a **receive-only** peer for the important +
    archival shares -> true near-real-time, one mechanism across the whole
    mesh. Installing Container Station and creating the container is a **QTS
    web-GUI / App Center step the user performs**; once it is running, the
    Syncthing container config is manageable over SSH.
    Fallback if containerized Syncthing proves heavy or version-fragile on the
    NAS (cf. the quin Syncthing-version saga): a short-interval `nasupdate`/rsync
    cron. Until Syncthing-on-Nakama is stood up and proven, that rsync cron is
    also the **interim** mechanism keeping Nakama current.
  - Deep-archival shares (`archive`, `incrementals`, `homes`) are not synced at
    all; they are just directories on Nakama that occasionally get data copied
    in.

- **Graymoor (version authority):** Syncthing, **receive-only** + `staggered`
  versioning with `maxAge=0`. This reproduces Zadash's proven setup (same
  folder set: 5 important + camera) but improves `sendreceive` -> `receiveonly`
  to match "never edited by hand on Graymoor." The accumulated `.stversions`
  tree *is* `sync_hist`.

- **`sync_hist` -> Nakama:** periodic rsync of Graymoor's `/srv/sync_hist` tree
  (live copies + `.stversions`) to `nakama:/share/sync_hist`. This is the only
  copy of file version history besides the authority box, so it matters.

- **Nakama -> B2:** `rclone` on a cron on Nakama (QNAP `/etc/config/crontab`,
  **not** makeln). See "B2 policy".

## B2 policy

- **Everything on Nakama goes to B2**, including the deep-archival bulk
  (`archive` ~1.1TB, `homes` ~156G, `sync_hist` ~510G). B2 is cheap and the
  whole point is total recoverability if the house is gone or the single NAS
  drive dies with its data.
- **Never delete from B2.** Implement as `rclone sync` against buckets whose B2
  lifecycle keeps **all versions** (so the live view mirrors Nakama and stays
  clean, but every superseded/deleted file is retained and recoverable), rather
  than naive `rclone copy` which accumulates duplicates on every rename. (The
  user acknowledges "never delete" may become untenable at some scale; revisit
  then.)
- **Cadence:** no less often than daily for shares that actually change. Deep
  archival rarely changes *at all*, so the only question is the cost of the
  change-scan: if scanning `archive` for changes is cheap (it is metadata-only),
  run it nightly anyway; if it proves slow enough to interfere with more
  important syncs, drop it to weekly/monthly. **Measure before deciding** (see
  roadmap Phase 4).
- **Encryption:** `personal` goes to the **cleartext** bucket for now -- its
  genuinely sensitive contents already live age-encrypted in `personal/crypt/`
  (the old `Dropbox/sensitive/` plaintext tree is gone; see the home-network
  `summary:automox-deflect-and-crypt-vault.md`). Encrypting all of `personal`
  on the B2 side is a possible later hardening, not a current requirement.
- **Targeted restore is native:** pulling a single file or subdir straight from
  B2 in an emergency is just `rclone copy b2:bucket/path/to/thing dest` -- no
  full-share download needed.

## Monitoring and verification

A sync architecture you don't watch silently degrades. The end-state includes:

- **Proactive sync-health checks** rather than "notice a file is missing, then
  open the Syncthing UI": poll each node's Syncthing folder-completion state
  (REST API), alert on a folder stuck out-of-sync. (`synudge` and
  `syncthing-troubleshooting.md` in home-network are the starting points.)
- **B2 cron health:** alert on a failed or missed nightly run, not just success.
- **Nakama disk threshold:** watch free space against the 80% line; the RAID-1
  second drive is the contingency if it tightens (not currently planned).
- **QNAP alert-email triage:** Nakama emails constantly and it is currently all
  noise the user ignores. Now that email access is wired up, surface the
  *important* ones (IHM disk health, critical log alerts) out of the noise.
  `aidoc/projects/home-network/parse-nakama-alerts.pl` already extracts the real
  message from these MIME mails.
- **Scheduled test-restores:** periodically pull a sample from B2 and diff it
  against source. An unverified backup is not a backup.

## Safety invariants

1. **Never delete a source until the destination copy is verified**, and do the
   deletion only through `bin/nas-reclaim` (see below), never a raw `rm`. The
   `bin/` listing toolchain is what produces that verification.
2. **Two-node invariant** (above): every non-deep share on >=2 nodes, >=1 not
   Nakama.
3. **Never delete from B2.**
4. **Nakama and Graymoor are receive-only** (no hand edits; the one exception is
   copying into Nakama's deep-archival dirs).
5. **Deep-archival redundancy is Nakama-disk + B2** (two copies, one on a single
   non-RAID drive). If that is judged too thin, the lever is the RAID-1 second
   drive.

## Verified deletion (`nas-reclaim`)

Auto-mode (and good sense) blocks raw `rm`, so reclamation cannot just shell out
to delete. All reclamation -- the Phase 2 Haven cleanups, and later deleting a
migration source once its copy is verified -- goes through one tool,
**`bin/nas-reclaim`** (built + self-tested 2026-06-20), designed to be safe enough
to allowlist and run unattended:

- **Allowlisted targets only.** It refuses any path not in its built-in table of
  vetted reclamation targets (e.g. `/export/synology-sync_hist`, specific
  `/var/tmp/*` staging dirs, "the source copy of share X on host Y"). No
  arbitrary-path deletion.
- **Re-verifies at delete time.** Each target carries its own check -- a
  `review-dir-listings` run requiring zero missing, or a presence/size assertion
  on the destination -- and the delete happens *only* if it passes.
- **`--noaction` first** (per the repo command-safety convention): previews what
  it would remove plus the verification result, deleting nothing. That safe form
  is freely allowlistable; the real form is allowlistable *because* of the
  guardrails above.
- **Clean vs caveated targets.** A *clean* target (e.g. `var-tmp-synology-camera`)
  deletes once verified. A *caveated* target (e.g. `synology-sync_hist`, whose
  ~336M of music `.stversions` exist only there) additionally requires an
  explicit `--accept-caveats`, so a documented partial loss is never incurred
  silently.
- **`--self-test`** exercises every decision branch (refuse on verify-fail,
  refuse unsafe path, refuse caveat, and the real delete) against a throwaway
  sandbox, so a logic bug can only destroy scratch files -- never real data.
- **Logs every action** to the audit trail.

So a deletion becomes `nas-reclaim --noaction <target>` to preview, then
`nas-reclaim <target>` to act -- both runnable un-prompted once allowlisted,
with the script's own verification as the real gate. This is what lets the
long-running, low-interruption workflow include deletions at all.

**Allowlisting (done 2026-06-20).** The safety classifier blocks the real
(non-`--noaction`) form on sight -- it cannot see the script's internal guards
(witnessed: a real-mode invocation was denied even though the script would
itself have refused). Rather than put these niche tools on `$PATH`, they are
**invoked by full absolute path and allowlisted at that exact path** in the
committed `conf/ai/claude/settings.json`:

- `permissions.allow`:
  `Bash(/export/proj/common/aidoc/projects/home-network/nas-sync/bin/whats-next:*)`
  and `.../nas-reclaim:*` (both the `/export/proj/common` and `/home/buddy/common`
  spellings, since `~/common` resolves to the latter).
- `autoMode.allow`: a note sanctioning `nas-reclaim` deletes, since the
  classifier otherwise hesitates on any `rm`.

So the **canonical invocation is the full path**, e.g.
`/export/proj/common/aidoc/projects/home-network/nas-sync/bin/nas-reclaim --noaction <target>` --
that exact prefix is what the allow rule matches. (`--noaction` is read-only and
safe regardless of how it is invoked.)

## How `whats-next` works (the hybrid model)

We chose a **hybrid** over a pure live-probe script (too slow: a real gap
computation means generating multi-hundred-MB listings across 4 machines on
every ask) and over a hand-maintained checklist (drifts the moment an agent
forgets to tick a box, and several agents plus Syncthing change state
underneath us).

- **[roadmap.md](roadmap.md) is the map:** an ordered, dependency-annotated list
  of phases. Each step records a *cheap probe signal* for done/not-done and any
  *gating* (notably "blocked until Graymoor is online").
- **`bin/whats-next` is the locator:** it runs only the cheap probes
  (`df`, targeted `du`, file/folder presence, Syncthing reachability, Graymoor
  and Zadash liveness), finds the first incomplete *and unblocked* step, and
  prints it with its reasoning. It degrades gracefully when a host is down.
- **The heavy toolchain stays holstered:** `dir-listing` + `review-dir-listings`
  (minutes to hours) run only to *verify a transfer immediately before a
  delete*, which is the one moment correctness is safety-critical.

So "fire up and ask what's next" is a seconds-long, always-honest answer, while
the expensive verification happens only when it actually protects data.

## Operating discipline (for long-running, low-interruption work)

- **Ask everything up front.** A fresh session should gather all the
  clarifications it needs, then run long without pestering. The user explicitly
  optimizes for this.
- **Run heavy transfers detached** (`screen`/`nohup`) **on the box local to the
  source data**, so neither a dropped agent session nor a Haven crash mid-job
  costs more than a restart. Syncs self-heal and rsync resumes; nothing lives
  *only* on Haven.
- **Sessions run on Haven by default** (user's choice, to keep Avalir free for
  work). Drive transfers on Avalir/Nakama/elsewhere from there as appropriate.
- **Commits are gated.** Never commit without an explicit ask; stage only your
  own files by path (shared tree, concurrent agents). See home-network README.

## Where things live

| What | Where | Versioned? |
|---|---|---|
| This architecture, roadmap, `whats-next`, toolchain | `common:aidoc/projects/home-network/nas-sync/` | yes (git -> public GitHub) |
| Anything sensitive (IPs, keys, device IDs) | `nas-sync/private/` | no (`.gitignore`d) |
| Bulky regenerable evidence (`.list`, `.log`, the 504M `new`, `pre/`, `post/`) | `/export/personal/technical/nas-xfer/` | no (synced + B2-backed, not git) |

The toolchain scripts in `bin/` are the canonical (versioned) copies; the
evidence dir keeps its own working copies. They rarely change, so drift is
low-stakes -- but edit the `bin/` copy and re-copy if you do change one.

## Pointers

- Roadmap and current next-actions: [roadmap.md](roadmap.md), [TODO.md](TODO.md)
- Historical inventory snapshots: [reference/](reference/)
- Disaster recovery from B2: home-network `fire-evac-recovery.md`
- Syncthing troubleshooting: home-network `syncthing-troubleshooting.md`
- Nakama storage layout history: home-network `summary:nakama-storage-reconfiguration.md`

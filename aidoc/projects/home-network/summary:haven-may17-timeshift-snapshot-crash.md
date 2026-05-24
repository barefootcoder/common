# Haven: May 17 Crash Triggered by Daily Timeshift Snapshot

## Session Context

Triggered by **another silent power-off on Haven on 2026-05-17 ~05:00:33**,
overnight while the laptop was unattended (plugged in, lid open, all
NoMachine sessions closed). Discovered ~8 hours after the fact when the
user found Haven powered off in the morning. This is a sequel to:

- `summary:haven-may13-vivmon-fix-and-nomachine-profile.md` (May 13)
- `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md` (May 11)
- `summary:vivaldi-7.9-upgrade-and-haven-instability.md` (May 8/9)
- `summary:haven-fstab-uuid-and-vivaldi-guard.md` (April)
- `summary:haven-kernel-upgrade-and-gpu-fix.md` (February)

This crash matters because it's the **first one for which the
post-May-13-functional `viv-mon` data and the journalctl trail together
identify a specific proximate trigger**: the daily Timeshift snapshot
fired by the hourly `--check` cron at 05:00:01. Every prior crash
investigation has ended at "kernel hang took the journal down before it
could write anything." This one ends at "we know which cron job did it."

## Crash Forensics

### Timeline (UTC-7)

| Time | Event |
|---|---|
| 2026-05-13 18:15 | Previous boot (post-crash recovery from May 13) |
| 2026-05-17 04:47 → 04:59 | Steady-state idle. `BROWSERS` samples show `c:chromium-gsheets v:vivaldi-media` resident the whole window. viv-mon polling at ~5 Hz. `pkg≈3.5 W`, `load≈0.25`, `tz4=47 °C`, `tp=off`. |
| 05:00:01.0 | journalctl: `(root) CMD (timeshift --check --scripted)` |
| 05:00:02.227 | viv-mon: **burst.** `pkg=12.72 W → 19.00 W` in the next sample; `gfreq=300 → 1050 MHz`; `tz4` climbs 47 → 53 → 56 in one second. |
| 05:00:03.5 | `tz4` peaks at **61 °C**. `pkg=17.62 W`. `unc=0.17 W` (so GPU did briefly spin but stayed tiny). |
| 05:00:04 → 05:00:08 | `pkg` settles 10–15 W, `gfreq` back to 300 MHz, `rc6` rising — GPU goes idle, CPU stays moderately busy. `load` starts climbing: 0.25 → 0.39 → 0.60. |
| 05:00:08.8 → 05:00:33.0 | **Polling cadence collapses.** viv-mon's own poll intervals stretch 264 ms → 648 ms → 1.1 s → 3.3 s → 1.7 s → 1.6 s → 2.6 s → 2.9 s. `load` climbs 0.60 → 0.95 → 1.28 → 1.49 → 1.69. `pkg` oscillates 6–12 W. Temps stable in low 50s. |
| 05:00:33.051 | Last viv-mon line. |
| 05:00:20 | Last journal line (journald flushed less aggressively than viv-mon, ends 13 s earlier). |
| 2026-05-17 13:21:18 | Manual boot after discovery. |

Uptime at crash: **3 d 10 h 45 m**. Right in the now-typical
~3-day endurance window (May 8 → May 11 was ~3 d; this stretch was the
longest survival since).

### What the new viv-mon columns told us

This is the **first crash investigation in which all four added-on-May-13
columns produced real data** through the crash window — `pkg`, `unc`,
`gfreq`, `rc6`. Conclusions they let us draw cleanly:

- **Not thermal.** Peak `tz4` = 61 °C, far below the throttle ceiling.
  Other thermal zones (`tz1=20`, `tz2=41`, `tz3=49`-ish) stayed flat.
- **Not GPU.** `gfreq` spiked to 1050 MHz for one sample at 05:00:02 then
  dropped right back to 300 MHz. `rc6` *rose* through the failure
  (longer GPU-idle deltas per sample, which is what you'd expect when
  the GPU has nothing to do). `unc` (renamed from `gpu` on May 13 since
  Raptor Lake has no dedicated GPU RAPL domain) maxed at 0.17 W
  briefly, otherwise ≈ 0.00 W. The May 13 "revisit only if gfreq climbs
  + rc6 collapses" precondition is the **opposite** of what we saw, so
  the xpra/NoMachine-replacement deferral from May 13 stands.
- **Not user activity.** `tp=off` throughout (touchpad floating per
  May 11 termstart hook), `load=0.25` for hours leading up.
- **CPU-side starvation, mild.** Final `load=1.69` is not crushing for a
  multicore box. But viv-mon's own poll interval stretching from 264 ms
  to 2.9 s says scheduling latency on the small periodic loop got an
  order of magnitude worse over 30 seconds — *something* was running
  long enough to dwarf 200 ms timeslices. Consistent with a single
  rsync-like process plus normal cron noise on a host whose CPU/VRM
  margin has degraded.

### The journal pin: timeshift cron is the proximate trigger

`journalctl -b -1 --since 04:55 --until 05:01` showed the 04:55, 04:56,
04:57, 04:58, 04:59 minutes contained only:

- The user's `* * * * *` `monitor-notifications` cron (every minute,
  consumes ~1.4 s CPU time)
- `system-monitor.service` repeatedly failing with
  `status=203/EXEC Permission denied` on
  `/usr/local/sbin/system-monitor` (existing noise, harmless,
  pre-dates the crash)
- `tailscaled` portmapper chatter
- UFW BLOCK kernel lines on multicast 21027 (Syncthing discovery from
  other LAN devices)

Then at 05:00:01 exactly **one new event** appeared that hadn't fired
in the prior minutes:

```
May 17 05:00:01 haven CRON[3271361]: pam_unix(cron:session): session opened for user root(uid=0) by (uid=0)
May 17 05:00:01 haven CRON[3271366]: (root) CMD (timeshift --check --scripted)
```

That's the smoking gun.

### Why 05:00 spiraled when 02:00/03:00/04:00 didn't

The hourly cron `/etc/cron.d/timeshift-hourly` runs `timeshift --check
--scripted` every hour at minute 0. The `--check` is cheap on most
hours — it just decides whether a scheduled snapshot is due. **At 05:00
on a day when the daily snapshot is due, the same `--check` invocation
triggers a full rsync snapshot creation.** The user observed this is
the empirical 5 AM pattern, and it's confirmed by snapshot timestamps:

```
$ sudo timeshift --list
Num     Name                 Tags  Description
0    >  2026-04-07_05-00-01  M
1    >  2026-05-07_05-00-01  M
2    >  2026-05-09_05-00-01  W
3    >  2026-05-11_18-39-59  B
4    >  2026-05-13_18-25-51  B
5    >  2026-05-16_05-00-01  D W
```

All daily/weekly/monthly entries are stamped `05-00-01`. The B-tagged
ones are boot snapshots from the May 11 and May 13 recovery reboots.
There is **no `2026-05-17_05-00-01` entry** — the daily snapshot that
started at 05:00:01 today never got far enough to leave a directory in
the snapshot list before the kernel went away.

Side-by-side viv-mon traces at each prior top-of-hour confirm the
heavier-at-05 picture. Each entry below is the bracket of "first few
samples after :00:00":

| Hour | Pre-:00 idle pkg | Peak burst pkg | Burst duration | Return to idle |
|---|---|---|---|---|
| 01:00 | already busy (~15 W) | 37 W | ~3 s | yes by 01:00:04 |
| 02:00 | 3.5 W | 14.7 W | ~1 s | yes by 02:00:03 |
| 03:00 | 3.5 W | 14.5 W | ~1 s | yes by 03:00:04 |
| 04:00 | 3.5 W | 14.2 W | ~1 s | yes by 04:00:03 |
| **05:00** | **3.5 W** | **22.1 W** | **30+ s, then crash** | **never** |

Notable: 01:00 was running at a *much* higher baseline than 02–04 (the
Vivaldi+chromium-gsheets pair was apparently doing something at the
time) and still survived the timeshift fire fine. So "busy beforehand"
is not the discriminator. 05:00 had the **same starting conditions as
02, 03, 04** (idle ~3.5 W, same BROWSERS, same `tp=off`, same `load`),
took a heavier trigger (daily snapshot creation vs lightweight check),
and went down.

### Interpretation

This is the lowest-stress crash trigger in the May series:

| Date | Trigger |
|---|---|
| Feb 2026 | Vivaldi GPU bursts on bare i915 driver |
| Apr 2026 | Vivaldi + active NoMachine session |
| May 8 | "Routine load" — Vivaldi 7.9 launches and bare `termstart` |
| May 11 | Long uptime + boot-time termstart on cold start |
| May 13 | MATE workspace switch onto fullscreen video while NoMachine streamed it |
| **May 17** | **Unattended cron-driven daily rsync snapshot, no user interaction, no display activity, no NoMachine** |

Each successive crash trigger is more benign. The May 17 trigger is
literally "the machine doing its own scheduled maintenance with nobody
watching." This **strongly reinforces** the mainboard-aging hypothesis
from the May 8 summary: the crash threshold has dropped to the point
where the system can no longer reliably complete idle background tasks.

## Current Timeshift Config Audit

Before deciding on mitigations, here's what's actually being snapshotted
and how:

**Mode:** RSYNC (not BTRFS) — so it's a true filesystem copy, not a CoW
clone. Read-heavy on source + write-heavy on destination.

**Backup volume:** `/dev/dm-1` (LVM/LUKS-backed) auto-mounted at
`/run/timeshift/<pid>/backup` on demand. 236.9 GB free. 6 snapshots
currently retained.

**Schedule + retention** (from `/etc/timeshift/timeshift.json`):

| Tier | Enabled | Keep |
|---|---|---|
| Boot | yes | 2 |
| Hourly | no | — |
| Daily | yes | 1 |
| Weekly | yes | 2 |
| Monthly | yes | 2 |

**Exclusions already in place:**

```
/home/buddy/**
/root/**
/var/tmp/synology-camera/***
/var/tmp/avalir-backup/***
/var/tmp/sandbox-test/***
/var/tmp/nas-backup/***
/usr/NX/var/log/server.log
```

**Filesystem layout — user data is NOT on the snapshotted volume:**

| Mount | Device | Used |
|---|---|---|
| `/` | `/dev/mapper/vgmint-root` (ext4) | 246 GB |
| `/export` | `/dev/nvme1n1p1` (ext4) | 365 GB |

`/export/{music,personal,proj,backup,camera,rpg}` are all Syncthing
folders (per `~/.config/syncthing/config.xml`) and live on a separate
NVMe partition. Timeshift's rsync does not cross filesystem boundaries
by default, so **user data on `/export` is not in the snapshot to begin
with.** Similarly `/home/buddy/**` is explicitly excluded.

**Snapshot size:** `snapshot_size : 30576320750` (= ~30 GB). Top
contributors on root fs:

| Path | Size on `/` |
|---|---|
| `/usr` | 48 G |
| `/var` | 91 G |
| `/opt` | 1.4 G |
| `/root` | 157 M (excluded anyway) |
| `/etc` | 34 M |

Most of `/var` likely is Timeshift's existing default excludes (caches,
logs, transient state); the 30 GB working size is roughly consistent
with the system-only set after defaults.

### What this means for the user's proposed "refocus on system files"

The intent — *let Timeshift handle system files, let Syncthing handle
user files* — is **already the de facto state**:

- `/home/buddy/**` excluded.
- `/root/**` excluded.
- `/export/**` not on the snapshotted filesystem.

So there isn't a big win available from "exclude my user data." The
levers worth pulling are different:

1. The hourly cron has no `nice`/`ionice` (only the redundant 7 AM
   daily cron does — see "Mitigation Options" below).
2. The daily-snapshot cadence itself is the question. With 1 daily
   retained and Syncthing replicating user data continuously, the
   daily snapshot is mainly disaster-recovery insurance for system
   state. That's valuable, but doesn't have to fire every 24 h while
   the machine is on the edge.

## Mitigation Options

Listed roughly cheapest → most invasive. None of these are mutually
exclusive.

### 1. nice/ionice the hourly cron (recommended, do first)

Current `/etc/cron.d/timeshift-hourly`:

```
0 * * * * root timeshift --check --scripted
```

Current `/etc/cron.d/timeshift-daily`:

```
0 7 * * * root ionice -c3 nice -n 19 timeshift --check --scripted
```

The 7 AM "daily" cron is the one Timeshift *thinks* is the polite-for-
daily-snapshots wrapper, **but in practice the daily snapshot fires
from the hourly cron at 05:00, not from the daily cron at 07:00**
(empirically confirmed by every snapshot in `--list` being stamped
`05-00-01`). So the nice/ionice wrapping is on the wrong cron job.

Fix: wrap the hourly cron the same way:

```
0 * * * * root ionice -c3 nice -n 19 timeshift --check --scripted
```

- `ionice -c3` = idle I/O class — only gets disk bandwidth when nothing
  else wants it. This is the big one for an rsync-heavy snapshot.
- `nice -n 19` = lowest CPU priority.

**Tradeoff:** snapshot creation will take longer (could stretch from
~30 seconds of activity to several minutes). That's *fine* — the only
thing waiting on it is "the snapshot eventually exists." A longer,
gentler operation should be less likely to push a marginal box over
the edge.

**Caveat:** this doesn't *prevent* the crash. The May 13 crash on a
fullscreen video had nothing to do with cron at all. nice/ionice
reduces the probability that *this specific class* of trigger fires
again, but the underlying hardware margin is still degraded.

### 2. Move the daily snapshot to a time when you're awake

Doesn't reduce crash probability, but if 05:00 stays the snapshot time
and the next crash happens then, you'd lose another ~8 hours to it
unattended.

Timeshift picks the snapshot time itself — it isn't a cron parameter.
The simplest way to influence it is to *take a manual `--create
--scripted --tags D`* at a chosen hour (say 22:00 the night before),
which resets the daily clock so the next automatic daily fires ~24 h
later. Not robust, since it drifts over time.

A cleaner version: disable the hourly cron entirely and replace with
a single explicit daily cron at a chosen hour.

### 3. Reduce snapshot frequency

Options:

- Drop to weekly+monthly+boot only (no daily). Boot snapshots already
  catch the "after-a-crash-recovery" interesting state, and weeklies
  cover the slow drift. This is what I'd suggest given Syncthing
  covers user data already.
- Keep daily but extend retention so individual snapshots happen less
  often — not really how Timeshift works, but you could disable the
  hourly cron and let only the daily cron at 07:00 fire (with its
  existing nice/ionice). Verify empirically that the snapshot
  actually relocates to 07:00.

### 4. Further trim the snapshot scope

Diminishing returns since user data is already out. Candidates that
could shrink the snapshot further and reduce rsync work:

- `/var/cache/**` — typically already excluded by Timeshift defaults,
  worth verifying.
- `/var/log/**` — if you don't need historical logs in snapshots
  (you can argue both ways). Excluding shrinks both source-read and
  destination-write workloads.
- `/var/lib/docker/**`, `/var/lib/containers/**` — if any of these
  are populated and you don't care about their state, excluding cuts
  big trees.
- `/var/lib/snapd/**` — likewise.

This is moderate effort (audit + Timeshift JSON edits) for moderate
gain. Worth doing if option 1 turns out insufficient.

### 5. Disable Timeshift entirely on Haven until hardware fixed

The nuclear option. Pros: removes a known crash trigger. Cons: lose
the post-crash recovery snapshots and the rollback escape hatch — which
on this hardware, with crashes happening every ~3 days, is exactly
when you'd want it.

Don't recommend unless option 1 fails to help.

## Recommendation

**Do option 1 now.** It's a one-line cron edit, fully reversible, and
has the highest probability of mattering. Watch the next ~10 days of
05:00 snapshots — if at least 3 daily snapshots complete cleanly under
the nice/ionice wrapper without crash, declare it adequate. If another
crash happens at 05:00 anyway, escalate to option 3 (drop the daily
schedule, keep weekly + boot).

Option 4 (trimming `/var/log` etc.) is worth queueing as a follow-up
regardless — it's pure win on snapshot size and rsync workload, just
not urgent.

The single most important Haven action remains **the hardware
intervention** (battery + repaste + cap inspection) from the May 8
summary. Every Timeshift tweak is buying time on a known-degrading
substrate.

## Decisions Made This Session

- **Documented:** This summary.
- **Identified:** Daily Timeshift snapshot fired by hourly cron at
  05:00 is the proximate trigger for the May 17 crash.
- **Confirmed:** Existing config already excludes `/home/buddy/**`
  and `/root/**`; `/export/**` is on a separate FS and not in the
  snapshot. Syncthing-vs-Timeshift scope separation already exists.
- **Applied (option 1):** `/etc/cron.d/timeshift-hourly` now reads
  `0 * * * * root ionice -c3 nice -n 19 timeshift --check --scripted`
  (was: `0 * * * * root timeshift --check --scripted`). Pre-edit
  contents saved at `/etc/cron.d/timeshift-hourly.bak.pre-may17`.
- **Under discussion:** whether to *reverse* the existing `/home/buddy/**`
  exclusion and start including ~/ with a targeted exclusion list
  for caches and regenerable bulk. Rationale: most of ~/ is symlinks
  to /export (which Syncthing covers), and the real non-symlinked
  content under ~/ (~ a couple dozen GB after exclusions) is
  currently in no backup at all. See "Including ~/" section below.

## May 23 Follow-Up: Both Live-Config Mitigations Failed Silently

Audit performed during a routine `/x-aidoc-project home-network` reload on
2026-05-23 (six days after the original session) discovered that **neither
live-config change actually achieved its stated goal**. Both findings need
to be on the record before future agents act on this doc.

### Finding 1: the cron `nice/ionice` wrapper was reverted

- Current `/etc/cron.d/timeshift-hourly` content:
  `0 * * * * root timeshift --check --scripted` — no wrappers.
- `diff` against `/etc/cron.d/timeshift-hourly.bak.pre-may17` is **empty**;
  the files are byte-identical.
- File mtime is **2026-05-17 14:00 PDT** — about 12 minutes after the
  original edit at 13:48. So whatever reverted it acted very quickly and
  has not touched the file since.
- User confirmed (May 23) they did not revert it manually.
- `apt-history` greps for `timeshift` returned nothing in the relevant
  window. Suspects (none confirmed): unattended-upgrades conffile restore,
  timeshift self-reinstall via some other trigger, or another agent
  session that touched the file. Worth chasing only because future cron
  edits could be silently lost the same way.

### Finding 2: the exclusion list rework had zero practical effect

Despite removing `/home/buddy/**` from `/etc/timeshift/timeshift.json` and
adding 26 targeted excludes underneath, the latest snapshot's
`/home/buddy/` directory is **empty** (4.0 K, just `.` and `..`):

```
$ sudo ls -la /timeshift/snapshots/2026-05-23_14-00-01/localhost/home/buddy/
drwxr-x--- 2 buddy users 4096 May 23 03:41 .
drwxr-xr-x 3 root  root  4096 Jun 30  2023 ..
```

Same for the boot snapshot. Total snapshot size still ~30 G — unchanged
from before the May 17 rework.

**Root cause:** Timeshift's RSYNC mode has hardcoded `/home/*` and
`/root/*` excludes that take precedence over the user-supplied `exclude`
array. The `/home/buddy/**` entry in the original config was therefore
*redundant* with Timeshift's internal default, not load-bearing. Removing
it did nothing because the default exclude was still in effect. The 26
targeted excludes I added under `/home/buddy/` are all dead patterns —
they exclude things that were already excluded one level up.

The mechanism for *including* user homes in Timeshift is not the JSON
`exclude` array. It's the GUI's "Filter → Users → Include/Exclude" panel,
which writes per-user flags somewhere other than the `exclude` array
(likely a `user-rules` block or similar — not investigated yet).

So the doc's earlier claim "~10 GB net addition to the snapshot" never
materialized. The Syncthing-vs-Timeshift gap for `~/local/` (Haven-
specific termstart, viv-mon, etc.) and `~/.claude/` is still open —
those directories are in no backup at all.

### Why neither failure has bitten us

- **RAPL cap from May 22** (PL1=20 W, PL2=27 W) addresses the original
  crash risk directly. The snapshot's CPU burst can't exceed 27 W now
  regardless of `nice`/`ionice` priority, so the lost cron wrapper is
  moot for crash prevention.
- **`~/` was never actually included**, so no surprise heavy snapshot
  ever ran at 05:00. Post-May-17 snapshot history shows clean runs.

The original crash analysis (timeshift cron at 05:00 was the proximate
trigger) is **still correct**. It's only the mitigations that turned out
not to do what we said.

### Doc/TODO actions taken

- This section added.
- README "Current Status" entry for May 17 corrected.
- Three TODOs added (cron-revert investigation, `~/` inclusion path
  decision, dead-exclusion cleanup) — see project `TODO.md`.

## Files Touched This Session

- `aidoc/projects/home-network/summary:haven-may17-timeshift-snapshot-crash.md` — this doc
- `aidoc/projects/home-network/README.md` — add reference + Current
  Status entry (pending)

## Open Items After This Session

1. **Hardware intervention on Haven** (battery / repaste / cap
   inspection) — still the most important and most-delayed next step.
2. **Implement option 1** (nice/ionice on hourly Timeshift cron) once
   user confirms.
3. **Consider option 4** (extra `/var` exclusions) as a follow-up.
4. **Watch the next 3–5 daily snapshots** post-mitigation to see if
   the 05:00 crash class recurs.
5. **The `system-monitor.service` failure-loop** seen in journalctl
   every minute (status=203/EXEC, /usr/local/sbin/system-monitor:
   Permission denied) is unrelated to the crash but is noise that
   could be cleaned up. Likely a leftover unit from an experiment.
6. **xpra-as-NoMachine-replacement** — still deferred per May 13
   assessment. This crash had no NoMachine activity, which further
   weakens the case for swapping.

## Conventions / Workflow Notes Carried Forward

(Unchanged from `summary:haven-may13-vivmon-fix-and-nomachine-profile.md`:
`/x-commit` for commits; termstart for reboot-persistence work;
never edit Haven's crontab directly — but note that the *system* cron
entries at `/etc/cron.d/timeshift-*` are not under makeln management
and are owned by the timeshift package, so they're edited normally
with sudo + an editor.)

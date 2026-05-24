# Home Network — Outstanding Tasks

Follow-up work deferred from previous sessions. The `x-aidoc-project`
skill scans this file on load and surfaces due/pending items.

## Outstanding

- **2026-05-24** — Hardware intervention on Haven: battery replacement + CPU/GPU
  repaste + visual capacitor inspection. User targeting "this weekend" (May 24–25).
  _(added 2026-05-23 during May 22 double-crash mitigations)_

- **2026-05-24** — Test the spare AC adapter at the office. Plug in the backup
  adapter, mark `office-ac`, leave it for several hours, then compare event rate to
  the current adapter via `ac-mode report`. If rate drops dramatically, the adapter
  itself is the culprit. _(added 2026-05-23 during May 22 double-crash mitigations)_

- **2026-05-26** — Review `ac-mode report` after a few days of den-ac vs office-ac
  data. Hypothesis: den-ac should show a materially lower events/hr. If confirmed,
  office-side physical path (adapter/cable/jack) is flaky. Also try `office-usb`
  for a day and compare. _(added 2026-05-23 during May 22 double-crash mitigations)_

- **anytime** — Validate RAPL cap is working: after the next `termstart` / boot,
  check that `viv-mon.log` shows `pkg=` values not exceeding ~27W in normal use.
  If the cap is being ignored (some BIOSes lock RAPL), we'll need a different
  approach. _(added 2026-05-23 during May 22 double-crash mitigations)_

- **anytime** — If a third Haven crash occurs during boot (before `termstart` has
  run and applied the RAPL cap), consider moving the `intel-rapl:0` writes into a
  systemd unit ordered before `juno-pp` and `TLP`, so the cap is in place before
  the userspace burst. Not urgent unless another boot crash happens.
  _(added 2026-05-23 during May 22 double-crash mitigations)_

- **anytime** — Backdate the `ac-mode` log to capture the full week of historical
  journal data: `ac-mode mark office-ac at 2026-05-15T00:00:00-0700`. Then
  `ac-mode report` will show the consistent ~18/day rate in context. Low priority
  (current data is accumulating from May 22 onward anyway).
  _(added 2026-05-23 during May 22 double-crash mitigations)_

- **anytime** — Verify the deep-S3 + LID0-disarm suspend fix on Haven before next
  travel: hit Suspend from the menu, wait ~1 minute, close+open the lid (nothing
  should happen), then power-button to wake. `journalctl -b 0 --grep='PM: suspend'`
  should show exactly one clean entry/exit pair with no spurious wake in between.
  If a wake is logged anyway, the trackball USB Receiver (`3-1`, currently still
  armed) is the next candidate to disarm. _(added 2026-05-23 during May 18 travel
  suspend-drain investigation)_

- **anytime** — Decide path for `~/` (and `~/local/`, `~/.claude/`) backup coverage.
  May 23 audit confirmed Timeshift's RSYNC mode has hardcoded `/home/*` exclusion
  that overrides the user-supplied `exclude` list in `/etc/timeshift/timeshift.json`,
  so the May 17 exclusion rework had zero effect on snapshot contents (latest snap's
  `/home/buddy/` is an empty 4 K directory). Options: (a) accept the gap — Syncthing
  covers `/export/**`, RAPL cap covers crash risk; (b) find the right Timeshift
  override (likely the GUI's "Filter → Users → Include/Exclude" panel, which writes
  somewhere other than the `exclude` array — possibly a `user-rules` block); (c) use
  a separate tool for `~/` (borg, restic, rdiff-backup). _(added 2026-05-23 during
  May 17 follow-up audit)_

- **anytime** — Investigate what reverted the `ionice -c3 nice -n 19` cron edit at
  `/etc/cron.d/timeshift-hourly` on Haven around **2026-05-17 14:00 PDT**. Edit was
  applied at 13:48 PDT; file mtime as of May 23 is 14:00 PDT and content is byte-
  identical to the `.bak.pre-may17` backup. User confirms no manual revert.
  `apt-history` shows no timeshift package action in that window. Suspects worth
  checking: unattended-upgrades conffile restore, timeshift self-reinstall via some
  other path, or a concurrent agent session. Mostly academic now (RAPL cap supersedes
  the need for the wrapper) but worth knowing so future cron edits in `/etc/cron.d/`
  aren't silently lost the same way. _(added 2026-05-23 during May 17 follow-up
  audit)_

- **anytime** — Clean up the dead `/home/buddy/*` exclusion entries in
  `/etc/timeshift/timeshift.json` (26 entries added on May 17). They're no-ops given
  Timeshift's internal `/home/*` default exclude in RSYNC mode. Decision points: (1)
  remove them entirely to keep the config honest, OR (2) leave them in place as
  intentional documentation of which `~/` subdirs we'd want excluded *if* we later
  figure out how to actually include `~/` (i.e., they pre-stage the right exclude
  list for option (b) in the `~/` backup-path TODO above). Low priority either way.
  _(added 2026-05-23 during May 17 follow-up audit)_

- **anytime** — Set up nightly rclone cron on Nakama to sync `/share/*` → B2
  (`barefoot-common/nakama/...`). Approach agreed: rclone + `/etc/config/crontab`
  (QNAP cron management, NOT makeln). Script + cron entry should live in
  `conf/crontab/` for version control, plus a one-time manual install on Nakama.
  Excludes: `**/@Recently-Snapshot/**`, `**/.@__thumb/**`, `**/.qpkg/**`.
  See fire-evac-recovery.md for the rclone.conf already in place on Nakama.
  _(added 2026-05-24 during fire-evac backup session)_

- **anytime** — Back up the remaining Avalir survey gaps identified 2026-05-22:
  `~/.config/` (minus vivaldi, covered), `~/.local/` (1.8 GB), `~/.purple/` ✅
  already set up, `~/Downloads/`, `~/.thunderbird-fresh/`, `/root/`, `/etc/`,
  Haven host-unique (`~/Insync/` 35 GB, `~/local/`, `~/.ssh/`, `~/.mozilla/`).
  `/var/lib/docker/` if containers have unique state. See the May 22 survey report
  in conversation; user approved deferring most of this.
  _(added 2026-05-24 during fire-evac backup session)_

- **anytime** — `~/.config/` cleanup: safe to delete `vivaldi-install/` (115 MB,
  mtime 2023-10-03, defunct Vivaldi profile). Likely safe: `chromium-crippled/`
  (464 MB, mtime 2025-04-17). Borderline: `google-chrome/` (176 MB, 2026-03-07).
  User to confirm before deletion. _(added 2026-05-24 during fire-evac backup session)_

- **anytime** — Nakama `/share/{music,camera,rpg}` not yet uploaded to B2
  (intentionally skipped since Avalir covers `/export/{music,camera,rpg}`). Nakama's
  `/share/music` has extra subdirs (`Christy/`, `Danny/`, `Dreamtime/`) not present
  on Avalir — worth a sweep under `barefoot-common/nakama/music/` eventually.
  _(added 2026-05-24 during fire-evac backup session)_

## Done

_(nothing yet)_

# Home Network — Outstanding Tasks

Follow-up work deferred from previous sessions. The `x-aidoc-project`
skill scans this file on load and surfaces due/pending items.

## Outstanding

- **anytime** — Verify the GPU frequency cap is holding: after the next
  `termstart`/boot, `cat /sys/class/drm/card1/gt_max_freq_mhz` should be 400, and
  viv-mon's `gfreq=` column should never exceed ~400 in normal use. If 400MHz
  feels sluggish in daily use (video-call composite, page rendering), bump both
  `gt_max_freq_mhz` and `gt_boost_freq_mhz` to 700 live and update termstart to
  match. _(added 2026-06-04 during June 4 crash mitigations)_

- **anytime** — Implement the durable keypad-colon fix (TWO_LEVEL/XKB level), now
  that mechanism #2 is IDENTIFIED (2026-06-04): every ECOXGEAR Bluetooth speaker
  connect makes X add an AVRCP "keyboard" device and recompile the keymap (pc105/us
  Xorg-log signature confirmed; historical hits all on weekends, matching the
  Saturday speaker habit). We have an ON-DEMAND REPRODUCER: connect the speaker,
  watch keymap-mon. The stopgap is ALREADY DEPLOYED (2026-06-04): keymap-mon on
  both boxes auto-reapplies `xmodmap ~/.Xmodmap` on detected wipe (REAPPLY log
  lines), shrinking the broken window to ~5s and covering the still-unsolved silent
  mechanism #1 too. What remains is the TWO_LEVEL change (Shift picks the level,
  NumLock irrelevant -- see `keypad-colon-investigation.md` "Fix plan"), which
  needs the user at Haven's keyboard to test the four NumLock/Shift combos, and
  the BT reproducer to verify survival. Note: the next ECOXGEAR connect doubles
  as the stopgap's live test. _(added 2026-06-04 during June 4 crash
  investigation; stopgap completed same day)_

- **anytime** — Markdown-viewer rollout (winner: **mdcat**, decided 2026-06-04 on
  aesthetics — glow's margins/reflow/colors lost on raw impact even after the
  TERM fix). Wrapper `bin/mdless` (renamed from `mdv` 2026-06-05): `mdcat
  --ansi` + `--columns` pinned to real terminal width + perl filter fixing
  mdcat's space-inside-italics bug, paged via `$PAGER`. DONE: mdcat installed
  on Haven + Avalir + quin (sha256-verified, tarball stashed in `/var/install/`
  on both home boxes); `setup/local-packages.setup` install section added;
  user-verified working in and out of screen; README "Tools and Scripts"
  section documents it. Build-script port DONE 2026-06-05: mdcat install block
  (pinned 2.7.1 + sha256, loud-skip on checksum failure, idempotent via
  `cmd-available`) added to `$CHEOPSROOT/launch-ec2/control-instance/build`
  between the pjawk and Claude Code sections (committed to cheops as 437b2b429). glow deliberately NOT ported (trial-only; still
  installed on the current quin, remove or ignore at leisure). _(added
  2026-06-04 during markdown-viewer selection session; updated 2026-06-05;
  upstream-report item resolved-as-moot 2026-06-08, see Done)_

- **anytime** — Migrate Tabs Backup & Restore (MV2, bit-rotting) → Tab Session
  Manager (MV3) on both Haven and Avalir. Data preserved on both (Avalir: code +
  4.3 MB data intact but disabled; Haven: code was pruned and restored). Steps in
  the "Tabs Backup & Restore" sections of
  `summary:vivaldi-7.9-upgrade-and-haven-instability.md`. _(added 2026-05-26
  during Avalir Vivaldi 7.9 upgrade)_

- **2026-08-03** — Hardware intervention on Haven: battery replacement + CPU/GPU
  repaste + visual capacitor inspection. Originally targeted May 24–25 weekend;
  pushed out a week on 2026-05-25, then pushed out ~2 months on 2026-06-03 (user
  hasn't bought a replacement battery and won't for a while -- the whole job is
  gated on acquiring the battery, so this date is a re-check, not a hard deadline).
  _(added 2026-05-23 during May 22 double-crash mitigations)_

- **anytime** — Empirical office AC adapter swap (the next step out of the
  2026-06-03 ac-mode analysis). Buy a new office AC adapter+cable (will take time;
  no rush -- RAPL cap is the live crash mitigation). When it arrives, swap it,
  KEEP the `office-ac` label, use normally for ~1 week, then re-run `ac-mode
  report`: office-ac falling to the ~13/day common floor = adapter was the culprit;
  staying at ~18/day = points at the laptop's barrel jack / internal AC path. See
  the "ac-mode analysis (2026-06-03)" section of
  `summary:haven-may22-double-crash.md`. _(added 2026-06-03, supersedes the spent
  "re-run after avoidance week" item)_

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

- **anytime** — Timeshift post-reschedule residuals (spun out of the 2026-06-08
  verification, see Done). (1) **Boot pruning with `schedule_boot=false`** is
  still unprovable: currently 2 B snapshots (May 22, June 4) sit exactly at
  `count_boot=2`, so we can't tell whether timeshift prunes B's when its own
  boot schedule is off until Haven reboots a 3rd time (rare). If B's ever climb
  past 2, prune manually and rethink. (2) **Explicit `W`/`M` cron lines are
  redundant** -- timeshift AUTO-PROMOTES the daily 04:23 `--tags D` create to
  weekly/monthly whenever that level is due (verified June 6 -> W, June 7 -> M),
  so the explicit 04:43 Sun W and 05:03 1st M lines in
  `conf/crontab/haven-timeshift.cron-d` double up on boundary days (June 7 got
  both a promoted M at 04:23 and an explicit W at 04:43; weekly transiently hit
  3 vs `count_weekly=2`). Decide whether to drop the explicit W/M lines and let
  promotion do the work (cleaner: one quiet-hour create/day, timeshift tags it).
  Low priority -- both paths are functional, just redundant. _(added 2026-06-08
  during Timeshift reschedule verification)_

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

- **anytime** — Figure out an ordered-playlist path for tracklists that were
  **NOT** on the old phone. The 2026-05-27 `peaceful` sync only worked because the
  app ("Music Player", `mp3.music.download.player.music.search`) had cloud-restored
  the playlist's track order from the old phone; a brand-new playlist has no
  remembered order. The app has no m3u import, ignores MediaStore playlists, and
  its private playlist DB is unreachable (not rooted, not debuggable, `adb backup`
  is empty on Android 13). Options to evaluate: (a) manual in-app reorder; (b) a
  different player that reads MediaStore/`.m3u` playlists (the MediaStore-injection
  recipe already produces a correctly-ordered system playlist such an app would
  pick up); (c) root. See `summary:phone-music-playlist-sync.md`.
  _(added 2026-05-27 during peaceful.m3u phone sync)_

- **anytime** — Install Syncthing on the new phone (`pixel-4a`) and set up
  continuous sync of the camera folder (`/sdcard/DCIM/Camera/`) to a tailnet
  peer — Avalir is the natural choice (already a Syncthing hub). Pulls photos
  off the phone without manual `adb pull` steps and works over both LAN and
  Tailscale when off-LAN. Fits the existing Syncthing architecture; will need
  a new folder definition on the receiving side and a per-device "send only"
  config on the phone. _(added 2026-05-25 during phone replacement session)_

- **anytime** — Vim control-key-map heisenbug: instrumentation is now live on the
  timer vim (keylog `-W`, event log, `\d`/`:TimerDump` capture → `~/local/log/vimkeys/`).
  When the bug next trips, press `\d` *before restarting*, then analyze the resulting
  `broken-<ts>.keys` (replay with `vim -s … -u ~/.vim-timer`) against `timer-events.log`
  to find the trigger. Remove the instrumentation once caught. See
  `summary:vim-control-key-map-bug.md` for the full signature and removal steps.
  _(added 2026-05-27 during vim control-key-map investigation)_

- **anytime** — Remove the `show-desktop` duplicate-session instrumentation once
  the `wmctrl`-based fix has proven out (give it a week or two of normal use, then
  confirm `~/local/log/show-desktop.log` shows only `-> MATCH` and never a spurious
  `-> NO MATCH` when a session was up). To remove: delete the `dbg()` sub, its
  call sites, the `$LOG` const, and the `pairmap` import (if unused elsewhere) in
  `bin/show-desktop`; delete the log file on each machine. The underlying fix
  (wmctrl detection replacing `xdotool search`) stays. _(added 2026-05-28 during
  show-desktop BadWindow-race diagnosis)_

## Done

- ~~2026-06-08~~ — Verify the Timeshift rescheduling (applied 2026-06-04).
  **VERIFIED working.** `sudo timeshift --list` on June 8 (via `ssh haven bash
  -s` heredoc -- a bare `bash -lc '...2>&1...'` fails because the remote tcsh
  re-parses the redirect): daily landed at `2026-06-08_04-23-02 D`,
  `count_daily=1` holding (single D, no accumulation); zero midday-drift
  snapshots (the original bug) -- every recent create is at 04:23/04:43, none
  at a random hour. `/etc/cron.d/timeshift-local` present and unmodified by
  timeshift; `schedule_boot=false` confirmed in `timeshift.json`; the two
  leftover timeshift-owned cron files (`timeshift-daily` 07:00, `timeshift-hourly`
  hourly) are both `--check` only, so harmless no-ops now that our crons own
  creation. The predicted "borderline" W/M did appear, but the MECHANISM was
  not what the jun4 summary guessed (it said ~05:00 self-creates via the hourly
  grid): timeshift AUTO-PROMOTES the 04:23 `--create --tags D` to weekly (June
  6, last W 7d prior) or monthly (June 7, last M 31d prior) when that level is
  due -- confirmed via each snapshot's `info.json` `tags` field (single tag
  each, not multi-tag). Two residuals (boot-prune-with-schedule-off still
  unprovable; explicit W/M cron lines redundant with promotion) spun out to a
  new anytime item above; summary doc corrected. _(added 2026-06-04 during June
  4 crash investigation, verified + completed 2026-06-08)_

- ~~2026-06-08~~ — Report mdcat's space-before-italics bug upstream. RESOLVED
  AS MOOT: swsnr/mdcat is no longer maintained -- README top line says so and
  the repo was ARCHIVED (read-only) 2025-01-10, which is why it has zero open
  issues (archiving closed them all and blocks new ones). No mirror/successor
  named; takeover-by-email only. So there is nowhere to file. Our diagnosis was
  corroborated anyway: changelog + PR GH-255 ("Flush trailing space before
  starting link... prevents the link from extending to the left, starting over
  a whitespace") is the LINK sibling of our bug -- mdcat had a general
  swallow-leading-space-into-styled-span pattern, fixed it for links, never
  fixed the emphasis/italic equivalent we hit. Our `bin/mdless` perl filter is
  therefore the permanent fix (no upstream patch will ever come). Upside: 2.7.1
  (2024-12-14) is the final release forever, so the pinned version + sha256 in
  the cheops build script never needs a feature/security bump -- the pin is now
  permanent by nature, not just by caution. Long-term watch-item only: if a
  future glibc bump ever bit-rots the 2.7.1 gnu binary, we'd need a replacement
  viewer (glow still the obvious fallback). _(added 2026-06-04, completed
  2026-06-08 during upstream-issue search)_

- ~~2026-06-05~~ — Make bold "pop" more in kitty. Side-by-side comparison
  (Bold/ExtraBold/Black test windows): user picked **Black** (900) for bold
  cells. Wired up: `bold_font Inconsolata Black` in `conf/kitty/kitty.conf`
  (synced, covers both boxes); Black face installed in `~/.fonts` on Avalir +
  Haven; `/var/install/Inconsolata.zip` rebuilt with Regular+Bold+Black on
  both; `setup/home-dir.setup` addfont line updated. Bold face (700) kept for
  generic fontconfig bold matches by other apps; unused ExtraBold trial face
  removed. Takes effect in new kitty windows. _(added and completed 2026-06-05
  after font side-by-sides)_

- ~~2026-06-04~~ — Diagnose quin markdown-rendering degradation + fix invisible
  bold globally. Root causes (all empirically verified): (1) glow under plain
  `TERM=screen` drops to termenv's no-color profile (`TERM=screen-256color`
  restores full 256-color output); (2) GNU screen 4.9 translates SGR 3 italics
  → SGR 7 reverse video (pty-harness capture; screen has no italics attribute —
  fixed upstream in screen 5.0); (3) mdcat 2.7.1 emits the space *before* an
  emphasis span inside the italic codes (off-by-one; filterable in a wrapper);
  (4) bold was invisible in EVERY kitty window since 2023 — `~/.fonts/
  Inconsolata.otf` was a single Medium face (no bold face existed) and kitty
  0.21.2 can't synthesize bold; `bold_is_bright` only rescued basic-8-color
  text (the kitty.conf comment blaming "tmux rendering buffer" weight loss was
  misattributed — it was the font). Fix: Google Inconsolata v3 Regular+Bold
  installed on Avalir AND Haven; `/var/install/Inconsolata.zip` rebuilt on both
  (old zip preserved as `Inconsolata-2011.zip`, old Medium face moved to
  `/tmp/Inconsolata-2011-medium.otf` on each box); `setup/home-dir.setup`
  updated to match. _(added and completed 2026-06-04 during markdown-viewer
  selection session)_

- ~~2026-06-04~~ — Investigate what reverted the `ionice` cron edit at
  `/etc/cron.d/timeshift-hourly` on Haven at 2026-05-17 14:00 PDT. **Solved:
  timeshift itself.** The file's mtime is 14:00:02.092 -- two seconds into the
  14:00 hourly `--check` run, 12 min after the 13:48 edit. Timeshift rewrites
  the cron files it owns (`timeshift-hourly`, `timeshift-boot`) to match its
  settings whenever it runs; direct edits to those files can never stick.
  Conversely, `/etc/cron.d/timeshift-daily` (custom, not timeshift-owned) has
  survived untouched since Jan 2025 -- the safe pattern for our own scheduling.
  _(added 2026-05-23 during May 17 follow-up audit, completed 2026-06-04 during
  June 4 crash investigation)_

- ~~2026-06-03~~ — Re-run + analyze `ac-mode report` (was the 2026-06-01 item).
  Result: office-ac remains the highest-rate mode (0.766/hr, 18.4/day) vs a ~12-13/day
  floor common to all modes incl. USB-C (so the original "drop to 8-9/day" prediction
  was unsound -- floor-dominated). office-ac's ~5/day excess is real, consistent, and
  held up even after being moved out of the suspend-heavy overnight block -- but only
  ~1.5-1.8 sigma and an indirect proxy (transitions, not crashes). No strict-avoidance
  week needed; next step is the empirical adapter swap (new Outstanding item). Full
  writeup in `summary:haven-may22-double-crash.md`. _(added 2026-05-23, completed
  2026-06-03 during Vivaldi tab-stacking session)_

- ~~2026-06-03~~ — Dispose of the pre-7.9 Vivaldi profile snapshots. Instead of
  deleting (the original plan), **relocated** them into the synced backup share so
  they're preserved + redundant, matching the existing `config/<host>-<date>/vivaldi/`
  convention: Avalir's 4.1 GB → `/export/backup/snapshots/config/avalir-pre-7.9-20260526/vivaldi/`
  and Haven's own 4.0 GB orphan (was untracked) → `.../config/haven-pre-7.9-20260508/vivaldi/`.
  Sources under `~/.config/vivaldi.bak.pre-7.9` removed on both boxes; Syncthing
  replicates the backup-share copies across the mesh. _(added 2026-05-26 during
  Avalir Vivaldi 7.9 upgrade, completed 2026-06-03 during Vivaldi tab-stacking session)_

- ~~2026-05-25~~ — Remove stale `google-pixel-4a` node (100.98.252.81) from
  Tailscale admin console. Old phone was replaced 2026-05-25; new phone is
  `pixel-4a` at 100.76.67.17. _(added 2026-05-25 during phone replacement
  session, completed 2026-05-25)_

- ~~2026-05-25~~ — Test the spare AC adapter at the office (originally framed
  as carrying the spare to the office for a side-by-side comparison). Resolved
  by realizing the existing labels already give a clean comparison: spare
  adapter lives permanently in the den (`den-ac` label, 0.46/hr) and main
  adapter lives permanently in the office (`office-ac` label, 0.67/hr). Spare
  is ~45% cleaner; combined with office-usb / office-both at the same ~0.49/hr
  baseline as den-ac, the office adapter+cable is the suspect path (not the
  barrel jack — that's shared by den-ac and would have elevated it too).
  Follow-up captured in the 2026-06-01 office-ac-avoidance review.
  _(added 2026-05-23 during May 22 double-crash mitigations, completed
  2026-05-25 during May 22–25 data analysis)_

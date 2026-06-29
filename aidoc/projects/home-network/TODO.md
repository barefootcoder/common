# Home Network — Outstanding Tasks

Follow-up work deferred from previous sessions. The `x-aidoc-project`
skill scans this file on load and surfaces due/pending items.

## Outstanding

- **anytime (SECURITY)** — Resolve Nakama's stuck QTS firmware update. The
  2026-06-20 attempt to go 5.2.7 (build 20251024) -> 5.2.9.3499 silently FAILED
  and the box reverted to 5.2.7 (still there as of 2026-06-28, uptime confirms the
  Jun 20 reboot was that failed attempt). This is now SECURITY-relevant, not just
  hygiene: the 3-month QNAP email scan (2026-06-28) found **QSA-26-10 explicitly
  names QTS 5.2.7 as affected** (Important; 14 CVEs incl. pre-auth command
  injection; fixed in exactly 5.2.9.3499), plus **QSA-26-17 "Dirty Frag" kernel
  LPE** (affects all x86 models -> Nakama is x86/Celeron N5095), plus the 5.2.8
  backlog (Apache QSA-26-04, QTS QSA-26-05, Samba QSA-26-06 -- all installed).
  EXPOSURE checked 2026-06-28: external probe from quin shows NO direct WAN
  exposure (all ports closed on the home public IP -- 80/443/8080/2322/445/
  8384/22000/2376), Eero default-deny, no active DDNS, no UPnP forward. The only
  internet path is myQNAPcloud VLINK/CloudLink (enabled, `VLINK=TRUE`), an
  outbound relay gated by QNAP-ID login. Long-term goal IS intentional exposure,
  which raises the pre-auth CVE stakes -- so patch BEFORE exposing. Documented next step
  (`nakama-firmware-update-fixes.md` Issue 3): do NOT retry blindly -- read QuLog
  Center -> System Event Log around the Jun 20 02:0x timestamp for the real failure
  reason. Space theory is now WEAKER (user checked QuLog at the failure
  time and found NOTHING; `/mnt/ext` is 92% full / 33.6M free but is almost
  entirely CORE system QPKGs -- samba/apache/mariadb/notification-center/netmgr/
  lang -- with essentially nothing removable, so "free /mnt/ext by removing unused
  QPKGs" has little to work with; `/` is 85% / 62M free). If a later check DOES
  cite FW_NOFREESPACE, better levers than scavenging /mnt/ext: stage to the data
  volume (UPDATE_TMP_PARTITION is unset) or do a Manual Update (download the
  5.2.9.3499 .img, flash via Control Panel -> Firmware Update -> Manual Update),
  which also tends to surface a clearer error than Live Update. Expect the Issue-1 /share/homes
  symlink + key-SSH breakage afterward -> run `nakama-firmware-fix` once it
  finishes. SEPARATELY, App Center app updates ARE flowing (newer FileStation5.bin
  staged Jun 26, LicenseCenter.bin May 14): update **License Center** via App Center
  to clear the **Critical** QSA-26-35 (QuMagie part N/A -- not installed) and File
  Station 5 for QSA-26-03. _(added 2026-06-28 during the QNAP/Nakama email scan)_

- **anytime** — Decide how to handle Nakama's recurring "80%" storage alert. As of
  2026-06-28 the data volume (DataVol1) is 2.8T total / ~558G free / 80% used, and
  the threshold alert has re-fired Apr 4 -> Jun 20 -> Jun 28 (free space drifting
  down slowly, not an emergency). Nakama is a SINGLE 4TB drive (md1 = 1-disk RAID1,
  clean/healthy -- no redundancy; relies on the B2 backup), and it is also a
  Syncthing mirror + Container Station/Docker host on that same volume, so growth
  will continue. Options: (a) clean up (find/remove large unneeded data; check
  Docker/Container overlay + snapshots); (b) raise the alert threshold (Control
  Panel -> Storage & Snapshots) to stop the nag if 80% is acceptable headroom; (c)
  expand storage (bigger drive, or add a 2nd bay -- TS-364 has 3). No urgency; the
  new `qnap-mail-check` will resurface it if free space keeps falling. NOTE: this
  is the DATA volume, a different filesystem from the tiny `/` + `/mnt/ext` system
  partitions in the firmware-update item above -- freeing one does not help the
  other. _(added 2026-06-28 during the QNAP/Nakama email scan)_

- **2026-07-05** — Run the weekly QNAP/Nakama mail review: `qnap-mail-check` (on
  Haven, or from any box -- it re-execs to Haven). Triage anything it surfaces
  (security advisories, device Critical/storage/network/power alerts); the routine
  IHM + marketing noise is auto-suppressed. **RECURRING -- re-arm on completion:**
  when done, move this to Done with the completion date AND re-add a fresh copy
  dated +7 days (`date -d '+7 days' +%F`). Interval rationale: QNAP advisories land
  roughly every 1-2 weeks and the check is cheap, so weekly keeps detection latency
  short without nagging. **Cadence is adjustable:** weekly/bi-weekly is fine while
  Nakama stays non-internet-exposed (confirmed not exposed 2026-06-28); TIGHTEN it
  once intentional exposure is turned on (the pre-auth QTS CVEs start mattering in
  real time then). If this ever gets wired to cron, retire this recurring item.
  _(added 2026-06-28 during the QNAP/Nakama email scan)_

- **anytime** — Confirm the "Reset Window Manager" panel launcher actually runs
  the new `/usr/local/sbin/fix-wm` rather than the cached old `marco --replace`.
  mate-panel caches launcher .desktop data at load, so the `Exec` change may not
  take effect until the panel reloads / next login (Avalir rarely relogs). Test
  by clicking it: a clean single-WM restart with no D-Bus `Hello` storm after =
  good. If it still runs the old command, the panel needs a reload to pick it up.
  See `summary:avalir-marco-respawn-loop.md`. _(added 2026-06-23 during the
  marco-respawn-loop fix)_

- **anytime** — Add a marco-respawn-loop watchdog. **If you are a future agent
  seeing a recurrence of this -- `xdg-desktop-portal` (or another bus-tracking
  daemon) ballooning in swap, a marco PID-churn / D-Bus `Hello` storm, a runaway
  `~/.xsession-errors` -- your FIRST thought should be to extend `fix-wm` into a
  self-healing watcher (or something similar), not to just hand-fix it again.**
  `fix-wm` stops the *user* from re-igniting the loop, but a spontaneous marco
  crash can still kick mate-session into it (that is how the 2026-06-23 episode
  started, after a May 28 marco coredump). A small pidfile-gated monitor (viv-mon
  / keymap-mon style) that watches for the marco PID churn or `Hello` storm and
  auto-runs `fix-wm` makes it self-healing. Left parked (belt-and-suspenders)
  until then. See `summary:avalir-marco-respawn-loop.md`. _(added 2026-06-23
  during the marco-respawn-loop diagnosis)_

- **anytime** — Confirm `bulk-charge-mon`'s live-`%` update fires in a real bulk
  cycle. The notify path was fixed 2026-06-11 (gdbus, not notify-send -- Haven's
  libnotify 0.7.9 lacks `--print-id`/`--replace-id`, so the original silently
  fired NOTHING, which is why no popup ever appeared), and a live-update refresh
  branch was added (re-`Notify` with the same `replaces_id` when the integer %
  moves). The quiet in-place update was verified with a synthetic test bubble,
  but the refresh branch itself hasn't run in an actual bulk-charge yet (battery
  was too full to trigger one). Next time Haven is plugged in below ~80%, watch
  the "Haven is bulk-charging" bubble climb its % in place, and check
  `~/local/log/bulk-charge-mon.log` for the BULK on/off pair. See the
  "bulk-charge-mon" tool entry in README. _(added 2026-06-11 during the
  notify-path fix + live-update build)_

- **anytime** — Avalir trackball lag: identify the interferer / find a fix. The
  2.4GHz-Unifying-link diagnosis is confirmed (not USB / not autosuspend / not
  battery / not host software -- see `summary:avalir-trackball-lag.md`); the
  `~/oneoff/trackball-mon` watcher caught its **first full episode 2026-06-17**
  (15:24-~15:29, 3 logged jumps, solaar `offline` coincident with a jump --
  signature reconfirmed). Root cause (what changed ~early June) and a fix are
  still open. **NOTE (user, 2026-06-17): nothing changed on Avalir's side ~Jun 9-10,
  and the Haven-trackball arrangement is NOT new** -- the user has brought Haven +
  its mouse into this room for months/years. So if the onset is real (and the
  Jun 9/10 powertop spike + two captured episodes say it is), the trigger is either
  EXTERNAL to the user's gear (a neighbor's/new RF source) or the Avalir link
  hardware itself degrading intermittently -- not anything on Avalir or a new Haven
  habit. This lowers the prior on the Haven-mouse test below but doesn't kill it
  (a long-tolerated emitter can start mattering once the link goes marginal).
  Follow-ups: (a) ~~analyze the log~~ DONE for the 2026-06-17 episode
  (signature confirmed; thresholds gap=0.3s/jump=150 caught it fine, no tuning
  needed yet); (b) **Haven-mouse test UPGRADED + ONGOING (2026-06-18 readout).**
  First readout: ~27h with zero JUMP episodes after Haven's M570 went off
  ~2026-06-17 15:30, monitor confirmed alive the whole time -- but INCONCLUSIVE,
  because the baseline is only ~1 episode per ~6 days (the monitor ran Jun 11->17
  catching nothing before the first cluster), so a 1-day clean window is exactly
  what an *unchanged* setup would show too. The 02:50 reminder fired and was
  dismissed 04:53 as designed. **The test is now both stronger and free, so it
  just continues:** the user has returned to the pre-investigation arrangement and
  Haven's M570 now lives permanently in the den, 3-4 rooms from Haven (full
  physical separation, not merely powered off) and no longer travels with Haven --
  so the bedtime reminder is OBSOLETE and retired (its whole job was catching an
  overnight re-enable that can't happen now; the one-shot already fired+finished,
  not re-armed). Zero cost because the M570 was only ever in the office to spare
  Haven's *touchpad* (an old crash suspect, since superseded by the AC-adapter
  theory); the touchpad is fine to use now. **Timeline confound (sharpens the low
  prior):** the user was bringing the M570 into the office WELL BEFORE the ~6/10
  jump onset, so its mere presence demonstrably coexisted with months of
  no-jumping -- it can only be the cause in the weak "long-tolerated emitter turns
  harmful once the link goes marginal" form. Re-check the log after a multi-day
  clean stretch (see the dated 2026-07-02 item below).
  (c) **Bluetooth EXONERATED + RE-ENABLED 2026-06-17** -- the
  lag recurred with BT soft-blocked, so BT is cleared; `sudo rfkill unblock
  bluetooth` run, README "Deliberately disabled" BT entry removed. (d) if it
  proves useful, promote the monitor to `local/avalir/bin/` + termstart
  (pidfile-gated like viv-mon) -- it has now proven its worth, so this is a
  reasonable do-anytime; (e) fallback fixes if confirmed RF-on-marginal-link:
  USB extension cable for line-of-sight, spare Unifying receiver via solaar re-pair,
  or MX Ergo on Bluetooth via Easy-Switch as an A/B. _(added 2026-06-11 during the
  trackball-lag investigation; updated 2026-06-17 after the first monitor capture)_

- **2026-07-02** — Re-check the Haven-mouse-OFF trackball test, now a permanent
  physical-separation test (Haven's M570 has lived in the den, 3-4 rooms away,
  since 2026-06-17). Must run ON Avalir -- `~/local/log/trackball-mon.log` is
  host-local, not synced, so this can't be a cloud agent. The 2026-06-18 first
  readout was clean but INCONCLUSIVE: baseline is only ~1 episode per ~6 days, so
  one clean day proves nothing (see Done). By 2026-07-02 the M570 will have been
  gone ~2 weeks = ~2 baseline intervals -- the first window big enough to mean
  something. Scan the log for JUMP lines after 2026-06-17 15:30, and confirm
  `trackball-mon` is still alive (`pgrep -af trackball-mon`; it's a perl script, so
  bare `pgrep trackball-mon` matches nothing). Verdict: **a multi-day clean stretch
  with the M570 in the den** = Haven's trackball implicated despite the timeline
  confound (then pursue per the main trackball item's fallback fixes (e)); **JUMPs
  still occurring** = M570 cleared, refocus on external RF / Avalir link-hardware
  degradation (the two leading hypotheses). No reminder to re-arm -- the M570 no
  longer travels with Haven. _(added 2026-06-18 during the trackball test readout,
  supersedes the spent 2026-06-18 readout item)_

- **anytime** — Haven charging discipline (June 10 crash mitigations, behavior +
  config, no code). The June 10 crash needed three legs stacked; the two easiest
  to remove are about charging: (1) **switch office charging to office-usb**
  (USB-C) instead of the suspect office-ac adapter -- avoids the suspect
  adapter+cable path AND USB-C PD's lower wattage limits the bulk-charge spike;
  (2) **don't let the battery run down to ~16% before plugging in** -- a near-flat
  40%-health pack bulk-charges at a constant ~21W, which is what stacked onto the
  video+NoMachine load and crossed the adapter's limit. Keeping it topped up keeps
  charging in trickle/taper. Both are user habits, captured here so they're not
  lost. See `summary:haven-jun10-video-crash.md` "Mitigations". _(added 2026-06-10
  during June 10 crash investigation)_

- **anytime** — (Optional) Try a NoMachine frame-rate / quality cap if further
  video-over-NoMachine power reduction is wanted. Background: the marco-
  compositing-off measurement is DONE (2026-06-10, see Done) -- compositing-off
  is a free but MODEST GPU-clock-up trim that does NOT reduce pkg power, because
  pkg during video-over-NoMachine is CPU-dominated (software decode + NoMachine
  capture/encode), with the GPU 75-85% idle. So the `EnableEGLCapture 0` idea is
  RULED OUT (it would shift capture onto the already-loaded CPU and raise pkg).
  The only NoMachine knob that would actually cut pkg is reducing the streamed
  frame rate / quality (fewer captures+encodes per second). Untried; low priority
  since the charging-discipline + hardware levers dominate. See
  `summary:haven-jun10-video-crash.md` "Mitigations" #4. _(added 2026-06-10)_

- **anytime** — Notification system: add a "delay before popup" option so a
  subscribed Claude only escalates to the Haven zenity URGENT popup after it has
  been waiting > ~30-60s (you genuinely stepped away), instead of instantly.
  Would use the marker's `timestamp` field. Deferred as a future feature during
  the 2026-06-09 opt-in-notifications build (user: "enticing, but maybe a future
  feature"). _(added 2026-06-09 during claude-notify build)_

- **anytime** — DRY up `bin/term-quin` to use the new `bin/sandbox-ssh-target`
  helper (which was extracted from term-quin's own Tailscale-IP lookup during
  the 2026-06-09 notification build). term-quin still carries its own inline copy
  of the `tailscale status | awk '/quin-/'` logic; point it at sandbox-ssh-target
  so there's a single definition of "how to reach the current sandbox". Low risk,
  but it touches the daily sandbox launcher, so verify an actual `term-quin`
  launch afterward. _(added 2026-06-09 during claude-notify build)_

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
  the BT reproducer to verify survival. **Deferred 2026-06-09 (user decision):
  the stopgap is now PROVEN -- keymap-mon caught and reapplied a real wipe on
  2026-06-06 (15:22:55 -> 15:22:56, ~1s), and the user has used the ECOXGEAR
  since with no colon breakage -- so we wait for the wipe to recur DESPITE the
  stopgap, or for NumLock fragility to actually bite, before doing the XKB
  surgery.** Two implementation refinements for when it's taken up (prefer
  `~/.config/xkb/` over editing `/usr/share/X11/xkb/`; prove survival via the
  reproducer and keep keymap-mon as a backstop) are in the investigation doc's
  "Status (2026-06-09)" note. _(added 2026-06-04 during June 4 crash
  investigation; stopgap completed same day; durable fix deferred 2026-06-09)_

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

- **2026-06-22** — Analyze the empirical office AC adapter swap (the next step out
  of the 2026-06-03 ac-mode analysis). **SWAPPED IN 2026-06-15:** the DTK 90W
  19V/4.74A 5.5x2.5mm barrel adapter (Amazon, $17; ordered 2026-06-12) replaced the
  suspect old office barrel adapter (now labeled `spare-ac`) at the office. The DTK
  is a generic match for `den-ac`'s spec (Chicony A16-090P1A: 90W, 19V/4.74A,
  5.5x2.5mm barrel; Haven = Clevo NS5x/NS7xAU, standard N-series tip). den-ac is a
  SEPARATE, known-good Chicony that lives in the den and is staying; it is the unit
  we have a photo of (`~/docs/ai/screenshots/chicony-laptop-adapter.jpg`, Jun 11),
  and the A16-090P1A model number + 19.0V/4.74A/90W rating were read straight off
  that label -- so A16-090P1A IS den-ac, NOT the retired office adapter and not
  (verified) any "Haven OEM" unit. The DTK's tip was verified by the user via
  direct visual A/B against den-ac: identical barrel, dimple ring, inner-barrel
  flathead slots, right-angle two-level housing. The retired office adapter (now
  `spare-ac`) is itself a Chicony but a DIFFERENT physical unit, exact model
  unconfirmed (user's read: possibly a bit smaller than den-ac). **Boundary mark:** `2026-06-15T19:05:18-0700 office-ac` --
  every `office-ac` event after that timestamp is the NEW adapter. We KEPT the
  `office-ac` label (did NOT relabel): `ac-mode report` renders one row per
  mark-interval, so the fresh mark isolates the new adapter's data automatically
  while the pre-June-10 office-ac intervals stay as the frozen ~18/day baseline.
  **On/after 2026-06-22 (~1 week of normal office use on the new adapter):** run
  `ac-mode report '2026-06-15 19:05:18'` and read the office-ac interval row(s)
  since the boundary. office-ac falling to the ~13/day common floor = the old
  adapter was the culprit (CONFIRMED); staying at ~18/day = old adapter exonerated,
  points at the laptop's barrel jack / internal AC path. Note: since June 10 the
  user had been deliberately on `office-usb`/`den-ac` (charging-discipline
  mitigation), so the office-ac slot was cold for 5 days before this swap -- clean
  start. **Then decide old-adapter disposition** (do NOT toss it before the verdict
  -- it's the control): if confirmed flaky, retire it from Haven (the box already
  has den-ac + the new office brick, so it's redundant) -- keep as a clearly-labeled
  low-load/emergency spare, NOT for the high-draw office video-over-NoMachine
  scenario or bulk-charging a low battery. If it's ever pressed into Haven service,
  mark it `spare-ac` (label already added to `@LABELS` in `bin/ac-mode` 2026-06-15)
  so its events don't contaminate the new adapter's clean office-ac data. See the "ac-mode
  analysis (2026-06-03)" section of `summary:haven-may22-double-crash.md`. _(added
  2026-06-03, supersedes the spent "re-run after avoidance week" item; ordered
  2026-06-12; swapped in + analysis scheduled 2026-06-15)_

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

- **anytime**: NAS sync/backup tasks now live in the **nas-sync** subproject
  (`nas-sync/TODO.md` + `nas-sync/roadmap.md`; run `nas-sync/bin/whats-next`).
  Moved out so main-project agents don't contend over them. Covers the
  Nakama->B2 rclone cron, the Avalir survey-gap backups, the `~/.config/`
  cleanup, and the Nakama `/share/{music,camera,rpg}` B2 sweep. **Add new NAS
  sync/backup items there, not here.** _(migrated 2026-06-20)_

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

## Done

- ~~2026-06-18~~ — Remove the `show-desktop` duplicate-session instrumentation,
  now that the `wmctrl`-based fix has proven out. **DONE.** The fix landed
  2026-05-28 (`2708cf7`); its `dbg()` probe then logged 405 invocations over 3
  weeks with ZERO spurious `-> NO MATCH` (every miss genuinely had no session in
  the window list), confirming it. Removed the `dbg()` sub, its call sites, the
  `$LOG` const, the `$arg` helper, and the now-unused `pairmap` import from
  `bin/show-desktop` (the `wmctrl` detection + its rationale comment stay), and
  deleted `~/local/log/show-desktop.log` on Avalir (29137 lines) and Haven (16255
  lines). Done alongside the sibling `pidgin_restore` fix for the same BadWindow
  tree-walk race. _(added 2026-05-28 during show-desktop BadWindow-race diagnosis,
  completed 2026-06-18)_

- ~~2026-06-18~~ — Read out the Haven-mouse-off trackball test (set up 2026-06-17).
  **DONE; verdict INCONCLUSIVE.** `trackball-mon` confirmed alive the whole window
  (pid 164896, continuous since the 2026-06-11 deploy) and logged ZERO JUMP
  episodes in the ~27h after Haven's M570 went off ~2026-06-17 15:30 (readout at
  2026-06-18 18:38). The 02:50 reminder fired and was dismissed 04:53 (reminder log
  FIRE/closed pair) -- worked as designed. BUT the baseline is only ~1 episode per
  ~6 days (monitor caught nothing Jun 11->17 before the first cluster), so a 27h
  clean window is uninformative -- exactly what an unchanged setup would show.
  Couldn't confirm from Haven that the M570 was physically off (its Unifying
  pairing persists in the kernel whether on or off, and solaar isn't installed on
  Haven), but the user reports it's now 3-4 rooms away in the den. Outcome: test
  upgraded to permanent physical separation, bedtime reminder retired (obsolete),
  timeline confound recorded (M570 was in the office well before the ~6/10 onset),
  and a dated 2026-07-02 re-check added (see Outstanding); main trackball item's
  sub-item (b) updated. _(added 2026-06-17 during the bedtime-reminder setup,
  completed 2026-06-18 during the readout)_

- ~~2026-06-12~~ — Fix vivaldi-guard's NoMachine detection gap. **DONE** (user
  approved; applied to `bin/vivaldi-guard`, synced to both boxes). The original
  framing here was too strong and is corrected: the guard's block has NOT "never
  fired" -- it fires constantly via `nxplayer.bin` (the client), and the user
  confirmed it blocks in both directions in everyday use. Live process data
  (2026-06-12, both boxes mutually viewing) explained why: the guard keys off
  the CLIENT process, but in the user's usual bidirectional pairing BOTH boxes
  run a client, so it trips on each. The real gap is narrower: the crash-risk
  LOAD is on the SERVED box (running `nxnode.bin -H` + `nxcodec.bin`, capturing/
  encoding its framebuffer -- the part `--disable-gpu` can't touch), and the
  guard catches that only INCIDENTALLY (because the served box is usually also a
  client). In a ONE-directional session (A views B, B not viewing back), the
  served box B runs only `nxnode.bin -H` -- no client, no nxagent -- so the guard
  did NOT fire on it. That is exactly the 2026-06-10 Haven state (`nxnode -H 31`,
  zero nxplayer/nxagent) when vivaldi-media ran unguarded and the box crashed.
  Fix: added `nxnode\.bin -H` to the guard's `pgrep -f` alternation. Validated
  live on both boxes -- the ` -H` anchor matches an active served session but
  NOT the always-running bare `nxnode.bin` daemon worker (matching plain
  `nxnode` would block Vivaldi permanently). Comment block rewritten to document
  all three roles + the one-directional rationale. Note: the clause is
  host-agnostic (matches the existing "block in either direction" intent), so it
  will also block a Vivaldi launch on Avalir when Avalir is being served
  one-directionally -- harmless (Avalir has no crash risk) but a new block;
  gate the clause to Haven if that ever annoys. See
  `summary:haven-jun10-video-crash.md` "Why vivaldi-guard does not prevent this
  class". _(added 2026-06-10 during June 10 crash investigation, completed
  2026-06-12 during the doc-notes + TLP-cap session)_

- ~~2026-06-12~~ — Configure TLP to enforce the Haven GPU frequency cap across
  AC events. **DONE + VERIFIED (config side).** Uncommented and set the four
  MAX/BOOST lines in `/etc/tlp.d/juno-tlp.conf` to 400
  (`INTEL_GPU_MAX_FREQ_ON_AC`, `INTEL_GPU_BOOST_FREQ_ON_AC`,
  `INTEL_GPU_MAX_FREQ_ON_BAT`, `INTEL_GPU_BOOST_FREQ_ON_BAT`); the two MIN lines
  left at the commented `=0` default. Original backed up to
  `/etc/tlp.d/juno-tlp.conf.pre-gpucap.bak` first. Reloaded with `sudo tlp
  start`; `tlp-stat -g` now reports `gt_max_freq_mhz=400` /
  `gt_boost_freq_mhz=400` (hardware RP0 ceiling is 1500, so it is a real cap).
  This makes the 400 cap durable across mid-session AC events -- TLP re-applies
  GPU freq on every AC connect/disconnect -- instead of relying solely on
  termstart's one-time boot write, closing the gap behind the June 10 crash's
  gfreq=600/600-during-decode reading. Edited over `ssh` from Avalir;
  `/etc/tlp.d/` is host-local so this change lives only on Haven (not synced).
  **Remaining (user, physical only):** confirm with an actual unplug/replug that
  `gt_max_freq_mhz` stays 400 across the AC transition. _(added 2026-06-10
  during June 10 crash investigation, completed 2026-06-12 during the
  doc-notes + TLP-cap session)_

- ~~2026-06-10~~ — Quantify the marco-compositing-off win during video-over-
  NoMachine. **MEASURED** via a controlled 45s-off / 45s-on / back-off sweep on
  the same video (viv-mon as instrument; intel_gpu_top not installed). Result:
  compositing OFF = pkg 10.63W mean, GPU idle 221ms (~85%), GPU clock-ups
  (cur>300) 0%; compositing ON = pkg 10.56W, GPU idle 196ms (~75%), clock-ups
  15%; neither hit 600MHz. So compositing-off is a free but MODEST GPU-clock-up
  trim that does NOT move pkg power -- because pkg during video-over-NoMachine is
  CPU-dominated (software decode + NoMachine capture/encode), GPU 75-85% idle.
  Kept compositing OFF (free, no power cost). Ruled out `EnableEGLCapture 0`
  (would shift capture to the loaded CPU, raising pkg); a NoMachine frame-rate
  cap is the only knob that would cut pkg (spun out to an optional Outstanding
  item). Full detail in `summary:haven-jun10-video-crash.md` "Mitigations" #4.
  _(added + completed 2026-06-10 during June 10 crash investigation)_

- ~~2026-06-09~~ — Verify the GPU frequency cap is holding (applied 2026-06-04).
  **VERIFIED holding; kept at 400** (user reports no sluggishness, so NOT bumped
  to 700). Checked on Haven *directly* -- no ssh, since `hostname` confirmed I
  was already on the box (an earlier attempt this session wastefully `ssh`ed into
  Haven from Haven; that mistake drove the README "FIRST: confirm which host"
  and heredoc-quoting doc updates). `gt_max_freq_mhz` and `gt_boost_freq_mhz`
  both read 400, written by `local/bin/termstart` lines 30-31 (survive the rare
  crash-reboot). Rapid live sampling never showed either deviate. Boot time
  2026-06-04 19:12:49 = the post-Jun-4-crash boot, so the cap has been live ~5
  days with no crash (first endurance test, passed). **Gotcha recorded for
  future viv-mon readers (also added to `summary:haven-jun4-gpu-ramp-crash.md`):**
  viv-mon's `gfreq=cur/act` column shows values up to 600 in the log, which LOOKS
  like a cap breach but is NOT. `gt_cur_freq_mhz` (requested) is reported
  unclamped during RC6 idle, and `gt_act_freq_mhz` latches stale values across
  idle->wake boundaries. 99.75% of the act=600 readings (1991/1996 across both
  logs) coincide with the GPU confirmed idle (rc6 accumulating the full poll
  interval); the 5 "busy" exceptions all carry low power (pkg ~4W, nowhere near
  a real 600MHz draw) and one even shows cur=350 < act=600 (backwards). No
  act>400 reading is corroborated by a power spike. The cap reads 400/400
  rock-solid; the 600s are i915 RC6 sysfs readout artifacts, not real operation.
  _(added 2026-06-04 during June 4 crash mitigations, verified + completed
  2026-06-09)_

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

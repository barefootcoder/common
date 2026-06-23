# Home Network Project

This project contains documentation and management information for the home network infrastructure.

## Project Overview

This is a mixed-platform home network with Linux systems, NAS storage, and smart home devices. The network is currently undergoing upgrades, particularly the replacement of a Synology NAS with a more powerful QNAP system.

## CRITICAL: System Environment Notes

### FIRST: confirm which host you are on before doing any host work
**The single most common agent mistake in this project is doing work on the
wrong machine -- or, worse, `ssh`-ing into the very box you are already running
on.** These machines share `~/common` (and much else) over Syncthing, so the
filesystem looks identical everywhere and it is genuinely easy to lose track of
where you are. This has actually happened: an agent ran `ssh haven bash -s`
repeatedly *while already on Haven*, looping back into itself over SSH and
fighting the tcsh quoting trap (below) the whole time, for commands it could
have just run directly.

Before any host-specific action (reading `/sys`, restarting a watcher, checking
`journalctl`, editing host-local files under `~/local`, inspecting the live
process table):

1. **Run `aidoc/check-environment`.** It reports which box you are on, whether
   your cwd and `~/common` are symlinks (and to where), and whether the git base
   is sound. (Bare `hostname` is enough if you only need the machine name.)
2. **If you are ALREADY on the target host, run the command directly** -- do not
   `ssh haven ...` from Haven. It loops back into yourself over SSH, wastes a
   round trip, and needlessly drags a perfectly good command through the tcsh
   login-shell quoting trap.
3. **Only reach for `ssh <host>` when that proves you are on a different box**
   (e.g. driving Haven from Avalir, or vice versa).

Tell-tale host-local paths that do NOT sync, so they differ per machine and
help confirm where you are: `~/local/`, `~/local/log/`, `/var/install/`, `/sys`,
and the live process table.

### Multiple agents edit these docs at once: re-read before you write
The `TODO.md` and `README.md` for this project are the files most likely to be
touched by another agent concurrently -- multiple sessions across Haven, Avalir,
etc. all maintain them, and Syncthing merges the tree underneath you. Two
consequences:

1. **Re-read right before editing.** A `TODO.md`/`README.md` you read at the
   start of the session may have changed by the time you go to write. If an
   Edit is rejected as stale, re-read and redo it -- do not try to force it
   through. (This very session saw exactly that: the `TODO.md` had grown two
   new items from another session mid-task.)
2. **At commit time, stage only your own changes**, by explicit path -- never
   `git add -A` / `git commit -a`. The working tree may hold another agent's
   in-flight edits to these same docs, and committing them as yours is the
   classic mistake here. `/x-commit` guards against this, but the scope is
   your responsibility.

### Uptime — Haven and Avalir do NOT reboot
**Common agent mistake:** assuming these machines reboot or shut down on any
normal cadence. They don't. Haven and Avalir effectively **never** shut down or
reboot except under extreme circumstances — Avalir's uptime is routinely measured
in *months* (165+ days is normal), and Haven only ever restarts when it *crashes*
(the recurring hardware instability), never a deliberate reboot. Do **not** assume
a reboot will clear state, restart a detached process, or reload config — a process
you start will keep running for months. If something must survive the *rare* crash,
treat that as the exceptional case (wire it into `termstart`), not the norm.

### Password-less sudo on Avalir and Haven
Both Avalir and Haven are set up for **password-less `sudo`** for the primary
user: `sudo` runs privileged commands without ever prompting for a password.
An agent can therefore run `sudo` freely (e.g. `sudo tlp start`, `sudo tee`
into `/etc/...`, editing root-owned config, `sudo journalctl`) without needing
a password and without the call silently hanging on a hidden prompt -- this
holds both on the box directly and when driving it over `ssh` (verified on
Haven via `sudo -n true`). This is specific to Avalir and Haven; do NOT assume
it on quin or other hosts.

### Encrypted root disks (LUKS) on Avalir and Haven
Both boxes run with their **root/system disk LUKS-encrypted** behind a fairly
long passphrase. `/etc/crypttab`'s key field is `none` -- no keyfile, no TPM
auto-unlock -- so the passphrase is typed at boot. Implications:
- `fdisk -l` / `lsblk` show a `crypto_LUKS` partition feeding a `dm-crypt`
  mapper into LVM (`vgmint-root` = `/`), NOT a plain filesystem on the raw
  partition. That is expected, not a misconfiguration. Per-host layout:
  - **Avalir**: single NVMe; `nvme0n1p3` (crypto_LUKS) -> `nvme0n1p3_crypt`
    -> `vgmint-root` (`/`). `/export` lives *inside* the encrypted root, so on
    Avalir effectively everything is encrypted at rest.
  - **Haven**: `nvme0n1p3` (crypto_LUKS) -> `nvme1n1p3_crypt` (the mapper name
    reflects the NVMe enumeration flip noted in the fstab-UUID summary) ->
    `vgmint-root` (`/`). But Haven's big **`/export` data partition
    (`nvme1n1p1`, ~950G) is plain ext4, NOT encrypted** -- the Syncthing-shared
    tree at rest is in the clear on Haven.
- Because the key is a boot-time passphrase (no auto-unlock), a **cold boot
  stops at a LUKS prompt that must be answered at the console.** Combined with
  "Haven and Avalir do NOT reboot" above, the disks are effectively
  always-unlocked in steady state -- but a Haven crash-reboot does NOT come
  back unattended: someone has to type the passphrase first.
- For security reasoning: data at rest on the encrypted volumes is protected,
  so weight live/online compromise over physical-disk theft -- with the caveat
  that Haven's `/export` is the exception (unencrypted at rest).

### Deliberately disabled -- so don't assume "broken" means broken
Hardware/services intentionally turned off on a given box, recorded here so a
future "why doesn't X work?" doesn't trigger a wild goose chase -- the answer
may simply be "we turned it off on purpose, here's how to undo it":

- _(Nothing currently disabled here.)_ **Bluetooth on Avalir was soft-blocked
  2026-06-11 -> 2026-06-17** as a 2.4GHz-interference elimination during the
  trackball-lag investigation, then **re-enabled 2026-06-17 once exonerated** (the
  trackball lag recurred with BT still blocked, so BT was cleared as a suspect).
  Kept here as a breadcrumb so a future agent knows the section is live but empty,
  not deleted. Background: `summary:avalir-trackball-lag.md`.

### Shell Environment (and the cross-host `ssh` quoting trap)
- **The interactive/login shell on every Linux box here (Haven, Avalir, Zadash,
  Caemlyn, quin) is `tcsh`, NOT bash.** A bare `ssh <host> '<command>'` runs
  `<command>` under the remote tcsh, which chokes on bash syntax (`$(...)`,
  `VAR=val`, `2>&1`, `for`/`if`, heredocs).
- **Why inline-quoted remote commands keep blowing up (the lesson that refuses
  to stick):** when you write `ssh haven bash -lc '...'`, YOUR local shell strips
  those quotes before `ssh` even runs, so `ssh` forwards the bare words, and the
  REMOTE tcsh then re-parses them -- splitting on `;`, spaces, and so on. The
  command gets chewed by two shells in a row, and piling on more quotes is just
  whack-a-mole. (Note: `bash -lc 'long; multi; statement'` falls into exactly
  this hole, despite naming bash, because the quotes never survive to bash.)
- **The form that is immune to all of it -- make it your DEFAULT for anything
  with a pipe, semicolon, redirect, loop, or more than a word or two of
  argument: a `bash -s` heredoc on stdin:**
  ```bash
  ssh haven bash -s <<'EOF'
  for f in gt_max_freq_mhz gt_cur_freq_mhz; do
      cat /sys/class/drm/card1/$f
  done
  EOF
  ```
  The single-quoted `<<'EOF'` stops your LOCAL shell from touching the body, and
  `bash -s` feeds that body to bash (not tcsh) verbatim on the REMOTE side. No
  quoting horrors; multi-line comes for free.
- A single trivial command inline is fine (`ssh haven uptime`), but the instant
  you need real shell syntax, go straight to the heredoc -- do not try to escape
  your way through tcsh.
- **And per the section above: check `hostname` first. If you are already on the
  target box, skip `ssh` entirely and just run the command.**

### Linux Mint Filesystem Structure  
- **UsrMerge implementation**: On Haven and Avalir (Linux Mint 21.1), these are symlinks:
  - `/bin` → `/usr/bin`
  - `/sbin` → `/usr/sbin`
  - `/lib*` → `/usr/lib*`
- **Important**: `/bin/foo` and `/usr/bin/foo` are the SAME file - don't compare them
- **Package queries**: Use `/usr/bin/*` paths (e.g., `dpkg -S /usr/bin/python3`)

### Symlink-heavy environment (and the Edit-tool gotcha)
Managing these machines means constantly touching symlinked paths.  The ones
that matter for this project's work:
- **The repo itself**: host-dependent.  On Haven/Avalir, `~/common` is a symlink
  to `/export/proj/common` (same tree, two names); on quin it is a real directory
  Syncthing writes to directly.  Don't hardcode it -- `aidoc/check-environment`
  reports the truth for whichever host you are on.
- **Host-local scripts**: `~/local/bin` is a symlink into
  `~/common/local/<host>/bin`, so editing e.g. `~/local/bin/termstart` or
  `~/local/bin/viv-mon` *is* editing the synced repo copy -- the edit deploys
  itself across machines (that is the point).
- **Claude config**: the `~/.claude/*` entries (`CLAUDE.md`, `settings.json`,
  `keybindings.json`, `skills/`, ...) are symlinks into
  `~/common/conf/ai/claude/`; edit the repo copy.  Detail and the new-artifact
  rule live in the `/x-claude-setup` skill.
- **System (UsrMerge)**: `/bin`, `/sbin`, `/lib*` (see the subsection above).

**The Edit/Write tool refuses to write through a symlinked *file*** (e.g.
`~/.claude/CLAUDE.md`), erroring with `Refusing to write through symlink: ...`.
When that happens, run `readlink -f <path>` and edit the resolved real target
-- which is the git-tracked repo copy you wanted anyway.  A symlinked *parent
directory* (like `~/common/...` or `~/local/...`) is fine; only a symlinked
target file trips the guard.

### Crontab management via makeln
**Never edit a user's crontab directly with `crontab -e` / `crontab -`** on
any home-network machine (Haven, Avalir, Caemlyn, Zadash, Graymoor) — the
crontab is regenerated from source on every interactive tcsh startup:

- `~/common/makeln` runs from `rc/tcshrc` on every interactive tcsh.
- It concatenates `~/common/conf/crontab/default.cron` (header / env vars)
  with `~/common/conf/crontab/<hostname>.cron` (per-machine lines) into a
  tmp file.
- If that differs from the live crontab, `crontab <tmpfile>` overwrites it.

So any change made directly to `crontab` will silently vanish at the next
shell start. **To add / remove / modify a cron line, edit the appropriate
`conf/crontab/<hostname>.cron` in `~/common`** and let makeln pick it up
(or run `~/common/makeln refresh` manually to apply immediately).

Same mechanism applies to **quin** (EC2 sandbox) via the ec2 branch of
makeln, reading `conf/crontab/quin.cron`.

**Exception — Zadash currently:** Zadash's `~/common` symlink points to
`/export/proj/common`, which depends on `/mnt/avalir/proj` being mounted.
The user mounts that manually after boot, so until they do, makeln fails
the `[[ -d $proj_dir ]]` check and never updates the crontab. Direct
`crontab` edits stick while in that state — but always *also* fix the
source file in `conf/crontab/`, since the mounts will be there next time.

### Launching Perl from cron / launchers / non-interactive contexts
Any Perl script invoked where the interactive shell environment is absent --
cron jobs, MATE/X keybindings, `.desktop` launchers, systemd units -- must run
through **`~/bin/launch-perl <script> [args]`**, NOT via its own shebang. A bare
`#!/usr/bin/env perl` picks up system Perl, which lacks the perlbrew/CPAN and
`myperl` modules and fails (often *silently*, since stderr is discarded in those
contexts). `launch-perl` locates perlbrew's Perl, sets `PATH`/`PERL5LIB`/
`local::lib`, and redirects stderr to `/tmp/launch-perl/<pid>.error`. This holds
on **quin** too -- its perlbrew env is reproduced there, so `launch-perl` finds
it. Canonical details: the "Launching Perl from constrained environments"
section of the repo `CLAUDE.md`. Concrete example in this project: the Haven
notification cron runs `launch-perl monitor-notifications avalir` rather than the
script's bare name.

## Key Documentation

### Core Network Documentation
- **[home-network-description.md](home-network-description.md)**: Complete technical description of the network infrastructure
  - Hardware components (Eero mesh WiFi, switches, modem)
  - Machine inventory (Haven, Avalir, Zadash, Caemlyn Linux systems)
  - Current and planned NAS systems (Synology Taaveren → QNAP Nakama)
  - Network services (Tailscale VPN, Syncthing file sync)
  - Security configuration and user management

### Project Planning
- **[qnap-upgrade-decisions.md](qnap-upgrade-decisions.md)**: Decision rationale and implementation plan for upgrading from Synology DS220j to QNAP TS-264-8G-US
  - Performance requirements and migration considerations
  - Service setup priorities (Syncthing, Backblaze B2 backup)
  - Security and future expansion planning

### NAS Sync + Backup Architecture
- **[nas-sync/](nas-sync/)**: Target end-state for the whole home data-sync +
  backup topology -- share tiers, the Syncthing mesh, Graymoor as version
  authority, Nakama, and the periodic push to Backblaze B2 -- plus the phased
  [roadmap](nas-sync/roadmap.md) to get there and a `nas-sync/bin/whats-next`
  probe that reports the next action on demand. Keeps its own README/TODO in
  the subdir to stay out of this file's multi-agent churn; **put new NAS-sync
  deferred work in `nas-sync/TODO.md`, not here.** Supersedes the old one-off
  `/export/personal/technical/nas-xfer/` workspace.

### Desktop Workflow
- **[desktop-switching-shortcuts.md](desktop-switching-shortcuts.md)**: Interlocking `Ctrl+Alt+Up` / `Ctrl+Alt+Down` MATE shortcuts that switch between paired desktops (Haven↔Avalir, Zadash↔Caemlyn) via NoMachine. Documents the `show-desktop` script, the `WORK`/`HOME` symbolic targets, and the full behavior matrix.

### Haven Crash Forensics

**If Haven just crashed, do these first:**

1. **keymap-mon**: the watcher died -- restart it per the instructions at the
   top of [keypad-colon-investigation.md](keypad-colon-investigation.md).
2. **viv-mon**: termstart auto-restarts it via pidfile check on every session
   start. Confirm it's running: `pgrep -a viv-mon`. The log is at `~/viv-mon.log`
   (NOT `~/local/log/`); previous log at `~/viv-mon.log.prev` (rotated at 50 MB).
3. **bulk-charge-mon**: also termstart-restarted via pidfile (dies on crash like
   the others). Confirm: `pgrep -a bulk-charge-mon`. Log at
   `~/local/log/bulk-charge-mon.log`. See the "bulk-charge-mon" tool entry below.
4. **RAPL + GPU cap**: applied by termstart on each boot. Current values:
   `cat /sys/class/drm/card1/gt_max_freq_mhz` (should be 400).
5. **Vivaldi stuck on its startup splash?** After an unclean shutdown Vivaldi can
   come up showing ONLY its faded logo splash ("Made with love in Europe") with
   no browser UI -- no tab bar, toolbar, or menu, and unresponsive to keystrokes.
   This is NOT a compositing/GPU problem (the splash paints fine) and NOT a lost
   session: it's Vivaldi's known post-crash hang -- its UI is itself a web
   document that stalls loading the crash-recovery state (`exit_type` reads
   `CrashedOnlyOnce`). Recovery (tabs stay safe throughout; verified 2026-06-10 on
   the vivaldi-media profile -- recovered on the first relaunch, full session
   restored, ~5 W pkg, no crash-risk spike):
   a. **Back up the session first** (it's the only copy of those tabs):
      `cp -p ~/.config/vivaldi-<profile>/Default/Sessions/* /var/tmp/viv-sess-bak/`
   b. **Graceful kill** -- SIGTERM, not SIGKILL: `pkill -TERM -f vivaldi-bin`. The
      graceful signal makes Vivaldi record a clean exit. Confirm `exit_type`
      flipped to `SessionEnded`/`Normal` (NOT `Crashed*`):
      `grep -o '"exit_type":"[^"]*"' ~/.config/vivaldi-<profile>/Default/Preferences`
   c. **Relaunch** via the profile's normal launcher. The clean-exit flag makes it
      take the normal restore path instead of the hung crash-recovery path.
   (Profile shown is `vivaldi-media`; the default profile is `~/.config/vivaldi`.
   See `summary:haven-jun10-video-crash.md` for the session it was first hit in.)

### Keyboard / Input
- **[keypad-colon-investigation.md](keypad-colon-investigation.md)**: OPEN investigation into the Shift+keypad-`.` = colon mapping on Haven. Establishes the physical key is **keycode 91** (NOT the long-assumed 129), explains the NumLock-dependent behavior, and documents the running `keymap-mon` watcher. **If Haven just crashed, the watcher died -- restart it** (instructions at the top of that doc).

### Sync Maintenance
- **[syncthing-troubleshooting.md](syncthing-troubleshooting.md)**: Symptom→fix guide for the Syncthing cluster (out-of-sync states, inotify-drop case studies, connectivity, `synudge` helper).
- **[quin-syncthing-downgrade.md](quin-syncthing-downgrade.md)**: Standalone agent-runnable brief for rolling quin back from Syncthing v2.1.0 to v1.30.0 and disabling auto-upgrade. Hand this to a quin-side session when it's time to realign the cluster.

### Machine Setup / Provisioning
- **`~/common/setup/`**: step-by-step instruction files (notes, not scripts) for
  provisioning fresh or restored machines — `home-dir.setup`, `laptop.setup`,
  `root-prep.setup`, `local-packages.setup`, etc.
- **`/var/install/`**: host-local stash (NOT Syncthing-synced — it's outside
  `/export` and `~`) of installers and artifacts referenced by those
  instructions: font archives (`Inconsolata.zip`, installed via `bin/addfont`),
  sideload APKs, one-off .debs. Artifacts needed on multiple machines are
  copied there manually (e.g. `Inconsolata.zip` lives on both Avalir and Haven).

### Disaster Recovery
- **[fire-evac-recovery.md](fire-evac-recovery.md)**: **READ THIS FIRST POST-DISASTER.** Step-by-step recovery from the Backblaze B2 backup. Covers where the keys live on Haven, how to reconfigure rclone, full bucket layout, restoration order, and re-keying afterward. The crypt passphrase and B2 application keys live in `/export/personal/Dropbox/sensitive/` (Syncthing-replicated to Haven).

## Private Data (Local Only)

The `private/` directory contains sensitive information that is excluded from version control:

- **[private/network-details.md](private/network-details.md)**: Actual IP addresses, Tailscale VPN IPs, specific firewall port configurations, hardware model numbers, and ISP details
- **[private/credentials.md](private/credentials.md)**: System usernames, UIDs/GIDs, administrator account names, and group memberships

## Historical Context (AI Session Summaries)

The following files contain summaries from previous AI collaboration sessions. These provide context for ongoing issues but should only be referenced when specifically relevant:

- `summary:ssh-remote-view-color-loss.md` - June 10 2026: Claude Code's submitted-prompt background tint (256-color index 237, a dark grey) renders crisply when a `screen` session is viewed locally but collapses into the background when the *same* session is reattached over `ssh` from another box: symmetric (local good / remote bad, in both directions), and visible even on an already-typed prompt, because it is purely a display-of-stored-cells difference, not anything Claude re-queries per view. Ruled out the OSC-11 / theme-detection and truecolor-quantization trails (the fill is a plain 256-*indexed* color, confirmed via `tmux capture-pane -e`). Root cause: `TERM` forced to colorless `vt100` on the ssh-attached display, by TWO synced layers: `rc/login`'s unconditional `set term=vt100` (fires on interactive login shells, not on local non-login kitty shells or `ssh host cmd`), and `bin/myterm`'s `faux_cmd="env TERM=vt100"` prepended before any `ssh`/`cessh` (forwarding `vt100` from the start, which is why fixing only `rc/login` left `termstart`-launched windows broken). Fix: gate the `rc/login` fallback to keep a real inherited `TERM`; make `myterm` pick `TERM` per emulator (`kitty`/`urxvt`/`gnome-terminal` get `xterm-256color`, Eterm/others keep `vt100`). Also corrects the now-falsified "faux_term ... actually an improvement" note in `summary:claude-code-terminal-corruption.md`.
- `summary:phone-music-playlist-sync.md` - May 27 2026: pushed `peaceful.m3u` (21 tracks) from Haven onto the Pixel 4a and got it playing as an ordered playlist in the phone's "Music Player" app (`mp3.music.download.player.music.search`). Documents the reusable song-push recipe (`adb push` to `/sdcard/Music/` + `content call scan_volume`), the app's playlist model (own private SQLite DB, no m3u import, ignores MediaStore playlists), the full set of ruled-out non-root DB-write avenues (root / `run-as` / `adb backup` all dead on Android 13, no exported provider), and the key finding: the playlist's track ORDER survived in the app's cloud-restored DB from the old phone, so selecting all songs and "Add to playlist" slotted them into the remembered order automatically. Limitation: that only works for playlists the old phone already knew — new ones need manual ordering or a different player (TODO captured).
- `summary:automox-deflect-and-crypt-vault.md` - May 20–22 2026: ops asked the user to run Automox endpoint-management on Avalir; pre-install analysis (root + osquery + cloud-pushed root scripts + lateral movement via Avalir's stored identity) led to MacOS-only scoping. Adjacent hygiene fix: plaintext personal credentials migrated from `Dropbox/sensitive/` (Syncthing-replicated) to age-encrypted vault at `/export/personal/crypt/` using identity-file pattern. Documents the architectural reasoning, the gotchas hit along the way (Avalir's GUI-only pinentry, libsecret per-symkey-id quirk, age 1.0's no-stdin-passphrase policy, prompt-cycle pain that drove the identity-file pivot), and the Avalir→work-only trajectory.
- `summary:haven-jun10-video-crash.md` - **[START HERE for Haven crash issues -- most recent]** June 10 2026: silent power-off at 14:53 PDT after ~6 days uptime, during video playback (vivaldi-media) over NoMachine on office-ac. **Three legs stacked**: (1) battery at 16% discharging when plugged in at 14:26 -> hard ~21W constant bulk-charge through the crash; (2) video-over-NoMachine sustained CPU+iGPU load, pkg peaked 27.86W (>PL2=27W); (3) flaky office-ac adapter couldn't supply ~48W combined. Sustained-load crash, NOT June 4's sub-ms GPU transient. **Corrects a first-pass error (user caught it):** vivaldi-guard worked -- vivaldi-media routes through it (panel launcher, --disable-gpu injected) and ran continuously for days (the "07:33 launch" was a viv-mon log rotation, not a restart). The GPU load isn't the browser (GPU disabled) but the display path --disable-gpu can't touch: marco compositing (on) + NoMachine nxnode capturing/encoding the framebuffer at realtime priority. Mitigations (best first): office-usb charging (avoids suspect adapter + lower bulk-charge wattage); don't drain to ~16% before plugging in; TLP GPU cap for AC durability; hardware fix (40%-health battery is leg #1). See TODO.md.
- `summary:haven-jun4-gpu-ramp-crash.md` - June 4 2026: silent power-off at 17:00:43 PDT after ~12d 13h uptime. User-confirmed trigger: exit + restart of ungoogled-chromium (a LIGHT profile -- one window, ~12 tabs) while setting up a video call. GPU frequency ramped from constant 300MHz to 1083/1100MHz at the restart moment (browser GPU-process init + camera-preview page reload); crash within ~1s. RAPL cap (PL1=20W / PL2=27W) was in place but did NOT prevent it -- measured pkg peaked at only ~24W, within the limit; the killer is the sub-millisecond inrush transient of the GPU idle→max ramp, which RAPL's averaging windows can't see. Key implication: workload size is irrelevant; ANY GPU wake-from-idle ramp now exceeds the degraded power-delivery margin (Vivaldi is immune only because it runs `--disable-gpu`; UC has no guard). Timeshift exonerated for THIS crash (its 17:00 fire was a 200ms no-op; the heavy daily snapshot ran at 14:00 and survived fine) -- but the side investigation SOLVED the May 17 cron-revert mystery (timeshift itself rewrites `timeshift-hourly`/`timeshift-boot` to match its settings on every run; mtime 14:00:02 = the 14:00 check) and surfaced that boot snapshots fire 10 min after every boot (hazard window). Second major finding: keymap revert mechanism #2 IDENTIFIED -- every ECOXGEAR Bluetooth speaker connect makes X add an AVRCP "keyboard" and recompile the keymap (pc105/us Xorg-log signature; historical hits all land on weekends, matching the Saturday speaker habit) -- giving the keypad investigation an on-demand reproducer. Recommended mitigation: GPU frequency cap in termstart (`gt_max_freq_mhz` AND `gt_boost_freq_mhz` to 400). See `summary:haven-jun4-gpu-ramp-crash.md`.
- `summary:haven-may22-double-crash.md` - May 22 2026: **two silent power-offs in 15 minutes**. Crash #1 at 17:07:23 PDT after a 3 d 19 h uptime, during browser-over-NoMachine activity, with three `AC:`-tagged udev firings landing in the crash second (rapid AC-online bounce). Crash #2 at 17:21:58 PDT — only 34 seconds into the recovery boot, killed by termstart's own self-launching processes pushing CPU pkg power past ~38 W. Both deaths at the same pkg threshold (sustained ~30 W, peak ~38 W); no thermal, GPU, or IO component. Surfaced two new signals: (a) Haven has been logging ~18 spurious AC-online transitions per day for a week (vs. user's actual ~6/day plug-cycle), pointing at flaky AC adapter/cable/jack; (b) the crash threshold has dropped low enough that a routine boot's own activity can cross it. Three mitigations applied: termstart de-burst (sleeps between parallel launches), RAPL package-power cap (PL1=20W / PL2=27W on intel-rapl:0, written from termstart), and new `ac-mode` tool (`common/bin/ac-mode`) for localizing the AC anomaly across charging methods (office-ac / office-usb / office-both / den-ac). Initial den-ac data point: zero AC events in first 10 minutes (vs. 0.75/hr office-ac baseline) — too small to conclude but qualitatively favors office-side flakiness. Hardware intervention (battery + repaste + cap inspection) still pending; RAPL cap is the bandage until then.
- `summary:haven-may17-timeshift-snapshot-crash.md` - May 17 2026 (with May 23 follow-up section appended): silent power-off at 05:00:33 PDT after ~3.5-day uptime, overnight unattended, plugged in, no NoMachine. First crash investigation in the May series where the post-May-13 viv-mon instrumentation and journalctl together identify a specific proximate trigger: the daily Timeshift snapshot fired by the hourly `--check` cron at 05:00:01. viv-mon data cleanly rules out thermal (peak 61°C), GPU (rc6 rose through failure, gfreq returned to 300MHz after a one-sample blip), and user activity (tp=off, load=0.25 right up to the trigger). 02:00/03:00/04:00 lightweight `--check` fires all survived with ~1-second bursts; 05:00 was the daily-snapshot fire (heavier rsync). Existing exclusions already cover `/home/buddy/**`, `/root/**`, and `/export/**` (separate filesystem). Two live-config mitigations attempted (cron `nice/ionice` wrapper + JSON exclusion rework to bring `~/` into snapshots) **both failed silently** — the cron edit was reverted by an unknown actor 12 minutes later, and the exclusion rework had zero practical effect because Timeshift's RSYNC mode has hardcoded `/home/*` defaults that override the user `exclude` array. Both findings documented in the May 23 follow-up section; the crash analysis itself still stands. Neither failure has bitten us because the May 22 RAPL cap covers the original crash risk independently. Bigger lever still pending: hardware intervention.
- `summary:haven-may13-vivmon-fix-and-nomachine-profile.md` - May 13 2026: another silent power-off, this time during a workspace switch onto a fullscreen video with NoMachine active. Three takeaways. (a) `viv-mon`'s `pkg=` and `gpu=` columns have been silently zero for the entire May 11→13 window — RAPL energy counters are root-only by default (PLATYPUS / CVE‑2020‑8694) and `rd()` swallowed the failure. Fixed: termstart now `chmod a+r`s them at boot; `viv-mon` rewritten to pick RAPL subdomains by name, add `gfreq=cur/act` and `rc6=Δms` columns from `/sys/class/drm/card1/`, add `tp=on/off` touchpad-state column and a periodic `BROWSERS` snapshot line listing distinct browser profiles, and rename the misleading `gpu=` field to `unc=`. (b) Captured the user's full NoMachine usage profile (servers, fullscreen-only, sound-on-Avalir, both clipboard modes; the per-host switching hotkeys are MATE+`show-desktop`, NOT a NoMachine feature) and assessed `xpra shadow` as a possible replacement — covers the functional surface, but the assessment ends with a **defer recommendation**: the crash data doesn't actually point at NoMachine, crashes happen without it, real root cause is hardware, switching cost is non-trivial. Revisit only if the next crash's new viv-mon data shows GPU climbing + RC6 collapsing in the final seconds. (c) Mystery: intermittent ~1-sec truncated audio clip the user has been chasing for weeks; logged for future correlation.
- `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md` - May 11 2026: another silent power-off after 3-day uptime (longest since May 8); the May 8 limp-along config is working but had to be made *persistent and idempotent* via `termstart`; forensic monitor relocated from lost `/tmp/viv-mon2.sh` to `~/local/bin/viv-mon` with log rotation; `bin/vivaldi-guard` now injects `--disable-gpu` on Haven; touchpad applet got `off`/`on` startup modes; new variable to watch is the NoMachine 8→9 upgrade on May 9
- `summary:vivaldi-7.9-upgrade-and-haven-instability.md` - May 2026: Vivaldi 6.1→7.9 upgrade + Haven crashes now triggered by routine load (not just GPU bursts); MV2 extension recovery; CSS-modding migrated to chrome://flags + Custom UI Modifications folder
- `summary:haven-kernel-upgrade-and-gpu-fix.md` - Kernel upgrade that resolved the i915 driver bugs causing Haven crashes (February 2026)
- `summary:haven-fstab-uuid-and-vivaldi-guard.md` - April 2026 follow-up: NVMe enumeration flip broke `/export` mount (fixed with UUID in fstab); Vivaldi + NoMachine combo still crashes Haven post-kernel-fix (guarded by `~/common/bin/vivaldi-guard` wrapper)
- `summary:ec2-syncthing.html` - Syncthing configuration for EC2 servers
- `summary:haven-crash-diagnosis-summary.md` - *(Superseded)* Earlier diagnosis of Haven system crashes
- `summary:haven-thermal-diagnosis-and-resolution.md` - *(Partially superseded)* Haven thermal issue resolution
- `summary:intermittent-shutdowns-diagnosis.md` - *(Historical)* Analysis of system shutdown problems
- `summary:intermittent-shutdowns.html` - *(Historical)* HTML version of shutdown diagnostics

## EC2 Sandbox ("Quin") Connection Details

**⚠️ IMPORTANT FOR AI AGENTS**: Read this section whenever the user mentions their "quin", "quin terminal", or EC2 sandbox — including connectivity issues, terminal lockups, or debugging remote sessions.

### How the User Connects to the Quin

The quin is an **EC2 instance** (not a local Vagrant VM — do not confuse with the local Vagrant sandbox on 127.0.0.1:2222). Connection details:

- **Platform**: Ubuntu 22.04 LTS (jammy), x86_64, glibc 2.35 — every quin is
  built from this image, and will be until the host class upgrades past jammy
  (a long way off as of June 2026). Safe to assume when picking prebuilt
  binaries / release assets. Provisioning lives in
  `$CHEOPSROOT/launch-ec2/control-instance/build` (work repo).
- **Script**: `local/avalir/bin/term-quin` launches the terminal window
- **Method**: SSH over **Tailscale VPN on port 8822** (not port 22)
- **Username**: `$CE_REMOTE_USERNAME` (currently `bburden`) — NOT `vagrant`, NOT `buddy`
- **Tailscale hostname**: Check `tailscale status` output for `quin-*` entry
- **Connection log**: `/tmp/term-quin.log` (verbose SSH debug output, check tail for recent events)
- **Session multiplexing**: GNU Screen runs inside the SSH session with many windows (tcsh shells)
- **Keepalive**: `ServerAliveInterval=60`, `ServerAliveCountMax=3`

To SSH to the quin from Avalir:
```bash
ssh -p 8822 bburden@<tailscale-hostname-or-ip>
```

### Known Connectivity Issues

- The Tailscale connection may go through a **DERP relay** (check `tailscale status` for "relay" in the output). Relay connections can cause intermittent freezes/lockups.
- Previous incidents show `tcsetattr: Input/output error` in the connection log when the connection path degrades.
- **Recurring "wedge" failure mode**: the SSH session can lock up entirely (no Ctrl-C, no Ctrl-A, no keystroke gets through) while TCP keepalives continue to round-trip normally — `ServerAliveInterval`/`CountMax` won't catch it because the keepalives *are* succeeding. Diagnostic signature: `ss -tnpi` shows `lastsnd`/`lastrcv` cycling at the keepalive interval, ssh sleeping in `do_poll`, `/tmp/term-quin.log` (the `-v` output) silent for hours. Suspected cause: WireGuard/Tailscale state desync that black-holes data-channel traffic but lets SSH-level keepalive control messages through. Tightening keepalive timing **does not** fix this; the keepalives are working.

### Agent Forwarding Constraints (CRITICAL for any reconnect-based fix)

The user's quin workflow has hard constraints around SSH agent forwarding that rule out several "obvious" solutions. Any AI agent proposing transport-level fixes must respect these:

- **Agent forwarding is non-negotiable.** The user uses a forwarded ssh-agent on quin for (a) GitHub access via `git`/`gh` and (b) SSH'ing from quin to other work machines. Removing agent forwarding stops development cold.
- **Keys cannot live on quin.** Don't suggest "just put the keys on the EC2 instance and run a local agent there" as a general solution. Treat it as off-limits unless the user explicitly raises it.
- **20–30 screen windows hold cached `SSH_AUTH_SOCK` values.** Each tcsh shell inside the remote screen session captured the agent socket path at the moment the SSH session was first established. A naïve reconnect with `ssh -A` allocates a *new* socket path, instantly invalidating every cached value. Schemes like plain `autossh` are non-starters in that form.
- **Solutions must use a stable agent socket path.** The right pattern is `RemoteForward /home/bburden/.ssh/agent.sock $SSH_AUTH_SOCK` on the client + `StreamLocalBindUnlink yes` in sshd + `setenv SSH_AUTH_SOCK /home/bburden/.ssh/agent.sock` in `~/.tcshrc`. Reconnects re-bind the same path, existing shells continue to work.
- **`mosh` does not forward ssh-agent.** Plain mosh is therefore a non-starter. Mosh-based solutions need a separate, dedicated ssh side-channel (with the stable socket-path setup above) whose only job is agent forwarding.

### Companion Failure: Screen IPC Wedge ("`sr` hangs on reattach")

The user has a *separate* recurring quin issue that often shows up at the same time as the SSH wedge: after relaunching `term-quin`, the `sr` alias (`screen -x`) hangs. The user's standard fix is `screen-cleanup`, then `sr` works.

What's actually going on (verified, not speculation):

- A long-running screen master on quin (uptime measured in *months* — last seen at 226 days) is the parent SCREEN session. There is **only ever one** screen session; the user's 20–30 "windows" are all inside it.
- Cron has `10 * * * * $HOME/bin/launch-perl screen-bufsave -Aq` — an hourly buffer save that calls `screen-windowlist`, which calls `screen -X msgwait 0` and `screen -p N -Q title` for windows 0..50.
- When something wedges screen's IPC (the master ends up blocked in `unix_stream_data_wait` reading a partial request from a previous client), every subsequent `screen -X` / `screen -Q` hangs forever. The hourly cron then **stacks one new zombie per hour** indefinitely.
- New `screen -x` attaches block in `unix_wait_for_peer` — they're trying to connect to a master whose accept loop isn't running.
- `screen-cleanup` (`~/common/bin/screen-cleanup`) `kill TERM`s all the zombie `screen-windowlist` / `screen-bufsave` / `msgwait` / `screen ... -Q` processes; the master then drains its queue and starts accepting again.

Diagnostic shortcut: `ps -eo pid,stat,etime,cmd | grep -E 'screen -X msgwait|screen -p .*-Q'` — if you see a clean arithmetic progression of `etime` values one hour apart, you're looking at this.

The `screen-bufsave` script already has a `-C` flag that runs `screen-cleanup` when ≥20 stale screen procs exist. **The cron line does not pass it** — that's the easy fix. A second cron entry running `screen-cleanup` unconditionally on a tighter cadence is even more robust.

**Identified trigger (Apr 2026):** the screen IPC wedge correlates strongly with `claude` usage because the user's `claude` wrapper at `bin/claude` runs `screen -X msgwait 0`, `screen -Q info`, `screen -X msgwait 3` on every invocation (to capture terminal size). Under load, that `screen -Q info` occasionally leaves the screen master stuck in `recvmsg()` on the client connection, which deadlocks IPC for everything downstream (including the hourly `screen-bufsave` cron). This explains the Avalir+quin (heavy claude usage) vs Haven (rare claude usage) asymmetry.

**Mitigation:** wrap the IPC call with `timeout 2 screen -Q info` so a wedged query self-clears (kill closes the socket → master gets EOF → master proceeds). Better long-term: replace with `tput cols` / `tput lines` / `$COLUMNS` / `stty size` and stop using screen IPC for terminal sizing.

Possible (but unproven) link to the SSH wedge: a stuck `claude` output stream inside screen could fill the per-window buffer, blocking screen's main select loop, which then doesn't service IPC; meanwhile the same backpressure could contribute to the SSH data-channel collapse. Treat this as a hypothesis, not established fact. What *is* established: both wedges are aggravated by very-long-uptime sessions accumulating exotic state.

### Possible Causes Worth Investigating Before Transport-Level Fixes

The wedge correlates with `claude` activity, but the actual mechanism appears to be **heavy ssh-agent-forwarding traffic** — the connection log routinely shows thousands of `auth-agent@openssh.com` channel opens (~1 per 100 seconds, sustained for days). That polling pattern is suspicious; it suggests *something* on quin is hammering the agent unnecessarily. Candidates to investigate before papering over the symptom:

- A tmux/screen status bar or shell prompt running `git` on every refresh
- A backgrounded watcher / language server / IDE plugin doing periodic git operations
- An MCP server (configured via project-scoped `.mcp.json`) polling git or gh
- A cron job using forwarded keys

Diagnostic approach (when the session is healthy): `lsof -U +c0 | grep "$SSH_AUTH_SOCK"` sampled a few times, or interpose a logging `socat` in front of the agent socket and watch what connects.

## EC2 Sandbox Sync Integration

**⚠️ IMPORTANT FOR AI AGENTS**: Only read this section if the user specifically mentions EC2 sandboxes, syncing with EC2, or working with "quin" instances. Otherwise, skip this section.

### Overview
EC2 sandboxes ("quin" instances) can be configured for bidirectional file sync with Avalir (desktop) using Tailscale VPN and Syncthing. This allows seamless development with automatic sync of `~/common`, `~/work`, and `~/CE` directories.

### Key Documentation Files (When Working on EC2 Sync)
- **[EC2-sync-proof-of-concept.md](EC2-sync-proof-of-concept.md)**: Complete test results and current setup
- **[EC2-sync-automation-roadmap.md](EC2-sync-automation-roadmap.md)**: Detailed automation implementation guide
- **[syncthing-troubleshooting.md](syncthing-troubleshooting.md)**: Troubleshooting guide for Syncthing sync issues
- **[ec2-sync-bootstrap.sh](ec2-sync-bootstrap.sh)**: Bootstrap script for new EC2 instances
- **[/export/proj/common/bin/sandbox-setup](/export/proj/common/bin/sandbox-setup)**: Local script to setup tunnels

### Private Files (When Needed)
- **[private/ec2-sync-credentials.md](private/ec2-sync-credentials.md)**: Current EC2 instance ID, Tailscale auth key, device IDs

### Quick Start for AI Agents
If user asks about EC2 sandbox sync:
1. Read `EC2-sync-proof-of-concept.md` for current state
2. Check `private/ec2-sync-credentials.md` for instance ID
3. Run `sandbox-setup <instance-id>` to establish connections
4. Access Syncthing UI at http://localhost:8388
5. If sync issues occur, consult `syncthing-troubleshooting.md` for diagnosis and solutions
6. For Claude Code: MCP servers are configured via project-scoped `.mcp.json` files
   - After initial sync, restart Claude Code to load the configuration
   - Authenticate with `/mcp` command if using OAuth services

## Current Status

- **Avalir xdg-desktop-portal 7 GB swap blowup traced to a marco respawn loop
  (2026-06-23):** A low-memory episode showed `xdg-desktop-portal` (PID 3867,
  ~200-day uptime) holding **~7 GB of swap** -- a process the user had never seen
  on `topswap` in ~7 years. Root cause was NOT the portal (binary unchanged since
  2022): a **marco respawn loop firing ~18x/sec** flooded the session D-Bus with
  connect/disconnect churn (`NameOwnerChanged`), and the portal -- which tracks
  every client connection -- leaked a sliver per event, compounding to ~7 GB. The
  loop: the "Reset Window Manager" panel launcher ran a bare `marco --replace`,
  creating an unmanaged WM that fights mate-session's managed WM slot; each
  mate-session relaunch exits *cleanly* ("already has a window manager"), so the
  crash-throttle never trips and it loops. Dormant for months, it ignited
  ~2026-05-29 after a marco crash (coredump in `meta_display_set_cursor_theme`).
  Collateral: `~/.xsession-errors` had grown to **15.4 GB** (~567 MB/day). Fixes:
  restarted the portal (reclaimed ~7 GB swap); `pkill -x marco` to break the loop
  (the SIGTERM trips mate-session's throttle so it backs off -- note mate-session
  does NOT auto-respawn marco, which is why the manual launcher exists at all);
  truncated the 15.4 GB log (~15 GB disk back). Durable fix: new **`fix-wm`**
  (`root/sbin/fix-wm` -> `/usr/local/sbin/fix-wm`) does signal-kill-then-replace
  so it never hands mate-session a clean exit to chase; the panel launcher and
  `bin/dtop-gaming` both repointed at it. See
  `summary:avalir-marco-respawn-loop.md`.
- **Avalir trackball lag diagnosed to the 2.4GHz link (June 10-17 2026):**
  The MX Ergo trackball intermittently freezes then jumps "halfway across the
  screen." It is a Logitech **Unifying** (2.4GHz proprietary radio) device, NOT
  Bluetooth despite the "USB receiver" framing. Confirmed the fault is on the
  wireless link the receiver hides from the OS: during live episodes solaar
  read the device `offline` while actively in use, the kernel logged zero
  USB/HID events across 186 days uptime, the receiver never autosuspended, and
  battery is healthy (90%). Buffered-then-flushed motion = the jump. **Monitor
  PROVEN: `~/oneoff/trackball-mon` caught its first full episode 2026-06-17**
  (15:24-~15:29, signature reconfirmed). That episode cleared two suspects:
  **Bluetooth** (lag recurred with BT soft-blocked -> exonerated, BT re-enabled
  2026-06-17) and **Avalir's own WiFi** (radio off). A `powertop --auto-tune`
  udev storm seen during episodes is a symptom (a 2023 Juno rule firing on the
  trackball's `hidpp_battery_0` power_supply device), not a cause. Root cause
  still open and now narrowed: the user confirms NOTHING changed on Avalir's
  side ~Jun 9-10 and the Haven-trackball arrangement is long-standing, so the
  trigger is likely external RF or intermittent link-hardware degradation. Test
  in progress (2026-06-17): Haven's trackball powered off at its base switch for
  a day. See `summary:avalir-trackball-lag.md` and TODO.md.
- **Haven crashed again (June 10 2026):** Silent power-off at 14:53 PDT after
  ~6 days uptime, during video playback (vivaldi-media) over NoMachine on
  office-ac. **Three legs stacked** (remove any one and it likely doesn't crash):
  (1) battery was at **16% discharging** when plugged in at 14:26, triggering a
  hard ~21W constant bulk-charge that ran through the crash; (2) video-over-
  NoMachine sustained CPU+iGPU load (pkg peaked 27.86W >PL2); (3) the known-flaky
  office-ac adapter couldn't supply the ~48W combined draw. Sustained-load crash,
  NOT the June-4 sub-ms GPU transient. **Key correction (user caught my first-pass
  error):** vivaldi-guard worked correctly -- vivaldi-media DOES route through it
  (panel launcher, with --disable-gpu injected) and ran continuously for days (no
  restart; the "07:33 launch" was a viv-mon log rotation). The GPU load is NOT the
  browser (its GPU was disabled) but the display path --disable-gpu can't touch:
  **marco compositing (on) + NoMachine nxnode capturing/encoding the framebuffer
  at realtime priority**, recompositing the video region every frame. Mitigations
  (best leverage first): switch office charging to **office-usb** (avoids suspect
  adapter, lower bulk-charge wattage); don't run battery to ~16% before plugging
  in; TLP GPU freq cap for AC-event durability; hardware fix (battery is leg #1)
  remains the real lever. See `summary:haven-jun10-video-crash.md`.
- **Haven crashed (June 4 2026):** Silent power-off at 17:00:43 PDT after
  ~12d 13h uptime. GPU ramp (300→1083MHz) triggered by ungoogled-chromium restart
  during video call setup -- a light profile; workload size is irrelevant, any
  GPU wake-from-idle ramp now crashes the box. RAPL cap was in place but can't
  catch it: pkg peaked at only ~24W (within PL2); the killer is the sub-ms GPU
  inrush transient. Mitigation: GPU frequency cap (`gt_max_freq_mhz` +
  `gt_boost_freq_mhz` = 400) in termstart -- VERIFIED holding 2026-06-09, ~5
  days up with no crash; kept at 400 (no sluggishness reported). NOTE after June 10
  crash: gfreq=600/600 readings during ACTIVE GPU work are real, not just RC6
  artifacts -- the 600/0 RC6-idle readings are still artifacts but active-decode
  600/600 readings require attention. Side findings: May 17 cron-revert mystery
  solved (timeshift rewrites its own cron files); keymap mechanism #2 = ECOXGEAR
  Bluetooth connects (on-demand reproducer now available). Hardware intervention
  (battery + repaste + cap inspection) remains the real fix -- 2026-08-03 re-check.
  See `summary:haven-jun4-gpu-ramp-crash.md`.
- **`show-desktop` duplicate-session heisenbug diagnosed + fixed** (May 28 2026):
  The intermittent bug where `Ctrl+Alt+Up/Down` would *sometimes* launch a new
  NoMachine session instead of focusing the existing one (no discernible pattern;
  "3 times in a row then fine then again") was root-caused to `xdotool search
  --name` aborting on a **fatal `BadWindow` X error**. `xdotool search` walks the
  whole X window tree; if any transient window is destroyed mid-walk, it exits
  with empty output, which `show-desktop` misread as "no existing session" →
  duplicate launch. Reproduced live at ~50% failure; `wmctrl -l` found the same
  window 10/10. Fixed by switching existing-session detection from `xdotool
  search` to the `wmctrl -l` list the script already fetches (reads
  `_NET_CLIENT_LIST`, no tree walk, race-immune). The temporary decision-logging
  instrumentation (`dbg()` to `~/local/log/show-desktop.log`, host-local) confirmed
  the fix (405 invocations over 3 weeks, zero spurious `NO MATCH`) and was REMOVED
  2026-06-18 alongside the sibling `pidgin_restore` fix for the same race; the
  `wmctrl` detection stays. NOT the same as the
  May 11 NoMachine-9.x title-order fix (`c49dbed`), which addressed an *every-time*
  failure. See `desktop-switching-shortcuts.md`.
- **Phone music + ordered playlist sync working** (May 27 2026): Established a
  reusable workflow for pushing music to the Pixel 4a's "Music Player" app
  (`mp3.music.download.player.music.search`) over `adb`: `adb push` into
  `/sdcard/Music/<sub>/` then `content call ... scan_volume` to index (titles from
  ID3 tags). Replicated `/export/music/tracklists/gaming/peaceful.m3u` (21 tracks)
  as an in-app playlist. The app keeps playlists in a root-only private DB (no m3u
  import, ignores MediaStore playlists); all non-root DB-write paths are dead on
  Android 13 (`run-as` not debuggable, `adb backup` returns an empty archive, no
  exported provider). It worked anyway because the playlist's track ORDER had been
  cloud-restored into the app's DB from the old phone — "select all → add to
  playlist" landed the songs in the remembered order. New playlists (not on the old
  phone) still need a workaround. See `summary:phone-music-playlist-sync.md` + TODO.
- **Keypad-colon mapping investigation** (May 26 2026; stopgap PROVEN, durable fix
  DEFERRED 2026-06-09): Haven's Shift+keypad-`.` = colon mapping intermittently
  reverts to default. Root keycode confirmed as **91** (`<KPDL>`, standard) — *not*
  the long-assumed 129 that derailed earlier work. Mechanism #2 is identified (every
  ECOXGEAR Bluetooth connect recompiles the keymap); the silent mechanism #1 is still
  unknown. The `keymap-mon` self-heal stopgap (auto-reapplies `xmodmap` on a detected
  wipe) **caught and fixed a real wipe on 2026-06-06 in ~1s**, so the durable
  TWO_LEVEL/XKB fix is deferred until the wipe recurs *despite* the stopgap or NumLock
  fragility starts biting. **If Haven just crashed, the watcher died — restart it**
  (see [keypad-colon-investigation.md](keypad-colon-investigation.md)). Boot-time
  loading is already handled by `termstart-common` (commit `75cea2a`).
- **Avalir Vivaldi 6.1 → 7.9 upgrade complete** (May 26 2026): Mirrored Haven's
  upgrade — `vivaldi-stable` 6.1.3035.302 → **7.9.3970.67**, `apt-mark hold`ed to
  avoid drifting to the new **8.0** "Unified" redesign (deferred; revisit via a
  throwaway profile/`vivaldi-snapshot`). Vivaldi Sync had already carried Haven's
  theme + tab position + the CSS-mods folder pointer, but **not** the per-device
  `chrome://flags/#vivaldi-css-mods` enable flag (flipped manually; CSS was
  effectively already loading via the in-place upgrade's pre-7.7 carryover).
  Caught & fixed a latent bug affecting **both** machines: a stale `custom.css`
  rule painted the bookmark bar dark (`--colorBg`) under "color behind tabs" —
  now unified with the purple chrome (Haven gets it on next restart). No hardware
  mitigations needed (desktop). Tabs Backup & Restore here is intact-but-disabled
  (not pruned like Haven). Pre-upgrade profile snapshot was kept at
  `~/.config/vivaldi.bak.pre-7.9` (4.1 GB); **relocated 2026-06-03** into the
  synced backup share at `/export/backup/snapshots/config/avalir-pre-7.9-20260526/vivaldi/`
  (Haven's own pre-7.9 snapshot likewise moved to `.../config/haven-pre-7.9-20260508/vivaldi/`).
  See `summary:vivaldi-7.9-upgrade-and-haven-instability.md` ("Avalir
  Upgrade — Outcome" and "Post-Upgrade Tab-Stacking Behavior Changes").
- **Phone replaced; SwiftKey downgraded** (May 25 2026): New Pixel 4a (same model — `sunfish`) replaces previous unit. Tailscale node renamed `google-pixel-4a` → `pixel-4a`, IP `100.98.252.81` → `100.76.67.17`. Old node still in admin console pending manual removal (see TODO). USB debugging authorized for Haven, so `adb` workflows are available going forward. SwiftKey downgraded from Microsoft-era 9.12.29.12 to pre-acquisition **7.0.0.15** via adb sideload (APK at `/var/install/`); installer registered as `null` to block Play Store auto-update. Note: Pixel 4a is past Google's EOL (final firmware `TQ3A.230805.001.S2`, security patch 2023-08-05) — no further OS updates available. Full reinstall procedure in `private/network-details.md`.
- **Automox-on-Linux push deflected; personal credentials vault established** (May 20–22 2026): Ops asked the user to run an Automox endpoint-management installer on Avalir. Analysis (artifacts at `/var/install/`) showed the agent runs as root with zero systemd sandboxing, bundles Meta's `osqueryi` for full-OS introspection, executes cloud-pushed "DCU" remediation scripts as root, and (crucially) gains lateral-movement capability via Avalir's stored personal SSH/GPG keys and Tailscale tailnet membership. After conversation, ops scoped the install to MacOS-only and excluded Linux boxes. Independent of the install decision, plaintext personal credentials in `/export/personal/Dropbox/sensitive/` (Syncthing-replicated for years) were migrated into an age-encrypted vault at `/export/personal/crypt/` using the identity-file pattern (single prompt per session for decrypt; re-encrypt is non-interactive via recipient pubkey). Original `Dropbox/sensitive/` plaintext tree wiped after diff verification; Syncthing propagated the deletion across personal nodes. Avalir is on a trajectory to **work-only**; Haven becoming personal-primary. Remaining: B2 cloud leg for `crypt/` (separate bucket + key to avoid circular dependency), credential rotation, migrate personal SSH/GPG identity off Avalir. See `summary:automox-deflect-and-crypt-vault.md`.
- **Fire-evac cloud backup complete** (May 19–23 2026): During a shelter-in-place fire warning, triggered a comprehensive B2 backup of all at-risk machines; all queues drained by May 23. Avalir (~450 GB), Nakama (~650 GB incl. /share/archive), Zadash (.stversions ~200 GB + camera-bak ~56 GB). New bucket `barefoot-encrypted` holds rclone-crypt credentials. B2 keys + crypt passphrase in `/export/personal/Dropbox/sensitive/` (Syncthing-replicated to Haven). Recovery procedure: [fire-evac-recovery.md](fire-evac-recovery.md). Nightly `~/.purple` snapshot to `nakama:/share/incrementals/avalir/purple/YYYY-MM-DD/` configured (cron in `conf/crontab/avalir.cron`, script `bin/purple-snapshot`). Remaining: Nakama→B2 nightly rclone cron, `~/.config/` cleanup, remaining survey gaps — see TODO.
- **NAS Migration Complete**: QNAP Nakama (TS-364) deployed and operational (August 2025)
  - Single 4TB disk configuration with snapshot support
  - SSH/rsync access configured with key-based authentication
  - Backup directories created at `/share/backup`, `/share/archive`, `/share/personal`, `/share/proj`, `/share/work`
  - Daily IHM (IronWolf Health Management) scans running at 03:29 AM
- **EC2 Sandbox Sync**: Operational with Tailscale + Syncthing (September 2025)
  - Proof-of-concept complete, semi-automated setup available
  - See EC2 Sandbox Sync Integration section if working on this
- **Haven GPU/Crash Issues Resolved** (February 2026): Kernel upgrade from 6.1-oem to 6.8-generic fixed the i915 GPU driver bugs causing crashes. Haven now runs modesetting + iris + glamor with proper hardware acceleration. See `summary:haven-kernel-upgrade-and-gpu-fix.md` for details.
- **Haven NoMachine + Vivaldi Combo Still Crashes** (April 2026): Kernel fix raised the crash threshold but didn't eliminate it — running Vivaldi's heavy GPU load while NoMachine streams the display is still beyond this hardware's margin. Mitigated by `~/common/bin/vivaldi-guard` wrapper on Haven's Vivaldi panel launchers, which refuses to launch Vivaldi when a NoMachine session is active. Same session fixed an unrelated `/export` mount failure caused by NVMe probe-order flip vs. hardcoded device paths in fstab. See `summary:haven-fstab-uuid-and-vivaldi-guard.md`.
- **Haven Crashes Now on Routine Load** (May 2026): Crash threshold has dropped further — Vivaldi 7.9 launches and even bare `termstart` now trigger silent power-offs without GPU bursts or NoMachine. Pattern points to mainboard component aging (VRMs/decoupling caps). Hardware intervention (battery replacement + CPU/GPU repaste + visual cap inspection) pending. Limp-along: Vivaldi must launch from terminal with `--disable-gpu`; Docker/Insync disabled; CPU governor on powersave; suspend rather than reboot. Same session: Vivaldi 6.1→7.9 upgrade succeeded; CSS modding migrated from `/opt/vivaldi/`-patch style to the official `chrome://flags/#vivaldi-css-mods` + Custom UI Modifications folder approach pointing at `~/common/vivaldi-patch/`. See `summary:vivaldi-7.9-upgrade-and-haven-instability.md`.
- **Haven Limp-Along Made Persistent** (May 11 2026): Another silent power-off after a 3-day uptime — the longest since May 8, confirming the limp-along config works. Made persistent and idempotent: forensic monitor relocated from lost `/tmp/viv-mon2.sh` to `~/local/bin/viv-mon` with 50 MB log rotation; `termstart` now sets the powersave governor and auto-starts the monitor (gated by pidfile); the touchpad applet got `off`/`on` startup modes and `termstart` passes `off`; `bin/vivaldi-guard` now injects `--disable-gpu` automatically on Haven. Only new software variable since May 8: NoMachine self-updated `8.22.1→9.5.7` on May 9 — flagged for watch, not yet downgrading. See `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md`.
- **Haven Crash Triggered by Daily Timeshift Snapshot** (May 17 2026; May 23 follow-up: both live-config mitigations failed silently): Silent power-off at 05:00:33 PDT after a 3.5-day uptime. First crash in the May series where post-May-13 viv-mon data + journalctl together identify a *specific* proximate cause: the daily Timeshift snapshot creation fired by the hourly `--check` cron at 05:00:01. Crash signature cleanly rules out thermal (peak tz4 = 61°C), GPU (rc6 *rose* through failure, gfreq returned to 300MHz after a one-sample blip), and user activity (tp=off, load=0.25 just before the trigger). viv-mon's own poll cadence stretched from 264ms to 2.9s over the final 30 seconds — CPU/IO starvation, not thermal. The 02:00/03:00/04:00 lightweight `--check` fires all produced ~1-second bursts and recovered cleanly; 05:00 was where the daily-snapshot logic actually creates a new rsync copy. **Crash analysis still stands. Both live-config mitigations did not.** (a) The `ionice -c3 nice -n 19` wrapper added to `/etc/cron.d/timeshift-hourly` at 13:48 PDT on May 17 was reverted by an unknown actor 12 minutes later (file mtime is 14:00 PDT, byte-identical to the pre-edit backup; user confirms no manual revert; apt-history shows no timeshift package action). (b) The `/etc/timeshift/timeshift.json` exclusion rework that removed `/home/buddy/**` and added 26 targeted excludes is still in place but had **zero effect on snapshot contents** — Timeshift's RSYNC mode has hardcoded `/home/*` and `/root/*` excludes that override the user-supplied list. May 23 audit confirmed the latest snapshot's `/home/buddy/` is an empty directory and total snapshot size is unchanged at ~30 G. The `~/local/` + `~/.claude/` backup gap I claimed had been closed is still open. Neither failure has bitten us because the May 22 RAPL cap (PL1=20W, PL2=27W) covers the original crash risk independently. See `summary:haven-may17-timeshift-snapshot-crash.md` (now includes a "May 23 Follow-Up" section documenting these findings) and project `TODO.md` (three new entries for cron-revert investigation, `~/` inclusion path decision, and dead-exclusion cleanup). Hardware intervention (battery + repaste + cap inspection) remains the pending big lever.
- **Haven Suspend Drain + s2idle→S3 Fix** (May 18–23 2026): Haven went dead on battery during travel despite having been explicitly suspended before packing. UPower history showed steady 9–12W draw from 11:09 to 14:15 — the system was fully awake the whole time. Root cause: suspend entered `s2idle` at 11:08:54; the user closed the lid 36 seconds later while packing; `LID0` was armed as a wake source, so the lid-close interrupt woke s2idle immediately; MATE's lid-close action is `blank` (deliberately — carrying the laptop between rooms), so nothing re-suspended. Battery (40%-health, ~30Wh effective) drained in ~3h, critical-battery shutdown at 14:15, dead on arrival. Battery health is 40.5% of design capacity (3884/9600 mAh). Fix applied to `local/haven/bin/termstart`: `mem_sleep` forced to `deep` (S3) on session start, and `LID0` toggled disabled (idempotent guard). Also applied live. Both changes committed `67111d8`.
- **Haven Double Crash + RAPL Bandage + AC-Mode Tracking** (May 22 2026): **Two silent power-offs in 15 minutes** — one at 17:07:23 after a 3 d 19 h uptime (browser-over-NoMachine), and one at 17:21:58, only 34 seconds into the recovery boot during termstart's own self-launching. Both deaths at the same threshold: CPU package power sustained ~30 W with peaks ~38 W, no thermal/GPU/IO component. Two new signals surfaced: (a) Haven has been firing ~18 spurious AC-online udev transitions per day for a week (user's actual plug-cycle rate is ~6/day), with three of them landing in the crash second of crash #1 — points at flaky AC adapter/cable/jack physical path; (b) crash threshold has dropped low enough that a routine boot's own activity crosses it. Three mitigations applied this session: termstart de-burst (~3.6 s of staggering sleeps between parallel launches); RAPL package-power cap (PL1=20W, PL2=27W on `intel-rapl:0`, written idempotently from termstart, vs. stock 200W/61W); new `ac-mode` tool (`common/bin/ac-mode`) with tcsh tab completion (`rc/tcshrc`) for tracking AC-event rate across charging methods (labels: office-ac / office-usb / office-both / den-ac). Initial den-ac measurement: zero AC events in first 10 minutes (vs. 0.75/hr office-ac baseline), too small to conclude but qualitatively favors office-side flakiness. Hardware intervention (battery + repaste + cap inspection) targeted for weekend if possible; RAPL cap is the bandage until then. See `summary:haven-may22-double-crash.md`.
- **Haven viv-mon Made Functional + NoMachine Profile Captured** (May 13 2026): Another silent power-off (workspace switch onto fullscreen video with NoMachine active). Investigation discovered that `viv-mon`'s `pkg=` and `gpu=` columns had been logging zeros the entire May 11→13 window — RAPL energy counters default to `0400 root` (PLATYPUS / CVE‑2020‑8694 mitigation) and the script silently fell back to 0. Fix: `termstart` now `sudo chmod a+r`s `/sys/class/powercap/intel-rapl*/energy_uj` at boot, and `viv-mon` was rewritten to pick RAPL subdomains by name (Raptor Lake has no GPU-only domain — `gpu=` was always `uncore=`, now renamed accordingly), probe the i915 DRM card path (`card1` because `simpledrm` claimed `card0`), add `gfreq=cur/act` + `rc6=Δms` columns from `/sys/class/drm/card1/`, add a `tp=on/off` touchpad-state column (via `xinput`), and emit a periodic `BROWSERS` snapshot line listing distinct browser profiles by their `--user-data-dir` basenames. Same session: full NoMachine usage profile captured and `xpra shadow` mode assessed as a possible replacement — assessment concludes **defer the swap** (crash data doesn't actually point at NoMachine, crashes happen without it, real root cause is hardware degradation, switching cost is non-trivial); revisit only if the next crash's new viv-mon data implicates the framebuffer-capture path. Open mystery: intermittent ~1-sec truncated audio for weeks, possibly correlated with browser sessions, probably unrelated but logged for future tracking. See `summary:haven-may13-vivmon-fix-and-nomachine-profile.md`.
- **Graymoor Setup In Progress** (April 2026): New headless server (Debian 13.2) to replace Zadash
  - OS installed; not yet connected to network
  - IP-KVM purchased: Sipeed NanoKVM Lite (E variant), pending assembly
    - 3D-printed case planned (Bambu Lab A1 printer available)
  - Next steps: assemble NanoKVM, flash SD, connect to office hub, configure SSH/Tailscale/Syncthing
- **Network Stability**: Core infrastructure stable with Tailscale VPN and Eero mesh WiFi

## Tools and Scripts

### fix-wm
`root/sbin/fix-wm` (deploys to `/usr/local/sbin/fix-wm` via root's
`psync`+`makeln`, alongside the other `fix-*` scripts) -- safely restarts the
MATE window manager (marco). It does `pkill -x marco` (SIGTERM) **first**, then
`marco --replace`. The signal-kill is the whole point: an abnormal marco death
trips mate-session's crash-throttle so it backs off, instead of the runaway
~18/sec respawn loop a bare `marco --replace` triggers (which leaked
`xdg-desktop-portal` to 7 GB swap on 2026-06-23 -- see that Current Status entry
and `summary:avalir-marco-respawn-loop.md`). Guards on `$DISPLAY` (won't kill the
WM if it can't relaunch it) and verifies a WM returned. The "Reset Window Manager"
panel launcher and `bin/dtop-gaming` both call it. Note: mate-session does NOT
reliably respawn marco on its own, so `fix-wm` always relaunches it rather than
trusting mate-session to.

### bulk-charge-mon
Haven-local watcher (`local/haven/bin/bulk-charge-mon`, Perl, core-only) that
fires a desktop notification (via the D-Bus `Notify` method on `:0`, visible
locally and over NoMachine) when the battery starts **bulk-charging** -- drawing high charge
current, the load that stacked with video-over-NoMachine to crash the box on
2026-06-10. A near-flat 40%-health pack bulk-charges at a constant ~20W; that
on top of the display load pushed the flaky office-ac adapter over its limit.

- **Detects**: `status=Charging` AND charge power >= 15 W (computed from
  `current_now * voltage_now` on `/sys/class/power_supply/BAT0`). Hysteresis:
  clears below 10 W (taper) -- prevents notification flapping.
- **Notifies**: a **persistent** critical-urgency bubble at onset (`expire_timeout
  0`, so it stays up the whole time it's bulk-charging -- you can't miss it by
  glancing late); its battery %/watts **refresh in place** as the pack climbs
  (re-`Notify` with the same `replaces_id` whenever the integer % moves, ~once a
  minute -- mate updates a same-id bubble quietly, with no re-pop, verified
  2026-06-11); when it tapers, that same bubble is replaced in place (the onset's
  notification id fed back as `replaces_id`) with a transient normal-urgency
  all-clear.
- **Why gdbus, not notify-send**: Haven's `notify-send` is libnotify **0.7.9**,
  which has neither `--print-id` (to capture the id) nor `--replace-id` (to
  replace a bubble in place) -- the two things the persistent-then-replace design
  needs. So the script calls the `org.freedesktop.Notifications` `Notify` method
  via `gdbus` instead (which returns the id and takes `replaces_id`). The first
  cut used notify-send and silently fired NOTHING -- every call died on `Unknown
  option --print-id` before sending -- so no bubble ever appeared until this was
  found and fixed 2026-06-11. Any other Haven desktop-notification code that
  needs an id or replace-in-place must use gdbus for the same reason.
- **Manual check**: `bulk-charge-mon status` prints a one-shot snapshot
  (`battery=.. status=.. charge=..W bulk-charging=YES/no`) using the same
  threshold; `tail ~/local/log/bulk-charge-mon.log` shows the on/off history.
- **Lifecycle**: launched pidfile-guarded from `termstart` (like viv-mon); dies
  on crash, restarted next session. Log: `~/local/log/bulk-charge-mon.log`.
- Polls every 20 s (bulk charge lasts many minutes, so onset latency <= 20 s).

### ac-mode
Tracks Haven's AC charging method against journalctl's `AC: Process` udev
events, to localize the ~18 spurious AC transitions/day surfaced by the
May 22 crash investigation.

**Usage:**
```bash
ac-mode <label>                 # shortcut for `ac-mode mark <label>`
ac-mode mark <label> [at <iso>] # explicit form (supports backdating)
ac-mode report [since]          # events/hr per mode, with in/out/bounce
ac-mode tail [N]                # recent events with mode annotation
ac-mode modes                   # dump full mode log
ac-mode labels                  # list valid labels
```

Valid labels: `office-ac`, `office-usb`, `office-both`, `den-ac`, `spare-ac`.
Each is a distinct physical unit fixed at its location (office barrel adapter /
office USB-C / both / den barrel adapter), except `spare-ac`: the old office
adapter retired 2026-06-15 (a Chicony, a different unit from den-ac), kept as a
roaming low-load spare and given its own label so any pinch-use never pollutes
the new office-ac adapter's data.
Mode log lives at `~/local/log/ac-mode.log` (host-local, not synced).
Run `ac-mode <label>` *immediately before* the next plug action — the
mark defines the active mode for any AC events that follow it. No
need to mark anything when unplugging (the unplug event correctly
attributes to the prior mode, and no events fire during transit).

### mdless
Terminal markdown viewer (`bin/mdless`): thin wrapper around `mdcat`, chosen
over `glow` in the 2026-06 viewer trial (full diagnosis in the TODO Done
entry for 2026-06-04). The wrapper pins `--columns` to the real terminal
width (mdcat can't detect it through a pipe), filters out mdcat's
space-inside-italics bug, and pages via `$PAGER`.

`mdcat` itself is at `/usr/local/bin` on Avalir, Haven, and the quin;
install procedure for new machines is in `setup/local-packages.setup`
(tarball stashed in `/var/install/`), and new quins get it from the cheops
build script. Known cosmetic limitation: under GNU screen 4.x, italics
render as reverse video (screen translates SGR 3 → SGR 7; fixed in screen
5.0, so it goes away whenever the distro catches up).

Note: mdcat upstream (swsnr/mdcat) is archived/unmaintained as of 2025-01-10;
2.7.1 is the final release. So the pinned version is permanent (no upgrades
coming), the space-before-italics bug `mdless` filters will never be fixed
upstream, and if a future glibc ever bit-rots the binary we'd switch viewers
(glow is the fallback). Full detail in the TODO Done entry for 2026-06-08.

### parse-nakama-alerts.pl
Parses QNAP Nakama email alerts to extract the actual alert messages from MIME-encoded emails.

**Usage:**
```bash
# Parse individual alert emails
./parse-nakama-alerts.pl "/path/to/alert-email.eml"

# Parse multiple emails
./parse-nakama-alerts.pl email1.eml email2.eml

# Verbose mode for debugging
./parse-nakama-alerts.pl --verbose email.eml

# Show summary of alert types (when processing multiple files)
./parse-nakama-alerts.pl --all *.eml
```

**Common Alert Types:**
- `[Storage & Snapshots] [IHM]` - IronWolf Health Management disk checks (daily at 03:29-03:30)
- `[Critical Log Alert]` - System critical events

## Key Network Details

- **IP Range**: Private RFC1918 range (DHCP managed by Eero router)
- **VPN Network**: Tailscale subnet for secure remote access
- **Primary User**: [see private/credentials.md] across all Linux systems
- **Security**: UFW firewalls on Linux systems, no external port forwarding
# Vivaldi 6.1 → 7.9 Upgrade and Haven Instability (2026-05-08/09)

## Session Context

Long-running Vivaldi 6.1.3035.111 install on Haven (deferred since 2023 due
to fear of breaking custom CSS) was finally upgraded to 7.9.3970.64 after
Haven crashed on Vivaldi launch — same hardware-off pattern as April 2026
but this time with **NoMachine definitely not involved**, ruling out the
Apr 2026 explanation.

This session is a sequel to:
- `summary:haven-kernel-upgrade-and-gpu-fix.md` (Feb 2026)
- `summary:haven-fstab-uuid-and-vivaldi-guard.md` (Apr 2026)

## What's New / Established

### 1. Vivaldi 7.7+ Modding Has Changed

**Critical for any future Vivaldi upgrade**: as of 7.7+, the experiments
toggle moved.

- **Old (≤7.6)**: `vivaldi://experiments` → "Allow for using CSS modifications"
- **New (≥7.7)**: `chrome://flags/#vivaldi-css-mods` → Enabled

`browser.html` no longer exists in the install dir; replaced by
`main.html` and `window.html`. Old GwenDragon-style patch scripts that
inject `<link rel="stylesheet" ...>` into `browser.html` after each
upgrade are **broken and irrelevant**.

The official mod method is now mandatory:
1. Enable flag at `chrome://flags/#vivaldi-css-mods`
2. **Restart browser** (the "Custom UI Modifications" setting in
   Appearance does not appear until after restart — chicken-and-egg
   trap that ate hours in 2023)
3. Settings → Appearance → Custom UI Modifications → set folder
4. Restart again so CSS loads

Reference: pinned forum post https://forum.vivaldi.net/topic/10549/modding-vivaldi
explicitly notes the 7.7+ change.

### 2. CSS for 7.x Lives in `vivaldi-patch/`

Reorganized as the canonical Custom UI Modifications folder:

- `vivaldi-patch/custom.css` — **active** (the OP from
  https://forum.vivaldi.net/topic/56809 + cosmetic tweaks).
  Last functional update Nov 2023; still works on 7.5/7.6/7.9.
- `vivaldi-patch/upstream/tabs-below-v2023-09-18.css` — clean OP snapshot
- `vivaldi-patch/deprecated/custom.css.pre-7.x` — old `/opt/vivaldi/`-patched CSS
- `vivaldi-patch/deprecated/custom.js` — search-engine-backup JS, dropped
- `vivaldi-patch/deprecated/preserve-ctrl-k.js` — Ctrl-K suppressor, dropped
  (replaced by Vivaldi keyboard shortcut binding)

Vivaldi loads **all** `.css` files in the configured folder, so reference
files are kept under subdirectories to avoid concurrent loading.

### 3. JS Mods Are No Longer Pursued

Per official docs, JS mods still require patching `window.html` after
each upgrade. The cumulative pain isn't worth it for the value the user
got from `custom.js` (search-engine backup) and `preserve-ctrl-k.js`
(Ctrl-K suppression). Both dropped; the latter replaced by a Vivaldi
keyboard shortcut binding.

## Haven Hardware Instability (Distinct from Vivaldi)

Haven crashed **multiple times today** with classic silent-power-off
signature (no journal, no GPU error, no thermal trip, no oops). New
findings beyond the April 2026 summary:

### Crashes Are Not GPU-Specific Anymore

April said: "kernel fix raised threshold but Vivaldi+NoMachine still
exceeds margin." Today's data forces a stronger statement:

- **2.5-min crash on Vivaldi launch** (16:34 boot) — main profile, no
  NoMachine, kernel/Mesa/firmware all unchanged from April baseline
- **2.5-min crash on Vivaldi 7.9 main profile launch with `--disable-gpu`**
- **14-second crash during `termstart`** (no Vivaldi at all, no GPU
  load — just systemd boot + first terminal launch)

Pattern: **silent hardware power-offs are now triggering on routine
load, not specifically GPU bursts.** The likely mechanism is mainboard
component aging (VRMs, decoupling capacitors) — transient power-rail
collapse under any moderately-spiky load.

### Hardware Diagnosis (As of 2026-05-08)

- **Battery**: 40% of design capacity (3884 mAh / 9600 mAh). Confirmed
  not the crash cause (crashed at 73% charge), but should be replaced.
- **Touchpad** (ELAN0412 on i²c): generates ~1170 IRQs/sec at idle pre-
  applet-disable; ~100/sec post-disable. Driver/hardware-level chatter,
  not user input. User has long described touchpad as "super-flaky."
- **Memory**: 64 GB DDR5 Corsair non-ECC. The `EDAC igen6 IBECC MEMORY ERROR`
  messages on every boot are **driver false positives** (sentinel address
  `0x1ffffffffff`, ce_count/ue_count both 0). Not real ECC errors.
- **Thermals**: nominal idle (60-65°C package). Not a thermal issue.
- **NoMachine**: was active April; **not** active today. Confirms the
  April-summary's stated trigger isn't the only path to crash.

### Hardware Intervention Plan (Pending)

1. Battery replacement: Clevo NS50AU compatible part (Juno Computers
   Gemini 15 v5 = Clevo NSxxAU; serial in
   `aidoc/projects/home-network/private/haven-snlabel.jpg`).
   Budget $60-110, source from Sager (US Clevo distributor) or Green
   Cell (third-party).
2. CPU/GPU repaste while case is open. Material (MX-4 or MX-6) on hand.
3. Visual cap inspection near SoC for bulged/leaking caps.
4. If post-repaste/post-battery the crashes continue: mainboard issue,
   plan laptop replacement timeline regardless of tariffs (used Clevo
   NS50AU mainboards on eBay if limp-along is needed).

### Limp-Along Configuration (Active on Haven)

Tonight's Vivaldi-launch survival required these mitigations. Some may
need to remain in place until hardware intervention:

- **Touchpad disabled** via Mate applet (X-level only — kernel still
  receives some chatter, but rate dropped 40×)
- **Docker disabled**: `systemctl disable --now docker docker.socket containerd`
  (user confirmed disable-forever; doesn't use it)
- **Insync killed** + `~/.config/autostart/insync*.desktop` removed (user
  confirmed ditch-forever; never worked for them)
- **CPU governor**: powersave. Not persistent across reboots — must be
  reapplied: `sudo cpupower frequency-set -g powersave`
- **journald `SyncIntervalSec=10s`** in `/etc/systemd/journald.conf`
  (was 5min). Persists.
- **Vivaldi must be launched with `--disable-gpu`** from a terminal. The
  Mate panel launchers (`~/.config/mate/panel2.d/default/launchers/vivaldi-stable*.desktop`)
  go through `~/common/bin/vivaldi-guard` which does **not** inject the
  flag, so panel launches will crash Haven. **Pending TODO**: update
  `vivaldi-guard` to also inject `--disable-gpu` on Haven specifically
  (gate via hostname check). Until then, terminal launches only on Haven.
- **Suspend, don't shut down**: cold boot is the riskiest moment.

### Forensic Setup Left Running

A power/thermal monitor (`/tmp/viv-mon2.sh`) is running on Haven (PID was
86622 as of session end), polling at 5 Hz, logging to
`~/viv-mon-prelaunch.log` with `sync` after every line so a hard
power-off preserves data. Kill with `kill <pid>` when no longer needed.
Output captures: CPU temp zones, battery V/I/W, system load. (RAPL
energy counters are root-only since CVE-2020-8694, so `pkg=0/gpu=0`
columns are blank — that's normal, not a bug.)

## Tabs Backup & Restore Extension (Resolved)

The MV2 extension `dehocbglhkaogiljpihicakmlockmlgd` (Tabs Backup &
Restore, NOT to be confused with Tab Backup & Restore or Tabs Backup)
was popup-broken with `ERR_FILE_NOT_FOUND` — Vivaldi auto-pruned its
code dir (likely during MV2 deprecation enforcement at some prior
update), leaving the user data intact at
`~/.config/vivaldi/Default/Local Extension Settings/<id>/`.

**Recovery**: original MV2 code restored from
`~/.config/vivaldi.save/Default/Extensions/<id>/0.2.1_0/` (also
available at `/export/backup/snapshots/config/haven-20250502/vivaldi.save/...`
and `/export/backup/snapshots/config/avalir-20250417/vivaldi/...`).
Toggle off/on via `vivaldi://extensions` to make Vivaldi reload.

**Migration plan (deferred)**: extension is functional but bit-rotting
(MV2, ChromeWebStore "soon no longer supported" warning). Migrate to
**Tab Session Manager** (sienori/Tab-Session-Manager — open source, MV3,
imports JSON, has explicit Session Buddy import format).

Migration steps when ready:
1. Install Tab Session Manager from Chrome Web Store
2. Extract data from `~/.config/vivaldi/Default/Local Extension Settings/<id>/`
   - Either: `sudo apt install python3-plyvel` (clean Debian package, no
     `$PATH`/`$HOME` cruft, ~250 KB) + script to convert
   - Or: Perl-based extractor using JSON::PP (core only). The extension's
     stored values are JSON-serialized session records starting
     `{"isAutomatic":true,"totNumTabs":N,"windows":[...]}`; bracket-counting
     extraction works.
3. Import via TSM's File → Import
4. Verify; keep old extension installed but disabled until comfort
5. Snapshot already saved at `~/tabs-backup-restore-data.bak` (8.2 MB)

## Vivaldi Profile Backup

Pre-upgrade snapshot at `~/.config/vivaldi.bak.pre-7.9` (4 GB, identical
to the live profile at the time the upgrade started). Safe to delete
once 7.9 has been stable for a while.

## For the Avalir Upgrade (Next Session)

### What Avalir Does Not Need to Redo

- `vivaldi-patch/` is already there (synced)
- `bin/vivaldi-guard` is already there (synced)
- This summary doc is already there (synced)
- Knowledge of which extensions are MV2-broken vs. MV3-fine

### Pre-Flight Checklist for Avalir

1. Snapshot Avalir's `~/.config/vivaldi/` first:
   `rsync -a ~/.config/vivaldi/ ~/.config/vivaldi.bak.pre-7.9/`
2. `apt-cache policy vivaldi-stable` to confirm current installed and
   target versions
3. **Avalir likely does NOT have Haven's hardware instability** (it's a
   desktop with a dedicated PSU, not a laptop with a dying battery + worn
   mainboard caps). Don't carry the `--disable-gpu` mitigation across
   unless it crashes. The two `summary:haven-*` docs covering the crash
   pattern are Haven-specific.
4. `apt install vivaldi-stable` (the new package is ~128 MB)
5. First launch — bare command, no special flags
6. `chrome://flags/#vivaldi-css-mods` → Enabled → restart Vivaldi
7. Settings → Appearance → Custom UI Modifications → folder:
   `/export/proj/common/vivaldi-patch` (Avalir's repo path)
8. Restart Vivaldi → verify tabs-below layout
9. If Avalir has the same `Tabs Backup & Restore` issue: extension code
   is recoverable from
   `/export/backup/snapshots/config/avalir-20250417/vivaldi/Default/Extensions/dehocbglhkaogiljpihicakmlockmlgd/0.2.1_0/`

### What Could Differ

- **Vivaldi profile content is independent.** Avalir's tab session and
  extensions are its own; Haven's session backup is Haven-only.
- **Cosmetic CSS variables.** `custom.css` has Windows-control-button
  padding values tuned for Haven's resolution. Avalir's display setup
  (different DPI/window decoration) may need
  `--addressBarPaddingRight` / `--addressBarPaddingLeft` adjustments.
  Tweak in-place; don't re-fetch the upstream file.

## Avalir Upgrade — Outcome (2026-05-26)

Done. Avalir upgraded **6.1.3035.302 → 7.9.3970.67** (the pre-flight checklist
above held up). Pinned with `apt-mark hold vivaldi-stable` so it won't drift to
the now-current **8.0** — a major "Unified" UI redesign we deliberately deferred
(brand-new, touches the exact tab/chrome surface our CSS mods target; revisit via
a throwaway profile or `vivaldi-snapshot` side-channel). No hardware instability,
no `--disable-gpu` needed (desktop, as predicted).

### Key finding: Vivaldi Sync does NOT carry the css-mods enable flag

Avalir already had Sync on (`keep_everything_synced`), so it had pulled Haven's
**theme**, **tab-bar position (top)**, and the **`css_ui_mods_directory` pointer**
(`/home/buddy/common/vivaldi-patch`, which resolves correctly on Avalir via
`~/common → proj/common`). But the **`chrome://flags/#vivaldi-css-mods` enable
flag did NOT sync** — it lives in per-device `Local State`
(`enabled_labs_experiments`), which Chromium/Vivaldi Sync never replicates.

**Implication for future machines / fresh profiles:** on any synced machine you
must still flip that flag by hand. Avalir got lucky — the in-place 6.1→7.9
upgrade preserved the pre-7.7 enablement, so the CSS was *already* loading and
flipping the new flag was a visual no-op. A *fresh* profile would not have that
carryover.

### Bug found + fixed (affects BOTH machines): dark bookmark bar

The bookmark bar rendered as a dark band (`--colorBg` = `#2e2e2e`) amid the
otherwise-purple chrome, on Avalir *and* Haven. Root cause: a stale "thread #2"
rule at the end of `custom.css` —
`.color-behind-tabs-on .bookmark-bar{,button} { background-color: var(--colorBg) }`
— fired because the theme has "color behind tabs" on, overriding the
unified-transparent `.bookmark-bar` rules added near the top in the May 8 rework
(equal specificity, later in file → wins). Commented out 2026-05-26; the bookmark
bar now unifies with the purple chrome. **Haven picks up the fix on its next
Vivaldi restart** (shared, synced `custom.css`).

### Tabs Backup & Restore on Avalir: intact but disabled

Unlike Haven (where Vivaldi had pruned the MV2 code), Avalir's extension **code
is intact** (`…/Extensions/dehocbglhkaogiljpihicakmlockmlgd/0.2.1_0/`) and **data
is intact** (4.3 MB, last save May 14). It's just **disabled**
(`disable_reasons=[1]` = user/sync action — NOT MV2 auto-disable; uBlock Origin
MV2 runs fine here). Left disabled, consistent with the still-deferred
Tab-Session-Manager migration.

### Terminology correction

This mod requires **tab position = TOP**; "tabs-below" means tabs sit *below the
address bar* (the mod lifts the address bar up into the title-bar row), not tabs
at the window bottom.

### Commit note

The May 8 CSS reorg (`custom.css` 5.x→7.x rework, `deprecated/`, `upstream/`,
`custom.js` move) had been intentionally left **uncommitted** until Avalir was
verified — which proved lucky, since we caught the bookmark-bar bug in the
process. Committed 2026-05-26 together with the bookmark fix and these docs.

## Open Items After This Session

> **Status update (2026-05-11):** items 4, 5, and 6 are resolved in the
> follow-up session — see
> `summary:haven-may11-monitor-relocation-and-mitigation-hardening.md`.
> Item 1 remains the most impactful pending work.

1. **Hardware intervention on Haven** (battery, repaste, cap inspection)
2. ~~**Avalir Vivaldi upgrade** (this doc is the handoff)~~ **Done 2026-05-26 —
   see "Avalir Upgrade — Outcome" above.**
3. **Migrate Tabs Backup & Restore → Tab Session Manager** (defer until
   convenient; data is preserved)
4. ~~**Update `bin/vivaldi-guard`** to inject `--disable-gpu` on Haven
   (gate by hostname). Until then, panel launchers on Haven will crash.~~
   **Done 2026-05-11.**
5. ~~**Touchpad permanent disable on Haven** (kernel-level unbind, not just
   X-level — current applet-disable still leaves ~100 IRQs/sec). Not
   urgent; effective rate is now low.~~ **Rejected 2026-05-11** — `tp`
   toggle is the user's preferred pattern; applet-level + `off`-at-startup
   is enough.
6. ~~**CPU governor persistence on Haven** (TLP / cpufreqd config to make
   powersave persist across reboots). Not urgent — can re-apply manually.~~
   **Done 2026-05-11** via `termstart` rather than TLP/cpufreqd.

## Files Changed This Session

In repo (synced):
- `vivaldi-patch/custom.css` — new, the active CSS (was `custom.css.new`)
- `vivaldi-patch/upstream/tabs-below-v2023-09-18.css` — moved from root
- `vivaldi-patch/deprecated/custom.css.pre-7.x` — moved from root `custom.css`
- `vivaldi-patch/deprecated/custom.js` — moved from root
- `vivaldi-patch/deprecated/preserve-ctrl-k.js` — moved from root
- `aidoc/projects/home-network/summary:vivaldi-7.9-upgrade-and-haven-instability.md` — this doc

On Haven (not synced):
- Vivaldi upgraded to 7.9.3970.64
- Profile backup at `~/.config/vivaldi.bak.pre-7.9`
- Restored extension code at
  `~/.config/vivaldi/Default/Extensions/dehocbglhkaogiljpihicakmlockmlgd/0.2.1_0/`
- Tabs B&R data snapshot at `~/tabs-backup-restore-data.bak`
- `/etc/fstab` of journald (config edit, restart applied)
- Docker / Insync disabled
- Touchpad disabled via Mate applet
- CPU governor on powersave (non-persistent)
- Monitor still polling at PID 86622 → `~/viv-mon-prelaunch.log`

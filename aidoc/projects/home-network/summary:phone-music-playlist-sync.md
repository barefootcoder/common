# Phone Music + Playlist Sync (Pixel 4a "Music Player")

**Date:** 2026-05-27
**Goal:** Push MP3s from Haven onto the Pixel 4a (`pixel-4a`, `sunfish`, Android 13)
and replicate a Haven `.m3u` playlist inside the phone's music app — which is
literally named **"Music Player"** (package `mp3.music.download.player.music.search`,
launcher activity `.activity.MainActivity`, a free MP3-downloader-style player).

This session pushed `/export/music/tracklists/gaming/peaceful.m3u` (21 tracks,
~140 MB) and got it playing as an ordered playlist in the app. Below is the
reusable recipe **and** the constraints, so the dead-ends don't get re-explored.

## The app: how it stores music vs. playlists

- **Songs** are indexed via the Android **MediaStore**
  (`content://media/external/audio/media/`). Title/artist come from **ID3 tags**,
  not filenames — so on-device filenames don't matter for display.
- **Playlists** live in the app's **own private SQLite DB** under
  `/data/data/mp3.music.download.player.music.search/databases/`:
  - `t_mu_plst` — playlist name, `item_count`, `sortOrder`
  - `t_mu_plst_det` — rows of `playlist_id, song_id, path, title, artist, sortOrder`
- The app does **not** surface system/MediaStore playlists in its Playlists UI.
- The app has **no** `.m3u`/`.pls` import and **no** in-app playlist
  backup/import/export feature (confirmed by `strings` over both dex files).

## Reusable recipe — getting songs onto the phone (this part fully works)

1. Phone connected via USB; `adb` works (USB debugging authorized for Haven).
2. Push (trailing slash preserves basename; flatten into one folder is fine as
   long as basenames are unique — guard against collisions):
   `adb push "<file>" /sdcard/Music/<sub>/`
3. Index into MediaStore (synchronous; assigns `_id`, reads ID3):
   `adb shell content call --uri content://media --method scan_volume --arg external_primary`
   - NB: per-file `scan_file` chokes on parens/special chars in the path —
     use `scan_volume`, it's clean and scans the whole external volume.
4. Songs then appear in the app's Songs / Folders / Artists / Albums views.

## Playlists — non-root DB access is a dead end on this device

To populate the app's *own* playlists programmatically you'd need to write its
private DB. **Every non-root avenue was ruled out (Android 13, retail build):**

| Avenue | Result |
|---|---|
| root | Not rooted (`id` = uid 2000 shell, no `su`) |
| `run-as` | App not debuggable → `run-as: package not debuggable` |
| `adb backup` / `restore` | `ALLOW_BACKUP` is set, but local `adb backup` yields an **empty** archive (decoded `.ab` → 1024-byte all-zero tar). Android 12+ strips non-debuggable app data from local backups; `ALLOW_BACKUP` only enables Google **cloud** auto-backup. |
| Exported content provider | Only framework providers (Ads / Firebase / androidx `FileProvider` + startup). No playlist provider to `content insert` into. |
| MediaStore playlist injection | `content insert` into `content://media/external/audio/playlists` works (created + ordered members fine), but **this app ignores MediaStore playlists** — invisible in its UI. (Would work for a *different* player that reads system playlists.) |

## How `peaceful` actually succeeded (the key, non-obvious finding)

The app's private DB had been **cloud-restored from the old phone** during setup,
so it already contained the `peaceful` playlist row **with its track ordering**
(`sortOrder` in `t_mu_plst_det`) — it just showed empty because the songs weren't
present to resolve. Symptom seen along the way: Playlists tab listed all the old
playlists with their **old track counts** but **empty contents**.

Once the 21 songs were pushed + scanned, the user **selected all tracks in the
folder → "Add to playlist" → peaceful**, and the app slotted them into the
**remembered order automatically**. No manual reordering needed.

## Limitation (important for future tracklists)

The "remembered order" trick **only works for playlists that already existed on
the old phone** (their order rode along in the cloud restore). A **brand-new**
playlist (never on the old phone) has no remembered order, so adding songs would
land them in some default sort. Options for that case:
- Manually reorder in-app (the app does allow it), or
- Use a player that reads **MediaStore** playlists or `.m3u` files — the
  MediaStore-injection recipe above already produces a correctly-ordered system
  playlist that such an app would pick up, or
- Root the phone to write the DB directly (not worth it for this).

See `TODO.md` for the captured follow-up.

## Artifacts / state left behind

- `/sdcard/Music/peaceful/` on the phone holds the 21 MP3s (kept — they back the
  playlist). Source: `/export/music/tracklists/gaming/peaceful.m3u`.
- All Haven-side temp files and the stray MediaStore `peaceful` playlist were
  cleaned up at end of session.

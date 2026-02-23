# YouTube Upload Automation: Summary for Follow‑On AI Session

## Overview
The goal of this project is to automate uploading audio tracks to YouTube by generating a static‑image video (MP4) and publishing it to a YouTube channel with metadata. The automation is script‑driven, runs on a Linux system (Avalir), and requires no GUI interaction once OAuth authentication is complete.

## Key Decisions and Outcomes

### 1. **Upload Tool Selected: `youtubeuploader`**
A third‑party CLI tool (`porjo/youtubeuploader`) was selected because:
- It supports YouTube Data API v3.
- It handles OAuth token creation and refresh automatically.
- It simplifies video uploads compared to implementing resumable uploads manually.
Alternatives (e.g., raw API via curl, Python `youtube-upload`) were rejected due to higher complexity or unwanted Python maintenance burden.

### 2. **Authentication Requirements**
YouTube authentication requires OAuth2.
Important decisions:
- A **Web Application OAuth Client** must be created in Google Cloud, *not* a Desktop Client.
- The required redirect URI is:

  ```
  http://localhost:8080/oauth2callback
  ```

- The YouTube Data API v3 must be explicitly enabled in the same Google Cloud project.
- After proper configuration, running `youtubeuploader` generates:
  - `request.token` — persisted OAuth token
  - Future uploads require no browser interaction.

**Token Expiry:** If the Google Cloud project is in "Testing" mode, tokens expire after 7 days. In "Production" mode, they last longer (~6 months of inactivity). When a token expires (`invalid_grant` error), delete `request.token` and re-run `youtubeuploader` to trigger a fresh browser-based OAuth flow:
```bash
mv ~/.g-api/request.token ~/.g-api/request.token.bak
youtubeuploader -secrets ~/.g-api/secret-upload-video.json \
    -cache ~/.g-api/request.token -filename /tmp/some-video.mp4
```
The browser auth flow ends with a blank page — this is normal; check that a new `request.token` was created.

### 3. **Directory Layout**
All OAuth material lives in:

```
~/.g-api/secret-upload-video.json
~/.g-api/request.token
```

This keeps secrets separate from scripts and ensures easy reuse across automation.

### 4. **Video Creation Process**
YouTube does **not** accept raw audio files.
A static-image video must be generated using `ffmpeg`:

```bash
ffmpeg -y -loglevel error -loop 1 -framerate 1 \
    -i cover.jpg \
    -i audio.mp3 \
    -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
    -c:v libx264 -tune stillimage \
    -c:a aac -b:a 192k \
    -shortest -pix_fmt yuv420p \
    output.mp4
```

Key details:
- `-loglevel error` suppresses the verbose build/codec output; only real errors shown.
- `-vf "pad=ceil(iw/2)*2:ceil(ih/2)*2"` pads odd-dimension images to even dimensions, which H.264 requires.
- Works with any audio format (mp3, wav, flac, ogg, etc.) and any image format (jpg, png, webp, etc.) that ffmpeg supports.

### 5. **Thumbnails**
Custom thumbnail upload requires channel phone verification and is a separate API permission. Since the video is a single static image, YouTube's auto-generated thumbnail is identical to the cover image anyway. The script does **not** attempt to set a custom thumbnail.

### 6. **Upload Script: `bin/youtube-upload`**
The finalized script lives in the repo at `bin/youtube-upload`. It:
- Takes 2-3 positional args: `<music-file> <image-file> [description]`
- Derives video title as "Artist - Song Title"
- Supports metadata via `=key=value::key=value` syntax (t=title, a=artist, f=album, y=year, c=copyright holder)
- Fills missing metadata from MP3 tags (via `ffprobe`) and filename pattern (`Artist - Title.ext`)
- Builds a description template with graceful degradation for missing fields
- Options: `-t TITLE`, `-T TAGS`, `-p PRIVACY`, `-P PLAYLIST`, `-n` (dry run), `-h` (help)
- Env var overrides: `YTU_SECRETS`, `YTU_TOKEN`
- Defaults to `unlisted` privacy
- Dry run (`-n`) shows full metadata before cleanup

### 7. **Completed Milestones**
- `youtubeuploader` installed and working.
- Correct OAuth client created and configured.
- Token successfully generated (and re-auth procedure documented).
- Real video uploaded successfully (unlisted).
- Finalized upload script with metadata extraction, template descriptions, and dry-run mode.

## Remaining Work
1. **Batch mode** — wrapper script or loop to process multiple tracks from a directory or manifest file.
2. **Playlist support** — the `-P` flag exists but hasn't been tested with a real playlist ID.
3. **Logging** — for auditability when doing batch uploads.
4. **Scheduling** — `youtubeuploader` supports `-publishAt` for scheduled publishing.
5. **Google Cloud project status** — consider moving from "Testing" to "Production" to avoid frequent token expiry.

This document captures all architectural and configuration decisions needed for further development.

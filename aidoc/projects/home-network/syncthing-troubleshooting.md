# Syncthing Troubleshooting Guide

This guide covers common Syncthing sync issues between Avalir (desktop) and quin (EC2 sandbox instances).

## Quick Status Check

### On Avalir (Desktop)
```bash
# Check if Syncthing is running
ps aux | grep syncthing | grep -v grep

# Access Syncthing Web UI
# URL: http://localhost:8384
# Requires authentication - credentials in GUI settings

# Check status via API
API_KEY=$(grep '<apikey>' ~/.config/syncthing/config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
curl -s -H "X-API-Key: $API_KEY" "http://127.0.0.1:8384/rest/db/status?folder=workproj-ce" | python3 -m json.tool
```

### On quin (EC2 Instance)

**Via SSH Tunnel (Recommended):**
```bash
# From Avalir, establish tunnel to quin
# See private/ec2-sync-credentials.md for current instance ID
cessh --tunnel 8388:localhost:8384 <INSTANCE_ID>

# Access quin's Syncthing UI at: http://localhost:8388
# No authentication required
```

**Direct on quin:**
```bash
# Check if Syncthing is running
ps aux | grep syncthing | grep -v grep

# Check status via API (no API key required while quin is on the v1.x series)
curl -s http://127.0.0.1:8384/rest/db/status?folder=workproj-ce | python3 -m json.tool
```

> **Cluster version baseline (post 2026-05-13):** the entire Syncthing
> cluster — Avalir, Haven, quin (and Zadash once it's powered back on) —
> is aligned on `v1.30.0`. Quin's `~/.local/bin/syncthing` had
> auto-upgraded itself to `v2.1.0` on 2026-05-12, producing a v1↔v2 split
> that was resolved by downgrading quin and disabling its auto-upgrade
> (`autoUpgradeIntervalH=0`). See
> [quin-syncthing-downgrade.md](quin-syncthing-downgrade.md) for the
> runbook and the May 2026 case studies below for the diagnosed
> symptoms.
>
> If quin ever shows `v2.x` again, the REST API on quin will require an
> `X-API-Key` header — v1.x doesn't.

## Common Sync Issues

### 1. "Out of Sync" Status with Permission Errors

**Symptoms:**
- Folder shows "Out of Sync"
- Failed Items: `chmod /path/to/file: operation not permitted`

**Root Cause:**
File ownership or permissions mismatch between the two systems. Syncthing cannot set file permissions when:
- File is owned by a different user than the Syncthing process
- File has unusual permissions (e.g., execute bit on non-executable files)

**Diagnosis Steps:**

1. **Check the failed item:**
   - In Syncthing UI, click on the "Out of Sync" folder
   - Click on "Failed Items" link to see the specific file and error

2. **Check file permissions on both sides:**
   ```bash
   # On Avalir
   ls -la $CEROOT/path/to/file

   # On quin
   ls -la /var/local/CE-src/path/to/file
   ```

3. **Check Syncthing process ownership:**
   ```bash
   # See what user Syncthing runs as
   ps aux | grep syncthing | grep -v grep
   ```

**Solution:**

**Option 1: Fix ownership (if file owned by wrong user)**
```bash
# On quin, change ownership to match Syncthing user
sudo chown bburden:CE /var/local/CE-src/path/to/file
```

**Option 2: Fix permissions on source (if unusual permissions)**
```bash
# On Avalir, remove execute bit from non-executable files
chmod -x $CEROOT/path/to/file

# Then rescan on Avalir side so change propagates
```

**Option 3: Fix permissions directly**
```bash
# On quin, manually fix permissions to match source
chmod 644 /var/local/CE-src/path/to/file  # for regular files
chmod 755 /var/local/CE-src/path/to/file  # for executable files
```

**After fixing, trigger rescans:**
- On Avalir: Click "Rescan" button in Syncthing UI for the folder
- On quin: Click "Rescan" button in Syncthing UI for the folder
- Wait for both sides to sync

### 2. Changes Not Propagating

**Symptoms:**
- File added/modified on one side but doesn't appear on the other
- Status shows "Up to Date" but files are missing

**Common Causes:**
- Rescans only happen every 1 hour by default
- File watching may not be working (inotify missed the change)
- Files may be ignored by `.stignore` patterns

#### Case Study: "Up to Date" But File Missing (January 2026)

**Problem:** A new file (`summary:20260126-investigate-remaining-discrepancies.md`) existed on Avalir but not on quin. Both sides showed "Up to Date".

**Investigation:**
1. Colons in filenames are NOT the issue - other `summary:*.md` files sync fine
2. inotify watch limit was fine (500,000 - checked via `cat /proc/sys/fs/inotify/max_user_watches`)
3. File was not in `.stignore`
4. Manual rescan on Avalir immediately fixed the issue

**Root Cause:** inotify occasionally misses file creation events. This can happen due to:
- Brief network disconnects during file creation
- Timing issues with how editors write files (vim writes to temp then renames)
- Random kernel/inotify glitches

**Prevention:** Enable periodic rescans as a safety net:
- In Syncthing folder settings, set "Full Rescan Interval" to 3600 seconds (1 hour)
- This catches anything inotify misses with minimal overhead
- For the highest-churn quin-shared folders (`workproj-ce`, `proj-common`),
  this is currently set to **600 seconds** — see the May 2026 case study below
  for the reasoning.

#### Case Study: Modified File Not Propagating (April 2026)

**Problem:** `aidoc/projects/devops-scripts/README.md` had a newer mtime and larger size
on Avalir than on quin (Avalir: 02:59/37,727 bytes; quin: 02:28/37,527 bytes). Folder
status on Avalir was `idle` with `needFiles: 0` — Syncthing thought everything was synced.

**Diagnosis — compare Syncthing's DB record against the actual file on disk:**
```bash
# What Syncthing thinks the file looks like (local + global views)
API_KEY=$(grep '<apikey>' ~/.config/syncthing/config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
curl -s -H "X-API-Key: $API_KEY" \
  "http://127.0.0.1:8384/rest/db/file?folder=workproj-ce&file=aidoc/projects/devops-scripts/README.md" \
  | python3 -m json.tool

# Compare with what's actually on disk
ls -la $CEROOT/aidoc/projects/devops-scripts/README.md
```

In this case `local.size` / `local.modified` in the DB matched quin's stale version,
not the newer on-disk file — proving Syncthing's index was out of date. `inodeChange`
in the DB also predated the actual mtime, confirming inotify never saw the write.

**Fix — targeted rescan of just that file** (faster than scanning the whole folder):
```bash
curl -X POST -H "X-API-Key: $API_KEY" \
  "http://127.0.0.1:8384/rest/db/scan?folder=workproj-ce&sub=aidoc/projects/devops-scripts/README.md"
```

After the rescan, the `global` version gained a new entry stamped with Avalir's short
device ID, and quin pulled the new version within seconds.

**Lesson:** Same root cause as the January case — inotify drops events — but for a
*modification* rather than a *creation*. Periodic full rescans remain the recommended
safety net; see Prevention note above.

#### Case Study: New File Not Propagating to quin (May 2026)

**Problem:** A new file `aidoc/ticket-docs/CLASS-990/plan=mece-migration.txt` was
created on quin at 17:56 PDT and was confirmed missing on Avalir minutes later.
Both sides showed `state=idle` with `needFiles=0` and `errors=0`. The file did
*not* appear via passive observation; a manual `GET /rest/db/file?folder=workproj-ce&file=<path>`
metadata query from Avalir, executed during diagnosis, appears to have nudged
Syncthing into noticing the file, which then propagated within seconds.

**What was different from the Jan/Apr cases:**
- The lag was longer than usual (minutes, not the typical seconds).
- Quin had auto-upgraded to Syncthing `v2.1.0` the previous day, so this was
  the first observed instance of the inotify-drop pattern under the mixed-version
  cluster (see "Cluster version note" near the top of this doc).

**Mitigations applied:**
- `rescanIntervalS` lowered from `3600` → `600` on the two highest-churn folders
  shared with quin (`workproj-ce`, `proj-common`). The hourly safety net felt too
  loose given the version mismatch. *Once the cluster is re-aligned and stable,
  these can be relaxed back to `3600`.*
- New helper script `bin/synudge` — takes a directory or a file (parent dir
  is used) and POSTs the corresponding `/rest/db/scan?folder=...&sub=...`
  request, auto-detecting the enclosing Syncthing folder. Use this as a
  faster, name-stable replacement for the curl recipe in case #2 above.

#### Case Study: Cluster Realignment via quin Downgrade (May 2026)

**Problem:** Quin's `~/.local/bin/syncthing` auto-upgraded itself to `v2.1.0`
on 2026-05-12 while Avalir, Haven, and Zadash remained on the apt-managed
v1.x series. Syncthing's `apt stable` channel did not yet ship v2, so the
realistic realignment was to drag quin back to v1.

**Resolution:** Followed the runbook at
[quin-syncthing-downgrade.md](quin-syncthing-downgrade.md):

1. Avalir and Haven were apt-upgraded to `v1.30.0` (Haven was already at
   1.30.0 by accident; Avalir matched it via `apt install syncthing`). Both
   restarted via the apt postinst trigger; no manual systemctl needed.
2. Quin was stopped, its v2 binary stashed, and v1.30.0 installed in
   `~/.local/bin/syncthing`.
3. Quin's `~/.config/syncthing/index-v2/` directory was moved aside;
   Syncthing rebuilt a fresh leveldb on first start (re-indexing took
   tens of minutes for `workproj-ce` and `work-ce`).
4. `autoUpgradeIntervalH` was set to `0` in quin's `config.xml` to prevent
   recurrence.
5. v2 binary, `_v2-stash/`, and a preflight tarball were retained on quin
   as rollback insurance.

**Gotcha worth knowing for future runs:** v2.x writes `config.xml` schema
`v52`; v1.x supports up to `v37`. A plain v1 start refuses with
`config file version (52) is newer than supported version (37)`. Resolved
by adding `--allow-newer-config` to the v1 first-start command — v1
migrates and archives the v52 form as `config.xml.v52`. The runbook now
documents this.

**Lesson:** Watch for binary self-upgrade on the EC2 sandboxes — they're
the only nodes in this cluster outside apt's pinning. Disabling
`autoUpgradeIntervalH` on every quin-style instance at provisioning time
would prevent a repeat.

**Solutions:**

1. **Manually trigger a rescan:**
   - In Syncthing UI, expand the folder
   - Click "Rescan" button

2. **Check last scan time:**
   - In folder details, look at "Last Scan" timestamp
   - If it's old, file watching might not be working

3. **Check if file is ignored:**
   - Look for `.stignore` files in the synced directory
   - Check for patterns that might match your file

4. **Force rescan via API** (preferred path: use `synudge`):
   ```bash
   # Easiest — auto-detects the enclosing folder and the sub-path
   synudge ~/workproj/CE/aidoc/ticket-docs/CLASS-990/plan=mece-migration.txt
   synudge ~/workproj/CE/aidoc/ticket-docs/CLASS-990    # whole subdir works too

   # Manual equivalent on Avalir
   API_KEY=$(grep '<apikey>' ~/.config/syncthing/config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
   curl -X POST -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/db/scan?folder=workproj-ce

   # Manual on quin — v2 now requires the API key (v1.x did not)
   curl -X POST -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/db/scan?folder=workproj-ce
   ```

### 3. Connection Issues Between Devices

**Symptoms:**
- Devices show as "Disconnected"
- One device can't see the other

**Diagnosis:**
```bash
# Check if devices can reach each other
# See private/ec2-sync-credentials.md for Tailscale IPs
# On Avalir
ping <QUIN_TAILSCALE_IP>  # quin's Tailscale IP

# On quin
ping <AVALIR_TAILSCALE_IP>   # Avalir's Tailscale IP
```

**Solutions:**
1. Verify Tailscale is running on both sides
2. Check firewall rules (UFW on Linux systems)
3. Restart Syncthing on both sides

## Useful Commands

### Restart Syncthing

**On quin (user service):**
```bash
# Syncthing runs directly, not as systemd service on quin
# Find and kill the process, then restart
pkill syncthing
~/.local/bin/syncthing serve --no-browser --home=/home/bburden/.config/syncthing &
```

**On Avalir:**
```bash
# Check if running as systemd service
systemctl --user status syncthing

# Restart if using systemd
systemctl --user restart syncthing
```

### View Syncthing Logs

**On quin:**
```bash
# Syncthing logs to stdout when run manually
# Check the terminal where it was started

# Or check system logs
journalctl -u syncthing@$USER -n 50
```

**On Avalir:**
```bash
# If using systemd
journalctl --user -u syncthing -n 50

# Or check Syncthing's log files
tail -f ~/.config/syncthing/syncthing.log
```

### Check Folder Status Details

```bash
# Get detailed folder status (shows errors, file counts, sync state)
API_KEY=$(grep '<apikey>' ~/.config/syncthing/config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
curl -s -H "X-API-Key: $API_KEY" "http://127.0.0.1:8384/rest/db/status?folder=workproj-ce" | python3 -m json.tool

# Check for errors specifically
curl -s -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/system/error | python3 -m json.tool
```

## Standard Synced Folders

Between Avalir and quin:

| Folder Name | Avalir Path | quin Path | Purpose |
|------------|-------------|-----------|---------|
| repo-common | ~/common | ~/common | Personal scripts and configs |
| repo-CE | $CEROOT | /var/local/CE-src | Work project |
| repo-archer-boot | ~/workproj/archer-boot | ~/workproj/archer-boot | Work tooling |
| repo-cheops | ~/workproj/cheops | ~/workproj/cheops | Work project |
| work-ce | ~/work/ce | ~/work/ce | Work data |

## Typical Ownership Patterns

### On quin
- Most files: `bburden:CE`
- Syncthing runs as: `bburden`
- Important: Files must be owned by `bburden` for Syncthing to modify them

### On Avalir
- Most files: `<USER>:users` (see private/credentials.md)
- Syncthing runs as: `<USER>`

## Case Study: Permission Error Resolution

**Problem:** `tmp/check-wider-pattern.sql` failed to sync with error:
```
chmod /var/local/CE-src/tmp/check-wider-pattern.sql: operation not permitted
```

**Investigation:**
1. File on Avalir: `-rwxr-xr-x <USER>:users` (had execute bit - see private/credentials.md)
2. File on quin: `-rwxr-xr-x CE:CE` (owned by wrong user)
3. Syncthing on quin runs as `bburden`

**Resolution:**
1. On Avalir: `chmod -x $CEROOT/tmp/check-wider-pattern.sql` (remove execute bit)
2. On quin: `sudo chown bburden:CE /var/local/CE-src/tmp/check-wider-pattern.sql` (fix ownership)
3. On quin: `chmod -x /var/local/CE-src/tmp/check-wider-pattern.sql` (match permissions)
4. Rescanned on both sides
5. Status changed from "Out of Sync" to "Up to Date"

**Lesson:** SQL files and other non-executable files shouldn't have execute permissions. Check file permissions before adding to sync.

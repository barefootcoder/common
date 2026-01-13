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

# Check status via API (no auth needed on quin)
curl -s http://127.0.0.1:8384/rest/db/status?folder=workproj-ce | python3 -m json.tool
```

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
- File watching may not be working
- Files may be ignored by `.stignore` patterns

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

4. **Force rescan via API:**
   ```bash
   # On Avalir
   API_KEY=$(grep '<apikey>' ~/.config/syncthing/config.xml | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
   curl -X POST -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/db/scan?folder=workproj-ce

   # On quin (no API key needed)
   curl -X POST http://127.0.0.1:8384/rest/db/scan?folder=workproj-ce
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

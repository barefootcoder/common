# QNAP NAS Firmware Update - Known Issues & Fixes

## Overview
QNAP firmware updates have a history of breaking configuration. This document tracks known issues and how to fix them.

**Note**: NAS hostname, SSH port, and firmware version details are in `private/network-details.md`. In examples below, `$NAS` refers to the NAS hostname and `$NAS_PORT` to its SSH port.

## Historical Firmware Update Issues

### Issue 1: Missing `/share/homes` Symlink
**Affected:** Firmware updates (observed: November 2025)

**Symptom:**
- SSH login fails with: `Could not chdir to home directory /share/homes/<USER>: No such file or directory`
- `/etc/passwd` still references `/share/homes/<USER>` but symlink is missing
- (See `private/credentials.md` for actual username)

**Root Cause:**
The firmware update removes the `/share/homes -> CACHEDEV1_DATA/homes/` symlink, even though the actual home directories are intact in `/share/CACHEDEV1_DATA/homes/`.

**Fix:**
```bash
cd /share
sudo ln -s CACHEDEV1_DATA/homes homes
```

**Verification:**
```bash
ls -la /share/homes/
ssh -p $NAS_PORT <USER>@$NAS  # Should work with key auth now (see private/credentials.md)
```

### Issue 2: Passwordless Sudo Disabled
**Affected:** Firmware updates (observed: November 2025)

**Symptom:**
- `sudo` commands prompt for password even though user is in `administrators` group

**Root Cause:**
The firmware update modifies `/usr/etc/sudoers` and removes `NOPASSWD:` from the `%administrators` line.

**Fix:**
```bash
# Backup first
sudo cp /usr/etc/sudoers /usr/etc/sudoers.backup

# Edit the sudoers file
sudo vi /usr/etc/sudoers
```

**Change this line:**
```
%administrators ALL=(ALL) ALL
```

**To this:**
```
%administrators ALL=(ALL) NOPASSWD: ALL
```

**Verification:**
```bash
# Exit and reconnect
exit
ssh -p $NAS_PORT $NAS
sudo ls /root  # Should not prompt for password
```

## Post-Firmware-Update Checklist

After applying any QNAP firmware update, check and fix these items:

1. **Verify SSH access works:**
   ```bash
   ssh -p $NAS_PORT $NAS
   ```
   - If you get "Could not chdir to home directory", see Issue 1 above

2. **Verify passwordless sudo works:**
   ```bash
   ssh -p $NAS_PORT $NAS 'sudo ls /root'
   ```
   - If it prompts for password, see Issue 2 above

3. **Verify critical services are running:**
   ```bash
   # Check if shares are accessible
   ls /share/backup /share/work /share/proj

   # Check SSH is on correct port (see private/network-details.md)
   # Via web UI: Control Panel → Telnet / SSH
   ```

4. **Check system logs for issues:**
   - Web UI → QuLog Center → Event Log
   - Look for warnings/errors after the firmware update timestamp

## Automated Fix Script

**Location:** `/export/proj/common/aidoc/projects/home-network/nakama-firmware-fix`

After any QNAP firmware update, run:
```bash
~/common/aidoc/projects/home-network/nakama-firmware-fix
```

This script will:
1. Restore the `/share/homes` symlink if missing
2. Fix passwordless sudo configuration
3. Verify both SSH and sudo work properly

**Note:** The script uses `ssh -t` to allocate a TTY, allowing sudo to prompt for password interactively during the fix process. After the sudoers file is fixed, subsequent runs won't need passwords.

### Script Implementation Reference

If you need to recreate or understand the script logic:

```bash
#!/bin/bash
# /share/scripts/post-firmware-fix.sh

# Fix 1: Restore /share/homes symlink
if [ ! -L /share/homes ]; then
    echo "Restoring /share/homes symlink..."
    cd /share && ln -s CACHEDEV1_DATA/homes homes
fi

# Fix 2: Restore passwordless sudo
if ! grep -q "%administrators ALL=(ALL) NOPASSWD: ALL" /usr/etc/sudoers; then
    echo "Fixing passwordless sudo..."
    cp /usr/etc/sudoers /usr/etc/sudoers.backup
    sed -i 's/%administrators ALL=(ALL) ALL/%administrators ALL=(ALL) NOPASSWD: ALL/' /usr/etc/sudoers
fi

echo "Post-firmware fixes complete!"
```

## QNAP-Specific Paths Reference

Standard Linux paths don't always apply on QNAP systems:

- **Sudoers file:** `/usr/etc/sudoers` (NOT `/etc/sudoers`)
- **Home directories:** `/share/CACHEDEV1_DATA/homes/` (symlinked as `/share/homes`)
- **User data:** `/share/CACHEDEV1_DATA/` (main volume)
- **SSH config:** Web UI → Control Panel → Network & File Services → Telnet / SSH

### Checking Firmware Version

To check the current QTS version and build number via SSH:

```bash
ssh $NAS 'getcfg System Version -f /etc/config/uLinux.conf'
ssh $NAS 'getcfg System "Build Number" -f /etc/config/uLinux.conf'
```

Or combined:
```bash
ssh $NAS 'getcfg System Version -f /etc/config/uLinux.conf && getcfg System "Build Number" -f /etc/config/uLinux.conf'
```

See `private/network-details.md` for expected firmware version after the latest security update.

## Security Advisory Context

The November 2025 firmware update addressed critical vulnerabilities disclosed at PWN2OWN 2025 across multiple QNAP components (Malware Remover, QuMagie, Notification Center, Qsync Central, and QTS core OS).

Despite the configuration breakage, these security updates are critical and should be applied - just be prepared to fix the resulting issues.

## Lessons Learned

1. **QNAP firmware updates can be destructive** - Always be prepared to restore configuration
2. **Document everything** - The next firmware update will likely break the same things
3. **Test immediately after update** - Don't discover broken SSH access when you need it urgently
4. **Consider automation** - If this becomes a pattern, automate the fixes
5. **Keep local console access** - Web UI access is critical when SSH breaks

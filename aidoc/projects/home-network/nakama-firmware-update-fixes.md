# QNAP NAS Firmware Update - Known Issues & Fixes

## Overview
QNAP firmware updates have a history of breaking configuration. This document tracks known issues and how to fix them.

**Note**: NAS hostname, SSH port, and firmware version details are in `private/network-details.md`. In examples below, `$NAS` refers to the NAS hostname and `$NAS_PORT` to its SSH port.

## Historical Firmware Update Issues

### Issue 1: Missing `/share/homes` Symlink
**Affected:** Firmware updates (observed: November 2025)

**Symptom:**
- SSH login fails with: `Could not chdir to home directory /share/homes/<USER>: No such file or directory`
- **Worse manifestation (seen 2026-06-20): a total SSH key-auth lockout.** Because `~/.ssh/authorized_keys` lives *under* the now-missing home path, `sshd` cannot read it, so public-key auth is rejected and SSH falls back to password: `Permission denied (publickey,password,keyboard-interactive)`. This locks out key-based tooling AND the key path of this very fix script, so the fix must be run interactively and you enter the password **~3 times** (SSH login, then `sudo` for the symlink, then `sudo` for the sudoers fix) -- both key auth and passwordless sudo are down until the script finishes.
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

### Issue 3: The update can silently FAIL while still breaking the symlink
**Affected:** observed 2026-06-20, updating 5.2.7 (build 20251024) toward 5.2.9.3499 (build 20260514)

**Symptom:**
- You apply the update, the NAS reboots, and the "New firmware updates are available" banner is *still there*. It is tempting to call it a stale-banner bug. It usually is not -- the update genuinely did not install.

**What actually happened (2026-06-20):**
- After the update + reboot, `getcfg System Version` still read `5.2.7` / build `20251024`, unchanged. QNAP boots the old image when the new one fails to apply, so the box reverted and the banner was accurate.
- The failed attempt *still* wiped the `/share/homes` symlink (Issue 1) and took out key-based SSH -- so you pay the breakage without getting the upgrade.

**Confirm the real version -- do not trust the banner either way:**
```bash
ssh -p $NAS_PORT $NAS 'getcfg System Version -f /etc/config/uLinux.conf; getcfg System "Build Number" -f /etc/config/uLinux.conf'
```

**Cause -- NOT confirmed (don't assume space).** The QTS updater (`/etc/init.d/update.sh`) does have an explicit `FW_NOFREESPACE` failure ("not enough space on the system volume to decrypt firmware image"), and `/` is tiny (84% full, ~65M free), which fits. BUT the staging-partition key (`FIRMWARE STORAGE / UPDATE_TMP_PARTITION` in `/etc/platform.conf`) is unset, and the box has ~3.8G RAM free for a tmpfs staging mount -- so a simple disk-space failure is *not* established. Get the real reason from the Web UI: **QuLog Center -> System Event Log**, around the update timestamp -- look for the firmware-update-failed entry. Only if it cites space, free `/mnt/ext` (92% full; remove unused QPKGs) and retry.

**Retrying without the Web UI modal.** The login-time "update available" popup is only the Live Update *notification*, not the path to updating. Three dialog-free routes:
- *Web UI:* dismiss the popup, then Control Panel -> System -> Firmware Update (Live Update tab to re-apply; Manual Update tab to flash a downloaded `.img`).
- *CLI (headless):* `/sbin/qcli_firmwareupdate` -- `sudo qcli_firmwareupdate -i` (info), `-c` (check), `-u` (perform the update).
- *Stop the popup recurring:* untick "automatically check" on that Control Panel page, or `sudo setcfg System "Enable Live Update" FALSE -f /etc/config/uLinux.conf`.

Whichever route, it is the **same** update that just failed, so it will fail the same way until the root cause is found -- and expect the Issue-1 symlink breakage afterward regardless, so run `nakama-firmware-fix` once when it finishes.

**Recommendation:** do not retry blindly -- each failed attempt costs the Issue-1 key-auth-lockout recovery (3 password entries). The box runs fine on 5.2.7 and Container Station / other apps install to the data volume, so defer the firmware update until the event log explains the failure.

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

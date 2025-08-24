# QNAP IHM Daily Notification Management

## Issue Summary
User receives daily emails from QNAP Nakama NAS at 03:29 and 03:30 for IronWolf Health Management (IHM) disk checks. These are routine "everything's fine" notifications that clutter the inbox. User wants to stop these while still receiving actual error/warning notifications.

## Current State
- **Root Cause Identified**: Cron job at `/etc/config/crontab`:
  ```
  30 3 * * * /sbin/storage_util --ironwolf_disk_health_test dev_id=00000001
  ```
- **IHM Tool**: `/sbin/stx_ihm` (symlink to `/usr/local/sbin/stx_ihm`) - Seagate SeaDragon utility
- **Device**: `dev_id=00000001` refers to first disk (sda)

## Discarded Approaches (Don't Retry These)
1. **GUI Configuration**: No granular IHM schedule controls in Storage & Snapshots interface
2. **Notification Center Rules**: Too broad - would disable ALL storage alerts, not just IHM
3. **Direct IHM Disable**: Would lose health monitoring entirely

## Viable Options (User Has Not Chosen Yet)

### Option 1: Comment Out Cron Job
```bash
ssh nakama
cp /etc/config/crontab /etc/config/crontab.backup
sed -i 's/^30 3 \* \* \* \/sbin\/storage_util --ironwolf/#&/' /etc/config/crontab
/etc/init.d/crond.sh restart
```
- **Pros**: Stops all IHM tests and emails
- **Cons**: Loses health monitoring; may be overwritten by firmware updates

### Option 2: Redirect to /dev/null
```bash
ssh nakama
cp /etc/config/crontab /etc/config/crontab.backup
sed -i 's|30 3 \* \* \* /sbin/storage_util --ironwolf_disk_health_test dev_id=00000001|& >/dev/null 2>&1|' /etc/config/crontab
/etc/init.d/crond.sh restart
```
- **Pros**: Tests run silently; health data collected
- **Cons**: No notifications at all (even errors)

### Option 3: Reduce Frequency
```bash
# Weekly (Sundays)
sed -i 's/30 3 \* \* \*/30 3 * * 0/' /etc/config/crontab

# Monthly (1st of month)
sed -i 's/30 3 \* \* \*/30 3 1 * */' /etc/config/crontab
```
- **Pros**: Fewer emails
- **Cons**: Still get routine notifications

### Option 4: Wrapper Script (Recommended)
```bash
cat > /share/backup/ihm_wrapper.sh << 'EOF'
#!/bin/sh
OUTPUT=$(/sbin/storage_util --ironwolf_disk_health_test dev_id=00000001 2>&1)
EXIT_CODE=$?
# Only output if error
if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -iE '(error|fail|critical|warning)'; then
    echo "$OUTPUT"
    exit $EXIT_CODE
fi
exit 0
EOF
chmod +x /share/backup/ihm_wrapper.sh
sed -i 's|/sbin/storage_util --ironwolf_disk_health_test dev_id=00000001|/share/backup/ihm_wrapper.sh|' /etc/config/crontab
/etc/init.d/crond.sh restart
```
- **Pros**: Only emails on problems; tests run daily; safest approach
- **Cons**: Requires maintaining custom script

### Option 5: Email Filtering (Fallback)
Configure email client to filter:
- Subject contains: `[Nakama Alert]`
- Body contains: `[Storage & Snapshots] [IHM]`
- Action: Auto-archive

## Related Files
- `/export/proj/common/aidoc/projects/home-network/nakama-notification-adjustment-notes.md`
- `/export/proj/common/aidoc/projects/home-network/parse-nakama-alerts.pl`

## Next Steps
User needs to choose which option to implement. Option 4 (wrapper script) provides the best balance of maintaining health monitoring while eliminating routine notifications.

## Restore Commands
```bash
# Check current status
ssh nakama "grep ironwolf /etc/config/crontab"

# Restore from backup
ssh nakama "cp /etc/config/crontab.backup /etc/config/crontab && /etc/init.d/crond.sh restart"
```

## Important Notes
- Changes to `/etc/config/crontab` persist across reboots but may be overwritten by firmware updates
- Modifying system files might affect warranty/support
- Always backup before changes

[Session Date: 2025-08-24]
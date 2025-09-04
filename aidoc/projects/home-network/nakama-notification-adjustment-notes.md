# QNAP Nakama Notification Adjustment Process

## Issue
Daily email notifications from QNAP Nakama NAS at 03:29 and 03:30 for IronWolf Health Management (IHM) disk checks.

## What We Discovered
- The alerts are routine IHM (IronWolf Health Management) disk health checks
- They occur daily at:
  - 03:29 - IHM scan started
  - 03:30 - IHM scan finished
- These are informational notifications, not critical alerts

## Web Interface Navigation Path
1. Access QNAP web interface at https://<NAKAMA_IP>
2. Login with credentials (password entry required)
3. Navigate to: Control Panel > Notification Center > System Notification Rules
4. Found one rule: "Storage and System Alerts" sending emails to barefootcoder@gmail.com

## Limitations Encountered
- The "Storage and System Alerts" rule appears to be a system-defined rule without granular edit options
- Could not find a direct way to disable only IHM notifications while keeping other storage alerts
- Global Notification Settings shows service-level toggles but not severity-level filtering

## Alternative Solutions

### 1. Email Client Filtering (Recommended)
Create an email filter with these criteria:
- Subject contains: "[Nakama Alert]"
- Body contains: "[Storage & Snapshots] [IHM]"
- Action: Auto-archive or move to a folder

### 2. Check for IHM-Specific Settings
- Look for IHM configuration in Storage & Snapshots app
- Check if IHM scheduling can be adjusted to reduce frequency

### 3. Command Line Options
Via SSH (port 2322, user 'nami'):
```bash
# Check for notification configuration files
find /etc -name "*notification*" -o -name "*alert*" 2>/dev/null
# Look for IHM configuration
find /etc -name "*ihm*" -o -name "*ironwolf*" 2>/dev/null
```

### 4. Contact QNAP Support
If the notifications become too bothersome, QNAP support may have additional configuration options not exposed in the web UI.

## Script for Parsing Alert Emails
A Perl script has been created at `/export/proj/common/aidoc/projects/home-network/parse-nakama-alerts.pl` to extract and parse these MIME-encoded alert emails for easier reading.

Usage:
```bash
./parse-nakama-alerts.pl /path/to/alert-email.eml
```
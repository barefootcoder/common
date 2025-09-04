# Home Network Project

This project contains documentation and management information for the home network infrastructure.

## Project Overview

This is a mixed-platform home network with Linux systems, NAS storage, and smart home devices. The network is currently undergoing upgrades, particularly the replacement of a Synology NAS with a more powerful QNAP system.

## CRITICAL: System Environment Notes

### Shell Environment
- **Interactive shell on Linux systems**: `tcsh` (NOT bash)
- **Remote command execution**: Commands via SSH execute in tcsh by default
- **Use `bash -c` for complex remote commands**: 
  ```bash
  # CORRECT: ssh haven 'bash -c "ls -l 2>/dev/null | grep foo"'
  # WRONG:   ssh haven "ls -l 2>/dev/null | grep foo"  # tcsh syntax error
  ```

### Linux Mint Filesystem Structure  
- **UsrMerge implementation**: On Haven and Avalir (Linux Mint 21.1), these are symlinks:
  - `/bin` → `/usr/bin`
  - `/sbin` → `/usr/sbin`
  - `/lib*` → `/usr/lib*`
- **Important**: `/bin/foo` and `/usr/bin/foo` are the SAME file - don't compare them
- **Package queries**: Use `/usr/bin/*` paths (e.g., `dpkg -S /usr/bin/python3`)

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

## Private Data (Local Only)

The `private/` directory contains sensitive information that is excluded from version control:

- **[private/network-details.md](private/network-details.md)**: Actual IP addresses, Tailscale VPN IPs, specific firewall port configurations, hardware model numbers, and ISP details
- **[private/credentials.md](private/credentials.md)**: System usernames, UIDs/GIDs, administrator account names, and group memberships

## Historical Context (AI Session Summaries)

The following files contain summaries from previous AI collaboration sessions. These provide context for ongoing issues but should only be referenced when specifically relevant:

- `summary:ec2-syncthing.html` - Syncthing configuration for EC2 servers
- `summary:haven-crash-diagnosis-summary.md` - Diagnosis of Haven system crashes
- `summary:haven-thermal-diagnosis-and-resolution.md` - Haven thermal issue resolution
- `summary:intermittent-shutdowns-diagnosis.md` - Analysis of system shutdown problems
- `summary:intermittent-shutdowns.html` - HTML version of shutdown diagnostics

## Current Status

- **NAS Migration Complete**: QNAP Nakama (TS-364) deployed and operational (August 2025)
  - Single 4TB disk configuration with snapshot support
  - SSH/rsync access configured with key-based authentication
  - Backup directories created at `/share/backup`, `/share/archive`, `/share/personal`, `/share/proj`, `/share/work`
  - Daily IHM (IronWolf Health Management) scans running at 03:29 AM
- **Ongoing Issues**: Haven experiencing intermittent shutdowns (thermal-related, under monitoring)
- **Network Stability**: Core infrastructure stable with Tailscale VPN and Eero mesh WiFi
- **Planned Improvements**: EC2 Tailscale integration, Zadash hardwired connection fixes

## Tools and Scripts

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
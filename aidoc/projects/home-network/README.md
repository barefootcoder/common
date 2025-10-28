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

## EC2 Sandbox Sync Integration

**⚠️ IMPORTANT FOR AI AGENTS**: Only read this section if the user specifically mentions EC2 sandboxes, syncing with EC2, or working with "quin" instances. Otherwise, skip this section.

### Overview
EC2 sandboxes ("quin" instances) can be configured for bidirectional file sync with Avalir (desktop) using Tailscale VPN and Syncthing. This allows seamless development with automatic sync of `~/common`, `~/work`, and `~/CE` directories.

### Key Documentation Files (When Working on EC2 Sync)
- **[EC2-sync-proof-of-concept.md](EC2-sync-proof-of-concept.md)**: Complete test results and current setup
- **[EC2-sync-automation-roadmap.md](EC2-sync-automation-roadmap.md)**: Detailed automation implementation guide
- **[ec2-sync-bootstrap.sh](ec2-sync-bootstrap.sh)**: Bootstrap script for new EC2 instances
- **[/export/proj/common/bin/sandbox-setup](/export/proj/common/bin/sandbox-setup)**: Local script to setup tunnels

### Private Files (When Needed)
- **[private/ec2-sync-credentials.md](private/ec2-sync-credentials.md)**: Current EC2 instance ID, Tailscale auth key, device IDs

### Quick Start for AI Agents
If user asks about EC2 sandbox sync:
1. Read `EC2-sync-proof-of-concept.md` for current state
2. Check `private/ec2-sync-credentials.md` for instance ID
3. Run `sandbox-setup <instance-id>` to establish connections
4. Access Syncthing UI at http://localhost:8388
5. For Claude Code: MCP servers are configured via project-scoped `.mcp.json` files
   - After initial sync, restart Claude Code to load the configuration
   - Authenticate with `/mcp` command if using OAuth services

## Current Status

- **NAS Migration Complete**: QNAP Nakama (TS-364) deployed and operational (August 2025)
  - Single 4TB disk configuration with snapshot support
  - SSH/rsync access configured with key-based authentication
  - Backup directories created at `/share/backup`, `/share/archive`, `/share/personal`, `/share/proj`, `/share/work`
  - Daily IHM (IronWolf Health Management) scans running at 03:29 AM
- **EC2 Sandbox Sync**: Operational with Tailscale + Syncthing (September 2025)
  - Proof-of-concept complete, semi-automated setup available
  - See EC2 Sandbox Sync Integration section if working on this
- **Ongoing Issues**: Haven experiencing intermittent shutdowns (thermal-related, under monitoring)
- **Network Stability**: Core infrastructure stable with Tailscale VPN and Eero mesh WiFi

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
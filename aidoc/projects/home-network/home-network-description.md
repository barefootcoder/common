# Network Description

## Hardware Components
- **Internet Connection**: Spectrum (formerly Time-Warner Cable) with a provider-supplied modem connected via coax
- **Primary Router**: Eero mesh WiFi system with IPv6 enabled
  - Main gateway configured with DHCP
  - At least one mesh extender node located upstairs
  - UPnP enabled, Amazon Connected Home integration active
  - Client steering enabled for better device connectivity
- **Network Switches**:
  - TP-Link gigabit switch connected directly to the modem
  - Small 4-port hub located in office area

## Machines
- **Linux Systems**:
  - **Haven**: Linux Mint 21.1 (Vera) running Mate, based on Ubuntu Jammy
    - Primarily connected via WiFi
    - Static IP: [see private/network-details.md]
    - UFW firewall active (SSH, mDNS, and application ports)
    - Tailscale VPN configured and running
    - Experiencing intermittent shutdown issues (under monitoring)
    - Interactive shell: tcsh; scripts use bash
    - Filesystem: UsrMerge implemented (/bin → /usr/bin, etc.)
  - **Avalir**: Linux Mint 21.1 (Vera) running Mate, based on Ubuntu Jammy
    - Desktop machine hardwired through office hub
    - Static IP: [see private/network-details.md]
    - UFW firewall active (SSH and Syncthing ports)
    - Tailscale installed but not currently running
    - Interactive shell: tcsh; scripts use bash
    - Filesystem: UsrMerge implemented (/bin → /usr/bin, etc.)
  - **Zadash**: Slightly older version of Linux Mint
    - Intended to be hardwired but currently using WiFi due to connection issues
    - Static IP: [see private/network-details.md]
    - Experiencing some hardware issues
    - Tailscale active
    - Has mounted (via `sshfs`) copies of shares from Avalir
    - Interactive shell: tcsh; scripts use bash
    - Filesystem: Likely has UsrMerge (to be verified)
  - **Caemlyn**: 
    - Static IP: [see private/network-details.md]
    - Being decommissioned; contains backups pending transfer to new NAS
    - Will be returned to company after QNAP setup

- **NAS Systems**:
  - **Previous - Taaveren**: Synology DS220j (decommissioned)
    - Replaced by Nakama in August 2025
  - **Current - Nakama**: QNAP TS-364 (operational as of August 2025)
    - 3-bay NAS with Intel Celeron N5095 processor
    - 8GB DDR4 RAM (expandable to 16GB)
    - Dual 2.5GbE networking
    - Static IP: <NAKAMA_IP>
    - SSH on port 2322, user 'nami' with key-based authentication
    - Single 4TB Seagate drive configured as single-disk storage pool
    - 2.8TB volume with 743GB reserved for snapshots
    - Backup directories: `/share/backup`, `/share/archive`, `/share/personal`, `/share/proj`, `/share/work`

## Network Services
- **Tailscale VPN**: Deployed across all machines for secure remote access
- **Syncthing**: File synchronization service running across machines
  - Various shares configured between machines
  - Versioning setup on Zadash
  - Planned integration with NAS and EC2 servers

## Smart Home Infrastructure
- Amazon Alexa ecosystem with multiple Echo Dots
- Google Home system with main console and satellite devices
- Home automation integration with Eero router

## Security
- UFW firewalls on Linux machines with specific port allowances
- Router-level firewall through Eero
- Secure remote access managed via Tailscale VPN
- No external port forwarding rules exposing services to the internet

## Connection Types
- Mixed connectivity with both wired and wireless connections
- Avalir (desktop) connected via Ethernet
- All laptops connected via WiFi (with Zadash currently using WiFi despite intended Ethernet connection)
- Critical devices (NAS, router, TV, game console) connected via Ethernet

## User Management
- Single primary user [see private/credentials.md] across all Linux systems
- UIDs synchronized across all Linux machines
- Consistent group memberships across systems:
  - Primary group: users (gid=100)
  - Admin access via sudo group (gid=27)
  - Custom dev group (gid=502) on all machines
- Standard Linux system users otherwise

## Network Administration
- **Primary Admin Device**: Android phone
  - Used for Eero router management via Eero app
  - Provides emergency WiFi hotspot when needed
  - Connected to Tailscale network

## Planned Upgrades
- Complete Tailscale access for EC2 servers
- Fix hardwired connection for Zadash
- Implement automated backup schedules using rsync scripts
- Configure Syncthing on Nakama NAS
- Decommission Caemlyn after remaining data migration
- Consider adding second drive to Nakama for RAID-1 redundancy

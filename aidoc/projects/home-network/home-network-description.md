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
  - Netgear switch in office area (5 ports: 3 in use, 2 free as of April 2026)
    - Current: Avalir, Zadash, uplink to router
    - Planned: Graymoor + IP-KVM will use the 2 free ports (Zadash port frees up after decommission)
- **IP-KVM**: Sipeed NanoKVM Lite (E variant) for out-of-band console access to Graymoor
  - Hardware: LicheeRV Nano E (RISC-V SG2002, 256MB DDR3) + HDMItoCSI board
  - Connections: HDMI + USB-C to Graymoor (USB provides both HID and power), Ethernet to office hub
  - 100Mbps Ethernet, 1080P@60fps capture, open-source software
  - 3D-printed case (STL from Printables) for dust protection
  - Provides browser-based console access independent of Graymoor's network state
  - Status: purchased April 2026, pending assembly and deployment

## Machines
- **Linux Systems**:
  - **Haven**: Linux Mint 21.1 (Vera) running Mate, based on Ubuntu Jammy
    - Primarily connected via WiFi
    - Static IP: [see private/network-details.md]
    - UFW firewall active (SSH, mDNS, and application ports)
    - Tailscale VPN configured and running
    - Kernel: 6.8.0-100-generic (HWE), upgraded from 6.1-oem in Feb 2026
    - GPU: Intel Raptor Lake-P Iris Xe (modesetting + iris + glamor)
    - Interactive shell: tcsh; scripts use bash
    - Filesystem: UsrMerge implemented (/bin → /usr/bin, etc.)
    - Note: Clevo laptop with DKMS keyboard backlight module
    - Note: Keyboard generates non-standard keycodes for numpad keys (e.g., keypad decimal is keycode 129 `<KPPT>` instead of standard 91 `<KPDL>`)
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
    - Being replaced by Graymoor (see below)
  - **Graymoor**: Debian 13.2 (Trixie) — headless server, replacing Zadash
    - Currently not yet connected to network; OS installed, pending initial setup
    - Planned: hardwired Ethernet to office hub
    - Planned: SSH, Tailscale, Syncthing, sshfs shares (mirroring Zadash's role)
    - Console access via IP-KVM device (see Network Hardware section)
  - **Caemlyn** *(decommissioned May 2026, hardware dead)*:
    - Was: company-issued machine. All data was migrated to Nakama
      (`/share/{archive,personal,backup,proj,...}`) and the machine then died
      before being returned. No longer on the network — `ssh caemlyn` returns
      "no route to host" and the host should not be expected to be reachable.
    - Mentioned in legacy MATE keybinding docs (Zadash↔Caemlyn pairing) — those
      bindings are dormant.

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

## Other Hardware
- **3D Printer**: Bambu Lab A1
  - Used for printing equipment enclosures (e.g., NanoKVM case)

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
- **Graymoor setup**: Connect to network, configure SSH, Tailscale, Syncthing; replace Zadash's role
- Complete Tailscale access for EC2 servers
- Implement automated backup schedules using rsync scripts
- Configure Syncthing on Nakama NAS
- Decommission Zadash after Graymoor is fully operational
- Consider adding second drive to Nakama for RAID-1 redundancy

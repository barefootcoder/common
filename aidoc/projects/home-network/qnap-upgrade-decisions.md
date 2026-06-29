# QNAP NAS Upgrade Decision Document

## Current System
- Synology DS220j (Taaveren)
- Issues: Performance limitations, RAM constraints, timeouts
- Current Usage: Basic file storage, no automated backups
- Integration: Part of Tailscale network, planned for Syncthing (not implemented)

## Selected Upgrade
Originally selected: QNAP TS-264-8G-US (2-bay).  **NOTE: the deployed unit is
actually a QNAP TS-364 (3-bay)** -- the migration from the TS-264 to the TS-364
is recorded in `summary:nakama-storage-reconfiguration.md`.  Same Celeron N5095
platform, so the specs below apply to both; the bay count is the difference.
- 2-bay (TS-264) / 3-bay (TS-364, deployed)
- Intel Celeron N5095 processor
- 8GB DDR4 RAM (expandable to 16GB)
- Dual 2.5GbE networking
- M.2 PCIe expansion slots

## Key Decision Factors
1. Performance needs:
   - Syncthing integration
   - Backblaze B2 backup capability
   - Container support
   - Remote access requirements

2. Migration considerations:
   - Existing drives can be reused (after reformatting)
   - Most data currently duplicated on Avalir and Haven
   - Will require fresh setup of services and configurations

## Implementation Requirements
1. Data Migration:
   - Identify unique data on current Synology
   - Plan transfer methodology using existing machines
   - Document shares and permissions for recreation

2. Network Integration:
   - Tailscale configuration
   - 2.5GbE network setup considerations
   - Remote access planning

3. Service Setup Priorities:
   - Syncthing configuration
   - Backblaze B2 backup implementation
   - Container environment if needed
   - Remote access configuration

## Security Considerations
- Maintain Tailscale for remote access
- Careful initial security configuration
- Keep system updated
- Avoid exposing admin interfaces to internet

## Future Expansion Possibilities
- RAM upgrade to 16GB if needed
- M.2 PCIe slot utilization
- Additional container deployments
- Enhanced backup strategies
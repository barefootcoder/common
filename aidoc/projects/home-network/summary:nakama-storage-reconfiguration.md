# Nakama NAS Storage Reconfiguration Summary

**Date**: August 15-16, 2025
**System**: QNAP TS-364 (Nakama)
**Issue**: Daily alert emails about degraded RAID arrays after 2-bay to 3-bay migration

## Problem Description
After migrating from a QNAP TS-264 (2-bay) to TS-364 (3-bay) enclosure with a single 4TB drive, the system was sending two daily alert emails about degraded RAID arrays. The root cause was that the storage configuration still expected 2 drives from the original 2-bay setup but only had 1 drive installed.

## Investigation Findings
- RAID arrays showed degraded state: `[2/1] [U_]` indicating 1 of 2 expected drives
- Multiple MD arrays (md322, md256, md13, md9) in degraded state
- System was functional but continuously alerting about the degraded state

## Solution Implemented

### 1. Backed Up Configuration
- Saved critical configuration files from `/export/proj/common/projects/home-network/`
- Documented rsync setup and SSH access details

### 2. Storage Pool Removal
- Removed existing degraded storage pool through QNAP web interface
- Verified clean state with empty /proc/mdstat

### 3. Created New Storage Configuration
- **Storage Pool**: Single-disk configuration with Seagate 4TB drive
  - 20% snapshot space allocation (743.42 GB)
  - 80% alert threshold
  - Status: Ready
- **Volume**: Thin volume "DataVol1"
  - Capacity: 2.8 TB
  - File system: ext4
  - Snapshot support enabled
  - Smart versioning retention configured

### 4. Restored Access and Directories
- Re-established SSH key authentication (`ssh-copy-id -p 2322 nami@nakama`)
- Created backup directories:
  - `/share/backup`
  - `/share/archive`
  - `/share/personal`
  - `/share/proj`
  - `/share/work`
- Created symbolic links in /share/ for easy access
- Verified rsync functionality

## Final Status
- Storage pool shows healthy: `[1/1] [U]` (proper single-disk configuration)
- Volume mounted at `/share/CACHEDEV1_DATA` with 2.8TB available
- SSH/rsync access working with key-based authentication
- No more degraded RAID warnings

## Key Learnings
1. When migrating between different bay configurations, complete storage reconfiguration may be necessary
2. QNAP maintains RAID metadata even when moving to different hardware
3. Single-disk configurations should use single-disk RAID setup, not degraded multi-disk RAID
4. Storage reconfiguration wipes user home directories and SSH keys - these must be recreated

## Follow-up Actions
- Monitor for any further alert emails (should be resolved)
- Consider adding second drive for RAID-1 redundancy in the future
- Implement automated backup schedules using the configured rsync infrastructure
- Configure Syncthing integration for real-time file synchronization
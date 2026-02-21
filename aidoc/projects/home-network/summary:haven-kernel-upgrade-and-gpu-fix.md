# Haven Kernel Upgrade and GPU Driver Fix (2026-02-20)

## Problem Description

Haven was experiencing hard crashes (no graceful shutdown, no journal entries) triggered specifically by launching Vivaldi browser's main profile. The system had a long history of intermittent shutdowns and GPU-related instability documented in earlier summaries.

### Symptoms
- Launching Vivaldi main profile caused immediate hard crash
- Alternate (lighter) Vivaldi profile worked fine
- After crashes, multiple reboot attempts needed before system stabilized
- Fullscreen video playback in Vivaldi caused intermittent freezes (video froze, audio continued)
- `dmesg` showed `i915 0000:00:02.0: [drm] *ERROR* arb session failed to go in play` on every boot

### Key Diagnostic Evidence
- Crashes occurred at normal temperatures (46°C), ruling out thermal causes
- No OOM, no swap usage, no excessive load at crash time
- Journal entries just stopped abruptly (hard crash, not graceful shutdown)
- The `arb session` errors appeared on every single boot regardless of configuration

## Root Cause

**The i915 kernel DRM driver in kernel 6.1.0-1022-oem was fundamentally buggy for Haven's Raptor Lake-P [Iris Xe Graphics] GPU (PCI ID 8086:a7a0).**

Multiple compounding factors:

1. **Wrong kernel for the hardware**: Kernel 6.1 (OEM, from 2023) had incomplete/buggy Raptor Lake support. The `arb session failed to go in play` errors are PXP (Protected Xe Path) subsystem failures.

2. **Wrong Xorg DDX driver**: The `xserver-xorg-video-intel` DDX driver (configured in `/etc/X11/xorg.conf.d/20-intel.conf`) reported `Unknown chipset` for Raptor Lake. This GPU requires the `modesetting` DDX driver.

3. **Wrong DRI driver**: The old intel DDX tried to load `i965_dri.so` (for Gen4-Gen11 GPUs). Raptor Lake is Gen12+ and needs `iris_dri.so`. AIGLX fell back to DRISWRAST (software rendering).

4. **Workarounds masked the real problem**: Previous sessions had added `NoAccel: True` to the xorg config and i915 kernel parameters (`enable_psr=0`, `enable_dc=0`, `enable_fbc=0`, `enable_guc=0`). These reduced GPU usage enough to avoid most crashes but never fixed the underlying driver bugs.

### Why the main Vivaldi profile specifically triggered crashes
- 5.6 GB profile with 16 extensions, 2.1 GB Service Worker cache, 708 MB IndexedDB
- `restore_on_startup: 1` with 7 pinned tabs (ChatGPT, Mastodon, Discord x2, etc.)
- 9.8 MB session file (dozens of additional tabs)
- All tabs restoring simultaneously hammered the broken GPU subsystem
- The alternate "media" profile (238 MB, 3 extensions, minimal tabs) stayed below the crash threshold

## Resolution

### Changes Applied (in order)

1. **Kernel upgrade: 6.1.0-1022-oem → 6.8.0-100-generic**
   ```bash
   sudo apt install linux-image-oem-22.04c
   # Meta-package resolved to linux-image-6.8.0-100-generic (HWE kernel)
   ```
   - This was the critical fix
   - Kernel 6.8 has ~2 years of i915 Raptor Lake fixes over 6.1
   - `arb session` errors completely eliminated

2. **Mesa upgrade: 23.0.4 → 23.2.1**
   ```bash
   sudo apt install libgl1-mesa-dri mesa-va-drivers mesa-vulkan-drivers
   ```

3. **linux-firmware update: 0ubuntu3.19 → 0ubuntu3.41**
   ```bash
   sudo apt install linux-firmware
   sudo update-initramfs -u -k 6.8.0-100-generic
   ```

4. **Removed old Intel xorg config** (`20-intel.conf` → `20-intel.conf.disabled`)
   - X now auto-detects `modesetting` DDX driver
   - Uses `iris` DRI driver and `glamor` acceleration correctly
   - Xorg log confirms: `glamor X acceleration enabled on Mesa Intel(R) Graphics (RPL-P)`

5. **Upgraded clevo-keyboard DKMS module: 0.3.1-4 → 0.4.4-3**
   - Old version failed to build against kernel 6.8 (API change: `acpi_device_ops.remove` signature)
   - New version builds cleanly

6. **GRUB kernel parameters cleaned up**
   - The i915 workaround parameters (`enable_psr=0`, `enable_dc=0`, `enable_fbc=0`, `enable_guc=0`, `log_buf_len=1M`) were removed during the upgrade
   - Not needed on kernel 6.8

### Changes NOT Applied (preserved from earlier sessions)
- **NoMachine resource limits** (`/etc/systemd/system/nxserver.service.d/limits.conf`): Kept as good defensive practice (CPUQuota=50%, Nice=10, MemoryLimit=2G)
- **Vivaldi `--disable-gpu-compositing --enable-webgl`** flag in panel launcher: Kept for now. May be removable since the underlying GPU issue is fixed, but not urgent.

## Current Configuration (Post-Fix)

### Kernel & GPU Stack
- **Kernel**: 6.8.0-100-generic (HWE)
- **Xorg DDX**: modesetting (auto-detected, no config file)
- **DRI driver**: iris
- **Acceleration**: glamor (hardware-accelerated)
- **Mesa**: 23.2.1
- **Firmware**: linux-firmware 0ubuntu3.41

### Fallback Options
- Old kernels available in GRUB: 6.1.0-1022-oem, 6.1.0-1014-oem
- Old xorg config preserved at `/etc/X11/xorg.conf.d/20-intel.conf.bak` and `.disabled`

### Verification Commands
```bash
# Check kernel version
uname -r
# Should be: 6.8.0-100-generic

# Check for GPU errors (should return nothing)
dmesg | grep -iE 'i915.*ERROR|arb session'

# Verify Xorg is using modesetting + iris
grep -E 'modeset|iris|glamor' /var/log/Xorg.0.log

# Check temperatures
sensors | grep Package
```

## Other Fixes in This Session

### Audio Profile Reset
- After kernel upgrade, PulseAudio defaulted to HDMI output instead of analog speakers
- Fixed by switching card profile: `pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:analog-stereo+input:analog-stereo`
- Modernized `~/common/root/sbin/fix-audio` script to handle systemd-managed PulseAudio and auto-select analog stereo profile

### Screen Buffer Hold Files
- Fixed `~/common/bin/screen-buflog-hold-files` to use negative lookbehind (`(?<!-hold)\.`) to prevent stacking `-hold` infixes on repeated reboots

## Superseded Documentation

The following earlier summaries describe workarounds that are **no longer the recommended approach**. The kernel upgrade is the proper fix:

- `summary:haven-crash-diagnosis-summary.md` - Describes the `20-intel.conf` and kernel parameter workarounds. These are no longer needed on kernel 6.8.
- `summary:haven-thermal-diagnosis-and-resolution.md` - Describes Vivaldi GPU and NoMachine CPU issues causing thermal shutdowns. The GPU issues are resolved; the NoMachine limits remain as a precaution.

## Lessons Learned

1. **Kernel version matters enormously for GPU stability.** The i915 driver improved dramatically between 6.1 and 6.8 for Raptor Lake.
2. **Workarounds can mask root causes.** Disabling GPU acceleration prevented crashes but also prevented diagnosis of the real issue (buggy kernel driver).
3. **"Wrong driver" symptoms**: `Unknown chipset` in Xorg log, `arb session failed to go in play` in dmesg, and AIGLX falling back to DRISWRAST are all signs that the Xorg/Mesa/kernel stack doesn't properly support the GPU.
4. **When diagnosing GPU crashes**: Check kernel age vs GPU generation first, before adding workaround flags.

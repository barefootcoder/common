# Haven Laptop Crash Diagnosis Summary

## Problem Description
Haven (a Linux Mint 21.1 laptop) was experiencing sudden crashes, particularly during:
- Remote access sessions using NoMachine
- When using Vivaldi browser, especially when F11 was pressed to enter fullscreen mode
- During system restarts, at the point where the GUI is initializing
- The crashes were severe enough to require hard resets

## Root Cause Analysis
The investigation identified the Intel i915 graphics driver as the primary culprit:
- Log files showed multiple "arb session failed to go in play" errors from the i915 driver
- X.org logs showed "Failed to submit rendering commands (Invalid argument), disabling acceleration"
- The issue was triggered by specific GPU operations, particularly during mode changes and heavy GPU workloads
- The combination of NoMachine remote access (which uses GPU acceleration) and Vivaldi browser created conditions that exacerbated the problem

## Implemented Solutions

### 1. Added Intel Graphics Configuration
Created a new configuration file at `/etc/X11/xorg.conf.d/20-intel.conf`:

```
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "AccelMethod"  "sna"
    Option      "TearFree"     "true"
    Option      "DRI"          "2"
    Option      "NoAccel"      "False"  # Try "True" if crashes continue
EndSection
```

### 2. Modified NoMachine Client Settings
- Disabled network-adaptive display quality
- Disabled client-side hardware decoding
- Maintained resolution at native display resolution
- Quality slider set to middle/moderate (can be moved further toward "Best speed" if needed)

### 3. Planned Browser Changes
- Disabled hardware acceleration in Vivaldi browser settings (under Settings → search for "hardware")

## Additional Options (Not Yet Implemented)

### 1. More Aggressive Graphics Configuration
If crashes continue:
- Change `NoAccel` from "False" to "True" in the Intel config file
- This will disable hardware acceleration entirely, reducing performance but increasing stability

### 2. Kernel Parameters Modification
If crashes persist, add these parameters to GRUB:
```
i915.modeset=1 i915.enable_fbc=0 i915.enable_guc=2
```

To implement this:
```bash
sudo nano /etc/default/grub
# Add parameters to GRUB_CMDLINE_LINUX_DEFAULT
sudo update-grub
```

### 3. Alternative Remote Access Solutions
Consider alternatives to NoMachine if problems continue with graphical performance

## Monitoring and Verification
- System is now configured to maintain system-monitor logs that capture critical system metrics
- The `/var/log/system-monitor/` directory contains these logs
- These logs should be consulted if crashes recur

## Key Commands for Further Diagnostics
```bash
# Check for graphics driver errors
dmesg | grep -i "i915\|error\|fail"

# Check X configuration application
grep -i intel /var/log/Xorg.0.log

# View latest system monitoring data
cat /var/log/system-monitor/$(ls -t /var/log/system-monitor/ | head -1)

# Check power events (for AC power related issues)
tail -20 /var/log/power-events.log
```

## Next Steps
1. Continue monitoring system stability
2. Implement additional options if crashes persist
3. Consider kernel updates or newer driver versions if available
4. Avoid triggering conditions (fullscreen changes in NoMachine) where possible

This configuration should provide a good balance of performance and stability, with fallback options if further issues arise.
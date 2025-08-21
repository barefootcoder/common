# Haven System Diagnostics - Intermittent Shutdown Investigation

:::: section
## Overview

Investigation into unexpected system shutdowns occurring on Haven, a
Linux Mint 21.1 system. The shutdowns primarily occur during overnight
hours with no immediately apparent cause. The system is otherwise stable
with no observable memory issues or resource contention.

::: highlight
**System Environment:**

-   Operating System: Linux Mint 21.1
-   Issue: Intermittent unexpected shutdowns
-   Pattern: Predominantly overnight occurrences
-   System Status: Otherwise stable operation
:::
::::

::: section
## Monitoring Infrastructure

### 1. System Monitor Script

-   Minute-level monitoring via systemd timer
-   Captures comprehensive metrics:
    -   CPU frequencies and temperature
    -   Power management information
    -   Battery status
    -   Graphics driver errors
    -   System load and resource usage
    -   Voltage levels
    -   ACPI events
-   15-minute interval checks for disk health, detailed temperatures,
    and process information
-   Two-week log retention policy

### 2. Power Event Monitor

-   Implemented as systemd service
-   Tracks AC power state changes
-   Minute-level polling frequency
-   Logs stored in /var/log/power-events.log

### 3. SMART Monitoring

-   Weekly short tests (Sundays, 2:13 AM)
-   Monthly long tests (1st of month, 3:17 AM)
-   User-level execution
-   Results logged to user\'s home directory

### 4. Event Correlation

-   Manual analysis tool for post-shutdown investigation
-   Integrates data from multiple monitoring sources
-   Preserves shutdown context for analysis

### 5. Boot Logging

-   Enhanced kernel logging via GRUB
-   Dedicated shutdown reason capture service
-   Previous boot log preservation
:::

::: section
## Key Decisions

-   Adopted interval-based temperature monitoring instead of continuous
    monitoring
-   Implemented 2-week log retention policy
-   Utilized prime number scheduling for cron jobs
-   Optimized monitoring intervals for system performance
-   Chose manual event correlation approach
-   Standardized on Allman style bracing and hyphenated naming
    convention
:::

:::: section
## Current Status

::: note
-   All monitoring systems are operational and collecting data
-   Root cause remains unidentified
-   Data collection continues for further analysis
:::
::::

::: section
## Next Steps

-   Continue monitoring and data collection
-   Analyze gathered data in subsequent sessions
-   Potential refinement of monitoring strategies based on findings
-   Consider additional diagnostic measures as patterns emerge
:::

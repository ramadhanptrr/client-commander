#!/bin/bash

# ==========================================
# NAS BOOT TIME (EPOCH) — uptime watchdog
# ==========================================
#
# Outputs the NAS boot time as a unix epoch (UTC), e.g. 1753082400.
# The Commander bot SSH-runs this as a FIXED script path (Infisical: NAS_UPTIME_SCRIPT),
# never as an inline command, then computes uptime as `now - <this output>`.
# Converting to epoch here keeps it timezone-safe and independent of the bot's clock.
# Keep stdout clean: a single integer, nothing else.

# Primary: boot timestamp from `uptime -s` (procps)
BOOT=$(uptime -s 2>/dev/null)

if [ -n "$BOOT" ]; then
    date -d "$BOOT" +%s
else
    # Fallback: derive from /proc/uptime (seconds since boot)
    UP=$(cut -d' ' -f1 /proc/uptime)
    echo $(( $(date +%s) - ${UP%.*} ))
fi

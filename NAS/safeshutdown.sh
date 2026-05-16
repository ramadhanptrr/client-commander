#!/bin/bash

set -e

LOG_FILE="/home/rama/script/safeshutdown.log"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🛑 SAFE SHUTDOWN INITIATED"

# =========================
# STOP SERVICES
# =========================

log "• Stopping vsftpd..."
systemctl stop vsftpd || log "• vsftpd already stopped"

sleep 2

# =========================
# FLUSH FILESYSTEM
# =========================

log "• Syncing filesystem..."
sync

# =========================
# DETECT & UNMOUNT DISKS
# =========================

MOUNT_POINTS=$(mount | awk '$3 ~ /^\/mnt\// { print $3 }' | sort -r)

if [ -z "$MOUNT_POINTS" ]; then

    log "• No mounted disks detected"

else

    echo "$MOUNT_POINTS" | while read -r disk; do

        if mountpoint -q "$disk"; then

            log "• Unmounting $(basename "$disk")..."

            if umount "$disk"; then

                log "✅ $(basename "$disk") unmounted"

            else

                log "❌ Failed to unmount $(basename "$disk")"

                fuser -vm "$disk" 2>&1 | tee -a "$LOG_FILE"

                log "🛑 Shutdown aborted"

                exit 1
            fi
        fi
    done
fi

# =========================
# FINAL SYNC
# =========================

log "• Final sync..."
sync

sleep 3

# =========================
# SHUTDOWN
# =========================

log "⏳ Poweroff in 1 minute"

shutdown +1 "Graceful shutdown initiated by Commander Bot"

log "✅ Shutdown sequence completed"
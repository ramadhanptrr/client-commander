#!/bin/bash

# ==========================================
# EDGE NODE STATUS (TELEGRAM FRIENDLY)
# ==========================================

HOSTNAME=$(hostname)

# Uptime
UPTIME=$(uptime -p | sed 's/up //')

# Load Average
LOADAVG=$(cut -d " " -f1-3 /proc/loadavg)

# CPU Usage
CPU_USAGE=$(top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f%%", 100 - $8}')

# Memory Usage
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')

# Disk Usage
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')

# ==========================================
# NETWORK USAGE
# ==========================================

IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)

RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)

sleep 1

RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)

RX_RATE=$(( (RX2 - RX1) / 1024 ))
TX_RATE=$(( (TX2 - TX1) / 1024 ))

# ==========================================
# DOCKER STATUS
# ==========================================

if systemctl is-active --quiet docker; then
    DOCKER_STATUS="ONLINE"
else
    DOCKER_STATUS="OFFLINE"
fi

CONTAINER_NAME="telegram-commander"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    CONTAINER_STATUS="RUNNING"
else
    CONTAINER_STATUS="STOPPED"
fi

RUNNING_CONTAINERS=$(docker ps -q | wc -l)
TOTAL_CONTAINERS=$(docker ps -aq | wc -l)

# ==========================================
# WIREGUARD STATUS
# ==========================================

WG_INTERFACE=$(sudo wg show interfaces 2>/dev/null | awk '{print $1}' | head -n1)

if [ -n "$WG_INTERFACE" ]; then

    WG_STATUS="ONLINE"

    WG_PEER_STATUS=$(sudo wg show "$WG_INTERFACE" 2>/dev/null \
        | grep "latest handshake" \
        | head -n1 \
        | sed 's/.*latest handshake: //')

    if [ -z "$WG_PEER_STATUS" ]; then
        WG_PEER_STATUS="NO HANDSHAKE"
    fi

else
    WG_STATUS="OFFLINE"
    WG_PEER_STATUS="-"
fi

# ==========================================
# STATUS INDICATORS (color-friendly emoji)
# ==========================================

# Docker indicator
case "$DOCKER_STATUS" in
    ONLINE)  DOCKER_ICON="🟢" ;;
    OFFLINE) DOCKER_ICON="🔴" ;;
    *)       DOCKER_ICON="⚪" ;;
esac

# Container indicator
case "$CONTAINER_STATUS" in
    RUNNING)  CONTAINER_ICON="🟢" ;;
    STOPPED)  CONTAINER_ICON="🔴" ;;
    *)        CONTAINER_ICON="⚪" ;;
esac

# WireGuard indicator
case "$WG_STATUS" in
    ONLINE)  WG_ICON="🟢" ;;
    OFFLINE) WG_ICON="🔴" ;;
    *)       WG_ICON="⚪" ;;
esac

# Handshake freshness
if [ "$WG_PEER_STATUS" = "NO HANDSHAKE" ] || [ "$WG_PEER_STATUS" = "-" ]; then
    HANDSHAKE_ICON="⚠️"
else
    HANDSHAKE_ICON="✅"
fi

# ==========================================
# OUTPUT
# ==========================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

MESSAGE=$(cat <<EOF
🔍 <b>EDGE NODE STATUS</b>
━━━━━━━━━━━━━━━━━━━━

📌 <b>General</b>
   🌐 Host    <code>$HOSTNAME</code>
   ⏱️  Uptime <code>$UPTIME</code>
   📊 Load    <code>$LOADAVG</code>

🖥️  <b>Resources</b>
   CPU   $CPU_USAGE
   RAM   ${MEM_USED}MB / ${MEM_TOTAL}MB <code>(${MEM_PERCENT}%)</code>
   Disk  ${DISK_USED} / ${DISK_TOTAL} <code>(${DISK_PERCENT})</code>

🌐 <b>Network</b>
   ⬇️  Download <code>${RX_RATE} KB/s</code>
   ⬆️  Upload   <code>${TX_RATE} KB/s</code>

🔒 <b>WireGuard</b>
   $WG_ICON Status     <code>$WG_STATUS</code>
   $HANDSHAKE_ICON Handshake <code>$WG_PEER_STATUS</code>

🐳 <b>Docker</b>
   $DOCKER_ICON Daemon     <code>$DOCKER_STATUS</code>
   📦 Containers  <code>${RUNNING_CONTAINERS}/${TOTAL_CONTAINERS}</code>
   $CONTAINER_ICON Commander   <code>$CONTAINER_STATUS</code>

━━━━━━━━━━━━━━━━━━━━
🕐 $TIMESTAMP
EOF
)

echo "$MESSAGE"

#!/bin/bash

# ==========================================
# EDGE NODE STATUS (TELEGRAM FRIENDLY)
# ==========================================

# Hostname: fallback if hostname cmd fails (common in containers)
HOSTNAME=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "edge-node")

# Uptime
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "unknown")

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

# Check if Commander bot process is running (more reliable inside container)
if pgrep -f "python.*bot" > /dev/null 2>&1; then
    CONTAINER_STATUS="RUNNING"
else
    # Fallback: check container name (works on host)
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        CONTAINER_STATUS="RUNNING"
    else
        CONTAINER_STATUS="STOPPED"
    fi
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
# OUTPUT
# ==========================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "EDGE NODE STATUS"
echo "============================"
echo ""
echo "[ GENERAL ]"
echo "Host    : $HOSTNAME"
echo "Uptime  : $UPTIME"
echo "Load    : $LOADAVG"
echo ""
echo "[ RESOURCES ]"
echo "CPU     : $CPU_USAGE"
echo "RAM     : ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PERCENT}%)"
echo "Disk    : ${DISK_USED} / ${DISK_TOTAL} (${DISK_PERCENT})"
echo ""
echo "[ NETWORK ]"
echo "Download: ${RX_RATE} KB/s"
echo "Upload  : ${TX_RATE} KB/s"
echo ""
echo "[ WIREGUARD ]"
echo "Status    : $WG_STATUS"
echo "Handshake : $WG_PEER_STATUS"
echo ""
echo "[ DOCKER ]"
echo "Daemon     : $DOCKER_STATUS"
echo "Containers : ${RUNNING_CONTAINERS}/${TOTAL_CONTAINERS}"
echo "Commander  : $CONTAINER_STATUS"
echo ""
echo "============================"
echo "$TIMESTAMP"

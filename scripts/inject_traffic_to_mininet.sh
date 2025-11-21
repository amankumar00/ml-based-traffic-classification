#!/bin/bash
# Inject heavy iperf traffic into running Mininet session
# Uses mnexec to execute commands in mininet host namespaces

set -e

echo "================================================================"
echo "INJECTING HEAVY TRAFFIC INTO RUNNING MININET"
echo "================================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must run as root (use sudo)"
    exit 1
fi

# Check if mininet is running
if ! pgrep -f "mininet" > /dev/null; then
    echo "ERROR: Mininet does not appear to be running!"
    echo ""
    echo "Please start mininet first:"
    echo "  sudo python3 topology/fplf_topo.py"
    exit 1
fi

echo "✓ Mininet is running"
echo ""

# Function to get PID of mininet host
get_host_pid() {
    local host=$1
    pgrep -f "mininet:$host\$" | head -1
}

# Kill existing iperf processes
echo "Cleaning up old iperf processes..."
killall iperf 2>/dev/null || true
sleep 1

echo ""
echo "================================================================"
echo "STARTING IPERF SERVERS (Matching ML Classification)"
echo "================================================================"

# Start iperf servers on destinations matching ML classification
echo "Starting iperf servers on h1..."
H1_PID=$(get_host_pid h1)
if [ -n "$H1_PID" ]; then
    mnexec -a $H1_PID iperf -s -p 5004 -u > /dev/null 2>&1 &  # h3->h1 VIDEO
    mnexec -a $H1_PID iperf -s -p 80 -u > /dev/null 2>&1 &    # h3->h1 HTTP
    mnexec -a $H1_PID iperf -s -p 22 -u > /dev/null 2>&1 &    # h5->h1 SSH
    echo "  ✓ h1 servers started (PID: $H1_PID) - ports 5004, 80, 22"
else
    echo "  ✗ ERROR: Could not find h1"
fi

echo "Starting iperf servers on h2..."
H2_PID=$(get_host_pid h2)
if [ -n "$H2_PID" ]; then
    mnexec -a $H2_PID iperf -s -p 8080 -u > /dev/null 2>&1 &  # h4->h2 HTTP
    mnexec -a $H2_PID iperf -s -p 5006 -u > /dev/null 2>&1 &  # h4->h2 VIDEO
    mnexec -a $H2_PID iperf -s -p 22 -u > /dev/null 2>&1 &    # h6->h2 SSH
    echo "  ✓ h2 servers started (PID: $H2_PID) - ports 8080, 5006, 22"
fi

echo "Starting iperf server on h3..."
H3_PID=$(get_host_pid h3)
if [ -n "$H3_PID" ]; then
    mnexec -a $H3_PID iperf -s -p 21 -u > /dev/null 2>&1 &    # h5->h3 FTP
    echo "  ✓ h3 server started (PID: $H3_PID) - port 21"
fi

echo "Starting iperf server on h4..."
H4_PID=$(get_host_pid h4)
if [ -n "$H4_PID" ]; then
    mnexec -a $H4_PID iperf -s -p 21 -u > /dev/null 2>&1 &    # h6->h4 FTP
    echo "  ✓ h4 server started (PID: $H4_PID) - port 21"
fi

echo ""
echo "Waiting 3 seconds for servers to initialize..."
sleep 3

echo ""
echo "================================================================"
echo "GENERATING HEAVY TRAFFIC"
echo "================================================================"

# VIDEO Traffic (high priority, should avoid congestion)
echo ""
echo "VIDEO Traffic (Priority 4 - Avoids Congestion - EXTREME BANDWIDTH):"
H3_PID=$(get_host_pid h3)
if [ -n "$H3_PID" ]; then
    mnexec -a $H3_PID iperf -c 10.0.0.1 -p 5004 -u -b 30M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h3 -> h1:5004 (30 Mbps VIDEO, flow_id=62)"
fi

if [ -n "$H4_PID" ]; then
    mnexec -a $H4_PID iperf -c 10.0.0.2 -p 5006 -u -b 30M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h4 -> h2:5006 (30 Mbps VIDEO, flow_id=68)"
fi

# SSH Traffic (medium-high priority)
echo ""
echo "SSH Traffic (Priority 3 - Moderate Avoidance - EXTREME BANDWIDTH):"
H5_PID=$(get_host_pid h5)
if [ -n "$H5_PID" ]; then
    mnexec -a $H5_PID iperf -c 10.0.0.1 -p 22 -u -b 15M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h5 -> h1:22 (15 Mbps SSH, flow_id=64)"
fi

H6_PID=$(get_host_pid h6)
if [ -n "$H6_PID" ]; then
    mnexec -a $H6_PID iperf -c 10.0.0.2 -p 22 -u -b 25M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h6 -> h2:22 (25 Mbps SSH, flow_id=65)"
fi

# HTTP Traffic (medium priority)
echo ""
echo "HTTP Traffic (Priority 2 - Slight Avoidance - EXTREME BANDWIDTH):"
if [ -n "$H3_PID" ]; then
    mnexec -a $H3_PID iperf -c 10.0.0.1 -p 80 -u -b 10M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h3 -> h1:80 (10 Mbps HTTP, flow_id=61)"
fi

if [ -n "$H4_PID" ]; then
    mnexec -a $H4_PID iperf -c 10.0.0.2 -p 8080 -u -b 10M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h4 -> h2:8080 (10 Mbps HTTP, flow_id=67)"
fi

# FTP Traffic (low priority, tolerates congestion)
echo ""
echo "FTP Traffic (Priority 1 - Tolerates Congestion - EXTREME BANDWIDTH):"
if [ -n "$H6_PID" ]; then
    mnexec -a $H6_PID iperf -c 10.0.0.4 -p 21 -u -b 35M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h6 -> h4:21 (35 Mbps FTP, flow_id=63)"
fi

if [ -n "$H5_PID" ]; then
    mnexec -a $H5_PID iperf -c 10.0.0.3 -p 21 -u -b 35M -t 120 > /dev/null 2>&1 &
    echo "  ✓ h5 -> h3:21 (35 Mbps FTP, flow_id=66)"
fi

echo ""
echo "================================================================"
echo "EXTREME TRAFFIC GENERATION STARTED - OVERSATURATING LINKS!"
echo "================================================================"
echo ""
echo "Total bandwidth on s2->s1 link: 105 Mbps (30M+15M+35M+25M)"
echo "Link capacity: 100 Mbps"
echo "OVERSATURATION: 105% - This will FORCE VIDEO to reroute!"
echo ""
echo "Duration: 120 seconds"
echo ""
echo "Monitor results:"
echo "  tail -f data/fplf_monitoring/link_utilization.csv"
echo "  tail -f data/fplf_monitoring/fplf_routes.csv"
echo ""
echo "Check for route changes after 30 seconds:"
echo "  grep VIDEO data/fplf_monitoring/fplf_routes.csv | grep YES"
echo "  grep FTP data/fplf_monitoring/fplf_routes.csv | tail -5"
echo ""
echo "Expected with 105% link saturation:"
echo "  ✓ Link utilization > 50% on s2-s1 link"
echo "  ✓ route_changed=YES for VIDEO traffic (priority=4, avoids congestion)"
echo "  ✓ route_changed=NO for FTP traffic (priority=1, tolerates congestion)"
echo "  ✓ VIDEO should reroute BEFORE SSH (highest priority avoids first)"
echo ""
echo "================================================================"

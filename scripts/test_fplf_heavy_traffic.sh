#!/bin/bash
#
# FPLF Test with HEAVY Traffic to Force Route Changes
# This generates high-volume traffic to create link congestion
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=============================================="
echo "  FPLF Heavy Traffic Test"
echo "  Goal: Create congestion to see route_changed=YES"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo"
    exit 1
fi

# Get actual user for conda
ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

# Initialize conda
if [ -f "$USER_HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$USER_HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found"
    exit 1
fi

conda activate ml-sdn
cd "$PROJECT_ROOT"

# Clean old data
rm -f data/fplf_monitoring/*.csv

echo "Starting FPLF controller..."
ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py \
    > data/fplf_monitoring/controller.log 2>&1 &
CONTROLLER_PID=$!
echo "Controller PID: $CONTROLLER_PID"
sleep 8

echo ""
echo "Starting mesh topology..."
echo ""

# Start topology in background
/usr/bin/python3 << 'PYTHON_SCRIPT' &
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.link import TCLink
from mininet.log import setLogLevel, info
import time

setLogLevel('info')

# Import mesh topology
import sys
sys.path.insert(0, '/home/hello/Desktop/ML_SDN')
from topology.fplf_topo import MeshTopology

# Create network
topo = MeshTopology(num_switches=3, hosts_per_switch=3)
net = Mininet(
    topo=topo,
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch,
    link=TCLink,
    autoSetMacs=True,
    autoStaticArp=True
)

info('*** Starting network\n')
net.start()
time.sleep(5)

info('*** Generating HEAVY traffic to congest links\n')
hosts = net.hosts

# HEAVY VIDEO traffic (large files, continuous streams)
info('Starting VIDEO servers on h7, h8...\n')
hosts[6].cmd('dd if=/dev/zero of=/tmp/bigvideo bs=1M count=100 2>/dev/null')  # 100MB
hosts[7].cmd('dd if=/dev/zero of=/tmp/bigvideo2 bs=1M count=100 2>/dev/null')
hosts[6].cmd('while true; do nc -l -p 1935 < /tmp/bigvideo; done &')
hosts[7].cmd('while true; do nc -l -p 1935 < /tmp/bigvideo2; done &')
time.sleep(2)

info('Starting VIDEO clients (HEAVY bandwidth)...\n')
# Multiple concurrent streams from h1, h2, h3 to h7, h8
hosts[0].cmd('while true; do nc 10.0.0.7 1935 > /dev/null 2>&1; done &')  # h1 -> h7
hosts[0].cmd('while true; do nc 10.0.0.8 1935 > /dev/null 2>&1; done &')  # h1 -> h8
hosts[1].cmd('while true; do nc 10.0.0.7 1935 > /dev/null 2>&1; done &')  # h2 -> h7
hosts[1].cmd('while true; do nc 10.0.0.8 1935 > /dev/null 2>&1; done &')  # h2 -> h8
hosts[2].cmd('while true; do nc 10.0.0.7 1935 > /dev/null 2>&1; done &')  # h3 -> h7

# SSH traffic
info('Starting SSH traffic...\n')
hosts[7].cmd('dd if=/dev/zero of=/tmp/sshdata bs=1M count=50 2>/dev/null')
hosts[8].cmd('dd if=/dev/zero of=/tmp/sshdata2 bs=1M count=50 2>/dev/null')
hosts[7].cmd('while true; do nc -l -p 22 < /tmp/sshdata; done &')
hosts[8].cmd('while true; do nc -l -p 22 < /tmp/sshdata2; done &')
time.sleep(1)
hosts[2].cmd('while true; do nc 10.0.0.8 22 > /dev/null 2>&1; done &')  # h3 -> h8
hosts[3].cmd('while true; do nc 10.0.0.9 22 > /dev/null 2>&1; done &')  # h4 -> h9

# HTTP traffic
info('Starting HTTP servers...\n')
hosts[6].cmd('python3 -m http.server 8000 &')
hosts[4].cmd('python3 -m http.server 8001 &')
time.sleep(2)
hosts[5].cmd('while true; do wget -q -O /dev/null http://10.0.0.7:8000/ 2>&1; done &')
hosts[0].cmd('while true; do wget -q -O /dev/null http://10.0.0.5:8001/ 2>&1; done &')

# FTP traffic
info('Starting FTP traffic...\n')
hosts[8].cmd('dd if=/dev/zero of=/tmp/ftpfile bs=1M count=50 2>/dev/null')
hosts[8].cmd('while true; do nc -l -p 21 < /tmp/ftpfile; done &')
time.sleep(1)
hosts[1].cmd('while true; do nc 10.0.0.9 21 > /dev/null 2>&1; done &')

info('*** HEAVY traffic generation complete!\n')
info('*** Running for 60 seconds...\n')
time.sleep(60)

info('*** Stopping network\n')
net.stop()
PYTHON_SCRIPT

TOPO_PID=$!
echo "Topology PID: $TOPO_PID"

# Wait for test to complete
sleep 70

echo ""
echo "=============================================="
echo "  Test Complete!"
echo "=============================================="
echo ""

# Kill controller
kill $CONTROLLER_PID 2>/dev/null

# Cleanup
mn -c 2>/dev/null

echo "Results:"
echo ""
echo "Total routes logged:"
wc -l data/fplf_monitoring/fplf_routes.csv

echo ""
echo "Route changes (route_changed=YES):"
grep "YES" data/fplf_monitoring/fplf_routes.csv | wc -l

echo ""
echo "Sample route changes:"
grep "YES" data/fplf_monitoring/fplf_routes.csv | head -5 || echo "No route changes found"

echo ""
echo "Link utilization summary:"
tail -20 data/fplf_monitoring/link_utilization.csv

echo ""

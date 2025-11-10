#!/bin/bash
# Clean 4-switch FPLF test - ensures no stale processes

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "Clean 4-Switch FPLF Test"
echo "========================================="
echo ""

# Aggressive cleanup
echo "Cleaning up any existing processes..."
sudo mn -c 2>/dev/null
sudo pkill -9 -f ryu-manager 2>/dev/null
sudo pkill -9 -f ovs 2>/dev/null
sleep 3

# Verify nothing is running
if pgrep -f ryu-manager > /dev/null; then
    echo "ERROR: Ryu controller still running!"
    exit 1
fi

# Start fresh controller
echo "Starting controller..."
ryu-manager src/controller/fplf_controller.py > /tmp/fplf_clean_test.log 2>&1 &
RYU_PID=$!
echo "Controller PID: $RYU_PID"
sleep 5

if ! ps -p $RYU_PID > /dev/null; then
    echo "ERROR: Controller failed to start!"
    cat /tmp/fplf_clean_test.log
    exit 1
fi

echo "Controller running successfully"
echo ""

# Run simple 2-switch test first to verify controller works
echo "========================================="
echo "Step 1: Testing with 2 switches"
echo "========================================="
sudo python3 <<'EOF'
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.log import setLogLevel
import time

setLogLevel('info')

net = Mininet(
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch
)

c0 = net.addController('c0')
s1 = net.addSwitch('s1', protocols='OpenFlow13')
s2 = net.addSwitch('s2', protocols='OpenFlow13')

h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')

net.addLink(h1, s1)
net.addLink(h2, s2)
net.addLink(s1, s2)

net.start()

print('Waiting for topology setup...')
time.sleep(5)

print('\nTesting h1 -> h2:')
result = h1.cmd('ping -c 3 10.0.0.2')
print(result)

time.sleep(1)
net.stop()
EOF

echo ""
echo "Waiting 2 seconds before restarting controller..."
sleep 2

# RESTART CONTROLLER to clear all state
echo "Restarting controller for 4-switch test..."
kill $RYU_PID 2>/dev/null
wait $RYU_PID 2>/dev/null
sleep 2

ryu-manager src/controller/fplf_controller.py >> /tmp/fplf_clean_test.log 2>&1 &
RYU_PID=$!
sleep 3

if ! ps -p $RYU_PID > /dev/null; then
    echo "ERROR: Controller failed to restart!"
    exit 1
fi

echo "Controller restarted (PID: $RYU_PID)"
echo ""

# Now test 4-switch topology
echo ""
echo "========================================="
echo "Step 2: Testing with 4 switches"
echo "========================================="
sudo python3 scripts/fplf_demo_topology.py

# Stop controller
sleep 2
kill $RYU_PID 2>/dev/null
wait $RYU_PID 2>/dev/null

echo ""
echo "========================================="
echo "Controller Log Analysis"
echo "========================================="

echo "Switches connected:"
grep "Switch.*connected" /tmp/fplf_clean_test.log

echo ""
echo "Topology builds:"
grep "Manual topology" /tmp/fplf_clean_test.log

echo ""
echo "Routes computed:"
grep -c "FPLF ROUTE" /tmp/fplf_clean_test.log || echo "0"

echo ""
echo "Sample routes:"
grep -A 2 "FPLF ROUTE" /tmp/fplf_clean_test.log | head -12

echo ""
echo "Full log: /tmp/fplf_clean_test.log"

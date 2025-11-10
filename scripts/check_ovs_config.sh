#!/bin/bash
# Check OVS configuration while Mininet is running

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "OVS Configuration Check"
echo "========================================="

# Clean
sudo mn -c 2>/dev/null
sudo pkill -f ryu-manager 2>/dev/null
sleep 1

# Start controller
echo "Starting controller..."
ryu-manager src/controller/fplf_controller.py > /tmp/ovs_check.log 2>&1 &
RYU_PID=$!
sleep 3

# Start Mininet in background
sudo python3 <<'EOF' &
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.log import setLogLevel
import time

setLogLevel('info')

net = Mininet(
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch,
    autoSetMacs=True
)

c0 = net.addController('c0')
s1 = net.addSwitch('s1', protocols='OpenFlow13', failMode='secure')
s2 = net.addSwitch('s2', protocols='OpenFlow13', failMode='secure')

h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')

net.addLink(h1, s1)
net.addLink(h2, s2)
net.addLink(s1, s2)

net.start()
print("\n*** Network started, waiting 60 seconds for inspection...")
time.sleep(60)
net.stop()
EOF

MININET_PID=$!
sleep 8

echo ""
echo "Checking OVS configuration:"
echo "-------------------------------------------"

sudo ovs-vsctl show

echo ""
echo "-------------------------------------------"
echo "Checking s1 flows:"
sudo ovs-ofctl -O OpenFlow13 dump-flows s1

echo ""
echo "-------------------------------------------"
echo "Checking s2 flows:"
sudo ovs-ofctl -O OpenFlow13 dump-flows s2

echo ""
echo "-------------------------------------------"
echo "Checking s1 fail mode:"
sudo ovs-vsctl get-fail-mode s1

echo ""
echo "Checking s2 fail mode:"
sudo ovs-vsctl get-fail-mode s2

echo ""
echo "========================================="
echo "Stopping..."
sudo pkill -f "python3"
kill $RYU_PID 2>/dev/null
sleep 2
sudo mn -c 2>/dev/null

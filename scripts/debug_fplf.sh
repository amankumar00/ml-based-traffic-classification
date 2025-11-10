#!/bin/bash
# Debug script for FPLF - checks OpenFlow flows and connectivity

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "FPLF Debug Test"
echo "========================================="

# Clean
sudo mn -c 2>/dev/null
sudo pkill -f ryu-manager 2>/dev/null
sleep 1

# Start controller
echo "Starting controller..."
ryu-manager src/controller/fplf_controller.py > /tmp/fplf_debug.log 2>&1 &
RYU_PID=$!
sleep 3

if ! ps -p $RYU_PID > /dev/null; then
    echo "Controller failed!"
    cat /tmp/fplf_debug.log
    exit 1
fi

echo "Controller running (PID: $RYU_PID)"
echo ""

# Run test in background so we can check flows while it's running
echo "Starting Mininet (in background)..."
sudo python3 -c "
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

print('\\n=== Waiting 5 seconds for controller ===')
time.sleep(5)

print('\\n=== Checking OpenFlow flows on s1 ===')
import subprocess
subprocess.call(['ovs-ofctl', '-O', 'OpenFlow13', 'dump-flows', 's1'])

print('\\n=== Checking OpenFlow flows on s2 ===')
subprocess.call(['ovs-ofctl', '-O', 'OpenFlow13', 'dump-flows', 's2'])

print('\\n=== Checking h1 interface ===')
h1_result = h1.cmd('ip addr show h1-eth0')
print(h1_result)

print('\\n=== Checking h2 interface ===')
h2_result = h2.cmd('ip addr show h2-eth0')
print(h2_result)

print('\\n=== Testing ping h1 -> h2 ===')
result = h1.cmd('ping -c 3 10.0.0.2')
print(result)

print('\\n=== Waiting 2 seconds ===')
time.sleep(2)

print('\\n=== Final OpenFlow flows on s1 ===')
subprocess.call(['ovs-ofctl', '-O', 'OpenFlow13', 'dump-flows', 's1'])

print('\\n=== Final OpenFlow flows on s2 ===')
subprocess.call(['ovs-ofctl', '-O', 'OpenFlow13', 'dump-flows', 's2'])

net.stop()
" &

MININET_PID=$!

# Wait for Mininet to finish
wait $MININET_PID

# Stop controller
sleep 1
kill $RYU_PID 2>/dev/null

echo ""
echo "========================================="
echo "Controller Log"
echo "========================================="
cat /tmp/fplf_debug.log

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo "ARP packets: $(grep -c 'ARP' /tmp/fplf_debug.log || echo 0)"
echo "IPv4 packets logged: $(grep 'IPv4' /tmp/fplf_debug.log | wc -l)"
echo "Routes computed: $(grep -c 'FPLF ROUTE' /tmp/fplf_debug.log || echo 0)"

#!/bin/bash
# Simple FPLF test with minimal topology

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "Simple FPLF Test"
echo "========================================="
echo ""

# Clean
sudo mn -c 2>/dev/null
sudo pkill -f ryu-manager 2>/dev/null
sleep 1

# Start controller
echo "Starting controller..."
ryu-manager src/controller/fplf_controller.py > /tmp/fplf_simple_test.log 2>&1 &
RYU_PID=$!
sleep 3

if ! ps -p $RYU_PID > /dev/null; then
    echo "Controller failed!"
    cat /tmp/fplf_simple_test.log
    exit 1
fi

echo "Controller running (PID: $RYU_PID)"
echo ""

# Run Mininet
echo "Starting Mininet with 2-switch topology..."
sudo -E python3 << 'ENDPYTHON'
from mininet.net import Mininet
from mininet.node import RemoteController
from mininet.log import setLogLevel
import time

setLogLevel('info')

net = Mininet(controller=lambda n: RemoteController(n, ip='127.0.0.1', port=6653))

c0 = net.addController('c0')
s1 = net.addSwitch('s1', protocols='OpenFlow13')
s2 = net.addSwitch('s2', protocols='OpenFlow13')

h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')
h3 = net.addHost('h3', ip='10.0.0.3/24')

net.addLink(h1, s1)
net.addLink(h2, s1)
net.addLink(h3, s2)
net.addLink(s1, s2)

net.start()
time.sleep(3)

print("\n*** Testing connectivity...")
print("h1 -> h3:")
h1.cmd('ping -c 3 10.0.0.3')

time.sleep(1)
net.stop()
ENDPYTHON

sleep 2
kill $RYU_PID 2>/dev/null

echo ""
echo "========================================="
echo "Controller Log:"
echo "========================================="
cat /tmp/fplf_simple_test.log

echo ""
echo "========================================="
echo "Packet Count:"
grep "Packet #" /tmp/fplf_simple_test.log | wc -l
echo "Routes:"
grep "FPLF ROUTE" /tmp/fplf_simple_test.log | wc -l

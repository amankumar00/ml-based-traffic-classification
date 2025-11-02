#!/bin/bash
# Very simple traffic test to isolate the issue

echo "========================================="
echo "Simple Traffic Test"
echo "========================================="

cd /home/hello/Desktop/ML_SDN

echo "This will run a MINIMAL test:"
echo "  - Linear topology (2 switches, 2 hosts)"
echo "  - Only ICMP (ping)"
echo "  - 45 seconds"
echo ""
echo "Make sure controller is running in another terminal first!"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "WARNING: Make sure you ran 'sudo mn -c' BEFORE starting the controller!"
echo ""
echo "Starting minimal test..."
echo ""

sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 -c "
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
import time

setLogLevel('info')

info('*** Creating minimal network\n')
net = Mininet(
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch
)

info('*** Adding controller\n')
c0 = net.addController('c0')

info('*** Adding hosts and switches\n')
h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')
s1 = net.addSwitch('s1', protocols='OpenFlow13')

info('*** Creating links\n')
net.addLink(h1, s1)
net.addLink(h2, s1)

info('*** Starting network\n')
net.start()

info('*** Waiting for controller connection...\n')
time.sleep(3)

info('*** Starting ping test\n')
print('h1 -> h2 ping')
h1.cmd('ping -c 10 10.0.0.2 &')

info('*** Running for 45 seconds...\n')
time.sleep(45)

info('*** Stopping network\n')
net.stop()

info('*** Done!\n')
"

echo ""
echo "Test complete!"
echo ""
echo "Check controller terminal for:"
echo "  - 'Switch connected' message"
echo "  - 'Saved X packets' after 30 seconds"

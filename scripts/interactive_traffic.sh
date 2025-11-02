#!/bin/bash
# Interactive traffic generation - verify each step works

echo "========================================="
echo "Interactive Traffic Generator"
echo "========================================="
echo ""
echo "This will:"
echo "1. Start Mininet CLI"
echo "2. You manually test each traffic type"
echo "3. Verify controller captures it"
echo ""

cd /home/hello/Desktop/ML_SDN

echo "Make sure controller is running in Terminal 1!"
read -p "Press Enter to start Mininet CLI..."

sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 << 'ENDPYTHON'
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
import time

setLogLevel('info')

info('*** Creating network with 6 hosts\n')
net = Mininet(
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch
)

c0 = net.addController('c0')
s1 = net.addSwitch('s1', protocols='OpenFlow13')

h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')
h3 = net.addHost('h3', ip='10.0.0.3/24')
h4 = net.addHost('h4', ip='10.0.0.4/24')
h5 = net.addHost('h5', ip='10.0.0.5/24')
h6 = net.addHost('h6', ip='10.0.0.6/24')

net.addLink(h1, s1)
net.addLink(h2, s1)
net.addLink(h3, s1)
net.addLink(h4, s1)
net.addLink(h5, s1)
net.addLink(h6, s1)

info('*** Starting network\n')
net.start()
time.sleep(3)

info('*** Testing connectivity\n')
net.pingAll()

info('\n=====================================\n')
info('MANUAL TRAFFIC GENERATION GUIDE\n')
info('=====================================\n\n')

info('Generate 2 HTTP flows:\n')
info('  mininet> h1 python3 -m http.server 80 &\n')
info('  mininet> h2 python3 -m http.server 8080 &\n')
info('  mininet> h3 wget -O /dev/null http://10.0.0.1:80/\n')
info('  mininet> h4 wget -O /dev/null http://10.0.0.2:8080/\n\n')

info('Generate 2 FTP flows (port 21):\n')
info('  mininet> h1 nc -l -p 21 &\n')
info('  mininet> h2 nc -l -p 21 &\n')
info('  mininet> h5 echo "USER test" | nc 10.0.0.1 21\n')
info('  mininet> h6 echo "USER test" | nc 10.0.0.2 21\n\n')

info('Generate 2 SSH flows (port 22):\n')
info('  mininet> h1 nc -l -p 22 &\n')
info('  mininet> h2 nc -l -p 2222 &\n')
info('  mininet> h3 echo "SSH" | nc 10.0.0.1 22\n')
info('  mininet> h4 echo "SSH" | nc 10.0.0.2 2222\n\n')

info('Generate 2 ICMP flows:\n')
info('  mininet> h1 ping -c 10 10.0.0.2 &\n')
info('  mininet> h3 ping -c 10 10.0.0.4 &\n\n')

info('Generate 2 UDP flows (VIDEO ports):\n')
info('  mininet> h1 nc -u -l -p 5004 &\n')
info('  mininet> h2 nc -u -l -p 5006 &\n')
info('  mininet> h5 echo "VIDEO" | nc -u 10.0.0.1 5004\n')
info('  mininet> h6 echo "VIDEO" | nc -u 10.0.0.2 5006\n\n')

info('After generating traffic:\n')
info('  mininet> exit\n\n')

info('=====================================\n\n')

CLI(net)

info('*** Stopping network\n')
net.stop()
ENDPYTHON

echo ""
echo "Now check captured packets and classify"

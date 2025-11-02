#!/bin/bash
# Final test using iperf - the most reliable tool for Mininet

echo "========================================="
echo "Final Reliable Test - Using iPerf"
echo "========================================="
echo ""
echo "This uses iperf which is designed for Mininet"
echo "Should generate real TCP and UDP traffic"
echo ""

cd /home/hello/Desktop/ML_SDN

read -p "Press Enter to start..."

sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 << 'ENDPYTHON'
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.log import setLogLevel, info
import time

setLogLevel('info')

info('*** Creating network\n')
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

net.addLink(h1, s1)
net.addLink(h2, s1)
net.addLink(h3, s1)
net.addLink(h4, s1)

info('*** Starting network\n')
net.start()
time.sleep(3)

info('*** Testing connectivity\n')
net.pingAll()

info('\n*** Starting iperf traffic for 60 seconds\n')
info('  TCP traffic: h1->h2 (port 5001)\n')
info('  TCP traffic: h3->h4 (port 5002)\n')
info('  UDP traffic: h1->h3 (port 5003)\n')
info('  ICMP: ping h1->h4\n\n')

# Start iperf TCP servers
h2.cmd('iperf -s -p 5001 > /dev/null 2>&1 &')
h4.cmd('iperf -s -p 5002 > /dev/null 2>&1 &')
time.sleep(2)

# Start iperf UDP server
h3.cmd('iperf -s -u -p 5003 > /dev/null 2>&1 &')
time.sleep(2)

# Start iperf TCP clients (continuous for 60 seconds)
h1.cmd('iperf -c 10.0.0.2 -p 5001 -t 60 > /dev/null 2>&1 &')
h3.cmd('iperf -c 10.0.0.4 -p 5002 -t 60 > /dev/null 2>&1 &')

# Start iperf UDP client
h1.cmd('iperf -c 10.0.0.3 -u -p 5003 -t 60 -b 10M > /dev/null 2>&1 &')

# Start ping
h1.cmd('ping -i 1 10.0.0.4 > /dev/null 2>&1 &')

info('*** Traffic running for 60 seconds...\n')
for i in range(60):
    time.sleep(1)
    if (i+1) % 15 == 0:
        info(f'... {i+1} seconds\n')

info('\n*** Stopping network\n')
net.stop()
ENDPYTHON

echo ""
echo "========================================="
echo "Checking captured packets..."
echo "========================================="
sleep 2

python3 -c "
import json, glob, os

files = sorted(glob.glob('data/raw/captured_packets_*.json'), key=os.path.getmtime, reverse=True)[:3]

all_packets = []
for f in files:
    with open(f) as fp:
        all_packets.extend(json.load(fp))

protocols = {}
tcp_ports = set()
udp_ports = set()

for p in all_packets:
    proto = p.get('protocol', 'UNKNOWN')
    protocols[proto] = protocols.get(proto, 0) + 1

    if proto == 'TCP':
        tcp_ports.add(p.get('dst_port'))
    elif proto == 'UDP':
        udp_ports.add(p.get('dst_port'))

print(f'Total packets: {len(all_packets)}')
print('\nProtocols:')
for proto, count in sorted(protocols.items()):
    print(f'  {proto}: {count} packets')

if tcp_ports:
    print(f'\nTCP ports: {sorted(tcp_ports)}')
if udp_ports:
    print(f'UDP ports: {sorted(udp_ports)}')

tcp_count = protocols.get('TCP', 0)
if tcp_count > 10:
    print(f'\n✓ SUCCESS! {tcp_count} TCP packets captured!')
    print('Now run:')
    print('  python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv')
    print('  python src/ml_models/classifier.py data/models/ data/processed/features.csv')
else:
    print(f'\n✗ Only {tcp_count} TCP packets captured')
    print('Traffic generation still not working reliably')
"

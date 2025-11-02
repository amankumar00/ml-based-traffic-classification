#!/bin/bash
# Uses EXACTLY the approach that worked in diagnostic test
# But generates more diverse traffic types

echo "========================================="
echo "Proven Working Traffic Generator"
echo "========================================="
echo "Uses the EXACT method that worked in diagnostic"
echo "Running for 90 seconds to ensure capture"
echo ""

cd /home/hello/Desktop/ML_SDN

read -p "Press Enter to start..."

sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 << 'ENDPYTHON'
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
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

info('\n*** Setting up servers (PROVEN METHOD)\n')

# HTTP servers - this WORKED in diagnostic
info('  HTTP: ports 80, 8080, 8888\n')
h1.cmd('cd /tmp && python3 -m http.server 80 > /dev/null 2>&1 &')
h2.cmd('cd /tmp && python3 -m http.server 8080 > /dev/null 2>&1 &')
h3.cmd('cd /tmp && python3 -m http.server 8888 > /dev/null 2>&1 &')
time.sleep(3)

# Verify servers are running
info('  Verifying servers...\n')
result1 = h1.cmd('netstat -tuln | grep ":80 "')
result2 = h2.cmd('netstat -tuln | grep ":8080 "')
result3 = h3.cmd('netstat -tuln | grep ":8888 "')

if ':80' in result1:
    info('    ✓ HTTP server on h1:80\n')
if ':8080' in result2:
    info('    ✓ HTTP server on h2:8080\n')
if ':8888' in result3:
    info('    ✓ HTTP server on h3:8888\n')

info('\n*** Generating traffic for 90 seconds\n')
info('  Make NEW connections every 3 seconds\n')
info('  This ensures controller sees each connection\n\n')

# Start continuous traffic in background
info('  Starting HTTP traffic generators...\n')

# HTTP traffic - make NEW connections repeatedly
h4.cmd('bash -c "for i in {1..30}; do wget -q -O /dev/null http://10.0.0.1:80/ 2>/dev/null; sleep 3; done" > /dev/null 2>&1 &')
h5.cmd('bash -c "for i in {1..30}; do wget -q -O /dev/null http://10.0.0.2:8080/ 2>/dev/null; sleep 3; done" > /dev/null 2>&1 &')
h6.cmd('bash -c "for i in {1..30}; do wget -q -O /dev/null http://10.0.0.3:8888/ 2>/dev/null; sleep 3; done" > /dev/null 2>&1 &')

# ICMP traffic
info('  Starting ICMP traffic...\n')
h1.cmd('ping -i 2 10.0.0.4 > /dev/null 2>&1 &')
h2.cmd('ping -i 2 10.0.0.5 > /dev/null 2>&1 &')

# Give it 5 seconds, then test one connection manually to verify
time.sleep(5)
info('\n  Testing one HTTP connection manually...\n')
result = h4.cmd('wget -O /dev/null http://10.0.0.1:80/ 2>&1')
if 'saved' in result.lower() or '200 ok' in result.lower():
    info('  ✓ Manual HTTP test successful!\n')
else:
    info('  ✗ Manual HTTP test failed\n')
    info(f'    Output: {result[:200]}\n')

info('\n*** Traffic running for 90 seconds total...\n')
info('    Controller should save packets at 30s and 60s\n')
info('    Watch Terminal 1 for "Saved X packets" messages\n\n')

for i in range(85):  # Already waited 5
    time.sleep(1)
    if (i+1) % 15 == 0:
        info(f'... {i+6} seconds total\n')

info('\n*** Stopping network\n')
net.stop()

info('\n*** Traffic generation complete!\n')
ENDPYTHON

echo ""
echo "========================================="
echo "Analyzing Results..."
echo "========================================="
sleep 2

python3 << 'ENDPYTHON'
import json, glob, os

files = sorted(glob.glob('data/raw/captured_packets_*.json'), key=os.path.getmtime, reverse=True)[:3]

if not files:
    print('ERROR: No captured files found!')
    print('Controller may not be running or packets not saved yet')
    exit(1)

all_packets = []
for f in files:
    with open(f) as fp:
        all_packets.extend(json.load(fp))

protocols = {}
tcp_by_port = {}

for p in all_packets:
    proto = p.get('protocol', 'UNKNOWN')
    protocols[proto] = protocols.get(proto, 0) + 1

    if proto == 'TCP':
        port = p.get('dst_port', 0)
        tcp_by_port[port] = tcp_by_port.get(port, 0) + 1

print(f'Total packets captured: {len(all_packets)}')
print('\nProtocol breakdown:')
for proto, count in sorted(protocols.items()):
    print(f'  {proto}: {count} packets')

tcp_count = protocols.get('TCP', 0)
print(f'\nTCP packets: {tcp_count}')

if tcp_count > 0:
    print('\nTCP by destination port:')
    for port, count in sorted(tcp_by_port.items(), key=lambda x: -x[1]):
        print(f'  Port {port}: {count} packets')

    if tcp_count >= 10:
        print('\n✓ SUCCESS! TCP traffic captured!')
        print('\nNow run classification:')
        print('  python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv')
        print('  python src/ml_models/classifier.py data/models/ data/processed/features.csv')
    else:
        print(f'\n⚠ Only {tcp_count} TCP packets - may need more traffic')
else:
    print('\n✗ NO TCP PACKETS CAPTURED')
    print('\nPossible issues:')
    print('  1. Flow rules are still being installed (check controller code)')
    print('  2. Packets timing out before save (wait longer)')
    print('  3. Controller not receiving PacketIn events')
ENDPYTHON

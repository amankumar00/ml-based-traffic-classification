#!/bin/bash
# Generate exactly 10 flows: 2 HTTP, 2 FTP, 2 SSH, 2 ICMP, 2 VIDEO (UDP streaming)

echo "========================================="
echo "Generate 10 Diverse Flows"
echo "========================================="
echo "Target: 2 flows of each type"
echo "  - 2 HTTP (ports 80, 8080)"
echo "  - 2 FTP (port 21)"
echo "  - 2 SSH (port 22)"
echo "  - 2 ICMP (ping)"
echo "  - 2 VIDEO (UDP ports 5004, 5006)"
echo ""
echo "Duration: 90 seconds"
echo "========================================="
echo ""

cd /home/hello/Desktop/ML_SDN

echo "Make sure controller is running!"
read -p "Press Enter to start..."

echo ""
echo "Starting traffic generation..."
echo ""

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
s2 = net.addSwitch('s2', protocols='OpenFlow13')

# Create 6 hosts
h1 = net.addHost('h1', ip='10.0.1.1/24')
h2 = net.addHost('h2', ip='10.0.1.2/24')
h3 = net.addHost('h3', ip='10.0.2.1/24')
h4 = net.addHost('h4', ip='10.0.2.2/24')
h5 = net.addHost('h5', ip='10.0.2.3/24')
h6 = net.addHost('h6', ip='10.0.2.4/24')

# Connect hosts to switches
net.addLink(h1, s1)
net.addLink(h2, s1)
net.addLink(h3, s2)
net.addLink(h4, s2)
net.addLink(h5, s2)
net.addLink(h6, s2)
net.addLink(s1, s2)

info('*** Starting network\n')
net.start()
time.sleep(3)

info('*** Setting up servers\n')

# HTTP servers (2 different ports)
info('  HTTP servers on h1 (port 80) and h2 (port 8080)\n')
h1.cmd('cd /tmp && python3 -m http.server 80 > /dev/null 2>&1 &')
h2.cmd('cd /tmp && python3 -m http.server 8080 > /dev/null 2>&1 &')
time.sleep(2)

# FTP-like servers (port 21) - use netcat
info('  FTP servers on h1 (port 21) and h2 (port 21)\n')
h1.cmd('while true; do echo "FTP response from h1" | nc -l -p 21 -q 1 2>/dev/null; done > /dev/null 2>&1 &')
h2.cmd('while true; do echo "FTP response from h2" | nc -l -p 21 -q 1 2>/dev/null; done > /dev/null 2>&1 &')
time.sleep(2)

# SSH-like servers (port 22)
info('  SSH servers on h1 (port 22) and h2 (port 2222)\n')
h1.cmd('while true; do echo "SSH response from h1" | nc -l -p 22 -q 1 2>/dev/null; done > /dev/null 2>&1 &')
h2.cmd('while true; do echo "SSH response from h2" | nc -l -p 2222 -q 1 2>/dev/null; done > /dev/null 2>&1 &')
time.sleep(2)

# VIDEO-like UDP servers (streaming ports)
info('  VIDEO UDP servers on h1 (port 5004) and h2 (port 5006)\n')
h1.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('0.0.0.0', 5004))
while True: s.recvfrom(1024)
" > /dev/null 2>&1 &''')

h2.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('0.0.0.0', 5006))
while True: s.recvfrom(1024)
" > /dev/null 2>&1 &''')
time.sleep(2)

info('\n*** Generating traffic for 90 seconds\n')
info('    Creating NEW connections every 5 seconds to ensure controller sees them\n\n')

# Generate traffic with NEW connections each time (so controller sees them)

# Flow 1-2: HTTP traffic (2 flows)
info('  Starting HTTP traffic (h3->h1:80, h4->h2:8080)\n')
h3.cmd('(for i in {1..18}; do wget -q -O /dev/null http://10.0.1.1:80/ 2>/dev/null; sleep 5; done) > /dev/null 2>&1 &')
h4.cmd('(for i in {1..18}; do wget -q -O /dev/null http://10.0.1.2:8080/ 2>/dev/null; sleep 5; done) > /dev/null 2>&1 &')

# Flow 3-4: FTP traffic (2 flows)
info('  Starting FTP traffic (h3->h1:21, h4->h2:21)\n')
h3.cmd('(for i in {1..18}; do echo "USER test" | nc 10.0.1.1 21 -w 1 2>/dev/null; sleep 5; done) > /dev/null 2>&1 &')
h4.cmd('(for i in {1..18}; do echo "USER test" | nc 10.0.1.2 21 -w 1 2>/dev/null; sleep 5; done) > /dev/null 2>&1 &')

# Flow 5-6: SSH traffic (2 flows)
info('  Starting SSH traffic (h5->h1:22, h6->h2:2222)\n')
h5.cmd('(for i in {1..18}; do echo "SSH-2.0-Test" | nc 10.0.1.1 22 -w 1 2>/dev/null; sleep 5; done) > /dev/null 2>&1 &')
h6.cmd('(for i in {1..18}; do echo "SSH-2.0-Test" | nc 10.0.1.2 2222 -w 1 2>/dev/null; sleep 5; done) > /dev/null 2>&1 &')

# Flow 7-8: ICMP traffic (2 flows)
info('  Starting ICMP traffic (h3->h1, h4->h2)\n')
h3.cmd('ping -i 2 10.0.1.1 > /dev/null 2>&1 &')
h4.cmd('ping -i 2 10.0.1.2 > /dev/null 2>&1 &')

# Flow 9-10: VIDEO UDP streaming (2 flows)
info('  Starting VIDEO UDP traffic (h5->h1:5004, h6->h2:5006)\n')
h5.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
while True:
    s.sendto(b'VIDEO_STREAM_DATA' * 100, ('10.0.1.1', 5004))
    time.sleep(0.1)
" > /dev/null 2>&1 &''')

h6.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
while True:
    s.sendto(b'VIDEO_STREAM_DATA' * 100, ('10.0.1.2', 5006))
    time.sleep(0.1)
" > /dev/null 2>&1 &''')

info('\n*** Traffic running for 90 seconds...\n')
info('    Watch controller Terminal for "Saved X packets" messages\n')
info('    Expected: 2 saves at 30s and 60s\n\n')

for i in range(90):
    time.sleep(1)
    if (i+1) % 15 == 0:
        info(f'... {i+1} seconds elapsed\n')

info('\n*** Stopping network\n')
net.stop()

info('\n*** Traffic generation complete!\n')
ENDPYTHON

echo ""
echo "========================================="
echo "Traffic Generation Complete!"
echo "========================================="
echo ""
echo "Now analyzing captured traffic..."
echo ""

# Wait a moment for last save
sleep 2

# Analyze
python3 -c "
import json, glob, os

files = sorted(glob.glob('data/raw/captured_packets_*.json'), key=os.path.getmtime, reverse=True)

if files:
    print('Checking captured traffic:')
    all_packets = []
    for f in files[:3]:  # Check last 3 files
        with open(f) as fp:
            data = json.load(fp)
            all_packets.extend(data)

    # Count protocols
    protocols = {}
    ports = {}

    for p in all_packets:
        proto = p.get('protocol', 'UNKNOWN')
        protocols[proto] = protocols.get(proto, 0) + 1

        if proto == 'TCP':
            port = f\"{p.get('src_port')}->{p.get('dst_port')}\"
            ports[port] = ports.get(port, 0) + 1
        elif proto == 'UDP':
            port = f\"{p.get('src_port')}->{p.get('dst_port')}\"
            ports[port] = ports.get(port, 0) + 1

    print(f'\nTotal packets: {len(all_packets)}')
    print('\nProtocol breakdown:')
    for proto, count in sorted(protocols.items()):
        print(f'  {proto}: {count} packets')

    if ports:
        print('\nTCP/UDP ports seen:')
        for port, count in sorted(ports.items(), key=lambda x: -x[1])[:15]:
            print(f'  {port}: {count} packets')
else:
    print('No packets captured yet!')
"

echo ""
echo "Now run ML classification:"
echo "  python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv"
echo "  python src/ml_models/classifier.py data/models/ data/processed/features.csv"

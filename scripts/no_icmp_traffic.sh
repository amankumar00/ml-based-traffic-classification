#!/bin/bash
# Generate ONLY TCP and UDP traffic - NO ICMP!
# This way we get clean HTTP, FTP, SSH, VIDEO classifications

echo "========================================="
echo "TCP/UDP Only Traffic Generator"
echo "========================================="
echo "NO ICMP - Only application traffic!"
echo ""
echo "Target flows:"
echo "  - 2 HTTP flows (ports 80, 8080)"
echo "  - 2 FTP flows (port 21)"
echo "  - 2 SSH flows (port 22, 2222)"
echo "  - 2 VIDEO flows (UDP ports 5004, 5006)"
echo ""
echo "Duration: 90 seconds"
echo "========================================="
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

info('*** NO PING TEST - skipping connectivity test\n')
info('*** Starting servers\n')

# HTTP servers (ports 80, 8080)
info('  HTTP servers: h1:80, h2:8080\n')
h1.cmd('cd /tmp && python3 -m http.server 80 > /dev/null 2>&1 &')
h2.cmd('cd /tmp && python3 -m http.server 8080 > /dev/null 2>&1 &')
time.sleep(3)

# FTP-like servers (port 21) - using netcat
info('  FTP servers: h1:21, h2:21\n')
h1.cmd('while true; do echo "220 FTP Server h1" | nc -l -p 21 -q 1 2>/dev/null; sleep 0.1; done > /dev/null 2>&1 &')
h2.cmd('while true; do echo "220 FTP Server h2" | nc -l -p 21 -q 1 2>/dev/null; sleep 0.1; done > /dev/null 2>&1 &')
time.sleep(2)

# SSH-like servers (ports 22, 2222)
info('  SSH servers: h3:22, h4:2222\n')
h3.cmd('while true; do echo "SSH-2.0-Server" | nc -l -p 22 -q 1 2>/dev/null; sleep 0.1; done > /dev/null 2>&1 &')
h4.cmd('while true; do echo "SSH-2.0-Server" | nc -l -p 2222 -q 1 2>/dev/null; sleep 0.1; done > /dev/null 2>&1 &')
time.sleep(2)

# VIDEO UDP servers (ports 5004, 5006)
info('  VIDEO UDP servers: h5:5004, h6:5006\n')
h5.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', 5004))
while True: s.recvfrom(2048)
" > /dev/null 2>&1 &''')

h6.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', 5006))
while True: s.recvfrom(2048)
" > /dev/null 2>&1 &''')
time.sleep(2)

info('\n*** Starting traffic - NO ICMP!\n')
info('  Making NEW connections every 2 seconds\n\n')

# HTTP traffic - continuous new connections
info('  HTTP: h3->h1:80, h4->h2:8080\n')
h3.cmd('bash -c "for i in {1..45}; do wget -q -O /dev/null http://10.0.0.1:80/ 2>/dev/null; sleep 2; done" &')
h4.cmd('bash -c "for i in {1..45}; do wget -q -O /dev/null http://10.0.0.2:8080/ 2>/dev/null; sleep 2; done" &')

# FTP traffic - continuous connections
info('  FTP: h5->h1:21, h6->h2:21\n')
h5.cmd('bash -c "for i in {1..45}; do echo USER anonymous | nc 10.0.0.1 21 -w 1 2>/dev/null; sleep 2; done" &')
h6.cmd('bash -c "for i in {1..45}; do echo USER anonymous | nc 10.0.0.2 21 -w 1 2>/dev/null; sleep 2; done" &')

# SSH traffic - continuous connections
info('  SSH: h1->h3:22, h2->h4:2222\n')
h1.cmd('bash -c "for i in {1..45}; do echo SSH-2.0-Client | nc 10.0.0.3 22 -w 1 2>/dev/null; sleep 2; done" &')
h2.cmd('bash -c "for i in {1..45}; do echo SSH-2.0-Client | nc 10.0.0.4 2222 -w 1 2>/dev/null; sleep 2; done" &')

# VIDEO UDP streaming - continuous
info('  VIDEO: h3->h5:5004, h4->h6:5006\n')
h3.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for i in range(90):
    s.sendto(b'VIDEO_PACKET_' + str(i).encode() * 100, ('10.0.0.5', 5004))
    time.sleep(1)
" > /dev/null 2>&1 &''')

h4.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for i in range(90):
    s.sendto(b'VIDEO_PACKET_' + str(i).encode() * 100, ('10.0.0.6', 5006))
    time.sleep(1)
" > /dev/null 2>&1 &''')

info('\n*** Traffic running for 90 seconds...\n')
info('    NO ICMP - Only TCP/UDP!\n')
info('    Watch controller for "Saved X packets"\n\n')

for i in range(90):
    time.sleep(1)
    if (i+1) % 15 == 0:
        info(f'... {i+1} seconds\n')

info('\n*** Stopping network\n')
net.stop()
ENDPYTHON

echo ""
echo "========================================="
echo "Checking Captured Traffic..."
echo "========================================="
sleep 2

python3 << 'ENDPYTHON'
import json, glob, os

files = sorted(glob.glob('data/raw/captured_packets_*.json'), key=os.path.getmtime, reverse=True)[:3]

all_packets = []
for f in files:
    with open(f) as fp:
        all_packets.extend(json.load(fp))

protocols = {}
tcp_ports = {}
udp_ports = {}

for p in all_packets:
    proto = p.get('protocol', 'UNKNOWN')
    protocols[proto] = protocols.get(proto, 0) + 1

    if proto == 'TCP':
        dst = p.get('dst_port', 0)
        tcp_ports[dst] = tcp_ports.get(dst, 0) + 1
    elif proto == 'UDP':
        dst = p.get('dst_port', 0)
        udp_ports[dst] = udp_ports.get(dst, 0) + 1

print(f'Total packets: {len(all_packets)}')
print('\nProtocol breakdown:')
for proto, count in sorted(protocols.items()):
    print(f'  {proto}: {count} packets')

if protocols.get('ICMP', 0) > 0:
    print(f'\n⚠ WARNING: {protocols["ICMP"]} ICMP packets found!')
    print('  These should not be here!')

tcp_count = protocols.get('TCP', 0)
udp_count = protocols.get('UDP', 0)

if tcp_count > 0:
    print(f'\n✓ TCP traffic captured!')
    print('TCP destination ports:')
    for port, count in sorted(tcp_ports.items(), key=lambda x: -x[1]):
        traffic_type = {80: 'HTTP', 8080: 'HTTP', 21: 'FTP', 22: 'SSH', 2222: 'SSH'}.get(port, 'Unknown')
        print(f'  Port {port} ({traffic_type}): {count} packets')

if udp_count > 0:
    print(f'\n✓ UDP traffic captured!')
    print('UDP destination ports:')
    for port, count in sorted(udp_ports.items(), key=lambda x: -x[1]):
        if port in [5004, 5006]:
            print(f'  Port {port} (VIDEO): {count} packets')
        elif port != 5353:  # Ignore mDNS
            print(f'  Port {port}: {count} packets')

if tcp_count > 5 or udp_count > 5:
    print('\n✓ SUCCESS! Diverse traffic captured!')
    print('\nNow classify:')
    print('  python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv')
    print('  python src/ml_models/classifier.py data/models/ data/processed/features.csv')
else:
    print(f'\n⚠ Limited traffic: TCP={tcp_count}, UDP={udp_count}')
    print('May need to wait longer or try again')
ENDPYTHON

#!/bin/bash
# Generate BALANCED traffic with all 4 types: HTTP, FTP, SSH, VIDEO
# Creates realistic traffic patterns matching training data

echo "========================================="
echo "Balanced Traffic Generator"
echo "========================================="
echo "Generating realistic traffic for:"
echo "  - 2 HTTP flows"
echo "  - 2 FTP flows"
echo "  - 2 SSH flows"
echo "  - 2 VIDEO flows"
echo ""
echo "Duration: 90 seconds"
echo "========================================="
echo ""

cd /home/hello/Desktop/ML_SDN

read -p "Press Enter to start...\n"

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

info('*** Starting servers\n')

# ============================================
# HTTP SERVERS (simple, few packets)
# ============================================
info('  HTTP servers: h1:80, h2:8080\n')
h1.cmd('cd /tmp && python3 -m http.server 80 > /dev/null 2>&1 &')
h2.cmd('cd /tmp && python3 -m http.server 8080 > /dev/null 2>&1 &')
time.sleep(2)

# ============================================
# FTP SERVERS (moderate packets)
# ============================================
info('  FTP servers: h3:21, h4:21\n')
h3.cmd('while true; do echo "220 FTP Ready" | nc -l -p 21 -q 1 2>/dev/null; done > /dev/null 2>&1 &')
h4.cmd('while true; do echo "220 FTP Ready" | nc -l -p 21 -q 1 2>/dev/null; done > /dev/null 2>&1 &')
time.sleep(2)

# ============================================
# SSH SERVERS (many medium packets, ~25 pkt/sec)
# ============================================
info('  SSH servers: h5:22, h6:22\n')
# SSH receiver - accepts connections
h5.cmd('''python3 -c "
import socket, time, threading
def handle_client(conn):
    try:
        for i in range(500):
            data = conn.recv(256)
            if not data: break
            conn.send(b'SSH_RESPONSE_' + str(i).encode() + b'_' * 150)
            time.sleep(0.04)  # 25 packets/sec
    except: pass
    finally: conn.close()

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('', 22))
s.listen(5)
while True:
    conn, addr = s.accept()
    threading.Thread(target=handle_client, args=(conn,)).start()
" > /dev/null 2>&1 &''')

h6.cmd('''python3 -c "
import socket, time, threading
def handle_client(conn):
    try:
        for i in range(500):
            data = conn.recv(256)
            if not data: break
            conn.send(b'SSH_RESPONSE_' + str(i).encode() + b'_' * 150)
            time.sleep(0.04)
    except: pass
    finally: conn.close()

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('', 22))
s.listen(5)
while True:
    conn, addr = s.accept()
    threading.Thread(target=handle_client, args=(conn,)).start()
" > /dev/null 2>&1 &''')
time.sleep(3)

# ============================================
# VIDEO SERVERS (MANY large packets, ~120 pkt/sec)
# ============================================
info('  VIDEO UDP servers: h1:5004, h2:5006\n')
h1.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', 5004))
while True:
    s.recvfrom(2048)
" > /dev/null 2>&1 &''')

h2.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', 5006))
while True:
    s.recvfrom(2048)
" > /dev/null 2>&1 &''')
time.sleep(2)

info('\n*** Starting traffic generators\n\n')

# ============================================
# FLOW 1-2: HTTP Traffic (h3->h1:80, h4->h2:8080)
# Small number of packets, simple GET requests
# ============================================
info('  HTTP: h3->h1:80, h4->h2:8080\n')
h3.cmd('bash -c "for i in {1..45}; do wget -q -O /dev/null http://10.0.0.1:80/ 2>/dev/null; sleep 2; done" > /dev/null 2>&1 &')
h4.cmd('bash -c "for i in {1..45}; do wget -q -O /dev/null http://10.0.0.2:8080/ 2>/dev/null; sleep 2; done" > /dev/null 2>&1 &')

# ============================================
# FLOW 3-4: FTP Traffic (h5->h3:21, h6->h4:21)
# Moderate packets, file transfer simulation
# ============================================
info('  FTP: h5->h3:21, h6->h4:21\n')
h5.cmd('bash -c "for i in {1..45}; do echo USER anonymous | nc 10.0.0.3 21 -w 1 2>/dev/null; sleep 2; done" > /dev/null 2>&1 &')
h6.cmd('bash -c "for i in {1..45}; do echo USER anonymous | nc 10.0.0.4 21 -w 1 2>/dev/null; sleep 2; done" > /dev/null 2>&1 &')

# ============================================
# FLOW 5-6: SSH Traffic (h1->h5:22, h2->h6:22)
# INTERACTIVE: Many medium packets at ~25 pkt/sec
# ============================================
info('  SSH: h1->h5:22, h2->h6:22 (interactive, ~25 pkt/sec)\n')

# SSH client - sends and receives many packets
h1.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.5', 22))
for i in range(500):
    s.send(b'SSH_COMMAND_' + str(i).encode() + b'x' * 100)
    try:
        s.recv(256)
    except:
        pass
    time.sleep(0.04)  # 25 packets/sec
s.close()
" > /dev/null 2>&1 &''')

h2.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.6', 22))
for i in range(500):
    s.send(b'SSH_COMMAND_' + str(i).encode() + b'x' * 100)
    try:
        s.recv(256)
    except:
        pass
    time.sleep(0.04)
s.close()
" > /dev/null 2>&1 &''')

# ============================================
# FLOW 7-8: VIDEO Traffic (h3->h1:5004, h4->h2:5006)
# STREAMING: Large packets (1200 bytes) at HIGH rate (~120 pkt/sec)
# ============================================
info('  VIDEO: h3->h1:5004, h4->h2:5006 (streaming, ~120 pkt/sec, 1200 byte packets)\n')

h3.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
# Send large packets at high rate (VIDEO streaming)
for i in range(2700):  # ~2700 packets to match training data
    # 1200 byte packets
    packet = b'VIDEO_FRAME_' + str(i).encode() + b'X' * 1180
    s.sendto(packet, ('10.0.0.1', 5004))
    time.sleep(0.0083)  # ~120 packets/sec
s.close()
" > /dev/null 2>&1 &''')

h4.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for i in range(2700):
    packet = b'VIDEO_FRAME_' + str(i).encode() + b'X' * 1180
    s.sendto(packet, ('10.0.0.2', 5006))
    time.sleep(0.0083)
s.close()
" > /dev/null 2>&1 &''')

info('\n*** Traffic running for 90 seconds...\n')
info('    Expected flows:\n')
info('      HTTP:  2 flows (h3->h1:80, h4->h2:8080)\n')
info('      FTP:   2 flows (h5->h3:21, h6->h4:21)\n')
info('      SSH:   2 flows (h1->h5:22, h2->h6:22)\n')
info('      VIDEO: 2 flows (h3->h1:5004, h4->h2:5006)\n\n')

for i in range(90):
    time.sleep(1)
    if (i+1) % 15 == 0:
        info(f'... {i+1} seconds\n')

info('\n*** Stopping network\n')
net.stop()
ENDPYTHON

echo ""
echo "========================================="
echo "Traffic Generation Complete!"
echo "========================================="
echo ""
echo "Now run classification to see results"
echo ""

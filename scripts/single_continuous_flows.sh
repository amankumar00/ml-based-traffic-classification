#!/bin/bash
# Generate EXACTLY 8 continuous flows (2 of each type)
# NO LOOPS - single long-lived connections

echo "========================================="
echo "Single Continuous Flow Generator"
echo "========================================="
echo "Generates exactly 8 flows:"
echo "  2 HTTP, 2 FTP, 2 SSH, 2 VIDEO"
echo "Duration: 30 seconds"
echo "========================================="

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

# HTTP servers
info('  HTTP: h1:80, h2:8080\n')
h1.cmd('cd /tmp && python3 -m http.server 80 > /dev/null 2>&1 &')
h2.cmd('cd /tmp && python3 -m http.server 8080 > /dev/null 2>&1 &')
time.sleep(2)

# FTP servers (continuous)
info('  FTP: h3:21, h4:21\n')
h3.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('', 21))
s.listen(5)
while True:
    conn, addr = s.accept()
    for i in range(200):
        conn.send(b'220 FTP DATA ' + str(i).encode() + b'X' * 500)
    conn.close()
" > /dev/null 2>&1 &''')

h4.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('', 21))
s.listen(5)
while True:
    conn, addr = s.accept()
    for i in range(200):
        conn.send(b'220 FTP DATA ' + str(i).encode() + b'X' * 500)
    conn.close()
" > /dev/null 2>&1 &''')
time.sleep(2)

# SSH servers (interactive)
info('  SSH: h5:22, h6:22\n')
h5.cmd('''python3 -c "
import socket, time, threading
def handle_client(conn):
    try:
        for i in range(250):
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

h6.cmd('''python3 -c "
import socket, time, threading
def handle_client(conn):
    try:
        for i in range(250):
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
time.sleep(2)

# VIDEO UDP servers
info('  VIDEO: h1:5004, h2:5006\n')
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

info('\n*** Starting SINGLE continuous flow of each type\n\n')

# FLOW 1-2: HTTP - SINGLE long connection with data transfer
info('  HTTP FLOW 1: h3->h1:80\n')
h3.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.1', 80))
for i in range(50):
    s.send(b'GET / HTTP/1.1\\r\\nHost: test\\r\\n\\r\\n' * 10)
    try:
        s.recv(4096)
    except:
        pass
    time.sleep(0.2)
s.close()
" > /dev/null 2>&1 &''')

info('  HTTP FLOW 2: h4->h2:8080\n')
h4.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.2', 8080))
for i in range(50):
    s.send(b'GET / HTTP/1.1\\r\\nHost: test\\r\\n\\r\\n' * 10)
    try:
        s.recv(4096)
    except:
        pass
    time.sleep(0.2)
s.close()
" > /dev/null 2>&1 &''')

# FLOW 3-4: FTP - SINGLE connection with data
info('  FTP FLOW 1: h5->h3:21\n')
h5.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.3', 21))
for i in range(30):
    try:
        data = s.recv(4096)
    except:
        break
    time.sleep(0.1)
s.close()
" > /dev/null 2>&1 &''')

info('  FTP FLOW 2: h6->h4:21\n')
h6.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.4', 21))
for i in range(30):
    try:
        data = s.recv(4096)
    except:
        break
    time.sleep(0.1)
s.close()
" > /dev/null 2>&1 &''')

# FLOW 5-6: SSH - SINGLE interactive session
info('  SSH FLOW 1: h1->h5:22\n')
h1.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.5', 22))
for i in range(250):
    s.send(b'SSH_COMMAND_' + str(i).encode() + b'x' * 100)
    try:
        s.recv(256)
    except:
        pass
    time.sleep(0.04)
s.close()
" > /dev/null 2>&1 &''')

info('  SSH FLOW 2: h2->h6:22\n')
h2.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.6', 22))
for i in range(250):
    s.send(b'SSH_COMMAND_' + str(i).encode() + b'x' * 100)
    try:
        s.recv(256)
    except:
        pass
    time.sleep(0.04)
s.close()
" > /dev/null 2>&1 &''')

# FLOW 7-8: VIDEO - SINGLE streaming session
info('  VIDEO FLOW 1: h3->h1:5004 (UDP streaming)\n')
h3.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for i in range(2700):
    packet = b'VIDEO_FRAME_' + str(i).encode() + b'X' * 1880
    s.sendto(packet, ('10.0.0.1', 5004))
    time.sleep(0.0083)
s.close()
" > /dev/null 2>&1 &''')

info('  VIDEO FLOW 2: h4->h2:5006 (UDP streaming)\n')
h4.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for i in range(2700):
    packet = b'VIDEO_FRAME_' + str(i).encode() + b'X' * 1880
    s.sendto(packet, ('10.0.0.2', 5006))
    time.sleep(0.0083)
s.close()
" > /dev/null 2>&1 &''')

info('\n*** Traffic running for 30 seconds...\n')
info('    Exactly 8 flows total\n\n')

for i in range(30):
    time.sleep(1)
    if (i+1) % 10 == 0:
        info(f'... {i+1} seconds\n')

info('\n*** Stopping network\n')
net.stop()
ENDPYTHON

echo ""
echo "Done! Now classify with automated script."

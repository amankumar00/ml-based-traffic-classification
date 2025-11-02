#!/bin/bash
# Automated Traffic Classification Pipeline
# Runs controller -> generates traffic -> classifies -> outputs CSV

echo "========================================="
echo "Automated Traffic Classification"
echo "========================================="
echo ""
echo "This script will:"
echo "  1. Clean old data"
echo "  2. Start Ryu controller in background"
echo "  3. Generate traffic (NO ICMP)"
echo "  4. Stop controller"
echo "  5. Extract features"
echo "  6. Classify flows"
echo "  7. Generate host-to-host CSV"
echo ""
echo "Output: data/processed/host_to_host_flows.csv"
echo ""

cd /home/hello/Desktop/ML_SDN

# Activate conda environment
source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

read -p "Press Enter to start..."

# Step 1: Clean old data
echo ""
echo "========================================="
echo "Step 1: Cleaning old data..."
echo "========================================="
rm -f data/raw/*.json
rm -f data/processed/features.csv
rm -f data/processed/flow_classification.csv
rm -f data/processed/host_to_host_flows.csv
echo "✓ Old data cleaned"

# Step 2: Clean Mininet (before starting controller!)
echo ""
echo "========================================="
echo "Step 2: Cleaning Mininet..."
echo "========================================="
sudo mn -c 2>/dev/null
echo "✓ Mininet cleaned"

# Step 3: Start Ryu controller in background
echo ""
echo "========================================="
echo "Step 3: Starting Ryu controller..."
echo "========================================="
ryu-manager src/controller/sdn_controller.py --verbose > /tmp/ryu_controller.log 2>&1 &
RYU_PID=$!
echo "✓ Controller started (PID: $RYU_PID)"
echo "  Log: /tmp/ryu_controller.log"

# Wait for controller to initialize
sleep 5

# Check if controller is still running
if ! ps -p $RYU_PID > /dev/null; then
    echo "✗ ERROR: Controller failed to start!"
    echo "Check /tmp/ryu_controller.log for details"
    exit 1
fi

# Step 4: Generate traffic
echo ""
echo "========================================="
echo "Step 4: Generating traffic (90 seconds)..."
echo "========================================="
echo "Controller is running, starting Mininet..."
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
# FTP SERVERS (moderate packets) - send MORE data for ~1096 packets
# ============================================
info('  FTP servers: h3:21, h4:21\n')
h3.cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('', 21))
s.listen(5)
while True:
    conn, addr = s.accept()
    for i in range(600):
        conn.send(b'220 FTP DATA ' + str(i).encode() + b'X' * 2000)
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
    for i in range(600):
        conn.send(b'220 FTP DATA ' + str(i).encode() + b'X' * 2000)
    conn.close()
" > /dev/null 2>&1 &''')
time.sleep(2)

# ============================================
# SSH SERVERS (many medium packets, ~26 pkt/sec, 205 byte avg)
# ============================================
info('  SSH servers: h5:22, h6:22\n')
h5.cmd('''python3 -c "
import socket, time, threading
def handle_client(conn):
    try:
        for i in range(180):
            data = conn.recv(512)
            if not data: break
            conn.send(b'SSH_RESPONSE_' + str(i).encode() + b'_' * 250)
            time.sleep(0.11)
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
        for i in range(180):
            data = conn.recv(512)
            if not data: break
            conn.send(b'SSH_RESPONSE_' + str(i).encode() + b'_' * 250)
            time.sleep(0.11)
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
# FLOW 1-2: HTTP Traffic - SINGLE continuous connection
# ============================================
info('  HTTP: h3->h1:80, h4->h2:8080 (continuous)\n')
h3.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.1', 80))
for i in range(60):
    s.send(b'GET / HTTP/1.1\\\\r\\\\nHost: test\\\\r\\\\n\\\\r\\\\n' * 5)
    try:
        s.recv(4096)
    except:
        pass
    time.sleep(0.5)
s.close()
" > /dev/null 2>&1 &''')

h4.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.2', 8080))
for i in range(60):
    s.send(b'GET / HTTP/1.1\\\\r\\\\nHost: test\\\\r\\\\n\\\\r\\\\n' * 5)
    try:
        s.recv(4096)
    except:
        pass
    time.sleep(0.5)
s.close()
" > /dev/null 2>&1 &''')

# ============================================
# FLOW 3-4: FTP Traffic - SINGLE connection receiving data
# Target: ~1096 packets, ~86 pkt/sec, ~1077 byte avg
# ============================================
info('  FTP: h5->h3:21, h6->h4:21 (continuous, ~86 pkt/sec)\n')
h5.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.3', 21))
for i in range(150):
    try:
        data = s.recv(4096)
    except:
        break
    time.sleep(0.012)
s.close()
" > /dev/null 2>&1 &''')

h6.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.4', 21))
for i in range(150):
    try:
        data = s.recv(4096)
    except:
        break
    time.sleep(0.012)
s.close()
" > /dev/null 2>&1 &''')

# ============================================
# FLOW 5-6: SSH Traffic (h1->h5:22, h2->h6:22)
# Target: ~539 packets, ~26 pkt/sec, ~205 byte avg
# ============================================
info('  SSH: h1->h5:22, h2->h6:22 (interactive, ~26 pkt/sec)\n')
h1.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.5', 22))
for i in range(180):
    s.send(b'SSH_COMMAND_' + str(i).encode() + b'x' * 150)
    try:
        s.recv(512)
    except:
        pass
    time.sleep(0.11)
s.close()
" > /dev/null 2>&1 &''')

h2.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('10.0.0.6', 22))
for i in range(180):
    s.send(b'SSH_COMMAND_' + str(i).encode() + b'x' * 150)
    try:
        s.recv(512)
    except:
        pass
    time.sleep(0.11)
s.close()
" > /dev/null 2>&1 &''')

# ============================================
# FLOW 7-8: VIDEO Traffic (h3->h1:5004, h4->h2:5006)
# STREAMING: Large packets (1200 bytes) at HIGH rate (~120 pkt/sec)
# ============================================
info('  VIDEO: h3->h1:5004, h4->h2:5006 (streaming, ~119 pkt/sec, 2700 pkts, 1450 bytes/pkt)\n')
h3.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for i in range(2700):
    packet = b'VIDEO_FRAME_' + str(i).encode() + b'X' * 1450
    s.sendto(packet, ('10.0.0.1', 5004))
    time.sleep(0.0084)
s.close()
" > /dev/null 2>&1 &''')

h4.cmd('''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for i in range(2700):
    packet = b'VIDEO_FRAME_' + str(i).encode() + b'X' * 1450
    s.sendto(packet, ('10.0.0.2', 5006))
    time.sleep(0.0084)
s.close()
" > /dev/null 2>&1 &''')

info('\n*** Traffic running for 90 seconds...\n')
info('    Expected: 2 HTTP, 2 FTP, 2 SSH, 2 VIDEO flows\n\n')

for i in range(90):
    time.sleep(1)
    if (i+1) % 15 == 0:
        info(f'... {i+1} seconds\n')

info('\n*** Stopping network\n')
net.stop()
ENDPYTHON

echo ""
echo "✓ Traffic generation complete"

# Step 5: Stop controller
echo ""
echo "========================================="
echo "Step 5: Stopping controller..."
echo "========================================="
kill $RYU_PID 2>/dev/null
wait $RYU_PID 2>/dev/null
echo "✓ Controller stopped"

# Wait for files to be written
sleep 2

# Step 6: Check captured data
echo ""
echo "========================================="
echo "Step 6: Checking captured data..."
echo "========================================="
PACKET_FILES=$(ls data/raw/captured_packets_*.json 2>/dev/null | wc -l)
if [ $PACKET_FILES -eq 0 ]; then
    echo "✗ ERROR: No packet files captured!"
    echo "Controller may not have saved any data"
    exit 1
fi
echo "✓ Found $PACKET_FILES packet file(s)"

# Step 7: Extract features
echo ""
echo "========================================="
echo "Step 7: Extracting features..."
echo "========================================="
python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv
if [ ! -f data/processed/features.csv ]; then
    echo "✗ ERROR: Feature extraction failed!"
    exit 1
fi
echo "✓ Features extracted"

# Step 8: Classify flows
echo ""
echo "========================================="
echo "Step 8: Classifying flows..."
echo "========================================="
python src/ml_models/classify_and_export.py data/models/ data/processed/features.csv data/processed/flow_classification.csv
if [ ! -f data/processed/flow_classification.csv ]; then
    echo "✗ ERROR: Classification failed!"
    exit 1
fi
echo "✓ Flows classified"

# Step 9: Generate host-to-host CSV
echo ""
echo "========================================="
echo "Step 9: Generating host-to-host CSV..."
echo "========================================="
(head -1 data/processed/flow_classification.csv; grep '^[0-9]*,h[0-9]' data/processed/flow_classification.csv) > data/processed/host_to_host_flows.csv

NUM_FLOWS=$(grep '^[0-9]*,h[0-9]' data/processed/flow_classification.csv | wc -l)
echo "✓ Host-to-host CSV generated: $NUM_FLOWS flows"

# Step 10: Show summary
echo ""
echo "========================================="
echo "FINAL RESULTS"
echo "========================================="
python << 'ENDPYTHON'
import pandas as pd

df = pd.read_csv('data/processed/host_to_host_flows.csv')

print(f"\nTotal host-to-host flows: {len(df)}\n")

print("Traffic Type Distribution:")
print("-" * 40)
for traffic_type in sorted(df['traffic_type'].unique()):
    count = len(df[df['traffic_type'] == traffic_type])
    pct = (count / len(df)) * 100
    print(f"  {traffic_type:10s}: {count:4d} flows ({pct:5.1f}%)")

print("\n\nFlows Grouped by Host Pairs:")
print("-" * 60)
grouped = df.groupby(['src_host', 'dst_host', 'traffic_type']).size().reset_index(name='num_flows')
grouped = grouped.sort_values(['src_host', 'dst_host', 'num_flows'], ascending=[True, True, False])

print(f"{'Source':8s} {'Dest':8s} {'Type':10s} {'Flows':>8s}")
print("-" * 60)
for _, row in grouped.iterrows():
    print(f"{row['src_host']:8s} {row['dst_host']:8s} {row['traffic_type']:10s} {int(row['num_flows']):8d}")

ENDPYTHON

echo ""
echo "========================================="
echo "✓ COMPLETE!"
echo "========================================="
echo ""
echo "Output files:"
echo "  • data/processed/host_to_host_flows.csv"
echo "  • data/processed/flow_classification.csv"
echo "  • data/processed/features.csv"
echo ""
echo "Controller log: /tmp/ryu_controller.log"
echo ""

#!/bin/bash
# Demonstrate FPLF Routing with Traffic-Aware Path Selection

echo "========================================="
echo "FPLF Routing Demonstration"
echo "========================================="
echo ""
echo "This script will:"
echo "  1. Start Ryu FPLF controller"
echo "  2. Create multi-switch topology"
echo "  3. Generate classified traffic"
echo "  4. Show priority-based route assignments"
echo ""
echo "Priority: VIDEO > SSH > HTTP > FTP"
echo ""

cd /home/hello/Desktop/ML_SDN

# Activate conda environment
source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

# Check if classification data exists
if [ ! -f data/processed/host_to_host_flows.csv ]; then
    echo "ERROR: Classification data not found!"
    echo "Please run ./scripts/automated_traffic_classification.sh first"
    exit 1
fi

echo "Using classified flows from previous run:"
echo "========================================="
python3 << 'EOF'
import pandas as pd
df = pd.read_csv('data/processed/host_to_host_flows.csv')
print(df[['src_host', 'dst_host', 'dst_port', 'protocol', 'traffic_type']].to_string(index=False))
EOF
echo ""

read -p "Press Enter to start FPLF demonstration..."

# Clean up
echo ""
echo "Cleaning environment..."
sudo mn -c 2>/dev/null
sudo pkill -f ryu-manager 2>/dev/null
sleep 2

# Start FPLF controller
echo ""
echo "========================================="
echo "Starting FPLF Controller..."
echo "========================================="
ryu-manager src/controller/fplf_controller.py > /tmp/fplf_controller.log 2>&1 &
RYU_PID=$!
echo "Controller started (PID: $RYU_PID)"
echo "Log: /tmp/fplf_controller.log"
sleep 5

# Check if controller is running
if ! ps -p $RYU_PID > /dev/null; then
    echo "ERROR: Controller failed to start!"
    echo "Check /tmp/fplf_controller.log for details"
    exit 1
fi

# Start Mininet with multi-switch topology
echo ""
echo "========================================="
echo "Creating Multi-Switch Topology..."
echo "========================================="
echo "Topology: 6 hosts, 4 switches, multiple paths"
echo ""

sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 << 'ENDPYTHON'
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
import time

setLogLevel('info')

info('*** Creating network\n')
net = Mininet(
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch
)

# Add controller
c0 = net.addController('c0')

# Add switches
info('*** Adding switches\n')
s1 = net.addSwitch('s1', protocols='OpenFlow13')
s2 = net.addSwitch('s2', protocols='OpenFlow13')
s3 = net.addSwitch('s3', protocols='OpenFlow13')
s4 = net.addSwitch('s4', protocols='OpenFlow13')

# Add hosts
info('*** Adding hosts\n')
h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')
h3 = net.addHost('h3', ip='10.0.0.3/24')
h4 = net.addHost('h4', ip='10.0.0.4/24')
h5 = net.addHost('h5', ip='10.0.0.5/24')
h6 = net.addHost('h6', ip='10.0.0.6/24')

# Create topology with multiple paths
info('*** Creating links\n')
info('  Hosts to access switches\n')
net.addLink(h1, s1)
net.addLink(h2, s1)
net.addLink(h3, s2)
net.addLink(h4, s2)
net.addLink(h5, s3)
net.addLink(h6, s4)

info('  Core network (multiple paths)\n')
# Create redundant paths between switches
net.addLink(s1, s2)  # Direct path
net.addLink(s1, s3)  # Via s3
net.addLink(s2, s4)  # Direct path
net.addLink(s3, s4)  # Alternate
net.addLink(s1, s4)  # Another path

info('*** Starting network\n')
net.start()

info('*** Waiting for topology discovery (LLDP)...\n')
for i in range(15):
    time.sleep(1)
    if (i+1) % 5 == 0:
        info(f'  ... {i+1} seconds (discovering links)\n')

info('*** Network topology created:\n')
info('  h1, h2 -- s1 -- s2 -- h3, h4\n')
info('            |  X  |\n')
info('           s3 -- s4 -- h5, h6\n')
info('  (Multiple paths for FPLF routing)\n\n')

info('*** Starting servers\n')

# HTTP servers
info('  HTTP servers: h1:80, h2:8080\n')
h1.cmd('cd /tmp && python3 -m http.server 80 > /dev/null 2>&1 &')
h2.cmd('cd /tmp && python3 -m http.server 8080 > /dev/null 2>&1 &')
time.sleep(2)

# FTP servers
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

# SSH servers
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

# VIDEO servers
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

info('\n*** Generating traffic (30 seconds)...\n')
info('  Priority: VIDEO > SSH > HTTP > FTP\n\n')

# Start all traffic generators simultaneously
info('  VIDEO: h3->h1:5004, h4->h2:5006 (HIGH PRIORITY)\n')
h3.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); [s.sendto(b\'VIDEO_FRAME_\' + str(i).encode() + b\'X\' * 1450, (\'10.0.0.1\', 5004)) or time.sleep(0.01) for i in range(3000)]" > /dev/null 2>&1 &')
h4.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); [s.sendto(b\'VIDEO_FRAME_\' + str(i).encode() + b\'X\' * 1450, (\'10.0.0.2\', 5006)) or time.sleep(0.01) for i in range(3000)]" > /dev/null 2>&1 &')

info('  SSH: h1->h5:22, h2->h6:22 (MEDIUM-HIGH PRIORITY)\n')
h1.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect((\'10.0.0.5\', 22)); [s.send(b\'SSH_COMMAND_\' + str(i).encode() + b\'x\' * 150) or s.recv(512) or time.sleep(0.15) for i in range(200)]" > /dev/null 2>&1 &')
h2.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect((\'10.0.0.6\', 22)); [s.send(b\'SSH_COMMAND_\' + str(i).encode() + b\'x\' * 150) or s.recv(512) or time.sleep(0.15) for i in range(200)]" > /dev/null 2>&1 &')

info('  HTTP: h3->h1:80, h4->h2:8080 (MEDIUM PRIORITY)\n')
h3.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect((\'10.0.0.1\', 80)); [s.send(b\'GET / HTTP/1.1\\\\r\\\\nHost: test\\\\r\\\\n\\\\r\\\\n\' * 5) or s.recv(4096) or time.sleep(0.5) for i in range(60)]" > /dev/null 2>&1 &')
h4.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect((\'10.0.0.2\', 8080)); [s.send(b\'GET / HTTP/1.1\\\\r\\\\nHost: test\\\\r\\\\n\\\\r\\\\n\' * 5) or s.recv(4096) or time.sleep(0.5) for i in range(60)]" > /dev/null 2>&1 &')

info('  FTP: h5->h3:21, h6->h4:21 (LOW PRIORITY)\n')
h5.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect((\'10.0.0.3\', 21)); [s.recv(4096) or time.sleep(0.02) for i in range(150)]" > /dev/null 2>&1 &')
h6.cmd('timeout 30 python3 -c "import socket, time; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect((\'10.0.0.4\', 21)); [s.recv(4096) or time.sleep(0.02) for i in range(150)]" > /dev/null 2>&1 &')

# Wait for traffic
for i in range(30):
    time.sleep(1)
    if (i+1) % 10 == 0:
        info(f'... {i+1} seconds\n')

info('\n*** Traffic generation complete\n')
info('*** Check /tmp/fplf_controller.log for route assignments\n\n')

info('*** Network is running. Press Ctrl-D to exit and see results.\n')
CLI(net)

info('*** Stopping network\n')
net.stop()
ENDPYTHON

# Stop controller
echo ""
echo "========================================="
echo "Stopping controller..."
echo "========================================="
kill $RYU_PID 2>/dev/null
wait $RYU_PID 2>/dev/null

# Show results
echo ""
echo "========================================="
echo "FPLF ROUTING RESULTS"
echo "========================================="
echo ""
echo "Checking controller log for route assignments..."
echo ""

# Show topology discovery
echo "Topology Discovery:"
echo "-------------------"
grep "LINK DISCOVERED" /tmp/fplf_controller.log || echo "No links discovered!"

echo ""
echo "Route Assignments:"
echo "-------------------"
grep -A 3 "FPLF ROUTE" /tmp/fplf_controller.log | grep -v "^--$" || echo "No routes logged"

echo ""
echo "========================================="
echo "Priority Summary:"
echo "========================================="
echo "  VIDEO (Priority 4): Preferred lowest-load paths"
echo "  SSH   (Priority 3): Preferred low-load paths"
echo "  HTTP  (Priority 2): Medium priority paths"
echo "  FTP   (Priority 1): Any available path"
echo ""

# Run visualization
echo ""
echo "========================================="
echo "ROUTE VISUALIZATION"
echo "========================================="
python3 scripts/visualize_fplf_routes.py /tmp/fplf_controller.log

echo ""
echo "Controller log: /tmp/fplf_controller.log"
echo ""

#!/bin/bash
# Diagnose why TCP traffic isn't being generated

echo "========================================="
echo "TCP Traffic Diagnostic Test"
echo "========================================="

cd /home/hello/Desktop/ML_SDN

echo ""
echo "This will test if TCP traffic can work in Mininet"
echo "Make sure controller is running!"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "Starting diagnostic test..."
echo ""

sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 << 'ENDPYTHON'
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.log import setLogLevel, info
import time

setLogLevel('info')

info('*** Creating minimal network (2 hosts, 1 switch)\n')
net = Mininet(
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch
)

c0 = net.addController('c0')
s1 = net.addSwitch('s1', protocols='OpenFlow13')
h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')

net.addLink(h1, s1)
net.addLink(h2, s1)

info('*** Starting network\n')
net.start()
time.sleep(3)

info('\n*** Testing basic connectivity\n')
result = net.ping([h1, h2])
if result > 0:
    info('ERROR: Ping failed! Network not working properly.\n')
    net.stop()
    exit(1)

info('OK: Ping works\n\n')

# Test 1: Check if Python HTTP server can start
info('*** TEST 1: Starting Python HTTP server on h1...\n')
h1.cmd('cd /tmp && python3 -m http.server 8000 > /tmp/http_server.log 2>&1 &')
time.sleep(3)

# Check if server is listening
result = h1.cmd('netstat -tuln | grep 8000')
if ':8000' in result:
    info('OK: HTTP server is listening on port 8000\n')
    info(f'    netstat output: {result}\n')
else:
    info('ERROR: HTTP server not listening!\n')
    info(f'    Server log:\n')
    log = h1.cmd('cat /tmp/http_server.log')
    info(f'{log}\n')

# Test 2: Check if wget exists and can connect
info('\n*** TEST 2: Testing wget from h2 to h1...\n')
result = h2.cmd(f'wget -O /dev/null http://10.0.0.1:8000/ 2>&1')
info(f'wget output:\n{result}\n')

if 'saved' in result.lower() or '200 ok' in result.lower():
    info('OK: wget successfully connected!\n')
else:
    info('ERROR: wget failed to connect\n')

# Test 3: Check with tcpdump if TCP packets are being sent
info('\n*** TEST 3: Capturing traffic with tcpdump...\n')
info('Starting tcpdump on h1...\n')
h1.cmd('timeout 5 tcpdump -i any -c 10 "tcp port 8000" > /tmp/tcpdump.log 2>&1 &')
time.sleep(1)

info('Making HTTP request from h2...\n')
h2.cmd('wget -q -O /dev/null http://10.0.0.1:8000/ 2>&1')
time.sleep(3)

tcpdump_out = h1.cmd('cat /tmp/tcpdump.log')
info(f'tcpdump output:\n{tcpdump_out}\n')

if 'tcp' in tcpdump_out.lower():
    info('OK: TCP packets are flowing!\n')
else:
    info('ERROR: No TCP packets seen by tcpdump\n')

info('\n*** TEST 4: Check what controller sees...\n')
info('Generating one more HTTP request...\n')
h2.cmd('wget -q -O /dev/null http://10.0.0.1:8000/')
time.sleep(2)

info('\n*** Stopping network\n')
net.stop()

info('\n========================================\n')
info('Diagnostic complete!\n')
info('Check controller output for PacketIn events\n')
info('Check data/raw/ for captured packets\n')
ENDPYTHON

echo ""
echo "========================================="
echo "Now checking captured packets..."
echo "========================================="
sleep 2

if [ -f "data/raw/captured_packets_"*.json 2>/dev/null ]; then
    python3 -c "
import json, glob
files = sorted(glob.glob('data/raw/captured_packets_*.json'))
if files:
    # Check the most recent file
    with open(files[-1]) as f:
        data = json.load(f)
        tcp_count = sum(1 for p in data if p.get('protocol') == 'TCP')
        print(f'Most recent capture file: {files[-1]}')
        print(f'TCP packets in file: {tcp_count}')

        if tcp_count > 0:
            print('\\nSUCCESS: TCP packets are being captured!')
        else:
            print('\\nPROBLEM: No TCP packets in captured data')
            print('This means either:')
            print('  1. TCP traffic not reaching switches')
            print('  2. Controller not forwarding PacketIn to capture')
"
else
    echo "No captured packets found yet"
fi

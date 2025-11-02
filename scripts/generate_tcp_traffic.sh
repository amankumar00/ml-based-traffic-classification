#!/bin/bash
# Generate continuous TCP traffic for 60 seconds to ensure capture

echo "========================================="
echo "TCP Traffic Generator - 60 Second Test"
echo "========================================="

cd /home/hello/Desktop/ML_SDN

echo ""
echo "This will:"
echo "  - Start Python HTTP server"
echo "  - Generate continuous HTTP requests for 60 seconds"
echo "  - Controller will save packets every 30 seconds"
echo ""
echo "Make sure controller is running in Terminal 1!"
echo ""
read -p "Press Enter to start..."

echo ""
echo "Starting 60-second TCP traffic test..."
echo ""

sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 << 'ENDPYTHON'
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.log import setLogLevel, info
import time

setLogLevel('info')

info('*** Creating network (3 hosts, 1 switch)\n')
net = Mininet(
    controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
    switch=OVSSwitch
)

c0 = net.addController('c0')
s1 = net.addSwitch('s1', protocols='OpenFlow13')
h1 = net.addHost('h1', ip='10.0.0.1/24')
h2 = net.addHost('h2', ip='10.0.0.2/24')
h3 = net.addHost('h3', ip='10.0.0.3/24')

net.addLink(h1, s1)
net.addLink(h2, s1)
net.addLink(h3, s1)

info('*** Starting network\n')
net.start()
time.sleep(3)

info('*** Starting HTTP servers on h1 and h2\n')
h1.cmd('cd /tmp && python3 -m http.server 8000 > /dev/null 2>&1 &')
h2.cmd('cd /tmp && python3 -m http.server 8001 > /dev/null 2>&1 &')
time.sleep(3)

info('*** Starting continuous HTTP requests for 60 seconds\n')
info('    h3 will make requests every 2 seconds\n')
info('    Watch Terminal 1 for "Saved X packets" messages\n\n')

# Start continuous HTTP traffic
h3.cmd('(for i in {1..30}; do wget -q -O /dev/null http://10.0.0.1:8000/ 2>/dev/null; sleep 2; done) &')
h3.cmd('(for i in {1..30}; do wget -q -O /dev/null http://10.0.0.2:8001/ 2>/dev/null; sleep 2.5; done) &')

# Also continuous ping
h1.cmd('ping -i 1 10.0.0.2 > /dev/null 2>&1 &')

# Wait 60 seconds
for i in range(60):
    time.sleep(1)
    if (i+1) % 10 == 0:
        info(f'... {i+1} seconds elapsed\n')

info('\n*** Stopping network\n')
net.stop()

info('*** Done! Check Terminal 1 for "Saved X packets" messages\n')
info('*** Then analyze with:\n')
info('    python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv\n')
info('    python src/ml_models/classifier.py data/models/ data/processed/features.csv\n')
ENDPYTHON

echo ""
echo "========================================="
echo "Traffic generation complete!"
echo "========================================="
echo ""
echo "Check Terminal 1 - you should have seen:"
echo "  'Saved X packets' at 30 seconds and 60 seconds"
echo ""
echo "Now check captured TCP packets:"
echo ""

python3 -c "
import json, glob, os
files = sorted(glob.glob('data/raw/captured_packets_*.json'), key=os.path.getmtime, reverse=True)
if files:
    print(f'Checking most recent files:')
    for f in files[:3]:
        with open(f) as fp:
            data = json.load(fp)
            tcp_count = sum(1 for p in data if p.get('protocol') == 'TCP')
            total = len(data)
            print(f'  {os.path.basename(f)}: {tcp_count} TCP packets (out of {total} total)')
"

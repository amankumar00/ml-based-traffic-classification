#!/bin/bash
# Simple test to verify controller can capture packets

echo "========================================="
echo "Simple Traffic Capture Test"
echo "========================================="

cd /home/hello/Desktop/ML_SDN

# Check if controller is running
if ! pgrep -f "ryu-manager.*sdn_controller" > /dev/null; then
    echo "ERROR: Controller is not running!"
    echo "Please start it in another terminal:"
    echo "  conda activate ml-sdn"
    echo "  ryu-manager src/controller/sdn_controller.py --verbose"
    exit 1
fi

echo "Controller is running ✓"
echo ""
echo "Starting Mininet with simple ping test..."
echo ""

# Run simple topology with just ping
sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 topology/custom_topo.py --topology linear --traffic icmp --duration 45

echo ""
echo "Checking captured packets..."
sleep 2

if [ "$(ls -A data/raw/)" ]; then
    echo "✓ Packets captured!"
    ls -lh data/raw/

    # Show what was captured
    python3 -c "
import json, glob
files = glob.glob('data/raw/captured_packets_*.json')
if files:
    data = json.load(open(files[0]))
    print(f'\nTotal packets in first file: {len(data)}')
    protocols = {}
    for p in data:
        proto = p.get('protocol', 'UNKNOWN')
        protocols[proto] = protocols.get(proto, 0) + 1
    print('\nProtocol breakdown:')
    for proto, count in sorted(protocols.items()):
        print(f'  {proto}: {count} packets')
"
else
    echo "✗ No packets captured!"
    echo "Check controller output for errors"
fi

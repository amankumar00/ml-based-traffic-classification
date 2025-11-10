#!/bin/bash
# Test ONLY 4-switch topology (no 2-switch test first)

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "4-Switch FPLF Test (standalone)"
echo "========================================="

# Clean
sudo mn -c 2>/dev/null
sudo pkill -9 -f ryu-manager 2>/dev/null
sleep 2

# Start controller
echo "Starting controller..."
ryu-manager src/controller/fplf_controller.py > /tmp/fplf_4sw_only.log 2>&1 &
RYU_PID=$!
sleep 3

if ! ps -p $RYU_PID > /dev/null; then
    echo "Controller failed!"
    cat /tmp/fplf_4sw_only.log
    exit 1
fi

echo "Controller running (PID: $RYU_PID)"
echo ""

# Run 4-switch topology
echo "Starting 4-switch Mininet..."
sudo python3 scripts/fplf_demo_topology.py

# Stop controller
sleep 2
kill $RYU_PID 2>/dev/null

echo ""
echo "========================================="
echo "Results"
echo "========================================="
echo "Switches: $(grep -c 'Switch.*connected' /tmp/fplf_4sw_only.log)"
echo "Routes: $(grep -c 'FPLF ROUTE' /tmp/fplf_4sw_only.log)"
echo ""
echo "ARP packets at each switch:"
echo "  s1: $(grep -c '\[s1.*ARP' /tmp/fplf_4sw_only.log)"
echo "  s2: $(grep -c '\[s2.*ARP' /tmp/fplf_4sw_only.log)"
echo "  s3: $(grep -c '\[s3.*ARP' /tmp/fplf_4sw_only.log)"
echo "  s4: $(grep -c '\[s4.*ARP' /tmp/fplf_4sw_only.log)"
echo ""
echo "Full log: /tmp/fplf_4sw_only.log"

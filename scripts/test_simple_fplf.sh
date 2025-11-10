#!/bin/bash
# Test the new simple FPLF controller with custom topology

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "Simple FPLF Test"
echo "========================================="

# Clean up
sudo mn -c 2>/dev/null
sudo pkill -9 -f ryu-manager 2>/dev/null
sleep 2

# Start controller
echo "Starting Simple FPLF controller..."
ryu-manager src/controller/simple_fplf.py > /tmp/simple_fplf.log 2>&1 &
RYU_PID=$!
sleep 3

if ! ps -p $RYU_PID > /dev/null; then
    echo "ERROR: Controller failed to start!"
    cat /tmp/simple_fplf.log
    exit 1
fi

echo "Controller running (PID: $RYU_PID)"
echo ""

# Start Mininet with custom topology
echo "Starting Mininet with custom topology..."
sudo python3 topology/custom_topo.py --topology custom --traffic icmp --duration 10

# Stop controller
sleep 2
kill $RYU_PID 2>/dev/null

echo ""
echo "========================================="
echo "Results"
echo "========================================="
echo "Topology discovered:"
grep "Topology:" /tmp/simple_fplf.log | tail -1
echo ""
echo "FPLF Paths computed:"
grep "FPLF Path:" /tmp/simple_fplf.log | head -10
echo ""
echo "Full log: /tmp/simple_fplf.log"

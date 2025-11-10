#!/bin/bash
# Test FPLF with actual ping traffic

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "FPLF Test with Traffic"
echo "========================================="
echo ""

# Clean
sudo mn -c 2>/dev/null
sudo pkill -f ryu-manager 2>/dev/null
sleep 1

# Start controller
echo "Starting FPLF controller..."
ryu-manager src/controller/fplf_controller.py > /tmp/fplf_test_traffic.log 2>&1 &
RYU_PID=$!
sleep 3

if ! ps -p $RYU_PID > /dev/null; then
    echo "Controller failed!"
    cat /tmp/fplf_test_traffic.log
    exit 1
fi

echo "Controller running (PID: $RYU_PID)"
echo ""

# Run Mininet
echo "Starting Mininet..."
sudo python3 scripts/fplf_demo_topology.py

# Controller keeps running after Mininet exits
sleep 2
kill $RYU_PID 2>/dev/null

echo ""
echo "========================================="
echo "Controller Log:"
echo "========================================="
cat /tmp/fplf_test_traffic.log

echo ""
echo "========================================="
echo "Statistics:"
echo "========================================="
echo "Packets received: $(grep 'Packet #' /tmp/fplf_test_traffic.log | wc -l)"
echo "Routes computed: $(grep 'FPLF ROUTE' /tmp/fplf_test_traffic.log | wc -l)"
echo ""
echo "Routes:"
grep -A 3 "FPLF ROUTE" /tmp/fplf_test_traffic.log

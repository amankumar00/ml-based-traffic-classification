#!/bin/bash
# Minimal test - 2 switches, 2 hosts

cd /home/hello/Desktop/ML_SDN

source ~/miniconda3/etc/profile.d/conda.sh
conda activate ml-sdn

echo "========================================="
echo "Minimal FPLF Test (2 switches, 2 hosts)"
echo "========================================="
echo ""

# Clean
sudo mn -c 2>/dev/null
sudo pkill -f ryu-manager 2>/dev/null
sleep 1

# Start controller
echo "Starting controller..."
ryu-manager src/controller/fplf_controller.py > /tmp/fplf_minimal.log 2>&1 &
RYU_PID=$!
sleep 3

if ! ps -p $RYU_PID > /dev/null; then
    echo "Controller failed!"
    cat /tmp/fplf_minimal.log
    exit 1
fi

echo "Controller running (PID: $RYU_PID)"
echo ""

# Run Mininet
echo "Starting Mininet..."
sudo python3 scripts/test_fplf_minimal.py

# Stop controller
sleep 2
kill $RYU_PID 2>/dev/null

echo ""
echo "========================================="
echo "Controller Log:"
echo "========================================="
cat /tmp/fplf_minimal.log

echo ""
echo "========================================="
echo "Analysis:"
echo "========================================="
echo -n "ARP Requests: "
grep "ARP Request" /tmp/fplf_minimal.log | wc -l
echo -n "ARP Replies: "
grep "ARP Reply" /tmp/fplf_minimal.log | wc -l
echo -n "Routes computed: "
grep "FPLF ROUTE" /tmp/fplf_minimal.log | wc -l

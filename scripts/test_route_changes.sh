#!/bin/bash
#
# Test FPLF Route Changes with Extreme Bandwidth Constraints
# This should finally show route_changed=YES entries!
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=============================================="
echo "  FPLF Route Change Test"
echo "  s1-s2: 100 Mbps | s2-s3: 100 Mbps"
echo "  s1-s3: 10 Mbps (BOTTLENECK!)"
echo "  6+ concurrent VIDEO streams via netcat"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo"
    exit 1
fi

# Get actual user for conda
ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

# Initialize conda
if [ -f "$USER_HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$USER_HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found"
    exit 1
fi

conda activate ml-sdn
cd "$PROJECT_ROOT"

# Clean old data
echo "Cleaning old monitoring data..."
rm -f data/fplf_monitoring/*.csv

echo "Starting FPLF controller..."
ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py \
    > data/fplf_monitoring/controller.log 2>&1 &
CONTROLLER_PID=$!
echo "Controller PID: $CONTROLLER_PID"

sleep 8

echo ""
echo "Starting mesh topology with VIDEO traffic..."
echo "This will run for 60 seconds..."
echo ""

# Run topology
/usr/bin/python3 topology/fplf_topo.py --topology mesh --controller-ip 127.0.0.1 --controller-port 6653 --traffic mixed --duration 60 &
TOPO_PID=$!

# Wait for test
wait $TOPO_PID

echo ""
echo "=============================================="
echo "  Test Complete!"
echo "=============================================="
echo ""

# Kill controller
kill $CONTROLLER_PID 2>/dev/null
sleep 2

# Cleanup
mn -c 2>/dev/null

echo "Results:"
echo ""
echo "=== Total routes logged ==="
wc -l data/fplf_monitoring/fplf_routes.csv

echo ""
echo "=== Route changes (route_changed=YES) ==="
CHANGED_COUNT=$(grep -c "YES" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
echo "Found: $CHANGED_COUNT route changes"

echo ""
echo "=== Sample entries with route_changed=YES ==="
grep "YES" data/fplf_monitoring/fplf_routes.csv | head -10 || echo "No route changes found"

echo ""
echo "=== All VIDEO traffic entries ==="
grep "VIDEO" data/fplf_monitoring/fplf_routes.csv | head -10 || echo "No VIDEO traffic found"

echo ""
echo "=== Link utilization (last 20 entries) ==="
tail -20 data/fplf_monitoring/link_utilization.csv

echo ""
echo "Full CSV files available at:"
echo "  - data/fplf_monitoring/fplf_routes.csv"
echo "  - data/fplf_monitoring/link_utilization.csv"
echo "  - data/fplf_monitoring/graph_weights.csv"
echo ""

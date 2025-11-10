#!/bin/bash
#
# Test FPLF with Mesh Topology to see route changes
# This topology has multiple paths, allowing FPLF to demonstrate optimization
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=============================================="
echo "  FPLF Mesh Topology Test"
echo "  Demonstrates route optimization"
echo "=============================================="
echo ""
echo "Topology:"
echo "      s1 ------- s2"
echo "       \\        /"
echo "        \\      /"
echo "         \\    /"
echo "          \\  /"
echo "           s3"
echo ""
echo "Multiple paths allow FPLF to:"
echo "  - Route around congested links"
echo "  - Balance load across paths"
echo "  - Prioritize high-priority traffic"
echo ""
echo "Expected results:"
echo "  - s1 -> s3: Can use s1->s3 OR s1->s2->s3"
echo "  - s2 -> s3: Can use s2->s3 OR s2->s1->s3"
echo "  - VIDEO traffic gets best path (lowest load)"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo"
    exit 1
fi

# Get the actual user (not root) to access their conda installation
ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

# Initialize conda for the actual user
if [ -f "$USER_HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$USER_HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found in $USER_HOME/anaconda3 or $USER_HOME/miniconda3"
    exit 1
fi

# Activate ml-sdn environment
conda activate ml-sdn

cd "$PROJECT_ROOT"

# Start controller in background
echo "Starting FPLF controller..."
ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py \
    > data/fplf_monitoring/controller.log 2>&1 &
CONTROLLER_PID=$!
echo "Controller PID: $CONTROLLER_PID"

# Wait for controller to start
echo "Waiting for controller to initialize..."
sleep 8

# Start mesh topology
echo ""
echo "Starting mesh topology with traffic generation..."
echo ""

# Use system python for mininet (not conda environment)
# Must use absolute path to avoid conda's python
/usr/bin/python3 topology/fplf_topo.py \
    --topology mesh \
    --controller-ip 127.0.0.1 \
    --controller-port 6653 \
    --traffic mixed \
    --duration 60 &

TOPO_PID=$!

# Wait for test to complete
wait $TOPO_PID

echo ""
echo "=============================================="
echo "  Test Complete!"
echo "=============================================="
echo ""
echo "Check results:"
echo "  cat data/fplf_monitoring/fplf_routes.csv"
echo ""
echo "Look for route_changed=YES entries!"
echo "These show where FPLF chose different paths than baseline routing."
echo ""

# Kill controller
kill $CONTROLLER_PID 2>/dev/null

# Cleanup
mn -c 2>/dev/null

echo "Displaying route changes:"
echo ""
grep "YES" data/fplf_monitoring/fplf_routes.csv || echo "No route changes found yet - may need more traffic or congestion"
echo ""

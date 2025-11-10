#!/bin/bash
# Test FPLF with HIGH traffic to force route changes

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

if [ -f "$USER_HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$USER_HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/miniconda3/etc/profile.d/conda.sh"
fi

conda activate ml-sdn
cd "$PROJECT_ROOT"

echo "Starting FPLF controller..."
ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py \
    > data/fplf_monitoring/controller.log 2>&1 &
CONTROLLER_PID=$!

sleep 8

echo "Starting mesh topology with HEAVY traffic..."
# Use lower bandwidth to create congestion faster
/usr/bin/python3 topology/fplf_topo.py \
    --topology mesh \
    --controller-ip 127.0.0.1 \
    --controller-port 6653 \
    --traffic mixed \
    --duration 90 &

TOPO_PID=$!
wait $TOPO_PID

echo ""
echo "Route changes found:"
grep "YES" data/fplf_monitoring/fplf_routes.csv || echo "No route changes - link utilization still too low"

kill $CONTROLLER_PID 2>/dev/null
mn -c 2>/dev/null

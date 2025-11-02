#!/bin/bash
# Controller that ignores common signals

echo "========================================="
echo "Controller with Signal Protection"
echo "========================================="

cd /home/hello/Desktop/ML_SDN

if [[ "$CONDA_DEFAULT_ENV" != "ml-sdn" ]]; then
    echo "ERROR: Not in ml-sdn environment!"
    exit 1
fi

echo "✓ Environment: $CONDA_DEFAULT_ENV"
echo ""
echo "Starting controller..."
echo "This controller will IGNORE Mininet shutdown signals"
echo ""
echo "To stop: Press Ctrl+C twice"
echo ""

# Trap signals to prevent accidental shutdown
trap 'echo "Received signal, ignoring... (Press Ctrl+C again to really stop)"' SIGTERM SIGINT

# Run controller in background with signal trapping
(
    trap '' SIGTERM SIGHUP
    ryu-manager src/controller/sdn_controller.py --verbose
) &

CONTROLLER_PID=$!
echo "Controller PID: $CONTROLLER_PID"

# Wait for controller
wait $CONTROLLER_PID

echo ""
echo "Controller exited"

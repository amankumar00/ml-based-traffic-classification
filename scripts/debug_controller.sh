#!/bin/bash
# Debug controller with full error logging

echo "========================================="
echo "Controller Debug Mode"
echo "========================================="

cd /home/hello/Desktop/ML_SDN

# Check environment
if [[ "$CONDA_DEFAULT_ENV" != "ml-sdn" ]]; then
    echo "ERROR: Not in ml-sdn environment!"
    exit 1
fi

echo "✓ Environment: $CONDA_DEFAULT_ENV"

# Clean old data
rm -f controller_debug.log controller_error.log

echo ""
echo "Starting controller with full logging..."
echo "Output will be saved to controller_debug.log"
echo "Errors will be saved to controller_error.log"
echo ""
echo "In another terminal, run:"
echo "  cd /home/hello/Desktop/ML_SDN"
echo "  sudo mn -c"
echo "  sudo -E env \"PYTHONPATH=/usr/lib/python3/dist-packages:\$PYTHONPATH\" python3 topology/custom_topo.py --topology linear --traffic icmp --duration 45"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Run with both stdout and stderr captured
ryu-manager src/controller/sdn_controller.py --verbose 2>&1 | tee controller_debug.log

# Check exit status
EXIT_CODE=$?
echo ""
echo "Controller exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: Controller crashed!"
    echo ""
    echo "Last 30 lines of output:"
    tail -30 controller_debug.log
fi

#!/bin/bash
# Safe controller startup with environment checks

echo "========================================="
echo "Starting Ryu Controller with Checks"
echo "========================================="

# Check if in ml-sdn environment
if [[ "$CONDA_DEFAULT_ENV" != "ml-sdn" ]]; then
    echo "ERROR: Not in ml-sdn environment!"
    echo "Current environment: $CONDA_DEFAULT_ENV"
    echo ""
    echo "Please run:"
    echo "  conda activate ml-sdn"
    echo "  ./scripts/start_controller.sh"
    exit 1
fi

echo "✓ Conda environment: $CONDA_DEFAULT_ENV"

# Check Python version
PYTHON_VERSION=$(python --version 2>&1)
echo "✓ $PYTHON_VERSION"

# Check if Ryu is available
if ! python -c "from ryu.cmd.manager import main" 2>/dev/null; then
    echo "ERROR: Ryu not found!"
    echo "Try: pip install --force-reinstall ryu==4.34"
    exit 1
fi

echo "✓ Ryu is available"

# Check data directory
if [ ! -d "data/raw" ]; then
    echo "Creating data/raw directory..."
    mkdir -p data/raw
fi

echo "✓ Data directory exists"

# Check for old controller processes
if pgrep -f "ryu-manager.*sdn_controller" > /dev/null; then
    echo "WARNING: Controller already running!"
    echo "PIDs: $(pgrep -f 'ryu-manager.*sdn_controller')"
    read -p "Kill and restart? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "ryu-manager.*sdn_controller"
        sleep 2
    else
        exit 1
    fi
fi

echo ""
echo "========================================="
echo "Starting Controller..."
echo "========================================="
echo ""
echo "Watch for these messages:"
echo "  1. 'loading app src/controller/sdn_controller.py'"
echo "  2. 'BRICK TrafficMonitorController'"
echo "  3. When Mininet connects: 'Switch connected: ...'"
echo "  4. Every 30 seconds: 'Periodic save completed'"
echo ""
echo "Press Ctrl+C to stop"
echo ""

cd /home/hello/Desktop/ML_SDN
ryu-manager src/controller/sdn_controller.py --verbose

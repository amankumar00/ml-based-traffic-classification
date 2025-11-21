#!/bin/bash
#
# Test FPLF with Phased Traffic Generation
# Demonstrates adaptive behavior with temporal variation
#
# Phase 1 (0-20s): Light traffic - HTTP + SSH only
# Phase 2 (20-40s): Medium traffic - Add FTP
# Phase 3 (40-60s): Heavy traffic - Add VIDEO
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  FPLF PHASED TRAFFIC TEST"
echo "  Demonstrating FPLF Adaptive Behavior with Temporal Variation"
echo "=========================================================================="
echo ""
echo "Traffic phases:"
echo "  Phase 1 (0-20s):  Light traffic  - HTTP + SSH     → 2-3 active links"
echo "  Phase 2 (20-40s): Medium traffic - + FTP          → 4-5 active links"
echo "  Phase 3 (40-60s): Heavy traffic  - + VIDEO        → 5-6 active links"
echo ""
echo "Expected results:"
echo "  - Energy graphs show variation over time (not flat lines)"
echo "  - Active links increase from phase 1 → 3"
echo "  - Energy savings decrease from phase 1 → 3"
echo "=========================================================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo"
    exit 1
fi

# Get actual user for conda
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER="$USER"
fi
USER_HOME="/home/$ACTUAL_USER"

# Initialize conda
CONDA_SH=""
if [ -f "$USER_HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    CONDA_SH="$USER_HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "$USER_HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    CONDA_SH="$USER_HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found at $USER_HOME/anaconda3 or $USER_HOME/miniconda3"
    echo "   Trying to use system Python and ryu-manager..."
fi

if [ -n "$CONDA_SH" ]; then
    source "$CONDA_SH"
    conda activate ml-sdn
fi

cd "$PROJECT_ROOT"

# Clean old data
echo "1. Cleaning old monitoring data..."
rm -f data/fplf_monitoring/*.csv
rm -rf data/fplf_monitoring/graphs/
echo "   ✓ Old data removed"
echo ""

echo "2. Starting FPLF controller..."
ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py \
    > data/fplf_monitoring/controller.log 2>&1 &
CONTROLLER_PID=$!
echo "   Controller PID: $CONTROLLER_PID"
echo ""

sleep 8

echo "3. Starting mesh topology with PHASED traffic..."
echo "   (This will run for 60 seconds with 3 distinct phases)"
echo ""

# Run topology with phased traffic
/usr/bin/python3 topology/fplf_topo.py --topology mesh --controller-ip 127.0.0.1 --controller-port 6653 --traffic phased --duration 60 &
TOPO_PID=$!

# Wait for test
wait $TOPO_PID

echo ""
echo "=========================================================================="
echo "  Test Complete!"
echo "=========================================================================="
echo ""

# Kill controller
echo "4. Stopping controller..."
kill $CONTROLLER_PID 2>/dev/null
sleep 2

# Cleanup
echo "5. Cleaning up Mininet..."
mn -c 2>/dev/null
echo ""

echo "=========================================================================="
echo "  RESULTS SUMMARY"
echo "=========================================================================="
echo ""

# Check if energy data was generated
if [ -f data/fplf_monitoring/energy_consumption.csv ]; then
    LINES=$(wc -l < data/fplf_monitoring/energy_consumption.csv)
    if [ "$LINES" -gt 1 ]; then
        echo "✓ Energy data collected: $((LINES - 1)) measurements"
        echo ""

        # Show sample data from different phases
        echo "=== Energy data samples (showing phase variation) ==="
        echo ""
        echo "First 5 entries (Phase 1 - Light traffic):"
        head -6 data/fplf_monitoring/energy_consumption.csv | column -t -s,
        echo ""

        echo "Middle entries (Phase 2 - Medium traffic):"
        MIDDLE_LINE=$((LINES / 2))
        head -$((MIDDLE_LINE + 3)) data/fplf_monitoring/energy_consumption.csv | tail -5 | column -t -s,
        echo ""

        echo "Last 5 entries (Phase 3 - Heavy traffic):"
        tail -5 data/fplf_monitoring/energy_consumption.csv | column -t -s,
        echo ""
    else
        echo "✗ Energy CSV is empty (only headers)"
        echo "  Check controller log for topology discovery issues"
    fi
else
    echo "✗ Energy CSV not created"
fi

echo ""
echo "=========================================================================="
echo "  NEXT STEPS"
echo "=========================================================================="
echo ""
echo "1. Generate graphs to visualize the phased traffic:"
echo "   python3 scripts/generate_energy_graphs.py"
echo ""
echo "2. Check the graphs in data/fplf_monitoring/graphs/"
echo "   - active_links_over_time.png (should show 3 distinct levels)"
echo "   - energy_savings_over_time.png (should show variation, not flat)"
echo ""
echo "3. View summary statistics:"
echo "   cat data/fplf_monitoring/graphs/summary_statistics.csv"
echo ""
echo "Expected graph pattern:"
echo "  Savings %"
echo "    40% |████          "
echo "    30% |█████         "
echo "    20% |██████        "
echo "    10% |███████████   "
echo "     0% |████████████████"
echo "        └───────────────────> Time (s)"
echo "         0   20   40   60"
echo "        P1   P2   P3"
echo ""


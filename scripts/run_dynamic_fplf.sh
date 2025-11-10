#!/bin/bash
#
# Run Dynamic FPLF Controller with Custom Topology
# This script demonstrates the FPLF algorithm with real-time link monitoring
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=============================================="
echo "  Dynamic FPLF Controller Demonstration"
echo "=============================================="
echo ""

# Activate conda environment (ml-sdn)
if ! command -v conda &> /dev/null; then
    echo "❌ Conda not found!"
    echo "Please install conda or activate ml-sdn environment manually"
    exit 1
fi

# Initialize conda for bash
eval "$(conda shell.bash hook)"

# Activate ml-sdn conda environment
conda activate ml-sdn

# Check if Ryu is installed
if ! python -c "import ryu" 2>/dev/null; then
    echo "❌ Ryu controller not found in ml-sdn environment!"
    echo "Please install: conda activate ml-sdn && pip install ryu"
    exit 1
fi

# Create data directory for monitoring output
mkdir -p "$PROJECT_ROOT/data/fplf_monitoring"

echo "✓ Environment ready"
echo ""
echo "Starting Dynamic FPLF Controller..."
echo "Controller: src/controller/dynamic_fplf_controller.py"
echo "Monitoring data will be saved to: data/fplf_monitoring/"
echo ""
echo "Features:"
echo "  - Real-time port statistics monitoring"
echo "  - Dynamic link weight updates based on utilization"
echo "  - Dijkstra-based path computation"
echo "  - CSV export of link utilization and routes"
echo ""
echo "Weight Formula:"
echo "  - Idle (uti=0):      weight = 500"
echo "  - Active (0<uti<0.9): weight = 499 - (0.9 - uti)"
echo "  - Congested (uti≥0.9): weight = 1000"
echo ""
echo "Press Ctrl+C to stop the controller"
echo "=============================================="
echo ""

# Run Ryu controller with verbose logging (using conda ml-sdn environment)
cd "$PROJECT_ROOT"
ryu-manager --verbose \
    --observe-links \
    src/controller/dynamic_fplf_controller.py

echo ""
echo "Controller stopped."
echo ""
echo "Monitoring data saved in: data/fplf_monitoring/"
echo "  - link_utilization.csv: Link utilization over time"
echo "  - fplf_routes.csv: Routing decisions"
echo "  - graph_weights.csv: Graph edge weights"

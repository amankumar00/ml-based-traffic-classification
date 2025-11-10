#!/bin/bash
#
# Complete FPLF Demonstration Script
# Runs both the controller and Mininet topology with traffic generation
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================="
echo "  Dynamic FPLF Complete Demonstration"
echo -e "==============================================${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"

    # Kill Ryu controller if running
    pkill -f "ryu-manager.*dynamic_fplf_controller" 2>/dev/null || true

    # Clean up Mininet
    sudo mn -c 2>/dev/null || true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT

# Check requirements
echo -e "${BLUE}Checking requirements...${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run with sudo${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if conda is available and ml-sdn environment exists
if ! command -v conda &> /dev/null; then
    echo -e "${RED}❌ Conda not found${NC}"
    exit 1
fi

# Initialize conda for bash
eval "$(conda shell.bash hook)"

# Check if ml-sdn environment exists
if ! conda env list | grep -q "ml-sdn"; then
    echo -e "${RED}❌ Conda environment 'ml-sdn' not found${NC}"
    exit 1
fi

# Activate ml-sdn environment
conda activate ml-sdn

if ! command -v mn &> /dev/null; then
    echo -e "${RED}❌ Mininet not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All requirements met${NC}"
echo ""

# Create monitoring directory
mkdir -p "$PROJECT_ROOT/data/fplf_monitoring"

# Step 1: Start Ryu Controller
echo -e "${BLUE}Step 1: Starting Ryu Controller${NC}"
echo "Controller: dynamic_fplf_controller.py"
echo "Waiting for controller to initialize..."
echo ""

cd "$PROJECT_ROOT"
ryu-manager --verbose --observe-links \
    src/controller/dynamic_fplf_controller.py \
    > "$PROJECT_ROOT/data/fplf_monitoring/controller.log" 2>&1 &

CONTROLLER_PID=$!
echo "Controller PID: $CONTROLLER_PID"

# Wait for controller to start
sleep 5

if ! ps -p $CONTROLLER_PID > /dev/null; then
    echo -e "${RED}❌ Controller failed to start${NC}"
    echo "Check logs: data/fplf_monitoring/controller.log"
    exit 1
fi

echo -e "${GREEN}✓ Controller started${NC}"
echo ""

# Step 2: Start Mininet Topology
echo -e "${BLUE}Step 2: Starting Mininet Topology${NC}"
echo "Topology: custom_topo.py (3 switches, 9 hosts)"
echo "Controller: 127.0.0.1:6653"
echo ""

python3 "$PROJECT_ROOT/topology/custom_topo.py" \
    --topology custom \
    --controller-ip 127.0.0.1 \
    --controller-port 6653 \
    --traffic mixed \
    --duration 120 &

MININET_PID=$!
echo "Mininet PID: $MININET_PID"
echo ""

# Wait for topology to be established
echo -e "${YELLOW}Waiting 10 seconds for topology discovery...${NC}"
sleep 10

echo ""
echo -e "${BLUE}Step 3: Generating Traffic${NC}"
echo "Traffic types: ICMP (ping), HTTP, FTP, SSH, iPerf"
echo "Duration: 120 seconds"
echo ""
echo -e "${GREEN}✓ Traffic generation started${NC}"
echo ""

# Monitor for a while
echo -e "${BLUE}Monitoring FPLF behavior...${NC}"
echo "Press Ctrl+C to stop early, or wait 120 seconds"
echo ""
echo "Real-time monitoring data:"
echo "  - Link utilization: data/fplf_monitoring/link_utilization.csv"
echo "  - Routes: data/fplf_monitoring/fplf_routes.csv"
echo "  - Controller logs: data/fplf_monitoring/controller.log"
echo ""

# Wait for traffic generation to complete
wait $MININET_PID 2>/dev/null || true

echo ""
echo -e "${GREEN}=============================================="
echo "  Demonstration Complete!"
echo -e "==============================================${NC}"
echo ""
echo "Results saved to: $PROJECT_ROOT/data/fplf_monitoring/"
echo ""
echo "Files:"
echo "  - link_utilization.csv: Link usage over time"
echo "  - fplf_routes.csv: Routing decisions"
echo "  - controller.log: Full controller logs"
echo ""
echo "You can analyze these files to see how FPLF adapted routes"
echo "based on link utilization."
echo ""

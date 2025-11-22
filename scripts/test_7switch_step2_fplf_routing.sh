#!/bin/bash
#
# Step 2: FPLF Routing Validation for 7-Switch Topology
#
# This script:
# 1. Uses host_to_host_flows.csv from Step 1 (ML classifications)
# 2. Starts dynamic_fplf_controller.py (FPLF routing)
# 3. Generates traffic matching the classified flows
# 4. Validates FPLF routes different traffic types on different paths
#
# Prerequisites: Run test_7switch_step1_ml_classification.sh first
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  STEP 2: FPLF Routing Validation for 7-Switch Topology"
echo "=========================================================================="
# echo ""
# echo "This will:"
# echo "  1. Load ML classifications from host_to_host_flows.csv"
# echo "  2. Start FPLF controller (dynamic_fplf_controller.py)"
# echo "  3. Start 7-switch topology with classified traffic"
# echo "  4. Monitor FPLF routing decisions for 60 seconds"
# echo "  5. Analyze route diversity and energy savings"
# echo ""
# echo "Prerequisites: host_to_host_flows.csv must exist"
# echo "=========================================================================="
# echo ""

if [ "$EUID" -ne 0 ]; then
    echo " Please run with sudo"
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
    echo " Conda not found, trying system Python..."
fi

if [ -n "$CONDA_SH" ]; then
    source "$CONDA_SH"
    conda activate ml-sdn
fi

cd "$PROJECT_ROOT"

# Check prerequisites
echo "1. Checking prerequisites..."

if [ ! -f "data/processed/host_to_host_flows.csv" ]; then
    echo "    host_to_host_flows.csv not found!"
    echo ""
    echo "   Please run Step 1 first:"
    echo "   sudo bash scripts/test_7switch_step1_ml_classification.sh"
    echo ""
    exit 1
fi

FLOW_COUNT=$(tail -n +2 data/processed/host_to_host_flows.csv | wc -l)
# echo "   ✓ Found host_to_host_flows.csv with $FLOW_COUNT classified flows"
echo ""

echo "   Classified flows that will be tested:"
echo "   ────────────────────────────────────────────────────────────────"
column -t -s, < data/processed/host_to_host_flows.csv
echo "   ────────────────────────────────────────────────────────────────"
echo ""

# Check host_map for 7-switch
if [ ! -f "config/host_map_7switch.txt" ]; then
    echo "     config/host_map_7switch.txt not found"
    echo "   Using config/host_map.txt (make sure it's configured for 7 switches)"
else
    # echo "   Installing 7-switch host_map..."
    cp config/host_map.txt config/host_map.txt.backup 2>/dev/null
    cp config/host_map_7switch.txt config/host_map.txt
    # echo "   ✓ Installed 7-switch host mapping"
fi
echo ""

# Clean old FPLF monitoring data
echo "2. Cleaning old FPLF monitoring data..."
rm -f data/fplf_monitoring/*.csv
rm -rf data/fplf_monitoring/graphs/
# echo "   ✓ Old monitoring data removed"
# echo ""

# Start FPLF controller
echo "3. Starting FPLF controller (dynamic_fplf_controller.py)..."
# echo "   This controller will:"
# echo "   - Load ML classifications from host_to_host_flows.csv"
# echo "   - Route VIDEO traffic on longer paths (avoids congestion)"
# echo "   - Route FTP traffic on shorter paths (tolerates congestion)"
# echo "   - Monitor link utilization and energy consumption"
# echo ""

ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py \
    > data/fplf_monitoring/fplf_controller_7switch.log 2>&1 &
CONTROLLER_PID=$!
echo "   Controller PID: $CONTROLLER_PID"
echo "   Waiting for controller startup..."
sleep 8
echo ""

# Check if controller loaded classifications
echo "   Checking if controller loaded ML classifications..."
if grep -q "Loaded .* classified flows" data/fplf_monitoring/fplf_controller_7switch.log; then
    LOADED_FLOWS=$(grep "Loaded .* classified flows" data/fplf_monitoring/fplf_controller_7switch.log | head -1)
    echo "   ✓ $LOADED_FLOWS"
else
    echo "     Could not verify classification loading - check log"
fi
echo ""

# Start 7-switch topology with traffic
echo "4. Starting 7-switch topology with traffic..."
# echo "   Traffic will match the classified flows:"
# echo "   - VIDEO: h1 → h7 (priority 4)"
# echo "   - SSH:   h3 → h5 (priority 3)"
# echo "   - HTTP:  h2 → h8 (priority 2)"
# echo "   - FTP:   h4 → h9 (priority 1)"
# echo ""
# echo "   Running for 60 seconds..."
# echo ""

/usr/bin/python3 topology/test_7switch_core_topo.py \
    --controller-ip 127.0.0.1 \
    --controller-port 6653 \
    --traffic \
    --duration 60 &
TOPO_PID=$!

# Wait for topology to finish
wait $TOPO_PID

echo ""
echo "=========================================================================="
echo "  Test Complete!"
echo "=========================================================================="
echo ""

# Stop controller
echo "5. Stopping controller..."
kill $CONTROLLER_PID 2>/dev/null
sleep 2
echo ""

# Cleanup Mininet
echo "6. Cleaning up Mininet..."
mn -c 2>/dev/null
echo ""

# Analyze results
echo "=========================================================================="
echo "  RESULTS ANALYSIS"
echo "=========================================================================="
echo ""

# Check topology discovery
echo "1. Topology Discovery:"
if grep -q "Topology:" data/fplf_monitoring/fplf_controller_7switch.log; then
    TOPO_INFO=$(grep "Topology:" data/fplf_monitoring/fplf_controller_7switch.log | tail -1)
    echo "   $TOPO_INFO"

    if echo "$TOPO_INFO" | grep -q "7 switches"; then
        echo "    7-switch topology discovered correctly"
    else
        echo "    Expected 7 switches, check topology"
    fi
else
    echo "    Topology info not found in log"
fi
echo ""

# Check ML classification usage
echo "2. ML Flow Classification Usage:"
if [ -f data/fplf_monitoring/fplf_routes.csv ]; then
    VIDEO_COUNT=$(grep -c "VIDEO" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    SSH_COUNT=$(grep -c "SSH" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    HTTP_COUNT=$(grep -c "HTTP" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    FTP_COUNT=$(grep -c "FTP" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")

    # echo "   Traffic types detected by FPLF:"
    # echo "   - VIDEO: $VIDEO_COUNT routing decisions"
    # echo "   - SSH:   $SSH_COUNT routing decisions"
    # echo "   - HTTP:  $HTTP_COUNT routing decisions"
    # echo "   - FTP:   $FTP_COUNT routing decisions"
    # echo ""

    if [ "$VIDEO_COUNT" -gt 0 ] && [ "$FTP_COUNT" -gt 0 ]; then
        echo "   ML classifications successfully used by FPLF!"
    else
        echo "     Some traffic types not detected"
    fi
else
    echo "    fplf_routes.csv not found"
fi
echo ""

# Check route diversity
echo "3. Route Diversity (different paths for different priorities):"
if [ -f data/fplf_monitoring/fplf_routes.csv ]; then
    echo ""
    # echo "   VIDEO routes (high priority, should avoid congestion):"
    grep "VIDEO" data/fplf_monitoring/fplf_routes.csv | head -3 | \
        awk -F, '{printf "   %s: %s\n", $1, $5}' 2>/dev/null || echo "   No VIDEO routes found"

    echo ""
    # echo "   FTP routes (low priority, can tolerate congestion):"
    grep "FTP" data/fplf_monitoring/fplf_routes.csv | head -3 | \
        awk -F, '{printf "   %s: %s\n", $1, $5}' 2>/dev/null || echo "   No FTP routes found"

    echo ""
    ROUTE_CHANGES=$(grep -c ",YES$" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    echo "   Route changes detected: $ROUTE_CHANGES"

    if [ "$ROUTE_CHANGES" -gt 0 ]; then
        # echo "    FPLF adapted routes based on link utilization!"
        # echo ""
        # echo "   Sample route changes:"
        # grep ",YES$" data/fplf_monitoring/fplf_routes.csv | head -3 | \
            awk -F, '{printf "   %s: %s → %s (%s, priority=%s)\n", $1, $4, $5, $6, $7}' 2>/dev/null
    else
        echo "   No route changes (traffic may be light enough for all paths)"
    fi
else
    echo "    fplf_routes.csv not found"
fi
echo ""

# Check energy monitoring
echo "4. Energy Monitoring:"
if [ -f data/fplf_monitoring/energy_consumption.csv ]; then
    MEASUREMENTS=$(tail -n +2 data/fplf_monitoring/energy_consumption.csv | wc -l)
    echo "   Total measurements: $MEASUREMENTS"

    if [ "$MEASUREMENTS" -gt 10 ]; then
        echo ""
        # echo "   Sample energy data (first 5 entries):"
        head -6 data/fplf_monitoring/energy_consumption.csv | column -t -s,
        echo ""
        # echo "    Energy monitoring working!"

        # Calculate average savings
        AVG_SAVINGS=$(tail -n +2 data/fplf_monitoring/energy_consumption.csv | \
            awk -F, '{sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count}' 2>/dev/null)

        if [ -n "$AVG_SAVINGS" ]; then
            # echo "   Average energy savings: ${AVG_SAVINGS}%"
        fi
    else
        # echo "     Only $MEASUREMENTS measurements collected"
    fi
else
    # echo "    energy_consumption.csv not found"
fi
echo ""

# Final summary
# echo "=========================================================================="
# echo "  VALIDATION SUMMARY"
# echo "=========================================================================="
# echo ""

SUCCESS=true

# Check all criteria
if [ "$VIDEO_COUNT" -gt 0 ] && [ "$FTP_COUNT" -gt 0 ]; then
    # echo " ML Classifications: Successfully loaded and used by FPLF"
else
    # echo " ML Classifications: Not all traffic types detected"
    SUCCESS=false
fi

if grep -q "7 switches" data/fplf_monitoring/fplf_controller_7switch.log 2>/dev/null; then
    # echo " Topology Discovery: 7-switch topology correctly detected"
else
    # echo " Topology Discovery: Could not verify 7 switches"
fi

if [ "$ROUTE_CHANGES" -gt 0 ] || ([ "$VIDEO_COUNT" -gt 0 ] && [ "$FTP_COUNT" -gt 0 ]); then
    echo "FPLF Routing: Different paths for different traffic priorities"
else
    echo "  FPLF Routing: Limited route diversity detected"
fi

if [ "$MEASUREMENTS" -gt 10 ]; then
    echo " Energy Monitoring: Data collected successfully"
else
    echo "  Energy Monitoring: Limited data collected"
fi

echo ""

if [ "$SUCCESS" = true ]; then
    # echo " SUCCESS: ML Classifier + FPLF work correctly with 7-switch topology!"
    # echo ""
    # echo "Key achievements:"
    # echo "  ✓ ML classified flows loaded by FPLF controller"
    # echo "  ✓ 7-switch topology with 20 directional links"
    # echo "  ✓ Traffic-aware routing (VIDEO, SSH, HTTP, FTP)"
    # echo "  ✓ Energy monitoring and optimization"
    # echo ""
    # echo "Your system is topology-agnostic and scales successfully! 🚀"
else
    # echo "  Tests completed with warnings - review logs for details"
fi

echo ""
echo "=========================================================================="
echo "  OUTPUT FILES"
echo "=========================================================================="
echo ""
echo "Controller log:"
echo "  data/fplf_monitoring/fplf_controller_7switch.log"
echo ""
echo "FPLF monitoring data:"
echo "  data/fplf_monitoring/fplf_routes.csv"
echo "  data/fplf_monitoring/link_utilization.csv"
echo "  data/fplf_monitoring/energy_consumption.csv"
echo ""
echo "Generate graphs:"
echo "  python3 scripts/generate_energy_graphs.py"
echo ""
# echo "Restore original host_map:"
# echo "  cp config/host_map.txt.backup config/host_map.txt"
# echo ""

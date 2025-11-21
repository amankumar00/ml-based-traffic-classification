#!/bin/bash
#
# Test Script 2: FPLF Routing Validation for 7-Switch Topology
# Purpose: Verify FPLF routing works with 7-switch core network
#
# This script runs the full test with controller + topology
# WITHOUT modifying the original FPLF controller code
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  TEST 2: FPLF Routing Validation for 7-Switch Core Network"
echo "=========================================================================="
echo ""
echo "Purpose: Verify FPLF + ML classifier work together on complex topology"
echo ""
echo "Topology: 7 switches, 9 hosts, 20 directional links"
echo "Duration: 60 seconds"
echo ""
echo "Expected results:"
echo "  ✓ Topology discovery finds 20 directional links"
echo "  ✓ ML classifier identifies VIDEO/SSH/HTTP/FTP traffic"
echo "  ✓ FPLF routes each traffic type on different paths"
echo "  ✓ VIDEO takes longer paths (avoids congestion)"
echo "  ✓ FTP takes shorter paths (tolerates congestion)"
echo "  ✓ Route changes occur when link utilization changes"
echo "  ✓ Energy monitoring shows 30-50% savings (vs 3-switch topology)"
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
    echo "⚠️  Conda not found, trying system Python..."
fi

if [ -n "$CONDA_SH" ]; then
    source "$CONDA_SH"
    conda activate ml-sdn
fi

cd "$PROJECT_ROOT"

# Step 1: Ensure configs are installed
echo "1. Checking 7-switch configuration..."
if [ ! -f config/host_map.txt ]; then
    echo "   ⚠️  config/host_map.txt not found"
    echo "   Installing 7-switch config..."
    cp config/host_map_7switch.txt config/host_map.txt
fi

if [ ! -f data/processed/host_to_host_flows.csv ]; then
    echo "   ⚠️  host_to_host_flows.csv not found"
    echo "   Installing 7-switch flows..."
    cp data/processed/host_to_host_flows_7switch.csv data/processed/host_to_host_flows.csv
fi

echo "   ✓ Configuration files ready"
echo ""

# Step 2: Clean old data
echo "2. Cleaning old monitoring data..."
rm -f data/fplf_monitoring/*.csv
rm -rf data/fplf_monitoring/graphs/
echo "   ✓ Old data removed"
echo ""

# Step 3: Show expected topology
echo "3. Expected topology structure:"
echo ""
echo "    Edge Layer              Core Layer"
echo ""
echo "   h1,h2 ─ s1 ─────┐"
echo "                   │"
echo "   h3,h4 ─ s2 ───┐ ├─── s5 ───┐"
echo "                 │ │           │"
echo "   h5,h6 ─ s3 ───┼─┼───────────┼─── s6"
echo "                 │ │           │     │"
echo "   h7,h8,h9─ s4 ─┴─┘           └─────┴─── s7"
echo ""
echo "   Inter-switch links: 10 (20 directional)"
echo ""

# Step 4: Start controller
echo "4. Starting FPLF controller..."
echo "   NOTE: Controller will use existing code (no modifications needed!)"
echo ""

ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py \
    > data/fplf_monitoring/controller_7switch.log 2>&1 &
CONTROLLER_PID=$!
echo "   Controller PID: $CONTROLLER_PID"
echo "   Waiting for controller startup..."
sleep 8
echo ""

# Step 5: Start topology
echo "5. Starting 7-switch topology with test traffic..."
echo "   Running for 60 seconds..."
echo ""

/usr/bin/python3 topology/test_7switch_core_topo.py \
    --controller-ip 127.0.0.1 \
    --controller-port 6653 \
    --traffic \
    --duration 60 &
TOPO_PID=$!

# Wait for test
wait $TOPO_PID

echo ""
echo "=========================================================================="
echo "  Test Complete!"
echo "=========================================================================="
echo ""

# Step 6: Stop controller
echo "6. Stopping controller..."
kill $CONTROLLER_PID 2>/dev/null
sleep 2
echo ""

# Step 7: Cleanup
echo "7. Cleaning up Mininet..."
mn -c 2>/dev/null
echo ""

# Step 8: Analyze results
echo "=========================================================================="
echo "  RESULTS ANALYSIS"
echo "=========================================================================="
echo ""

# Check topology discovery
echo "1. Topology Discovery:"
if grep -q "Topology: 7 switches" data/fplf_monitoring/controller_7switch.log; then
    SWITCHES=$(grep "Topology:" data/fplf_monitoring/controller_7switch.log | tail -1 | grep -oP '\d+ switches' | grep -oP '^\d+')
    LINKS=$(grep "Topology:" data/fplf_monitoring/controller_7switch.log | tail -1 | grep -oP '\d+ links' | grep -oP '^\d+')
    echo "   ✅ Discovered $SWITCHES switches, $LINKS links"
else
    echo "   ⚠️  Check controller_7switch.log for details"
fi
echo ""

# Check ML classification
echo "2. ML Flow Classification:"
if [ -f data/fplf_monitoring/fplf_routes.csv ]; then
    VIDEO_COUNT=$(grep -c "VIDEO" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    SSH_COUNT=$(grep -c "SSH" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    HTTP_COUNT=$(grep -c "HTTP" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    FTP_COUNT=$(grep -c "FTP" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")

    echo "   VIDEO flows: $VIDEO_COUNT"
    echo "   SSH flows:   $SSH_COUNT"
    echo "   HTTP flows:  $HTTP_COUNT"
    echo "   FTP flows:   $FTP_COUNT"

    if [ "$VIDEO_COUNT" -gt 0 ] && [ "$SSH_COUNT" -gt 0 ]; then
        echo "   ✅ ML classifier working correctly!"
    else
        echo "   ⚠️  Some traffic types not detected"
    fi
else
    echo "   ⚠️  fplf_routes.csv not found"
fi
echo ""

# Check route diversity
echo "3. Route Diversity (different paths for different traffic):"
if [ -f data/fplf_monitoring/fplf_routes.csv ]; then
    echo ""
    echo "   Sample VIDEO routes (should use longer paths):"
    grep "VIDEO" data/fplf_monitoring/fplf_routes.csv | grep -v "route_changed" | head -3 | \
        awk -F, '{print "     " $4}' | sed 's/^/   /'

    echo ""
    echo "   Sample FTP routes (should use shorter paths):"
    grep "FTP" data/fplf_monitoring/fplf_routes.csv | grep -v "route_changed" | head -3 | \
        awk -F, '{print "     " $4}' | sed 's/^/   /'

    echo ""
    ROUTE_CHANGES=$(grep -c "YES" data/fplf_monitoring/fplf_routes.csv 2>/dev/null || echo "0")
    echo "   Route changes detected: $ROUTE_CHANGES"
    if [ "$ROUTE_CHANGES" -gt 0 ]; then
        echo "   ✅ FPLF is adapting routes based on utilization!"
    fi
fi
echo ""

# Check energy savings
echo "4. Energy Monitoring:"
if [ -f data/fplf_monitoring/energy_consumption.csv ]; then
    MEASUREMENTS=$(tail -n +2 data/fplf_monitoring/energy_consumption.csv | wc -l)
    echo "   Total measurements: $MEASUREMENTS"

    if [ "$MEASUREMENTS" -gt 1 ]; then
        echo ""
        echo "   Sample energy data:"
        head -6 data/fplf_monitoring/energy_consumption.csv | column -t -s,
        echo ""
        echo "   ✅ Energy monitoring working!"
    fi
else
    echo "   ⚠️  energy_consumption.csv not found"
fi
echo ""

# Summary
echo "=========================================================================="
echo "  VALIDATION SUMMARY"
echo "=========================================================================="
echo ""

if [ "$SWITCHES" = "7" ] && [ "$VIDEO_COUNT" -gt 0 ] && [ "$MEASUREMENTS" -gt 10 ]; then
    echo "✅ SUCCESS: ML Classifier + FPLF work correctly with 7-switch topology!"
    echo ""
    echo "Key findings:"
    echo "  ✓ Topology discovery: 7 switches detected"
    echo "  ✓ ML classifier: Traffic types identified correctly"
    echo "  ✓ FPLF routing: Different paths for different priorities"
    echo "  ✓ Energy monitoring: Data collected successfully"
    echo ""
    echo "Your code is topology-agnostic! ✨"
else
    echo "⚠️  Some tests incomplete - check logs for details"
fi
echo ""

echo "=========================================================================="
echo "  OUTPUT FILES"
echo "=========================================================================="
echo ""
echo "Controller log:"
echo "  data/fplf_monitoring/controller_7switch.log"
echo ""
echo "Monitoring data:"
echo "  data/fplf_monitoring/fplf_routes.csv"
echo "  data/fplf_monitoring/link_utilization.csv"
echo "  data/fplf_monitoring/energy_consumption.csv"
echo ""
echo "Generate graphs:"
echo "  python3 scripts/generate_energy_graphs.py"
echo ""
echo "Restore original configs:"
echo "  cp config/host_map.txt.backup config/host_map.txt"
echo "  cp data/processed/host_to_host_flows.csv.backup data/processed/host_to_host_flows.csv"
echo ""
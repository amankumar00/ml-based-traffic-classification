#!/bin/bash
#
# Step 1: ML Traffic Classification for 7-Switch Topology
#
# This script:
# 1. Starts the 7-switch topology
# 2. Runs sdn_controller.py (traffic monitoring for ML)
# 3. Generates traffic to collect packet data
# 4. Runs ML classifier to generate host_to_host_flows.csv
#
# Output: data/processed/host_to_host_flows.csv with classified flows
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  STEP 1: ML Traffic Classification for 7-Switch Topology"
echo "=========================================================================="
echo ""
echo "This will:"
echo "  1. Start SDN controller (sdn_controller.py) for packet capture"
echo "  2. Start 7-switch topology with traffic generation"
echo "  3. Collect packet data for 60 seconds"
echo "  4. Run ML classifier to generate flow classifications"
echo ""
echo "Output: data/processed/host_to_host_flows.csv"
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

# Clean old data
echo "1. Cleaning old packet capture data..."
rm -f data/raw/captured_packets_*.json
rm -f data/raw/flow_stats_*.json
echo "   ✓ Old packet data removed"
echo ""

# Start SDN controller for traffic monitoring
echo "2. Starting SDN controller (sdn_controller.py) for packet capture..."
ryu-manager --verbose src/controller/sdn_controller.py \
    > data/raw/sdn_controller_7switch.log 2>&1 &
CONTROLLER_PID=$!
echo "   Controller PID: $CONTROLLER_PID"
echo "   Waiting for controller startup..."
sleep 8
echo ""

# Start 7-switch topology with traffic
echo "3. Starting 7-switch topology with traffic generation..."
echo "   Running for 60 seconds to collect packet data..."
echo ""

/usr/bin/python3 topology/test_7switch_core_topo.py \
    --controller-ip 127.0.0.1 \
    --controller-port 6653 \
    --traffic \
    --duration 60 &
TOPO_PID=$!

# Wait for topology to finish
wait $TOPO_PID

echo ""
echo "4. Traffic generation complete. Stopping controller..."
kill $CONTROLLER_PID 2>/dev/null
sleep 2
echo ""

# Cleanup Mininet
echo "5. Cleaning up Mininet..."
mn -c 2>/dev/null
echo ""

# Check captured packets
echo "=========================================================================="
echo "  PACKET CAPTURE RESULTS"
echo "=========================================================================="
echo ""

PACKET_FILES=$(ls -1 data/raw/captured_packets_*.json 2>/dev/null | wc -l)
if [ "$PACKET_FILES" -gt 0 ]; then
    TOTAL_PACKETS=0
    for file in data/raw/captured_packets_*.json; do
        COUNT=$(python3 -c "import json; print(len(json.load(open('$file'))))" 2>/dev/null || echo "0")
        TOTAL_PACKETS=$((TOTAL_PACKETS + COUNT))
    done

    echo "✅ Captured packets: $TOTAL_PACKETS packets in $PACKET_FILES files"
    echo ""

    # Show sample packet
    echo "Sample packet data:"
    python3 -c "
import json
import sys
try:
    files = sorted(__import__('glob').glob('data/raw/captured_packets_*.json'))
    if files:
        data = json.load(open(files[0]))
        if data:
            pkt = data[0]
            print(f\"  Timestamp: {pkt.get('timestamp', 'N/A')}\")
            print(f\"  Source: {pkt.get('eth_src', 'N/A')} -> Dest: {pkt.get('eth_dst', 'N/A')}\")
            print(f\"  Protocol: {pkt.get('protocol', 'N/A')}\")
            if 'dst_port' in pkt:
                print(f\"  Dst Port: {pkt.get('dst_port', 'N/A')}\")
except Exception as e:
    print(f'  Error reading packets: {e}')
" 2>/dev/null
    echo ""
else
    echo "❌ No packet files found in data/raw/"
    echo "   Check controller log: data/raw/sdn_controller_7switch.log"
    echo ""
    exit 1
fi

# Run ML classifier (same logic as automated_traffic_classification.sh)
echo "=========================================================================="
echo "  RUNNING ML CLASSIFIER"
echo "=========================================================================="
echo ""

# Step 6a: Extract features
echo "6a. Extracting features from captured packets..."
python3 src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv

if [ ! -f data/processed/features.csv ]; then
    echo "❌ ERROR: Feature extraction failed!"
    exit 1
fi
echo "    ✓ Features extracted to data/processed/features.csv"
echo ""

# Step 6b: Classify flows
echo "6b. Classifying flows with ML model..."
python3 src/ml_models/classify_and_export.py data/models/ data/processed/features.csv data/processed/flow_classification.csv

if [ ! -f data/processed/flow_classification.csv ]; then
    echo "❌ ERROR: Classification failed!"
    exit 1
fi
echo "    ✓ Flows classified to data/processed/flow_classification.csv"
echo ""

# Step 6c: Generate host-to-host CSV with bidirectional flows
echo "6c. Generating host-to-host CSV (converting to FPLF format)..."

# First get classified flows
(head -1 data/processed/flow_classification.csv; grep '^[0-9]*,h[0-9]' data/processed/flow_classification.csv) > data/processed/host_to_host_flows_raw.csv

NUM_FLOWS=$(grep '^[0-9]*,h[0-9]' data/processed/flow_classification.csv | wc -l)
echo "    ✓ Extracted $NUM_FLOWS classified host-to-host flows"

# Add bidirectional flows (keep all 14 columns from ML classifier)
python3 << 'ENDPYTHON'
import pandas as pd
import sys

try:
    # Read classified flows (14 columns)
    df = pd.read_csv('data/processed/host_to_host_flows_raw.csv')

    # Create bidirectional flows by adding reverse flows
    bidirectional_flows = []

    for _, row in df.iterrows():
        # Add the detected flow as-is (keep all 14 columns)
        bidirectional_flows.append(row.to_dict())

        # Add reverse flow (swap src/dst, keep same dst_port)
        reverse_flow = row.to_dict()
        # Swap hosts
        reverse_flow['src_host'] = row['dst_host']
        reverse_flow['dst_host'] = row['src_host']
        # Swap IPs
        reverse_flow['src_ip'] = row['dst_ip']
        reverse_flow['dst_ip'] = row['src_ip']
        # Swap ports
        reverse_flow['src_port'] = row['dst_port']
        reverse_flow['dst_port'] = row['src_port']
        # Keep same: protocol, traffic_type, confidence
        # Note: flow_id, packets, bytes, duration will be copied (not accurate but OK for FPLF)

        bidirectional_flows.append(reverse_flow)

    # Create DataFrame and remove duplicates
    result_df = pd.DataFrame(bidirectional_flows)
    result_df = result_df.drop_duplicates(subset=['src_host', 'dst_host', 'dst_port', 'traffic_type'])

    # Sort for readability
    result_df = result_df.sort_values(['src_host', 'dst_host', 'traffic_type'])

    # Save with all columns (14 columns kept)
    result_df.to_csv('data/processed/host_to_host_flows.csv', index=False)

    print(f"✓ Generated {len(result_df)} bidirectional flows (kept all 14 columns)")

except Exception as e:
    print(f"Error generating bidirectional flows: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
ENDPYTHON

echo ""

# Check if classification was successful
if [ -f "data/processed/host_to_host_flows.csv" ]; then
    FLOW_COUNT=$(tail -n +2 data/processed/host_to_host_flows.csv 2>/dev/null | wc -l)
    echo "✅ ML Classification complete: $FLOW_COUNT flows classified"
    echo ""
    echo "Generated file: data/processed/host_to_host_flows.csv"
    echo ""
    echo "Classified flows:"
    echo "=========================================================================="
    column -t -s, < data/processed/host_to_host_flows.csv 2>/dev/null || cat data/processed/host_to_host_flows.csv
    echo "=========================================================================="
    echo ""
else
    echo "❌ Classification failed - host_to_host_flows.csv not created"
    echo ""
    exit 1
fi

# Backup for 7-switch topology
echo "7. Creating backup for 7-switch topology..."
cp data/processed/host_to_host_flows.csv data/processed/host_to_host_flows_7switch_generated.csv
echo "   ✓ Backup saved to: data/processed/host_to_host_flows_7switch_generated.csv"
echo ""

# Show traffic distribution summary
echo "=========================================================================="
echo "  CLASSIFICATION SUMMARY"
echo "=========================================================================="
echo ""

python3 << 'ENDPYTHON'
import pandas as pd
import sys

try:
    df = pd.read_csv('data/processed/host_to_host_flows.csv')

    print(f"Total flows classified: {len(df)}\n")

    print("Traffic Type Distribution:")
    print("-" * 40)
    for traffic_type in sorted(df['traffic_type'].unique()):
        count = len(df[df['traffic_type'] == traffic_type])
        pct = (count / len(df)) * 100
        print(f"  {traffic_type:10s}: {count:4d} flows ({pct:5.1f}%)")

    print("\n\nFlows by Host Pairs:")
    print("-" * 60)
    grouped = df.groupby(['src_host', 'dst_host', 'traffic_type']).size().reset_index(name='count')
    grouped = grouped.sort_values(['src_host', 'dst_host'])

    print(f"{'Source':8s} {'Dest':8s} {'Type':10s} {'Count':>8s}")
    print("-" * 60)
    for _, row in grouped.iterrows():
        print(f"{row['src_host']:8s} {row['dst_host']:8s} {row['traffic_type']:10s} {int(row['count']):8d}")
except Exception as e:
    print(f"Error reading classification results: {e}")
    sys.exit(1)
ENDPYTHON

echo ""
echo "=========================================================================="
echo "  STEP 1 COMPLETE ✅"
echo "=========================================================================="
echo ""
echo "Summary:"
echo "  ✓ Captured $TOTAL_PACKETS packets from 7-switch topology"
echo "  ✓ Extracted features and classified flows"
echo "  ✓ Generated $FLOW_COUNT host-to-host flow classifications"
echo "  ✓ Output: data/processed/host_to_host_flows.csv"
echo ""
echo "Next step:"
echo "  Run Step 2 to test FPLF routing with these classified flows:"
echo "  sudo bash scripts/test_7switch_step2_fplf_routing.sh"
echo ""
echo "Output files:"
echo "  - data/raw/captured_packets_*.json (packet capture)"
echo "  - data/processed/features.csv (extracted features)"
echo "  - data/processed/flow_classification.csv (all flow classifications)"
echo "  - data/processed/host_to_host_flows.csv (host-to-host flows for FPLF)"
echo "  - data/processed/host_to_host_flows_7switch_generated.csv (backup)"
echo "  - data/raw/sdn_controller_7switch.log (controller log)"
echo ""

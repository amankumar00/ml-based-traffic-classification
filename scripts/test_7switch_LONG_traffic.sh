#!/bin/bash
#
# 7-Switch Topology with LONG Traffic Generation
# This runs the topology for 5 MINUTES to generate large flows for ML classification
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

TRAFFIC_DURATION=300  # 5 minutes (300 seconds)

echo "=========================================================================="
echo "  7-SWITCH TOPOLOGY - LONG TRAFFIC TEST"
echo "=========================================================================="
echo ""
echo "Traffic duration: $TRAFFIC_DURATION seconds (5 minutes)"
echo "This will generate LARGE flows (100s-1000s of packets) for ML classifier"
echo ""
echo "Expected results:"
echo "  • VIDEO (h1→h7): ~18,000 packets (1 Mbps for 5 min)"
echo "  • SSH (h3→h5): ~600 packets (bursty, every 3s)"
echo "  • HTTP (h2→h8): ~450 packets (requests every 4s)"
echo "  • FTP (h4→h9): ~600 packets (connections every 5s)"
echo ""
echo "These LARGE flows will have distinct statistical patterns!"
echo "=========================================================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo (Mininet requires root)"
    exit 1
fi

# Get actual user for conda
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER="$USER"
fi
USER_HOME="/home/$ACTUAL_USER"

# Initialize conda (with proper user home)
if [ -f "$USER_HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/miniconda3/etc/profile.d/conda.sh"
    conda activate ml-sdn 2>/dev/null || true
elif [ -f "$USER_HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$USER_HOME/anaconda3/etc/profile.d/conda.sh"
    conda activate ml-sdn 2>/dev/null || true
fi

# Set Python path to use user's conda environment
export PATH="$USER_HOME/miniconda3/envs/ml-sdn/bin:$PATH"

# Verify Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found!"
    exit 1
fi

cd "$PROJECT_ROOT"

# Clean old data
echo "Cleaning old packet captures..."
rm -f data/raw/captured_packets_*.json
rm -f /tmp/sdn_controller.log

echo ""
echo "=========================================================================="
echo "  STEP 1: Start SDN Controller (ML Classifier)"
echo "=========================================================================="
echo ""

# Start controller using ryu-manager (proper way!)
ryu-manager --verbose src/controller/sdn_controller.py \
    > data/raw/sdn_controller_long.log 2>&1 &
CONTROLLER_PID=$!

echo "   Controller PID: $CONTROLLER_PID"
echo "   Waiting for controller startup..."
sleep 8

if ! ps -p $CONTROLLER_PID > /dev/null; then
    echo "❌ Controller failed to start!"
    cat data/raw/sdn_controller_long.log
    exit 1
fi

echo "✅ Controller started successfully"
echo ""

echo "=========================================================================="
echo "  STEP 2: Launch 7-Switch Topology with ${TRAFFIC_DURATION}s Traffic"
echo "=========================================================================="
echo ""

# Run topology with long traffic duration (use system Python for Mininet!)
/usr/bin/python3 topology/test_7switch_core_topo.py \
    --controller-ip 127.0.0.1 \
    --controller-port 6653 \
    --traffic \
    --duration $TRAFFIC_DURATION

TOPO_EXIT=$?

echo ""
echo "=========================================================================="
echo "  STEP 3: Stopping Controller"
echo "=========================================================================="
echo ""

# Stop controller
kill $CONTROLLER_PID 2>/dev/null
wait $CONTROLLER_PID 2>/dev/null

if [ $TOPO_EXIT -ne 0 ]; then
    echo "❌ Topology execution failed!"
    exit 1
fi

echo "✅ Controller stopped"
echo ""

# Cleanup
echo "Cleaning up Mininet..."
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
else
    echo "❌ No packets captured!"
    exit 1
fi

echo "=========================================================================="
echo "  STEP 4: Extract Features and Classify"
echo "=========================================================================="
echo ""

echo "4a. Extracting features from captured packets..."

python3 src/traffic_monitor/feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/features.csv

if [ ! -f data/processed/features.csv ]; then
    echo "❌ Feature extraction failed!"
    exit 1
fi

FEATURE_COUNT=$(tail -n +2 data/processed/features.csv | wc -l)
echo "   ✓ Extracted features for $FEATURE_COUNT flows"
echo ""

echo "4b. Classifying flows with ML model..."

python3 src/ml_models/classify_and_export.py \
    data/models/ \
    data/processed/features.csv \
    data/processed/flow_classification.csv

if [ ! -f data/processed/flow_classification.csv ]; then
    echo "❌ Classification failed!"
    exit 1
fi

echo ""

echo "4c. Extracting host-to-host flows and generating bidirectional entries..."

# First filter to host-to-host
(head -1 data/processed/flow_classification.csv; \
 tail -n +2 data/processed/flow_classification.csv | grep -E '^[0-9]+,h[0-9]') \
 > data/processed/host_to_host_flows_raw.csv

RAW_FLOW_COUNT=$(tail -n +2 data/processed/host_to_host_flows_raw.csv | wc -l)
echo "   ✓ Found $RAW_FLOW_COUNT flows between hosts"

# Generate bidirectional flows
python3 << 'ENDPYTHON'
import pandas as pd
import sys

try:
    df = pd.read_csv('data/processed/host_to_host_flows_raw.csv')

    if len(df) == 0:
        print("❌ No host-to-host flows found!")
        sys.exit(1)

    # Create bidirectional flows
    bidirectional_flows = []

    for _, row in df.iterrows():
        # Add detected flow
        bidirectional_flows.append(row.to_dict())

        # Add reverse flow (swap src/dst)
        reverse_flow = row.to_dict()
        reverse_flow['src_host'] = row['dst_host']
        reverse_flow['dst_host'] = row['src_host']
        reverse_flow['src_ip'] = row['dst_ip']
        reverse_flow['dst_ip'] = row['src_ip']
        reverse_flow['src_port'] = row['dst_port']
        reverse_flow['dst_port'] = row['src_port']

        bidirectional_flows.append(reverse_flow)

    result_df = pd.DataFrame(bidirectional_flows)
    result_df = result_df.drop_duplicates(subset=['src_host', 'dst_host', 'dst_port', 'traffic_type'])
    result_df = result_df.sort_values(['src_host', 'dst_host', 'traffic_type'])

    result_df.to_csv('data/processed/host_to_host_flows.csv', index=False)

    print(f"   ✓ Generated {len(result_df)} bidirectional flows (kept all 14 columns)")

except Exception as e:
    print(f"❌ Error generating bidirectional flows: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
ENDPYTHON

if [ ! -f data/processed/host_to_host_flows.csv ]; then
    echo "❌ Bidirectional flow generation failed!"
    exit 1
fi

echo ""

echo "=========================================================================="
echo "  STEP 5: RESULTS"
echo "=========================================================================="
echo ""

python3 << 'ENDPYTHON'
import pandas as pd

df = pd.read_csv('data/processed/host_to_host_flows.csv')

print("Classified Host-to-Host Flows:")
print("─" * 80)
print(df[['src_host', 'dst_host', 'traffic_type', 'confidence', 'total_packets', 'total_bytes']].to_string(index=False))

print("\n\nTraffic Summary:")
print("─" * 80)
summary = df.groupby('traffic_type').agg({
    'src_host': 'count',
    'total_packets': 'mean',
    'total_bytes': 'mean',
    'confidence': 'mean'
}).round(2)
summary.columns = ['Flows', 'Avg Packets', 'Avg Bytes', 'Avg Confidence']
print(summary)

print("\n\nKey Flows (expected):")
print("─" * 80)
expected = [
    ('h1', 'h7', 'VIDEO'),
    ('h7', 'h1', 'VIDEO'),
    ('h3', 'h5', 'SSH'),
    ('h5', 'h3', 'SSH'),
    ('h2', 'h8', 'HTTP'),
    ('h8', 'h2', 'HTTP'),
    ('h4', 'h9', 'FTP'),
    ('h9', 'h4', 'FTP'),
]

found_count = 0
for src, dst, traffic in expected:
    match = df[(df['src_host'] == src) & (df['dst_host'] == dst) & (df['traffic_type'] == traffic)]
    if len(match) > 0:
        packets = match.iloc[0]['total_packets']
        confidence = match.iloc[0]['confidence']
        print(f"  ✓ {src}→{dst} {traffic:<8} (packets: {packets}, confidence: {confidence:.2f})")
        found_count += 1
    else:
        print(f"  ✗ {src}→{dst} {traffic:<8} NOT FOUND or misclassified!")

accuracy = (found_count / len(expected)) * 100
print(f"\n\nAccuracy: {found_count}/{len(expected)} = {accuracy:.1f}%")

if accuracy >= 75:
    print("✅ EXCELLENT! ML classifier working well with large flows!")
elif accuracy >= 50:
    print("⚠️  MODERATE: Some misclassifications, but usable.")
else:
    print("❌ POOR: Most flows misclassified.")
ENDPYTHON

echo ""
echo "=========================================================================="
echo "  COMPLETE ✅"
echo "=========================================================================="
echo ""
echo "Generated files:"
echo "  - data/processed/features.csv (extracted features)"
echo "  - data/processed/flow_classification.csv (all classifications)"
echo "  - data/processed/host_to_host_flows.csv (bidirectional host-to-host flows)"
echo ""
echo "With ${TRAFFIC_DURATION}s traffic, flows should have 100s-1000s of packets."
echo "This gives the ML classifier enough data to distinguish traffic patterns!"
echo ""

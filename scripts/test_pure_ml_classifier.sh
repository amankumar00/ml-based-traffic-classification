#!/bin/bash
#
# Test Pure ML Classifier (No Port-Based Override)
# Uses existing packet captures to test ML model performance
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  TESTING PURE ML CLASSIFIER (No Port-Based Override)"
echo "=========================================================================="
echo ""
echo "This will re-classify existing packet captures using ONLY the ML model"
echo "(port-based classification has been disabled for testing)"
echo ""
echo "=========================================================================="
echo ""

# No sudo needed! Just use current user
ACTUAL_USER="$USER"
USER_HOME="$HOME"

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

# Check for existing packet captures
PACKET_FILES=$(ls -1 data/raw/captured_packets_*.json 2>/dev/null | wc -l)
if [ "$PACKET_FILES" -eq 0 ]; then
    echo "❌ No packet captures found!"
    echo "   Please run: sudo bash scripts/test_7switch_step1_ml_classification.sh"
    exit 1
fi

echo "Found $PACKET_FILES packet capture files"
echo ""

# Step 1: Extract features
echo "1. Extracting features from captured packets..."
python3 src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features_pure_ml_test.csv

if [ ! -f data/processed/features_pure_ml_test.csv ]; then
    echo "❌ ERROR: Feature extraction failed!"
    exit 1
fi
echo "   ✓ Features extracted"
echo ""

# Step 2: Classify with PURE ML (port-based override is commented out)
echo "2. Classifying flows with PURE ML model (no port-based override)..."
python3 src/ml_models/classify_and_export.py data/models/ data/processed/features_pure_ml_test.csv data/processed/flow_classification_pure_ml_test.csv

if [ ! -f data/processed/flow_classification_pure_ml_test.csv ]; then
    echo "❌ ERROR: Classification failed!"
    exit 1
fi
echo ""

# Step 3: Extract host-to-host flows
echo "3. Extracting host-to-host flows..."
(head -1 data/processed/flow_classification_pure_ml_test.csv; grep '^[0-9]*,h[0-9]' data/processed/flow_classification_pure_ml_test.csv) > data/processed/host_to_host_flows_pure_ml_test.csv

FLOW_COUNT=$(tail -n +2 data/processed/host_to_host_flows_pure_ml_test.csv | wc -l)
echo "   ✓ Extracted $FLOW_COUNT host-to-host flows"
echo ""

# Step 4: Compare with port-based results
echo "=========================================================================="
echo "  PURE ML CLASSIFICATION RESULTS"
echo "=========================================================================="
echo ""

if [ -f data/processed/host_to_host_flows.csv ]; then
    echo "Comparing PURE ML vs PORT-BASED classification:"
    echo ""
    echo "PORT-BASED RESULTS (original):"
    echo "────────────────────────────────────────────────────────────────"
    head -5 data/processed/host_to_host_flows.csv | column -t -s,
    echo ""

    echo "PURE ML RESULTS (testing):"
    echo "────────────────────────────────────────────────────────────────"
    head -5 data/processed/host_to_host_flows_pure_ml_test.csv | column -t -s,
    echo ""
fi

# Show detailed classification results
echo "=========================================================================="
echo "  DETAILED PURE ML RESULTS"
echo "=========================================================================="
echo ""

python3 << 'ENDPYTHON'
import pandas as pd
import sys

try:
    df = pd.read_csv('data/processed/host_to_host_flows_pure_ml_test.csv')

    print(f"Total flows classified: {len(df)}\n")

    # Check expected flows
    expected_flows = {
        ('h7', 'h1', 'VIDEO'),
        ('h1', 'h7', 'VIDEO'),
        ('h5', 'h3', 'SSH'),
        ('h3', 'h5', 'SSH'),
        ('h8', 'h2', 'HTTP'),
        ('h2', 'h8', 'HTTP'),
        ('h9', 'h4', 'FTP'),
        ('h4', 'h9', 'FTP'),
    }

    actual_flows = set()
    for _, row in df.iterrows():
        actual_flows.add((row['src_host'], row['dst_host'], row['traffic_type']))

    correct = expected_flows & actual_flows
    incorrect = actual_flows - expected_flows
    missing = expected_flows - actual_flows

    print("Classification Accuracy:")
    print("-" * 60)
    print(f"  ✓ Correct:   {len(correct)}/8 expected flows")
    if len(incorrect) > 0:
        print(f"  ✗ Incorrect: {len(incorrect)} flows")
    if len(missing) > 0:
        print(f"  ⚠ Missing:   {len(missing)} expected flows")
    print("")

    # Show all flows with confidence
    print("All Classified Flows:")
    print("-" * 80)
    print(f"{'Src':8s} {'Dst':8s} {'Traffic':10s} {'Confidence':12s} {'Correct?':10s}")
    print("-" * 80)

    for _, row in df.iterrows():
        flow_tuple = (row['src_host'], row['dst_host'], row['traffic_type'])
        is_correct = "✓ YES" if flow_tuple in expected_flows else "✗ NO"
        print(f"{row['src_host']:8s} {row['dst_host']:8s} {row['traffic_type']:10s} {float(row['confidence']):12.4f} {is_correct:10s}")

    print("")

    # Show traffic type distribution
    print("\nTraffic Type Distribution:")
    print("-" * 40)
    for traffic_type in sorted(df['traffic_type'].unique()):
        count = len(df[df['traffic_type'] == traffic_type])
        pct = (count / len(df)) * 100
        print(f"  {traffic_type:10s}: {count:4d} flows ({pct:5.1f}%)")

    # Calculate average confidence
    avg_confidence = df['confidence'].astype(float).mean()
    print(f"\nAverage ML Confidence: {avg_confidence:.4f}")

except Exception as e:
    print(f"Error analyzing results: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
ENDPYTHON

echo ""
echo "=========================================================================="
echo "  TEST COMPLETE"
echo "=========================================================================="
echo ""
echo "Files generated:"
echo "  - data/processed/features_pure_ml_test.csv"
echo "  - data/processed/flow_classification_pure_ml_test.csv"
echo "  - data/processed/host_to_host_flows_pure_ml_test.csv"
echo ""
echo "To restore port-based classification:"
echo "  cp src/ml_models/classify_and_export.py.backup src/ml_models/classify_and_export.py"
echo ""

#!/bin/bash
#
# Complete Test: Bidirectional ML Classifier (Paper's Approach)
# This script:
#   1. Retrains ML model with bidirectional features (NO PORTS!)
#   2. Tests the new classifier on existing packet captures
#   3. Compares with old port-based results
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  COMPLETE BIDIRECTIONAL ML TEST (Paper's Approach)"
echo "=========================================================================="
echo ""
echo "This will:"
echo "  1. Retrain ML model with bidirectional flow features (NO PORTS!)"
echo "  2. Classify flows using PURE ML"
echo "  3. Compare results with old port-based approach"
echo ""
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

# Step 1: Retrain model
echo "STEP 1: Retraining ML Model"
echo "=========================================================================="
bash scripts/retrain_ml_model_bidirectional.sh

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Model retraining failed!"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "STEP 2: Testing New Bidirectional Classifier"
echo "=========================================================================="
echo ""

# Step 2: Extract bidirectional features from existing captures
echo "2a. Extracting bidirectional features from packet captures..."
python3 src/traffic_monitor/bidirectional_feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/bidirectional_features_test.csv

if [ ! -f data/processed/bidirectional_features_test.csv ]; then
    echo "❌ ERROR: Feature extraction failed!"
    exit 1
fi
echo ""

# Step 3: Classify with new model
echo "2b. Classifying with new bidirectional ML model..."
python3 src/ml_models/classify_and_export_bidirectional.py \
    data/models/ \
    data/processed/bidirectional_features_test.csv \
    data/processed/flow_classification_bidirectional.csv

if [ ! -f data/processed/flow_classification_bidirectional.csv ]; then
    echo "❌ ERROR: Classification failed!"
    exit 1
fi
echo ""

# Step 4: Extract host-to-host flows
echo "2c. Extracting host-to-host flows..."
(head -1 data/processed/flow_classification_bidirectional.csv; grep '^[0-9]*,h[0-9]' data/processed/flow_classification_bidirectional.csv) > data/processed/host_to_host_flows_bidirectional.csv

BIDIR_FLOW_COUNT=$(tail -n +2 data/processed/host_to_host_flows_bidirectional.csv | wc -l)
echo "   ✓ Extracted $BIDIR_FLOW_COUNT host-to-host flows"
echo ""

# Step 5: Generate bidirectional flow pairs
echo "2d. Generating bidirectional flow pairs..."
python3 << 'ENDPYTHON'
import pandas as pd
import sys

try:
    df = pd.read_csv('data/processed/host_to_host_flows_bidirectional.csv')

    # Create bidirectional pairs
    bidirectional_flows = []

    for _, row in df.iterrows():
        # Add original flow
        bidirectional_flows.append(row.to_dict())

        # Add reverse flow
        reverse_flow = row.to_dict()
        reverse_flow['src_host'] = row['dst_host']
        reverse_flow['dst_host'] = row['src_host']
        reverse_flow['src_ip'] = row['dst_ip']
        reverse_flow['dst_ip'] = row['src_ip']
        # Note: ports are 0 in bidirectional approach

        bidirectional_flows.append(reverse_flow)

    result_df = pd.DataFrame(bidirectional_flows)
    result_df = result_df.drop_duplicates(subset=['src_host', 'dst_host', 'traffic_type'])
    result_df = result_df.sort_values(['src_host', 'dst_host', 'traffic_type'])

    result_df.to_csv('data/processed/host_to_host_flows_bidirectional_final.csv', index=False)

    print(f"✓ Generated {len(result_df)} bidirectional flow pairs")

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
ENDPYTHON

echo ""

# Step 6: Compare results
echo "=========================================================================="
echo "STEP 3: COMPARING RESULTS"
echo "=========================================================================="
echo ""

python3 << 'ENDPYTHON'
import pandas as pd

print("PORT-BASED APPROACH (Old):")
print("────────────────────────────────────────────────────────────────")
if os.path.exists('data/processed/host_to_host_flows.csv'):
    df_old = pd.read_csv('data/processed/host_to_host_flows.csv')
    print(df_old[['src_host', 'dst_host', 'traffic_type', 'confidence']].head(8))
    print(f"\nTotal flows: {len(df_old)}")
    print(f"Avg confidence: {df_old['confidence'].astype(float).mean():.4f}")
else:
    print("No old results found")

print("\n\nBIDIRECTIONAL ML APPROACH (New - Paper-based):")
print("────────────────────────────────────────────────────────────────")
df_new = pd.read_csv('data/processed/host_to_host_flows_bidirectional_final.csv')
print(df_new[['src_host', 'dst_host', 'traffic_type', 'confidence']].head(8))
print(f"\nTotal flows: {len(df_new)}")
print(f"Avg confidence: {df_new['confidence'].astype(float).mean():.4f}")

print("\n\nACCURACY COMPARISON:")
print("────────────────────────────────────────────────────────────────")

# Expected flows
expected = {
    ('h1', 'h7', 'VIDEO'),
    ('h7', 'h1', 'VIDEO'),
    ('h3', 'h5', 'SSH'),
    ('h5', 'h3', 'SSH'),
    ('h2', 'h8', 'HTTP'),
    ('h8', 'h2', 'HTTP'),
    ('h4', 'h9', 'FTP'),
    ('h9', 'h4', 'FTP'),
}

actual = set()
for _, row in df_new.iterrows():
    actual.add((row['src_host'], row['dst_host'], row['traffic_type']))

correct = expected & actual
incorrect = actual - expected
missing = expected - actual

print(f"Expected flows: {len(expected)}")
print(f"Correct:   {len(correct)}/8 ({'✅' if len(correct) >= 6 else '❌'})")
print(f"Incorrect: {len(incorrect)}")
print(f"Missing:   {len(missing)}")

accuracy = (len(correct) / len(expected)) * 100
print(f"\nAccuracy: {accuracy:.1f}%")

if accuracy >= 75:
    print("✅ GOOD - Model is working reasonably well!")
elif accuracy >= 50:
    print("⚠️  MODERATE - May need more training data")
else:
    print("❌ POOR - Consider using port-based backup")

ENDPYTHON

echo ""
echo "=========================================================================="
echo "  TEST COMPLETE"
echo "=========================================================================="
echo ""
echo "Generated files:"
echo "  - data/processed/bidirectional_features_test.csv (features)"
echo "  - data/processed/flow_classification_bidirectional.csv (all flows)"
echo "  - data/processed/host_to_host_flows_bidirectional_final.csv (host-to-host)"
echo ""
echo "Models:"
echo "  - data/models/ (NEW bidirectional model)"
echo "  - data/models_backup/ (OLD port-based model)"
echo ""
echo "To use new model in Step 1 script, update feature extractor to use:"
echo "  src/traffic_monitor/bidirectional_feature_extractor.py"
echo ""
echo "To restore old port-based model if needed:"
echo "  cp -r data/models_backup/* data/models/"
echo "  cp src/ml_models/classify_and_export_ORIGINAL_PORT_BASED.py src/ml_models/classify_and_export.py"
echo ""

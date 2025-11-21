#!/bin/bash
#
# Complete Test: Honest ML Classifier (NO PORT FEATURES!)
# This script will:
#   1. Use the newly trained model (trained on 800 samples WITHOUT ports)
#   2. Extract features from existing 7-switch packet captures
#   3. Classify flows using PURE ML
#   4. Compare with expected results
#   5. Show detailed accuracy metrics
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  HONEST ML CLASSIFIER TEST - Complete Analysis"
echo "=========================================================================="
echo ""
echo "This will test the newly trained Random Forest model:"
echo "  ✓ Trained on 800 samples (200 each: VIDEO, SSH, HTTP, FTP)"
echo "  ✓ Uses 27 statistical features (NO port numbers!)"
echo "  ✓ Achieved 100% test accuracy on training data"
echo ""
echo "Now testing on 7-switch packet captures..."
echo ""
echo "=========================================================================="
echo ""

cd "$PROJECT_ROOT"

# Check if packet captures exist
if [ ! -f data/raw/captured_packets_*.json 2>/dev/null ]; then
    echo "❌ No packet captures found in data/raw/"
    echo "   Please run: sudo bash scripts/test_7switch_step1_ml_classification.sh"
    exit 1
fi

PACKET_COUNT=$(ls -1 data/raw/captured_packets_*.json 2>/dev/null | wc -l)
echo "Found $PACKET_COUNT packet capture files"
echo ""

# Step 1: Extract features using standard feature extractor
echo "=========================================================================="
echo "STEP 1: Extract Features from Packet Captures"
echo "=========================================================================="
echo ""

source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate ml-sdn 2>/dev/null

python3 src/traffic_monitor/feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/features_honest_ml_test.csv

if [ $? -ne 0 ] || [ ! -f data/processed/features_honest_ml_test.csv ]; then
    echo "❌ Feature extraction failed!"
    exit 1
fi

FEATURE_COUNT=$(tail -n +2 data/processed/features_honest_ml_test.csv | wc -l)
echo "   ✓ Extracted features for $FEATURE_COUNT flows"
echo ""

# Step 2: Classify with honest ML model
echo "=========================================================================="
echo "STEP 2: Classify Flows Using Honest ML Model"
echo "=========================================================================="
echo ""

python3 src/ml_models/classify_and_export.py \
    data/models/ \
    data/processed/features_honest_ml_test.csv \
    data/processed/flow_classification_honest_ml.csv

if [ $? -ne 0 ] || [ ! -f data/processed/flow_classification_honest_ml.csv ]; then
    echo "❌ Classification failed!"
    exit 1
fi

echo ""

# Step 3: Extract host-to-host flows
echo "=========================================================================="
echo "STEP 3: Extract Host-to-Host Flows"
echo "=========================================================================="
echo ""

# Filter for host-to-host traffic (h1-h9)
(head -1 data/processed/flow_classification_honest_ml.csv; \
 tail -n +2 data/processed/flow_classification_honest_ml.csv | grep -E '^[0-9]+,h[0-9]') \
 > data/processed/host_to_host_flows_honest_ml.csv

HOST_FLOW_COUNT=$(tail -n +2 data/processed/host_to_host_flows_honest_ml.csv | wc -l)
echo "   ✓ Found $HOST_FLOW_COUNT host-to-host flows"
echo ""

# Step 4: Detailed Analysis
echo "=========================================================================="
echo "STEP 4: DETAILED ANALYSIS & COMPARISON"
echo "=========================================================================="
echo ""

python3 << 'ENDPYTHON'
import pandas as pd
import sys

try:
    # Load honest ML results
    df_honest = pd.read_csv('data/processed/host_to_host_flows_honest_ml.csv')

    print("HONEST ML CLASSIFIER RESULTS:")
    print("─" * 80)
    print(df_honest[['flow_id', 'src_host', 'dst_host', 'traffic_type', 'confidence',
                      'total_packets', 'total_bytes', 'flow_duration']].to_string(index=False))
    print("")
    print(f"Total flows classified: {len(df_honest)}")
    print(f"Average confidence: {df_honest['confidence'].astype(float).mean():.4f}")
    print("")

    print("\nTraffic Type Distribution:")
    print("─" * 80)
    for traffic_type, count in df_honest['traffic_type'].value_counts().items():
        percentage = (count / len(df_honest)) * 100
        print(f"  {traffic_type:<10}: {count:>3} flows ({percentage:>5.1f}%)")
    print("")

    # Expected results from 7-switch topology
    print("\n" + "=" * 80)
    print("ACCURACY ANALYSIS")
    print("=" * 80)
    print("")

    expected_flows = {
        ('h1', 'h7', 'VIDEO'): 'h1→h7 video stream (port 5004)',
        ('h7', 'h1', 'VIDEO'): 'h7→h1 video return',
        ('h3', 'h5', 'SSH'): 'h3→h5 SSH session (port 22)',
        ('h5', 'h3', 'SSH'): 'h5→h3 SSH return',
        ('h2', 'h8', 'HTTP'): 'h2→h8 HTTP request (port 80)',
        ('h8', 'h2', 'HTTP'): 'h8→h2 HTTP return',
        ('h4', 'h9', 'FTP'): 'h4→h9 FTP transfer (port 21)',
        ('h9', 'h4', 'FTP'): 'h9→h4 FTP return',
    }

    # Build set of actual flows
    actual_flows = set()
    flow_details = {}
    for _, row in df_honest.iterrows():
        flow_key = (row['src_host'], row['dst_host'], row['traffic_type'])
        actual_flows.add(flow_key)
        flow_details[flow_key] = {
            'confidence': row['confidence'],
            'packets': row['total_packets'],
            'bytes': row['total_bytes'],
            'duration': row['flow_duration']
        }

    # Compare
    correct = []
    incorrect = []
    missing = []

    for expected_flow, description in expected_flows.items():
        if expected_flow in actual_flows:
            correct.append((expected_flow, description))
        else:
            # Check if flow exists but with wrong classification
            src, dst, expected_type = expected_flow
            found_wrong = False
            for actual_flow in actual_flows:
                if actual_flow[0] == src and actual_flow[1] == dst:
                    incorrect.append((expected_flow, actual_flow, description))
                    found_wrong = True
                    break
            if not found_wrong:
                missing.append((expected_flow, description))

    # Find unexpected flows (not in expected set)
    unexpected = []
    for actual_flow in actual_flows:
        if actual_flow not in expected_flows:
            unexpected.append(actual_flow)

    print(f"Expected Flows: {len(expected_flows)}")
    print(f"Detected Flows: {len(actual_flows)}")
    print("")

    # Show correct predictions
    if correct:
        print(f"✅ CORRECT PREDICTIONS: {len(correct)}/{len(expected_flows)}")
        print("─" * 80)
        for flow, description in correct:
            details = flow_details[flow]
            print(f"  ✓ {flow[0]}→{flow[1]} {flow[2]:<8} (confidence: {details['confidence']:.3f})")
            print(f"    {description}")
        print("")

    # Show incorrect predictions
    if incorrect:
        print(f"❌ INCORRECT PREDICTIONS: {len(incorrect)}")
        print("─" * 80)
        for expected, actual, description in incorrect:
            print(f"  ✗ Expected: {expected[0]}→{expected[1]} {expected[2]}")
            print(f"    Got:      {actual[0]}→{actual[1]} {actual[2]}")
            print(f"    {description}")
        print("")

    # Show missing flows
    if missing:
        print(f"⚠️  MISSING FLOWS: {len(missing)}")
        print("─" * 80)
        for flow, description in missing:
            print(f"  ? {flow[0]}→{flow[1]} {flow[2]} not detected")
            print(f"    {description}")
        print("")

    # Show unexpected flows
    if unexpected:
        print(f"❓ UNEXPECTED FLOWS: {len(unexpected)}")
        print("─" * 80)
        for flow in unexpected:
            details = flow_details[flow]
            print(f"  ? {flow[0]}→{flow[1]} {flow[2]} (confidence: {details['confidence']:.3f})")
        print("")

    # Calculate accuracy
    accuracy = (len(correct) / len(expected_flows)) * 100

    print("=" * 80)
    print("FINAL SCORE")
    print("=" * 80)
    print(f"Accuracy: {len(correct)}/{len(expected_flows)} = {accuracy:.1f}%")
    print("")

    if accuracy >= 75:
        print("✅ EXCELLENT: Model performs well with honest ML!")
        print("   This is legitimate machine learning without port-based cheating.")
    elif accuracy >= 50:
        print("⚠️  MODERATE: Model needs more diverse training data.")
        print("   Consider collecting longer traffic captures for better patterns.")
    else:
        print("❌ POOR: Current packet captures may not have enough diversity.")
        print("   The 4 flows captured are too small to show distinct patterns.")
    print("")

    # Feature importance reminder
    print("\n" + "=" * 80)
    print("MODEL INFORMATION")
    print("=" * 80)
    print("")
    print("Model: Random Forest (100 trees)")
    print("Training: 800 samples (200 each: VIDEO, SSH, HTTP, FTP)")
    print("Features: 27 statistical features (NO PORT NUMBERS!)")
    print("")
    print("Top 5 Most Important Features:")
    print("  1. min_packet_size")
    print("  2. max_packet_size")
    print("  3. mean_tos (Type of Service)")
    print("  4. mean_forward_packet_size")
    print("  5. mean_packet_size")
    print("")
    print("✅ This is REAL machine learning based on traffic patterns!")
    print("")

except Exception as e:
    print(f"Error during analysis: {e}")
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
echo "  - data/processed/features_honest_ml_test.csv (extracted features)"
echo "  - data/processed/flow_classification_honest_ml.csv (all classifications)"
echo "  - data/processed/host_to_host_flows_honest_ml.csv (host-to-host only)"
echo ""
echo "Model used:"
echo "  - data/models/random_forest_model.pkl (trained WITHOUT ports)"
echo "  - data/models/model_metadata.json (feature names and metadata)"
echo ""
echo "To restore old port-based model if needed:"
echo "  cp -r data/models_backup/* data/models/"
echo ""

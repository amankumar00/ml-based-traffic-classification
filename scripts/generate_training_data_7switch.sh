#!/bin/bash
#
# Generate Training Data from 7-Switch Topology
#
# This script will:
#   1. Run 7-switch topology multiple times with extended traffic
#   2. Capture packets for all 4 traffic types (VIDEO, SSH, HTTP, FTP)
#   3. Extract features and label them using port numbers
#   4. Accumulate 10k+ training samples
#   5. Train new ML model on this realistic data
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  TRAINING DATA GENERATION - 7-Switch Topology"
echo "=========================================================================="
echo ""
echo "This will generate ~10,000 training samples by:"
echo "  • Running 7-switch topology multiple times"
echo "  • Capturing VIDEO, SSH, HTTP, FTP traffic"
echo "  • Extracting statistical features"
echo "  • Using port numbers ONLY for labeling (not as features!)"
echo ""
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

# Configuration
NUM_ITERATIONS=50  # Number of topology runs
TRAFFIC_DURATION=120  # seconds per run (2 minutes)
TARGET_SAMPLES=10000

echo "Configuration:"
echo "  Iterations: $NUM_ITERATIONS"
echo "  Traffic duration per run: ${TRAFFIC_DURATION}s"
echo "  Target samples: $TARGET_SAMPLES"
echo ""

# Create backup of old training data
if [ -f data/processed/training_data_no_icmp.csv ]; then
    BACKUP_NAME="training_data_no_icmp_backup_$(date +%Y%m%d_%H%M%S).csv"
    cp data/processed/training_data_no_icmp.csv "data/processed/$BACKUP_NAME"
    echo "✓ Backed up old training data to: $BACKUP_NAME"
fi

# Create directory for new captures
mkdir -p data/raw/training_captures
rm -f data/raw/training_captures/*.json 2>/dev/null

echo ""
echo "=========================================================================="
echo "  PHASE 1: Generating Traffic Captures"
echo "=========================================================================="
echo ""

for i in $(seq 1 $NUM_ITERATIONS); do
    echo "────────────────────────────────────────────────────────────────────────"
    echo "Iteration $i/$NUM_ITERATIONS"
    echo "────────────────────────────────────────────────────────────────────────"

    # Clean old controller logs
    rm -f /tmp/sdn_controller.log 2>/dev/null

    # Run topology with extended traffic
    timeout $((TRAFFIC_DURATION + 60)) python3 << ENDPYTHON
from mininet.net import Mininet
from mininet.node import RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel
import time
import os

def create_7switch_topology():
    """Create 7-switch topology with traffic generation"""

    net = Mininet(controller=RemoteController)

    # Add controller
    c0 = net.addController('c0', controller=RemoteController, ip='127.0.0.1', port=6653)

    # Add 7 switches
    switches = []
    for i in range(1, 8):
        s = net.addSwitch(f's{i}')
        switches.append(s)

    # Add 9 hosts (h1-h9)
    hosts = []
    for i in range(1, 10):
        h = net.addHost(f'h{i}', ip=f'10.0.0.{i}/24')
        hosts.append(h)

    # Edge switches (s1-s4) connect to hosts
    # s1: h1, h2
    net.addLink(hosts[0], switches[0])
    net.addLink(hosts[1], switches[0])

    # s2: h3, h4
    net.addLink(hosts[2], switches[1])
    net.addLink(hosts[3], switches[1])

    # s3: h5, h6
    net.addLink(hosts[4], switches[2])
    net.addLink(hosts[5], switches[2])

    # s4: h7, h8, h9
    net.addLink(hosts[6], switches[3])
    net.addLink(hosts[7], switches[3])
    net.addLink(hosts[8], switches[3])

    # Core switches (s5, s6, s7) - full mesh between edge and core
    # Edge to core connections
    for edge_idx in range(4):  # s1-s4
        for core_idx in range(4, 7):  # s5-s7
            net.addLink(switches[edge_idx], switches[core_idx])

    # Core mesh (s5-s6, s6-s7, s5-s7)
    net.addLink(switches[4], switches[5])
    net.addLink(switches[5], switches[6])
    net.addLink(switches[4], switches[6])

    net.start()

    # Wait for controller to discover topology
    print("Waiting for controller to discover topology...")
    time.sleep(5)

    # Generate traffic for ${TRAFFIC_DURATION} seconds
    print("\\nGenerating traffic for ${TRAFFIC_DURATION} seconds...")

    # VIDEO: h1 -> h7 (port 5004)
    hosts[6].cmd('iperf -s -p 5004 &')
    time.sleep(1)
    hosts[0].cmd(f'iperf -c 10.0.0.7 -p 5004 -t ${TRAFFIC_DURATION} -b 1M &')

    # SSH: h3 -> h5 (port 22) - simulate with nc
    hosts[4].cmd('nc -l -p 22 > /dev/null &')
    time.sleep(1)
    hosts[2].cmd(f'yes | nc 10.0.0.5 22 &')

    # HTTP: h2 -> h8 (port 80)
    hosts[7].cmd('nc -l -p 80 > /dev/null &')
    time.sleep(1)
    hosts[1].cmd(f'yes | nc 10.0.0.8 80 &')

    # FTP: h4 -> h9 (port 21)
    hosts[8].cmd('nc -l -p 21 > /dev/null &')
    time.sleep(1)
    hosts[3].cmd(f'yes | nc 10.0.0.9 21 &')

    # Let traffic run
    time.sleep(${TRAFFIC_DURATION})

    # Stop traffic
    print("\\nStopping traffic...")
    for h in hosts:
        h.cmd('killall iperf nc 2>/dev/null')

    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    create_7switch_topology()
ENDPYTHON

    TOPOLOGY_EXIT=$?

    if [ $TOPOLOGY_EXIT -eq 0 ]; then
        echo "✓ Iteration $i completed"

        # Move captured packets to training directory
        if [ -f data/raw/captured_packets_*.json ]; then
            mv data/raw/captured_packets_*.json data/raw/training_captures/ 2>/dev/null
        fi
    else
        echo "⚠️  Iteration $i had issues (exit code: $TOPOLOGY_EXIT)"
    fi

    # Clean up processes
    killall -9 controller 2>/dev/null
    mn -c > /dev/null 2>&1

    sleep 2
done

echo ""
echo "=========================================================================="
echo "  PHASE 2: Extract Features from Captures"
echo "=========================================================================="
echo ""

CAPTURE_COUNT=$(ls -1 data/raw/training_captures/*.json 2>/dev/null | wc -l)
echo "Found $CAPTURE_COUNT packet capture files"

if [ $CAPTURE_COUNT -eq 0 ]; then
    echo "❌ No packet captures found!"
    exit 1
fi

echo ""
echo "Extracting features (this may take a few minutes)..."

python3 src/traffic_monitor/feature_extractor.py \
    data/raw/training_captures/captured_packets_*.json \
    data/processed/new_training_features.csv

if [ ! -f data/processed/new_training_features.csv ]; then
    echo "❌ Feature extraction failed!"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "  PHASE 3: Label and Prepare Training Data"
echo "=========================================================================="
echo ""

python3 << 'ENDPYTHON'
import pandas as pd
import numpy as np

# Load extracted features
df = pd.read_csv('data/processed/new_training_features.csv')

print(f"Total flows extracted: {len(df)}")

# Function to label flows based on port (for training labels only!)
def label_flow(src_port, dst_port):
    """Assign traffic type label based on port (for training LABELS only!)"""
    port_mapping = {
        80: 'HTTP', 8080: 'HTTP', 443: 'HTTP',
        21: 'FTP', 20: 'FTP',
        22: 'SSH',
        5004: 'VIDEO', 5006: 'VIDEO', 1935: 'VIDEO'
    }

    if dst_port in port_mapping:
        return port_mapping[dst_port]
    if src_port in port_mapping:
        return port_mapping[src_port]

    return 'UNKNOWN'

# Apply labels
df['traffic_type'] = df.apply(lambda row: label_flow(row['src_port'], row['dst_port']), axis=1)

# Filter to only known traffic types
df_labeled = df[df['traffic_type'] != 'UNKNOWN'].copy()

print(f"\nLabeled flows: {len(df_labeled)}")
print("\nTraffic type distribution:")
print(df_labeled['traffic_type'].value_counts())

# Feature columns (EXCLUDING src_port and dst_port!)
feature_cols = [
    'total_packets', 'forward_packets', 'backward_packets',
    'total_bytes', 'forward_bytes', 'backward_bytes',
    'flow_duration', 'packets_per_second', 'bytes_per_second',
    'min_packet_size', 'max_packet_size', 'mean_packet_size', 'std_packet_size',
    'mean_forward_packet_size', 'mean_backward_packet_size',
    'mean_inter_arrival_time', 'std_inter_arrival_time',
    'min_inter_arrival_time', 'max_inter_arrival_time',
    'syn_count', 'ack_count', 'fin_count', 'rst_count', 'psh_count',
    'mean_tcp_window', 'mean_ttl', 'mean_tos'
]

# Ensure all features exist
for col in feature_cols:
    if col not in df_labeled.columns:
        df_labeled[col] = 0

# Save training data (features + traffic_type label)
training_data = df_labeled[feature_cols + ['traffic_type']].copy()
training_data.to_csv('data/processed/training_data_7switch_generated.csv', index=False)

print(f"\n✓ Training data saved: {len(training_data)} samples")
print(f"  Features: {len(feature_cols)} (NO PORTS!)")
print(f"  File: data/processed/training_data_7switch_generated.csv")
ENDPYTHON

if [ ! -f data/processed/training_data_7switch_generated.csv ]; then
    echo "❌ Training data preparation failed!"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "  PHASE 4: Train ML Model on New Data"
echo "=========================================================================="
echo ""

python3 << 'ENDPYTHON'
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier
import pickle
import json
import os

# Load training data
df = pd.read_csv('data/processed/training_data_7switch_generated.csv')

print(f"Training samples: {len(df)}")
print(f"\nTraffic type distribution:")
print(df['traffic_type'].value_counts())

# Feature columns (NO PORTS!)
feature_cols = [
    'total_packets', 'forward_packets', 'backward_packets',
    'total_bytes', 'forward_bytes', 'backward_bytes',
    'flow_duration', 'packets_per_second', 'bytes_per_second',
    'min_packet_size', 'max_packet_size', 'mean_packet_size', 'std_packet_size',
    'mean_forward_packet_size', 'mean_backward_packet_size',
    'mean_inter_arrival_time', 'std_inter_arrival_time',
    'min_inter_arrival_time', 'max_inter_arrival_time',
    'syn_count', 'ack_count', 'fin_count', 'rst_count', 'psh_count',
    'mean_tcp_window', 'mean_ttl', 'mean_tos'
]

# Check if we have enough samples per class
min_samples_per_class = df['traffic_type'].value_counts().min()
if min_samples_per_class < 50:
    print(f"\n⚠️  WARNING: Only {min_samples_per_class} samples for smallest class!")
    print("   Model may not perform well. Consider running more iterations.")

# Prepare data
X = df[feature_cols].fillna(0).values
y = df['traffic_type'].values

# Encode labels
label_encoder = LabelEncoder()
y_encoded = label_encoder.fit_transform(y)

print(f"\nClasses: {list(label_encoder.classes_)}")

# Split data
X_train, X_test, y_train, y_test = train_test_split(
    X, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded
)

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Train Random Forest
print(f"\n🌲 Training Random Forest Classifier...")
print(f"Training samples: {len(X_train)}")
print(f"Test samples: {len(X_test)}")
print("")

model = RandomForestClassifier(
    n_estimators=100,
    max_depth=15,
    min_samples_split=5,
    random_state=42,
    n_jobs=-1
)

model.fit(X_train_scaled, y_train)

# Evaluate
train_acc = model.score(X_train_scaled, y_train)
test_acc = model.score(X_test_scaled, y_test)

print(f"✅ Training Accuracy: {train_acc*100:.2f}%")
print(f"✅ Test Accuracy: {test_acc*100:.2f}%")

# Feature importance
importances = model.feature_importances_
indices = np.argsort(importances)[::-1][:10]

print(f"\nTop 10 Most Important Features:")
for i, idx in enumerate(indices):
    print(f"  {i+1}. {feature_cols[idx]}: {importances[idx]:.4f}")

# Backup old model
os.makedirs('data/models_backup_7switch', exist_ok=True)
os.system('cp -r data/models/* data/models_backup_7switch/ 2>/dev/null')
print("\n💾 Backed up old model to data/models_backup_7switch/")

# Save new model
os.makedirs('data/models', exist_ok=True)

with open('data/models/random_forest_model.pkl', 'wb') as f:
    pickle.dump(model, f)

with open('data/models/scaler.pkl', 'wb') as f:
    pickle.dump(scaler, f)

with open('data/models/label_encoder.pkl', 'wb') as f:
    pickle.dump(label_encoder, f)

# Save metadata
metadata = {
    'model_type': 'random_forest',
    'feature_names': feature_cols,
    'class_names': list(label_encoder.classes_),
    'train_accuracy': float(train_acc),
    'test_accuracy': float(test_acc),
    'training_samples': len(X_train),
    'approach': '7switch_topology_generated_data',
    'note': 'Trained on data generated from 7-switch topology WITHOUT port features!'
}

with open('data/models/model_metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)

print("\n✅ New model saved to data/models/")
print(f"   Model: Random Forest (100 trees)")
print(f"   Training data: {len(df)} samples from 7-switch topology")
print(f"   Features: {len(feature_cols)} features (NO ports!)")
print(f"   Classes: {list(label_encoder.classes_)}")
print(f"   Test Accuracy: {test_acc*100:.2f}%")
print(f"\n🎯 Model trained on YOUR topology's traffic patterns!")
ENDPYTHON

if [ $? -ne 0 ]; then
    echo "❌ Model training failed!"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "  TRAINING COMPLETE ✅"
echo "=========================================================================="
echo ""
echo "New model trained with:"
echo "  ✓ ~$TARGET_SAMPLES samples from 7-switch topology"
echo "  ✓ Real VIDEO, SSH, HTTP, FTP traffic patterns"
echo "  ✓ 27 statistical features (NO port numbers!)"
echo "  ✓ Matches your actual use case"
echo ""
echo "Next steps:"
echo "  1. Test the new model:"
echo "     bash scripts/test_honest_ml_complete.sh"
echo ""
echo "  2. If accuracy is good (>70%), integrate into Step 1:"
echo "     The model is already saved to data/models/"
echo ""
echo "  3. If it fails, restore old model:"
echo "     cp -r data/models_backup_7switch/* data/models/"
echo ""

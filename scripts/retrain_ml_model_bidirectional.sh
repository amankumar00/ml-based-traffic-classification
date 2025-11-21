#!/bin/bash
#
# Retrain ML Model with Bidirectional Features (NO PORT NUMBERS!)
# Based on research paper approach
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  RETRAINING ML MODEL - Bidirectional Flow Features (Paper's Approach)"
echo "=========================================================================="
echo ""
echo "This will retrain the ML model using:"
echo "  ✓ Bidirectional flow statistics (forward + reverse)"
echo "  ✓ Packet/byte rates (instantaneous + average)"
echo "  ✓ Inter-arrival times and packet sizes"
echo "  ✗ NO PORT NUMBERS (honest ML!)"
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

# Check for packet captures
PACKET_FILES=$(ls -1 data/raw/captured_packets_*.json 2>/dev/null | wc -l)
if [ "$PACKET_FILES" -eq 0 ]; then
    echo "❌ No packet captures found!"
    echo "   Please run traffic capture first"
    exit 1
fi

echo "Found $PACKET_FILES packet capture files"
echo ""

# Step 1: Extract bidirectional features
echo "1. Extracting bidirectional flow features (NO PORTS!)..."
python3 src/traffic_monitor/bidirectional_feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/bidirectional_features.csv

if [ ! -f data/processed/bidirectional_features.csv ]; then
    echo "❌ ERROR: Feature extraction failed!"
    exit 1
fi
echo ""

# Step 2: Train new model
echo "2. Training neural network with bidirectional features..."
echo ""

python3 << 'ENDPYTHON'
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
import tensorflow as tf
from tensorflow import keras
import pickle
import json
import os

# Load features
df = pd.read_csv('data/processed/bidirectional_features.csv')

# Filter for labeled data only
df = df[df['label'] != 'UNKNOWN']

print(f"Total labeled flows: {len(df)}")
print(f"\nLabel distribution:")
print(df['label'].value_counts())

if len(df) < 10:
    print("\n❌ ERROR: Not enough labeled data to train!")
    print("   Need at least 10 flows with known labels")
    exit(1)

# Feature columns (NO PORTS!)
feature_cols = [
    'forward_packets', 'forward_bytes', 'forward_inst_pps', 'forward_avg_pps',
    'forward_inst_bps', 'forward_avg_bps',
    'reverse_packets', 'reverse_bytes', 'reverse_inst_pps', 'reverse_avg_pps',
    'reverse_inst_bps', 'reverse_avg_bps',
    'flow_duration', 'forward_iat_mean', 'forward_iat_std',
    'reverse_iat_mean', 'reverse_iat_std',
    'forward_pkt_size_mean', 'forward_pkt_size_std',
    'reverse_pkt_size_mean', 'reverse_pkt_size_std',
    'forward_packet_ratio', 'forward_byte_ratio',
    'protocol'
]

# Ensure all features exist
for col in feature_cols:
    if col not in df.columns:
        df[col] = 0

X = df[feature_cols].fillna(0).values
y = df['label'].values

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

# Build neural network
model = keras.Sequential([
    keras.layers.Dense(64, activation='relu', input_shape=(len(feature_cols),)),
    keras.layers.Dropout(0.3),
    keras.layers.Dense(32, activation='relu'),
    keras.layers.Dropout(0.2),
    keras.layers.Dense(len(label_encoder.classes_), activation='softmax')
])

model.compile(
    optimizer='adam',
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

print("\n🧠 Training Neural Network...")
print(f"Features: {len(feature_cols)} (NO PORT NUMBERS!)")
print(f"Training samples: {len(X_train)}")
print(f"Test samples: {len(X_test)}")
print("")

history = model.fit(
    X_train_scaled, y_train,
    epochs=50,
    batch_size=8,
    validation_split=0.2,
    verbose=1
)

# Evaluate
test_loss, test_acc = model.evaluate(X_test_scaled, y_test, verbose=0)
print(f"\n✅ Test Accuracy: {test_acc*100:.2f}%")

# Backup old model
os.makedirs('data/models_backup', exist_ok=True)
os.system('cp -r data/models/* data/models_backup/ 2>/dev/null')
print("\n💾 Backed up old model to data/models_backup/")

# Save new model
os.makedirs('data/models', exist_ok=True)
model.save('data/models/neural_network_model.keras')

# Save scaler
with open('data/models/scaler.pkl', 'wb') as f:
    pickle.dump(scaler, f)

# Save label encoder
with open('data/models/label_encoder.pkl', 'wb') as f:
    pickle.dump(label_encoder, f)

# Save metadata
metadata = {
    'model_type': 'neural_network',
    'feature_names': feature_cols,
    'class_names': list(label_encoder.classes_),
    'test_accuracy': float(test_acc),
    'training_samples': len(X_train),
    'approach': 'bidirectional_flow_statistics'
}

with open('data/models/model_metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)

print("\n✅ New model saved to data/models/")
print(f"   Approach: Bidirectional Flow Statistics (Paper-based)")
print(f"   Features: {len(feature_cols)} features (NO ports!)")
print(f"   Classes: {list(label_encoder.classes_)}")
print(f"   Test Accuracy: {test_acc*100:.2f}%")

ENDPYTHON

echo ""
echo "=========================================================================="
echo "  RETRAINING COMPLETE ✅"
echo "=========================================================================="
echo ""
echo "New model trained with:"
echo "  ✓ Bidirectional flow statistics (forward + reverse)"
echo "  ✓ NO port numbers as features!"
echo "  ✓ Honest machine learning"
echo ""
echo "Old model backed up to: data/models_backup/"
echo "New model saved to: data/models/"
echo ""
echo "Next steps:"
echo "  1. Test the new classifier:"
echo "     sudo bash scripts/test_7switch_step1_ml_classification.sh"
echo ""
echo "  2. If it fails, restore the old model:"
echo "     cp -r data/models_backup/* data/models/"
echo ""

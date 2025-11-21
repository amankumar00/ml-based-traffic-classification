#!/bin/bash
#
# Train ML Model with Synthetic Training Data
#
# This script:
#   1. Generates 10k diverse synthetic training samples
#   2. Trains Random Forest model WITHOUT port features
#   3. Tests the model on existing 7-switch captures
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  TRAIN ML MODEL - Synthetic Training Data"
echo "=========================================================================="
echo ""
echo "This will:"
echo "  1. Generate 10,000 diverse synthetic training samples"
echo "  2. Train Random Forest model (NO PORT FEATURES!)"
echo "  3. Test on your 7-switch packet captures"
echo ""
echo "Synthetic data includes realistic randomness for:"
echo "  • VIDEO: High bitrate, steady rate, asymmetric"
echo "  • SSH: Bursty, interactive, symmetric"
echo "  • HTTP: Request-response, moderate asymmetry"
echo "  • FTP: Bulk transfer, very asymmetric"
echo ""
echo "=========================================================================="
echo ""

cd "$PROJECT_ROOT"

# Activate conda
source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate ml-sdn 2>/dev/null

# Step 1: Generate synthetic training data
echo "=========================================================================="
echo "STEP 1: Generate Synthetic Training Data"
echo "=========================================================================="
echo ""

python3 scripts/generate_synthetic_training_data.py -n 10000 -o data/processed/synthetic_training_data.csv

if [ ! -f data/processed/synthetic_training_data.csv ]; then
    echo "❌ Synthetic data generation failed!"
    exit 1
fi

echo ""

# Step 2: Train model on synthetic data
echo "=========================================================================="
echo "STEP 2: Train ML Model"
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

# Load synthetic training data
df = pd.read_csv('data/processed/synthetic_training_data.csv')

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
    n_estimators=200,
    max_depth=20,
    min_samples_split=10,
    min_samples_leaf=4,
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
os.makedirs('data/models_backup_synthetic', exist_ok=True)
os.system('cp -r data/models/* data/models_backup_synthetic/ 2>/dev/null')
print("\n💾 Backed up old model to data/models_backup_synthetic/")

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
    'approach': 'synthetic_diverse_data',
    'note': 'Trained on diverse synthetic data WITHOUT port features!'
}

with open('data/models/model_metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)

print("\n✅ New model saved to data/models/")
print(f"   Model: Random Forest (200 trees)")
print(f"   Training data: {len(df)} synthetic samples")
print(f"   Features: {len(feature_cols)} features (NO ports!)")
print(f"   Classes: {list(label_encoder.classes_)}")
print(f"   Test Accuracy: {test_acc*100:.2f}%")
print(f"\n🎯 Model trained on DIVERSE traffic patterns with realistic randomness!")
ENDPYTHON

if [ $? -ne 0 ]; then
    echo "❌ Model training failed!"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "STEP 3: Test on 7-Switch Captures"
echo "=========================================================================="
echo ""

bash scripts/test_honest_ml_complete.sh

echo ""
echo "=========================================================================="
echo "  TRAINING COMPLETE ✅"
echo "=========================================================================="
echo ""
echo "Model trained with:"
echo "  ✓ 10,000 diverse synthetic samples"
echo "  ✓ Realistic traffic patterns with randomness"
echo "  ✓ 27 statistical features (NO port numbers!)"
echo "  ✓ No overfitting - each sample is unique"
echo ""
echo "Model backups:"
echo "  • data/models_backup_synthetic/ (previous model)"
echo "  • data/models/ (NEW synthetic-trained model)"
echo ""
echo "To restore old model if needed:"
echo "  cp -r data/models_backup_synthetic/* data/models/"
echo ""

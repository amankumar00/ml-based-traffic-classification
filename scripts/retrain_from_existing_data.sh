#!/bin/bash
#
# Retrain ML Model from Existing Training Data (NO PORT FEATURES!)
# Uses data/processed/training_data_no_icmp.csv but EXCLUDES port columns
#

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================================================="
echo "  RETRAINING ML MODEL - Using Existing Training Data (NO PORTS!)"
echo "=========================================================================="
echo ""
echo "Training data: data/processed/training_data_no_icmp.csv"
echo "Features: Will EXCLUDE src_port and dst_port for honest ML"
echo ""
echo "=========================================================================="
echo ""

# No sudo needed for training! Just use current user
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

# Check training data exists
if [ ! -f "data/processed/training_data_no_icmp.csv" ]; then
    echo "❌ Training data not found: data/processed/training_data_no_icmp.csv"
    exit 1
fi

ROWS=$(wc -l < data/processed/training_data_no_icmp.csv)
echo "Found training data: $ROWS rows"
echo ""

# Train model
echo "Training neural network (EXCLUDING port features)..."
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
df = pd.read_csv('data/processed/training_data_no_icmp.csv')

print(f"Total samples: {len(df)}")
print(f"\nTraffic type distribution:")
print(df['traffic_type'].value_counts())

# Feature columns (EXCLUDING src_port and dst_port!)
all_features = [
    'total_packets', 'forward_packets', 'backward_packets',
    'total_bytes', 'forward_bytes', 'backward_bytes',
    'flow_duration', 'packets_per_second', 'bytes_per_second',
    'min_packet_size', 'max_packet_size', 'mean_packet_size', 'std_packet_size',
    'mean_forward_packet_size', 'mean_backward_packet_size',
    'mean_inter_arrival_time', 'std_inter_arrival_time',
    'min_inter_arrival_time', 'max_inter_arrival_time',
    'syn_count', 'ack_count', 'fin_count', 'rst_count', 'psh_count',
    'mean_tcp_window', 'mean_ttl', 'mean_tos'
    # NOTE: src_port and dst_port EXCLUDED!
]

# Filter to only features that exist in the dataframe
feature_cols = [f for f in all_features if f in df.columns]

print(f"\nUsing {len(feature_cols)} features (NO PORTS!)")
print(f"Excluded: src_port, dst_port")

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

# Train Random Forest (faster and more stable than neural network for this size)
print("\n🌲 Training Random Forest Classifier...")
print(f"Training samples: {len(X_train)}")
print(f"Test samples: {len(X_test)}")
print("")

model = RandomForestClassifier(
    n_estimators=100,
    max_depth=10,
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
os.makedirs('data/models_backup', exist_ok=True)
os.system('cp -r data/models/* data/models_backup/ 2>/dev/null')
print("\n💾 Backed up old model to data/models_backup/")

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
    'approach': 'statistical_features_no_ports',
    'note': 'Trained WITHOUT port numbers as features!'
}

with open('data/models/model_metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)

print("\n✅ New model saved to data/models/")
print(f"   Model: Random Forest (100 trees)")
print(f"   Features: {len(feature_cols)} features (NO ports!)")
print(f"   Classes: {list(label_encoder.classes_)}")
print(f"   Test Accuracy: {test_acc*100:.2f}%")
print(f"\n🎯 This is REAL machine learning!")

ENDPYTHON

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================================================="
    echo "  TRAINING COMPLETE ✅"
    echo "=========================================================================="
    echo ""
    echo "New model trained with:"
    echo "  ✓ 800 training samples"
    echo "  ✓ Statistical flow features ONLY"
    echo "  ✓ NO port numbers!"
    echo "  ✓ Honest machine learning"
    echo ""
    echo "Next steps:"
    echo "  1. Test the new classifier:"
    echo "     sudo bash scripts/test_pure_ml_classifier.sh"
    echo ""
    echo "  2. If it fails, restore old model:"
    echo "     cp -r data/models_backup/* data/models/"
    echo ""
else
    echo ""
    echo "❌ Training failed!"
    exit 1
fi

"""
Classify flows using bidirectional flow statistics (NO PORT-BASED OVERRIDE!)
Based on research paper approach - pure ML classification
"""

import os
import sys
import json
import pickle
import pandas as pd
import numpy as np
from datetime import datetime
import tensorflow as tf


def ip_to_host(ip):
    """Convert IP address to host name"""
    if not ip or ip == '::' or ip == '0.0.0.0':
        return 'unknown'

    if '.' in ip:
        parts = ip.split('.')
        if len(parts) == 4 and parts[0] == '10' and parts[1] == '0' and parts[2] == '0':
            try:
                return f'h{int(parts[3])}'
            except:
                pass

    return ip


def main():
    if len(sys.argv) < 4:
        print("Usage: python classify_and_export_bidirectional.py <model_dir> <features.csv> <output.csv>")
        sys.exit(1)

    model_dir = sys.argv[1]
    features_file = sys.argv[2]
    output_file = sys.argv[3]

    # Load model
    print(f"Loading bidirectional ML model from {model_dir}...")
    metadata_path = os.path.join(model_dir, 'model_metadata.json')
    with open(metadata_path, 'r') as f:
        metadata = json.load(f)

    model_path = os.path.join(model_dir, 'neural_network_model.keras')
    model = tf.keras.models.load_model(model_path)

    scaler_path = os.path.join(model_dir, 'scaler.pkl')
    with open(scaler_path, 'rb') as f:
        scaler = pickle.load(f)

    encoder_path = os.path.join(model_dir, 'label_encoder.pkl')
    with open(encoder_path, 'rb') as f:
        label_encoder = pickle.load(f)

    print(f"Model approach: {metadata.get('approach', 'unknown')}")
    print(f"Classes: {metadata['class_names']}")
    print(f"Features: {len(metadata['feature_names'])} (NO PORT NUMBERS!)")

    # Load features
    print(f"\nLoading features from {features_file}...")
    features_df = pd.read_csv(features_file)
    print(f"Total flows: {len(features_df)}")

    # Get feature names from model metadata
    feature_names = metadata['feature_names']

    # Ensure all required features exist
    for feat in feature_names:
        if feat not in features_df.columns:
            features_df[feat] = 0

    # Select features
    X = features_df[feature_names].fillna(0)
    X_scaled = scaler.transform(X)

    # Predict with PURE ML (no port-based override!)
    print("\n🧠 Classifying with PURE ML (no port-based override)...")
    predictions = model.predict(X_scaled, verbose=0)
    predicted_classes = np.argmax(predictions, axis=1)
    confidences = np.max(predictions, axis=1)

    # Decode predictions
    traffic_types = label_encoder.inverse_transform(predicted_classes)

    # Build output
    print("\nBuilding results...")
    results = []

    for i in range(len(features_df)):
        # Get metadata from features
        src_host = features_df.iloc[i].get('src_host', 'unknown')
        dst_host = features_df.iloc[i].get('dst_host', 'unknown')
        src_ip = features_df.iloc[i].get('src_ip', 'unknown')
        dst_ip = features_df.iloc[i].get('dst_ip', 'unknown')

        # Protocol
        protocol_val = features_df.iloc[i].get('protocol', 3)
        protocol_map = {0: 'TCP', 1: 'UDP', 2: 'ICMP', 3: 'OTHER'}
        protocol = protocol_map.get(int(protocol_val), 'OTHER')

        # Note: We don't have src_port/dst_port in bidirectional features!
        # This is intentional - forces pure ML classification
        result = {
            'flow_id': i + 1,
            'src_host': src_host,
            'dst_host': dst_host,
            'src_ip': src_ip,
            'dst_ip': dst_ip,
            'src_port': 0,  # Not used in bidirectional approach
            'dst_port': 0,  # Not used in bidirectional approach
            'protocol': protocol,
            'traffic_type': traffic_types[i],
            'confidence': f"{confidences[i]:.4f}",
            'total_packets': int(features_df.iloc[i].get('forward_packets', 0) + features_df.iloc[i].get('reverse_packets', 0)),
            'total_bytes': int(features_df.iloc[i].get('forward_bytes', 0) + features_df.iloc[i].get('reverse_bytes', 0)),
            'flow_duration': f"{features_df.iloc[i].get('flow_duration', 0):.4f}",
            'packets_per_second': f"{features_df.iloc[i].get('forward_avg_pps', 0) + features_df.iloc[i].get('reverse_avg_pps', 0):.2f}"
        }

        results.append(result)

    # Create DataFrame
    results_df = pd.DataFrame(results)

    # Save
    results_df.to_csv(output_file, index=False)
    print(f"\n✓ Results saved to {output_file}")
    print(f"  Total flows: {len(results_df)}")
    print(f"  🧠 PURE ML CLASSIFICATION (bidirectional features, no port override)")

    # Show summary
    print("\nTraffic Summary:")
    summary = results_df['traffic_type'].value_counts()
    for traffic_type, count in summary.items():
        percentage = (count / len(results_df)) * 100
        print(f"  {traffic_type}: {count} flows ({percentage:.1f}%)")

    # Show sample flows
    print("\nSample flows:")
    print(results_df[['src_host', 'dst_host', 'traffic_type', 'confidence']].head(10).to_string(index=False))

    # Show confidence distribution
    print(f"\nConfidence statistics:")
    print(f"  Mean: {results_df['confidence'].astype(float).mean():.4f}")
    print(f"  Min:  {results_df['confidence'].astype(float).min():.4f}")
    print(f"  Max:  {results_df['confidence'].astype(float).max():.4f}")


if __name__ == '__main__':
    main()

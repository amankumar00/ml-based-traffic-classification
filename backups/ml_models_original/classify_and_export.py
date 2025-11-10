"""
Classify flows and export detailed results to CSV
Shows which traffic types are flowing between which hosts
"""

import os
import sys
import json
import pickle
import pandas as pd
import numpy as np
from datetime import datetime


def ip_to_host(ip):
    """Convert IP address to host name (e.g., 10.0.0.1 -> h1)"""
    if not ip or ip == '::' or ip == '0.0.0.0':
        return 'unknown'

    # Handle IPv4
    if '.' in ip:
        parts = ip.split('.')
        if len(parts) == 4 and parts[0] == '10' and parts[1] == '0' and parts[2] == '0':
            try:
                host_num = int(parts[3])
                return f'h{host_num}'
            except ValueError:
                pass

    # Handle IPv6 or other formats
    return ip


def parse_flow_key(flow_key_str):
    """
    Parse flow_key string like '(10.0.0.1, 5004, 10.0.0.3, 44000, UDP)'
    Format is: (dst_ip, dst_port, src_ip, src_port, protocol)
    Returns: dict with src_ip, src_port, dst_ip, dst_port, protocol
    """
    try:
        # Remove parentheses and split by comma
        flow_key_str = str(flow_key_str).strip('()')
        parts = [p.strip().strip("'\"") for p in flow_key_str.split(',')]

        if len(parts) >= 5:
            return {
                'dst_ip': parts[0],
                'dst_port': int(parts[1]) if parts[1].isdigit() else 0,
                'src_ip': parts[2],
                'src_port': int(parts[3]) if parts[3].isdigit() else 0,
                'protocol': parts[4]
            }
    except Exception as e:
        print(f"Warning: Could not parse flow_key: {flow_key_str} - {e}")

    return {
        'src_ip': 'unknown',
        'src_port': 0,
        'dst_ip': 'unknown',
        'dst_port': 0,
        'protocol': 'unknown'
    }


def main():
    if len(sys.argv) < 4:
        print("Usage: python classify_and_export.py <model_dir> <features.csv> <output.csv>")
        sys.exit(1)

    model_dir = sys.argv[1]
    features_file = sys.argv[2]
    output_file = sys.argv[3]

    # Load model
    print(f"Loading model from {model_dir}...")
    metadata_path = os.path.join(model_dir, 'model_metadata.json')
    with open(metadata_path, 'r') as f:
        metadata = json.load(f)

    model_type = metadata['model_type']
    model_path = os.path.join(model_dir, f'{model_type}_model.pkl')
    with open(model_path, 'rb') as f:
        model = pickle.load(f)

    scaler_path = os.path.join(model_dir, 'scaler.pkl')
    with open(scaler_path, 'rb') as f:
        scaler = pickle.load(f)

    encoder_path = os.path.join(model_dir, 'label_encoder.pkl')
    with open(encoder_path, 'rb') as f:
        label_encoder = pickle.load(f)

    print(f"Model: {model_type}")
    print(f"Classes: {metadata['class_names']}")

    # Load features
    print(f"\nLoading features from {features_file}...")
    features_df = pd.read_csv(features_file)
    print(f"Total flows: {len(features_df)}")

    # Prepare feature columns
    feature_names = metadata['feature_names']

    # Ensure all required features exist
    for feat in feature_names:
        if feat not in features_df.columns:
            features_df[feat] = 0

    # Preprocess protocol column if it exists
    if 'protocol' in features_df.columns:
        protocol_mapping = {'TCP': 0, 'UDP': 1, 'ICMP': 2, 'OTHER': 3}
        features_df['protocol'] = features_df['protocol'].map(protocol_mapping).fillna(3)

    # Extract flow_key before selecting features
    flow_keys = features_df['flow_key'].values if 'flow_key' in features_df.columns else None

    # Select and scale features
    X = features_df[feature_names].fillna(0)
    X_scaled = scaler.transform(X)

    # Predict
    print("\nClassifying flows...")
    predictions = model.predict(X_scaled)

    if hasattr(model, 'predict_proba'):
        prediction_proba = model.predict_proba(X_scaled)
        confidences = np.max(prediction_proba, axis=1)
    else:
        confidences = [1.0] * len(predictions)

    # Decode predictions
    predicted_classes = label_encoder.inverse_transform(predictions)

    # Build output dataframe
    print("\nBuilding results...")
    results = []

    for i in range(len(features_df)):
        # Parse flow key
        if flow_keys is not None:
            flow_info = parse_flow_key(flow_keys[i])
        else:
            flow_info = {
                'src_ip': 'unknown',
                'src_port': 0,
                'dst_ip': 'unknown',
                'dst_port': 0,
                'protocol': 'unknown'
            }

        # Get host names
        src_host = ip_to_host(flow_info['src_ip'])
        dst_host = ip_to_host(flow_info['dst_ip'])

        # Build result row
        result = {
            'flow_id': i + 1,
            'src_host': src_host,
            'dst_host': dst_host,
            'src_ip': flow_info['src_ip'],
            'dst_ip': flow_info['dst_ip'],
            'src_port': flow_info['src_port'],
            'dst_port': flow_info['dst_port'],
            'protocol': flow_info['protocol'],
            'traffic_type': predicted_classes[i],
            'confidence': f"{confidences[i]:.4f}",
            'total_packets': int(features_df.iloc[i].get('total_packets', 0)),
            'total_bytes': int(features_df.iloc[i].get('total_bytes', 0)),
            'flow_duration': f"{features_df.iloc[i].get('flow_duration', 0):.4f}",
            'packets_per_second': f"{features_df.iloc[i].get('packets_per_second', 0):.2f}"
        }

        results.append(result)

    # Create results dataframe
    results_df = pd.DataFrame(results)

    # Save to CSV
    results_df.to_csv(output_file, index=False)
    print(f"\n✓ Results saved to {output_file}")
    print(f"  Total flows: {len(results_df)}")

    # Show summary
    print("\nTraffic Summary:")
    summary = results_df['traffic_type'].value_counts()
    for traffic_type, count in summary.items():
        percentage = (count / len(results_df)) * 100
        print(f"  {traffic_type}: {count} flows ({percentage:.1f}%)")

    # Show sample flows
    print("\nSample flows:")
    print(results_df[['src_host', 'dst_host', 'src_port', 'dst_port', 'traffic_type', 'confidence']].head(10).to_string(index=False))

    # Show flows by host pairs
    print("\n\nFlows by host pairs:")
    host_pairs = results_df.groupby(['src_host', 'dst_host', 'traffic_type']).size().reset_index(name='count')
    host_pairs = host_pairs.sort_values('count', ascending=False)
    print(host_pairs.head(20).to_string(index=False))


if __name__ == '__main__':
    main()

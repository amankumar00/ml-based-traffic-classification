"""
Generate sample labeled training data for traffic classification
This creates synthetic training data with different traffic patterns
"""

import pandas as pd
import numpy as np
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def generate_http_traffic(n_samples=100):
    """Generate HTTP traffic features"""
    data = []
    for i in range(n_samples):
        features = {
            'total_packets': np.random.randint(50, 500),
            'forward_packets': np.random.randint(25, 250),
            'backward_packets': np.random.randint(25, 250),
            'total_bytes': np.random.randint(5000, 100000),
            'forward_bytes': np.random.randint(2000, 50000),
            'backward_bytes': np.random.randint(3000, 50000),
            'flow_duration': np.random.uniform(0.5, 30.0),
            'packets_per_second': np.random.uniform(10, 100),
            'bytes_per_second': np.random.uniform(1000, 50000),
            'min_packet_size': np.random.randint(40, 100),
            'max_packet_size': np.random.randint(1000, 1500),
            'mean_packet_size': np.random.uniform(200, 800),
            'std_packet_size': np.random.uniform(50, 300),
            'mean_forward_packet_size': np.random.uniform(100, 500),
            'mean_backward_packet_size': np.random.uniform(100, 500),
            'mean_inter_arrival_time': np.random.uniform(0.01, 0.5),
            'std_inter_arrival_time': np.random.uniform(0.005, 0.3),
            'min_inter_arrival_time': np.random.uniform(0.001, 0.05),
            'max_inter_arrival_time': np.random.uniform(0.5, 2.0),
            'syn_count': np.random.randint(1, 5),
            'ack_count': np.random.randint(20, 200),
            'fin_count': np.random.randint(0, 3),
            'rst_count': 0,
            'psh_count': np.random.randint(5, 50),
            'mean_tcp_window': np.random.randint(20000, 65535),
            'mean_ttl': 64,
            'mean_tos': 0,
            'src_port': np.random.randint(1024, 65535),
            'dst_port': 80 if np.random.random() > 0.3 else 443,
            'traffic_type': 'HTTP'
        }
        data.append(features)
    return data


def generate_ftp_traffic(n_samples=100):
    """Generate FTP traffic features"""
    data = []
    for i in range(n_samples):
        features = {
            'total_packets': np.random.randint(200, 2000),
            'forward_packets': np.random.randint(100, 1000),
            'backward_packets': np.random.randint(100, 1000),
            'total_bytes': np.random.randint(50000, 5000000),
            'forward_bytes': np.random.randint(20000, 2500000),
            'backward_bytes': np.random.randint(30000, 2500000),
            'flow_duration': np.random.uniform(5.0, 120.0),
            'packets_per_second': np.random.uniform(20, 150),
            'bytes_per_second': np.random.uniform(10000, 200000),
            'min_packet_size': np.random.randint(40, 100),
            'max_packet_size': 1460,
            'mean_packet_size': np.random.uniform(800, 1400),
            'std_packet_size': np.random.uniform(100, 400),
            'mean_forward_packet_size': np.random.uniform(700, 1400),
            'mean_backward_packet_size': np.random.uniform(100, 500),
            'mean_inter_arrival_time': np.random.uniform(0.005, 0.1),
            'std_inter_arrival_time': np.random.uniform(0.002, 0.05),
            'min_inter_arrival_time': np.random.uniform(0.0001, 0.01),
            'max_inter_arrival_time': np.random.uniform(0.2, 1.0),
            'syn_count': np.random.randint(1, 3),
            'ack_count': np.random.randint(100, 1000),
            'fin_count': np.random.randint(1, 3),
            'rst_count': 0,
            'psh_count': np.random.randint(50, 500),
            'mean_tcp_window': np.random.randint(30000, 65535),
            'mean_ttl': 64,
            'mean_tos': 0,
            'src_port': np.random.randint(1024, 65535),
            'dst_port': 21,
            'traffic_type': 'FTP'
        }
        data.append(features)
    return data


def generate_ssh_traffic(n_samples=100):
    """Generate SSH traffic features"""
    data = []
    for i in range(n_samples):
        features = {
            'total_packets': np.random.randint(100, 1000),
            'forward_packets': np.random.randint(50, 500),
            'backward_packets': np.random.randint(50, 500),
            'total_bytes': np.random.randint(10000, 200000),
            'forward_bytes': np.random.randint(5000, 100000),
            'backward_bytes': np.random.randint(5000, 100000),
            'flow_duration': np.random.uniform(10.0, 300.0),
            'packets_per_second': np.random.uniform(5, 50),
            'bytes_per_second': np.random.uniform(500, 10000),
            'min_packet_size': 40,
            'max_packet_size': np.random.randint(200, 1000),
            'mean_packet_size': np.random.uniform(100, 300),
            'std_packet_size': np.random.uniform(30, 150),
            'mean_forward_packet_size': np.random.uniform(80, 250),
            'mean_backward_packet_size': np.random.uniform(80, 250),
            'mean_inter_arrival_time': np.random.uniform(0.05, 0.5),
            'std_inter_arrival_time': np.random.uniform(0.02, 0.3),
            'min_inter_arrival_time': np.random.uniform(0.001, 0.05),
            'max_inter_arrival_time': np.random.uniform(1.0, 5.0),
            'syn_count': 1,
            'ack_count': np.random.randint(50, 500),
            'fin_count': np.random.randint(0, 2),
            'rst_count': 0,
            'psh_count': np.random.randint(20, 300),
            'mean_tcp_window': np.random.randint(10000, 40000),
            'mean_ttl': 64,
            'mean_tos': 16,
            'src_port': np.random.randint(1024, 65535),
            'dst_port': 22,
            'traffic_type': 'SSH'
        }
        data.append(features)
    return data


def generate_icmp_traffic(n_samples=100):
    """Generate ICMP traffic features"""
    data = []
    for i in range(n_samples):
        features = {
            'total_packets': np.random.randint(10, 100),
            'forward_packets': np.random.randint(5, 50),
            'backward_packets': np.random.randint(5, 50),
            'total_bytes': np.random.randint(500, 10000),
            'forward_bytes': np.random.randint(250, 5000),
            'backward_bytes': np.random.randint(250, 5000),
            'flow_duration': np.random.uniform(1.0, 10.0),
            'packets_per_second': np.random.uniform(1, 20),
            'bytes_per_second': np.random.uniform(100, 2000),
            'min_packet_size': 64,
            'max_packet_size': 84,
            'mean_packet_size': 74,
            'std_packet_size': 5,
            'mean_forward_packet_size': 74,
            'mean_backward_packet_size': 74,
            'mean_inter_arrival_time': np.random.uniform(0.1, 1.0),
            'std_inter_arrival_time': np.random.uniform(0.01, 0.2),
            'min_inter_arrival_time': np.random.uniform(0.05, 0.5),
            'max_inter_arrival_time': np.random.uniform(1.0, 2.0),
            'syn_count': 0,
            'ack_count': 0,
            'fin_count': 0,
            'rst_count': 0,
            'psh_count': 0,
            'mean_tcp_window': 0,
            'mean_ttl': 64,
            'mean_tos': 0,
            'src_port': 0,
            'dst_port': 0,
            'traffic_type': 'ICMP'
        }
        data.append(features)
    return data


def generate_video_traffic(n_samples=100):
    """Generate Video streaming traffic features"""
    data = []
    for i in range(n_samples):
        features = {
            'total_packets': np.random.randint(500, 5000),
            'forward_packets': np.random.randint(50, 500),
            'backward_packets': np.random.randint(450, 4500),
            'total_bytes': np.random.randint(500000, 10000000),
            'forward_bytes': np.random.randint(10000, 200000),
            'backward_bytes': np.random.randint(490000, 9800000),
            'flow_duration': np.random.uniform(30.0, 600.0),
            'packets_per_second': np.random.uniform(50, 200),
            'bytes_per_second': np.random.uniform(100000, 500000),
            'min_packet_size': np.random.randint(100, 500),
            'max_packet_size': 1500,
            'mean_packet_size': np.random.uniform(1000, 1450),
            'std_packet_size': np.random.uniform(100, 300),
            'mean_forward_packet_size': np.random.uniform(100, 300),
            'mean_backward_packet_size': np.random.uniform(1200, 1450),
            'mean_inter_arrival_time': np.random.uniform(0.005, 0.05),
            'std_inter_arrival_time': np.random.uniform(0.002, 0.02),
            'min_inter_arrival_time': np.random.uniform(0.001, 0.01),
            'max_inter_arrival_time': np.random.uniform(0.1, 0.5),
            'syn_count': np.random.randint(1, 3),
            'ack_count': np.random.randint(200, 2000),
            'fin_count': np.random.randint(0, 2),
            'rst_count': 0,
            'psh_count': np.random.randint(100, 1000),
            'mean_tcp_window': np.random.randint(40000, 65535),
            'mean_ttl': 64,
            'mean_tos': 0,
            'src_port': np.random.randint(1024, 65535),
            'dst_port': np.random.choice([443, 8080, 1935]),
            'traffic_type': 'VIDEO'
        }
        data.append(features)
    return data


def main():
    """Generate sample dataset"""
    print("Generating sample training data...")

    # Generate data for each traffic type
    all_data = []
    all_data.extend(generate_http_traffic(200))
    all_data.extend(generate_ftp_traffic(200))
    all_data.extend(generate_ssh_traffic(200))
    all_data.extend(generate_icmp_traffic(200))
    all_data.extend(generate_video_traffic(200))

    # Create DataFrame
    df = pd.DataFrame(all_data)

    # Shuffle the data
    df = df.sample(frac=1, random_state=42).reset_index(drop=True)

    # Save to CSV
    output_dir = os.path.join(os.path.dirname(__file__), '..', 'data', 'processed')
    os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, 'sample_training_data.csv')

    df.to_csv(output_file, index=False)

    print(f"\nGenerated {len(df)} samples")
    print(f"Saved to: {output_file}")
    print(f"\nTraffic type distribution:")
    print(df['traffic_type'].value_counts())
    print(f"\nSample features:")
    print(df.head())


if __name__ == '__main__':
    main()

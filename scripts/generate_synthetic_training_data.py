#!/usr/bin/env python3
"""
Generate Synthetic Training Data for Traffic Classification

This script generates diverse synthetic traffic flow features with realistic
randomness to train the ML model WITHOUT overfitting to specific flows.

Traffic patterns are based on real-world characteristics:
- VIDEO: High bitrate, steady rate, asymmetric (server->client heavy)
- SSH: Bursty, interactive, symmetric-ish, small packets
- HTTP: Request-response pattern, moderate asymmetry
- FTP: High bitrate, sustained transfer, very asymmetric
"""

import pandas as pd
import numpy as np
import random
import argparse

# Set random seed for reproducibility
np.random.seed(42)
random.seed(42)


def generate_video_flow():
    """Generate VIDEO traffic features (e.g., streaming)"""
    # VIDEO characteristics: High forward bps, low reverse bps, steady rate

    duration = np.random.uniform(5, 120)  # 5s to 2min (include SHORT flows!)

    # Forward direction (server -> client): Heavy streaming
    # Include small flows (10-100 packets) for short captures!
    if np.random.random() < 0.3:  # 30% chance of small flow
        forward_packets = int(np.random.uniform(10, 100))
    else:
        forward_packets = int(np.random.uniform(500, 5000))
    forward_avg_pps = forward_packets / duration
    forward_bytes = int(forward_packets * np.random.uniform(800, 1400))  # Large packets
    forward_avg_bps = forward_bytes / duration

    # Reverse direction (client -> server): MINIMAL or ZERO for UDP streaming!
    # Real UDP video streams (like iperf) have NO backward packets
    # Include both UDP (0 backward) and TCP (few ACKs) scenarios
    if np.random.random() < 0.7:  # 70% chance of UDP-like (pure streaming)
        backward_packets = 0
        backward_bytes = 0
        backward_avg_pps = 0
        backward_avg_bps = 0
    else:  # 30% chance of TCP-like (with minimal ACKs)
        backward_packets = int(forward_packets * np.random.uniform(0.05, 0.15))  # Very few ACKs
        backward_avg_pps = backward_packets / duration
        backward_bytes = int(backward_packets * np.random.uniform(50, 100))  # Small ACKs
        backward_avg_bps = backward_bytes / duration

    total_packets = forward_packets + backward_packets
    total_bytes = forward_bytes + backward_bytes

    # Packet size statistics
    forward_pkt_sizes = np.random.normal(1200, 200, forward_packets).clip(500, 1500)
    if backward_packets > 0:
        backward_pkt_sizes = np.random.normal(60, 20, backward_packets).clip(40, 100)
        all_pkt_sizes = np.concatenate([forward_pkt_sizes, backward_pkt_sizes])
    else:
        backward_pkt_sizes = np.array([])
        all_pkt_sizes = forward_pkt_sizes

    # Inter-arrival times (steady for video)
    mean_iat = 1.0 / (total_packets / duration)
    forward_iat_mean = 1.0 / forward_avg_pps
    forward_iat_std = forward_iat_mean * np.random.uniform(0.1, 0.3)  # Low variance (steady)

    # TCP flags (video uses persistent connections)
    syn_count = np.random.randint(1, 3)
    fin_count = np.random.randint(0, 2)
    ack_count = int(total_packets * np.random.uniform(0.6, 0.9))
    psh_count = int(forward_packets * np.random.uniform(0.3, 0.6))
    rst_count = 0

    return {
        'total_packets': total_packets,
        'forward_packets': forward_packets,
        'backward_packets': backward_packets,
        'total_bytes': total_bytes,
        'forward_bytes': forward_bytes,
        'backward_bytes': backward_bytes,
        'flow_duration': duration,
        'packets_per_second': total_packets / duration,
        'bytes_per_second': total_bytes / duration,
        'min_packet_size': int(all_pkt_sizes.min()),
        'max_packet_size': int(all_pkt_sizes.max()),
        'mean_packet_size': int(all_pkt_sizes.mean()),
        'std_packet_size': int(all_pkt_sizes.std()),
        'mean_forward_packet_size': int(forward_pkt_sizes.mean()),
        'mean_backward_packet_size': int(backward_pkt_sizes.mean()) if len(backward_pkt_sizes) > 0 else 0 if backward_packets > 0 else 0,
        'mean_inter_arrival_time': mean_iat,
        'std_inter_arrival_time': mean_iat * 0.2,
        'min_inter_arrival_time': mean_iat * 0.5,
        'max_inter_arrival_time': mean_iat * 2.0,
        'syn_count': syn_count,
        'ack_count': ack_count,
        'fin_count': fin_count,
        'rst_count': rst_count,
        'psh_count': psh_count,
        'mean_tcp_window': int(np.random.uniform(20000, 65535)),
        'mean_ttl': int(np.random.uniform(60, 64)),
        'mean_tos': int(np.random.choice([0, 16, 32])),  # Some QoS marking
        'traffic_type': 'VIDEO'
    }


def generate_ssh_flow():
    """Generate SSH traffic features (interactive, bursty)"""
    # SSH characteristics: Bursty, small packets, bidirectional

    duration = np.random.uniform(5, 180)  # 5s to 3min (include SHORT!)

    # Bursty traffic (typing patterns)
    # Include small flows (5-50 packets) for short captures!
    if np.random.random() < 0.3:  # 30% chance of small flow
        num_bursts = int(np.random.uniform(1, 5))
        packets_per_burst = int(np.random.uniform(2, 8))
    else:
        num_bursts = int(np.random.uniform(5, 30))
        packets_per_burst = int(np.random.uniform(3, 15))

    forward_packets = int(num_bursts * packets_per_burst * np.random.uniform(0.9, 1.1))
    backward_packets = int(forward_packets * np.random.uniform(0.7, 1.3))  # More symmetric

    total_packets = forward_packets + backward_packets

    # Small packet sizes (encrypted keystrokes)
    forward_pkt_sizes = np.random.normal(150, 50, forward_packets).clip(60, 400)
    backward_pkt_sizes = np.random.normal(100, 40, backward_packets).clip(60, 300)
    all_pkt_sizes = np.concatenate([forward_pkt_sizes, backward_pkt_sizes])

    forward_bytes = int(forward_pkt_sizes.sum())
    backward_bytes = int(backward_pkt_sizes.sum())
    total_bytes = forward_bytes + backward_bytes

    # Bursty inter-arrival times
    mean_iat = duration / total_packets
    iat_std = mean_iat * np.random.uniform(1.5, 3.0)  # High variance (bursty)

    # TCP flags
    syn_count = np.random.randint(1, 2)
    fin_count = np.random.randint(0, 2)
    ack_count = int(total_packets * np.random.uniform(0.7, 0.95))
    psh_count = int(total_packets * np.random.uniform(0.5, 0.8))  # High PSH (interactive)
    rst_count = 0

    return {
        'total_packets': total_packets,
        'forward_packets': forward_packets,
        'backward_packets': backward_packets,
        'total_bytes': total_bytes,
        'forward_bytes': forward_bytes,
        'backward_bytes': backward_bytes,
        'flow_duration': duration,
        'packets_per_second': total_packets / duration,
        'bytes_per_second': total_bytes / duration,
        'min_packet_size': int(all_pkt_sizes.min()),
        'max_packet_size': int(all_pkt_sizes.max()),
        'mean_packet_size': int(all_pkt_sizes.mean()),
        'std_packet_size': int(all_pkt_sizes.std()),
        'mean_forward_packet_size': int(forward_pkt_sizes.mean()),
        'mean_backward_packet_size': int(backward_pkt_sizes.mean()) if len(backward_pkt_sizes) > 0 else 0,
        'mean_inter_arrival_time': mean_iat,
        'std_inter_arrival_time': iat_std,
        'min_inter_arrival_time': mean_iat * 0.1,
        'max_inter_arrival_time': mean_iat * 5.0,
        'syn_count': syn_count,
        'ack_count': ack_count,
        'fin_count': fin_count,
        'rst_count': rst_count,
        'psh_count': psh_count,
        'mean_tcp_window': int(np.random.uniform(15000, 40000)),
        'mean_ttl': int(np.random.uniform(60, 64)),
        'mean_tos': 0,
        'traffic_type': 'SSH'
    }


def generate_http_flow():
    """Generate HTTP traffic features (request-response)"""
    # HTTP characteristics: Request-response, moderate asymmetry

    duration = np.random.uniform(1, 60)  # 1s to 1min

    # Request-response pattern
    # Include small flows (5-50 packets) for short captures!
    if np.random.random() < 0.3:  # 30% chance of small flow
        num_requests = int(np.random.uniform(1, 5))
    else:
        num_requests = int(np.random.uniform(1, 20))

    # Forward (client requests): Small
    forward_packets = int(num_requests * np.random.uniform(2, 10))
    forward_pkt_sizes = np.random.normal(300, 100, max(1, forward_packets)).clip(60, 800)
    forward_bytes = int(forward_pkt_sizes.sum())

    # Backward (server responses): Larger
    backward_packets = int(num_requests * np.random.uniform(5, 30))
    backward_pkt_sizes = np.random.normal(800, 300, backward_packets).clip(200, 1500)
    backward_bytes = int(backward_pkt_sizes.sum())

    total_packets = forward_packets + backward_packets
    total_bytes = forward_bytes + backward_bytes
    all_pkt_sizes = np.concatenate([forward_pkt_sizes, backward_pkt_sizes])

    # Inter-arrival times
    mean_iat = duration / total_packets
    iat_std = mean_iat * np.random.uniform(0.5, 1.5)  # Moderate variance

    # TCP flags
    syn_count = np.random.randint(1, num_requests + 1)  # May have multiple connections
    fin_count = np.random.randint(1, num_requests + 1)
    ack_count = int(total_packets * np.random.uniform(0.6, 0.9))
    psh_count = int(total_packets * np.random.uniform(0.3, 0.6))
    rst_count = np.random.randint(0, 2)

    return {
        'total_packets': total_packets,
        'forward_packets': forward_packets,
        'backward_packets': backward_packets,
        'total_bytes': total_bytes,
        'forward_bytes': forward_bytes,
        'backward_bytes': backward_bytes,
        'flow_duration': duration,
        'packets_per_second': total_packets / duration,
        'bytes_per_second': total_bytes / duration,
        'min_packet_size': int(all_pkt_sizes.min()),
        'max_packet_size': int(all_pkt_sizes.max()),
        'mean_packet_size': int(all_pkt_sizes.mean()),
        'std_packet_size': int(all_pkt_sizes.std()),
        'mean_forward_packet_size': int(forward_pkt_sizes.mean()),
        'mean_backward_packet_size': int(backward_pkt_sizes.mean()) if len(backward_pkt_sizes) > 0 else 0,
        'mean_inter_arrival_time': mean_iat,
        'std_inter_arrival_time': iat_std,
        'min_inter_arrival_time': mean_iat * 0.2,
        'max_inter_arrival_time': mean_iat * 3.0,
        'syn_count': syn_count,
        'ack_count': ack_count,
        'fin_count': fin_count,
        'rst_count': rst_count,
        'psh_count': psh_count,
        'mean_tcp_window': int(np.random.uniform(10000, 50000)),
        'mean_ttl': int(np.random.uniform(60, 64)),
        'mean_tos': 0,
        'traffic_type': 'HTTP'
    }


def generate_ftp_flow():
    """Generate FTP traffic features (bulk transfer)"""
    # FTP characteristics: Very high forward bps, sustained transfer, asymmetric

    duration = np.random.uniform(5, 180)  # 5s to 3min (include SHORT!)

    # Forward (file transfer): Very heavy
    # Include small flows (10-100 packets) for short captures!
    if np.random.random() < 0.3:  # 30% chance of small flow
        forward_packets = int(np.random.uniform(10, 150))
    else:
        forward_packets = int(np.random.uniform(1000, 10000))
    forward_pkt_sizes = np.random.normal(1400, 100, forward_packets).clip(1000, 1500)
    forward_bytes = int(forward_pkt_sizes.sum())

    # Backward (ACKs): Minimal
    backward_packets = int(forward_packets * np.random.uniform(0.2, 0.4))
    backward_pkt_sizes = np.random.normal(60, 20, backward_packets).clip(40, 100)
    backward_bytes = int(backward_pkt_sizes.sum())

    total_packets = forward_packets + backward_packets
    total_bytes = forward_bytes + backward_bytes
    all_pkt_sizes = np.concatenate([forward_pkt_sizes, backward_pkt_sizes])

    # Inter-arrival times (steady bulk transfer)
    mean_iat = duration / total_packets
    iat_std = mean_iat * np.random.uniform(0.1, 0.2)  # Very low variance (steady)

    # TCP flags
    syn_count = np.random.randint(1, 3)  # Control + data connection
    fin_count = np.random.randint(1, 3)
    ack_count = int(total_packets * np.random.uniform(0.5, 0.8))
    psh_count = int(forward_packets * np.random.uniform(0.2, 0.5))
    rst_count = 0

    return {
        'total_packets': total_packets,
        'forward_packets': forward_packets,
        'backward_packets': backward_packets,
        'total_bytes': total_bytes,
        'forward_bytes': forward_bytes,
        'backward_bytes': backward_bytes,
        'flow_duration': duration,
        'packets_per_second': total_packets / duration,
        'bytes_per_second': total_bytes / duration,
        'min_packet_size': int(all_pkt_sizes.min()),
        'max_packet_size': int(all_pkt_sizes.max()),
        'mean_packet_size': int(all_pkt_sizes.mean()),
        'std_packet_size': int(all_pkt_sizes.std()),
        'mean_forward_packet_size': int(forward_pkt_sizes.mean()),
        'mean_backward_packet_size': int(backward_pkt_sizes.mean()) if len(backward_pkt_sizes) > 0 else 0,
        'mean_inter_arrival_time': mean_iat,
        'std_inter_arrival_time': iat_std,
        'min_inter_arrival_time': mean_iat * 0.5,
        'max_inter_arrival_time': mean_iat * 1.5,
        'syn_count': syn_count,
        'ack_count': ack_count,
        'fin_count': fin_count,
        'rst_count': rst_count,
        'psh_count': psh_count,
        'mean_tcp_window': int(np.random.uniform(30000, 65535)),
        'mean_ttl': int(np.random.uniform(60, 64)),
        'mean_tos': 0,
        'traffic_type': 'FTP'
    }


def generate_training_data(num_samples=10000):
    """Generate balanced synthetic training data"""

    samples_per_class = num_samples // 4

    print(f"Generating {num_samples} synthetic training samples...")
    print(f"  {samples_per_class} VIDEO flows")
    print(f"  {samples_per_class} SSH flows")
    print(f"  {samples_per_class} HTTP flows")
    print(f"  {samples_per_class} FTP flows")
    print("")

    flows = []

    # Generate VIDEO flows
    print("Generating VIDEO flows...", end="", flush=True)
    for _ in range(samples_per_class):
        flows.append(generate_video_flow())
    print(" ✓")

    # Generate SSH flows
    print("Generating SSH flows...", end="", flush=True)
    for _ in range(samples_per_class):
        flows.append(generate_ssh_flow())
    print(" ✓")

    # Generate HTTP flows
    print("Generating HTTP flows...", end="", flush=True)
    for _ in range(samples_per_class):
        flows.append(generate_http_flow())
    print(" ✓")

    # Generate FTP flows
    print("Generating FTP flows...", end="", flush=True)
    for _ in range(samples_per_class):
        flows.append(generate_ftp_flow())
    print(" ✓")

    # Shuffle
    random.shuffle(flows)

    return pd.DataFrame(flows)


def main():
    parser = argparse.ArgumentParser(
        description='Generate synthetic training data for traffic classification'
    )
    parser.add_argument(
        '-n', '--num-samples',
        type=int,
        default=10000,
        help='Number of samples to generate (default: 10000)'
    )
    parser.add_argument(
        '-o', '--output',
        type=str,
        default='data/processed/synthetic_training_data.csv',
        help='Output CSV file (default: data/processed/synthetic_training_data.csv)'
    )

    args = parser.parse_args()

    # Generate data
    df = generate_training_data(args.num_samples)

    # Save to CSV
    df.to_csv(args.output, index=False)

    print(f"\n✅ Training data saved to: {args.output}")
    print(f"   Total samples: {len(df)}")
    print(f"\nTraffic type distribution:")
    print(df['traffic_type'].value_counts())

    print(f"\nSample statistics:")
    print(f"  Total packets: {df['total_packets'].min():.0f} - {df['total_packets'].max():.0f}")
    print(f"  Total bytes: {df['total_bytes'].min():.0f} - {df['total_bytes'].max():.0f}")
    print(f"  Flow duration: {df['flow_duration'].min():.1f}s - {df['flow_duration'].max():.1f}s")
    print(f"  Packets/sec: {df['packets_per_second'].min():.1f} - {df['packets_per_second'].max():.1f}")
    print(f"\n🎯 Ready to train ML model with diverse, realistic traffic patterns!")


if __name__ == '__main__':
    main()

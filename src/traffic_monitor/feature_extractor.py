"""
Feature Extractor for Network Traffic
Converts raw packet data into features suitable for ML classification
"""

import json
import pandas as pd
import numpy as np
from collections import defaultdict
from datetime import datetime


class TrafficFeatureExtractor:
    """
    Extracts statistical features from network traffic for ML classification
    Features include: flow duration, packet counts, byte counts, inter-arrival times, etc.
    """

    def __init__(self):
        self.flows = defaultdict(list)
        self.flow_features = []

    def extract_features_from_packets(self, packets):
        """
        Extract flow-based features from packet list

        Args:
            packets: List of packet dictionaries

        Returns:
            DataFrame with extracted features
        """
        # Group packets into flows (5-tuple: src_ip, dst_ip, src_port, dst_port, protocol)
        discarded_packets = 0
        discarded_by_reason = {}

        for packet in packets:
            flow_key = self._get_flow_key(packet)
            if flow_key:
                self.flows[flow_key].append(packet)
            else:
                # Track why packet was discarded
                discarded_packets += 1
                protocol = packet.get('protocol', 'UNKNOWN')
                has_ip = 'ip_src' in packet and 'ip_dst' in packet
                reason = f"{protocol} (missing IP info)" if not has_ip else f"{protocol} (other)"
                discarded_by_reason[reason] = discarded_by_reason.get(reason, 0) + 1

        # Log statistics
        if discarded_packets > 0:
            print(f"\nWARNING: {discarded_packets} packets discarded (no flow key created)")
            print("Discarded packet breakdown:")
            for reason, count in sorted(discarded_by_reason.items(), key=lambda x: -x[1]):
                print(f"  {reason}: {count} packets")
            print()

        # Extract features for each flow
        for flow_key, flow_packets in self.flows.items():
            features = self._extract_flow_features(flow_packets)
            features['flow_key'] = flow_key
            self.flow_features.append(features)

        return pd.DataFrame(self.flow_features)

    def _get_flow_key(self, packet):
        """Create unique flow identifier from packet"""
        if 'ip_src' not in packet or 'ip_dst' not in packet:
            return None

        src_ip = packet.get('ip_src')
        dst_ip = packet.get('ip_dst')
        src_port = packet.get('src_port', 0)
        dst_port = packet.get('dst_port', 0)
        protocol = packet.get('protocol', 'UNKNOWN')

        # Normalize flow direction (use lexicographic order)
        if (src_ip, src_port) < (dst_ip, dst_port):
            return (src_ip, src_port, dst_ip, dst_port, protocol)
        else:
            return (dst_ip, dst_port, src_ip, src_port, protocol)

    def _extract_flow_features(self, flow_packets):
        """Extract statistical features from a flow"""
        features = {}

        # Sort packets by timestamp
        flow_packets = sorted(flow_packets, key=lambda x: x.get('timestamp', 0))

        # Basic flow information
        features['protocol'] = flow_packets[0].get('protocol', 'UNKNOWN')
        features['src_port'] = flow_packets[0].get('src_port', 0)
        features['dst_port'] = flow_packets[0].get('dst_port', 0)

        # Temporal features
        timestamps = [p['timestamp'] for p in flow_packets if 'timestamp' in p]
        if len(timestamps) > 1:
            features['flow_duration'] = timestamps[-1] - timestamps[0]
            features['flow_start_time'] = timestamps[0]
        else:
            features['flow_duration'] = 0
            features['flow_start_time'] = timestamps[0] if timestamps else 0

        # Packet count features
        features['total_packets'] = len(flow_packets)
        features['forward_packets'] = sum(1 for p in flow_packets
                                          if p.get('ip_src') == flow_packets[0].get('ip_src'))
        features['backward_packets'] = features['total_packets'] - features['forward_packets']

        # Packet size features
        packet_sizes = [p.get('packet_size', 0) for p in flow_packets]
        features['total_bytes'] = sum(packet_sizes)
        features['min_packet_size'] = min(packet_sizes) if packet_sizes else 0
        features['max_packet_size'] = max(packet_sizes) if packet_sizes else 0
        features['mean_packet_size'] = np.mean(packet_sizes) if packet_sizes else 0
        features['std_packet_size'] = np.std(packet_sizes) if packet_sizes else 0

        # Forward/backward packet size statistics
        forward_sizes = [p.get('packet_size', 0) for p in flow_packets
                        if p.get('ip_src') == flow_packets[0].get('ip_src')]
        backward_sizes = [p.get('packet_size', 0) for p in flow_packets
                         if p.get('ip_src') != flow_packets[0].get('ip_src')]

        features['forward_bytes'] = sum(forward_sizes)
        features['backward_bytes'] = sum(backward_sizes)
        features['mean_forward_packet_size'] = np.mean(forward_sizes) if forward_sizes else 0
        features['mean_backward_packet_size'] = np.mean(backward_sizes) if backward_sizes else 0

        # Inter-arrival time features
        if len(timestamps) > 1:
            inter_arrival_times = [timestamps[i+1] - timestamps[i]
                                  for i in range(len(timestamps)-1)]
            features['mean_inter_arrival_time'] = np.mean(inter_arrival_times)
            features['std_inter_arrival_time'] = np.std(inter_arrival_times)
            features['min_inter_arrival_time'] = min(inter_arrival_times)
            features['max_inter_arrival_time'] = max(inter_arrival_times)
        else:
            features['mean_inter_arrival_time'] = 0
            features['std_inter_arrival_time'] = 0
            features['min_inter_arrival_time'] = 0
            features['max_inter_arrival_time'] = 0

        # Flow rate features
        if features['flow_duration'] > 0:
            features['packets_per_second'] = features['total_packets'] / features['flow_duration']
            features['bytes_per_second'] = features['total_bytes'] / features['flow_duration']
        else:
            features['packets_per_second'] = 0
            features['bytes_per_second'] = 0

        # TCP-specific features
        if features['protocol'] == 'TCP':
            tcp_flags = [p.get('tcp_flags', 0) for p in flow_packets if 'tcp_flags' in p]
            features['syn_count'] = sum(1 for f in tcp_flags if f & 0x02)  # SYN flag
            features['ack_count'] = sum(1 for f in tcp_flags if f & 0x10)  # ACK flag
            features['fin_count'] = sum(1 for f in tcp_flags if f & 0x01)  # FIN flag
            features['rst_count'] = sum(1 for f in tcp_flags if f & 0x04)  # RST flag
            features['psh_count'] = sum(1 for f in tcp_flags if f & 0x08)  # PSH flag

            tcp_windows = [p.get('tcp_window', 0) for p in flow_packets if 'tcp_window' in p]
            features['mean_tcp_window'] = np.mean(tcp_windows) if tcp_windows else 0
        else:
            features['syn_count'] = 0
            features['ack_count'] = 0
            features['fin_count'] = 0
            features['rst_count'] = 0
            features['psh_count'] = 0
            features['mean_tcp_window'] = 0

        # IP-specific features
        ip_ttls = [p.get('ip_ttl', 0) for p in flow_packets if 'ip_ttl' in p]
        features['mean_ttl'] = np.mean(ip_ttls) if ip_ttls else 0

        ip_tos_values = [p.get('ip_tos', 0) for p in flow_packets if 'ip_tos' in p]
        features['mean_tos'] = np.mean(ip_tos_values) if ip_tos_values else 0

        return features

    def load_and_extract(self, json_file_path):
        """
        Load packets from JSON file and extract features

        Args:
            json_file_path: Path to JSON file containing captured packets

        Returns:
            DataFrame with extracted features
        """
        with open(json_file_path, 'r') as f:
            packets = json.load(f)

        return self.extract_features_from_packets(packets)

    def get_feature_names(self):
        """Return list of feature names for ML model"""
        return [
            'total_packets', 'forward_packets', 'backward_packets',
            'total_bytes', 'forward_bytes', 'backward_bytes',
            'flow_duration', 'packets_per_second', 'bytes_per_second',
            'min_packet_size', 'max_packet_size', 'mean_packet_size', 'std_packet_size',
            'mean_forward_packet_size', 'mean_backward_packet_size',
            'mean_inter_arrival_time', 'std_inter_arrival_time',
            'min_inter_arrival_time', 'max_inter_arrival_time',
            'syn_count', 'ack_count', 'fin_count', 'rst_count', 'psh_count',
            'mean_tcp_window', 'mean_ttl', 'mean_tos',
            'src_port', 'dst_port'
        ]

    def save_features(self, output_path):
        """Save extracted features to CSV file"""
        df = pd.DataFrame(self.flow_features)
        df.to_csv(output_path, index=False)
        print(f"Features saved to {output_path}")
        return df


def main():
    """Example usage"""
    import sys
    import glob

    if len(sys.argv) < 2:
        print("Usage: python feature_extractor.py <input_json_files> [output_csv_file]")
        print("Example: python feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv")
        sys.exit(1)

    # Separate input files from output file
    # Last argument is output if it ends with .csv, otherwise use default
    args = sys.argv[1:]
    if len(args) > 1 and args[-1].endswith('.csv'):
        output_file = args[-1]
        input_patterns = args[:-1]
    else:
        output_file = 'extracted_features.csv'
        input_patterns = args

    # Expand glob patterns and collect all input files
    input_files = []
    for pattern in input_patterns:
        if '*' in pattern or '?' in pattern:
            input_files.extend(glob.glob(pattern))
        else:
            input_files.append(pattern)

    if not input_files:
        print("Error: No input files found")
        sys.exit(1)

    print(f"Processing {len(input_files)} file(s)...")

    # Load and combine packets from all files
    extractor = TrafficFeatureExtractor()
    all_packets = []

    for input_file in input_files:
        print(f"Loading {input_file}...")
        with open(input_file, 'r') as f:
            packets = json.load(f)
            all_packets.extend(packets)

    print(f"Total packets loaded: {len(all_packets)}")

    # Extract features from all packets
    df = extractor.extract_features_from_packets(all_packets)
    extractor.save_features(output_file)

    print(f"\nExtracted {len(df)} flows")
    print(f"Features: {extractor.get_feature_names()}")
    print(f"\nSample features:")
    print(df.head())


if __name__ == '__main__':
    main()

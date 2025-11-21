"""
Bidirectional Flow Feature Extractor
Based on research paper approach - tracks forward and reverse flow statistics
WITHOUT using port numbers as features
"""

import json
import sys
import pandas as pd
from collections import defaultdict
import numpy as np


class BidirectionalFlow:
    """
    Tracks bidirectional flow statistics (forward + reverse)
    Based on paper's approach using temporal flow statistics
    """

    def __init__(self, time_start, src_ip, dst_ip, protocol):
        self.time_start = time_start
        self.src_ip = src_ip
        self.dst_ip = dst_ip
        self.protocol = protocol

        # Forward direction (src -> dst)
        self.forward_packets = 0
        self.forward_bytes = 0
        self.forward_delta_packets = 0
        self.forward_delta_bytes = 0
        self.forward_inst_pps = 0.0
        self.forward_avg_pps = 0.0
        self.forward_inst_bps = 0.0
        self.forward_avg_bps = 0.0
        self.forward_last_time = time_start
        self.forward_packet_times = []
        self.forward_packet_sizes = []

        # Reverse direction (dst -> src)
        self.reverse_packets = 0
        self.reverse_bytes = 0
        self.reverse_delta_packets = 0
        self.reverse_delta_bytes = 0
        self.reverse_inst_pps = 0.0
        self.reverse_avg_pps = 0.0
        self.reverse_inst_bps = 0.0
        self.reverse_avg_bps = 0.0
        self.reverse_last_time = time_start
        self.reverse_packet_times = []
        self.reverse_packet_sizes = []

        # Flow metadata (for labeling, not features!)
        self.src_port = None
        self.dst_port = None

    def update_forward(self, timestamp, packet_size, src_port=None, dst_port=None):
        """Update forward direction stats"""
        # Store ports for labeling only (NOT used as ML features)
        if self.src_port is None:
            self.src_port = src_port
        if self.dst_port is None:
            self.dst_port = dst_port

        old_packets = self.forward_packets
        old_bytes = self.forward_bytes

        self.forward_packets += 1
        self.forward_bytes += packet_size
        self.forward_packet_times.append(timestamp)
        self.forward_packet_sizes.append(packet_size)

        # Calculate deltas
        self.forward_delta_packets = self.forward_packets - old_packets
        self.forward_delta_bytes = self.forward_bytes - old_bytes

        # Calculate rates
        flow_duration = timestamp - self.time_start
        if flow_duration > 0:
            self.forward_avg_pps = self.forward_packets / flow_duration
            self.forward_avg_bps = self.forward_bytes / flow_duration

        time_since_last = timestamp - self.forward_last_time
        if time_since_last > 0:
            self.forward_inst_pps = self.forward_delta_packets / time_since_last
            self.forward_inst_bps = self.forward_delta_bytes / time_since_last

        self.forward_last_time = timestamp

    def update_reverse(self, timestamp, packet_size, src_port=None, dst_port=None):
        """Update reverse direction stats"""
        # Store ports for labeling only
        if self.src_port is None:
            self.src_port = dst_port  # Reverse flow
        if self.dst_port is None:
            self.dst_port = src_port

        old_packets = self.reverse_packets
        old_bytes = self.reverse_bytes

        self.reverse_packets += 1
        self.reverse_bytes += packet_size
        self.reverse_packet_times.append(timestamp)
        self.reverse_packet_sizes.append(packet_size)

        # Calculate deltas
        self.reverse_delta_packets = self.reverse_packets - old_packets
        self.reverse_delta_bytes = self.reverse_bytes - old_bytes

        # Calculate rates
        flow_duration = timestamp - self.time_start
        if flow_duration > 0:
            self.reverse_avg_pps = self.reverse_packets / flow_duration
            self.reverse_avg_bps = self.reverse_bytes / flow_duration

        time_since_last = timestamp - self.reverse_last_time
        if time_since_last > 0:
            self.reverse_inst_pps = self.reverse_delta_packets / time_since_last
            self.reverse_inst_bps = self.reverse_delta_bytes / time_since_last

        self.reverse_last_time = timestamp

    def get_features(self):
        """
        Extract ML features (NO PORT NUMBERS!)
        Returns features matching paper's approach
        """
        # Calculate additional statistical features
        flow_duration = max(self.forward_last_time, self.reverse_last_time) - self.time_start

        # Inter-arrival times
        forward_iat_mean = 0.0
        forward_iat_std = 0.0
        if len(self.forward_packet_times) > 1:
            iats = np.diff(self.forward_packet_times)
            forward_iat_mean = np.mean(iats)
            forward_iat_std = np.std(iats)

        reverse_iat_mean = 0.0
        reverse_iat_std = 0.0
        if len(self.reverse_packet_times) > 1:
            iats = np.diff(self.reverse_packet_times)
            reverse_iat_mean = np.mean(iats)
            reverse_iat_std = np.std(iats)

        # Packet size statistics
        forward_pkt_size_mean = np.mean(self.forward_packet_sizes) if self.forward_packet_sizes else 0.0
        forward_pkt_size_std = np.std(self.forward_packet_sizes) if self.forward_packet_sizes else 0.0

        reverse_pkt_size_mean = np.mean(self.reverse_packet_sizes) if self.reverse_packet_sizes else 0.0
        reverse_pkt_size_std = np.std(self.reverse_packet_sizes) if self.reverse_packet_sizes else 0.0

        # Flow asymmetry (ratio features)
        total_packets = self.forward_packets + self.reverse_packets
        forward_packet_ratio = self.forward_packets / total_packets if total_packets > 0 else 0.5

        total_bytes = self.forward_bytes + self.reverse_bytes
        forward_byte_ratio = self.forward_bytes / total_bytes if total_bytes > 0 else 0.5

        features = {
            # Core bidirectional features (from paper)
            'forward_packets': self.forward_packets,
            'forward_bytes': self.forward_bytes,
            'forward_inst_pps': self.forward_inst_pps,
            'forward_avg_pps': self.forward_avg_pps,
            'forward_inst_bps': self.forward_inst_bps,
            'forward_avg_bps': self.forward_avg_bps,

            'reverse_packets': self.reverse_packets,
            'reverse_bytes': self.reverse_bytes,
            'reverse_inst_pps': self.reverse_inst_pps,
            'reverse_avg_pps': self.reverse_avg_pps,
            'reverse_inst_bps': self.reverse_inst_bps,
            'reverse_avg_bps': self.reverse_avg_bps,

            # Additional statistical features
            'flow_duration': flow_duration,
            'forward_iat_mean': forward_iat_mean,
            'forward_iat_std': forward_iat_std,
            'reverse_iat_mean': reverse_iat_mean,
            'reverse_iat_std': reverse_iat_std,
            'forward_pkt_size_mean': forward_pkt_size_mean,
            'forward_pkt_size_std': forward_pkt_size_std,
            'reverse_pkt_size_mean': reverse_pkt_size_mean,
            'reverse_pkt_size_std': reverse_pkt_size_std,

            # Flow asymmetry ratios
            'forward_packet_ratio': forward_packet_ratio,
            'forward_byte_ratio': forward_byte_ratio,

            # Protocol encoding
            'protocol': self.protocol
        }

        return features

    def get_metadata(self):
        """Get metadata for labeling (ports, IPs)"""
        return {
            'src_ip': self.src_ip,
            'dst_ip': self.dst_ip,
            'src_port': self.src_port if self.src_port else 0,
            'dst_port': self.dst_port if self.dst_port else 0,
            'protocol': self.protocol
        }


def ip_to_host(ip):
    """Convert IP to host name"""
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


def classify_by_port(src_port, dst_port):
    """Port-based classification for LABELING ONLY (not features!)"""
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


def main():
    if len(sys.argv) < 3:
        print("Usage: python bidirectional_feature_extractor.py <packet_files...> <output.csv>")
        sys.exit(1)

    packet_files = sys.argv[1:-1]
    output_file = sys.argv[-1]

    print(f"Processing {len(packet_files)} file(s)...")

    # Track bidirectional flows
    flows = {}  # key: (src_ip, dst_ip, protocol)

    # Load all packets
    for packet_file in packet_files:
        print(f"Loading {packet_file}...")
        try:
            with open(packet_file, 'r') as f:
                packets = json.load(f)

            for pkt in packets:
                timestamp = pkt.get('timestamp', 0)
                # Try different IP field names
                src_ip = pkt.get('ip_src') or pkt.get('ipv4_src') or pkt.get('ipv6_src', 'unknown')
                dst_ip = pkt.get('ip_dst') or pkt.get('ipv4_dst') or pkt.get('ipv6_dst', 'unknown')
                protocol = pkt.get('protocol', 'OTHER')
                packet_size = pkt.get('packet_size') or pkt.get('packet_length', 0)
                src_port = pkt.get('tcp_src') or pkt.get('udp_src') or pkt.get('src_port', 0)
                dst_port = pkt.get('tcp_dst') or pkt.get('udp_dst') or pkt.get('dst_port', 0)

                # Convert IPs to hosts
                src_host = ip_to_host(src_ip)
                dst_host = ip_to_host(dst_ip)

                # Only process host-to-host traffic
                if not (src_host.startswith('h') and dst_host.startswith('h')):
                    continue

                # Create bidirectional flow key (normalize direction)
                if (src_ip, dst_ip, protocol) < (dst_ip, src_ip, protocol):
                    flow_key = (src_ip, dst_ip, protocol)
                    is_forward = True
                else:
                    flow_key = (dst_ip, src_ip, protocol)
                    is_forward = False

                # Create flow if doesn't exist
                if flow_key not in flows:
                    flows[flow_key] = BidirectionalFlow(timestamp, flow_key[0], flow_key[1], flow_key[2])

                # Update flow stats
                if is_forward:
                    flows[flow_key].update_forward(timestamp, packet_size, src_port, dst_port)
                else:
                    flows[flow_key].update_reverse(timestamp, packet_size, src_port, dst_port)

        except Exception as e:
            print(f"Error loading {packet_file}: {e}")
            continue

    print(f"\nExtracted {len(flows)} bidirectional flows")

    # Extract features
    results = []
    for flow_key, flow in flows.items():
        features = flow.get_features()
        metadata = flow.get_metadata()

        # Get labels (for training only, NOT features!)
        traffic_type = classify_by_port(metadata['src_port'], metadata['dst_port'])

        # Combine everything
        result = {
            'flow_key': str(flow_key),
            'src_ip': metadata['src_ip'],
            'dst_ip': metadata['dst_ip'],
            'src_host': ip_to_host(metadata['src_ip']),
            'dst_host': ip_to_host(metadata['dst_ip']),
            'label': traffic_type,  # Ground truth label (for training)
            **features
        }

        results.append(result)

    # Create DataFrame
    df = pd.DataFrame(results)

    if len(df) == 0:
        print("\n❌ No host-to-host flows found!")
        print("   Check that packets contain host traffic (h1-h9)")
        sys.exit(1)

    # Encode protocol
    protocol_mapping = {'TCP': 0, 'UDP': 1, 'ICMP': 2, 'OTHER': 3}
    if 'protocol' in df.columns:
        df['protocol'] = df['protocol'].map(protocol_mapping).fillna(3)
    else:
        df['protocol'] = 3

    # Save
    df.to_csv(output_file, index=False)
    print(f"\nFeatures saved to {output_file}")
    print(f"Total flows: {len(df)}")
    print(f"\nLabel distribution:")
    print(df['label'].value_counts())

    print(f"\nFeature columns (NO PORTS!):")
    feature_cols = [c for c in df.columns if c not in ['flow_key', 'src_ip', 'dst_ip', 'src_host', 'dst_host', 'label']]
    print(feature_cols)

    print(f"\nSample features:")
    print(df[['src_host', 'dst_host', 'label', 'forward_avg_bps', 'reverse_avg_bps', 'forward_packet_ratio']].head(10))


if __name__ == '__main__':
    main()

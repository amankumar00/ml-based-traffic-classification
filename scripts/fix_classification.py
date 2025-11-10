#!/usr/bin/env python3
"""
Post-process ML classification to fix misclassifications based on port numbers
This is a workaround until the ML model is retrained properly
"""

import pandas as pd
import sys

def fix_classification(csv_path):
    """
    Fix misclassified flows based on well-known ports
    """
    df = pd.read_csv(csv_path)

    print(f"Original classification:")
    print(df['traffic_type'].value_counts())
    print()

    # Fix based on destination port
    for idx, row in df.iterrows():
        dst_port = row['dst_port']

        # Port-based classification (overrides ML prediction)
        if dst_port == 80 or dst_port == 8080:
            df.at[idx, 'traffic_type'] = 'HTTP'
        elif dst_port == 21:
            df.at[idx, 'traffic_type'] = 'FTP'
        elif dst_port == 22:
            df.at[idx, 'traffic_type'] = 'SSH'
        elif dst_port in [5004, 5006, 1935]:
            df.at[idx, 'traffic_type'] = 'VIDEO'

    print(f"Fixed classification:")
    print(df['traffic_type'].value_counts())
    print()

    # Save corrected CSV
    df.to_csv(csv_path, index=False)
    print(f"✓ Saved corrected classification to {csv_path}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python fix_classification.py <csv_file>")
        sys.exit(1)

    csv_path = sys.argv[1]
    fix_classification(csv_path)

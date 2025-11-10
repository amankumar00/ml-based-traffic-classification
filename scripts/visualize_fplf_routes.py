#!/usr/bin/env python3
"""
Visualize FPLF Routing Results
Parses controller log and shows routing decisions
"""

import re
import sys
from collections import defaultdict

def parse_log(log_file):
    """Parse FPLF controller log for route assignments"""
    routes = []

    with open(log_file, 'r') as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        if '═══ FPLF ROUTE ═══' in lines[i]:
            # Extract flow info from next 3 lines
            flow_line = lines[i+1].strip() if i+1 < len(lines) else ""
            type_line = lines[i+2].strip() if i+2 < len(lines) else ""
            path_line = lines[i+3].strip() if i+3 < len(lines) else ""

            # Parse flow
            flow_match = re.search(r'Flow: (.+?) → (.+?):(\d+) \((.+?)\)', flow_line)
            type_match = re.search(r'Type: (.+?) \(Priority (\d+)\)', type_line)
            path_match = re.search(r'Path: (.+)', path_line)

            if flow_match and type_match and path_match:
                routes.append({
                    'src': flow_match.group(1),
                    'dst': flow_match.group(2),
                    'port': int(flow_match.group(3)),
                    'protocol': flow_match.group(4),
                    'type': type_match.group(1),
                    'priority': int(type_match.group(2)),
                    'path': path_match.group(1)
                })
            i += 4
        else:
            i += 1

    return routes

def visualize_routes(routes):
    """Display routes in a formatted table"""
    if not routes:
        print("No routes found in log file!")
        return

    print("\n" + "="*80)
    print("FPLF ROUTING TOPOLOGY")
    print("="*80)

    # Group by traffic type
    by_type = defaultdict(list)
    for route in routes:
        by_type[route['type']].append(route)

    # Priority order
    priority_order = ['VIDEO', 'SSH', 'HTTP', 'FTP']

    for traffic_type in priority_order:
        if traffic_type not in by_type:
            continue

        type_routes = by_type[traffic_type]
        priority = type_routes[0]['priority']

        print(f"\n{traffic_type} (Priority {priority}):")
        print("-" * 80)

        for route in type_routes:
            print(f"  {route['src']:8s} → {route['dst']:8s}:{route['port']:<6d} "
                  f"| {route['protocol']:4s} | Path: {route['path']}")

    print("\n" + "="*80)

    # Statistics
    print("\nRoute Statistics:")
    print("-" * 40)
    for traffic_type in priority_order:
        if traffic_type in by_type:
            count = len(by_type[traffic_type])
            print(f"  {traffic_type:10s}: {count} flows")

    print("\nPath Distribution:")
    print("-" * 40)
    path_counts = defaultdict(int)
    for route in routes:
        path_counts[route['path']] += 1

    for path, count in sorted(path_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  {path:20s}: {count} flows")

if __name__ == '__main__':
    log_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/fplf_controller.log'

    print(f"Parsing log file: {log_file}")
    routes = parse_log(log_file)
    visualize_routes(routes)

#!/usr/bin/env python3
"""
Inject Heavy Traffic into Running Mininet Session

This script connects to a running mininet instance and generates
heavy iperf traffic to create congestion for FPLF testing.

Usage:
    python3 scripts/inject_heavy_traffic.py

Requirements:
    - Mininet must already be running
    - Controller must be running
"""

import os
import sys
import time
from mininet.cli import CLI
from mininet.net import Mininet
from mininet.log import setLogLevel, info

def inject_heavy_traffic():
    """
    Inject heavy iperf traffic into running Mininet network
    """

    info('='*80 + '\n')
    info('INJECTING HEAVY IPERF TRAFFIC\n')
    info('='*80 + '\n\n')

    # Check if mininet is running
    if not os.path.exists('/var/run/mn'):
        info('ERROR: Mininet does not appear to be running!\n')
        info('Please start topology first:\n')
        info('  sudo python3 topology/fplf_topo.py\n')
        sys.exit(1)

    # Try to get existing mininet instance
    try:
        # This is a workaround - we'll use system commands instead
        info('*** Generating traffic using system commands...\n\n')

        # Generate traffic script
        traffic_commands = """
# Kill any existing iperf processes
sudo killall iperf 2>/dev/null

# Start iperf servers
sudo mn -c 2>/dev/null
sudo mnexec -a $(pgrep -f 'mininet:h1') iperf -s -p 5001 -u > /dev/null 2>&1 &
sudo mnexec -a $(pgrep -f 'mininet:h2') iperf -s -p 5002 -u > /dev/null 2>&1 &
sudo mnexec -a $(pgrep -f 'mininet:h4') iperf -s -p 5003 -u > /dev/null 2>&1 &
sudo mnexec -a $(pgrep -f 'mininet:h7') iperf -s -p 5004 -u > /dev/null 2>&1 &
sudo mnexec -a $(pgrep -f 'mininet:h8') iperf -s -p 22 -u > /dev/null 2>&1 &
sudo mnexec -a $(pgrep -f 'mininet:h9') iperf -s -p 80 -u > /dev/null 2>&1 &

sleep 3

# Generate VIDEO traffic (8 Mbps, crosses switches)
sudo mnexec -a $(pgrep -f 'mininet:h3') iperf -c 10.0.0.7 -p 5004 -u -b 8M -t 120 > /dev/null 2>&1 &
sudo mnexec -a $(pgrep -f 'mininet:h6') iperf -c 10.0.0.1 -p 5001 -u -b 8M -t 120 > /dev/null 2>&1 &

# Generate SSH traffic (3 Mbps)
sudo mnexec -a $(pgrep -f 'mininet:h5') iperf -c 10.0.0.8 -p 22 -u -b 3M -t 120 > /dev/null 2>&1 &

# Generate HTTP traffic (5 Mbps)
sudo mnexec -a $(pgrep -f 'mininet:h4') iperf -c 10.0.0.9 -p 80 -u -b 5M -t 120 > /dev/null 2>&1 &

# Generate FTP traffic (9 Mbps, heavy bulk transfer)
sudo mnexec -a $(pgrep -f 'mininet:h2') iperf -c 10.0.0.4 -p 5003 -u -b 9M -t 120 > /dev/null 2>&1 &
sudo mnexec -a $(pgrep -f 'mininet:h9') iperf -c 10.0.0.2 -p 5002 -u -b 9M -t 120 > /dev/null 2>&1 &
"""

        # Save commands to temp file
        with open('/tmp/inject_traffic.sh', 'w') as f:
            f.write('#!/bin/bash\n')
            f.write(traffic_commands)

        os.chmod('/tmp/inject_traffic.sh', 0o755)

        info('ERROR: Cannot directly inject into running Mininet from Python.\n\n')
        info('Please use one of these methods:\n\n')

        info('METHOD 1 (Easiest): At your mininet> prompt, paste:\n')
        info('-'*80 + '\n')
        print('h1 iperf -s -p 5001 -u &')
        print('h2 iperf -s -p 5002 -u &')
        print('h4 iperf -s -p 5003 -u &')
        print('h7 iperf -s -p 5004 -u &')
        print('h8 iperf -s -p 22 -u &')
        print('h9 iperf -s -p 80 -u &')
        print('h3 iperf -c 10.0.0.7 -p 5004 -u -b 8M -t 120 &')
        print('h6 iperf -c 10.0.0.1 -p 5001 -u -b 8M -t 120 &')
        print('h5 iperf -c 10.0.0.8 -p 22 -u -b 3M -t 120 &')
        print('h4 iperf -c 10.0.0.9 -p 80 -u -b 5M -t 120 &')
        print('h2 iperf -c 10.0.0.4 -p 5003 -u -b 9M -t 120 &')
        print('h9 iperf -c 10.0.0.2 -p 5002 -u -b 9M -t 120 &')
        info('-'*80 + '\n\n')

        info('METHOD 2: Run the automated script:\n')
        info('  bash scripts/inject_traffic_to_mininet.sh\n\n')

    except Exception as e:
        info(f'Error: {e}\n')
        sys.exit(1)

if __name__ == '__main__':
    setLogLevel('info')
    inject_heavy_traffic()

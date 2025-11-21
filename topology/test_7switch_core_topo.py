#!/usr/bin/env python3
"""
Test 7-Switch Core Network Topology
Purpose: Validate ML classifier + FPLF scalability with complex topology

Topology:
    Edge Layer: s1, s2, s3, s4 (hosts attached)
    Core Layer: s5, s6, s7 (pure forwarding)

    h1,h2 ─ s1 ─────┐
                    │
    h3,h4 ─ s2 ───┐ ├─── s5 ───┐
                  │ │           │
    h5,h6 ─ s3 ───┼─┼───────────┼─── s6
                  │ │           │     │
    h7,h8,h9─ s4 ─┴─┘           └─────┴─── s7

Links: 10 inter-switch (20 directional)
Hosts: 9 total, distributed across edge switches
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
import time
import argparse


def create_7switch_topology(controller_ip='127.0.0.1', controller_port=6653):
    """Create 7-switch core network topology"""

    net = Mininet(
        controller=RemoteController,
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True,
        autoStaticArp=True
    )

    info('*** Adding controller\n')
    c0 = net.addController(
        'c0',
        controller=RemoteController,
        ip=controller_ip,
        port=controller_port
    )

    info('*** Adding switches\n')
    # Edge switches (hosts attached)
    s1 = net.addSwitch('s1', dpid='0000000000000001', protocols='OpenFlow13')
    s2 = net.addSwitch('s2', dpid='0000000000000002', protocols='OpenFlow13')
    s3 = net.addSwitch('s3', dpid='0000000000000003', protocols='OpenFlow13')
    s4 = net.addSwitch('s4', dpid='0000000000000004', protocols='OpenFlow13')

    # Core switches (pure forwarding)
    s5 = net.addSwitch('s5', dpid='0000000000000005', protocols='OpenFlow13')
    s6 = net.addSwitch('s6', dpid='0000000000000006', protocols='OpenFlow13')
    s7 = net.addSwitch('s7', dpid='0000000000000007', protocols='OpenFlow13')

    info('*** Adding hosts\n')
    # Distribute 9 hosts across 4 edge switches (IPv6 disabled to reduce noise)
    # s1: h1, h2
    h1 = net.addHost('h1', ip='10.0.0.1/24', mac='00:00:00:00:00:01', defaultRoute='via 10.0.0.254')
    h2 = net.addHost('h2', ip='10.0.0.2/24', mac='00:00:00:00:00:02', defaultRoute='via 10.0.0.254')

    # s2: h3, h4
    h3 = net.addHost('h3', ip='10.0.0.3/24', mac='00:00:00:00:00:03', defaultRoute='via 10.0.0.254')
    h4 = net.addHost('h4', ip='10.0.0.4/24', mac='00:00:00:00:00:04', defaultRoute='via 10.0.0.254')

    # s3: h5, h6
    h5 = net.addHost('h5', ip='10.0.0.5/24', mac='00:00:00:00:00:05', defaultRoute='via 10.0.0.254')
    h6 = net.addHost('h6', ip='10.0.0.6/24', mac='00:00:00:00:00:06', defaultRoute='via 10.0.0.254')

    # s4: h7, h8, h9
    h7 = net.addHost('h7', ip='10.0.0.7/24', mac='00:00:00:00:00:07', defaultRoute='via 10.0.0.254')
    h8 = net.addHost('h8', ip='10.0.0.8/24', mac='00:00:00:00:00:08', defaultRoute='via 10.0.0.254')
    h9 = net.addHost('h9', ip='10.0.0.9/24', mac='00:00:00:00:00:09', defaultRoute='via 10.0.0.254')

    info('*** Creating links\n')
    info('  Host-to-edge links...\n')
    # Host-to-switch links (10 Mbps for easy traffic generation)
    net.addLink(h1, s1, port1=0, port2=1, bw=10)
    net.addLink(h2, s1, port1=0, port2=2, bw=10)
    net.addLink(h3, s2, port1=0, port2=1, bw=10)
    net.addLink(h4, s2, port1=0, port2=2, bw=10)
    net.addLink(h5, s3, port1=0, port2=1, bw=10)
    net.addLink(h6, s3, port1=0, port2=2, bw=10)
    net.addLink(h7, s4, port1=0, port2=1, bw=10)
    net.addLink(h8, s4, port1=0, port2=2, bw=10)
    net.addLink(h9, s4, port1=0, port2=3, bw=10)

    info('  Edge-to-core links...\n')
    # Edge-to-core links (100 Mbps)
    # Each edge switch connects to 2 core switches for redundancy
    net.addLink(s1, s5, port1=4, port2=1, bw=100)  # s1:4 <-> s5:1
    net.addLink(s1, s6, port1=5, port2=1, bw=100)  # s1:5 <-> s6:1

    net.addLink(s2, s5, port1=4, port2=2, bw=100)  # s2:4 <-> s5:2
    net.addLink(s2, s7, port1=5, port2=1, bw=100)  # s2:5 <-> s7:1

    net.addLink(s3, s6, port1=4, port2=2, bw=100)  # s3:4 <-> s6:2
    net.addLink(s3, s7, port1=5, port2=2, bw=100)  # s3:5 <-> s7:2

    net.addLink(s4, s7, port1=4, port2=3, bw=100)  # s4:4 <-> s7:3

    info('  Core-to-core links (backbone)...\n')
    # Core mesh (1 Gbps backbone)
    net.addLink(s5, s6, port1=4, port2=4, bw=1000)  # s5:4 <-> s6:4
    net.addLink(s6, s7, port1=5, port2=5, bw=1000)  # s6:5 <-> s7:5
    net.addLink(s5, s7, port1=5, port2=4, bw=1000)  # s5:5 <-> s7:4

    info('*** Starting network\n')
    net.build()

    info('*** Disabling IPv6 on all hosts BEFORE starting (prevent neighbor discovery)...\n')
    for host in net.hosts:
        host.cmd('sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1')
        host.cmd('sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null 2>&1')

    net.start()

    info('*** Waiting for switches to connect to controller...\n')
    time.sleep(8)

    info('\n')
    info('='*80 + '\n')
    info('*** 7-Switch Core Network Topology Ready\n')
    info('='*80 + '\n')
    info('Switches:\n')
    info('  Edge: s1, s2, s3, s4 (hosts attached)\n')
    info('  Core: s5, s6, s7 (pure forwarding)\n')
    info('\n')
    info('Hosts (9 total):\n')
    info('  s1: h1 (10.0.0.1), h2 (10.0.0.2)\n')
    info('  s2: h3 (10.0.0.3), h4 (10.0.0.4)\n')
    info('  s3: h5 (10.0.0.5), h6 (10.0.0.6)\n')
    info('  s4: h7 (10.0.0.7), h8 (10.0.0.8), h9 (10.0.0.9)\n')
    info('\n')
    info('Inter-switch links: 10 undirected (20 directional)\n')
    info('  Edge-to-core: 7 links\n')
    info('  Core-to-core: 3 links (full mesh)\n')
    info('\n')
    info('Path diversity examples:\n')
    info('  h1 (s1) → h7 (s4): 6 possible paths!\n')
    info('    1. s1 → s5 → s7 → s4\n')
    info('    2. s1 → s6 → s7 → s4\n')
    info('    3. s1 → s5 → s6 → s7 → s4\n')
    info('    ... (and more)\n')
    info('='*80 + '\n')
    info('\n')

    return net


def generate_test_traffic(net, duration=60):
    """
    Generate test traffic to validate ML classifier + FPLF

    Traffic patterns:
    - VIDEO: h1 -> h7 (cross-rack, high priority) - CONTINUOUS iperf UDP stream
    - SSH: h3 -> h5 (cross-rack, medium-high priority) - BURSTY interactive
    - HTTP: h2 -> h8 (cross-rack, medium priority) - REQUEST-RESPONSE pattern
    - FTP: h4 -> h9 (cross-rack, low priority) - BULK TCP transfer
    """
    hosts = net.hosts

    info('*** Generating test traffic for 7-switch topology\n')
    info('*** This validates ML classifier + FPLF with complex paths\n')
    info('='*80 + '\n')

    # Get hosts by name
    h1 = net.get('h1')
    h2 = net.get('h2')
    h3 = net.get('h3')
    h4 = net.get('h4')
    h5 = net.get('h5')
    h7 = net.get('h7')
    h8 = net.get('h8')
    h9 = net.get('h9')

    # Start servers first
    info('*** Starting servers\n')

    # Start TCP iperf servers on destination ports matching ML classification
    info('  VIDEO server: h7:5004 (TCP iperf)\n')
    h7.cmd('iperf -s -p 5004 > /dev/null 2>&1 &')

    info('  SSH server: h5:22 (TCP iperf)\n')
    h5.cmd('iperf -s -p 22 > /dev/null 2>&1 &')

    info('  HTTP server: h8:80 (TCP iperf)\n')
    h8.cmd('iperf -s -p 80 > /dev/null 2>&1 &')

    info('  FTP server: h9:21 (TCP iperf)\n')
    h9.cmd('iperf -s -p 21 > /dev/null 2>&1 &')

    time.sleep(3)

    # Start TCP iperf traffic generators
    info('\\n*** Starting TCP iperf traffic generators\\n')

    # VIDEO traffic: h1 -> h7:5004 (TCP iperf, continuous stream)
    info('1. Starting VIDEO traffic: h1 -> h7:5004 (TCP iperf, 2 streams)\\n')
    h1.cmd(f'iperf -c {h7.IP()} -p 5004 -P 2 -t {duration} > /dev/null 2>&1 &')

    # SSH traffic: h3 -> h5:22 (TCP iperf, continuous stream)
    info('2. Starting SSH traffic: h3 -> h5:22 (TCP iperf, 1 stream)\\n')
    h3.cmd(f'iperf -c {h5.IP()} -p 22 -t {duration} > /dev/null 2>&1 &')

    # HTTP traffic: h2 -> h8:80 (TCP iperf, continuous stream)
    info('3. Starting HTTP traffic: h2 -> h8:80 (TCP iperf, 1 stream)\\n')
    h2.cmd(f'iperf -c {h8.IP()} -p 80 -t {duration} > /dev/null 2>&1 &')

    # FTP traffic: h4 -> h9:21 (TCP iperf, continuous stream)
    info('4. Starting FTP traffic: h4 -> h9:21 (TCP iperf, 1 stream)\\n')
    h4.cmd(f'iperf -c {h9.IP()} -p 21 -t {duration} > /dev/null 2>&1 &')

    info('='*80 + '\n')
    info('*** Traffic flows created (TCP iperf - PORT-BASED ML):\n')
    info('  VIDEO (priority 4): h1 (s1) -> h7 (s4):5004 - TCP iperf (2 streams, continuous)\n')
    info('  SSH   (priority 3): h3 (s2) -> h5 (s3):22 - TCP iperf (1 stream, continuous)\n')
    info('  HTTP  (priority 2): h2 (s1) -> h8 (s4):80 - TCP iperf (1 stream, continuous)\n')
    info('  FTP   (priority 1): h4 (s2) -> h9 (s4):21 - TCP iperf (1 stream, continuous)\n')
    info('='*80 + '\n')
    info(f'\n*** Running for {duration} seconds...\n')
    info('*** Expected results:\n')
    info(f'  TOTAL FLOWS: Exactly 8 (4 traffic types × 2 directions)\n')
    info(f'  VIDEO: Continuous TCP stream (2 parallel connections)\n')
    info(f'  SSH: Continuous TCP stream\n')
    info(f'  HTTP: Continuous TCP stream\n')
    info(f'  FTP: Continuous TCP stream\n')
    info('*** PORT-BASED ML: Classifier uses src_port and dst_port features\n')
    info('*** FPLF should choose DIFFERENT paths for each traffic type!\n')
    info('*** VIDEO: Longest path (avoids congestion)\n')
    info('*** FTP: Shortest path (tolerates congestion)\n')
    info('='*80 + '\n')

    time.sleep(duration)

    info('*** Traffic generation complete\n')


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='7-Switch Core Network Topology Test')
    parser.add_argument('--controller-ip', '-c',
                       default='127.0.0.1',
                       help='Ryu controller IP address')
    parser.add_argument('--controller-port', '-p',
                       type=int,
                       default=6653,
                       help='Ryu controller port')
    parser.add_argument('--traffic', '-t',
                       action='store_true',
                       help='Generate test traffic automatically')
    parser.add_argument('--duration', '-d',
                       type=int,
                       default=60,
                       help='Traffic duration (seconds)')

    args = parser.parse_args()

    setLogLevel('info')

    # Create topology
    net = create_7switch_topology(
        controller_ip=args.controller_ip,
        controller_port=args.controller_port
    )

    try:
        if args.traffic:
            # Generate traffic
            generate_test_traffic(net, duration=args.duration)
        else:
            # Interactive mode
            info('*** Running CLI (type "help" for commands)\n')
            info('*** Useful commands:\n')
            info('  - pingall: Test connectivity\n')
            info('  - h1 ping h7: Test cross-rack connectivity\n')
            info('  - links: Show link status\n')
            info('  - dump: Show network info\n')
            CLI(net)

    finally:
        info('*** Stopping network\n')
        net.stop()


if __name__ == '__main__':
    main()

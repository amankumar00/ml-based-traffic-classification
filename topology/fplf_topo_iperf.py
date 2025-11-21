#!/usr/bin/env python3
"""
FPLF Topology with HIGH-BANDWIDTH iperf Traffic

This version generates REAL congestion using iperf instead of netcat.
Use this to actually test flow-type routing!

Usage:
    sudo python3 topology/fplf_topo_iperf.py
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
import time

def create_heavy_traffic_topology():
    """Create 3-switch mesh with heavy iperf traffic"""

    net = Mininet(
        controller=RemoteController,
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True,
        autoStaticArp=True
    )

    info('*** Adding controller\n')
    c0 = net.addController('c0', controller=RemoteController,
                          ip='127.0.0.1', port=6653)

    info('*** Adding switches\n')
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    s2 = net.addSwitch('s2', protocols='OpenFlow13')
    s3 = net.addSwitch('s3', protocols='OpenFlow13')

    info('*** Adding hosts\n')
    h1 = net.addHost('h1', ip='10.0.0.1/24')
    h2 = net.addHost('h2', ip='10.0.0.2/24')
    h3 = net.addHost('h3', ip='10.0.0.3/24')
    h4 = net.addHost('h4', ip='10.0.0.4/24')
    h5 = net.addHost('h5', ip='10.0.0.5/24')
    h6 = net.addHost('h6', ip='10.0.0.6/24')
    h7 = net.addHost('h7', ip='10.0.0.7/24')
    h8 = net.addHost('h8', ip='10.0.0.8/24')
    h9 = net.addHost('h9', ip='10.0.0.9/24')

    info('*** Adding links\n')
    # Host-switch links (10 Mbps bottleneck)
    net.addLink(h1, s1, bw=10, delay='5ms', loss=0)
    net.addLink(h2, s1, bw=10, delay='5ms', loss=0)
    net.addLink(h3, s1, bw=10, delay='5ms', loss=0)
    net.addLink(h4, s2, bw=10, delay='5ms', loss=0)
    net.addLink(h5, s2, bw=10, delay='5ms', loss=0)
    net.addLink(h6, s2, bw=10, delay='5ms', loss=0)
    net.addLink(h7, s3, bw=10, delay='5ms', loss=0)
    net.addLink(h8, s3, bw=10, delay='5ms', loss=0)
    net.addLink(h9, s3, bw=10, delay='5ms', loss=0)

    # Inter-switch links (100 Mbps)
    net.addLink(s1, s2, bw=100, delay='2ms')
    net.addLink(s2, s3, bw=100, delay='2ms')
    net.addLink(s1, s3, bw=100, delay='2ms')  # Mesh direct link

    info('*** Starting network\n')
    net.start()

    info('*** Waiting for switches to connect...\n')
    time.sleep(10)

    info('\n')
    info('='*80 + '\n')
    info('*** GENERATING HEAVY TRAFFIC WITH IPERF\n')
    info('='*80 + '\n\n')

    # Start iperf servers on destinations matching ML classification
    info('*** Starting iperf servers...\n')
    h1.cmd('iperf -s -p 5004 -u > /dev/null 2>&1 &')  # h3->h1 VIDEO
    h1.cmd('iperf -s -p 80 -u > /dev/null 2>&1 &')    # h3->h1 HTTP
    h1.cmd('iperf -s -p 22 -u > /dev/null 2>&1 &')    # h5->h1 SSH
    h4.cmd('iperf -s -p 21 -u > /dev/null 2>&1 &')    # h6->h4 FTP
    h3.cmd('iperf -s -p 21 -u > /dev/null 2>&1 &')    # h5->h3 FTP
    h2.cmd('iperf -s -p 8080 -u > /dev/null 2>&1 &')  # h4->h2 HTTP
    h2.cmd('iperf -s -p 5006 -u > /dev/null 2>&1 &')  # h4->h2 VIDEO
    h2.cmd('iperf -s -p 22 -u > /dev/null 2>&1 &')    # h6->h2 SSH
    time.sleep(3)

    info('\n*** Phase 1: VIDEO Traffic (0-50s) - HIGH PRIORITY\n')
    info('    h3 -> h1:5004 (30 Mbps VIDEO, flow_id=62) - CROSSES s1\n')
    info('    h4 -> h2:5006 (30 Mbps VIDEO, flow_id=68) - CROSSES s2->s1\n')
    h3.cmd('iperf -c 10.0.0.1 -p 5004 -u -b 30M -t 50 > /dev/null 2>&1 &')
    h4.cmd('iperf -c 10.0.0.2 -p 5006 -u -b 30M -t 50 > /dev/null 2>&1 &')

    info('\n*** Waiting 10 seconds for VIDEO traffic to establish...\n')
    time.sleep(10)

    info('\n*** Phase 2: Add SSH + HTTP (10-50s) - MEDIUM PRIORITY\n')
    info('    h5 -> h1:22 (15 Mbps SSH, flow_id=64) - CROSSES s2->s1\n')
    info('    h3 -> h1:80 (10 Mbps HTTP, flow_id=61)\n')
    info('    h4 -> h2:8080 (10 Mbps HTTP, flow_id=67)\n')
    h5.cmd('iperf -c 10.0.0.1 -p 22 -u -b 15M -t 40 > /dev/null 2>&1 &')
    h3.cmd('iperf -c 10.0.0.1 -p 80 -u -b 10M -t 40 > /dev/null 2>&1 &')
    h4.cmd('iperf -c 10.0.0.2 -p 8080 -u -b 10M -t 40 > /dev/null 2>&1 &')

    info('\n*** Waiting 10 seconds...\n')
    time.sleep(10)

    info('\n*** Phase 3: Add MASSIVE FTP (20-50s) - LOW PRIORITY, Creates EXTREME CONGESTION!\n')
    info('    h6 -> h4:21 (35 Mbps FTP, flow_id=63) - STAYS on s2\n')
    info('    h5 -> h3:21 (35 Mbps FTP, flow_id=66) - CROSSES s2->s1 (MASSIVE CONGESTION!)\n')
    info('    h6 -> h2:22 (25 Mbps SSH, flow_id=65) - CROSSES s2->s1 (MASSIVE CONGESTION!)\n')
    info('\n')
    info('    Total on s2->s1 link: 30M VIDEO + 15M SSH + 35M FTP + 25M SSH = 105 Mbps!\n')
    info('    This will OVERSATURATE the 100M link at 105%% and FORCE VIDEO to reroute!\n')
    h6.cmd('iperf -c 10.0.0.4 -p 21 -u -b 35M -t 30 > /dev/null 2>&1 &')
    h5.cmd('iperf -c 10.0.0.3 -p 21 -u -b 35M -t 30 > /dev/null 2>&1 &')
    h6.cmd('iperf -c 10.0.0.2 -p 22 -u -b 25M -t 30 > /dev/null 2>&1 &')

    info('\n')
    info('='*80 + '\n')
    info('*** HEAVY TRAFFIC RUNNING - Monitor results:\n')
    info('='*80 + '\n')
    info('  Terminal 2: tail -f data/fplf_monitoring/link_utilization.csv\n')
    info('  Terminal 3: tail -f data/fplf_monitoring/fplf_routes.csv\n')
    info('\n')
    info('  Expected:\n')
    info('    - Link utilization > 8% on congested links\n')
    info('    - route_changed=YES for VIDEO traffic (avoids congestion)\n')
    info('    - route_changed=NO for FTP traffic (tolerates congestion)\n')
    info('='*80 + '\n')
    info('\n*** Traffic will run for 60 seconds, then enter CLI\n\n')

    time.sleep(60)

    info('\n*** Traffic generation complete. Entering CLI for manual testing.\n')
    CLI(net)

    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    create_heavy_traffic_topology()

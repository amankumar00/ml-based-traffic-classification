#!/usr/bin/env python3
"""
FPLF Topology with TCP iperf Traffic - REAL CONGESTION!

This version uses TCP iperf to create ACTUAL link saturation.
TCP will achieve 90%+ bandwidth utilization, finally triggering VIDEO rerouting!

Usage:
    sudo python3 topology/fplf_topo_tcp.py
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
import time

def create_tcp_traffic_topology():
    """Create 3-switch mesh with TCP iperf traffic that ACTUALLY saturates links"""

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
    # Host-switch links (100 Mbps - increased to not bottleneck)
    net.addLink(h1, s1, bw=100, delay='5ms', loss=0)
    net.addLink(h2, s1, bw=100, delay='5ms', loss=0)
    net.addLink(h3, s1, bw=100, delay='5ms', loss=0)
    net.addLink(h4, s2, bw=100, delay='5ms', loss=0)
    net.addLink(h5, s2, bw=100, delay='5ms', loss=0)
    net.addLink(h6, s2, bw=100, delay='5ms', loss=0)
    net.addLink(h7, s3, bw=100, delay='5ms', loss=0)
    net.addLink(h8, s3, bw=100, delay='5ms', loss=0)
    net.addLink(h9, s3, bw=100, delay='5ms', loss=0)

    # Inter-switch links (100 Mbps - THE BOTTLENECK)
    net.addLink(s1, s2, bw=100, delay='2ms')
    net.addLink(s2, s3, bw=100, delay='2ms')
    net.addLink(s1, s3, bw=100, delay='2ms')  # Mesh direct link

    info('*** Starting network\n')
    net.start()

    info('*** Waiting for switches to connect...\n')
    time.sleep(10)

    info('\n')
    info('='*80 + '\n')
    info('*** GENERATING REAL CONGESTION WITH TCP IPERF\n')
    info('='*80 + '\n\n')

    # Start TCP iperf servers on destinations matching ML classification
    info('*** Starting TCP iperf servers...\n')
    h1.cmd('iperf -s -p 5004 > /dev/null 2>&1 &')  # h3->h1 VIDEO
    h1.cmd('iperf -s -p 80 > /dev/null 2>&1 &')    # h3->h1 HTTP
    h1.cmd('iperf -s -p 22 > /dev/null 2>&1 &')    # h5->h1 SSH
    h4.cmd('iperf -s -p 21 > /dev/null 2>&1 &')    # h6->h4 FTP
    h3.cmd('iperf -s -p 21 > /dev/null 2>&1 &')    # h5->h3 FTP
    h2.cmd('iperf -s -p 8080 > /dev/null 2>&1 &')  # h4->h2 HTTP
    h2.cmd('iperf -s -p 5006 > /dev/null 2>&1 &')  # h4->h2 VIDEO
    h2.cmd('iperf -s -p 22 > /dev/null 2>&1 &')    # h6->h2 SSH
    time.sleep(3)

    info('\n*** Phase 1: WARM-UP with FTP+SSH (0-30s) - Create Congestion FIRST!\n')
    info('    h6 -> h4:21 (TCP FTP, flow_id=63) - 2 streams, STAYS on s2\n')
    info('    h5 -> h3:21 (TCP FTP, flow_id=66) - 2 streams, CROSSES s2->s1\n')
    info('    h5 -> h1:22 (TCP SSH, flow_id=64) - 1 stream, CROSSES s2->s1\n')
    info('    h6 -> h2:22 (TCP SSH, flow_id=65) - 1 stream, CROSSES s2->s1\n')
    info('    Purpose: Saturate s2->s1 link BEFORE VIDEO starts!\n')
    h6.cmd('iperf -c 10.0.0.4 -p 21 -P 2 -t 30 > /dev/null 2>&1 &')
    h5.cmd('iperf -c 10.0.0.3 -p 21 -P 2 -t 30 > /dev/null 2>&1 &')
    h5.cmd('iperf -c 10.0.0.1 -p 22 -t 30 > /dev/null 2>&1 &')
    h6.cmd('iperf -c 10.0.0.2 -p 22 -t 30 > /dev/null 2>&1 &')

    info('\n*** Waiting 8 seconds for FTP+SSH to fully saturate link...\n')
    info('    Monitor: tail -f data/fplf_monitoring/link_utilization.csv\n')
    info('    Expected: s2-s1 utilization reaching 80-90%!\n')
    time.sleep(8)

    info('\n*** Phase 2: Add VIDEO (8-30s) - VIDEO ENTERS DURING CONGESTION!\n')
    info('    h3 -> h1:5004 (TCP VIDEO, flow_id=62) - 2 parallel streams\n')
    info('    h4 -> h2:5006 (TCP VIDEO, flow_id=68) - 2 parallel streams, CROSSES s2->s1\n')
    info('    CRITICAL: VIDEO starts AFTER link is saturated!\n')
    info('    Expected: VIDEO classified at 80-90%% utilization, SHOULD REROUTE!\n')
    h3.cmd('iperf -c 10.0.0.1 -p 5004 -P 2 -t 22 > /dev/null 2>&1 &')
    h4.cmd('iperf -c 10.0.0.2 -p 5006 -P 2 -t 22 > /dev/null 2>&1 &')

    info('\n*** Waiting 7 seconds for VIDEO to be classified during congestion...\n')
    time.sleep(7)

    info('\n*** Phase 3: Add HTTP (15-30s) - MAXIMUM TRAFFIC MIX!\n')
    info('    h3 -> h1:80 (TCP HTTP, flow_id=61) - 1 stream\n')
    info('    h4 -> h2:8080 (TCP HTTP, flow_id=67) - 1 stream\n')
    info('    All traffic types now competing for bandwidth!\n')
    h3.cmd('iperf -c 10.0.0.1 -p 80 -t 15 > /dev/null 2>&1 &')
    h4.cmd('iperf -c 10.0.0.2 -p 8080 -t 15 > /dev/null 2>&1 &')

    info('\n')
    info('='*80 + '\n')
    info('*** FIXED TIMING - VIDEO WILL BE CLASSIFIED DURING CONGESTION!\n')
    info('='*80 + '\n')
    info('  Monitor results:\n')
    info('    Terminal 2: tail -f data/fplf_monitoring/link_utilization.csv\n')
    info('    Terminal 3: tail -f data/fplf_monitoring/fplf_routes.csv\n')
    info('\n')
    info('  Expected timeline:\n')
    info('    0-8s: FTP+SSH saturates s2->s1 to 80-90%% (warm-up)\n')
    info('    8s: VIDEO traffic starts\n')
    info('    9-12s: VIDEO gets classified at 80-90%% utilization\n')
    info('    Result: route_changed=YES for VIDEO (weight >1500)!\n')
    info('\n')
    info('  Expected VIDEO behavior:\n')
    info('    - VIDEO classified during 80-90%% utilization\n')
    info('    - VIDEO adjusted_weight = 500 + (0.85 * 2000) = 2200\n')
    info('    - Alternate path weight = 1000\n')
    info('    - 1000 < 2200 → VIDEO REROUTES! ✅\n')
    info('\n')
    info('  Expected FTP behavior:\n')
    info('    - FTP classified during 80-90%% utilization\n')
    info('    - FTP adjusted_weight = 500 + (0.85 * 100) = 585\n')
    info('    - Alternate path weight = 1000\n')
    info('    - 585 < 1000 → FTP STAYS on direct path! ✅\n')
    info('='*80 + '\n')
    info('\n*** Traffic will run for 30 seconds total, then enter CLI\n\n')

    time.sleep(15)

    info('\n*** TCP traffic generation complete. Entering CLI for manual testing.\n')
    info('*** To verify VIDEO rerouted:\n')
    info('    grep VIDEO data/fplf_monitoring/fplf_routes.csv | grep YES\n')
    info('*** To check link utilization:\n')
    info('    grep "s2-s1" data/fplf_monitoring/link_utilization.csv | tail -10\n')
    CLI(net)

    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    create_tcp_traffic_topology()

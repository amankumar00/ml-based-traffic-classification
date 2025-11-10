#!/usr/bin/env python3
"""
ML Classifier Mesh Topology
Matches the FPLF mesh topology exactly for consistent training data

Topology:
  s1: h1, h2, h3 (10.0.0.1-3)
  s2: h4, h5, h6 (10.0.0.4-6)
  s3: h7, h8, h9 (10.0.0.7-9)

Links:
  s1 -- s2: 100 Mbps (fast)
  s2 -- s3: 100 Mbps (fast)
  s1 -- s3: 10 Mbps (bottleneck) - DIRECT LINK

This creates a triangle mesh with the same bottleneck as FPLF testing.
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.link import TCLink
from mininet.log import setLogLevel, info
import time

def create_ml_classifier_topology():
    """
    Create mesh topology matching FPLF test topology
    Returns: Mininet network object
    """
    setLogLevel('info')

    info('*** Creating ML Classifier Mesh Topology\n')
    info('    9 hosts (3 per switch), 3 switches in triangle mesh\n')
    info('    s1-s2: 100 Mbps, s2-s3: 100 Mbps, s1-s3: 10 Mbps (bottleneck)\n\n')

    net = Mininet(
        controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True
    )

    # Add controller
    info('*** Adding controller\n')
    c0 = net.addController('c0')

    # Add switches
    info('*** Adding switches\n')
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    s2 = net.addSwitch('s2', protocols='OpenFlow13')
    s3 = net.addSwitch('s3', protocols='OpenFlow13')

    # Add hosts
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

    # Add host-to-switch links (10 Mbps, 5ms delay)
    info('*** Adding host-to-switch links\n')
    net.addLink(h1, s1, bw=10, delay='5ms')
    net.addLink(h2, s1, bw=10, delay='5ms')
    net.addLink(h3, s1, bw=10, delay='5ms')

    net.addLink(h4, s2, bw=10, delay='5ms')
    net.addLink(h5, s2, bw=10, delay='5ms')
    net.addLink(h6, s2, bw=10, delay='5ms')

    net.addLink(h7, s3, bw=10, delay='5ms')
    net.addLink(h8, s3, bw=10, delay='5ms')
    net.addLink(h9, s3, bw=10, delay='5ms')

    # Add inter-switch links - MESH TOPOLOGY
    info('*** Adding inter-switch links (MESH)\n')
    # s1 -- s2: 100 Mbps (fast alternate path)
    net.addLink(s1, s2, bw=100, delay='2ms')
    info('    s1 -- s2: 100 Mbps, 2ms delay (FAST)\n')

    # s2 -- s3: 100 Mbps (fast alternate path)
    net.addLink(s2, s3, bw=100, delay='2ms')
    info('    s2 -- s3: 100 Mbps, 2ms delay (FAST)\n')

    # s1 -- s3: 10 Mbps (direct bottleneck)
    net.addLink(s1, s3, bw=10, delay='3ms')
    info('    s1 -- s3: 10 Mbps, 3ms delay (BOTTLENECK!)\n')

    info('\n*** Starting network\n')
    net.start()
    time.sleep(3)

    return net, [h1, h2, h3, h4, h5, h6, h7, h8, h9]


if __name__ == '__main__':
    # Test topology
    net, hosts = create_ml_classifier_topology()

    info('\n*** Network topology created successfully!\n')
    info(f'    Hosts: {[h.name for h in hosts]}\n')
    info('    Press Ctrl-D to exit\n\n')

    from mininet.cli import CLI
    CLI(net)

    info('\n*** Stopping network\n')
    net.stop()

#!/usr/bin/env python3
"""
FPLF Demo Topology with Traffic Generation
Creates 4-switch topology and generates classified traffic
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
import time

def run_demo():
    setLogLevel('info')

    info('*** Creating network\n')
    net = Mininet(
        controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
        switch=OVSSwitch
    )

    # Add controller
    c0 = net.addController('c0')

    # Add switches with failMode='secure' to disable L2 learning
    info('*** Adding switches\n')
    s1 = net.addSwitch('s1', protocols='OpenFlow13', failMode='secure')
    s2 = net.addSwitch('s2', protocols='OpenFlow13', failMode='secure')
    s3 = net.addSwitch('s3', protocols='OpenFlow13', failMode='secure')
    s4 = net.addSwitch('s4', protocols='OpenFlow13', failMode='secure')

    # Add hosts
    info('*** Adding hosts\n')
    h1 = net.addHost('h1', ip='10.0.0.1/24')
    h2 = net.addHost('h2', ip='10.0.0.2/24')
    h3 = net.addHost('h3', ip='10.0.0.3/24')
    h4 = net.addHost('h4', ip='10.0.0.4/24')
    h5 = net.addHost('h5', ip='10.0.0.5/24')
    h6 = net.addHost('h6', ip='10.0.0.6/24')

    # Create topology with multiple paths
    info('*** Creating links\n')
    info('  Hosts to access switches\n')
    net.addLink(h1, s1)
    net.addLink(h2, s1)
    net.addLink(h3, s2)
    net.addLink(h4, s2)
    net.addLink(h5, s3)
    net.addLink(h6, s4)

    info('  Core network (multiple paths)\n')
    net.addLink(s1, s2)  # Direct path
    net.addLink(s1, s3)  # Via s3
    net.addLink(s2, s4)  # Direct path
    net.addLink(s3, s4)  # Alternate
    net.addLink(s1, s4)  # Another path

    info('*** Starting network\n')
    net.start()

    info('*** Waiting for topology discovery (LLDP)...\n')
    for i in range(15):
        time.sleep(1)
        if (i+1) % 5 == 0:
            info(f'  ... {i+1} seconds (discovering links)\n')

    info('*** Starting simple ping test\n')
    info('Testing h1 -> h3:\n')
    result = h1.cmd('ping -c 5 10.0.0.3')
    info(result)
    info('\n')

    info('Testing h2 -> h4:\n')
    result = h2.cmd('ping -c 5 10.0.0.4')
    info(result)
    info('\n')

    time.sleep(2)

    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    run_demo()

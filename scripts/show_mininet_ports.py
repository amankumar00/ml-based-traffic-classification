#!/usr/bin/env python3
"""
Show actual port assignments in Mininet 4-switch topology
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.log import setLogLevel, info
import time

def show_topology():
    setLogLevel('info')

    net = Mininet(
        controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
        switch=OVSSwitch
    )

    c0 = net.addController('c0')

    # Add switches
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    s2 = net.addSwitch('s2', protocols='OpenFlow13')
    s3 = net.addSwitch('s3', protocols='OpenFlow13')
    s4 = net.addSwitch('s4', protocols='OpenFlow13')

    # Add hosts
    h1 = net.addHost('h1', ip='10.0.0.1/24')
    h2 = net.addHost('h2', ip='10.0.0.2/24')
    h3 = net.addHost('h3', ip='10.0.0.3/24')
    h4 = net.addHost('h4', ip='10.0.0.4/24')
    h5 = net.addHost('h5', ip='10.0.0.5/24')
    h6 = net.addHost('h6', ip='10.0.0.6/24')

    # Create links - SAME ORDER as fplf_demo_topology.py
    info('*** Adding links (same order as demo topology)\\n')
    net.addLink(h1, s1)
    net.addLink(h2, s1)
    net.addLink(h3, s2)
    net.addLink(h4, s2)
    net.addLink(h5, s3)
    net.addLink(h6, s4)

    net.addLink(s1, s2)  # Direct path
    net.addLink(s1, s3)  # Via s3
    net.addLink(s2, s4)  # Direct path
    net.addLink(s3, s4)  # Alternate
    net.addLink(s1, s4)  # Another path

    net.start()

    time.sleep(2)

    info('\\n*** ACTUAL PORT ASSIGNMENTS:\\n')
    info('='*60 + '\\n')

    for switch in [s1, s2, s3, s4]:
        info(f'\\n{switch.name} ports:\\n')
        info('-'*40 + '\\n')
        for intf in sorted(switch.intfList(), key=lambda x: x.name):
            if intf.name == 'lo':
                continue
            link = intf.link
            if link:
                intf1, intf2 = link.intf1, link.intf2
                other = intf2 if intf1 == intf else intf1
                port_num = switch.ports[intf]
                info(f'  Port {port_num}: {intf.name} <--> {other.name}\\n')

    info('\\n' + '='*60 + '\\n')
    info('\\nExpected configuration (from manual topology):\\n')
    info('  s1: hosts on 1,2; switches on 3(s2), 4(s3), 5(s4)\\n')
    info('  s2: hosts on 1,2; switches on 3(s1), 4(s4)\\n')
    info('  s3: host on 1; switches on 2(s1), 3(s4)\\n')
    info('  s4: host on 1; switches on 2(s2), 3(s3), 4(s1)\\n')
    info('='*60 + '\\n')

    net.stop()

if __name__ == '__main__':
    show_topology()

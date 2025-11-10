#!/usr/bin/env python3
"""
Minimal FPLF test - 2 switches, 2 hosts
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.log import setLogLevel, info
from mininet.cli import CLI
import time

def run_test():
    setLogLevel('info')

    net = Mininet(
        controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
        switch=OVSSwitch
    )

    # Add controller
    c0 = net.addController('c0')

    # Add switches
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    s2 = net.addSwitch('s2', protocols='OpenFlow13')

    # Add hosts
    h1 = net.addHost('h1', ip='10.0.0.1/24')
    h2 = net.addHost('h2', ip='10.0.0.2/24')

    # Create links - hosts first, then inter-switch
    info('*** Adding links\n')
    net.addLink(h1, s1)  # h1 on s1
    net.addLink(h2, s2)  # h2 on s2
    net.addLink(s1, s2)  # s1 <-> s2

    info('*** Starting network\n')
    net.start()

    # Print actual port assignments
    info('\n*** Port assignments:\n')
    for switch in [s1, s2]:
        info(f'{switch.name}:\n')
        for intf in switch.intfList():
            if intf.name != 'lo':
                info(f'  {intf.name}: {intf.link}\n')

    info('\n*** Waiting for controller...\n')
    time.sleep(5)

    info('*** Testing h1 -> h2\n')
    result = h1.cmd('ping -c 3 10.0.0.2')
    info(result)

    time.sleep(2)
    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    run_test()

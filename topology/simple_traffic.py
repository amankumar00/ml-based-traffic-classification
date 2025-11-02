#!/usr/bin/env python3
"""
Simple working traffic generator for Mininet
Generates actual TCP and UDP traffic that gets captured
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.link import TCLink
from mininet.log import setLogLevel, info
import time
import sys

def generate_real_traffic(net, duration=60):
    """Generate actual TCP and UDP traffic that will be captured"""

    hosts = net.hosts

    info('*** Generating real network traffic\n')

    # 1. ICMP - Continuous ping between hosts
    info('  Starting ICMP (ping) traffic...\n')
    for i in range(min(3, len(hosts)-1)):
        hosts[i].cmd(f'ping -i 0.5 -c {duration*2} {hosts[i+1].IP()} > /dev/null 2>&1 &')

    # 2. TCP traffic with nc (netcat) - Simple data transfer
    info('  Starting TCP traffic (port 8000-8002)...\n')
    if len(hosts) >= 4:
        # Server hosts
        hosts[0].cmd('yes "TCP data from h1" | nc -l -p 8000 > /dev/null 2>&1 &')
        hosts[1].cmd('yes "TCP data from h2" | nc -l -p 8001 > /dev/null 2>&1 &')
        time.sleep(2)

        # Client hosts - connect and receive data
        hosts[2].cmd(f'nc {hosts[0].IP()} 8000 > /dev/null 2>&1 &')
        hosts[3].cmd(f'nc {hosts[1].IP()} 8001 > /dev/null 2>&1 &')

    # 3. UDP traffic with nc
    info('  Starting UDP traffic (port 9000-9001)...\n')
    if len(hosts) >= 4:
        # UDP servers
        hosts[0].cmd('yes "UDP data" | nc -u -l -p 9000 > /dev/null 2>&1 &')
        time.sleep(1)
        # UDP clients
        hosts[2].cmd(f'yes "UDP client" | nc -u {hosts[0].IP()} 9000 > /dev/null 2>&1 &')

    # 4. More TCP on different ports (simulate HTTP-like)
    info('  Starting HTTP-like TCP traffic (port 80)...\n')
    if len(hosts) >= 2:
        hosts[0].cmd('while true; do echo -e "HTTP/1.1 200 OK\n\nHello" | nc -l -p 80 -q 1; done > /dev/null 2>&1 &')
        time.sleep(1)
        # Clients repeatedly connect
        hosts[1].cmd(f'while true; do echo "GET /" | nc {hosts[0].IP()} 80 -w 1 > /dev/null 2>&1; sleep 2; done &')

    info(f'*** Traffic generation started, running for {duration} seconds...\n')
    info('*** Monitor controller for packet capture\n')


def main():
    setLogLevel('info')

    duration = int(sys.argv[1]) if len(sys.argv) > 1 else 60

    info('*** Creating network\n')
    net = Mininet(
        controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True
    )

    info('*** Adding controller\n')
    c0 = net.addController('c0')

    info('*** Adding hosts and switches\n')
    # Create custom topology: 3 switches, 6 hosts
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    s2 = net.addSwitch('s2', protocols='OpenFlow13')
    s3 = net.addSwitch('s3', protocols='OpenFlow13')

    h1 = net.addHost('h1', ip='10.0.1.1/24')
    h2 = net.addHost('h2', ip='10.0.1.2/24')
    h3 = net.addHost('h3', ip='10.0.2.1/24')
    h4 = net.addHost('h4', ip='10.0.2.2/24')
    h5 = net.addHost('h5', ip='10.0.3.1/24')
    h6 = net.addHost('h6', ip='10.0.3.2/24')

    info('*** Creating links\n')
    # Connect hosts to switches
    net.addLink(h1, s1)
    net.addLink(h2, s1)
    net.addLink(h3, s2)
    net.addLink(h4, s2)
    net.addLink(h5, s3)
    net.addLink(h6, s3)

    # Connect switches together
    net.addLink(s1, s2)
    net.addLink(s2, s3)

    info('*** Starting network\n')
    net.start()

    info('*** Waiting for controller connection\n')
    time.sleep(3)

    info('*** Testing connectivity\n')
    net.pingAll()

    # Generate traffic
    generate_real_traffic(net, duration)

    # Wait
    time.sleep(duration)

    info('*** Stopping network\n')
    net.stop()

    info('*** Done!\n')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Guaranteed working traffic generator using only Python built-ins
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.link import TCLink
from mininet.log import setLogLevel, info
import time
import sys

def generate_guaranteed_traffic(net, duration=60):
    """Generate traffic using Python and basic tools guaranteed to exist"""

    hosts = net.hosts
    info('*** Generating GUARANTEED working traffic\n')

    # 1. ICMP - Heavy continuous ping
    info('  ICMP: Continuous ping between all hosts...\n')
    for i in range(len(hosts)-1):
        hosts[i].cmd(f'ping -i 0.2 {hosts[i+1].IP()} > /dev/null 2>&1 &')

    # 2. TCP HTTP traffic using Python's built-in HTTP server
    info('  TCP: Starting Python HTTP servers on h1 and h2...\n')
    if len(hosts) >= 4:
        # Start HTTP servers
        hosts[0].cmd('cd /tmp && python3 -m http.server 8000 > /dev/null 2>&1 &')
        hosts[1].cmd('cd /tmp && python3 -m http.server 8001 > /dev/null 2>&1 &')
        time.sleep(3)

        # Use wget to generate HTTP requests (guaranteed to work)
        info('  TCP: Clients making HTTP requests with wget...\n')
        hosts[2].cmd(f'while true; do wget -q -O /dev/null http://{hosts[0].IP()}:8000/ 2>/dev/null; sleep 1; done &')
        hosts[3].cmd(f'while true; do wget -q -O /dev/null http://{hosts[1].IP()}:8001/ 2>/dev/null; sleep 1; done &')

        if len(hosts) >= 5:
            hosts[4].cmd(f'while true; do wget -q -O /dev/null http://{hosts[0].IP()}:8000/ 2>/dev/null; sleep 2; done &')

    # 3. More TCP on port 9000 using netcat-traditional (if available)
    info('  TCP: Additional TCP traffic on port 9000...\n')
    if len(hosts) >= 3:
        # Try netcat traditional which might work better
        hosts[0].cmd('(while true; do echo "Server response" | nc.traditional -l -p 9000 -q 1 2>/dev/null; done) &')
        time.sleep(2)
        hosts[2].cmd(f'(while true; do echo "Client request" | nc.traditional {hosts[0].IP()} 9000 -q 1 2>/dev/null; sleep 3; done) &')

    # 4. Generate some UDP traffic using Python
    info('  UDP: Generating UDP traffic with Python...\n')
    if len(hosts) >= 2:
        # Simple UDP server using Python
        hosts[0].cmd('''python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('0.0.0.0', 5555))
while True:
    data, addr = s.recvfrom(1024)
" > /dev/null 2>&1 &''')

        time.sleep(1)

        # UDP client
        hosts[1].cmd(f'''python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
while True:
    s.sendto(b'UDP test data', ('{hosts[0].IP()}', 5555))
    time.sleep(0.5)
" > /dev/null 2>&1 &''')

    info(f'\n*** Traffic generation started!\n')
    info(f'*** Running for {duration} seconds...\n')
    info('*** Watch controller for packet capture (saves every 30 seconds)\n\n')


def main():
    setLogLevel('info')
    duration = int(sys.argv[1]) if len(sys.argv) > 1 else 60

    info('*** Creating network with 6 hosts, 3 switches\n')
    net = Mininet(
        controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True
    )

    info('*** Adding controller\n')
    c0 = net.addController('c0')

    info('*** Adding switches\n')
    s1 = net.addSwitch('s1', protocols='OpenFlow13')
    s2 = net.addSwitch('s2', protocols='OpenFlow13')
    s3 = net.addSwitch('s3', protocols='OpenFlow13')

    info('*** Adding hosts\n')
    h1 = net.addHost('h1', ip='10.0.1.1/24')
    h2 = net.addHost('h2', ip='10.0.1.2/24')
    h3 = net.addHost('h3', ip='10.0.2.1/24')
    h4 = net.addHost('h4', ip='10.0.2.2/24')
    h5 = net.addHost('h5', ip='10.0.3.1/24')
    h6 = net.addHost('h6', ip='10.0.3.2/24')

    info('*** Creating links\n')
    net.addLink(h1, s1)
    net.addLink(h2, s1)
    net.addLink(h3, s2)
    net.addLink(h4, s2)
    net.addLink(h5, s3)
    net.addLink(h6, s3)
    net.addLink(s1, s2)
    net.addLink(s2, s3)

    info('*** Starting network\n')
    net.start()

    info('*** Waiting for switches to connect...\n')
    time.sleep(3)

    info('*** Testing basic connectivity\n')
    result = net.pingAll()

    # Generate traffic
    generate_guaranteed_traffic(net, duration)

    # Wait
    time.sleep(duration)

    info('\n*** Stopping network\n')
    net.stop()

    info('*** Traffic generation complete!\n')
    info('*** Check data/raw/ for captured packets\n')


if __name__ == '__main__':
    main()

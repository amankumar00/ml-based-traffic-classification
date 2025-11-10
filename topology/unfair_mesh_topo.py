#!/usr/bin/env python3
"""
Unfair Mesh Topology for Demonstrating FPLF Route Changes

This topology intentionally creates an unfair mesh where:
- Direct path s1->s3 has LOWER bandwidth (20 Mbps)
- Indirect path s1->s2->s3 has HIGHER bandwidth (100 Mbps each)

This forces FPLF to choose the longer path when direct link is congested!
"""

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.link import TCLink
from mininet.log import setLogLevel, info
from mininet.cli import CLI
import time


class UnfairMeshTopology(Topo):
    """
    Mesh topology with unfair link bandwidths to demonstrate FPLF

    Topology:
           s1 -------- s2
            \   20M   /
          20M \     / 100M
                \  /
                 s3

    - s1-s3 direct link: 20 Mbps (SLOW, will congest easily)
    - s1-s2 link: 100 Mbps (FAST)
    - s2-s3 link: 100 Mbps (FAST)

    With heavy traffic s1->s3:
    - Direct path gets congested (20 Mbps bottleneck)
    - FPLF routes via s2 (100+100 = 200 Mbps capacity)
    - route_changed = YES!
    """

    def build(self, num_switches=3, hosts_per_switch=3):
        # Add switches
        switches = []
        for i in range(1, num_switches + 1):
            switch = self.addSwitch(f's{i}', protocols='OpenFlow13')
            switches.append(switch)

        # Add hosts
        host_id = 1
        for switch in switches:
            for j in range(hosts_per_switch):
                host = self.addHost(f'h{host_id}',
                                   ip=f'10.0.0.{host_id}/24',
                                   mac=f'00:00:00:00:00:{host_id:02x}')
                self.addLink(host, switch, bw=10, delay='5ms')
                host_id += 1

        # Create UNFAIR mesh connectivity
        # Fast paths via s2
        self.addLink(switches[0], switches[1], bw=100, delay='2ms')  # s1-s2: FAST
        self.addLink(switches[1], switches[2], bw=100, delay='2ms')  # s2-s3: FAST

        # Slow direct path (intentionally throttled)
        self.addLink(switches[0], switches[2], bw=20, delay='2ms')   # s1-s3: SLOW!


def main():
    setLogLevel('info')

    # Create unfair mesh topology
    topo = UnfairMeshTopology(num_switches=3, hosts_per_switch=3)

    # Create network
    net = Mininet(
        topo=topo,
        controller=lambda name: RemoteController(name, ip='127.0.0.1', port=6653),
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True,
        autoStaticArp=True
    )

    info('*** Starting network\n')
    net.start()
    time.sleep(5)

    info('*** Network information:\n')
    for host in net.hosts:
        info(f'{host.name}: {host.IP()} (MAC: {host.MAC()})\n')

    info('\n')
    info('*** Link Bandwidths:\n')
    info('  s1-s2: 100 Mbps (FAST)\n')
    info('  s2-s3: 100 Mbps (FAST)\n')
    info('  s1-s3:  20 Mbps (SLOW - bottleneck)\n')
    info('\n')

    info('*** Generating traffic to congest s1-s3 link...\n')
    hosts = net.hosts

    # Generate HEAVY s1->s3 traffic to congest the 20Mbps direct link
    info('Starting VIDEO servers on s3 (h7, h8, h9)...\n')
    hosts[6].cmd('dd if=/dev/zero of=/tmp/video bs=1M count=200 2>/dev/null &')
    hosts[7].cmd('dd if=/dev/zero of=/tmp/video2 bs=1M count=200 2>/dev/null &')
    hosts[8].cmd('dd if=/dev/zero of=/tmp/video3 bs=1M count=200 2>/dev/null &')

    hosts[6].cmd('while true; do nc -l -p 1935 < /tmp/video; done &')
    hosts[7].cmd('while true; do nc -l -p 1935 < /tmp/video2; done &')
    hosts[8].cmd('while true; do nc -l -p 1935 < /tmp/video3; done &')
    time.sleep(2)

    info('Starting MULTIPLE VIDEO clients from s1 (h1, h2, h3) to s3...\n')
    # Generate > 20 Mbps of traffic to FORCE congestion on s1-s3 direct link
    hosts[0].cmd('while true; do nc 10.0.0.7 1935 > /dev/null 2>&1; done &')  # h1->h7
    hosts[0].cmd('while true; do nc 10.0.0.8 1935 > /dev/null 2>&1; done &')  # h1->h8
    hosts[1].cmd('while true; do nc 10.0.0.7 1935 > /dev/null 2>&1; done &')  # h2->h7
    hosts[1].cmd('while true; do nc 10.0.0.8 1935 > /dev/null 2>&1; done &')  # h2->h8
    hosts[2].cmd('while true; do nc 10.0.0.9 1935 > /dev/null 2>&1; done &')  # h3->h9

    # SSH traffic
    info('Starting SSH traffic...\n')
    hosts[7].cmd('dd if=/dev/zero of=/tmp/ssh bs=1M count=50 2>/dev/null &')
    hosts[8].cmd('while true; do nc -l -p 22 < /tmp/ssh; done &')
    time.sleep(1)
    hosts[2].cmd('while true; do nc 10.0.0.8 22 > /dev/null 2>&1; done &')

    # HTTP traffic
    info('Starting HTTP traffic...\n')
    hosts[6].cmd('python3 -m http.server 8000 &')
    hosts[4].cmd('python3 -m http.server 8001 &')
    time.sleep(2)
    hosts[5].cmd('while true; do wget -q -O /dev/null http://10.0.0.7:8000/; done &')
    hosts[0].cmd('while true; do wget -q -O /dev/null http://10.0.0.5:8001/; done &')

    # FTP traffic
    info('Starting FTP traffic...\n')
    hosts[8].cmd('dd if=/dev/zero of=/tmp/ftp bs=1M count=50 2>/dev/null &')
    hosts[8].cmd('while true; do nc -l -p 21 < /tmp/ftp; done &')
    time.sleep(1)
    hosts[1].cmd('while true; do nc 10.0.0.9 21 > /dev/null 2>&1; done &')

    info('\n')
    info('*** Traffic generation complete!\n')
    info('*** Expected behavior:\n')
    info('  1. Direct s1-s3 link (20 Mbps) gets CONGESTED\n')
    info('  2. FPLF routes VIDEO traffic via s2 (100+100 Mbps)\n')
    info('  3. CSV shows route_changed=YES for s1->s3 flows\n')
    info('\n')
    info('*** Running for 90 seconds...\n')

    time.sleep(90)

    info('*** Stopping network\n')
    net.stop()


if __name__ == '__main__':
    main()

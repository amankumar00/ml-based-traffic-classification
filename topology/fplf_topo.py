"""
FPLF Mininet Topology for Dynamic Routing Demonstration
Creates a network topology with multiple hosts and switches for FPLF algorithm testing
All hosts in single subnet (10.0.0.0/24) to enable inter-switch routing
"""

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import RemoteController, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
import time


class CustomTopology(Topo):
    """
    FPLF topology with multiple switches and hosts in single subnet

    Topology:
            Controller (Ryu FPLF)
                 |
        +--------+--------+
        |        |        |
       s1-------s2-------s3
       |        |        |
    +--+--+  +--+--+  +--+--+
    |  |  |  |  |  |  |  |  |
    h1 h2 h3 h4 h5 h6 h7 h8 h9
    (all in 10.0.0.0/24 subnet)
    """

    def build(self, num_switches=3, hosts_per_switch=3):
        """
        Build custom topology

        Args:
            num_switches: Number of switches
            hosts_per_switch: Number of hosts per switch
        """
        # Add switches
        switches = []
        for i in range(1, num_switches + 1):
            switch = self.addSwitch(f's{i}', protocols='OpenFlow13')
            switches.append(switch)

        # Add hosts and connect to switches (all in same subnet for L2 routing)
        host_id = 1
        for switch_idx, switch in enumerate(switches):
            for j in range(hosts_per_switch):
                host = self.addHost(f'h{host_id}',
                                   ip=f'10.0.0.{host_id}/24',
                                   mac=f'00:00:00:00:00:{host_id:02x}')
                # Add link with bandwidth and delay constraints
                self.addLink(host, switch,
                           bw=10,  # 10 Mbps
                           delay='5ms',
                           loss=0,
                           max_queue_size=1000)
                host_id += 1

        # Connect switches to each other (optional - creates more complex topology)
        if num_switches > 1:
            for i in range(len(switches) - 1):
                self.addLink(switches[i], switches[i + 1],
                           bw=100,  # 100 Mbps
                           delay='2ms')


class MeshTopology(Topo):
    """
    Mesh topology with multiple paths between switches
    This topology allows FPLF to demonstrate route optimization

    Topology (3 switches):
           s1 -------- s2
            \         /
             \       /
              \     /
               \   /
                 s3

    Multiple paths between any two switches allow FPLF to:
    - Route around congested links
    - Balance load across redundant paths
    - Prioritize high-priority traffic on better paths
    """

    def build(self, num_switches=3, hosts_per_switch=3):
        """
        Build mesh topology with full connectivity

        Args:
            num_switches: Number of switches (default: 3)
            hosts_per_switch: Number of hosts per switch (default: 3)
        """
        # Add switches
        switches = []
        for i in range(1, num_switches + 1):
            switch = self.addSwitch(f's{i}', protocols='OpenFlow13')
            switches.append(switch)

        # Add hosts (all in same subnet for L2 routing)
        host_id = 1
        for switch_idx, switch in enumerate(switches):
            for j in range(hosts_per_switch):
                host = self.addHost(f'h{host_id}',
                                   ip=f'10.0.0.{host_id}/24',
                                   mac=f'00:00:00:00:00:{host_id:02x}')
                # Add link with bandwidth and delay constraints
                self.addLink(host, switch,
                           bw=10,  # 10 Mbps
                           delay='5ms',
                           loss=0,
                           max_queue_size=1000)
                host_id += 1

        # Create mesh connectivity between switches
        # For 3 switches: s1-s2, s2-s3, s1-s3 (triangle/full mesh)
        if num_switches == 3:
            # Primary path: s1 -- s2 -- s3 (linear)
            # FAST alternate path via s2
            self.addLink(switches[0], switches[1],
                       bw=100, delay='2ms')  # 100 Mbps - FAST
            self.addLink(switches[1], switches[2],
                       bw=100, delay='2ms')  # 100 Mbps - FAST

            # Redundant path: s1 -- s3 (direct link)
            # BOTTLENECK: 10 Mbps with heavy netcat traffic = HIGH CONGESTION!
            self.addLink(switches[0], switches[2],
                       bw=10, delay='3ms')  # 10 Mbps BOTTLENECK!

        elif num_switches == 4:
            # Create rectangle with cross-links
            #   s1 -- s2
            #   |  X  |
            #   s3 -- s4
            self.addLink(switches[0], switches[1], bw=100, delay='2ms')  # s1-s2
            self.addLink(switches[2], switches[3], bw=100, delay='2ms')  # s3-s4
            self.addLink(switches[0], switches[2], bw=100, delay='2ms')  # s1-s3
            self.addLink(switches[1], switches[3], bw=100, delay='2ms')  # s2-s4
            # Diagonal links for more redundancy
            self.addLink(switches[0], switches[3], bw=100, delay='3ms')  # s1-s4
            self.addLink(switches[1], switches[2], bw=100, delay='3ms')  # s2-s3

        else:
            # General case: full mesh (all-to-all connectivity)
            for i in range(len(switches)):
                for j in range(i + 1, len(switches)):
                    self.addLink(switches[i], switches[j],
                               bw=100, delay='2ms')


class LinearTopology(Topo):
    """
    Simple linear topology: h1 -- s1 -- s2 -- s3 -- h2
    Good for testing basic flow routing
    """

    def build(self):
        # Add hosts
        h1 = self.addHost('h1', ip='10.0.0.1/24')
        h2 = self.addHost('h2', ip='10.0.0.2/24')

        # Add switches
        s1 = self.addSwitch('s1', protocols='OpenFlow13')
        s2 = self.addSwitch('s2', protocols='OpenFlow13')
        s3 = self.addSwitch('s3', protocols='OpenFlow13')

        # Add links
        self.addLink(h1, s1)
        self.addLink(s1, s2)
        self.addLink(s2, s3)
        self.addLink(s3, h2)


class StarTopology(Topo):
    """
    Star topology with central switch
    """

    def build(self, num_hosts=6):
        # Add central switch
        central_switch = self.addSwitch('s1', protocols='OpenFlow13')

        # Add hosts in star configuration
        for i in range(1, num_hosts + 1):
            host = self.addHost(f'h{i}',
                               ip=f'10.0.0.{i}/24',
                               mac=f'00:00:00:00:00:{i:02x}')
            self.addLink(host, central_switch,
                        bw=10,
                        delay='5ms')


def start_network(topology='custom', controller_ip='127.0.0.1', controller_port=6653):
    """
    Start Mininet network with specified topology

    Args:
        topology: Topology type ('custom', 'linear', 'star')
        controller_ip: IP address of Ryu controller
        controller_port: Port of Ryu controller
    """
    # Set logging level
    setLogLevel('info')

    # Create topology
    if topology == 'custom':
        topo = CustomTopology(num_switches=3, hosts_per_switch=3)
    elif topology == 'mesh':
        topo = MeshTopology(num_switches=3, hosts_per_switch=3)
    elif topology == 'linear':
        topo = LinearTopology()
    elif topology == 'star':
        topo = StarTopology(num_hosts=6)
    else:
        print(f"Unknown topology: {topology}")
        return

    # Create network with remote controller (Ryu)
    info('*** Creating network\n')
    net = Mininet(
        topo=topo,
        controller=lambda name: RemoteController(
            name,
            ip=controller_ip,
            port=controller_port
        ),
        switch=OVSSwitch,
        link=TCLink,
        autoSetMacs=True,
        autoStaticArp=True
    )

    # Start network
    info('*** Starting network\n')
    net.start()

    info('*** Network started successfully\n')
    info('*** Waiting for switches to connect to controller...\n')
    time.sleep(3)

    # Display network information
    info('*** Network information:\n')
    for host in net.hosts:
        info(f'{host.name}: {host.IP()} (MAC: {host.MAC()})\n')

    return net


def generate_traffic(net, traffic_type='mixed'):
    """
    Generate different types of network traffic for testing
    Focus on cross-switch traffic (especially s1<->s3) to demonstrate route optimization

    Args:
        net: Mininet network instance
        traffic_type: Type of traffic ('http', 'ftp', 'ssh', 'video', 'mixed')

    Host mapping (mesh topology with 9 hosts):
        s1: h1, h2, h3 (10.0.0.1-3)
        s2: h4, h5, h6 (10.0.0.4-6)
        s3: h7, h8, h9 (10.0.0.7-9)
    """
    info('*** Generating network traffic (FTP, SSH, HTTP, VIDEO only)\n')

    hosts = net.hosts

    if len(hosts) < 9:
        info('*** Warning: Expected 9 hosts for optimal traffic generation\n')

    # NOTE: ICMP and iPerf removed as per user request
    # Only generating: FTP (port 21), SSH (port 22), HTTP (port 80/8000), VIDEO (port 1935)

    if traffic_type == 'video' or traffic_type == 'mixed':
        # VIDEO traffic - MATCHES ML CLASSIFIER FLOWS
        # h3->h1:5004, h4->h2:5006
        info('Generating VIDEO traffic (matching ML classifier)...\n')
        if len(hosts) >= 2:
            # VIDEO servers on h1 and h2 (s1 hosts)
            info('*** Creating VIDEO files and starting servers on h1, h2...\n')
            hosts[0].cmd('dd if=/dev/zero of=/tmp/video1 bs=1M count=200 2>/dev/null &')  # h1
            hosts[1].cmd('dd if=/dev/zero of=/tmp/video2 bs=1M count=200 2>/dev/null &')  # h2
            time.sleep(3)

            # Start netcat servers on ports 5004, 5006 (matching ML classifier CSV)
            hosts[0].cmd('while true; do nc -l -p 5004 < /tmp/video1; done &')  # h1 server on port 5004
            hosts[1].cmd('while true; do nc -l -p 5006 < /tmp/video2; done &')  # h2 server on port 5006
            time.sleep(2)

            # VIDEO clients: h3->h1:5004, h4->h2:5006 (SAME SWITCH traffic for now)
            info('*** Starting VIDEO clients...\n')
            info(f'    h3 -> h1:5004 (VIDEO)\n')
            info(f'    h4 -> h2:5006 (VIDEO)\n')
            hosts[2].cmd(f'while true; do nc {hosts[0].IP()} 5004 > /dev/null 2>&1; done &')  # h3 -> h1:5004
            if len(hosts) >= 4:
                hosts[3].cmd(f'while true; do nc {hosts[1].IP()} 5006 > /dev/null 2>&1; done &')  # h4 -> h2:5006
            time.sleep(1)

    if traffic_type == 'ssh' or traffic_type == 'mixed':
        # SSH traffic - MATCHES ML CLASSIFIER FLOWS
        # h5->h1:22, h6->h2:22
        info('Generating SSH traffic (matching ML classifier)...\n')
        if len(hosts) >= 2:
            # SSH servers on h1 and h2 (s1 hosts)
            hosts[0].cmd('dd if=/dev/urandom of=/tmp/sshdata1 bs=1024 count=100 2>/dev/null')  # h1
            hosts[0].cmd('while true; do nc -l -p 22 < /tmp/sshdata1; done > /dev/null 2>&1 &')

            hosts[1].cmd('dd if=/dev/urandom of=/tmp/sshdata2 bs=1024 count=100 2>/dev/null')  # h2
            hosts[1].cmd('while true; do nc -l -p 22 < /tmp/sshdata2; done > /dev/null 2>&1 &')
            time.sleep(1)

            # SSH clients: h5->h1:22, h6->h2:22
            info(f'    h5 -> h1:22 (SSH)\n')
            info(f'    h6 -> h2:22 (SSH)\n')
            if len(hosts) >= 5:
                hosts[4].cmd(f'while true; do nc {hosts[0].IP()} 22 > /dev/null; sleep 3; done 2>/dev/null &')  # h5 -> h1
            if len(hosts) >= 6:
                hosts[5].cmd(f'while true; do nc {hosts[1].IP()} 22 > /dev/null; sleep 3; done 2>/dev/null &')  # h6 -> h2

    if traffic_type == 'http' or traffic_type == 'mixed':
        # HTTP traffic - MATCHES ML CLASSIFIER FLOWS
        # h3->h1:80, h4->h2:8080
        info('Generating HTTP traffic (matching ML classifier)...\n')
        if len(hosts) >= 2:
            # HTTP servers on h1 and h2 (s1 hosts)
            hosts[0].cmd('python3 -m http.server 80 > /dev/null 2>&1 &')  # h1 on port 80
            hosts[1].cmd('python3 -m http.server 8080 > /dev/null 2>&1 &')  # h2 on port 8080
            time.sleep(3)

            # HTTP clients: h3->h1:80, h4->h2:8080
            info(f'    h3 -> h1:80 (HTTP)\n')
            info(f'    h4 -> h2:8080 (HTTP)\n')
            hosts[2].cmd(f'while true; do wget -q -O /dev/null http://{hosts[0].IP()}:80/ 2>/dev/null; sleep 4; done &')  # h3 -> h1
            if len(hosts) >= 4:
                hosts[3].cmd(f'while true; do wget -q -O /dev/null http://{hosts[1].IP()}:8080/ 2>/dev/null; sleep 4; done &')  # h4 -> h2

    if traffic_type == 'ftp' or traffic_type == 'mixed':
        # FTP traffic - MATCHES ML CLASSIFIER FLOWS
        # h6->h4:21, h5->h3:21
        info('Generating FTP traffic (matching ML classifier)...\n')
        if len(hosts) >= 4:
            # FTP servers on h4 and h3
            hosts[3].cmd('dd if=/dev/urandom of=/tmp/ftpfile1 bs=1024 count=150 2>/dev/null')  # h4
            hosts[3].cmd('while true; do nc -l -p 21 < /tmp/ftpfile1; done > /dev/null 2>&1 &')

            hosts[2].cmd('dd if=/dev/urandom of=/tmp/ftpfile2 bs=1024 count=150 2>/dev/null')  # h3
            hosts[2].cmd('while true; do nc -l -p 21 < /tmp/ftpfile2; done > /dev/null 2>&1 &')
            time.sleep(1)

            # FTP clients: h6->h4:21, h5->h3:21
            info(f'    h6 -> h4:21 (FTP)\n')
            info(f'    h5 -> h3:21 (FTP)\n')
            if len(hosts) >= 6:
                hosts[5].cmd(f'while true; do nc {hosts[3].IP()} 21 > /dev/null; sleep 5; done 2>/dev/null &')  # h6 -> h4
            if len(hosts) >= 5:
                hosts[4].cmd(f'while true; do nc {hosts[2].IP()} 21 > /dev/null; sleep 5; done 2>/dev/null &')  # h5 -> h3

    info('*** Traffic generation complete\n')
    info('*** Flows created (MATCHING ML CLASSIFIER CSV):\n')
    info('    - VIDEO: h3->h1:5004, h4->h2:5006 (priority 4, same switch for now)\n')
    info('    - SSH: h5->h1:22, h6->h2:22 (priority 3)\n')
    info('    - HTTP: h3->h1:80, h4->h2:8080 (priority 2)\n')
    info('    - FTP: h6->h4:21, h5->h3:21 (priority 1)\n')
    info('*** These flows match the CSV generated by ML classifier\n')
    info('*** Controller will recognize traffic types and apply priorities!\n')


def run_interactive_mode(net):
    """Run Mininet in interactive CLI mode"""
    info('*** Running CLI\n')
    info('*** Useful commands:\n')
    info('  - pingall: Test connectivity between all hosts\n')
    info('  - h1 ping h2: Ping from h1 to h2\n')
    info('  - h1 iperf -s &: Start iperf server on h1\n')
    info('  - h2 iperf -c <h1_ip>: Run iperf client from h2\n')
    info('  - dump: Show network topology\n')
    info('  - net: Show network information\n')
    info('  - links: Show link status\n')
    info('  - xterm h1: Open terminal on h1\n')
    CLI(net)


def main():
    """Main function to setup and run the network"""
    import argparse

    parser = argparse.ArgumentParser(description='Mininet SDN Network Topology')
    parser.add_argument('--topology', '-t',
                       default='custom',
                       choices=['custom', 'mesh', 'linear', 'star'],
                       help='Network topology type')
    parser.add_argument('--controller-ip', '-c',
                       default='127.0.0.1',
                       help='Ryu controller IP address')
    parser.add_argument('--controller-port', '-p',
                       type=int,
                       default=6653,
                       help='Ryu controller port')
    parser.add_argument('--traffic', '-g',
                       default=None,
                       choices=['http', 'ftp', 'ssh', 'icmp', 'iperf', 'mixed'],
                       help='Generate traffic automatically')
    parser.add_argument('--duration', '-d',
                       type=int,
                       default=60,
                       help='Duration to run traffic (seconds)')

    args = parser.parse_args()

    # Start network
    net = start_network(
        topology=args.topology,
        controller_ip=args.controller_ip,
        controller_port=args.controller_port
    )

    try:
        # Generate traffic if requested
        if args.traffic:
            generate_traffic(net, traffic_type=args.traffic)
            info(f'*** Running for {args.duration} seconds...\n')
            time.sleep(args.duration)
        else:
            # Run interactive mode
            run_interactive_mode(net)

    finally:
        # Cleanup
        info('*** Stopping network\n')
        net.stop()


if __name__ == '__main__':
    main()

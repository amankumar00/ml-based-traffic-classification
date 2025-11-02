"""
Custom Mininet Topology for SDN Network Simulation
Creates a network topology with multiple hosts and switches for traffic classification testing
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
    Custom topology with multiple switches and hosts

    Topology:
            Controller (Ryu)
                 |
        +--------+--------+
        |        |        |
       s1       s2       s3
       |        |        |
    +--+--+  +--+--+  +--+--+
    |  |  |  |  |  |  |  |  |
    h1 h2 h3 h4 h5 h6 h7 h8 h9
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

        # Add hosts and connect to switches
        host_id = 1
        for switch_idx, switch in enumerate(switches):
            for j in range(hosts_per_switch):
                host = self.addHost(f'h{host_id}',
                                   ip=f'10.0.{switch_idx + 1}.{j + 1}/24',
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

    Args:
        net: Mininet network instance
        traffic_type: Type of traffic ('http', 'ftp', 'ssh', 'icmp', 'mixed')
    """
    info('*** Generating network traffic\n')

    hosts = net.hosts

    if traffic_type == 'icmp' or traffic_type == 'mixed':
        # ICMP traffic (ping) - continuous
        info('Generating ICMP traffic (ping)...\n')
        for i in range(min(3, len(hosts) - 1)):
            # Ping continuously with 1 second interval
            hosts[i].cmd(f'ping -i 1 {hosts[i + 1].IP()} > /dev/null 2>&1 &')

    if traffic_type == 'http' or traffic_type == 'mixed':
        # HTTP traffic (using python http.server)
        info('Generating HTTP traffic...\n')
        if len(hosts) >= 4:
            # Start HTTP servers on multiple hosts
            hosts[0].cmd('python3 -m http.server 8000 > /dev/null 2>&1 &')
            hosts[1].cmd('python3 -m http.server 8001 > /dev/null 2>&1 &')
            time.sleep(3)
            # Continuous HTTP requests from other hosts
            for i in range(2, min(6, len(hosts))):
                # Loop: make HTTP requests every 2 seconds
                hosts[i].cmd(f'while true; do wget -q -O /dev/null http://{hosts[0].IP()}:8000/ 2>/dev/null; sleep 2; done &')
                hosts[i].cmd(f'while true; do wget -q -O /dev/null http://{hosts[1].IP()}:8001/ 2>/dev/null; sleep 3; done &')

    if traffic_type == 'ftp' or traffic_type == 'mixed':
        # FTP-like traffic (using nc with data transfer)
        info('Generating FTP-like traffic...\n')
        if len(hosts) >= 3:
            # Create a test file and transfer it continuously
            hosts[0].cmd('dd if=/dev/urandom of=/tmp/testfile bs=1024 count=100 2>/dev/null')
            # Start FTP-like server (port 21)
            hosts[0].cmd('while true; do nc -l -p 21 < /tmp/testfile; done > /dev/null 2>&1 &')
            time.sleep(1)
            # Client connects and receives data repeatedly
            hosts[2].cmd(f'while true; do nc {hosts[0].IP()} 21 > /dev/null; sleep 3; done 2>/dev/null &')

    if traffic_type == 'ssh' or traffic_type == 'mixed':
        # SSH-like traffic (port 22 with data exchange)
        info('Generating SSH-like traffic...\n')
        if len(hosts) >= 3:
            # Create SSH-like traffic with bidirectional data transfer
            hosts[1].cmd('dd if=/dev/urandom of=/tmp/sshdata bs=512 count=50 2>/dev/null')
            hosts[1].cmd('while true; do nc -l -p 22 < /tmp/sshdata; done > /dev/null 2>&1 &')
            time.sleep(1)
            hosts[3 if len(hosts) > 3 else 2].cmd(f'while true; do nc {hosts[1].IP()} 22 > /dev/null; sleep 4; done 2>/dev/null &')

    if traffic_type == 'iperf' or traffic_type == 'mixed':
        # UDP/TCP bandwidth test - continuous
        info('Generating iPerf traffic...\n')
        if len(hosts) >= 2:
            # UDP traffic
            hosts[0].cmd('iperf -s -u > /dev/null 2>&1 &')
            time.sleep(1)
            hosts[1].cmd(f'iperf -c {hosts[0].IP()} -u -t 3600 -i 10 > /dev/null 2>&1 &')

            # TCP traffic
            hosts[2 if len(hosts) > 2 else 1].cmd('iperf -s -p 5002 > /dev/null 2>&1 &')
            time.sleep(1)
            hosts[3 if len(hosts) > 3 else 0].cmd(f'iperf -c {hosts[2 if len(hosts) > 2 else 1].IP()} -p 5002 -t 3600 > /dev/null 2>&1 &')

    info('*** Traffic generation started (continuous mode)\n')
    info('*** Traffic will run until network is stopped\n')


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
                       choices=['custom', 'linear', 'star'],
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

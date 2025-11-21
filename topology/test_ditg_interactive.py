#!/usr/bin/env python3
"""
Interactive D-ITG test to diagnose why traffic isn't flowing
"""

from mininet.net import Mininet
from mininet.node import OVSKernelSwitch, RemoteController
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.log import setLogLevel, info
import time

def test_ditg():
    """Test D-ITG with simple 2-host topology"""

    info('*** Creating network\n')
    net = Mininet(controller=RemoteController, switch=OVSKernelSwitch, link=TCLink)

    info('*** Adding controller\n')
    c0 = net.addController('c0', controller=RemoteController, ip='127.0.0.1', port=6633)

    info('*** Adding hosts\n')
    h1 = net.addHost('h1', ip='10.0.0.1/24')
    h2 = net.addHost('h2', ip='10.0.0.2/24')

    info('*** Adding switch\n')
    s1 = net.addSwitch('s1')

    info('*** Creating links\n')
    net.addLink(h1, s1, bw=10)
    net.addLink(h2, s1, bw=10)

    info('*** Starting network\n')
    net.start()

    info('\n' + '='*80 + '\n')
    info('*** Network ready! Testing D-ITG...\n')
    info('='*80 + '\n\n')

    # Test 1: Basic connectivity
    info('Test 1: Basic connectivity (ping)\n')
    h1.cmd('ping -c 3 10.0.0.2')

    info('\nTest 2: Start ITGRecv on h2\n')
    info('Command: h2 ITGRecv -l /tmp/recv_test.log &\n')
    h2.cmd('ITGRecv -l /tmp/recv_test.log > /tmp/recv_stdout.log 2>&1 &')
    time.sleep(2)

    # Check if ITGRecv is running
    info('Checking if ITGRecv is running...\n')
    recv_ps = h2.cmd('ps aux | grep ITGRecv | grep -v grep')
    info(f'ITGRecv process: {recv_ps}\n')

    # Check listening ports
    info('Checking listening ports on h2...\n')
    ports = h2.cmd('netstat -tuln | grep 8999 || netstat -tuln | grep 9000')
    info(f'Listening ports: {ports}\n')

    info('\nTest 3: Start ITGSend on h1\n')
    info('Command: h1 ITGSend -a 10.0.0.2 -t 10000 -C 100 -c 500 -T TCP -l /tmp/send_test.log\n')

    # Run ITGSend in foreground to see output
    info('Running ITGSend (will take 10 seconds)...\n')
    send_output = h1.cmd('ITGSend -a 10.0.0.2 -t 10000 -C 100 -c 500 -T TCP -l /tmp/send_test.log 2>&1')
    info(f'ITGSend output:\n{send_output}\n')

    info('\nTest 4: Check logs\n')
    info('Send log size: ')
    h1.cmd('ls -lh /tmp/send_test.log 2>&1')
    info('Recv log size: ')
    h2.cmd('ls -lh /tmp/recv_test.log 2>&1')

    info('\nSend log first 10 lines:\n')
    send_log = h1.cmd('head -10 /tmp/send_test.log 2>&1')
    info(f'{send_log}\n')

    info('Recv log first 10 lines:\n')
    recv_log = h2.cmd('head -10 /tmp/recv_test.log 2>&1')
    info(f'{recv_log}\n')

    info('\n' + '='*80 + '\n')
    info('*** D-ITG Test Complete!\n')
    info('*** Starting Mininet CLI for manual testing...\n')
    info('*** Try: h1 ITGSend -a 10.0.0.2 -t 5000 -C 50 -c 100 -T TCP\n')
    info('='*80 + '\n\n')

    CLI(net)

    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_ditg()

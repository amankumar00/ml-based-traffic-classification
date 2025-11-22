#!/usr/bin/env python3
"""
Realistic Traffic Generator for FPLF Testing

Generates REALISTIC, VARIABLE traffic patterns that create dynamic graphs:
- Bursty VIDEO traffic (simulates video streaming with I-frames, P-frames)
- Intermittent SSH traffic (simulates interactive sessions with pauses)
- Variable HTTP traffic (simulates web browsing with request/response cycles)
- Periodic FTP traffic (simulates file transfers with pauses)

This creates REALISTIC graphs with fluctuations, NOT flat lines!
"""

import time
import random
import threading
from mininet.log import info

class RealisticTrafficGenerator:
    """Generate realistic, variable-rate traffic for all 4 types"""

    def __init__(self, net, duration=60):
        self.net = net
        self.duration = duration
        self.running = True
        self.threads = []

    def generate_video_traffic(self, src, dst, port=5004):
        """
        VIDEO: Bursty traffic simulating video streaming
        - High bitrate bursts (I-frames every 2-3 seconds)
        - Lower bitrate between bursts (P-frames)
        - Creates oscillating bandwidth pattern
        """
        info(f'  Starting VIDEO traffic: {src.name} -> {dst.name}:{port} (bursty pattern)\n')

        start_time = time.time()
        while self.running and (time.time() - start_time) < self.duration:
            # I-frame burst: 10 Mbps for 0.5 seconds (background process)
            src.cmd(f'iperf -c {dst.IP()} -p {port} -b 10M -t 0.5 > /dev/null 2>&1 &')
            time.sleep(0.6)  # Wait slightly longer for burst to complete

            # P-frames: 2 Mbps for 1.5 seconds (background process)
            src.cmd(f'iperf -c {dst.IP()} -p {port} -b 2M -t 1.5 > /dev/null 2>&1 &')
            time.sleep(1.6)  # Wait slightly longer

            # COMPLETE SILENCE (no traffic): 1-3 seconds
            pause = random.uniform(1.0, 3.0)
            time.sleep(pause)

    def generate_ssh_traffic(self, src, dst, port=22):
        """
        SSH: Intermittent traffic simulating interactive terminal sessions
        - Short bursts when user types
        - Long pauses between bursts
        - Very realistic human interaction pattern
        """
        info(f'  Starting SSH traffic: {src.name} -> {dst.name}:{port} (interactive pattern)\n')

        start_time = time.time()
        while self.running and (time.time() - start_time) < self.duration:
            # Short burst (typing command): 500 Kbps for 0.2 seconds (background)
            src.cmd(f'iperf -c {dst.IP()} -p {port} -b 500K -t 0.2 > /dev/null 2>&1 &')
            time.sleep(0.3)

            # COMPLETE SILENCE (user thinking/reading): 3-7 seconds
            pause = random.uniform(3.0, 7.0)
            time.sleep(pause)

            # Response burst: 1 Mbps for 0.5 seconds (background)
            src.cmd(f'iperf -c {dst.IP()} -p {port} -b 1M -t 0.5 > /dev/null 2>&1 &')
            time.sleep(0.6)

            # Another COMPLETE SILENCE: 2-5 seconds
            pause = random.uniform(2.0, 5.0)
            time.sleep(pause)

    def generate_http_traffic(self, src, dst, port=80):
        """
        HTTP: Request/response cycles simulating web browsing
        - Short request burst
        - Large response burst
        - Pause between page loads
        - Variable page sizes
        """
        info(f'  Starting HTTP traffic: {src.name} -> {dst.name}:{port} (request/response pattern)\n')

        start_time = time.time()
        while self.running and (time.time() - start_time) < self.duration:
            # HTTP request: 100 Kbps for 0.1 seconds (background)
            src.cmd(f'iperf -c {dst.IP()} -p {port} -b 100K -t 0.1 > /dev/null 2>&1 &')
            time.sleep(0.2)

            # HTTP response: Variable size (1-8 Mbps) for 0.5-2 seconds (background)
            response_rate = random.randint(1, 8)
            response_time = random.uniform(0.5, 2.0)
            src.cmd(f'iperf -c {dst.IP()} -p {port} -b {response_rate}M -t {response_time} > /dev/null 2>&1 &')
            time.sleep(response_time + 0.1)

            # COMPLETE SILENCE (user reading page): 2-6 seconds
            pause = random.uniform(2.0, 6.0)
            time.sleep(pause)

    def generate_ftp_traffic(self, src, dst, port=21):
        """
        FTP: Periodic file transfers with pauses
        - Large burst (file transfer)
        - Long pause (idle)
        - Variable transfer rates
        """
        info(f'  Starting FTP traffic: {src.name} -> {dst.name}:{port} (bulk transfer pattern)\n')

        start_time = time.time()
        while self.running and (time.time() - start_time) < self.duration:
            # File transfer: 5-15 Mbps for 3-8 seconds (background)
            transfer_rate = random.randint(5, 15)
            transfer_time = random.uniform(3.0, 8.0)
            src.cmd(f'iperf -c {dst.IP()} -p {port} -b {transfer_rate}M -t {transfer_time} > /dev/null 2>&1 &')
            time.sleep(transfer_time + 0.5)

            # COMPLETE SILENCE (idle period): 4-10 seconds
            pause = random.uniform(4.0, 10.0)
            time.sleep(pause)

    def start_all_traffic(self):
        """Start all 4 traffic types in parallel threads"""
        info('\n' + '='*80 + '\n')
        info('*** REALISTIC VARIABLE TRAFFIC GENERATION\n')
        info('='*80 + '\n')
        info('Starting realistic, variable-rate traffic for all 4 types:\n')
        info('  VIDEO: Bursty (I-frames + P-frames) - creates oscillating pattern\n')
        info('  SSH:   Intermittent (interactive session) - bursts with long pauses\n')
        info('  HTTP:  Request/response cycles - variable page loads\n')
        info('  FTP:   Periodic transfers - large bursts with idle periods\n')
        info('\n')
        info('Expected graph behavior:\n')
        info('  ✓ Active links: FLUCTUATING (not flat!)\n')
        info('  ✓ Power consumption: VARIABLE over time\n')
        info('  ✓ Energy savings: DYNAMIC (changes as traffic varies)\n')
        info('='*80 + '\n\n')

        # Get hosts
        h1 = self.net.get('h1')
        h2 = self.net.get('h2')
        h3 = self.net.get('h3')
        h4 = self.net.get('h4')
        h5 = self.net.get('h5')
        h7 = self.net.get('h7')
        h8 = self.net.get('h8')
        h9 = self.net.get('h9')

        # Start iperf servers
        info('*** Starting iperf servers\n')
        h7.cmd('iperf -s -p 5004 > /dev/null 2>&1 &')
        h5.cmd('iperf -s -p 22 > /dev/null 2>&1 &')
        h8.cmd('iperf -s -p 80 > /dev/null 2>&1 &')
        h9.cmd('iperf -s -p 21 > /dev/null 2>&1 &')
        time.sleep(2)

        info('\n*** Starting realistic traffic generators\n')

        # Create threads for each traffic type
        video_thread = threading.Thread(target=self.generate_video_traffic, args=(h1, h7, 5004))
        ssh_thread = threading.Thread(target=self.generate_ssh_traffic, args=(h3, h5, 22))
        http_thread = threading.Thread(target=self.generate_http_traffic, args=(h2, h8, 80))
        ftp_thread = threading.Thread(target=self.generate_ftp_traffic, args=(h4, h9, 21))

        # Start all threads
        video_thread.start()
        ssh_thread.start()
        http_thread.start()
        ftp_thread.start()

        self.threads = [video_thread, ssh_thread, http_thread, ftp_thread]

        info(f'\n*** All traffic generators running for {self.duration} seconds...\n')
        info('*** Observe DYNAMIC behavior in controller logs and graphs!\n\n')

        # Wait for duration
        time.sleep(self.duration)

        # Stop all traffic
        self.stop()

    def stop(self):
        """Stop all traffic generators"""
        info('\n*** Stopping traffic generators...\n')
        self.running = False

        # Wait for all threads to finish
        for thread in self.threads:
            thread.join(timeout=2)

        info('*** Traffic generation complete\n')


def generate_realistic_traffic(net, duration=60):
    """
    Main entry point for realistic traffic generation

    This function can be called from test_7switch_core_topo.py
    """
    generator = RealisticTrafficGenerator(net, duration)
    generator.start_all_traffic()


if __name__ == '__main__':
    print("This module should be imported and used with Mininet")
    print("Example usage:")
    print("  from realistic_traffic_generator import generate_realistic_traffic")
    print("  generate_realistic_traffic(net, duration=60)")

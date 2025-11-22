#!/usr/bin/env python3
"""
Periodic Flow Table Clearer

Runs in background and periodically clears OpenFlow flow tables
to force flows to be re-routed, creating dynamic energy consumption patterns.

This simulates the effect of:
- Network changes (link failures/recovery)
- Load balancing decisions
- Route optimization

Without this, continuous iperf streams maintain persistent flows,
resulting in flat energy consumption graphs.
"""

import time
import subprocess
import sys

def clear_flow_tables(switch_ids, interval=10):
    """
    Periodically clear flow tables on specified switches

    Args:
        switch_ids: List of switch DPIDs (e.g., [1, 2, 3, 4, 5, 6, 7])
        interval: Seconds between clears (default: 10)
    """
    print(f"Starting periodic flow table clearer (interval={interval}s)")
    print(f"Target switches: {switch_ids}")
    print("")

    iteration = 0
    try:
        while True:
            time.sleep(interval)
            iteration += 1

            print(f"[Iteration {iteration}] Clearing flow tables at t={iteration * interval}s...")

            for dpid in switch_ids:
                switch_name = f"s{dpid}"
                try:
                    # Clear ALL flows except high-priority control flows (LLDP, ARP)
                    # Priority 10 flows are data flows installed by controller
                    cmd = f"ovs-ofctl del-flows {switch_name} 'priority=10,hard_timeout=0,idle_timeout=10'"
                    subprocess.run(cmd, shell=True, check=False,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

                    # Also clear any remaining priority=10 flows
                    cmd2 = f"ovs-ofctl del-flows {switch_name} 'priority=10'"
                    subprocess.run(cmd2, shell=True, check=False,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    print(f"  ✓ Cleared s{dpid}")
                except Exception as e:
                    print(f"  ✗ Failed to clear s{dpid}: {e}")

            print(f"  → Flows cleared! Controller will re-route all traffic.")
            print("")

    except KeyboardInterrupt:
        print("\nFlow clearer stopped.")
        sys.exit(0)

if __name__ == '__main__':
    # 7-switch topology
    switches = [1, 2, 3, 4, 5, 6, 7]

    # Clear flows every 10 seconds to force dynamic rerouting
    clear_flow_tables(switches, interval=10)

"""
Energy Consumption Monitoring Module for FPLF Controller

Calculates energy consumption based on active/idle link counts
Following methodology from:
"An Adaptive Routing Framework for Efficient Power Consumption in
Software-Defined Datacenter Networks" (Electronics 2021, 10, 3027)

Power Model (based on Kaup et al. 2014 - Reference [29] in paper):
- Active OpenFlow port: ~5.0 Watts
- Idle OpenFlow port: ~2.0 Watts (port on but no traffic)
- Port completely off: ~0.5 Watts (theoretical, not used in practice)

Energy savings = (Baseline Power - FPLF Power) / Baseline Power × 100%
where Baseline = all links active all the time
"""

import csv
import os
import time
from datetime import datetime


class EnergyMonitor:
    """
    Monitor and calculate energy consumption for FPLF routing

    Tracks active vs idle links and estimates power consumption
    compared to baseline (all-links-active) approach
    """

    # Power consumption constants (Watts) - from research literature
    POWER_ACTIVE_PORT = 5.0   # Active port transmitting data
    POWER_IDLE_PORT = 2.0     # Idle port (on but no traffic)
    POWER_OFF_PORT = 0.5      # Port powered off (theoretical)

    def __init__(self, data_dir='data/fplf_monitoring'):
        """
        Initialize energy monitor

        Args:
            data_dir: Directory to store energy consumption CSV
        """
        self.data_dir = data_dir
        os.makedirs(self.data_dir, exist_ok=True)

        # CSV file for energy data
        self.energy_csv = os.path.join(self.data_dir, 'energy_consumption.csv')

        # Energy log (in-memory before periodic CSV write)
        self.energy_log = []

        # Statistics
        self.total_measurements = 0
        self.cumulative_savings_wh = 0.0  # Watt-hours saved

        # Initialize CSV file
        self._init_csv()

    def _init_csv(self):
        """Initialize energy CSV file with headers"""
        with open(self.energy_csv, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([
                'timestamp',
                'datetime',
                'active_links',
                'idle_links',
                'total_links',
                'active_link_percent',
                'fplf_power_watts',
                'baseline_power_watts',
                'energy_saved_watts',
                'energy_saved_percent',
                'cumulative_savings_wh'
            ])

    def calculate_energy(self, active_links, total_links):
        """
        Calculate current energy consumption and savings

        Args:
            active_links: Number of links currently carrying traffic (utilization > 0)
            total_links: Total number of links in topology

        Returns:
            dict with energy metrics:
                - active_links: number of active links
                - idle_links: number of idle links
                - total_links: total links
                - active_link_percent: percentage of links active
                - fplf_power: current power consumption (Watts)
                - baseline_power: baseline power if all links active (Watts)
                - savings_watts: power saved vs baseline (Watts)
                - savings_percent: percentage energy savings
                - cumulative_savings_wh: total energy saved (Watt-hours)
        """
        # Calculate link distribution
        idle_links = total_links - active_links
        active_percent = (active_links / total_links * 100) if total_links > 0 else 0

        # Power consumption with FPLF (active + idle)
        fplf_power = (active_links * self.POWER_ACTIVE_PORT +
                     idle_links * self.POWER_IDLE_PORT)

        # Baseline: all links active all the time
        baseline_power = total_links * self.POWER_ACTIVE_PORT

        # Energy savings
        savings_watts = baseline_power - fplf_power
        savings_percent = (savings_watts / baseline_power * 100) if baseline_power > 0 else 0

        # Cumulative savings (Watt-hours)
        # Assuming 1-second measurement intervals
        self.cumulative_savings_wh += savings_watts / 3600.0  # Convert W to Wh
        self.total_measurements += 1

        return {
            'timestamp': time.time(),
            'datetime': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'active_links': active_links,
            'idle_links': idle_links,
            'total_links': total_links,
            'active_link_percent': active_percent,
            'fplf_power': fplf_power,
            'baseline_power': baseline_power,
            'savings_watts': savings_watts,
            'savings_percent': savings_percent,
            'cumulative_savings_wh': self.cumulative_savings_wh
        }

    def log_energy_data(self, active_links, total_links):
        """
        Calculate and log energy data to in-memory buffer

        Args:
            active_links: Number of currently active links
            total_links: Total number of links in topology
        """
        energy_data = self.calculate_energy(active_links, total_links)
        self.energy_log.append(energy_data)

    def export_to_csv(self):
        """Export buffered energy log to CSV file"""
        if not self.energy_log:
            return

        # Append to CSV
        with open(self.energy_csv, 'a', newline='') as f:
            writer = csv.writer(f)
            for entry in self.energy_log:
                writer.writerow([
                    entry['timestamp'],
                    entry['datetime'],
                    entry['active_links'],
                    entry['idle_links'],
                    entry['total_links'],
                    f"{entry['active_link_percent']:.2f}",
                    f"{entry['fplf_power']:.2f}",
                    f"{entry['baseline_power']:.2f}",
                    f"{entry['savings_watts']:.2f}",
                    f"{entry['savings_percent']:.2f}",
                    f"{entry['cumulative_savings_wh']:.6f}"
                ])

        # Clear buffer after export
        self.energy_log.clear()

    def get_summary_statistics(self):
        """
        Get summary statistics about energy consumption

        Returns:
            dict with summary statistics
        """
        if not self.energy_log:
            return None

        # Calculate averages
        avg_active = sum(e['active_links'] for e in self.energy_log) / len(self.energy_log)
        avg_power = sum(e['fplf_power'] for e in self.energy_log) / len(self.energy_log)
        avg_baseline = sum(e['baseline_power'] for e in self.energy_log) / len(self.energy_log)
        avg_savings_percent = sum(e['savings_percent'] for e in self.energy_log) / len(self.energy_log)

        max_savings = max(e['savings_percent'] for e in self.energy_log)
        min_savings = min(e['savings_percent'] for e in self.energy_log)

        total_links = self.energy_log[0]['total_links'] if self.energy_log else 0

        return {
            'total_measurements': self.total_measurements,
            'total_links': total_links,
            'avg_active_links': avg_active,
            'avg_fplf_power_watts': avg_power,
            'avg_baseline_power_watts': avg_baseline,
            'avg_energy_savings_percent': avg_savings_percent,
            'max_energy_savings_percent': max_savings,
            'min_energy_savings_percent': min_savings,
            'cumulative_savings_wh': self.cumulative_savings_wh,
            'cumulative_savings_kwh': self.cumulative_savings_wh / 1000.0
        }

    def print_summary(self):
        """Print energy consumption summary to console"""
        summary = self.get_summary_statistics()

        if not summary:
            print("No energy data collected yet")
            return

        print("\n" + "="*70)
        print(" ENERGY EFFICIENCY SUMMARY (vs All-Links-Active Baseline)")
        print("="*70)
        print(f"Total Measurements:        {summary['total_measurements']}")
        print(f"Total Links in Topology:   {summary['total_links']}")
        print(f"Average Active Links:      {summary['avg_active_links']:.1f}/{summary['total_links']}")
        print(f"Average Link Utilization:  {summary['avg_active_links']/summary['total_links']*100:.1f}%")
        print("-"*70)
        print(f"FPLF Power (avg):          {summary['avg_fplf_power_watts']:.2f} W")
        print(f"Baseline Power (avg):      {summary['avg_baseline_power_watts']:.2f} W")
        print(f"Power Saved (avg):         {summary['avg_baseline_power_watts'] - summary['avg_fplf_power_watts']:.2f} W")
        print("-"*70)
        print(f"Energy Savings (avg):      {summary['avg_energy_savings_percent']:.2f}%")
        print(f"Energy Savings (max):      {summary['max_energy_savings_percent']:.2f}%")
        print(f"Energy Savings (min):      {summary['min_energy_savings_percent']:.2f}%")
        print("-"*70)
        print(f"Cumulative Energy Saved:   {summary['cumulative_savings_wh']:.4f} Wh")
        print(f"                          ({summary['cumulative_savings_kwh']:.6f} kWh)")
        print("="*70)
        print(f"Energy data exported to: {self.energy_csv}")
        print("="*70 + "\n")
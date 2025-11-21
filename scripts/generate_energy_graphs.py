#!/usr/bin/env python3
"""
Generate Energy Consumption Graphs (Paper-Style)

Creates visualizations matching the paper:
"An Adaptive Routing Framework for Efficient Power Consumption
 in Software-Defined Datacenter Networks" (Electronics 2021)

Generates:
1. Active Links Over Time
2. Power Consumption Over Time
3. Energy Savings Comparison
4. Summary Statistics Table
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os
import sys

# Style configuration (academic paper style)
plt.style.use('seaborn-v0_8-paper')
plt.rcParams['figure.figsize'] = (10, 6)
plt.rcParams['font.size'] = 12
plt.rcParams['lines.linewidth'] = 2

def load_energy_data(csv_path):
    """Load energy consumption CSV"""
    if not os.path.exists(csv_path):
        print(f"Error: {csv_path} not found!")
        print("Please run: sudo bash scripts/test_route_changes.sh")
        sys.exit(1)

    df = pd.read_csv(csv_path)

    # Check if CSV has data (not just headers)
    if len(df) == 0:
        print(f"Error: {csv_path} is empty (only headers)!")
        print("This means topology wasn't fully discovered during the test.")
        print("Try running the test again: sudo bash scripts/test_route_changes.sh")
        sys.exit(1)

    # Convert timestamp to relative seconds
    df['time_seconds'] = df['timestamp'] - df['timestamp'].iloc[0]

    return df

def plot_active_links_over_time(df, output_path):
    """
    Graph 1: Number of Active Links Over Time
    Similar to Figure 5 in the paper
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot active links
    ax.plot(df['time_seconds'], df['active_links'],
            label='FPLF Active Links', color='#2E86AB', linewidth=2)

    # Plot total links as horizontal line (baseline)
    total = df['total_links'].iloc[0]
    ax.axhline(y=total, color='#A23B72', linestyle='--',
               label=f'Total Available Links ({total})', linewidth=2)

    # Formatting
    ax.set_xlabel('Time (seconds)', fontsize=14, fontweight='bold')
    ax.set_ylabel('Number of Active Links', fontsize=14, fontweight='bold')
    ax.set_title('FPLF Adaptive Link Usage Over Time',
                 fontsize=16, fontweight='bold', pad=20)
    ax.legend(loc='upper right', fontsize=12, frameon=True, shadow=True)
    ax.grid(True, alpha=0.3, linestyle=':')

    # Add statistics text box
    avg_active = df['active_links'].mean()
    min_active = df['active_links'].min()
    max_active = df['active_links'].max()

    stats_text = f"Avg Active: {avg_active:.1f}/{total}\n"
    stats_text += f"Range: {min_active}-{max_active}\n"
    stats_text += f"Utilization: {avg_active/total*100:.1f}%"

    ax.text(0.02, 0.98, stats_text, transform=ax.transAxes,
            fontsize=11, verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Generated: {output_path}")
    plt.close()

def plot_power_consumption_over_time(df, output_path):
    """
    Graph 2: Power Consumption Over Time
    FPLF vs Baseline comparison
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot power consumption
    ax.plot(df['time_seconds'], df['fplf_power_watts'],
            label='FPLF Power Consumption', color='#06A77D', linewidth=2.5)
    ax.plot(df['time_seconds'], df['baseline_power_watts'],
            label='Baseline (All Links Active)', color='#D62246',
            linewidth=2, linestyle='--')

    # Fill area between curves (savings)
    ax.fill_between(df['time_seconds'],
                     df['fplf_power_watts'],
                     df['baseline_power_watts'],
                     alpha=0.3, color='#06A77D', label='Energy Saved')

    # Formatting
    ax.set_xlabel('Time (seconds)', fontsize=14, fontweight='bold')
    ax.set_ylabel('Power Consumption (Watts)', fontsize=14, fontweight='bold')
    ax.set_title('Power Consumption: FPLF vs Baseline',
                 fontsize=16, fontweight='bold', pad=20)
    ax.legend(loc='upper right', fontsize=12, frameon=True, shadow=True)
    ax.grid(True, alpha=0.3, linestyle=':')

    # Add average power statistics
    avg_fplf = df['fplf_power_watts'].mean()
    avg_baseline = df['baseline_power_watts'].mean()
    avg_savings = avg_baseline - avg_fplf

    stats_text = f"FPLF (avg): {avg_fplf:.1f} W\n"
    stats_text += f"Baseline (avg): {avg_baseline:.1f} W\n"
    stats_text += f"Savings (avg): {avg_savings:.1f} W ({avg_savings/avg_baseline*100:.1f}%)"

    ax.text(0.02, 0.98, stats_text, transform=ax.transAxes,
            fontsize=11, verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.5))

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Generated: {output_path}")
    plt.close()

def plot_energy_savings_percentage(df, output_path):
    """
    Graph 3: Energy Savings Percentage Over Time
    Shows how savings varies with traffic load
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    # Plot savings percentage
    ax.plot(df['time_seconds'], df['energy_saved_percent'],
            label='Energy Savings', color='#F18F01', linewidth=2.5)

    # Add horizontal line at average
    avg_savings = df['energy_saved_percent'].mean()
    ax.axhline(y=avg_savings, color='#C73E1D', linestyle=':',
               label=f'Average Savings ({avg_savings:.1f}%)', linewidth=2)

    # Formatting
    ax.set_xlabel('Time (seconds)', fontsize=14, fontweight='bold')
    ax.set_ylabel('Energy Savings (%)', fontsize=14, fontweight='bold')
    ax.set_title('FPLF Energy Savings vs All-Links-Active Baseline',
                 fontsize=16, fontweight='bold', pad=20)
    ax.legend(loc='upper right', fontsize=12, frameon=True, shadow=True)
    ax.grid(True, alpha=0.3, linestyle=':')
    ax.set_ylim(0, max(df['energy_saved_percent']) * 1.1)

    # Add min/max markers
    max_idx = df['energy_saved_percent'].idxmax()
    min_idx = df['energy_saved_percent'].idxmin()

    ax.plot(df.loc[max_idx, 'time_seconds'], df.loc[max_idx, 'energy_saved_percent'],
            'go', markersize=10, label=f"Max ({df.loc[max_idx, 'energy_saved_percent']:.1f}%)")
    ax.plot(df.loc[min_idx, 'time_seconds'], df.loc[min_idx, 'energy_saved_percent'],
            'ro', markersize=10, label=f"Min ({df.loc[min_idx, 'energy_saved_percent']:.1f}%)")

    ax.legend(loc='upper right', fontsize=11, frameon=True, shadow=True)

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Generated: {output_path}")
    plt.close()

def plot_link_utilization_distribution(df, output_path):
    """
    Graph 4: Distribution of Active Links
    Histogram showing how often different numbers of links are active
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    # Histogram
    bins = range(int(df['active_links'].min()), int(df['active_links'].max()) + 2)
    ax.hist(df['active_links'], bins=bins, color='#4ECDC4',
            edgecolor='black', alpha=0.7)

    # Add vertical line at mean
    mean_active = df['active_links'].mean()
    ax.axvline(mean_active, color='red', linestyle='--', linewidth=2,
               label=f'Mean: {mean_active:.1f}')

    # Formatting
    ax.set_xlabel('Number of Active Links', fontsize=14, fontweight='bold')
    ax.set_ylabel('Frequency (seconds)', fontsize=14, fontweight='bold')
    ax.set_title('Distribution of Active Link Count',
                 fontsize=16, fontweight='bold', pad=20)
    ax.legend(fontsize=12, frameon=True, shadow=True)
    ax.grid(True, axis='y', alpha=0.3, linestyle=':')

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"✓ Generated: {output_path}")
    plt.close()

def generate_summary_table(df, output_path):
    """
    Generate summary statistics table (paper-style)
    """
    summary = {
        'Metric': [
            'Total Measurements',
            'Duration (seconds)',
            'Total Links in Topology',
            '---',
            'Active Links (avg)',
            'Active Links (min)',
            'Active Links (max)',
            'Link Utilization (avg %)',
            '---',
            'FPLF Power (avg, W)',
            'Baseline Power (avg, W)',
            'Power Saved (avg, W)',
            '---',
            'Energy Savings (avg %)',
            'Energy Savings (max %)',
            'Energy Savings (min %)',
            '---',
            'Cumulative Energy Saved (Wh)',
            'Cumulative Energy Saved (kWh)',
        ],
        'Value': [
            f"{len(df)}",
            f"{df['time_seconds'].max():.1f}",
            f"{df['total_links'].iloc[0]}",
            '',
            f"{df['active_links'].mean():.2f}",
            f"{df['active_links'].min()}",
            f"{df['active_links'].max()}",
            f"{df['active_link_percent'].mean():.2f}",
            '',
            f"{df['fplf_power_watts'].mean():.2f}",
            f"{df['baseline_power_watts'].mean():.2f}",
            f"{(df['baseline_power_watts'] - df['fplf_power_watts']).mean():.2f}",
            '',
            f"{df['energy_saved_percent'].mean():.2f}",
            f"{df['energy_saved_percent'].max():.2f}",
            f"{df['energy_saved_percent'].min():.2f}",
            '',
            f"{df['cumulative_savings_wh'].iloc[-1]:.4f}",
            f"{df['cumulative_savings_wh'].iloc[-1] / 1000:.6f}",
        ]
    }

    summary_df = pd.DataFrame(summary)

    # Save to CSV
    summary_df.to_csv(output_path, index=False)
    print(f"✓ Generated: {output_path}")

    # Print to console
    print("\n" + "="*70)
    print(" ENERGY EFFICIENCY SUMMARY")
    print("="*70)
    for _, row in summary_df.iterrows():
        if row['Metric'] == '---':
            print("-"*70)
        else:
            print(f"{row['Metric']:.<50} {row['Value']:>18}")
    print("="*70 + "\n")

def main():
    """Main execution"""
    print("\n" + "="*70)
    print(" Energy Consumption Graph Generator (Paper-Style)")
    print("="*70 + "\n")

    # Paths
    csv_path = 'data/fplf_monitoring/energy_consumption.csv'
    output_dir = 'data/fplf_monitoring/graphs'
    os.makedirs(output_dir, exist_ok=True)

    # Load data
    print(f"Loading data from: {csv_path}")
    df = load_energy_data(csv_path)
    print(f"✓ Loaded {len(df)} measurements ({df['time_seconds'].max():.1f} seconds)\n")

    # Generate graphs
    print("Generating graphs...")
    plot_active_links_over_time(df, os.path.join(output_dir, 'active_links_over_time.png'))
    plot_power_consumption_over_time(df, os.path.join(output_dir, 'power_consumption.png'))
    plot_energy_savings_percentage(df, os.path.join(output_dir, 'energy_savings_percent.png'))
    plot_link_utilization_distribution(df, os.path.join(output_dir, 'link_distribution.png'))

    # Generate summary table
    print("\nGenerating summary statistics...")
    generate_summary_table(df, os.path.join(output_dir, 'summary_statistics.csv'))

    print("\n" + "="*70)
    print(" COMPLETE!")
    print("="*70)
    print(f"\nAll graphs saved to: {output_dir}/")
    print("\nGenerated files:")
    print("  - active_links_over_time.png")
    print("  - power_consumption.png")
    print("  - energy_savings_percent.png")
    print("  - link_distribution.png")
    print("  - summary_statistics.csv")
    print("="*70 + "\n")

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

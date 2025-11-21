#!/usr/bin/env python3
"""
Quick test script for Energy Monitor module
Verifies that energy calculations are correct
"""

import sys
import os

# Add src/controller to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src/controller'))

from energy_monitor import EnergyMonitor
import time

def test_energy_calculations():
    """Test energy monitor calculations"""

    print("="*70)
    print(" Energy Monitor Module Test")
    print("="*70)

    # Create energy monitor with test directory
    test_dir = 'data/test_energy'
    os.makedirs(test_dir, exist_ok=True)

    monitor = EnergyMonitor(data_dir=test_dir)

    print("\nTest 1: Low traffic scenario (10 active links out of 32)")
    print("-"*70)
    energy_data = monitor.calculate_energy(active_links=10, total_links=32)

    print(f"Active Links: {energy_data['active_links']}/{energy_data['total_links']}")
    print(f"Active Percentage: {energy_data['active_link_percent']:.2f}%")
    print(f"FPLF Power: {energy_data['fplf_power']:.2f} W")
    print(f"Baseline Power: {energy_data['baseline_power']:.2f} W")
    print(f"Energy Saved: {energy_data['savings_watts']:.2f} W ({energy_data['savings_percent']:.2f}%)")

    # Verify calculation
    expected_fplf = 10 * 5.0 + 22 * 2.0  # 50 + 44 = 94 W
    expected_baseline = 32 * 5.0  # 160 W
    expected_savings = expected_baseline - expected_fplf  # 66 W
    expected_percent = (expected_savings / expected_baseline) * 100  # 41.25%

    assert abs(energy_data['fplf_power'] - expected_fplf) < 0.01, "FPLF power calculation error"
    assert abs(energy_data['baseline_power'] - expected_baseline) < 0.01, "Baseline power error"
    assert abs(energy_data['savings_percent'] - expected_percent) < 0.01, "Savings percent error"

    print("✓ Calculations verified!")

    print("\nTest 2: High traffic scenario (27 active links out of 32)")
    print("-"*70)
    energy_data = monitor.calculate_energy(active_links=27, total_links=32)

    print(f"Active Links: {energy_data['active_links']}/{energy_data['total_links']}")
    print(f"Active Percentage: {energy_data['active_link_percent']:.2f}%")
    print(f"FPLF Power: {energy_data['fplf_power']:.2f} W")
    print(f"Baseline Power: {energy_data['baseline_power']:.2f} W")
    print(f"Energy Saved: {energy_data['savings_watts']:.2f} W ({energy_data['savings_percent']:.2f}%)")

    # Verify calculation
    expected_fplf = 27 * 5.0 + 5 * 2.0  # 135 + 10 = 145 W
    expected_savings = 160 - 145  # 15 W
    expected_percent = (expected_savings / 160) * 100  # 9.375%

    assert abs(energy_data['fplf_power'] - expected_fplf) < 0.01, "FPLF power calculation error"
    assert abs(energy_data['savings_percent'] - expected_percent) < 0.01, "Savings percent error"

    print("✓ Calculations verified!")

    print("\nTest 3: Logging and CSV export")
    print("-"*70)

    # Simulate 10 seconds of monitoring
    for i in range(10):
        # Gradually increase active links (simulating traffic ramp-up)
        active = 10 + i
        monitor.log_energy_data(active, 32)
        time.sleep(0.1)  # Small delay

    # Export to CSV
    monitor.export_to_csv()

    csv_file = os.path.join(test_dir, 'energy_consumption.csv')

    if os.path.exists(csv_file):
        with open(csv_file, 'r') as f:
            lines = f.readlines()
            print(f"CSV file created: {csv_file}")
            print(f"Rows written: {len(lines) - 1} (excluding header)")
            print(f"Header: {lines[0].strip()}")
            print(f"Sample row: {lines[1].strip() if len(lines) > 1 else 'No data'}")
            print("✓ CSV export working!")
    else:
        print("✗ CSV file not created")
        return False

    print("\nTest 4: Summary statistics")
    print("-"*70)

    # Log more data for summary
    for i in range(20):
        active = 10 + (i % 10)
        monitor.log_energy_data(active, 32)

    summary = monitor.get_summary_statistics()

    print(f"Total Measurements: {summary['total_measurements']}")
    print(f"Average Active Links: {summary['avg_active_links']:.1f}/{summary['total_links']}")
    print(f"Average Energy Savings: {summary['avg_energy_savings_percent']:.2f}%")
    print(f"Max Savings: {summary['max_energy_savings_percent']:.2f}%")
    print(f"Min Savings: {summary['min_energy_savings_percent']:.2f}%")
    print(f"Cumulative Savings: {summary['cumulative_savings_wh']:.6f} Wh ({summary['cumulative_savings_kwh']:.9f} kWh)")
    print("✓ Summary statistics working!")

    print("\nTest 5: Print formatted summary")
    print("-"*70)
    monitor.print_summary()

    print("\n" + "="*70)
    print(" ALL TESTS PASSED!")
    print("="*70)
    print(f"\nTest data saved to: {test_dir}/")
    print("You can now run: sudo bash scripts/test_route_changes.sh")
    print("Energy monitoring will automatically run and save to:")
    print("  data/fplf_monitoring/energy_consumption.csv")
    print("="*70 + "\n")

    return True

if __name__ == '__main__':
    try:
        success = test_energy_calculations()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

"""
Verify ML-SDN setup and dependencies
Run this script to check if everything is installed correctly
"""

import sys
import os

def check_python_version():
    """Check Python version"""
    print("Checking Python version...")
    version = sys.version_info
    print(f"  Python {version.major}.{version.minor}.{version.micro}")

    if version.major < 3 or (version.major == 3 and version.minor < 8):
        print("  ❌ Python 3.8 or higher required")
        return False
    else:
        print("  ✓ Python version OK")
        return True


def check_dependencies():
    """Check if required packages are installed"""
    print("\nChecking dependencies...")

    required_packages = [
        'ryu', 'numpy', 'pandas', 'sklearn',
        'tensorflow', 'matplotlib', 'yaml'
    ]

    missing = []
    for package in required_packages:
        try:
            __import__(package)
            print(f"  ✓ {package}")
        except ImportError:
            print(f"  ❌ {package} - NOT FOUND")
            missing.append(package)

    if missing:
        print(f"\n  Missing packages: {', '.join(missing)}")
        print("  Run: pip install -r requirements.txt")
        return False

    print("  ✓ All dependencies installed")
    return True


def check_directories():
    """Check if required directories exist"""
    print("\nChecking directory structure...")

    required_dirs = [
        'src/controller',
        'src/ml_models',
        'src/traffic_monitor',
        'topology',
        'data/raw',
        'data/processed',
        'data/models',
        'config',
        'logs'
    ]

    project_root = os.path.join(os.path.dirname(__file__), '..')

    all_exist = True
    for dir_path in required_dirs:
        full_path = os.path.join(project_root, dir_path)
        if os.path.exists(full_path):
            print(f"  ✓ {dir_path}")
        else:
            print(f"  ❌ {dir_path} - NOT FOUND")
            all_exist = False

    if all_exist:
        print("  ✓ All directories exist")
    else:
        print("\n  Some directories are missing. Run quickstart.sh to set up.")

    return all_exist


def check_config():
    """Check if configuration file exists"""
    print("\nChecking configuration...")

    project_root = os.path.join(os.path.dirname(__file__), '..')
    config_path = os.path.join(project_root, 'config', 'config.yaml')

    if os.path.exists(config_path):
        print(f"  ✓ config.yaml found")
        return True
    else:
        print(f"  ❌ config.yaml NOT FOUND")
        return False


def check_scripts():
    """Check if main scripts are present"""
    print("\nChecking main scripts...")

    project_root = os.path.join(os.path.dirname(__file__), '..')

    scripts = {
        'SDN Controller': 'src/controller/sdn_controller.py',
        'Feature Extractor': 'src/traffic_monitor/feature_extractor.py',
        'Model Trainer': 'src/ml_models/train.py',
        'Classifier': 'src/ml_models/classifier.py',
        'Topology': 'topology/custom_topo.py'
    }

    all_exist = True
    for name, path in scripts.items():
        full_path = os.path.join(project_root, path)
        if os.path.exists(full_path):
            print(f"  ✓ {name}")
        else:
            print(f"  ❌ {name} - NOT FOUND")
            all_exist = False

    if all_exist:
        print("  ✓ All scripts present")

    return all_exist


def check_mininet():
    """Check if Mininet is installed"""
    print("\nChecking Mininet installation...")

    try:
        import mininet
        print("  ✓ Mininet installed")
        return True
    except ImportError:
        print("  ⚠ Mininet NOT installed")
        print("  Note: Mininet is required for network simulation")
        print("  Install with: sudo apt-get install mininet")
        return False


def main():
    """Run all checks"""
    print("=" * 50)
    print("ML-SDN Setup Verification")
    print("=" * 50)

    results = {
        'Python Version': check_python_version(),
        'Dependencies': check_dependencies(),
        'Directories': check_directories(),
        'Configuration': check_config(),
        'Scripts': check_scripts(),
        'Mininet': check_mininet()
    }

    print("\n" + "=" * 50)
    print("Summary")
    print("=" * 50)

    for check, result in results.items():
        status = "✓ PASS" if result else "❌ FAIL"
        print(f"{check:20s}: {status}")

    all_passed = all(results.values())

    print("\n" + "=" * 50)
    if all_passed:
        print("✓ All checks passed! System ready.")
        print("\nYou can now:")
        print("1. Start the Ryu controller")
        print("2. Run Mininet simulation")
        print("3. Collect and classify traffic")
    else:
        print("⚠ Some checks failed. Please review the output above.")
        print("\nTo fix issues:")
        print("1. Run: pip install -r requirements.txt")
        print("2. Run: ./scripts/quickstart.sh")
        print("3. Install Mininet if needed")
    print("=" * 50)

    return 0 if all_passed else 1


if __name__ == '__main__':
    sys.exit(main())

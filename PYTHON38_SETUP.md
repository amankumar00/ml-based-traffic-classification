# Python 3.8 Setup Guide

This project is configured to use **Python 3.8** for maximum compatibility with Ryu SDN Controller.

## Why Python 3.8?

- **Full Ryu compatibility**: Ryu 4.34 works perfectly with Python 3.8
- **Stable packages**: All ML libraries have well-tested versions for Python 3.8
- **No compatibility issues**: Avoid version conflicts and build errors

## Quick Setup

### One-Command Installation

```bash
./scripts/setup_python38.sh
```

This automated script will:
1. Install Python 3.8 (if not present)
2. Create a Python 3.8 virtual environment
3. Install all dependencies
4. Install Mininet and system packages
5. Generate sample training data
6. Train an initial model
7. Verify the installation

### Manual Installation

If you prefer manual setup:

#### Step 1: Install Python 3.8

```bash
# Update package lists
sudo apt-get update

# Install Python 3.8 and development tools
sudo apt-get install -y python3.8 python3.8-venv python3.8-dev
```

#### Step 2: Remove Old Virtual Environment (if exists)

```bash
cd /home/hello/Desktop/ML_SDN

# Remove old venv with wrong Python version
rm -rf venv
```

#### Step 3: Create Python 3.8 Virtual Environment

```bash
# Create venv with Python 3.8
python3.8 -m venv venv

# Activate it
source venv/bin/activate

# Verify Python version
python --version  # Should show Python 3.8.x
```

#### Step 4: Install Python Dependencies

```bash
# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install all dependencies
pip install -r requirements.txt
```

This will install:
- **ryu==4.34**: SDN controller framework
- **scikit-learn==1.3.2**: Machine learning
- **numpy==1.21.6**: Numerical computing (Python 3.8 compatible)
- **pandas==1.3.5**: Data manipulation (Python 3.8 compatible)
- **tensorflow==2.11.0**: Deep learning (optional)
- And other required packages

#### Step 5: Install System Dependencies

```bash
# Install Mininet and Open vSwitch
sudo apt-get install -y mininet openvswitch-switch

# Install build tools
sudo apt-get install -y build-essential libev-dev
```

#### Step 6: Generate Sample Data and Train Model

```bash
# Generate sample training data
python scripts/generate_sample_data.py

# Train initial model
python src/ml_models/train.py \
    data/processed/sample_training_data.csv \
    random_forest \
    data/models/
```

#### Step 7: Verify Installation

```bash
python scripts/verify_setup.py
```

## Current Environment Check

To check if you're using the correct Python version:

```bash
# Check system Python
python3 --version

# Check if Python 3.8 is installed
python3.8 --version

# Check virtual environment Python (after activating)
source venv/bin/activate
python --version  # Should be 3.8.x
which python      # Should point to venv/bin/python
```

## Switching from Python 3.13 to Python 3.8

If you previously set up with Python 3.13:

```bash
cd /home/hello/Desktop/ML_SDN

# Deactivate current venv if active
deactivate

# Remove old virtual environment
rm -rf venv

# Run Python 3.8 setup
./scripts/setup_python38.sh
```

## Troubleshooting

### "python3.8: command not found"

Install Python 3.8:
```bash
sudo apt-get update
sudo apt-get install python3.8 python3.8-venv python3.8-dev
```

### "venv is still using Python 3.13"

Delete and recreate:
```bash
rm -rf venv
python3.8 -m venv venv
source venv/bin/activate
python --version  # Verify it's 3.8.x
```

### Installation errors with numpy/pandas

Install build dependencies:
```bash
sudo apt-get install python3.8-dev build-essential
pip install --upgrade pip setuptools wheel
pip install numpy pandas
```

### Ryu installation fails

Make sure you're using Python 3.8:
```bash
python --version  # Must be 3.8.x
pip install ryu==4.34
```

### "No module named 'mininet'"

Mininet is a system package:
```bash
sudo apt-get install mininet
# Don't use pip to install mininet
```

## Running the Project

Always activate the Python 3.8 virtual environment first:

```bash
# Activate venv
source venv/bin/activate

# Verify Python version
python --version  # Should be 3.8.x

# Run Ryu controller
ryu-manager src/controller/sdn_controller.py --verbose
```

## Package Versions (Python 3.8 Compatible)

The `requirements.txt` file is configured with Python 3.8 compatible versions:

```
ryu==4.34
scikit-learn==1.3.2
numpy==1.21.6
pandas==1.3.5
tensorflow==2.11.0
keras==2.11.0
matplotlib==3.5.3
seaborn==0.11.2
pyyaml==6.0
loguru==0.6.0
scapy==2.5.0
```

## Benefits of Using Python 3.8

✅ No Ryu compatibility issues
✅ Stable, well-tested package versions
✅ No build errors or dependency conflicts
✅ Full TensorFlow/Keras support
✅ Production-ready setup

## Next Steps

After successful installation:

1. **Test Ryu**: `ryu-manager --version`
2. **Test Mininet**: `sudo mn --test pingall`
3. **Run verification**: `python scripts/verify_setup.py`
4. **Follow QUICKSTART.md**: Start using the system

## Alternative: Using Docker (Future Option)

If you encounter persistent issues, consider using Docker with Python 3.8:

```dockerfile
FROM python:3.8-slim
# ... setup instructions ...
```

This ensures consistent environment across all systems.

## Support

For Python version issues:
1. Verify: `python --version` (in venv)
2. Reinstall: `./scripts/setup_python38.sh`
3. Check logs: `pip list | grep ryu`

The project is now fully configured for Python 3.8!

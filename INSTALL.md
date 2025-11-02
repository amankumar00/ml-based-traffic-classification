# Installation Guide for ML-SDN

## Python Version Compatibility Issue

**Important**: Ryu 4.34 from PyPI has compatibility issues with Python 3.13+. There are several solutions:

### Solution 1: Use Python 3.8-3.12 (Recommended for beginners)

```bash
# Install Python 3.11 (if not already installed)
sudo apt-get update
sudo apt-get install python3.11 python3.11-venv python3.11-dev

# Create virtual environment with Python 3.11
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Solution 2: Install Ryu from GitHub (For Python 3.13)

```bash
# Activate your virtual environment
source venv/bin/activate

# Install Ryu from git repository
pip install git+https://github.com/faucetsdn/ryu.git

# Install other dependencies (use minimal requirements)
pip install -r requirements-minimal.txt
```

### Solution 3: Use system Python packages

```bash
# Install system packages
sudo apt-get update
sudo apt-get install python3-ryu python3-sklearn python3-numpy python3-pandas python3-matplotlib python3-yaml

# Skip virtual environment and use system Python
python3 scripts/verify_setup.py
```

## Step-by-Step Installation

### 1. Install System Dependencies

```bash
# Update package lists
sudo apt-get update

# Install Mininet (for network simulation)
sudo apt-get install mininet openvswitch-switch

# Install build tools (needed for some packages)
sudo apt-get install python3-dev build-essential

# Install OpenFlow controller dependencies
sudo apt-get install libev-dev
```

### 2. Create Virtual Environment

**Option A: With Python 3.11 (Recommended)**
```bash
cd /home/hello/Desktop/ML_SDN
python3.11 -m venv venv
source venv/bin/activate
```

**Option B: With Python 3.13 (Current)**
```bash
cd /home/hello/Desktop/ML_SDN
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Python Packages

**For Python 3.11 and below:**
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

**For Python 3.13:**
```bash
pip install --upgrade pip
pip install -r requirements-minimal.txt
```

### 4. Verify Installation

```bash
python scripts/verify_setup.py
```

### 5. Test Ryu Installation

```bash
# Test if Ryu is installed correctly
python -c "import ryu; print(f'Ryu version: {ryu.__version__}')"

# Try running the controller (Ctrl+C to stop)
ryu-manager --version
```

## Troubleshooting

### Error: "AttributeError: 'types.SimpleNamespace' object has no attribute 'get_script_args'"

**Cause**: Ryu 4.34 is incompatible with Python 3.13

**Solution**: Use one of the methods above (Python 3.11 or install from git)

### Error: "No module named 'ryu'"

**Solution 1**: Install from git
```bash
pip install git+https://github.com/faucetsdn/ryu.git
```

**Solution 2**: Use system package
```bash
sudo apt-get install python3-ryu
# Don't use virtual environment
```

### Error: "No module named 'mininet'"

**Note**: Mininet is a system package and requires sudo

**Solution**:
```bash
sudo apt-get install mininet

# Test installation
sudo mn --version
```

You don't need to install mininet in the virtual environment. Just run mininet scripts with sudo.

### Error: "Failed to build numpy/pandas"

**Solution**: Install build dependencies
```bash
sudo apt-get install python3-dev build-essential
pip install --upgrade pip setuptools wheel
pip install numpy pandas
```

### Error: Connection timeout when installing packages

**Solution**: Wait for internet connection or use a mirror
```bash
pip install --index-url https://pypi.org/simple -r requirements-minimal.txt
```

## Quick Install Commands (Copy & Paste)

### For Python 3.13 (Your current setup)

```bash
cd /home/hello/Desktop/ML_SDN

# Ensure you're in virtual environment
source venv/bin/activate

# Install dependencies one by one
pip install --upgrade pip
pip install numpy pandas scikit-learn
pip install matplotlib seaborn
pip install pyyaml loguru
pip install scapy

# Install Ryu from GitHub
pip install git+https://github.com/faucetsdn/ryu.git

# Install Mininet (system package)
sudo apt-get install mininet openvswitch-switch

# Verify installation
python scripts/verify_setup.py
```

### Alternative: Use Python 3.11

```bash
cd /home/hello/Desktop/ML_SDN

# Remove old venv
rm -rf venv

# Install Python 3.11 if needed
sudo apt-get install python3.11 python3.11-venv

# Create new venv with Python 3.11
python3.11 -m venv venv
source venv/bin/activate

# Install all dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Verify
python scripts/verify_setup.py
```

## Testing the Installation

Once installed, test each component:

```bash
# Test Python packages
python -c "import numpy, pandas, sklearn; print('ML packages OK')"
python -c "import ryu; print(f'Ryu OK: {ryu.__version__}')"

# Test Ryu controller (Ctrl+C to stop)
ryu-manager --version

# Test Mininet (requires sudo)
sudo mn --test pingall

# Run full verification
python scripts/verify_setup.py
```

## Recommended Setup

For easiest installation with fewest issues:

1. **Use Python 3.11**
2. **Install Mininet via apt-get** (don't use pip)
3. **Use virtual environment for Python packages**
4. **Skip TensorFlow/Keras** (optional, only for neural networks)

This avoids most compatibility issues while still providing all core functionality.

## Getting Help

If you continue to have issues:

1. Check Python version: `python --version`
2. Check if in virtual environment: `which python`
3. Run verification script: `python scripts/verify_setup.py`
4. Check the error logs in `logs/`

For Ryu-specific issues, see: https://github.com/faucetsdn/ryu

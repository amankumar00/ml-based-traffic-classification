#!/bin/bash
# Setup script for ML-SDN with Python 3.8

set -e

echo "========================================="
echo "ML-SDN Setup with Python 3.8"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Check if Python 3.8 is installed
echo -e "\n${BLUE}Checking for Python 3.8...${NC}"
if command -v python3.8 &> /dev/null; then
    echo -e "${GREEN}Python 3.8 found!${NC}"
    PYTHON_CMD="python3.8"
elif command -v python3 &> /dev/null; then
    PY_VERSION=$(python3 --version | grep -oP '\d+\.\d+' | head -1)
    if [ "$PY_VERSION" == "3.8" ]; then
        echo -e "${GREEN}Python 3.8 found (as python3)!${NC}"
        PYTHON_CMD="python3"
    else
        echo -e "${YELLOW}Warning: python3 version is $PY_VERSION, not 3.8${NC}"
        echo -e "${YELLOW}Installing Python 3.8...${NC}"
        sudo apt-get update
        sudo apt-get install -y python3.8 python3.8-venv python3.8-dev
        PYTHON_CMD="python3.8"
    fi
else
    echo -e "${RED}Python 3.8 not found. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y python3.8 python3.8-venv python3.8-dev
    PYTHON_CMD="python3.8"
fi

echo -e "\n${BLUE}Python version:${NC}"
$PYTHON_CMD --version

# Remove old virtual environment if it exists with wrong Python version
if [ -d "venv" ]; then
    VENV_PYTHON=$(venv/bin/python --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
    if [ "$VENV_PYTHON" != "3.8" ]; then
        echo -e "\n${YELLOW}Removing old virtual environment (Python $VENV_PYTHON)${NC}"
        rm -rf venv
    fi
fi

# Create virtual environment with Python 3.8
echo -e "\n${BLUE}Setting up Python 3.8 virtual environment${NC}"
if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
    echo -e "${GREEN}Virtual environment created with Python 3.8${NC}"
else
    echo -e "${GREEN}Virtual environment already exists${NC}"
fi

# Activate virtual environment
echo -e "\n${BLUE}Activating virtual environment${NC}"
source venv/bin/activate

# Verify Python version in venv
echo -e "\n${BLUE}Virtual environment Python version:${NC}"
python --version

# Upgrade pip
echo -e "\n${BLUE}Upgrading pip, setuptools, and wheel${NC}"
pip install --upgrade pip setuptools wheel

# Install dependencies
echo -e "\n${BLUE}Installing Python dependencies${NC}"
pip install -r requirements.txt

echo -e "${GREEN}Python packages installed successfully!${NC}"

# Install system dependencies
echo -e "\n${BLUE}Installing system dependencies (requires sudo)${NC}"
echo "Installing Mininet, Open vSwitch, and development tools..."

sudo apt-get update
sudo apt-get install -y \
    mininet \
    openvswitch-switch \
    build-essential \
    python3.8-dev \
    libev-dev

echo -e "${GREEN}System dependencies installed!${NC}"

# Create directories
echo -e "\n${BLUE}Creating project directories${NC}"
mkdir -p data/{raw,processed,models}
mkdir -p logs
echo -e "${GREEN}Directories created${NC}"

# Generate sample training data
echo -e "\n${BLUE}Generating sample training data${NC}"
python scripts/generate_sample_data.py
echo -e "${GREEN}Sample data generated${NC}"

# Train initial model
echo -e "\n${BLUE}Training initial Random Forest model${NC}"
python src/ml_models/train.py \
    data/processed/sample_training_data.csv \
    random_forest \
    data/models/
echo -e "${GREEN}Model trained and saved${NC}"

# Run verification
echo -e "\n${BLUE}Verifying installation${NC}"
python scripts/verify_setup.py

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}Important Notes:${NC}"
echo "1. Always activate the virtual environment before running:"
echo "   source venv/bin/activate"
echo ""
echo "2. Verify Python version in venv:"
echo "   python --version  (should show Python 3.8.x)"
echo ""
echo "3. To deactivate the virtual environment:"
echo "   deactivate"

echo -e "\n${BLUE}Next Steps - Run in separate terminals:${NC}"
echo ""
echo -e "${YELLOW}Terminal 1 (Ryu Controller):${NC}"
echo "   source venv/bin/activate"
echo "   ryu-manager src/controller/sdn_controller.py --verbose"
echo ""
echo -e "${YELLOW}Terminal 2 (Mininet):${NC}"
echo "   sudo python topology/custom_topo.py --topology custom"
echo ""
echo -e "${YELLOW}Terminal 3 (Process Traffic):${NC}"
echo "   source venv/bin/activate"
echo "   python src/traffic_monitor/feature_extractor.py data/raw/*.json data/processed/features.csv"
echo "   python src/ml_models/classifier.py data/models/ data/processed/features.csv"
echo ""
echo "See QUICKSTART.md for detailed usage instructions."

#!/bin/bash
# Manual installation without system packages (for when apt has issues)

set -e

echo "========================================="
echo "ML-SDN Manual Installation (Python Only)"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Check Python 3.8
echo -e "\n${BLUE}Checking for Python 3.8...${NC}"
if command -v python3.8 &> /dev/null; then
    PYTHON_CMD="python3.8"
    echo -e "${GREEN}Found python3.8${NC}"
else
    echo -e "${RED}Python 3.8 not found!${NC}"
    echo "Please install it first: sudo apt-get install python3.8 python3.8-venv python3.8-dev"
    exit 1
fi

# Remove old venv
if [ -d "venv" ]; then
    echo -e "\n${BLUE}Removing old virtual environment${NC}"
    rm -rf venv
fi

# Create new venv with Python 3.8
echo -e "\n${BLUE}Creating Python 3.8 virtual environment${NC}"
$PYTHON_CMD -m venv venv

# Activate virtual environment
source venv/bin/activate

# Verify Python version
echo -e "\n${BLUE}Python version in venv:${NC}"
python --version

# Upgrade pip
echo -e "\n${BLUE}Upgrading pip${NC}"
pip install --upgrade pip setuptools wheel

# Install dependencies one by one (more reliable)
echo -e "\n${BLUE}Installing Python packages${NC}"

echo "Installing Ryu..."
pip install ryu==4.34

echo "Installing numpy..."
pip install numpy==1.21.6

echo "Installing pandas..."
pip install pandas==1.3.5

echo "Installing scikit-learn..."
pip install scikit-learn==1.3.2

echo "Installing matplotlib..."
pip install matplotlib==3.5.3

echo "Installing seaborn..."
pip install seaborn==0.11.2

echo "Installing utilities..."
pip install pyyaml==6.0 loguru==0.6.0 scapy==2.5.0 python-dotenv==0.21.0

echo -e "${GREEN}Python packages installed!${NC}"

# Create directories
echo -e "\n${BLUE}Creating directories${NC}"
mkdir -p data/{raw,processed,models}
mkdir -p logs

# Generate sample data
echo -e "\n${BLUE}Generating sample training data${NC}"
python scripts/generate_sample_data.py

# Train model
echo -e "\n${BLUE}Training model${NC}"
python src/ml_models/train.py \
    data/processed/sample_training_data.csv \
    random_forest \
    data/models/

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Python Installation Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${YELLOW}Note: Mininet was NOT installed (requires fixing apt first)${NC}"
echo "You have two options:"
echo ""
echo "1. Fix apt and install Mininet:"
echo "   sudo rm -f /etc/apt/sources.list.d/regolith-linux-ubuntu-release-noble.list"
echo "   sudo apt-get update"
echo "   sudo apt-get install mininet openvswitch-switch"
echo ""
echo "2. Use the project without Mininet (just test the ML components):"
echo "   python scripts/verify_setup.py"
echo ""
echo "Python environment is ready! You can:"
echo "- Test ML models with existing data"
echo "- Train new models"
echo "- Once Mininet is installed, run the full system"

#!/bin/bash
# Fix repository issues and install ML-SDN

set -e

echo "========================================="
echo "Fixing Repository Issues & Installing"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Fix the problematic PPA
echo -e "\n${BLUE}Fixing problematic repository...${NC}"
if [ -f "/etc/apt/sources.list.d/regolith-linux-ubuntu-release-noble.list" ]; then
    echo "Removing regolith-linux PPA that's causing errors..."
    sudo rm -f /etc/apt/sources.list.d/regolith-linux-ubuntu-release-noble.list
    echo -e "${GREEN}Removed problematic repository${NC}"
fi

# Update package lists
echo -e "\n${BLUE}Updating package lists...${NC}"
sudo apt-get update 2>&1 | grep -v "command-not-found" || true

# Install system dependencies without the apt update hook that's failing
echo -e "\n${BLUE}Installing system dependencies...${NC}"
sudo apt-get install -y --no-install-recommends \
    mininet \
    openvswitch-switch \
    build-essential \
    python3.8-dev \
    libev-dev

echo -e "${GREEN}System dependencies installed!${NC}"

# Detect Python 3.8
echo -e "\n${BLUE}Setting up Python 3.8 environment...${NC}"
if command -v python3.8 &> /dev/null; then
    PYTHON_CMD="python3.8"
    echo -e "${GREEN}Found python3.8${NC}"
else
    echo -e "${RED}Python 3.8 not found!${NC}"
    exit 1
fi

# Remove old venv if exists with wrong version
if [ -d "venv" ]; then
    VENV_PYTHON=$(venv/bin/python --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
    if [ "$VENV_PYTHON" != "3.8" ]; then
        echo -e "\n${YELLOW}Removing old virtual environment (Python $VENV_PYTHON)${NC}"
        rm -rf venv
    fi
fi

# Create virtual environment with Python 3.8
echo -e "\n${BLUE}Creating Python 3.8 virtual environment${NC}"
if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
    echo -e "${GREEN}Virtual environment created${NC}"
else
    echo -e "${GREEN}Virtual environment already exists${NC}"
fi

# Activate virtual environment
source venv/bin/activate

# Verify Python version
echo -e "\n${BLUE}Virtual environment Python version:${NC}"
python --version

# Upgrade pip
echo -e "\n${BLUE}Upgrading pip, setuptools, and wheel${NC}"
pip install --upgrade pip setuptools wheel

# Install Python dependencies
echo -e "\n${BLUE}Installing Python dependencies${NC}"
pip install -r requirements.txt

echo -e "${GREEN}Python packages installed successfully!${NC}"

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

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}Next Steps:${NC}"
echo ""
echo "Open 3 terminals and run:"
echo ""
echo -e "${YELLOW}Terminal 1 (Controller):${NC}"
echo "  cd $PROJECT_DIR"
echo "  source venv/bin/activate"
echo "  ryu-manager src/controller/sdn_controller.py --verbose"
echo ""
echo -e "${YELLOW}Terminal 2 (Network):${NC}"
echo "  cd $PROJECT_DIR"
echo "  sudo python topology/custom_topo.py --topology custom"
echo ""
echo -e "${YELLOW}Terminal 3 (Analysis):${NC}"
echo "  cd $PROJECT_DIR"
echo "  source venv/bin/activate"
echo "  python src/traffic_monitor/feature_extractor.py data/raw/*.json data/processed/features.csv"
echo "  python src/ml_models/classifier.py data/models/ data/processed/features.csv"
echo ""
echo "See HOW_TO_RUN.md for detailed instructions."

#!/bin/bash
# Installation script for Python 3.13 compatible setup

set -e

echo "================================"
echo "ML-SDN Installation (Python 3.13)"
echo "================================"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo -e "\n${BLUE}Checking if virtual environment exists${NC}"
if [ ! -d "venv" ]; then
    echo -e "${RED}Virtual environment not found. Creating one...${NC}"
    python3 -m venv venv
fi

echo -e "\n${BLUE}Activating virtual environment${NC}"
source venv/bin/activate

echo -e "\n${BLUE}Upgrading pip${NC}"
pip install --upgrade pip setuptools wheel

echo -e "\n${BLUE}Installing core ML packages${NC}"
pip install numpy pandas scikit-learn

echo -e "\n${BLUE}Installing visualization packages${NC}"
pip install matplotlib seaborn

echo -e "\n${BLUE}Installing utility packages${NC}"
pip install pyyaml loguru scapy

echo -e "\n${BLUE}Installing Ryu from GitHub (Python 3.13 compatible)${NC}"
pip install git+https://github.com/faucetsdn/ryu.git

echo -e "\n${BLUE}Checking Ryu installation${NC}"
python -c "import ryu; print(f'Ryu version: {ryu.__version__}')" && echo -e "${GREEN}Ryu installed successfully!${NC}" || echo -e "${RED}Ryu installation failed${NC}"

echo -e "\n${BLUE}Installing Mininet (system package)${NC}"
echo "Mininet requires sudo access..."
sudo apt-get update
sudo apt-get install -y mininet openvswitch-switch

echo -e "\n${BLUE}Creating directories${NC}"
mkdir -p data/{raw,processed,models}
mkdir -p logs

echo -e "\n${BLUE}Generating sample training data${NC}"
python scripts/generate_sample_data.py

echo -e "\n${BLUE}Training initial model${NC}"
python src/ml_models/train.py data/processed/sample_training_data.csv random_forest data/models/

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"

echo -e "\n${BLUE}Verifying setup...${NC}"
python scripts/verify_setup.py

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Terminal 1: ryu-manager src/controller/sdn_controller.py --verbose"
echo "2. Terminal 2: sudo python topology/custom_topo.py --topology custom"
echo "3. See QUICKSTART.md for more details"

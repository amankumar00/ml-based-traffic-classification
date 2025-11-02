#!/bin/bash
# Install using conda base environment (you have conda already)

set -e

echo "========================================="
echo "ML-SDN Installation Using Conda"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo -e "\n${BLUE}You have conda (base) environment active${NC}"
echo -e "${YELLOW}Let's use conda instead of venv!${NC}"

# Create conda environment with Python 3.8
echo -e "\n${BLUE}Creating conda environment 'ml-sdn' with Python 3.8${NC}"
conda create -n ml-sdn python=3.8 -y

echo -e "\n${BLUE}Activating conda environment${NC}"
eval "$(conda shell.bash hook)"
conda activate ml-sdn

# Verify Python version
echo -e "\n${BLUE}Python version:${NC}"
python --version

# Install dependencies
echo -e "\n${BLUE}Installing Python packages${NC}"

# Install from conda-forge first (more reliable)
conda install -y -c conda-forge \
    numpy=1.21 \
    pandas=1.3 \
    scikit-learn=1.3 \
    matplotlib=3.5 \
    seaborn=0.11 \
    pyyaml

# Install remaining packages with pip
pip install ryu==4.34 loguru==0.6.0 scapy==2.5.0 python-dotenv==0.21.0

echo -e "${GREEN}Packages installed!${NC}"

# Create directories
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
echo -e "${GREEN}Installation Complete with Conda!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}To use the project:${NC}"
echo ""
echo "Always activate conda environment first:"
echo "  conda activate ml-sdn"
echo ""
echo "Then run components:"
echo "  Terminal 1: ryu-manager src/controller/sdn_controller.py --verbose"
echo "  Terminal 2: sudo python topology/custom_topo.py --topology custom"
echo "  Terminal 3: python src/traffic_monitor/feature_extractor.py ..."
echo ""
echo "To install Mininet:"
echo "  sudo rm -f /etc/apt/sources.list.d/regolith-linux-ubuntu-release-noble.list"
echo "  sudo apt-get update"
echo "  sudo apt-get install mininet openvswitch-switch"

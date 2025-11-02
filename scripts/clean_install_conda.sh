#!/bin/bash
# Complete clean installation with conda

set -e

echo "========================================="
echo "Clean Conda Installation"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${YELLOW}This will remove and recreate the ml-sdn environment${NC}"
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Deactivate if in ml-sdn
if [[ "$CONDA_DEFAULT_ENV" == "ml-sdn" ]]; then
    echo -e "\n${BLUE}Deactivating ml-sdn environment${NC}"
    conda deactivate
fi

# Remove old environment
echo -e "\n${BLUE}Removing old ml-sdn environment${NC}"
conda env remove -n ml-sdn -y 2>/dev/null || true

# Remove user-installed conflicting packages
echo -e "\n${BLUE}Cleaning up user-installed packages${NC}"
pip uninstall -y ryu eventlet 2>/dev/null || true
rm -rf ~/.local/lib/python3.8/site-packages/ryu* 2>/dev/null || true
rm -rf ~/.local/lib/python3.8/site-packages/eventlet* 2>/dev/null || true

# Create new environment from file
echo -e "\n${BLUE}Creating new ml-sdn environment from environment.yml${NC}"
cd /home/hello/Desktop/ML_SDN
conda env create -f environment.yml

echo -e "\n${GREEN}Environment created!${NC}"
echo -e "\n${BLUE}Activating ml-sdn environment${NC}"
eval "$(conda shell.bash hook)"
conda activate ml-sdn

# Verify Python version
echo -e "\n${BLUE}Python version:${NC}"
python --version

# Verify Ryu installation
echo -e "\n${BLUE}Verifying Ryu installation:${NC}"
python -c "from ryu.cmd.manager import main; print('✓ Ryu imported successfully!')" || {
    echo -e "${RED}Ryu import failed, trying alternative installation...${NC}"
    pip install --no-cache-dir eventlet==0.30.3
    pip install --no-cache-dir ryu==4.34
}

# Check ryu-manager
echo -e "\n${BLUE}Checking ryu-manager:${NC}"
which ryu-manager
ryu-manager --version

# Create directories
mkdir -p data/{raw,processed,models} logs

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
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}Test Ryu controller:${NC}"
echo "  conda activate ml-sdn"
echo "  ryu-manager --version"
echo "  ryu-manager src/controller/sdn_controller.py --verbose"
echo ""
echo -e "${YELLOW}Note: Press Ctrl+C to stop the controller${NC}"

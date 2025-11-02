#!/bin/bash
# Fix Ryu installation in conda environment

set -e

echo "========================================="
echo "Fixing Ryu in Conda Environment"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if in ml-sdn environment
if [[ "$CONDA_DEFAULT_ENV" != "ml-sdn" ]]; then
    echo -e "${RED}Please activate ml-sdn environment first:${NC}"
    echo "  conda activate ml-sdn"
    exit 1
fi

echo -e "\n${BLUE}Current environment: $CONDA_DEFAULT_ENV${NC}"

# Uninstall global ryu if it exists
echo -e "\n${BLUE}Cleaning up old Ryu installations...${NC}"
pip uninstall -y ryu 2>/dev/null || true

# Install compatible eventlet version first
echo -e "\n${BLUE}Installing compatible eventlet version...${NC}"
pip install "eventlet<0.31"

# Now install Ryu
echo -e "\n${BLUE}Installing Ryu in conda environment...${NC}"
pip install ryu==4.34

echo -e "\n${BLUE}Verifying installation...${NC}"
python -c "from ryu.cmd.manager import main; print('Ryu imported successfully!')" && \
    echo -e "${GREEN}✓ Ryu is working!${NC}" || \
    echo -e "${RED}✗ Ryu import failed${NC}"

# Check which ryu-manager is being used
echo -e "\n${BLUE}Checking ryu-manager location:${NC}"
which ryu-manager

# Try to run ryu-manager
echo -e "\n${BLUE}Testing ryu-manager:${NC}"
ryu-manager --version && echo -e "${GREEN}✓ ryu-manager works!${NC}" || echo -e "${RED}✗ ryu-manager failed${NC}"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Fix Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}Now you can run:${NC}"
echo "  ryu-manager src/controller/sdn_controller.py --verbose"

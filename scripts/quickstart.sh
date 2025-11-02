#!/bin/bash
# Quick start script for ML-SDN project (Python 3.8)

set -e

echo "================================"
echo "ML-SDN Quick Start (Python 3.8)"
echo "================================"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Detect Python 3.8
echo -e "\n${BLUE}Detecting Python 3.8...${NC}"
if command -v python3.8 &> /dev/null; then
    PYTHON_CMD="python3.8"
    echo -e "${GREEN}Found python3.8${NC}"
elif python3 --version 2>&1 | grep -q "Python 3.8"; then
    PYTHON_CMD="python3"
    echo -e "${GREEN}Found python3 (version 3.8)${NC}"
else
    echo -e "${RED}Python 3.8 not found!${NC}"
    echo -e "${YELLOW}Please run: ./scripts/setup_python38.sh${NC}"
    exit 1
fi

echo -e "\n${BLUE}Step 1: Setting up Python 3.8 virtual environment${NC}"
if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
    echo -e "${GREEN}Virtual environment created with Python 3.8${NC}"
else
    echo -e "${GREEN}Virtual environment already exists${NC}"
fi

echo -e "\n${BLUE}Step 2: Activating virtual environment${NC}"
source venv/bin/activate

echo -e "\n${BLUE}Step 3: Installing dependencies${NC}"
pip install --upgrade pip
pip install -r requirements.txt
echo -e "${GREEN}Dependencies installed${NC}"

echo -e "\n${BLUE}Step 4: Creating directory structure${NC}"
mkdir -p data/{raw,processed,models}
mkdir -p logs
echo -e "${GREEN}Directories created${NC}"

echo -e "\n${BLUE}Step 5: Generating sample training data${NC}"
python scripts/generate_sample_data.py
echo -e "${GREEN}Sample data generated${NC}"

echo -e "\n${BLUE}Step 6: Training ML model${NC}"
python src/ml_models/train.py data/processed/sample_training_data.csv random_forest data/models/
echo -e "${GREEN}Model trained and saved${NC}"

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Start the Ryu controller:"
echo "   ryu-manager src/controller/sdn_controller.py --verbose"
echo ""
echo "2. In another terminal, start Mininet:"
echo "   sudo python topology/custom_topo.py --topology custom"
echo ""
echo "3. Generate traffic in Mininet CLI:"
echo "   mininet> pingall"
echo "   mininet> iperf h1 h2"
echo ""
echo "4. Extract features from captured traffic:"
echo "   python src/traffic_monitor/feature_extractor.py data/raw/*.json data/processed/features.csv"
echo ""
echo "5. Classify traffic:"
echo "   python src/ml_models/classifier.py data/models/ data/processed/features.csv"
echo ""
echo "See README.md for more details!"

#!/bin/bash
# Quick system test - verifies all components work

set -e

echo "========================================="
echo "ML-SDN System Test"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Check if setup was done
echo -e "\n${BLUE}1. Checking setup...${NC}"
if [ ! -d "venv" ]; then
    echo -e "${RED}Virtual environment not found!${NC}"
    echo "Please run: ./scripts/setup_python38.sh"
    exit 1
fi

source venv/bin/activate

PY_VERSION=$(python --version 2>&1)
echo "   Python: $PY_VERSION"

if ! echo "$PY_VERSION" | grep -q "Python 3.8"; then
    echo -e "${YELLOW}   Warning: Not using Python 3.8${NC}"
fi

# Check if model exists
echo -e "\n${BLUE}2. Checking trained model...${NC}"
if [ ! -f "data/models/random_forest_model.pkl" ]; then
    echo -e "${YELLOW}   Model not found. Training model...${NC}"
    python scripts/generate_sample_data.py
    python src/ml_models/train.py data/processed/sample_training_data.csv random_forest data/models/
fi
echo -e "${GREEN}   ✓ Model ready${NC}"

# Test imports
echo -e "\n${BLUE}3. Testing Python imports...${NC}"
python -c "import ryu; print('   ✓ Ryu:', ryu.__version__)" || exit 1
python -c "import numpy; print('   ✓ NumPy:', numpy.__version__)" || exit 1
python -c "import pandas; print('   ✓ Pandas:', pandas.__version__)" || exit 1
python -c "import sklearn; print('   ✓ Scikit-learn:', sklearn.__version__)" || exit 1

# Check Mininet
echo -e "\n${BLUE}4. Checking Mininet...${NC}"
if command -v mn &> /dev/null; then
    MN_VERSION=$(mn --version 2>&1 | head -1)
    echo "   ✓ $MN_VERSION"
else
    echo -e "${YELLOW}   Warning: Mininet not found${NC}"
    echo "   Install: sudo apt-get install mininet"
fi

# Test feature extraction
echo -e "\n${BLUE}5. Testing feature extraction...${NC}"
if [ -f "data/processed/sample_training_data.csv" ]; then
    ROWS=$(wc -l < data/processed/sample_training_data.csv)
    echo "   ✓ Sample data: $ROWS rows"
else
    echo -e "${YELLOW}   No sample data found${NC}"
fi

# Test model loading
echo -e "\n${BLUE}6. Testing model loading...${NC}"
python -c "
from src.ml_models.classifier import TrafficClassifier
classifier = TrafficClassifier('data/models/')
print('   ✓ Model loaded successfully')
print('   Classes:', classifier.metadata['class_names'])
" || exit 1

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}All tests passed!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}System is ready to use!${NC}"
echo ""
echo "To run the system, open 3 terminals:"
echo ""
echo -e "${YELLOW}Terminal 1 (Controller):${NC}"
echo "  source venv/bin/activate"
echo "  ryu-manager src/controller/sdn_controller.py --verbose"
echo ""
echo -e "${YELLOW}Terminal 2 (Network):${NC}"
echo "  sudo python topology/custom_topo.py --topology custom"
echo ""
echo -e "${YELLOW}Terminal 3 (Analysis):${NC}"
echo "  source venv/bin/activate"
echo "  python src/traffic_monitor/feature_extractor.py data/raw/*.json data/processed/features.csv"
echo "  python src/ml_models/classifier.py data/models/ data/processed/features.csv"
echo ""
echo "See HOW_TO_RUN.md for detailed instructions."

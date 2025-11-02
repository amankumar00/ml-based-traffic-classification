#!/bin/bash
# Demo test - Run a complete test without Mininet

set -e

echo "========================================="
echo "ML-SDN Demo Test"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /home/hello/Desktop/ML_SDN

# Check if in ml-sdn environment
if [[ "$CONDA_DEFAULT_ENV" != "ml-sdn" ]]; then
    echo -e "${YELLOW}Please activate ml-sdn environment first:${NC}"
    echo "  conda activate ml-sdn"
    exit 1
fi

echo -e "\n${BLUE}Testing with sample training data...${NC}"

# Use the sample training data as test data
echo -e "\n${BLUE}1. Using sample data as test data${NC}"
if [ -f "data/processed/sample_training_data.csv" ]; then
    # Remove the traffic_type column to simulate unknown traffic
    python -c "
import pandas as pd
df = pd.read_csv('data/processed/sample_training_data.csv')
# Take first 50 rows for testing
test_df = df.head(50).copy()
# Remove the label column
if 'traffic_type' in test_df.columns:
    test_df = test_df.drop(columns=['traffic_type'])
test_df.to_csv('data/processed/test_features.csv', index=False)
print(f'Created test dataset with {len(test_df)} flows')
"
    echo -e "${GREEN}✓ Test data created${NC}"
else
    echo -e "${YELLOW}Generating sample data first...${NC}"
    python scripts/generate_sample_data.py
    python -c "
import pandas as pd
df = pd.read_csv('data/processed/sample_training_data.csv')
test_df = df.head(50).copy()
if 'traffic_type' in test_df.columns:
    test_df = test_df.drop(columns=['traffic_type'])
test_df.to_csv('data/processed/test_features.csv', index=False)
print(f'Created test dataset with {len(test_df)} flows')
"
fi

# Classify the test data
echo -e "\n${BLUE}2. Classifying traffic with trained model${NC}"
python src/ml_models/classifier.py data/models/ data/processed/test_features.csv

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Demo Test Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${BLUE}What was tested:${NC}"
echo "  ✓ ML model loaded successfully"
echo "  ✓ Feature processing works"
echo "  ✓ Traffic classification works"
echo "  ✓ Confidence scores calculated"

echo -e "\n${YELLOW}To test with real network traffic:${NC}"
echo "1. Install Mininet:"
echo "   sudo rm -f /etc/apt/sources.list.d/regolith-linux-ubuntu-release-noble.list"
echo "   sudo apt-get update"
echo "   sudo apt-get install mininet openvswitch-switch"
echo ""
echo "2. Terminal 1: Start controller"
echo "   conda activate ml-sdn"
echo "   ryu-manager src/controller/sdn_controller.py --verbose"
echo ""
echo "3. Terminal 2: Generate traffic"
echo "   sudo python topology/custom_topo.py --topology custom --traffic mixed --duration 30"
echo ""
echo "4. Terminal 3: Analyze captured traffic"
echo "   conda activate ml-sdn"
echo "   python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/real_features.csv"
echo "   python src/ml_models/classifier.py data/models/ data/processed/real_features.csv"

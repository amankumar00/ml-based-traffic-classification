#!/bin/bash
# Fix Python 3.8 missing dependencies

echo "========================================="
echo "Fixing Python 3.8 Dependencies"
echo "========================================="

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${BLUE}Installing missing Python 3.8 system libraries...${NC}"

# Install all Python 3.8 standard library modules
sudo apt-get update
sudo apt-get install -y \
    python3.8 \
    python3.8-venv \
    python3.8-dev \
    libbz2-dev \
    libssl-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libffi-dev \
    liblzma-dev \
    zlib1g-dev

echo -e "${GREEN}System libraries installed${NC}"

# Check if we need to reinstall Python 3.8
echo -e "\n${BLUE}Verifying Python 3.8 installation...${NC}"
python3.8 -c "import _bz2" 2>/dev/null && echo -e "${GREEN}✓ _bz2 module available${NC}" || {
    echo -e "${RED}✗ _bz2 still missing${NC}"
    echo -e "${BLUE}Python 3.8 may need reinstallation${NC}"
    echo "Try: sudo apt-get install --reinstall python3.8"
}

echo -e "\n${BLUE}Recommendation:${NC}"
echo "If _bz2 is still missing, reinstall Python 3.8:"
echo "  sudo apt-get install --reinstall python3.8"
echo ""
echo "Then recreate the virtual environment:"
echo "  rm -rf venv"
echo "  python3.8 -m venv venv"
echo "  source venv/bin/activate"
echo "  pip install -r requirements.txt"

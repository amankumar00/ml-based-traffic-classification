#!/bin/bash
# Check Python versions available on the system

echo "================================"
echo "Python Version Check"
echo "================================"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${BLUE}System Python versions:${NC}"

# Check python3
if command -v python3 &> /dev/null; then
    PY3_VERSION=$(python3 --version 2>&1)
    echo "  python3: $PY3_VERSION"
else
    echo -e "  ${RED}python3: Not found${NC}"
fi

# Check python3.8
if command -v python3.8 &> /dev/null; then
    PY38_VERSION=$(python3.8 --version 2>&1)
    echo -e "  ${GREEN}python3.8: $PY38_VERSION ✓${NC}"
    PY38_FOUND=true
else
    echo -e "  ${RED}python3.8: Not found${NC}"
    PY38_FOUND=false
fi

# Check python3.11
if command -v python3.11 &> /dev/null; then
    PY311_VERSION=$(python3.11 --version 2>&1)
    echo "  python3.11: $PY311_VERSION"
fi

# Check python3.13
if command -v python3.13 &> /dev/null; then
    PY313_VERSION=$(python3.13 --version 2>&1)
    echo "  python3.13: $PY313_VERSION"
fi

# Check virtual environment
echo -e "\n${BLUE}Virtual Environment:${NC}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -d "$PROJECT_DIR/venv" ]; then
    echo -e "  ${GREEN}Status: Exists${NC}"
    if [ -f "$PROJECT_DIR/venv/bin/python" ]; then
        VENV_VERSION=$($PROJECT_DIR/venv/bin/python --version 2>&1)
        echo "  Version: $VENV_VERSION"

        # Check if it's Python 3.8
        if echo "$VENV_VERSION" | grep -q "Python 3.8"; then
            echo -e "  ${GREEN}✓ Using Python 3.8 (Recommended for Ryu)${NC}"
        else
            echo -e "  ${YELLOW}⚠ Not using Python 3.8${NC}"
            echo -e "  ${YELLOW}Consider recreating venv with Python 3.8${NC}"
        fi
    fi
else
    echo -e "  ${RED}Status: Not found${NC}"
    echo "  Run: ./scripts/setup_python38.sh"
fi

echo -e "\n${BLUE}Recommendations:${NC}"
if [ "$PY38_FOUND" = true ]; then
    echo -e "  ${GREEN}✓ Python 3.8 is installed${NC}"
    echo "  To create venv: python3.8 -m venv venv"
    echo "  Or run: ./scripts/setup_python38.sh"
else
    echo -e "  ${YELLOW}⚠ Python 3.8 is NOT installed${NC}"
    echo "  Install with: sudo apt-get install python3.8 python3.8-venv python3.8-dev"
    echo "  Then run: ./scripts/setup_python38.sh"
fi

echo -e "\n${BLUE}Why Python 3.8?${NC}"
echo "  • Full compatibility with Ryu 4.34"
echo "  • Stable package versions"
echo "  • No build errors or dependency conflicts"

echo ""

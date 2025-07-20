#!/bin/bash

# Run Search Safety Validation Test
# Tests P0 content for dangerous query handling

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PrepperApp Search Safety Validation ===${NC}"
echo "Testing P0 content for dangerous medical query handling"
echo

# Set paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PYTHON_SCRIPT="${SCRIPT_DIR}/content/scripts/validate_search_safety.py"

# Check if P0 extraction exists
if [ ! -f "${SCRIPT_DIR}/data/processed-p0/content-p0.sqlite" ]; then
    echo -e "${RED}Error: P0 content not found${NC}"
    echo "Please run P0_ONLY_EXTRACT.sh first to create the P0 content"
    exit 1
fi

# Check Python dependencies
echo "Checking Python dependencies..."
python3 -c "import sqlite3, json, zstandard" 2>/dev/null || {
    echo -e "${RED}Error: Missing Python dependencies${NC}"
    echo "Please install: pip3 install zstandard"
    exit 1
}

# Run the validation
echo -e "${YELLOW}Running search safety validation...${NC}"
python3 "$PYTHON_SCRIPT"

echo
echo -e "${GREEN}✓ Validation complete${NC}"
echo
echo -e "${BLUE}=== What This Test Validates ===${NC}"
echo "1. Whether dangerous queries return safe results"
echo "2. Whether medical emergency queries find relevant content"
echo "3. Whether negation queries (e.g., 'do not apply heat') work correctly"
echo "4. Whether age-specific queries return appropriate results"
echo
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "If all tests pass:"
echo "  - Basic indexing without phrase search is safe"
echo "  - Proceed with mobile deployment (249MB bundle)"
echo
echo "If concerns are found:"
echo "  - Review specific failing queries"
echo "  - Consider selective positional indexing for critical terms only"
echo "  - Re-test after implementing mitigations"
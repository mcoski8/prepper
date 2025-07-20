#!/bin/bash

# Test Search Validation Script
# Tests the mobile-optimized P0 index for safety with dangerous queries

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PrepperApp Search Validation Test ===${NC}"
echo "Testing mobile-optimized P0 index for query safety"
echo

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: Rust/Cargo not installed${NC}"
    echo "Please install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

# Set paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEST_DIR="${SCRIPT_DIR}/rust/tantivy-search-test"
INDEX_PATH="${SCRIPT_DIR}/data/indexes/tantivy-p0-mobile"

# Check if index exists
if [ ! -d "$INDEX_PATH" ]; then
    echo -e "${RED}Error: P0 mobile index not found at: $INDEX_PATH${NC}"
    echo "Please run P0_MOBILE_OPTIMIZED.sh first to build the index"
    exit 1
fi

# Build the test binary
echo -e "${YELLOW}Building search test binary...${NC}"
cd "$TEST_DIR"
cargo build --release

# Run the search validation test
echo -e "${YELLOW}Running search validation test...${NC}"
echo
./target/release/tantivy-search-test

# Check if results file was created
if [ -f "search_test_results.json" ]; then
    echo
    echo -e "${GREEN}✓ Test completed. Results saved to: ${TEST_DIR}/search_test_results.json${NC}"
    
    # Quick analysis of results
    echo
    echo -e "${BLUE}=== Quick Analysis ===${NC}"
    
    # Count concerning results
    CONCERNS=$(grep -c "CONCERN" search_test_results.json || true)
    WARNINGS=$(grep -c "WARNING" search_test_results.json || true)
    
    if [ "$CONCERNS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
        echo -e "${GREEN}✅ All queries returned safe results!${NC}"
        echo
        echo "Recommendation: The Basic-indexed search is safe for deployment."
        echo "No phrase search appears to be necessary for medical emergency queries."
    else
        echo -e "${YELLOW}⚠️  Found $CONCERNS concerns and $WARNINGS warnings${NC}"
        echo
        echo "Please review search_test_results.json for details."
        echo "Consider whether phrase search or other mitigations are needed."
    fi
    
    # Show sample results
    echo
    echo -e "${BLUE}Sample query results:${NC}"
    echo "Cold water immersion:"
    grep -A 5 '"query": "cold water immersion"' search_test_results.json | grep -E '"title"|"analysis"' | head -2
    echo
    echo "Infant CPR dose:"
    grep -A 5 '"query": "infant cpr dose"' search_test_results.json | grep -E '"title"|"analysis"' | head -2
else
    echo -e "${RED}Error: Test results file was not created${NC}"
    exit 1
fi

echo
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Review the full results in search_test_results.json"
echo "2. If results are satisfactory, proceed with deployment"
echo "3. If concerns exist, consider implementing selective positional indexing"
echo "   for specific critical terms only"
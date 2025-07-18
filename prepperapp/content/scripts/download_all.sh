#!/bin/bash

# PrepperApp Content Download Master Script
# Downloads all available content sources

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== PrepperApp Content Acquisition ==="
echo "Starting download of survival content..."
echo ""

# Check Python dependencies
echo "Checking dependencies..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required${NC}"
    exit 1
fi

if ! python3 -c "import requests" &> /dev/null; then
    echo -e "${YELLOW}Installing required Python packages...${NC}"
    pip3 install requests
fi

# Create directory structure
echo "Setting up directories..."
mkdir -p ../raw/{wikipedia,military,medical,maps}
mkdir -p ../processed/{core,modules}
mkdir -p ../indexes

# Download Wikipedia Medical Content
echo -e "\n${GREEN}1. Downloading Wikipedia Medical Content${NC}"
echo "This may take a while (4.2GB)..."
if [ "$1" != "--skip-wikipedia" ]; then
    python3 download_wikipedia_medical.py
else
    echo "Skipping Wikipedia download (--skip-wikipedia flag)"
fi

# Download Military Manuals
echo -e "\n${GREEN}2. Downloading Military Survival Manuals${NC}"
python3 download_military_manuals.py

# Download additional medical resources
echo -e "\n${GREEN}3. Downloading Additional Medical Resources${NC}"
echo "Downloading 'Where There Is No Doctor'..."
mkdir -p ../raw/medical
if [ ! -f "../raw/medical/where_there_is_no_doctor.pdf" ]; then
    wget -q --show-progress \
        "https://store.hesperian.org/prod/downloads/B010R_wtnd_2021.pdf" \
        -O "../raw/medical/where_there_is_no_doctor.pdf" || \
        echo -e "${YELLOW}Warning: Could not download 'Where There Is No Doctor'${NC}"
fi

# Process downloaded content
echo -e "\n${GREEN}4. Processing Content${NC}"
python3 process_content.py

# Generate download report
echo -e "\n${GREEN}5. Generating Download Report${NC}"
cat > ../download_report.txt << EOF
PrepperApp Content Download Report
Generated: $(date)

Downloaded Content:
===================

1. Wikipedia Medical Subset
   Status: $([ -f "../raw/wikipedia/wikipedia_en_medicine_nodet_2024-06.zim" ] && echo "✓ Downloaded" || echo "✗ Missing")
   Size: ~4.2GB
   Articles: ~40,000 medical topics

2. Military Survival Manuals
   Status: $(ls ../raw/military/*.pdf 2>/dev/null | wc -l) manuals downloaded
   Key manuals:
   $(ls ../raw/military/*.pdf 2>/dev/null | xargs -I {} basename {} | sed 's/^/   - /')

3. Medical Resources
   Status: $([ -f "../raw/medical/where_there_is_no_doctor.pdf" ] && echo "✓ Downloaded" || echo "✗ Missing")
   
Processed Content:
==================
$([ -d "../processed/core" ] && find ../processed/core -name "*.json" | wc -l || echo "0") article batches
$([ -f "../indexes/articles_for_indexing.jsonl" ] && wc -l < ../indexes/articles_for_indexing.jsonl || echo "0") total articles ready for indexing

Next Steps:
===========
1. Review processing report: ../processed/processing_report.json
2. Build Tantivy indexes
3. Test search functionality
4. Package for mobile apps

Manual Downloads Still Needed:
==============================
- Plant identification database (requires API key)
- Weather pattern data (NOAA access)
- Radio frequency database (RadioReference API)
- OpenStreetMap data (select regions)

EOF

echo -e "${GREEN}✅ Content download complete!${NC}"
echo ""
echo "Download report saved to: ../download_report.txt"
echo ""
echo "Storage usage:"
du -sh ../raw/* 2>/dev/null | sort -h

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Review the download report"
echo "2. Run: cargo run --bin index_builder ../indexes/articles_for_indexing.jsonl"
echo "3. Test search with: cargo run --bin test_search"

# Check for failures
if [ -f download_errors.log ]; then
    echo -e "\n${RED}⚠️  Some downloads failed. Check download_errors.log${NC}"
fi
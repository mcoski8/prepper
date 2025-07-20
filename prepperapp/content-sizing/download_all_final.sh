#!/bin/bash

# PrepperApp Complete Content Download Script
# Downloads ALL content we plan to ship - no estimates, actual downloads only
# Total expected: ~220GB

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== PrepperApp Complete Content Download ===${NC}"
echo "This will download ~220GB of offline survival content"
echo "Ensure you have sufficient storage space!"
echo

# Function to check if we should use external drive
check_storage() {
    # Check for Vid SSD specifically
    if [ -d "/Volumes/Vid SSD" ]; then
        CONTENT_DIR="/Volumes/Vid SSD/PrepperApp-Content"
        echo -e "${GREEN}✅ Using Vid SSD (1TB free): $CONTENT_DIR${NC}"
        
        # Check actual free space
        FREE_SPACE=$(df -h "/Volumes/Vid SSD" | awk 'NR==2 {print $4}')
        echo -e "${GREEN}   Free space available: $FREE_SPACE${NC}"
    else
        echo -e "${RED}❌ Vid SSD not found at /Volumes/Vid SSD${NC}"
        echo "Please ensure your external SSD is connected and mounted"
        echo "Current volumes:"
        ls /Volumes/
        exit 1
    fi
}

# Function to download with progress and resume
download_with_resume() {
    local url=$1
    local output_dir=$2
    local filename=$3
    
    if [ -z "$filename" ]; then
        filename=$(basename "$url")
    fi
    
    if [ -f "$output_dir/$filename" ]; then
        echo "Already have: $filename"
        local size=$(ls -lh "$output_dir/$filename" | awk '{print $5}')
        echo "  Size: $size"
        return 0
    fi
    
    echo "Downloading: $filename"
    echo "  URL: $url"
    # Use curl with resume support (-C -) and progress bar
    curl -L -C - -o "$output_dir/$filename" "$url" || {
        echo -e "${RED}Failed to download $filename${NC}"
        return 1
    }
}

# Check storage and create directories
check_storage
mkdir -p "$CONTENT_DIR"/{wikipedia,medical,survival,plants,maps,repair,homestead,comms,reference,family,pharma,processed}

# Change to content directory
cd "$CONTENT_DIR"

# Create a log file
LOG_FILE="$CONTENT_DIR/download_log.txt"
echo "Download started: $(date)" > "$LOG_FILE"

echo
echo -e "${CYAN}=== 1. Complete Wikipedia (87GB) ===${NC}"
# Full English Wikipedia with images - latest version
download_with_resume \
    "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2024-01.zim" \
    "wikipedia"

echo
echo -e "${CYAN}=== 2. Medical References (15GB) ===${NC}"
# Wikipedia Medicine
download_with_resume \
    "https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2025-07.zim" \
    "medical"

# WikiMed Medical Encyclopedia
download_with_resume \
    "https://download.kiwix.org/zim/wikimed/wikimed_en_all_maxi_2024-10.zim" \
    "medical"

# MedlinePlus
download_with_resume \
    "https://download.kiwix.org/zim/other/medlineplus_en_all_2025-01.zim" \
    "medical"

echo
echo -e "${CYAN}=== 3. Survival & Skills (10GB) ===${NC}"
# WikiHow
download_with_resume \
    "https://download.kiwix.org/zim/wikihow/wikihow_en_maxi_2024-10.zim" \
    "survival"

# Military Manuals
cat > survival/military_manuals.txt << 'EOF'
https://archive.org/download/military-manuals/FM%2021-76%20US%20ARMY%20SURVIVAL%20MANUAL.pdf
https://archive.org/download/military-manuals/FM%203-05.70%20Survival.pdf
https://archive.org/download/military-manuals/FM%204-25.11%20First%20Aid.pdf
https://archive.org/download/military-manuals/FM%2021-10%20Field%20Hygiene%20and%20Sanitation.pdf
https://archive.org/download/military-manuals/FM%2021-11%20First%20Aid%20for%20Soldiers.pdf
https://archive.org/download/military-manuals/TC%203-21.76%20Ranger%20Handbook.pdf
EOF

while read -r url; do
    download_with_resume "$url" "survival"
done < survival/military_manuals.txt

echo
echo -e "${CYAN}=== 4. Plant & Foraging Guides (5GB) ===${NC}"
# Note: USDA Plants Database would need custom scraping
# For now, using available plant resources
echo "Plant database collection requires custom implementation"
echo "Marking for manual download..." >> "$LOG_FILE"

echo
echo -e "${CYAN}=== 5. Maps - US Regions (50GB) ===${NC}"
# OpenStreetMap extracts for major US states
STATES=(
    "california" "texas" "florida" "new-york" "pennsylvania"
    "illinois" "ohio" "georgia" "north-carolina" "michigan"
    "washington" "arizona" "massachusetts" "virginia" "colorado"
)

for state in "${STATES[@]}"; do
    download_with_resume \
        "https://download.geofabrik.de/north-america/us/${state}-latest.osm.pbf" \
        "maps" \
        "${state}.osm.pbf"
done

echo
echo -e "${CYAN}=== 6. Repair & Building (10GB) ===${NC}"
# iFixit
download_with_resume \
    "https://download.kiwix.org/zim/ifixit/ifixit_en_all_2024-10.zim" \
    "repair"

echo
echo -e "${CYAN}=== 7. Homesteading & Agriculture (5GB) ===${NC}"
# Farm and Garden content from appropriate sources
echo "Agriculture content requires aggregation from multiple sources"
echo "Marking for manual collection..." >> "$LOG_FILE"

echo
echo -e "${CYAN}=== 8. Communications (2GB) ===${NC}"
# HAM Radio references
echo "Downloading HAM radio frequency guides..."
# RepeaterBook data would need API access or scraping

echo
echo -e "${CYAN}=== 9. Reference Library (20GB) ===${NC}"
# Project Gutenberg
download_with_resume \
    "https://download.kiwix.org/zim/gutenberg/gutenberg_en_all_2023-08.zim" \
    "reference"

# Wikibooks
download_with_resume \
    "https://download.kiwix.org/zim/wikibooks/wikibooks_en_all_maxi_2024-10.zim" \
    "reference"

# Wikiversity (educational content)
download_with_resume \
    "https://download.kiwix.org/zim/wikiversity/wikiversity_en_all_maxi_2024-10.zim" \
    "reference"

echo
echo -e "${CYAN}=== 10. Family & Child Care (5GB) ===${NC}"
# This would need aggregation from multiple sources
echo "Family care content requires curation"
echo "Sources: CDC child development, Red Cross family prep, etc." >> "$LOG_FILE"

echo
echo -e "${CYAN}=== 11. Pharmaceutical Reference (3GB) ===${NC}"
# FDA Orange Book and DailyMed would need custom download
echo "Pill ID database requires custom implementation"
echo "FDA and NIH data marked for processing..." >> "$LOG_FILE"

echo
echo -e "${GREEN}=== Download Progress Summary ===${NC}"
echo "Calculating sizes..."

# Function to get human-readable size
get_size() {
    local path=$1
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Show sizes for each category
echo
echo "Content downloaded so far:"
for dir in wikipedia medical survival plants maps repair homestead comms reference family pharma; do
    size=$(get_size "$CONTENT_DIR/$dir")
    printf "%-15s: %s\n" "$dir" "$size"
done

# Total size
total_size=$(get_size "$CONTENT_DIR")
echo
echo -e "${YELLOW}Total size: $total_size${NC}"

# Create size report
cat > "$CONTENT_DIR/size_report.txt" << EOF
PrepperApp Content Size Report
Generated: $(date)

Downloaded Content:
$(du -sh "$CONTENT_DIR"/* 2>/dev/null || echo "No content yet")

Total Size: $total_size

Notes:
- Some content requires manual download/curation
- Pill ID database needs custom implementation
- Plant guides need USDA scraping
- Family care content needs aggregation

Next Steps:
1. Complete manual downloads
2. Process content into app-ready format
3. Create search indexes
4. Package into modules
EOF

echo
echo -e "${GREEN}✅ Initial download phase complete!${NC}"
echo "Check size_report.txt for details"
echo "Log file: $LOG_FILE"
echo
echo "Items requiring manual processing:"
echo "- Plant identification guides with images"
echo "- Agriculture/homesteading comprehensive guides"
echo "- Family care resources"
echo "- Pill identification database"
echo "- HAM radio frequency database"
#!/bin/bash

# Download ALL PrepperApp Content - The Complete Knowledge Base
# This downloads EVERYTHING we plan to ship, no estimates

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== PrepperApp Complete Content Download ===${NC}"
echo "Downloading ALL content for offline survival + human knowledge preservation"
echo

# Check available space
echo "Checking disk space..."
df -h | grep -E "easystore|disk3s1"

# Use external drive if available, otherwise local
if [ -d "/Volumes/easystore" ]; then
    CONTENT_DIR="/Volumes/easystore/PrepperApp-Content"
    echo -e "${GREEN}Using external drive: $CONTENT_DIR${NC}"
else
    CONTENT_DIR="$HOME/PrepperApp-Content"
    echo -e "${YELLOW}Using local storage: $CONTENT_DIR${NC}"
fi

# Create directory structure
echo "Creating directories..."
mkdir -p "$CONTENT_DIR"/{wikipedia,medical,survival,maps,reference,images,processed}

# Change to content directory
cd "$CONTENT_DIR"

echo
echo -e "${BLUE}=== 1. FULL Wikipedia (Complete Human Knowledge) ===${NC}"
echo "Downloading the complete Wikipedia with images..."
echo "Expected size: ~87GB (compressed ZIM format)"

# Kiwix Wikipedia downloads
WIKIPEDIA_DOWNLOADS=(
    # Full Wikipedia with images (latest)
    "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2024-01.zim"
    
    # Backup: Wikipedia without images if full is too large
    # "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_nopic_2024-01.zim"
)

for url in "${WIKIPEDIA_DOWNLOADS[@]}"; do
    filename=$(basename "$url")
    if [ ! -f "wikipedia/$filename" ]; then
        echo "Downloading: $filename"
        wget -c -P wikipedia/ "$url" || echo "Failed to download $filename"
    else
        echo "Already have: $filename"
    fi
done

echo
echo -e "${BLUE}=== 2. Medical References ===${NC}"
echo "Downloading medical-specific content..."

# Medical content beyond what we extracted
MEDICAL_DOWNLOADS=(
    # Wikipedia Medicine (detailed medical encyclopedia)
    "https://download.kiwix.org/zim/other/wikipedia_en_medicine_maxi_2025-07.zim"
    
    # WikiMed Medical Encyclopedia
    "https://download.kiwix.org/zim/wikimed/wikimed_en_all_maxi_2025-02.zim"
    
    # Where There Is No Doctor (if available as ZIM)
    # Note: May need to get PDF version and convert
)

for url in "${MEDICAL_DOWNLOADS[@]}"; do
    filename=$(basename "$url")
    if [ ! -f "medical/$filename" ]; then
        echo "Downloading: $filename"
        wget -c -P medical/ "$url" || echo "Failed to download $filename"
    else
        echo "Already have: $filename"
    fi
done

echo
echo -e "${BLUE}=== 3. Survival Manuals ===${NC}"
echo "Downloading military and survival guides..."

# Create survival content list
cat > survival/download_list.txt << 'EOF'
# US Military Field Manuals
https://www.bits.de/NRANEU/others/amd-us-archive/FM21-76%281992%29.pdf|FM_21-76_Survival.pdf
https://www.bits.de/NRANEU/others/amd-us-archive/FM3-05-70%282002%29.pdf|FM_3-05-70_Survival_Evasion_Recovery.pdf
https://www.bits.de/NRANEU/others/amd-us-archive/FM21-10%281988%29.pdf|FM_21-10_Field_Hygiene.pdf
https://www.bits.de/NRANEU/others/amd-us-archive/FM4-25-11%282002%29.pdf|FM_4-25-11_First_Aid.pdf
EOF

# Download survival manuals
while IFS='|' read -r url filename; do
    [[ "$url" =~ ^#.*$ ]] && continue
    [[ -z "$url" ]] && continue
    
    if [ ! -f "survival/$filename" ]; then
        echo "Downloading: $filename"
        wget -c -O "survival/$filename" "$url" || echo "Failed: $filename"
    fi
done < survival/download_list.txt

echo
echo -e "${BLUE}=== 4. OpenStreetMap Data ===${NC}"
echo "Downloading offline maps..."

# Download map data for US regions
# Using Geofabrik extracts
MAP_REGIONS=(
    "north-america/us/california"
    "north-america/us/texas"
    "north-america/us/florida"
    "north-america/us/new-york"
    # Add more states as needed
)

for region in "${MAP_REGIONS[@]}"; do
    filename="${region//\//-}-latest.osm.pbf"
    if [ ! -f "maps/$filename" ]; then
        echo "Downloading map: $region"
        wget -c -P maps/ "https://download.geofabrik.de/${region}-latest.osm.pbf" || echo "Failed: $region"
    fi
done

echo
echo -e "${BLUE}=== 5. Additional References ===${NC}"
echo "Downloading other essential references..."

# Wikibooks survival collection
REFERENCE_DOWNLOADS=(
    # Wikibooks
    "https://download.kiwix.org/zim/wikibooks/wikibooks_en_all_maxi_2025-01.zim"
    
    # Wikivoyage (travel/geography)
    "https://download.kiwix.org/zim/wikivoyage/wikivoyage_en_all_maxi_2025-02.zim"
    
    # Wiktionary (dictionary)
    "https://download.kiwix.org/zim/wiktionary/wiktionary_en_all_maxi_2025-02.zim"
)

for url in "${REFERENCE_DOWNLOADS[@]}"; do
    filename=$(basename "$url")
    if [ ! -f "reference/$filename" ]; then
        echo "Downloading: $filename"
        wget -c -P reference/ "$url" || echo "Failed to download $filename"
    fi
done

echo
echo -e "${BLUE}=== 6. Processing Content ===${NC}"
echo "Now we need to process all this into our delivery format..."

# Create processing script
cat > process_content.py << 'EOF'
#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess

def get_directory_size(path):
    """Get size of directory in GB"""
    result = subprocess.run(['du', '-sh', path], capture_output=True, text=True)
    size_str = result.stdout.split()[0] if result.stdout else "0"
    return size_str

def main():
    content_dir = Path.cwd()
    
    print("\n📊 Content Size Analysis")
    print("="*60)
    
    total_size = 0
    for subdir in ['wikipedia', 'medical', 'survival', 'maps', 'reference']:
        if (content_dir / subdir).exists():
            size = get_directory_size(content_dir / subdir)
            print(f"{subdir.capitalize()}: {size}")
    
    # Get total
    total = get_directory_size(content_dir)
    print(f"\nTOTAL DOWNLOADED: {total}")
    
    print("\n🎯 Next Steps:")
    print("1. Extract and process ZIM files")
    print("2. Convert PDFs to searchable text")
    print("3. Optimize images")
    print("4. Create Tantivy indexes")
    print("5. Package into modules")

if __name__ == "__main__":
    main()
EOF

python3 process_content.py

echo
echo -e "${GREEN}✅ Download complete!${NC}"
echo "Check $CONTENT_DIR for all content"
echo
echo "To see sizes:"
echo "du -sh $CONTENT_DIR/*"
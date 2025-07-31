#!/bin/bash
# Smart download script that checks existing files

set -e

BASE_DIR="${PREPPER_EXTERNAL_CONTENT:-/Volumes/Vid SSD/PrepperApp-Content}"
LOG_FILE="smart_downloads_$(date +%Y%m%d_%H%M%S).log"

echo "PrepperApp Smart Downloader"
echo "==========================="
echo "Base directory: $BASE_DIR"
echo

# Function to check if file exists with reasonable size
file_exists() {
    local filepath="$1"
    local min_size="$2"
    
    if [ -f "$filepath" ]; then
        size=$(du -k "$filepath" 2>/dev/null | cut -f1)
        if [ "$size" -gt "$min_size" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to download if missing
download_if_missing() {
    local url="$1"
    local category="$2"
    local filename="$3"
    local description="$4"
    local min_size_kb="$5"
    
    local filepath="$BASE_DIR/$category/$filename"
    
    if file_exists "$filepath" "$min_size_kb"; then
        echo "✓ Already have: $description ($(du -h "$filepath" | cut -f1))"
        return 0
    fi
    
    echo "✗ Missing: $description"
    echo "  Downloading from: $url"
    
    mkdir -p "$BASE_DIR/$category"
    
    if command -v wget >/dev/null 2>&1; then
        wget -c "$url" -O "$filepath" 2>&1 | tee -a "$LOG_FILE"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -C - "$url" -o "$filepath" 2>&1 | tee -a "$LOG_FILE"
    else
        echo "ERROR: Neither wget nor curl found"
        return 1
    fi
    
    echo "✓ Downloaded: $filename"
    echo
}

echo "Checking existing content..."
echo

# Check what we already have
echo "=== ALREADY DOWNLOADED ==="
[ -f "$BASE_DIR/wikipedia/wikipedia_en_all_maxi_2024-01.zim" ] && echo "✓ Wikipedia Full (102GB)"
[ -f "$BASE_DIR/medical/wikipedia_en_medicine_maxi_2025-07.zim" ] && echo "✓ Wikipedia Medical (2GB)"
[ -f "$BASE_DIR/gutenberg_en_all_2023-08.zim" ] && echo "✓ Project Gutenberg (65GB)"
[ -f "$BASE_DIR/repair/ifixit_en_all_2025-06.zim" ] && echo "✓ iFixit Repair Guides (1.2GB)"
[ -f "$BASE_DIR/survival/zimgit-post-disaster_en_2024-05.zim" ] && echo "✓ Post-disaster Guide (615MB)"
[ -f "$BASE_DIR/survival/zimgit-water_en_2024-08.zim" ] && echo "✓ Water Purification (20MB)"
[ -f "$BASE_DIR/survival/zimgit-medicine_en_2024-08.zim" ] && echo "✓ Medicine Collection (67MB)"

echo
echo "=== CHECKING FOR MISSING CONTENT ==="

# Content to download with minimum sizes in KB
# Format: URL|Category|Filename|Description|MinSizeKB

DOWNLOADS=(
    "https://download.kiwix.org/zim/wikiversity/wikiversity_en_all_nopic_2025-06.zim|education|wikiversity_en_all_nopic_2025-06.zim|Wikiversity Education (1.5GB)|1000000"
    "https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2025-05.zim|homesteading|appropedia_en_all_maxi_2025-05.zim|Appropedia Sustainability (200MB)|100000"
    "https://download.kiwix.org/zim/wikibooks/wikibooks_en_all_maxi_2025-06.zim|reference|wikibooks_en_all_maxi_2025-06.zim|Wikibooks How-to (4.3GB)|4000000"
    "https://download.kiwix.org/zim/wikihow/wikihow_en_maxi_2025-06.zim|howto|wikihow_en_maxi_2025-06.zim|WikiHow Instructions (10GB)|9000000"
    "https://download.kiwix.org/zim/other/energypedia_en_all_maxi_2025-06.zim|energy|energypedia_en_all_maxi_2025-06.zim|Energypedia Off-grid (100MB)|50000"
    "https://download.geofabrik.de/north-america-latest.osm.pbf|maps|north-america-latest.osm.pbf|OSM North America (12GB)|10000000"
    "https://download.geofabrik.de/europe-latest.osm.pbf|maps|europe-latest.osm.pbf|OSM Europe (25GB)|20000000"
    "https://download.geofabrik.de/asia-latest.osm.pbf|maps|asia-latest.osm.pbf|OSM Asia (11GB)|10000000"
    "https://download.geofabrik.de/south-america-latest.osm.pbf|maps|south-america-latest.osm.pbf|OSM South America (2.5GB)|2000000"
    "https://download.geofabrik.de/africa-latest.osm.pbf|maps|africa-latest.osm.pbf|OSM Africa (3.5GB)|3000000"
    "https://download.geofabrik.de/australia-oceania-latest.osm.pbf|maps|australia-oceania-latest.osm.pbf|OSM Australia/Oceania (1GB)|900000"
)

# Process each download
for item in "${DOWNLOADS[@]}"; do
    IFS='|' read -r url category filename description min_size <<< "$item"
    download_if_missing "$url" "$category" "$filename" "$description" "$min_size"
done

echo
echo "=== SUMMARY ==="
echo "Check log for details: $LOG_FILE"
echo "Total space used: $(du -sh "$BASE_DIR" 2>/dev/null | cut -f1)"
echo
echo "Tip: Run this script again to resume any interrupted downloads"
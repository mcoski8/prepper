#!/bin/bash
# Download missing content using curl

BASE_DIR="${PREPPER_EXTERNAL_CONTENT:-/Volumes/Vid SSD/PrepperApp-Content}"
LOG_FILE="downloads_$(date +%Y%m%d_%H%M%S).log"

echo "PrepperApp Essential Downloads (using curl)"
echo "=========================================="
echo "Log: $LOG_FILE"
echo

# Create directories
mkdir -p "$BASE_DIR"/{homesteading,energy,maps}

# Function to download with curl and progress
download_with_progress() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    echo "----------------------------------------"
    echo "Downloading: $description"
    echo "URL: $url"
    echo "To: $output"
    echo
    
    # Use curl with progress bar and resume support
    curl -L -C - --progress-bar "$url" -o "$output" 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        echo "✓ Success: $description"
    else
        echo "✗ Failed: $description"
    fi
    echo
}

# Start downloads
echo "Starting downloads..." | tee -a "$LOG_FILE"

# Small files first
download_with_progress \
    "https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2025-05.zim" \
    "$BASE_DIR/homesteading/appropedia_en_all_maxi_2025-05.zim" \
    "Appropedia Sustainability Guide (200MB)"

download_with_progress \
    "https://download.kiwix.org/zim/other/energypedia_en_all_maxi_2025-06.zim" \
    "$BASE_DIR/energy/energypedia_en_all_maxi_2025-06.zim" \
    "Energypedia Off-grid Energy (100MB)"

# Large file
echo "Note: The next download is 12GB and will take significant time..." | tee -a "$LOG_FILE"
download_with_progress \
    "https://download.geofabrik.de/north-america-latest.osm.pbf" \
    "$BASE_DIR/maps/north-america-latest.osm.pbf" \
    "OpenStreetMap North America (12GB)"

echo "=========================================="
echo "Download session complete!"
echo "Check log: $LOG_FILE"
echo
echo "To monitor downloads in progress:"
echo "  tail -f $LOG_FILE"
echo
echo "To check download status:"
echo "  ./check_missing.sh"
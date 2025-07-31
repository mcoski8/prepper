#!/bin/bash
# Simple download script using wget for PrepperApp content

set -e

# Configuration
BASE_DIR="${PREPPER_EXTERNAL_CONTENT:-/Volumes/Vid SSD/PrepperApp-Content}"
LOG_FILE="downloads_$(date +%Y%m%d_%H%M%S).log"

# Create directories
mkdir -p "$BASE_DIR"/{repair,education,homesteading,reference,howto,energy,maps,medical,military}

echo "Starting PrepperApp content downloads..."
echo "Base directory: $BASE_DIR"
echo "Log file: $LOG_FILE"
echo

# Function to download with progress
download_file() {
    local url="$1"
    local category="$2"
    local filename="$3"
    local description="$4"
    
    echo "----------------------------------------"
    echo "Downloading: $description"
    echo "Category: $category"
    echo "Filename: $filename"
    
    # Use wget with continue support
    if command -v wget >/dev/null 2>&1; then
        wget -c "$url" -O "$BASE_DIR/$category/$filename" 2>&1 | tee -a "$LOG_FILE"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -C - "$url" -o "$BASE_DIR/$category/$filename" 2>&1 | tee -a "$LOG_FILE"
    else
        echo "ERROR: Neither wget nor curl found. Please install one:"
        echo "  brew install wget"
        return 1
    fi
    
    echo "✓ Completed: $filename" | tee -a "$LOG_FILE"
    echo
}

# Start downloads - Tier 1 (Critical) first
echo "=== TIER 1 - CRITICAL CONTENT ===" | tee -a "$LOG_FILE"

download_file \
    "https://store.hesperian.org/prod/downloads/B010R_wtnd_2021.pdf" \
    "medical" \
    "where_there_is_no_doctor.pdf" \
    "Where There Is No Doctor"

download_file \
    "https://store.hesperian.org/prod/downloads/B012R_wtndentist_2021.pdf" \
    "medical" \
    "where_there_is_no_dentist.pdf" \
    "Where There Is No Dentist"

download_file \
    "https://archive.org/download/FM21-76SurvivalManual/FM21-76.pdf" \
    "military" \
    "FM21-76_SurvivalManual.pdf" \
    "US Army Survival Manual FM 21-76"

download_file \
    "https://archive.org/download/FirstAidTC4-02.1/TC_4-02.1.pdf" \
    "military" \
    "TC_4-02.1_FirstAid.pdf" \
    "US Army First Aid Manual"

# Tier 2 - Essential
echo "=== TIER 2 - ESSENTIAL CONTENT ===" | tee -a "$LOG_FILE"

download_file \
    "https://download.kiwix.org/zim/ifixit/ifixit_en_all_2025-06.zim" \
    "repair" \
    "ifixit_en_all_2025-06.zim" \
    "iFixit Repair Guides (3.2GB)"

download_file \
    "https://download.kiwix.org/zim/wikiversity/wikiversity_en_all_nopic_2025-06.zim" \
    "education" \
    "wikiversity_en_all_nopic_2025-06.zim" \
    "Wikiversity Educational Content (1.5GB)"

download_file \
    "https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2025-05.zim" \
    "homesteading" \
    "appropedia_en_all_maxi_2025-05.zim" \
    "Appropedia Sustainability (200MB)"

download_file \
    "https://download.kiwix.org/zim/other/energypedia_en_all_maxi_2025-06.zim" \
    "energy" \
    "energypedia_en_all_maxi_2025-06.zim" \
    "Energypedia Off-grid Energy (100MB)"

# Maps
echo "=== TIER 2/3 - MAP DATA ===" | tee -a "$LOG_FILE"

download_file \
    "https://download.geofabrik.de/north-america-latest.osm.pbf" \
    "maps" \
    "north-america-latest.osm.pbf" \
    "OpenStreetMap North America (12GB)"

# Add more as needed...

echo "----------------------------------------"
echo "Download session complete!"
echo "Check log file for details: $LOG_FILE"
echo "Run again to resume any interrupted downloads"
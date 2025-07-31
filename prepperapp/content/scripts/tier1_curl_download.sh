#!/bin/bash
# Safe download script for Tier 1 content using curl
# Avoids SSL certificate issues and Claude Code crashes

# Check environment variable
if [ -z "$PREPPER_EXTERNAL_CONTENT" ]; then
    echo "ERROR: PREPPER_EXTERNAL_CONTENT not set"
    echo "Please run: export PREPPER_EXTERNAL_CONTENT='/Volumes/Vid SSD/prepperapp-content'"
    exit 1
fi

# Create directories
echo "Creating content directories..."
mkdir -p "$PREPPER_EXTERNAL_CONTENT"/{medical,survival,energy,homesteading,plants,communications}

echo "PrepperApp Tier 1 Content Downloader (curl version)"
echo "============================================================"
echo "External content: $PREPPER_EXTERNAL_CONTENT"
echo "This will download critical survival content"
echo "============================================================"

# Function to download with progress
download_file() {
    local url="$1"
    local dest="$2"
    local desc="$3"
    
    # Check if already exists
    if [ -f "$dest" ]; then
        echo "✓ Already downloaded: $desc"
        return 0
    fi
    
    echo ""
    echo "Downloading: $desc"
    echo "URL: $url"
    echo "Destination: $dest"
    
    # Download with curl (ignoring SSL for now)
    if curl -k -L -# -o "$dest" "$url"; then
        echo "✓ Completed: $desc"
        return 0
    else
        echo "✗ Failed: $desc"
        return 1
    fi
}

# Critical downloads
echo ""
echo "Starting critical downloads..."

# Wikipedia Medical (2GB)
download_file \
    "https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2025-07.zim" \
    "$PREPPER_EXTERNAL_CONTENT/medical/wikipedia_en_medicine_maxi_2025-07.zim" \
    "Wikipedia Medical Maxi (2.0GB)"

# Appropedia (1.1GB)
download_file \
    "https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2025-05.zim" \
    "$PREPPER_EXTERNAL_CONTENT/homesteading/appropedia_en_all_maxi_2025-05.zim" \
    "Appropedia - Appropriate Technology (1.1GB)"

# USDA Plant Databases
download_file \
    "https://plants.usda.gov/assets/docs/CompletePLANTSList/plantlst.txt" \
    "$PREPPER_EXTERNAL_CONTENT/plants/usda_plantlst.txt" \
    "USDA Plants List"

download_file \
    "https://plants.usda.gov/assets/docs/CompletePLANTSList/CompleteCharacteristics.csv" \
    "$PREPPER_EXTERNAL_CONTENT/plants/usda_characteristics.csv" \
    "USDA Plant Characteristics"

# Poisonous Plants Guide
download_file \
    "https://www.ars.usda.gov/ARSUserFiles/oc/np/PoisonousPlants/PoisonousPlants.pdf" \
    "$PREPPER_EXTERNAL_CONTENT/plants/PoisonousPlants.pdf" \
    "USDA Poisonous Plants Guide (Critical)"

# FCC Amateur Radio Database
download_file \
    "https://data.fcc.gov/download/public/uls/complete/l_amat.zip" \
    "$PREPPER_EXTERNAL_CONTENT/communications/fcc_amateur_radio.zip" \
    "FCC Amateur Radio Database (150MB)"

# Where There Is No Doctor/Dentist
download_file \
    "https://store.hesperian.org/prod/downloads/B010R_wtnd_2021.pdf" \
    "$PREPPER_EXTERNAL_CONTENT/medical/where_there_is_no_doctor.pdf" \
    "Where There Is No Doctor (50MB)"

download_file \
    "https://store.hesperian.org/prod/downloads/B012R_wtndentist_2021.pdf" \
    "$PREPPER_EXTERNAL_CONTENT/medical/where_there_is_no_dentist.pdf" \
    "Where There Is No Dentist (50MB)"

echo ""
echo "============================================================"
echo "Download Summary"
echo "============================================================"
echo "Check downloaded files:"
echo ""

# Show what we have
find "$PREPPER_EXTERNAL_CONTENT" -type f -name "*.zim" -o -name "*.pdf" -o -name "*.zip" | while read -r file; do
    size=$(du -h "$file" | cut -f1)
    name=$(basename "$file")
    echo "$size - $name"
done

echo ""
echo "Next steps:"
echo "1. Extract FCC amateur radio database"
echo "2. Process USDA plant data for app"
echo "3. Set up WikiHow content acquisition"
echo "4. Create quick reference cards"
echo ""
echo "WikiHow Note: Requires manual curation or partnership"
echo "Contact: content-partnerships@wikihow.com"
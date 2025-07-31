#!/bin/bash
# Quick check for missing content

BASE_DIR="${PREPPER_EXTERNAL_CONTENT:-/Volumes/Vid SSD/PrepperApp-Content}"

echo "PrepperApp Content Status Check"
echo "==============================="
echo

# Function to check file
check_file() {
    local path="$1"
    local name="$2"
    local expected_size="$3"
    
    if [ -f "$BASE_DIR/$path" ]; then
        size=$(du -h "$BASE_DIR/$path" 2>/dev/null | cut -f1)
        echo "✓ $name ($size)"
    else
        echo "✗ $name (need $expected_size)"
    fi
}

echo "=== TIER 1 - CRITICAL (72hr) ==="
check_file "survival/zimgit-post-disaster_en_2024-05.zim" "Post-disaster Guide" "615MB"
check_file "survival/zimgit-water_en_2024-08.zim" "Water Purification" "20MB"
check_file "survival/zimgit-medicine_en_2024-08.zim" "Medicine Collection" "67MB"
check_file "medical/wikipedia_en_medicine_maxi_2025-07.zim" "Wikipedia Medical" "2GB"
check_file "medical/where_there_is_no_doctor.pdf" "Where No Doctor" "50MB"
check_file "medical/where_there_is_no_dentist.pdf" "Where No Dentist" "50MB"

echo
echo "=== TIER 2 - ESSENTIAL ==="
check_file "repair/ifixit_en_all_2025-06.zim" "iFixit Repair" "3.2GB"
check_file "education/wikiversity_en_all_nopic_2025-06.zim" "Wikiversity" "1.5GB"
check_file "homesteading/appropedia_en_all_maxi_2025-05.zim" "Appropedia" "200MB"
check_file "energy/energypedia_en_all_maxi_2025-06.zim" "Energypedia" "100MB"
check_file "maps/north-america-latest.osm.pbf" "OSM North America" "12GB"

echo
echo "=== TIER 3 - COMPREHENSIVE ==="
check_file "wikipedia/wikipedia_en_all_maxi_2024-01.zim" "Wikipedia Full" "102GB"
check_file "reference/wikibooks_en_all_maxi_2025-06.zim" "Wikibooks" "4.3GB"
check_file "howto/wikihow_en_maxi_2025-06.zim" "WikiHow" "10GB"
check_file "maps/europe-latest.osm.pbf" "OSM Europe" "25GB"
check_file "maps/asia-latest.osm.pbf" "OSM Asia" "11GB"

echo
echo "=== BONUS CONTENT ==="
check_file "gutenberg_en_all_2023-08.zim" "Project Gutenberg" "65GB"

echo
echo "Total space used: $(du -sh "$BASE_DIR" 2>/dev/null | cut -f1)"
echo "Available space: $(df -H "$BASE_DIR" | awk 'NR==2 {print $4}')"
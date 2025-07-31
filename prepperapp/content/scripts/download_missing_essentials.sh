#!/bin/bash
# Download only missing essential content

BASE_DIR="${PREPPER_EXTERNAL_CONTENT:-/Volumes/Vid SSD/PrepperApp-Content}"

echo "Downloading Missing Essential Content"
echo "===================================="
echo

# Create directories
mkdir -p "$BASE_DIR"/{homesteading,energy,maps}

# Download missing Tier 2 essentials
echo "1. Downloading Appropedia (200MB)..."
wget -c "https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2025-05.zim" \
     -O "$BASE_DIR/homesteading/appropedia_en_all_maxi_2025-05.zim"

echo
echo "2. Downloading Energypedia (100MB)..."
wget -c "https://download.kiwix.org/zim/other/energypedia_en_all_maxi_2025-06.zim" \
     -O "$BASE_DIR/energy/energypedia_en_all_maxi_2025-06.zim"

echo
echo "3. Downloading OSM North America (12GB)..."
echo "This is a large file and will take some time..."
wget -c "https://download.geofabrik.de/north-america-latest.osm.pbf" \
     -O "$BASE_DIR/maps/north-america-latest.osm.pbf"

echo
echo "Essential downloads complete!"
echo "You now have all Tier 1 and most Tier 2 content."
echo
echo "Optional downloads you can get later:"
echo "- Wikibooks (4.3GB)"
echo "- WikiHow (10GB)"
echo "- OSM maps for other continents"
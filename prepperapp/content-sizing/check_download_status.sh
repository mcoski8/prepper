#!/bin/bash

# Check download status for PrepperApp content

CONTENT_DIR="/Volumes/Vid SSD/PrepperApp-Content"

echo "=== PrepperApp Content Download Status ==="
echo "Location: $CONTENT_DIR"
echo

# Check if download is still running
if pgrep -f "curl.*wikipedia_en_all_maxi" > /dev/null; then
    echo "📥 Wikipedia download is ACTIVE"
else
    echo "⏸️  Wikipedia download is NOT running"
fi

echo
echo "=== Current Content Sizes ==="

# Function to show directory size
show_size() {
    local dir=$1
    local name=$2
    if [ -d "$CONTENT_DIR/$dir" ] && [ "$(ls -A "$CONTENT_DIR/$dir" 2>/dev/null)" ]; then
        local size=$(du -sh "$CONTENT_DIR/$dir" 2>/dev/null | cut -f1)
        local files=$(find "$CONTENT_DIR/$dir" -type f | wc -l | tr -d ' ')
        printf "%-15s: %8s (%s files)\n" "$name" "$size" "$files"
    else
        printf "%-15s: %8s\n" "$name" "empty"
    fi
}

show_size "wikipedia" "Wikipedia"
show_size "medical" "Medical"
show_size "survival" "Survival"
show_size "plants" "Plants"
show_size "maps" "Maps"
show_size "repair" "Repair"
show_size "homestead" "Homesteading"
show_size "comms" "Communications"
show_size "reference" "Reference"
show_size "family" "Family Care"
show_size "pharma" "Pharmaceuticals"

echo
echo "=== Total Space Used ==="
total_size=$(du -sh "$CONTENT_DIR" 2>/dev/null | cut -f1)
echo "Total: $total_size"

echo
echo "=== Available Space ==="
df -h "/Volumes/Vid SSD" | awk 'NR==2 {print "Free: " $4 " of " $2}'

# Show active downloads
echo
echo "=== Active Downloads ==="
for file in "$CONTENT_DIR"/*/*.zim; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "$filename: $size"
    fi
done

echo
echo "To resume downloads, run: ./content-sizing/download_all_final.sh"
echo "The script will skip already downloaded files."
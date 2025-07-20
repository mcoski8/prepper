#!/bin/bash

# Background download script that won't timeout
# Runs downloads in background and logs progress

CONTENT_DIR="/Volumes/Vid SSD/PrepperApp-Content"
LOG_FILE="$CONTENT_DIR/download_log.txt"

# Function to download with logging
download_with_log() {
    local url=$1
    local dir=$2
    local name=$3
    
    echo "[$(date)] Starting download: $name" >> "$LOG_FILE"
    nohup curl -L -C - -o "$CONTENT_DIR/$dir/$name" "$url" >> "$LOG_FILE" 2>&1 &
    echo $! > "$CONTENT_DIR/$dir/${name}.pid"
    echo "[$(date)] Download PID: $! for $name" >> "$LOG_FILE"
}

# Start remaining downloads
echo "[$(date)] === Starting background downloads ===" >> "$LOG_FILE"

# 1. Wikipedia - already partially downloaded, will resume
if [ -f "$CONTENT_DIR/wikipedia/wikipedia_en_all_maxi_2024-01.zim" ]; then
    SIZE=$(ls -lh "$CONTENT_DIR/wikipedia/wikipedia_en_all_maxi_2024-01.zim" | awk '{print $5}')
    echo "[$(date)] Wikipedia already at: $SIZE" >> "$LOG_FILE"
    if [[ "$SIZE" != *"G" ]] || [[ "${SIZE%G}" -lt "80" ]]; then
        echo "[$(date)] Resuming Wikipedia download..." >> "$LOG_FILE"
        download_with_log \
            "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2024-01.zim" \
            "wikipedia" \
            "wikipedia_en_all_maxi_2024-01.zim"
    fi
fi

# 2. Medical References
if [ ! -f "$CONTENT_DIR/medical/wikipedia_en_medicine_maxi_2025-07.zim" ]; then
    download_with_log \
        "https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2025-07.zim" \
        "medical" \
        "wikipedia_en_medicine_maxi_2025-07.zim"
fi

if [ ! -f "$CONTENT_DIR/medical/wikimed_en_all_maxi_2024-10.zim" ]; then
    download_with_log \
        "https://download.kiwix.org/zim/wikimed/wikimed_en_all_maxi_2024-10.zim" \
        "medical" \
        "wikimed_en_all_maxi_2024-10.zim"
fi

# 3. Survival & Skills
if [ ! -f "$CONTENT_DIR/survival/wikihow_en_maxi_2024-10.zim" ]; then
    download_with_log \
        "https://download.kiwix.org/zim/wikihow/wikihow_en_maxi_2024-10.zim" \
        "survival" \
        "wikihow_en_maxi_2024-10.zim"
fi

# 4. Reference Library
if [ ! -f "$CONTENT_DIR/reference/gutenberg_en_all_2023-08.zim" ]; then
    download_with_log \
        "https://download.kiwix.org/zim/gutenberg/gutenberg_en_all_2023-08.zim" \
        "reference" \
        "gutenberg_en_all_2023-08.zim"
fi

if [ ! -f "$CONTENT_DIR/reference/wikibooks_en_all_maxi_2024-10.zim" ]; then
    download_with_log \
        "https://download.kiwix.org/zim/wikibooks/wikibooks_en_all_maxi_2024-10.zim" \
        "reference" \
        "wikibooks_en_all_maxi_2024-10.zim"
fi

# 5. Repair guides
if [ ! -f "$CONTENT_DIR/repair/ifixit_en_all_2024-10.zim" ]; then
    download_with_log \
        "https://download.kiwix.org/zim/ifixit/ifixit_en_all_2024-10.zim" \
        "repair" \
        "ifixit_en_all_2024-10.zim"
fi

echo "[$(date)] All downloads started in background" >> "$LOG_FILE"
echo "[$(date)] Check individual .pid files to monitor processes" >> "$LOG_FILE"

# Create status script
cat > "$CONTENT_DIR/check_downloads.sh" << 'EOF'
#!/bin/bash
echo "=== Download Status ==="
for pidfile in /Volumes/Vid\ SSD/PrepperApp-Content/*/*.pid; do
    if [ -f "$pidfile" ]; then
        PID=$(cat "$pidfile")
        FILENAME=$(basename "${pidfile%.pid}")
        if ps -p $PID > /dev/null; then
            echo "✓ ACTIVE: $FILENAME (PID: $PID)"
        else
            echo "✗ STOPPED: $FILENAME"
            rm "$pidfile"
        fi
    fi
done

echo
echo "=== Current Sizes ==="
du -sh /Volumes/Vid\ SSD/PrepperApp-Content/*/ 2>/dev/null | grep -v "/$"
EOF

chmod +x "$CONTENT_DIR/check_downloads.sh"

echo "Downloads started in background!"
echo "To check status: $CONTENT_DIR/check_downloads.sh"
echo "To view logs: tail -f $LOG_FILE"
#!/bin/bash

# Monitor download progress with better formatting

CONTENT_DIR="/Volumes/Vid SSD/PrepperApp-Content"

while true; do
    clear
    echo "=== PrepperApp Content Download Monitor ==="
    echo "Time: $(date)"
    echo
    
    # Check active downloads
    echo "📥 Active Downloads:"
    ps aux | grep -E "curl.*zim" | grep -v grep | while read line; do
        PID=$(echo $line | awk '{print $2}')
        FILE=$(echo $line | grep -o '[^/]*\.zim' | head -1)
        echo "  ✓ $FILE (PID: $PID)"
    done
    
    echo
    echo "📊 Current Sizes:"
    
    # Show sizes with progress
    for dir in wikipedia medical survival plants maps repair homestead comms reference family pharma; do
        if [ -d "$CONTENT_DIR/$dir" ]; then
            SIZE=$(du -sh "$CONTENT_DIR/$dir" 2>/dev/null | cut -f1)
            FILES=$(find "$CONTENT_DIR/$dir" -name "*.zim" -o -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
            
            # Check for in-progress downloads
            PARTIAL=$(find "$CONTENT_DIR/$dir" -name "*.zim" -size +100M 2>/dev/null | wc -l | tr -d ' ')
            
            if [ "$FILES" -gt 0 ]; then
                if [ "$PARTIAL" -gt 0 ]; then
                    printf "  %-15s: %8s (%d files, downloading...)\n" "$dir" "$SIZE" "$FILES"
                else
                    printf "  %-15s: %8s (%d files)\n" "$dir" "$SIZE" "$FILES"
                fi
            fi
        fi
    done
    
    echo
    echo "💾 Total Space Used:"
    TOTAL=$(du -sh "$CONTENT_DIR" 2>/dev/null | cut -f1)
    echo "  $TOTAL"
    
    echo
    echo "💿 Available Space:"
    df -h "/Volumes/Vid SSD" | awk 'NR==2 {print "  Free: " $4 " of " $2}'
    
    echo
    echo "Press Ctrl+C to exit"
    sleep 10
done
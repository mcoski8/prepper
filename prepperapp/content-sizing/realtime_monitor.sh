#!/bin/bash

# Real-time download monitor for PrepperApp content
# Shows percentages, speeds, and ETAs for all downloads
# Compatible with bash 3.2 (macOS default)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Content directory
CONTENT_DIR="/Volumes/Vid SSD/PrepperApp-Content"

# Function to get expected size for a given filename
get_expected_size() {
    local filename="$1"
    local size=0
    
    case "$filename" in
        "wikipedia_en_all_maxi_2024-01.zim")
            size=87
            ;;
        "wikipedia_en_medicine_maxi_2025-07.zim")
            size=2
            ;;
        "wikimed_en_all_maxi_2024-10.zim")
            size=13
            ;;
        "medlineplus_en_all_2025-01.zim")
            size=0.5
            ;;
        "wikihow_en_maxi_2024-10.zim")
            size=10
            ;;
        "gutenberg_en_all_2023-08.zim")
            size=71
            ;;
        "wikibooks_en_all_maxi_2024-10.zim")
            size=4
            ;;
        "wikiversity_en_all_maxi_2024-10.zim")
            size=1
            ;;
        "ifixit_en_all_2024-10.zim")
            size=10
            ;;
        *)
            size=0
            ;;
    esac
    
    echo "$size"
}

# List of all expected files
get_all_files() {
    echo "wikipedia_en_all_maxi_2024-01.zim"
    echo "wikipedia_en_medicine_maxi_2025-07.zim"
    echo "wikimed_en_all_maxi_2024-10.zim"
    echo "medlineplus_en_all_2025-01.zim"
    echo "wikihow_en_maxi_2024-10.zim"
    echo "gutenberg_en_all_2023-08.zim"
    echo "wikibooks_en_all_maxi_2024-10.zim"
    echo "wikiversity_en_all_maxi_2024-10.zim"
    echo "ifixit_en_all_2024-10.zim"
}

# Function to get file size in GB
get_size_gb() {
    local file="$1"
    if [ -f "$file" ]; then
        local size_bytes=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
        if command -v bc >/dev/null 2>&1; then
            echo "scale=2; $size_bytes / 1073741824" | bc
        else
            # Fallback if bc is not available
            echo $((size_bytes / 1073741824))
        fi
    else
        echo "0"
    fi
}

# Function to format time
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    
    if [ $hours -gt 24 ]; then
        local days=$((hours / 24))
        echo "${days}d ${hours%24}h"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Function to draw progress bar
draw_progress_bar() {
    local percent=$1
    local width=30
    
    if command -v bc >/dev/null 2>&1; then
        local filled=$(printf "%.0f" $(echo "$percent * $width / 100" | bc))
    else
        local filled=$((percent * width / 100))
    fi
    
    local empty=$((width - filled))
    
    printf "["
    if [ $filled -gt 0 ]; then
        printf "%${filled}s" | tr ' ' '█'
    fi
    if [ $empty -gt 0 ]; then
        printf "%${empty}s" | tr ' ' '░'
    fi
    printf "]"
}

# Main monitoring loop
while true; do
    clear
    echo -e "${BOLD}${BLUE}═══ PrepperApp Content Download Monitor ═══${NC}"
    echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "Storage: $CONTENT_DIR"
    echo
    
    # Track totals
    TOTAL_DOWNLOADED=0
    TOTAL_EXPECTED=220
    ACTIVE_COUNT=0
    
    echo -e "${BOLD}Active Downloads:${NC}"
    echo "─────────────────────────────────────────────────────────────────────"
    
    # Check each expected file
    get_all_files | while read filename; do
        expected_gb=$(get_expected_size "$filename")
        
        # Find the file in any subdirectory
        filepath=$(find "$CONTENT_DIR" -name "$filename" -type f 2>/dev/null | head -1)
        
        if [ -n "$filepath" ]; then
            current_gb=$(get_size_gb "$filepath")
            
            # Check if actively downloading
            if pgrep -f "curl.*$filename" > /dev/null 2>&1; then
                ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
                
                # Calculate percentage
                if [ "$expected_gb" != "0" ]; then
                    if command -v bc >/dev/null 2>&1; then
                        percent=$(echo "scale=1; $current_gb * 100 / $expected_gb" | bc)
                    else
                        # Integer math with one decimal approximation
                        percent_int=$((current_gb * 1000 / expected_gb))
                        percent="$((percent_int / 10)).$((percent_int % 10))"
                    fi
                else
                    percent="0"
                fi
                
                # Display with color
                printf "${GREEN}● %-40s${NC} " "${filename:0:40}"
                printf "%6.1f/%-5.0fGB " "$current_gb" "$expected_gb"
                draw_progress_bar "${percent%.*}"
                printf " %5s%% " "$percent"
                printf "${CYAN}%-10s${NC} " "downloading"
                printf "\n"
                
            else
                # File exists but not downloading
                # Check if file is complete (within 95% of expected size)
                if command -v bc >/dev/null 2>&1; then
                    is_complete=$(echo "$current_gb >= $expected_gb * 0.95" | bc -l)
                else
                    # Integer math fallback
                    threshold=$((expected_gb * 95 / 100))
                    if [ $current_gb -ge $threshold ]; then
                        is_complete=1
                    else
                        is_complete=0
                    fi
                fi
                
                if [ "$is_complete" = "1" ]; then
                    # Complete (within 95% of expected size)
                    printf "${GREEN}✓ %-40s${NC} " "${filename:0:40}"
                    printf "%6.1fGB ${GREEN}COMPLETE${NC}\n" "$current_gb"
                else
                    # Incomplete
                    if command -v bc >/dev/null 2>&1; then
                        percent=$(echo "scale=1; $current_gb * 100 / $expected_gb" | bc)
                    else
                        percent_int=$((current_gb * 1000 / expected_gb))
                        percent="$((percent_int / 10)).$((percent_int % 10))"
                    fi
                    printf "${YELLOW}⏸ %-40s${NC} " "${filename:0:40}"
                    printf "%6.1f/%-5.0fGB " "$current_gb" "$expected_gb"
                    draw_progress_bar "${percent%.*}"
                    printf " %5s%% ${YELLOW}PAUSED${NC}\n" "$percent"
                fi
            fi
            
            # Add to total
            if command -v bc >/dev/null 2>&1; then
                TOTAL_DOWNLOADED=$(echo "$TOTAL_DOWNLOADED + $current_gb" | bc)
            else
                TOTAL_DOWNLOADED=$((TOTAL_DOWNLOADED + current_gb))
            fi
        else
            # File doesn't exist yet
            printf "${RED}✗ %-40s${NC} " "${filename:0:40}"
            printf "%6s/%-5.0fGB ${RED}NOT STARTED${NC}\n" "0" "$expected_gb"
        fi
    done
    
    echo "─────────────────────────────────────────────────────────────────────"
    
    # Summary statistics
    echo
    echo -e "${BOLD}Summary:${NC}"
    if command -v bc >/dev/null 2>&1; then
        overall_percent=$(echo "scale=1; $TOTAL_DOWNLOADED * 100 / $TOTAL_EXPECTED" | bc)
    else
        percent_int=$((TOTAL_DOWNLOADED * 1000 / TOTAL_EXPECTED))
        overall_percent="$((percent_int / 10)).$((percent_int % 10))"
    fi
    printf "Total Progress: %.1f GB / %d GB " "$TOTAL_DOWNLOADED" "$TOTAL_EXPECTED"
    draw_progress_bar "${overall_percent%.*}"
    printf " %s%%\n" "$overall_percent"
    
    echo "Active Downloads: $ACTIVE_COUNT"
    
    # Disk space check
    if [ -d "/Volumes/Vid SSD" ]; then
        FREE_SPACE=$(df -h "/Volumes/Vid SSD" | awk 'NR==2 {print $4}')
        USED_PERCENT=$(df -h "/Volumes/Vid SSD" | awk 'NR==2 {print $5}')
        echo "Disk Space Free: $FREE_SPACE (Used: $USED_PERCENT)"
    fi
    
    # Additional files not in expected list
    echo
    echo -e "${BOLD}Other Downloads:${NC}"
    find "$CONTENT_DIR" -name "*.zim" -o -name "*.pdf" -o -name "*.pbf" 2>/dev/null | while read -r file; do
        basename_file=$(basename "$file")
        # Check if it's not in our list
        is_expected=0
        get_all_files | while read expected; do
            if [ "$basename_file" = "$expected" ]; then
                is_expected=1
                break
            fi
        done
        
        if [ $is_expected -eq 0 ]; then
            size=$(ls -lh "$file" | awk '{print $5}')
            echo "  • $basename_file: $size"
        fi
    done
    
    echo
    echo "─────────────────────────────────────────────────────────────────────"
    echo "Press Ctrl+C to exit. Refreshing in 10 seconds..."
    
    # Check for any curl processes
    CURL_COUNT=$(pgrep -f "curl.*zim" | wc -l)
    if [ $CURL_COUNT -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No active curl processes detected. Downloads may have stopped.${NC}"
        echo "To resume: ./content-sizing/download_all_final.sh"
    fi
    
    sleep 10
done
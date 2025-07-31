#!/bin/bash
# PrepperApp Content Downloader
# Main script to manage all content downloads

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BASE_DIR="${PREPPER_EXTERNAL_CONTENT:-/Volumes/Vid SSD/PrepperApp-Content}"
DOWNLOAD_LIST="$SCRIPT_DIR/download_list.json"
LOG_FILE="download_$(date +%Y%m%d_%H%M%S).log"

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_color $BLUE "Checking prerequisites..."
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        print_color $RED "✗ Python 3 is required but not installed"
        exit 1
    fi
    
    # Check aria2c (optional but recommended)
    if command -v aria2c &> /dev/null; then
        print_color $GREEN "✓ aria2c found (fast downloads enabled)"
        USE_ARIA2=true
    else
        print_color $YELLOW "⚠ aria2c not found (install with: brew install aria2)"
        print_color $YELLOW "  Downloads will use Python urllib (slower)"
        USE_ARIA2=false
    fi
    
    # Check external drive
    if [ -d "$DEFAULT_BASE_DIR" ]; then
        print_color $GREEN "✓ External drive found: $DEFAULT_BASE_DIR"
    else
        print_color $YELLOW "⚠ External drive not found at: $DEFAULT_BASE_DIR"
        read -p "Enter base directory for downloads: " DEFAULT_BASE_DIR
        if [ ! -d "$DEFAULT_BASE_DIR" ]; then
            print_color $RED "✗ Directory does not exist: $DEFAULT_BASE_DIR"
            exit 1
        fi
    fi
    
    # Check disk space
    if command -v df &> /dev/null; then
        AVAILABLE_SPACE=$(df -H "$DEFAULT_BASE_DIR" | awk 'NR==2 {print $4}')
        print_color $BLUE "Available space: $AVAILABLE_SPACE"
    fi
}

# Function to show menu
show_menu() {
    clear
    print_color $BLUE "=================================="
    print_color $BLUE "PrepperApp Content Downloader"
    print_color $BLUE "=================================="
    echo
    echo "1) Download all remaining content (~73GB)"
    echo "2) Download by tier (Critical/Essential/Comprehensive)"
    echo "3) Download by category (Medical/Maps/Repair/etc)"
    echo "4) Monitor active downloads"
    echo "5) Show download status"
    echo "6) Resume failed downloads"
    echo "7) Verify downloaded content"
    echo "8) Exit"
    echo
    read -p "Select option: " choice
}

# Function to download all
download_all() {
    print_color $BLUE "Starting download of all content..."
    print_color $YELLOW "This will download approximately 73GB of data"
    read -p "Continue? (y/n): " confirm
    
    if [ "$confirm" = "y" ]; then
        python3 "$SCRIPT_DIR/download_manager.py" \
            --base-dir "$DEFAULT_BASE_DIR" \
            --list "$DOWNLOAD_LIST" \
            2>&1 | tee "$LOG_FILE"
    fi
}

# Function to download by tier
download_by_tier() {
    echo
    echo "Select tier:"
    echo "1) Tier 1 - Critical (72hr survival)"
    echo "2) Tier 2 - Essential"
    echo "3) Tier 3 - Comprehensive"
    read -p "Select tier: " tier
    
    # Create filtered download list
    TEMP_LIST=$(mktemp)
    python3 -c "
import json
with open('$DOWNLOAD_LIST', 'r') as f:
    data = json.load(f)
filtered = [d for d in data['downloads'] if d.get('tier') == $tier]
with open('$TEMP_LIST', 'w') as f:
    json.dump(filtered, f)
"
    
    python3 "$SCRIPT_DIR/download_manager.py" \
        --base-dir "$DEFAULT_BASE_DIR" \
        --list "$TEMP_LIST" \
        2>&1 | tee "$LOG_FILE"
    
    rm -f "$TEMP_LIST"
}

# Function to download by category
download_by_category() {
    echo
    echo "Select category:"
    echo "1) Medical"
    echo "2) Maps"
    echo "3) Military"
    echo "4) Repair"
    echo "5) Education"
    echo "6) Homesteading"
    echo "7) Energy"
    echo "8) How-to"
    read -p "Select category: " cat_choice
    
    case $cat_choice in
        1) CATEGORY="medical" ;;
        2) CATEGORY="maps" ;;
        3) CATEGORY="military" ;;
        4) CATEGORY="repair" ;;
        5) CATEGORY="education" ;;
        6) CATEGORY="homesteading" ;;
        7) CATEGORY="energy" ;;
        8) CATEGORY="howto" ;;
        *) print_color $RED "Invalid choice"; return ;;
    esac
    
    # Create filtered download list
    TEMP_LIST=$(mktemp)
    python3 -c "
import json
with open('$DOWNLOAD_LIST', 'r') as f:
    data = json.load(f)
filtered = [d for d in data['downloads'] if d.get('category') == '$CATEGORY']
with open('$TEMP_LIST', 'w') as f:
    json.dump(filtered, f)
"
    
    python3 "$SCRIPT_DIR/download_manager.py" \
        --base-dir "$DEFAULT_BASE_DIR" \
        --list "$TEMP_LIST" \
        2>&1 | tee "$LOG_FILE"
    
    rm -f "$TEMP_LIST"
}

# Function to monitor downloads
monitor_downloads() {
    print_color $BLUE "Starting download monitor..."
    print_color $YELLOW "Press 'q' to quit"
    sleep 2
    
    python3 "$SCRIPT_DIR/download_monitor.py" \
        --status-file "$DEFAULT_BASE_DIR/download_status.json"
}

# Function to show status
show_status() {
    python3 "$SCRIPT_DIR/download_manager.py" \
        --base-dir "$DEFAULT_BASE_DIR" \
        --status
}

# Function to resume failed
resume_failed() {
    print_color $YELLOW "Resuming failed downloads..."
    
    # The download manager automatically resumes, just re-run with same list
    python3 "$SCRIPT_DIR/download_manager.py" \
        --base-dir "$DEFAULT_BASE_DIR" \
        --list "$DOWNLOAD_LIST" \
        2>&1 | tee "$LOG_FILE"
}

# Function to verify content
verify_content() {
    print_color $BLUE "Verifying downloaded content..."
    
    # Use safe mode by default
    export PREPPER_EXTERNAL_CONTENT="$DEFAULT_BASE_DIR"
    python3 "$SCRIPT_DIR/verify_downloads.py"
}

# Main loop
main() {
    check_prerequisites
    
    while true; do
        show_menu
        
        case $choice in
            1) download_all ;;
            2) download_by_tier ;;
            3) download_by_category ;;
            4) monitor_downloads ;;
            5) show_status ;;
            6) resume_failed ;;
            7) verify_content ;;
            8) print_color $GREEN "Goodbye!"; exit 0 ;;
            *) print_color $RED "Invalid choice" ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main
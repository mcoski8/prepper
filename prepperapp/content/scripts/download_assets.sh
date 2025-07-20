#!/bin/bash
#
# download_assets.sh - Downloads and verifies the Wikipedia Medical ZIM file.
#
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
# Wikipedia Medical ZIM from Kiwix (July 2025 version)
ZIM_URL="https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2025-07.zim"

# Use a top-level data directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../../../data"
ZIM_DIR="${DATA_DIR}/zim"
ZIM_FILENAME=$(basename "${ZIM_URL}")
ZIM_FILEPATH="${ZIM_DIR}/${ZIM_FILENAME}"
CHECKSUM_FILEPATH="${ZIM_DIR}/${ZIM_FILENAME}.sha256"

# --- Main Logic ---
echo "--- PrepperApp Asset Downloader ---"
echo "Script directory: ${SCRIPT_DIR}"
echo "Data directory: ${DATA_DIR}"

# 1. Create directories
mkdir -p "${ZIM_DIR}"
echo "✓ Data directory created at: ${ZIM_DIR}"

# 2. Download ZIM file (if it doesn't exist)
if [ -f "${ZIM_FILEPATH}" ]; then
    echo "✓ ZIM file already exists. Skipping download."
    echo "  Path: ${ZIM_FILEPATH}"
else
    echo "Downloading Medical ZIM file (2.0GB)..."
    echo "URL: ${ZIM_URL}"
    
    if command -v aria2c &> /dev/null; then
        echo "Using aria2c for fast parallel download."
        # Use 8 connections, 8 splits, 1MB chunk size
        # Log to file to keep console clean
        aria2c -c -x 8 -s 8 -k 1M \
            --console-log-level=warn \
            --summary-interval=10 \
            -d "${ZIM_DIR}" \
            --log="${ZIM_DIR}/download.log" \
            "${ZIM_URL}"
    elif command -v wget &> /dev/null; then
        echo "aria2c not found. Using wget."
        echo "Note: You can install aria2 with: brew install aria2"
        wget -c -P "${ZIM_DIR}" "${ZIM_URL}"
    else
        echo "Neither aria2c nor wget found. Using curl (slower, no resume support)."
        echo "Note: For better downloads, install aria2: brew install aria2"
        echo "Or install wget: brew install wget"
        curl -L --progress-bar -o "${ZIM_FILEPATH}" "${ZIM_URL}"
    fi
    echo "✓ Download complete."
fi

# 3. Generate checksum if it doesn't exist
if [ -f "${CHECKSUM_FILEPATH}" ]; then
    echo "✓ Checksum file already exists."
else
    echo "Generating SHA256 checksum..."
    cd "${ZIM_DIR}"
    shasum -a 256 "${ZIM_FILENAME}" > "${ZIM_FILENAME}.sha256"
    cd - > /dev/null
    echo "✓ Checksum generated and saved to: ${CHECKSUM_FILEPATH}"
fi

# 4. Verify checksum
echo "Verifying file integrity..."
cd "${ZIM_DIR}"
if shasum -a 256 -c "${ZIM_FILENAME}.sha256"; then
    echo "✓ SUCCESS: Checksum matches. The ZIM file is valid."
    cd - > /dev/null
else
    echo "✗ ERROR: Checksum mismatch! The downloaded file may be corrupt."
    echo "Please delete '${ZIM_FILEPATH}' and run this script again."
    cd - > /dev/null
    exit 1
fi

# 5. Display file info
echo ""
echo "--- File Information ---"
ls -lh "${ZIM_FILEPATH}"
echo ""

# 6. Test that we can open the ZIM file with Python
echo "Testing ZIM file with Python libzim..."
python3 -c "
import libzim
try:
    zim = libzim.Archive('${ZIM_FILEPATH}')
    print(f'✓ ZIM file is valid. Total entries: {zim.all_entry_count:,}')
    print(f'  Articles: {zim.article_count:,}')
    print(f'  Media files: {zim.media_count:,}')
except Exception as e:
    print(f'✗ ERROR: Cannot open ZIM file: {e}')
    exit(1)
"

echo ""
echo "--- All assets ready ---"
echo "Next steps:"
echo "1. Test extraction: python3 extract_all.py --limit 1000 ${ZIM_FILEPATH}"
echo "2. Full extraction: python3 extract_all.py ${ZIM_FILEPATH}"
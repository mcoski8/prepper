#!/bin/bash
#
# SPRINT5_RUNNER.sh - Complete Sprint 5 workflow for PrepperApp
# This script coordinates the entire content processing pipeline
#
set -e

echo "====================================================="
echo "PrepperApp Sprint 5 - Content Processing Pipeline"
echo "====================================================="
echo ""

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_SCRIPTS="${SCRIPT_DIR}/content/scripts"
# Data dir is at the parent prepper level, not prepperapp
DATA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/data"

# Ensure we're in the right directory
cd "${SCRIPT_DIR}"

echo "Working directory: ${SCRIPT_DIR}"
echo "Data directory: ${DATA_DIR}"
echo ""

# Step 1: Download Wikipedia Medical ZIM
echo "Step 1: Downloading Wikipedia Medical ZIM file..."
echo "----------------------------------------------"
if [ -f "${DATA_DIR}/zim/wikipedia_en_medicine_maxi_2025-07.zim" ]; then
    echo "✓ ZIM file already exists, skipping download"
else
    cd "${CONTENT_SCRIPTS}"
    ./download_assets.sh
    cd "${SCRIPT_DIR}"
fi
echo ""

# Step 2: Test extraction (first 1000 articles)
echo "Step 2: Running test extraction (first 1000 articles)..."
echo "----------------------------------------------"
cd "${CONTENT_SCRIPTS}"
echo "Starting test extraction..."
python3 extract_all_final.py \
    --limit 1000 \
    "${DATA_DIR}/zim/wikipedia_en_medicine_maxi_2025-07.zim"

echo ""
echo "Test extraction complete. Check the output:"
ls -lh "${DATA_DIR}/../prepperapp/data/processed/"
echo ""

# Step 3: Build Tantivy index from test data
echo "Step 3: Building Tantivy index from test data..."
echo "----------------------------------------------"
./tantivy-indexer \
    --index "${DATA_DIR}/indexes/tantivy-test" \
    --input "${DATA_DIR}/../prepperapp/data/processed/articles.jsonl" \
    --threads 2 \
    --heap-size 300 \
    --finalize

echo ""
echo "Test index built. Size:"
du -sh "${DATA_DIR}/indexes/tantivy-test"
echo ""

# Step 4: Ask user if they want to proceed with full extraction
echo "========================================"
echo "TEST EXTRACTION COMPLETE"
echo "========================================"
echo ""
echo "Test Results:"
echo "- Articles extracted: Check manifest at ${DATA_DIR}/../prepperapp/data/processed/extraction_manifest.json"
echo "- JSONL size: $(ls -lh ${DATA_DIR}/../prepperapp/data/processed/articles.jsonl | awk '{print $5}')"
echo "- SQLite size: $(ls -lh ${DATA_DIR}/../prepperapp/data/processed/content.sqlite | awk '{print $5}')"
echo "- Index size: $(du -sh ${DATA_DIR}/indexes/tantivy-test | awk '{print $1}')"
echo ""

read -p "Do you want to proceed with FULL extraction? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Step 4: Running FULL extraction..."
    echo "----------------------------------------------"
    
    # Backup test results
    mv "${DATA_DIR}/../prepperapp/data/processed" "${DATA_DIR}/../prepperapp/data/processed-test"
    mv "${DATA_DIR}/indexes/tantivy-test" "${DATA_DIR}/indexes/tantivy-test-backup"
    
    # Run full extraction
    cd "${CONTENT_SCRIPTS}"
    python3 extract_all_final.py \
        "${DATA_DIR}/zim/wikipedia_en_medicine_maxi_2025-07.zim"
    
    echo ""
    echo "Step 5: Building final Tantivy index..."
    echo "----------------------------------------------"
    ./tantivy-indexer \
        --index "${DATA_DIR}/indexes/tantivy-final" \
        --input "${DATA_DIR}/../prepperapp/data/processed/articles.jsonl" \
        --threads 4 \
        --heap-size 500 \
        --finalize
    
    echo ""
    echo "========================================"
    echo "FULL EXTRACTION COMPLETE"
    echo "========================================"
    echo ""
    echo "Final Results:"
    echo "- Extraction manifest: ${DATA_DIR}/../prepperapp/data/processed/extraction_manifest.json"
    echo "- JSONL size: $(ls -lh ${DATA_DIR}/../prepperapp/data/processed/articles.jsonl | awk '{print $5}')"
    echo "- SQLite size: $(ls -lh ${DATA_DIR}/../prepperapp/data/processed/content.sqlite | awk '{print $5}')"
    echo "- Index size: $(du -sh ${DATA_DIR}/indexes/tantivy-final | awk '{print $1}')"
    echo ""
    echo "Next steps:"
    echo "1. Review extraction statistics in the manifest"
    echo "2. Test search performance with the CLI POC"
    echo "3. Package for mobile deployment"
else
    echo "Full extraction cancelled. Test data preserved."
fi

echo ""
echo "Sprint 5 runner complete!"
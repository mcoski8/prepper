#!/bin/bash
#
# P0_MOBILE_BUILD.sh - Build minimal mobile deployment with P0 content only
# Target: <400MB total package
#
set -e

echo "======================================================"
echo "PrepperApp P0-Only Mobile Build"
echo "Target: <400MB deployment package"
echo "======================================================"
echo ""

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_SCRIPTS="${SCRIPT_DIR}/content/scripts"
DATA_DIR="${SCRIPT_DIR}/data"
ZIM_FILE="/Users/michaelchang/documents/claudecode/prepper/data/zim/wikipedia_en_medicine_maxi_2025-07.zim"

# Ensure we're in the right directory
cd "${SCRIPT_DIR}"

echo "Step 1: Extracting P0 (critical) articles only..."
echo "----------------------------------------------"
cd "${CONTENT_SCRIPTS}"
chmod +x extract_p0_only.py
python3 extract_p0_only.py "${ZIM_FILE}"

echo ""
echo "Step 2: Building optimized Tantivy index for P0 content..."
echo "----------------------------------------------"
./tantivy-indexer \
    --index "${DATA_DIR}/indexes/tantivy-p0" \
    --input "${DATA_DIR}/processed-p0/articles-p0.jsonl" \
    --threads 4 \
    --heap-size 500 \
    --finalize

echo ""
echo "Step 3: Measuring deployment size..."
echo "----------------------------------------------"
JSONL_SIZE=$(ls -lh "${DATA_DIR}/processed-p0/articles-p0.jsonl" 2>/dev/null | awk '{print $5}' || echo "0")
SQLITE_SIZE=$(ls -lh "${DATA_DIR}/processed-p0/content-p0.sqlite" 2>/dev/null | awk '{print $5}' || echo "0")
INDEX_SIZE=$(du -sh "${DATA_DIR}/indexes/tantivy-p0" 2>/dev/null | awk '{print $1}' || echo "0")

# Calculate total in MB
SQLITE_MB=$(ls -l "${DATA_DIR}/processed-p0/content-p0.sqlite" 2>/dev/null | awk '{print $5/1024/1024}' || echo "0")
INDEX_MB=$(du -sm "${DATA_DIR}/indexes/tantivy-p0" 2>/dev/null | awk '{print $1}' || echo "0")
TOTAL_MB=$(echo "$SQLITE_MB + $INDEX_MB" | bc)

echo "P0-Only Bundle Sizes:"
echo "  JSONL (not deployed): ${JSONL_SIZE}"
echo "  SQLite content: ${SQLITE_SIZE} (${SQLITE_MB} MB)"
echo "  Tantivy index: ${INDEX_SIZE} (${INDEX_MB} MB)"
echo "  --------------------------------"
echo "  TOTAL DEPLOYMENT: ${TOTAL_MB} MB"
echo ""

# Check if we meet the target
if (( $(echo "$TOTAL_MB < 400" | bc -l) )); then
    echo "✅ SUCCESS: P0 bundle is under 400MB target!"
    echo ""
    echo "Next steps:"
    echo "1. Test search performance"
    echo "2. Package for mobile deployment"
    echo "3. Design P1/P2 as optional downloads"
else
    echo "❌ WARNING: P0 bundle exceeds 400MB target!"
    echo ""
    echo "Need to optimize:"
    echo "1. Review Tantivy schema (remove stored fields)"
    echo "2. Reduce index options (basic vs. freqs+positions)"
    echo "3. Further compress SQLite content"
fi

echo ""
echo "P0 Mobile Build complete!"
cd "${SCRIPT_DIR}"
#!/bin/bash
#
# P0_MOBILE_OPTIMIZED.sh - Build minimal mobile deployment with optimized indexing
# Target: <400MB deployment package
#
set -e

echo "======================================================"
echo "PrepperApp P0 Mobile-Optimized Build"
echo "Target: <400MB deployment package"
echo "======================================================"
echo ""

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_SCRIPTS="${SCRIPT_DIR}/content/scripts"
DATA_DIR="${SCRIPT_DIR}/data"

# Ensure we're in the right directory
cd "${SCRIPT_DIR}"

echo "Step 1: Using existing P0 extraction..."
echo "----------------------------------------------"
if [ ! -f "${DATA_DIR}/processed-p0/articles-p0.jsonl" ]; then
    echo "ERROR: P0 extraction not found. Run P0_MOBILE_BUILD.sh first!"
    exit 1
fi
echo "✓ Found P0 extraction with $(wc -l < "${DATA_DIR}/processed-p0/articles-p0.jsonl") articles"

echo ""
echo "Step 2: Building MOBILE-OPTIMIZED Tantivy index..."
echo "----------------------------------------------"
echo "Optimizations:"
echo "  - Basic index options (no positions/frequencies)"
echo "  - No indexed title field"
echo "  - No stored summary field"
echo "  - Single segment for mobile performance"
echo ""

cd "${CONTENT_SCRIPTS}"
./tantivy-indexer-mobile \
    --index "${DATA_DIR}/indexes/tantivy-p0-mobile" \
    --input "${DATA_DIR}/processed-p0/articles-p0.jsonl" \
    --threads 2 \
    --heap-size 300 \
    --finalize

echo ""
echo "Step 3: Measuring optimized deployment size..."
echo "----------------------------------------------"
SQLITE_SIZE=$(ls -lh "${DATA_DIR}/processed-p0/content-p0.sqlite" 2>/dev/null | awk '{print $5}' || echo "0")
INDEX_SIZE=$(du -sh "${DATA_DIR}/indexes/tantivy-p0-mobile" 2>/dev/null | awk '{print $1}' || echo "0")

# Calculate total in MB
SQLITE_MB=$(ls -l "${DATA_DIR}/processed-p0/content-p0.sqlite" 2>/dev/null | awk '{print $5/1024/1024}' || echo "0")
INDEX_MB=$(du -sm "${DATA_DIR}/indexes/tantivy-p0-mobile" 2>/dev/null | awk '{print $1}' || echo "0")
TOTAL_MB=$(echo "$SQLITE_MB + $INDEX_MB" | bc)

# For comparison, get the unoptimized index size
UNOPT_INDEX_SIZE=$(du -sh "${DATA_DIR}/indexes/tantivy-p0" 2>/dev/null | awk '{print $1}' || echo "N/A")

echo "Mobile-Optimized Bundle Sizes:"
echo "  SQLite content: ${SQLITE_SIZE} (${SQLITE_MB} MB)"
echo "  Optimized index: ${INDEX_SIZE} (${INDEX_MB} MB)"
echo "  Original index: ${UNOPT_INDEX_SIZE} (for comparison)"
echo "  --------------------------------"
echo "  TOTAL DEPLOYMENT: ${TOTAL_MB} MB"
echo ""

# Calculate savings
if [ -d "${DATA_DIR}/indexes/tantivy-p0" ]; then
    UNOPT_MB=$(du -sm "${DATA_DIR}/indexes/tantivy-p0" 2>/dev/null | awk '{print $1}' || echo "0")
    SAVINGS=$(echo "$UNOPT_MB - $INDEX_MB" | bc)
    SAVINGS_PCT=$(echo "scale=1; ($SAVINGS / $UNOPT_MB) * 100" | bc)
    echo "  Index size reduction: ${SAVINGS} MB (${SAVINGS_PCT}%)"
    echo ""
fi

# Check if we meet the target
if (( $(echo "$TOTAL_MB < 400" | bc -l) )); then
    echo "✅ SUCCESS: Mobile-optimized P0 bundle is under 400MB target!"
    echo ""
    echo "Next steps:"
    echo "1. Test search performance (phrase queries won't work)"
    echo "2. Create deployment package"
    echo "3. Test on actual mobile device"
else
    echo "❌ Still over target. Additional options:"
    echo "1. Further reduce P0 keywords"
    echo "2. Use zstd compression on SQLite file"
    echo "3. Split into smaller content packs"
fi

echo ""
echo "Mobile-optimized build complete!"
cd "${SCRIPT_DIR}"
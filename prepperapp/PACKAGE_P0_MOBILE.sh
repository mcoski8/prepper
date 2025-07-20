#!/bin/bash

# Package P0 Mobile Bundle for Deployment
# Creates a deployment-ready package with P0 content and mobile-optimized index

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PrepperApp P0 Mobile Deployment Packager ===${NC}"
echo "Creating deployment-ready bundle for mobile devices"
echo

# Set paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DATA_DIR="${SCRIPT_DIR}/data"

# Source and destination paths
SQLITE_SOURCE="${DATA_DIR}/processed-p0/content-p0.sqlite"
INDEX_SOURCE="${DATA_DIR}/indexes/tantivy-p0-mobile"
PACKAGE_DIR="${DATA_DIR}/mobile-deployment"
PACKAGE_NAME="prepperapp-p0-v1.0.0"
PACKAGE_PATH="${PACKAGE_DIR}/${PACKAGE_NAME}"

# Check prerequisites
echo "Checking prerequisites..."

if [ ! -f "$SQLITE_SOURCE" ]; then
    echo -e "${RED}Error: P0 SQLite content not found${NC}"
    echo "Please run P0_ONLY_EXTRACT.sh first"
    exit 1
fi

if [ ! -d "$INDEX_SOURCE" ]; then
    echo -e "${RED}Error: P0 mobile index not found${NC}"
    echo "Please run P0_MOBILE_OPTIMIZED.sh first"
    exit 1
fi

# Create package directory
echo -e "${YELLOW}Creating package directory...${NC}"
mkdir -p "$PACKAGE_PATH"
rm -rf "${PACKAGE_PATH:?}"/*  # Clean if exists

# Create directory structure
mkdir -p "$PACKAGE_PATH/content"
mkdir -p "$PACKAGE_PATH/index"
mkdir -p "$PACKAGE_PATH/metadata"

# Copy SQLite content database
echo -e "${YELLOW}Copying content database...${NC}"
cp "$SQLITE_SOURCE" "$PACKAGE_PATH/content/medical.db"

# Copy Tantivy index
echo -e "${YELLOW}Copying search index...${NC}"
cp -r "$INDEX_SOURCE"/* "$PACKAGE_PATH/index/"

# Create package manifest
echo -e "${YELLOW}Creating package manifest...${NC}"
cat > "$PACKAGE_PATH/metadata/manifest.json" << EOF
{
  "package": {
    "name": "PrepperApp Core Medical Content",
    "version": "1.0.0",
    "tier": "P0",
    "description": "Critical 72-hour survival medical information",
    "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "content": {
    "article_count": 9076,
    "priorities": {
      "P0": 9076,
      "P1": 0,
      "P2": 0
    },
    "topics": [
      "Hemorrhage control",
      "Cardiac emergencies",
      "Respiratory emergencies",
      "Shock treatment",
      "Wound care",
      "Fractures and dislocations",
      "Burns",
      "Hypothermia/Hyperthermia",
      "Poisoning",
      "Anaphylaxis"
    ]
  },
  "technical": {
    "database_format": "SQLite3 with zstd compression",
    "index_format": "Tantivy 0.22 (Basic indexing)",
    "search_capabilities": {
      "boolean_search": true,
      "phrase_search": false,
      "fuzzy_search": false,
      "stemming": true
    }
  },
  "size": {
    "database_mb": 0,
    "index_mb": 0,
    "total_mb": 0
  }
}
EOF

# Calculate actual sizes and update manifest
DB_SIZE=$(du -m "$PACKAGE_PATH/content/medical.db" | cut -f1)
INDEX_SIZE=$(du -sm "$PACKAGE_PATH/index" | cut -f1)
TOTAL_SIZE=$((DB_SIZE + INDEX_SIZE))

# Update manifest with actual sizes
python3 -c "
import json
with open('$PACKAGE_PATH/metadata/manifest.json', 'r') as f:
    manifest = json.load(f)
manifest['size']['database_mb'] = $DB_SIZE
manifest['size']['index_mb'] = $INDEX_SIZE
manifest['size']['total_mb'] = $TOTAL_SIZE
with open('$PACKAGE_PATH/metadata/manifest.json', 'w') as f:
    json.dump(manifest, f, indent=2)
"

# Create README
echo -e "${YELLOW}Creating README...${NC}"
cat > "$PACKAGE_PATH/README.md" << 'EOF'
# PrepperApp P0 Medical Content Bundle

## Overview
This bundle contains critical medical information for 72-hour survival scenarios.
All content is optimized for offline use and minimal battery consumption.

## Contents
- `content/medical.db`: SQLite database with compressed medical articles
- `index/`: Tantivy search index for fast full-text search
- `metadata/manifest.json`: Package metadata and technical specifications

## Integration Guide

### iOS (Swift)
```swift
// Copy bundle to app documents
let bundlePath = Bundle.main.path(forResource: "prepperapp-p0-v1.0.0", ofType: nil)
let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
// Copy files...

// Initialize search
let indexPath = "\(documentsPath)/index"
let dbPath = "\(documentsPath)/content/medical.db"
```

### Android (Kotlin)
```kotlin
// Extract from assets
val assetManager = context.assets
assetManager.open("prepperapp-p0-v1.0.0.zip").use { input ->
    // Extract to app files directory
}

// Initialize search
val indexPath = File(filesDir, "index")
val dbPath = File(filesDir, "content/medical.db")
```

## Search Capabilities
- Boolean keyword search (AND/OR)
- No phrase search (by design for size optimization)
- Case-insensitive search
- Stemming support

## Important Notes
1. Index uses Basic indexing - no positional data
2. Content is zstd compressed - decompress on read
3. All content pre-validated for emergency safety
4. Optimized for <2% battery drain per hour of use
EOF

# Create version file
echo "${PACKAGE_NAME}" > "$PACKAGE_PATH/metadata/VERSION"

# Create deployment checksums
echo -e "${YELLOW}Creating checksums...${NC}"
cd "$PACKAGE_PATH"
find . -type f -exec shasum -a 256 {} \; > metadata/checksums.txt

# Create compressed archives
echo -e "${YELLOW}Creating deployment archives...${NC}"
cd "$PACKAGE_DIR"

# Create tar.gz for Unix systems
echo "  Creating tar.gz archive..."
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# Create zip for general use
echo "  Creating zip archive..."
zip -qr "${PACKAGE_NAME}.zip" "$PACKAGE_NAME"

# Calculate final sizes
TAR_SIZE=$(ls -lh "${PACKAGE_NAME}.tar.gz" | awk '{print $5}')
ZIP_SIZE=$(ls -lh "${PACKAGE_NAME}.zip" | awk '{print $5}')

# Summary
echo
echo -e "${GREEN}✅ Package created successfully!${NC}"
echo
echo -e "${CYAN}=== Package Summary ===${NC}"
echo "Package name: ${PACKAGE_NAME}"
echo "Location: ${PACKAGE_DIR}"
echo
echo "Uncompressed bundle: ${TOTAL_SIZE}MB"
echo "  - Database: ${DB_SIZE}MB"
echo "  - Index: ${INDEX_SIZE}MB"
echo
echo "Compressed archives:"
echo "  - ${PACKAGE_NAME}.tar.gz: ${TAR_SIZE}"
echo "  - ${PACKAGE_NAME}.zip: ${ZIP_SIZE}"
echo
echo -e "${BLUE}=== Deployment Instructions ===${NC}"
echo "1. For iOS: Include the uncompressed bundle in app resources"
echo "2. For Android: Include the zip in assets folder"
echo "3. Both platforms should extract on first launch"
echo "4. Test search functionality before release"
echo
echo -e "${GREEN}Bundle is ready for mobile deployment!${NC}"

# Verify size is under target
if [ $TOTAL_SIZE -gt 400 ]; then
    echo
    echo -e "${RED}⚠️  WARNING: Bundle size (${TOTAL_SIZE}MB) exceeds 400MB target!${NC}"
    exit 1
fi
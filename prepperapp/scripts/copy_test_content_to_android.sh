#!/bin/bash

# Copy test content to Android assets for development
# This bundles the test database with the app

set -e

echo "Copying test content to Android assets..."

# Source and destination paths
SOURCE_DB="data/processed/test_content.db"
SOURCE_MANIFEST="data/processed/content_manifest.json"
DEST_DIR="android/app/src/main/assets/content"

# Create assets directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy files
if [ -f "$SOURCE_DB" ]; then
    cp "$SOURCE_DB" "$DEST_DIR/"
    echo "✓ Copied test_content.db"
else
    echo "✗ test_content.db not found!"
    exit 1
fi

if [ -f "$SOURCE_MANIFEST" ]; then
    cp "$SOURCE_MANIFEST" "$DEST_DIR/"
    echo "✓ Copied content_manifest.json"
else
    echo "✗ content_manifest.json not found!"
    exit 1
fi

# Show sizes
echo
echo "Asset sizes:"
du -h "$DEST_DIR"/*

echo
echo "✅ Test content ready for Android app!"
echo "The app will now include this content for offline development."
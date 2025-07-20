#!/bin/bash

# Copy test content to iOS app bundle for development
# This bundles the test database with the app

set -e

echo "Copying test content to iOS app bundle..."

# Source paths
SOURCE_DB="data/processed/test_content.db"
SOURCE_MANIFEST="data/processed/content_manifest.json"

# Destination - iOS app bundle Content directory
DEST_DIR="iOS/PrepperApp/Content"

# Create Content directory if it doesn't exist
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

# Update Xcode project to include Content folder
echo
echo "📱 Next steps for Xcode:"
echo "1. In Xcode, right-click on PrepperApp group"
echo "2. Select 'Add Files to PrepperApp...'"
echo "3. Navigate to and select the 'Content' folder"
echo "4. Check 'Copy items if needed'"
echo "5. Select 'Create folder references'"
echo "6. Click 'Add'"

# Show sizes
echo
echo "Content sizes:"
du -h "$DEST_DIR"/*

echo
echo "✅ Test content ready for iOS app!"
echo "The app will now include this content for offline development."
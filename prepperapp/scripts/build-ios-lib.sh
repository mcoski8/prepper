#!/bin/bash

# Build Tantivy library for iOS
# This creates a universal library for iOS devices and simulator

set -e

echo "Building Tantivy library for iOS..."

cd ../rust/tantivy-mobile

# Install cargo-lipo if not already installed
if ! command -v cargo-lipo &> /dev/null; then
    echo "Installing cargo-lipo..."
    cargo install cargo-lipo
fi

# Add iOS targets if not already added
rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim

# Build for iOS
echo "Building for iOS devices and simulator..."
cargo lipo --release

# Create output directory
OUTPUT_DIR="../../ios/Libraries"
mkdir -p $OUTPUT_DIR

# Copy the universal library
cp target/universal/release/libtantivy_mobile.a $OUTPUT_DIR/
cp tantivy_mobile.h $OUTPUT_DIR/

echo "iOS library built successfully!"
echo "Output files:"
echo "  - $OUTPUT_DIR/libtantivy_mobile.a"
echo "  - $OUTPUT_DIR/tantivy_mobile.h"

# Show library info
echo -e "\nLibrary info:"
lipo -info $OUTPUT_DIR/libtantivy_mobile.a
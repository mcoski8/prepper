#!/bin/bash

# Build Tantivy library for Android
# This creates libraries for all Android architectures

set -e

echo "Building Tantivy library for Android..."

cd ../rust/tantivy-mobile

# Set up Android NDK path (update this to your NDK path)
# You can also set this in your environment
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "Warning: ANDROID_NDK_HOME not set. Please set it to your Android NDK path."
    echo "Example: export ANDROID_NDK_HOME=/Users/username/Library/Android/sdk/ndk/25.2.9519653"
    exit 1
fi

# Install cargo-ndk if not already installed
if ! command -v cargo-ndk &> /dev/null; then
    echo "Installing cargo-ndk..."
    cargo install cargo-ndk
fi

# Add Android targets
rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android \
    i686-linux-android

# Build for all Android architectures
echo "Building for Android architectures..."

# Create output directory structure
OUTPUT_DIR="../../android/app/src/main/jniLibs"
mkdir -p $OUTPUT_DIR/{arm64-v8a,armeabi-v7a,x86_64,x86}

# Build for each architecture
echo "Building for arm64-v8a..."
cargo ndk -t arm64-v8a -o $OUTPUT_DIR build --release

echo "Building for armeabi-v7a..."
cargo ndk -t armeabi-v7a -o $OUTPUT_DIR build --release

echo "Building for x86_64..."
cargo ndk -t x86_64 -o $OUTPUT_DIR build --release

echo "Building for x86..."
cargo ndk -t x86 -o $OUTPUT_DIR build --release

# Copy header file
INCLUDE_DIR="../../android/app/src/main/cpp/include"
mkdir -p $INCLUDE_DIR
cp tantivy_mobile.h $INCLUDE_DIR/

echo "Android libraries built successfully!"
echo "Output files:"
echo "  - JNI Libraries: $OUTPUT_DIR/**/libtantivy_mobile.so"
echo "  - Header file: $INCLUDE_DIR/tantivy_mobile.h"

# Show library sizes
echo -e "\nLibrary sizes:"
find $OUTPUT_DIR -name "*.so" -exec ls -lh {} \;
#!/bin/bash

# Build script for Tantivy PoC
# This script demonstrates the build process for the Rust components

set -e

echo "Building Tantivy PoC..."

cd ../rust/cli-poc

# Build in release mode with mobile optimizations
echo "Building release binary with size optimizations..."
cargo build --release

# Show binary size
echo -e "\nBinary size:"
ls -lh target/release/tantivy-poc

# Run basic tests
echo -e "\nRunning basic workflow test..."

# Create test directory
TEST_DIR="./test-run"
rm -rf $TEST_DIR
mkdir -p $TEST_DIR

# 1. Create index
echo "1. Creating index..."
cargo run --release -- create-index --path $TEST_DIR/core-index

# 2. Index content
echo -e "\n2. Indexing sample content..."
cargo run --release -- index-content --index-path $TEST_DIR/core-index

# 3. Test searches
echo -e "\n3. Testing search queries..."
echo "   Searching for 'bleeding'..."
cargo run --release -- search --index-path $TEST_DIR/core-index --query "bleeding"

echo -e "\n   Searching for 'water'..."
cargo run --release -- search --index-path $TEST_DIR/core-index --query "water"

echo -e "\n   Searching for 'emergency'..."
cargo run --release -- search --index-path $TEST_DIR/core-index --query "emergency"

# 4. Create module index for multi-index test
echo -e "\n4. Creating module index..."
cargo run --release -- create-index --path $TEST_DIR/module-index
cargo run --release -- index-content --index-path $TEST_DIR/module-index

# 5. Test multi-index search
echo -e "\n5. Testing multi-index search..."
cargo run --release -- multi-search \
    --core-index $TEST_DIR/core-index \
    --module-index $TEST_DIR/module-index \
    --query "shock"

echo -e "\nPoC build and test complete!"
echo "Index files created in: $TEST_DIR"

# Show index size
echo -e "\nIndex sizes:"
du -sh $TEST_DIR/*
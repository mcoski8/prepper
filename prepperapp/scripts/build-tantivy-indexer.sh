#!/bin/bash
# Build the tantivy-indexer tool for content processing

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
INDEXER_DIR="$PROJECT_ROOT/rust/tantivy-indexer"

echo "Building tantivy-indexer..."
echo "Project root: $PROJECT_ROOT"
echo "Indexer directory: $INDEXER_DIR"

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "Error: Rust/Cargo is not installed."
    echo "Please install Rust from https://rustup.rs/"
    exit 1
fi

# Navigate to indexer directory
cd "$INDEXER_DIR"

# Build in release mode with optimizations
echo "Building tantivy-indexer in release mode..."
cargo build --release

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "✓ Build successful!"
    
    # Create symlink in scripts directory for easy access
    BINARY_PATH="$INDEXER_DIR/target/release/tantivy-indexer"
    SYMLINK_PATH="$PROJECT_ROOT/content/scripts/tantivy-indexer"
    
    if [ -f "$BINARY_PATH" ]; then
        ln -sf "$BINARY_PATH" "$SYMLINK_PATH"
        echo "✓ Created symlink: $SYMLINK_PATH"
        echo ""
        echo "You can now use tantivy-indexer from the content/scripts directory"
        
        # Show binary info
        echo ""
        echo "Binary info:"
        ls -lh "$BINARY_PATH"
        
        # Test the binary
        echo ""
        echo "Testing binary..."
        "$BINARY_PATH" --version || echo "(No version info available)"
    else
        echo "Error: Binary not found at expected location: $BINARY_PATH"
        exit 1
    fi
else
    echo "✗ Build failed!"
    exit 1
fi

echo ""
echo "Next steps:"
echo "1. Install Python dependencies: pip install -r content/scripts/requirements.txt"
echo "2. Download Wikipedia Medical ZIM file"
echo "3. Run extraction: python3 extract_curated_zim_streaming.py <path-to-zim>"
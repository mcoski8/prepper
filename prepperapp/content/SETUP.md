# PrepperApp Content Pipeline Setup

## Prerequisites

### 1. Python 3.8+
```bash
# Check Python version
python3 --version

# Install required packages
pip3 install -r scripts/requirements.txt
```

### 2. Rust Toolchain
```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Verify installation
cargo --version
```

### 3. ZIM Tools (Optional but recommended)
```bash
# macOS
brew install zim-tools

# Ubuntu/Debian
sudo apt-get install zim-tools

# From source
git clone https://github.com/openzim/zim-tools.git
cd zim-tools
meson . build
ninja -C build
```

### 4. Python Dependencies
```bash
cd scripts
pip3 install pyzim requests
```

## Quick Start

### 1. Test the Pipeline
```bash
cd scripts
./test_pipeline.sh
```

### 2. Download Sample Wikipedia Medical Content
```bash
# Download a small medical ZIM for testing (if available)
./chunked_downloader.py download \
  --url https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2024-10.zim \
  --dest ../raw/
```

### 3. Extract Curated Articles (Test with 50)
```bash
./extract_curated_zim.py ../raw/wikipedia_en_medicine_*.zim \
  --limit 50 \
  --output-name test_curated
```

### 4. Build Tantivy Index
```bash
cd ../../rust/cli-poc
cargo run --release --bin index_builder ../../content/indexes/articles_for_indexing.jsonl
```

## Full Production Pipeline

### Step 1: Download Full Wikipedia Medical ZIM
```bash
# This downloads ~4.2GB - ensure you have space and stable connection
./download_all.sh --category medical
```

### Step 2: Extract Priority Articles
```bash
# Extract all priority 0 and 1 articles (no limit)
./extract_curated_zim.py ../raw/wikipedia_en_medicine_*.zim \
  --output-name curated_medical_v1
```

### Step 3: Create Distribution Package
```bash
# This creates the final ZIM and index files
./create_distribution.py --module core
```

## Troubleshooting

### pyzim Installation Issues
```bash
# If pyzim fails to install, try:
pip3 install --upgrade pip
pip3 install wheel
pip3 install pyzim
```

### Memory Issues During Extraction
- Reduce batch size in extract_curated_zim.py
- Process in smaller chunks
- Use a machine with at least 8GB RAM

### Rust Build Errors
```bash
# Clean and rebuild
cd rust/cli-poc
cargo clean
cargo build --release
```

### ZIM File Not Found
- Check download completed successfully
- Verify file path and permissions
- Use chunked_downloader.py for reliable downloads

## Performance Targets

- Extraction: ~1000 articles/minute
- Index building: ~5000 articles/minute  
- Final index size: <10% of content size
- Search latency: <100ms

## Next Steps

After successful setup:
1. Review extracted articles in `processed/curated/`
2. Test search performance with the CLI
3. Copy indexes to mobile app resources
4. Create manifest.json for app downloads
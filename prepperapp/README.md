# PrepperApp

Offline-first survival knowledge base for iOS and Android. Designed to work with zero connectivity during emergencies.

## Project Status: Content Downloads Active 🔄

### Completed Features
- ✅ Rust-based Tantivy search engine with <100ms performance
- ✅ Content extraction pipeline (29,972 medical articles)
- ✅ Mobile-optimized bundle: **249MB** (P0 critical content)
- ✅ Search safety validation framework
- ✅ Automated deployment packaging
- ✅ 88% index size reduction using Basic indexing
- ✅ Pill identification database (46,872 FDA products)
- ✅ External storage support for 220GB+ content

### In Progress
**Content Downloads**: Acquiring ~220GB of comprehensive survival content
- Wikipedia (Full): 87GB 
- Medical References: 15GB
- Maps, Survival Guides, Reference Library: 118GB
- Progress: ~2.8GB downloaded (1.3%)

### Latest Achievement
**Two-Tier Architecture**: 
- Tier 1: 249MB core app (fits on any phone)
- Tier 2: 220GB+ external storage modules (SD card/USB)

## Project Structure

```
prepperapp/
├── ios/                    # iOS native app (Swift)
│   ├── PrepperApp/        # Swift source files
│   └── Libraries/         # Tantivy static library
├── android/               # Android native app (Kotlin)
│   ├── app/              # Android app module
│   └── (gradle files)    # Build configuration
├── rust/                  # Shared Rust libraries
│   ├── cli-poc/          # Tantivy CLI proof of concept
│   ├── tantivy-mobile/   # FFI/JNI wrapper library
│   └── kiwix-mobile/     # ZIM reader wrapper (TODO)
├── content/              # Content pipeline
│   ├── scripts/         # Download & processing scripts
│   ├── raw/            # Downloaded content
│   └── processed/      # Categorized content
├── scripts/             # Build scripts
└── tests/              # Cross-platform tests
```

## Quick Start

### Prerequisites
- Python 3.8+ with libzim
- Rust toolchain (optional, for custom builds)
- ~5GB disk space for full extraction

### 1. Extract Medical Content

```bash
# Run the full pipeline (takes ~3 minutes)
./SPRINT5_RUNNER.sh

# Or just P0 content for mobile
./P0_ONLY_EXTRACT.sh
```

### 2. Build Mobile Bundle

```bash
# Create mobile-optimized index
./P0_MOBILE_OPTIMIZED.sh

# Test search safety
./RUN_SEARCH_SAFETY_TEST.sh

# Package for deployment
./PACKAGE_P0_MOBILE.sh
```

### 3. Deploy to Mobile

**iOS:**
- Include `prepperapp-p0-v1.0.0` bundle in app resources
- Extract on first launch to Documents directory

**Android:**
- Add `prepperapp-p0-v1.0.0.zip` to assets
- Extract to app files directory on first launch

## Architecture

### Search Engine
- **Tantivy** (Rust): Full-text search with <100ms query time
- **Schema**: Optimized for mobile with FAST fields
- **Indexes**: Memory-mapped for efficiency

### Mobile Integration
- **iOS**: Swift + C FFI bridge
- **Android**: Kotlin + JNI bridge
- **Thread-safe**: Concurrent search, exclusive writes

### Content Pipeline
1. **Acquisition**: Wikipedia medical, military manuals
2. **Processing**: Extract, categorize, prioritize
3. **Indexing**: Tantivy with pre-built indexes
4. **Distribution**: Core (<1GB) + Modules (1-5GB)

## Performance

- **Search**: <100ms for any query
- **Memory**: <150MB active usage
- **Battery**: <2% per hour
- **Launch**: <1 second to search

## Emergency Features

- Pure black OLED theme (40% battery savings)
- No animations or transitions
- Search bar always visible
- One-tap emergency mode
- Priority indicators on results

## Content Sources

- Wikipedia Medical Subset (4.2GB)
- US Military Survival Manuals
- Where There Is No Doctor
- Red Cross First Aid guides

## Development

See `/docs` for detailed documentation:
- Architecture decisions
- Search implementation
- UI/UX guidelines
- Content curation
- FFI integration guide

## Testing

```bash
# Rust tests
cd rust/cli-poc
cargo test

# iOS tests
cd ios
xcodebuild test

# Android tests
cd android
./gradlew test
```

## License

[To be determined]

## Contact

Project documentation: `/docs`
Sprint tracking: `/docs/project/sprint-tracker.md`
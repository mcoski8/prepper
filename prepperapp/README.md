# PrepperApp

Offline-first survival knowledge base for iOS and Android. Designed to work with zero connectivity during emergencies.

## Project Status: Sprint 1 Complete ✅

### Completed Features
- ✅ Rust-based Tantivy search engine with <100ms performance
- ✅ Native iOS app (Swift) with emergency-optimized UI
- ✅ Native Android app (Kotlin) with OLED black theme
- ✅ FFI/JNI bridges for cross-platform search
- ✅ Content acquisition pipeline for real survival data
- ✅ Smart categorization and priority system

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
- Rust toolchain with mobile targets
- Xcode 14+ (iOS)
- Android Studio (Android)
- Python 3.8+ (content processing)

### 1. Build Rust Libraries

```bash
# iOS
cd scripts
./build-ios-lib.sh

# Android
export ANDROID_NDK_HOME=/path/to/ndk
./build-android-lib.sh
```

### 2. Download Real Content

```bash
cd content/scripts
pip3 install -r requirements.txt
./download_all.sh
```

### 3. Build & Run Apps

**iOS:**
1. Open `ios/` in Xcode
2. Add `libtantivy_mobile.a` to project
3. Build and run

**Android:**
1. Open `android/` in Android Studio
2. Sync Gradle
3. Build and run

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
# PrepperApp

Offline-first survival knowledge base for iOS and Android. Designed to work with zero connectivity during emergencies.

## Project Status: iOS Development Active 📱

### Development Strategy Update
Following consultation with Gemini 2.5 Pro, we've adopted an **iOS-first approach** due to:
- Founder only has iOS devices for testing
- iOS users are primary market
- External storage possible on iOS (with user setup)
- Android development deferred until after iOS success

### Completed Features
- ✅ **iOS App Foundation** (UIKit, Tab Navigation)
- ✅ **Content-Agnostic Architecture** (works with any size: 10MB to 220GB)
- ✅ **Emergency UI** - Instant access to life-saving content
- ✅ **Search & Browse** - Lightning-fast article discovery
- ✅ **Test Content Bundle** - 17 emergency procedures (56KB)
- ✅ **Content Manager** - Dynamic content loading system
- ✅ **Pure Black OLED UI** - Maximum battery efficiency

### In Progress
**Content System Enhancement**:
- Implementing On-Demand Resources for Tier 1 (2-3GB)
- Building module downloader for Tier 2 (1-5GB packs)
- External storage POC for Tier 3 (220GB archive)

### Three-Tier Content Strategy
- **Tier 1**: Essential Core (2-3GB) - Always on device
- **Tier 2**: Adaptive Bundles (1-5GB each) - User choice
- **Tier 3**: Complete Archive (220GB) - External storage

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
- Xcode 15+ (for iOS development)
- macOS Sonoma or later
- iOS device or simulator (iOS 15+)

### 1. Setup Test Content

```bash
# Generate test content bundle
python3 scripts/generate_test_content.py

# Copy to iOS project
./scripts/copy_test_content_to_ios.sh
```

### 2. Open iOS Project

```bash
# Open in Xcode
open iOS/PrepperApp.xcodeproj
```

In Xcode:
1. Add the 'Content' folder to the project (as folder reference)
2. Select your development team
3. Build and run (⌘R)

### 3. Test Key Features

- **Emergency Tab**: Quick access to priority 0 content
- **Search Tab**: Full-text search across all articles
- **Browse Tab**: Explore by category

### 4. Android (Future)

Android development is deferred until after iOS validation. The foundation is ready:
- Content-agnostic architecture
- Test content bundle
- Basic project structure

## Architecture

### iOS Implementation
- **UIKit**: Traditional views for stability and performance
- **ContentManager**: Discovers and loads content from multiple sources
- **SQLite**: Direct queries for lightning-fast search
- **Tab Navigation**: Emergency, Search, Browse

### Content System
- **Manifest-Driven**: JSON manifests describe available content
- **Multi-Source**: Bundled, Documents, App Group, External Storage
- **Dynamic UI**: Features enable/disable based on content
- **Fallback**: Always has minimal emergency content

### Content Sources Priority
1. **Test Bundle**: 56KB development content
2. **Downloaded**: Future Tier 1/2 content
3. **External**: Future Tier 3 via USB/Lightning
4. **Fallback**: 5 hardcoded emergency procedures

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
- [iOS-First Strategy](docs/development/ios-first-strategy.md)
- [Content-Agnostic Architecture](docs/architecture/content-agnostic-design.md)
- [Content Acquisition Plan](docs/content/content-acquisition.md)
- UI/UX Guidelines
- Sprint Tracking

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
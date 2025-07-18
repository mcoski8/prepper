# PrepperApp iOS

Native iOS implementation of PrepperApp, optimized for offline survival knowledge access.

## Architecture

- **Language**: Swift 5
- **UI Framework**: UIKit (programmatic UI, no storyboards)
- **Minimum iOS**: 14.0
- **Search**: Tantivy (Rust) via C FFI
- **Theme**: Pure black OLED-optimized

## Project Structure

```
ios/
├── PrepperApp/
│   ├── AppDelegate.swift           # App lifecycle
│   ├── SearchViewController.swift  # Main search interface  
│   ├── SearchResultCell.swift      # Search result display
│   ├── ArticleDetailViewController.swift  # Article viewer
│   ├── TantivyBridge.swift        # Swift wrapper for Tantivy (TODO)
│   ├── Info.plist                 # App configuration
│   └── PrepperApp-Bridging-Header.h  # C library imports
├── Libraries/
│   ├── libtantivy_mobile.a       # Tantivy static library
│   └── tantivy_mobile.h           # C header
└── Resources/
    └── (app assets)
```

## Key Features

### 1. Search-First UI
- Search bar always visible at top
- Instant search with debouncing (300ms)
- Results show priority indicators
- Automatic keyboard display on launch

### 2. OLED Optimization
- Pure black backgrounds (#000000)
- No animations or transitions
- White text with opacity variations
- Minimal UI chrome

### 3. Emergency Mode
- Accessible from article view
- Strips non-essential UI
- Increases font sizes
- Shows only critical info

### 4. Touch Targets
- Minimum 48pt touch targets
- High contrast selection states
- Large, readable fonts (min 16pt)

## Building

### Prerequisites
1. Xcode 14+
2. Rust toolchain with iOS targets
3. cargo-lipo installed

### Build Steps

1. Build the Rust library:
```bash
cd scripts
./build-ios-lib.sh
```

2. Open Xcode and create new project:
   - Product Name: PrepperApp
   - Interface: UIKit
   - Language: Swift
   - Uncheck "Use Storyboards"

3. Add files to project:
   - Drag all Swift files to project
   - Add `libtantivy_mobile.a` to "Frameworks, Libraries, and Embedded Content"
   - Set bridging header in Build Settings

4. Configure project:
   - Set deployment target to iOS 14.0
   - Add "All Files Access" usage description
   - Enable file sharing in Info.plist

## Performance Targets

- App launch to search: <1 second
- Search results: <100ms
- Memory usage: <150MB
- Battery drain: <2% per hour

## Next Steps

1. Implement TantivyBridge.swift
2. Add ZIM file support via Kiwix
3. Implement module downloader
4. Add offline content management
5. Create emergency mode UI
6. Add battery optimization

## Testing

Run on physical device to test:
- OLED black levels
- Battery consumption  
- Search performance
- Memory usage

Use Instruments to profile:
- Time Profiler (search speed)
- Allocations (memory)
- Energy Log (battery)
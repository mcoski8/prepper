# PrepperApp System Design

## Overview
PrepperApp is a native mobile application designed to provide comprehensive survival knowledge in offline, emergency scenarios. The system architecture prioritizes performance, battery efficiency, and instant information retrieval when lives may depend on it.

## System Architecture

### High-Level Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                        PrepperApp                            │
├─────────────────────────────────────────────────────────────┤
│                    Presentation Layer                        │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  Search UI  │  │ Content View │  │ Module Manager  │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                     Business Logic                           │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │Search Engine│  │Content Reader│  │Storage Manager  │   │
│  │  (Tantivy)  │  │  (ZIM/Kiwix) │  │  (Internal/Ext) │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                      Data Layer                              │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  Core Data  │  │Content Modules│ │ External Storage│   │
│  │  (500MB-1GB)│  │   (1-5GB ea)  │ │   (20-256GB+)   │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Component Architecture

#### 1. Presentation Layer
- **Search UI**: Minimalist search-first interface
- **Content Viewer**: Optimized HTML renderer with emergency mode
- **Module Manager**: Download, storage, and lifecycle management
- **Settings**: Storage management, theme (black only), cache control

#### 2. Business Logic Layer
- **Search Engine (Tantivy)**
  - Pre-built indexes for instant search
  - Tiered index loading (core always in memory)
  - Fuzzy search for misspellings
  - Category-based filtering
  
- **Content Reader (Kiwix-lib)**
  - ZIM file format support
  - Streaming decompression
  - Memory-mapped file access
  - Article caching with LRU eviction

- **Storage Manager**
  - Internal storage monitoring
  - External storage detection (USB-C/Lightning)
  - Module lifecycle (download, verify, install, remove)
  - Space allocation strategies

#### 3. Data Layer
- **Core Data**: Built into app bundle, always available
- **Content Modules**: Downloaded to internal/external storage
- **External Archive**: Large datasets on external media
- **User Data**: SQLite for bookmarks, notes, preferences

### Platform-Specific Implementation

#### iOS Architecture
```swift
// Core components
- ContentEngine: Kiwix-lib via C++ bridge
- SearchService: Tantivy via Swift-Rust bridge
- StorageService: iOS Storage APIs + USB-C support
- ViewControllers: UIKit for performance
```

#### Android Architecture
```kotlin
// Core components
- ContentEngine: Kiwix-lib via JNI
- SearchService: Tantivy via Rust NDK
- StorageService: Storage Access Framework
- Activities: Native Android Views
```

## Data Architecture

### Content Storage Format
```
/AppData/
├── core/
│   ├── content.zim          # Core survival content
│   ├── index.tantivy        # Pre-built search index
│   └── metadata.json        # Version, checksums
├── modules/
│   ├── medical_advanced/
│   │   ├── content.zim
│   │   ├── index.tantivy
│   │   └── metadata.json
│   └── regional_northeast/
│       ├── content.zim
│       ├── index.tantivy
│       └── metadata.json
└── cache/
    └── article_cache.db     # Recently viewed articles
```

### Database Schema
```sql
-- User data storage (SQLite)
CREATE TABLE bookmarks (
    id INTEGER PRIMARY KEY,
    article_id TEXT NOT NULL,
    module_id TEXT NOT NULL,
    title TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    category TEXT,
    priority INTEGER DEFAULT 0
);

CREATE TABLE notes (
    id INTEGER PRIMARY KEY,
    article_id TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE module_registry (
    module_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    storage_location TEXT NOT NULL,
    installed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed TIMESTAMP
);
```

## Performance Considerations

### Memory Management
- **Core Index**: Always loaded (~50MB)
- **Module Indexes**: Loaded on-demand, LRU cache
- **Content**: Streamed from disk, never fully loaded
- **Images**: Lazy loaded, aggressive caching

### Battery Optimization
- **UI Rendering**: Pure black theme, no animations
- **CPU Usage**: Background threads for I/O
- **Disk Access**: Batch reads, memory-mapped files
- **Network**: Completely disabled in emergency mode

### Search Performance Targets
- Index loading: <500ms
- Query execution: <100ms
- Result rendering: <50ms
- Total search time: <200ms

## Security & Privacy

### Data Security
- No network communication in offline mode
- No analytics or telemetry
- Local encryption for user notes
- Module integrity verification (SHA-256)

### Content Verification
- Digitally signed content modules
- Checksum verification on load
- Tamper detection for critical content

## Scalability

### Content Scalability
- Modular architecture supports unlimited modules
- External storage for terabyte-scale archives
- Lazy loading prevents memory exhaustion

### Performance Scalability
- Pre-computed indexes scale linearly
- Parallel search across modules
- Progressive content loading

## Technology Stack

### Core Technologies
- **Languages**: Kotlin 1.9+ (Android), Swift 5.9+ (iOS)
- **Search**: Tantivy 0.22+ (Rust)
- **Content**: Kiwix-lib 13.0+ (C++)
- **Database**: SQLite 3.40+
- **Compression**: Zstandard 1.5+

### Build Tools
- **Android**: Gradle 8.0+, Android Studio
- **iOS**: Xcode 15+, Swift Package Manager
- **Cross-platform**: CMake for C++ libraries
- **CI/CD**: GitHub Actions

## Error Handling

### Graceful Degradation
1. External storage unavailable → Use internal only
2. Search index corrupted → Rebuild from content
3. Module corrupted → Quarantine and notify
4. Low memory → Evict caches, reduce functionality

### User Feedback
- Clear error messages for content issues
- Offline status indicators
- Storage space warnings
- Module health monitoring

## Future Considerations

### Phase 1 Completion
- Core app with essential content
- Basic search and navigation
- Internal storage only

### Phase 2 Additions
- Module marketplace
- External storage support
- Advanced search filters

### Phase 3 Enhancements
- Offline maps integration
- Community content sharing
- Hardware companion device

### Phase 4 Research
- Mesh networking for local sharing
- Solar charging integration
- E-ink display support
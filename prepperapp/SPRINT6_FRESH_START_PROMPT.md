# Sprint 6: Native Mobile App Development - Fresh Start Prompt

## Context & Previous Work
You are starting Sprint 6 of PrepperApp development. Sprint 5 successfully created a 249MB mobile-deployable content bundle containing 9,076 critical medical articles with sub-100ms search capability using Tantivy and SQLite with zstd compression.

## Current State
- **Completed**: Content extraction pipeline, mobile-optimized bundle (249MB), search validation
- **In Progress**: Downloading ~220GB of comprehensive survival content to external storage
- **Ready**: Mobile deployment package at `/prepperapp/data/mobile-deployment/prepperapp-p0-v1.0.0.tar.gz`

## Sprint 6 Mission
Build native iOS and Android apps that can:
1. Use the 249MB P0 bundle for core functionality (Tier 1)
2. Access external storage for comprehensive content (Tier 2 - SD cards, external drives)
3. Provide emergency-optimized UI with instant search access
4. Work 100% offline with <2% battery drain per hour

## CRITICAL: First Steps Before ANY Implementation

### 1. Read Core Documentation
```bash
# Must read these files first:
/prepperapp/CLAUDE.md                    # Project principles and guidelines
/prepperapp/SPRINT5_COMPLETION_REPORT.md # Details on content bundle structure
/prepperapp/docs/architecture/mobile.md  # Mobile architecture decisions (if exists)
```

### 2. Examine Mobile Bundle Structure
```bash
# Understand what we're deploying:
cd /prepperapp/data/mobile-deployment/prepperapp-p0-v1.0.0/
ls -la
# Check: content.db (SQLite), search_index/ (Tantivy), metadata.json
```

### 3. MANDATORY: Consult Gemini 2.5 Pro Using mcp__zen__thinkdeep

Before writing ANY code, use `mcp__zen__thinkdeep` with the following consultation points:

```
I need to architect native iOS and Android apps for PrepperApp with these constraints:
- 249MB content bundle that must extract on first launch
- Tantivy search engine integration via FFI (iOS) and JNI (Android)
- Support for external storage (220GB+ on SD cards/USB drives)
- Emergency-optimized UI (one-handed use, panic scenarios)
- 100% offline operation with <2% battery drain per hour
- Pure black OLED theme, no animations, search bar always visible

Key architectural decisions needed:
1. iOS: SwiftUI vs UIKit for emergency UI performance?
2. Android: Jetpack Compose vs traditional Views?
3. Tantivy bridge: Best practices for FFI/JNI with Rust libraries?
4. Content extraction: How to handle 249MB unzip on first launch without blocking?
5. External storage: Federated search across internal + external content?
6. Memory management: Keep under 150MB active memory with mmap'd SQLite?
7. Battery optimization: Specific techniques for search-heavy apps?
```

## Technical Requirements

### Storage Architecture
- **Tier 1 (Internal)**: 249MB P0 medical content - always available
- **Tier 2 (External)**: 220GB+ comprehensive content - SD card/USB optional
- **Configuration**: User-selectable content location in settings

### Performance Targets
- **Search Speed**: <100ms for any query (Tantivy indexed)
- **App Launch**: <2 seconds to search-ready state
- **Memory Usage**: <150MB active (use memory-mapped files)
- **Battery Drain**: <2% per hour of active use

### UI/UX Requirements
- **Theme**: Pure black OLED only (no theme switching)
- **Search**: Always visible search bar at top
- **Results**: Dense text layout, maximum content visibility
- **Navigation**: One-handed operation optimized
- **Emergency Mode**: Shake/triple-tap for critical info access

## Implementation Plan

### Phase 1: Project Setup
1. Create iOS project (Swift, minimum iOS 14)
2. Create Android project (Kotlin, minimum API 26)
3. Set up build systems for content bundle integration

### Phase 2: Content Management
1. First-launch extraction logic (249MB bundle)
2. SQLite integration with memory mapping
3. External storage detection and configuration
4. Content versioning for updates

### Phase 3: Search Integration
1. Prepare Tantivy FFI bridge (iOS)
2. Prepare Tantivy JNI bridge (Android)
3. Search UI with instant results
4. Federated search across Tier 1/2 content

### Phase 4: Emergency Features
1. Panic mode activation (shake detection)
2. Critical info quick access
3. Offline maps integration prep
4. Low-light optimized UI

## Deliverables for Sprint 6
1. iOS app with emergency UI and content extraction
2. Android app with OLED theme and SD card support
3. Documentation for Tantivy bridge implementation
4. Test plans for offline operation
5. Battery usage benchmarks

## Code Organization
```
/prepperapp/mobile/
├── ios/
│   ├── PrepperApp/
│   ├── PrepperApp.xcodeproj/
│   └── docs/
├── android/
│   ├── app/
│   ├── gradle/
│   └── docs/
├── shared/
│   ├── tantivy-bridge/  # Rust FFI/JNI code
│   └── content-schema/   # Shared content definitions
└── tests/
    ├── integration/
    └── performance/
```

## Important Notes
- This is a life-critical app - reliability over features
- Every decision must optimize for offline use and battery life
- No network features, analytics, or telemetry
- Test on low-end devices with limited storage
- Consider users in actual emergency situations

## Questions to Answer Before Starting
1. Should we support iOS 14+ or 15+ for better performance APIs?
2. Android minimum API 26 (8.0) or higher for storage features?
3. How to handle app updates without internet connectivity?
4. Backup/restore strategy for user annotations?
5. Integration with device emergency features (SOS, medical ID)?

---

**Remember**: Use `mcp__zen__thinkdeep` FIRST to thoroughly plan the architecture with Gemini 2.5 Pro before writing any code. The mobile app must be bulletproof - lives may depend on it working correctly in emergencies.
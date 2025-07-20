# Sprint 6 Architecture Summary

## Critical Decisions Made

### 1. ✅ UI Framework Selection
- **iOS**: UIKit (not SwiftUI) - Direct control, predictable performance
- **Android**: Traditional Views (not Compose) - Battle-tested, efficient
- **Rationale**: Emergency situations require instant response, no framework overhead

### 2. ✅ SQLite Storage Verification
- **Finding**: SQLite DB is 215MB with compressed BLOBs
- **Good News**: No expansion needed, fits within mobile constraints
- **Memory**: Will use mmap for zero-copy reads

### 3. ✅ Tantivy FFI/JNI Bridge Design
- **Architecture**: Minimal C interface with `#[repr(C)]` structs
- **Error Handling**: All functions wrapped in `catch_unwind`
- **Data Transfer**: Zero-copy using pointers + length
- **Files Created**:
  - `/mobile/shared/tantivy-bridge/bindings.h` - C interface
  - `/mobile/shared/tantivy-bridge/src/lib.rs` - Rust implementation
  - `/mobile/shared/tantivy-bridge/Cargo.toml` - Build config

### 4. ✅ Federated Search Strategy
- **Query Flow**: Parallel search across Tantivy + SQLite
- **Result Merging**: Exact matches → P0 content → Relevance score
- **Deduplication**: By article ID, keeping highest score
- **File Created**: `/mobile/docs/federated-search-design.md`

### 5. ✅ Content Extraction Design
- **Strategy**: Atomic, resumable extraction to temp directory
- **Progress**: Real-time progress updates on background thread
- **Verification**: Check all required files before marking complete
- **Files Created**:
  - `/mobile/shared/content-schema/ContentExtractor.swift`
  - `/mobile/shared/content-schema/ContentExtractor.kt`

## Key Architecture Insights from Gemini 2.5 Pro

### 1. FFI/JNI Critical Points
- Never let Rust panics cross FFI boundary
- Use C-compatible structs for zero-copy transfer
- Stateless, re-entrant bridge functions
- Background thread execution mandatory

### 2. Storage Concerns Addressed
- SQLite already compressed (no expansion risk)
- Use memory mapping for both SQLite and Tantivy
- Atomic extraction with resumability
- 300MB safety margin for extraction

### 3. Battery Optimization Strategy
- Pure black (#000000) OLED theme only
- 300ms search debounce
- No animations or transitions
- Force 20% brightness in-app
- No background services

### 4. Emergency Features
- Shake detection → hemorrhage control
- Volume down 3x → CPR guide
- One-handed operation optimized
- Search bar always visible

## Project Structure Created
```
/prepperapp/mobile/
├── ios/                          # iOS app (to be created)
├── android/                      # Android app (to be created)
├── shared/
│   ├── tantivy-bridge/          # Rust FFI/JNI bridge ✅
│   │   ├── bindings.h           # C interface ✅
│   │   ├── src/lib.rs          # Rust implementation ✅
│   │   └── Cargo.toml          # Build configuration ✅
│   └── content-schema/          # Shared extractors ✅
│       ├── ContentExtractor.swift ✅
│       └── ContentExtractor.kt    ✅
├── docs/
│   ├── federated-search-design.md ✅
│   └── SPRINT6_ARCHITECTURE_SUMMARY.md ✅
└── tests/
    ├── integration/
    └── performance/
```

## Next Steps (Priority Order)

### High Priority:
1. Set up iOS project with UIKit
2. Set up Android project with Views
3. Integrate 249MB bundle into app assets
4. Implement extraction on first launch

### Medium Priority:
5. Build Tantivy bridge for each platform
6. Implement emergency-optimized UI
7. Create search interface with debouncing

### Low Priority:
8. External storage support
9. Battery usage benchmarks
10. Comprehensive testing

## Risk Mitigation

### ✅ Addressed Risks:
- SQLite size explosion (verified: no risk)
- FFI panic crashes (catch_unwind implemented)
- Extraction failures (atomic operations designed)
- Search performance (federated strategy defined)

### ⚠️ Remaining Risks:
- Tantivy binary size on mobile
- iOS App Store 200MB limit (bundle is 249MB)
- Android APK size limits
- First-launch UX during extraction

## Technical Debt to Track
1. Actual unzip implementation (prototypes use placeholders)
2. Tantivy index field mapping verification
3. Search snippet generation
4. External storage permission handling
5. Proper error localization

## Success Metrics
- [ ] Content extraction < 30 seconds
- [ ] Search response < 100ms
- [ ] Memory usage < 150MB active
- [ ] Battery drain < 2% per hour
- [ ] App launch < 2 seconds

---

**Sprint 6 Status**: Architecture complete, ready for implementation
**Critical Path**: iOS/Android project setup → Bundle integration → Extraction → Search
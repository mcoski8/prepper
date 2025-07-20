# Sprint 6 Phase 2: Native Mobile App Implementation

## Context for Claude
You are continuing Sprint 6 of PrepperApp development. Phase 1 (architecture) is complete with all critical decisions made and validated by Gemini 2.5 Pro. Now we move to implementation.

## Current State
- ✅ Architecture designed: UIKit (iOS), Traditional Views (Android)
- ✅ FFI/JNI bridge contract defined with Rust implementation
- ✅ Content extraction prototypes created (atomic, resumable)
- ✅ Federated search design complete
- ✅ 249MB bundle verified and ready at `/prepperapp/data/mobile-deployment/`

## Phase 2 Mission
Create the actual iOS and Android apps with:
1. Native project setup (Xcode/Android Studio)
2. 249MB bundle integration 
3. First-launch extraction implementation
4. Emergency-optimized UI (pure black OLED)
5. Basic search functionality

## CRITICAL: Before ANY Implementation

### 1. Review Phase 1 Work
```bash
# Must read these files first:
/prepperapp/mobile/docs/SPRINT6_ARCHITECTURE_SUMMARY.md
/prepperapp/mobile/docs/federated-search-design.md
/prepperapp/SPRINT6_PROGRESS.md
```

### 2. MANDATORY: Consult Gemini 2.5 Pro Using mcp__zen__thinkdeep

Before creating ANY native projects, use `mcp__zen__thinkdeep` with model `gemini-2.5-pro` to discuss:

```
I'm implementing native iOS/Android apps for PrepperApp based on our architecture decisions:
- iOS: UIKit with 249MB bundle in app resources
- Android: Traditional Views with bundle in APK assets
- Both need first-launch extraction to app storage

Key implementation challenges to discuss:
1. iOS App Store submission with 249MB bundle (limit is 200MB compressed)
   - Should we use On-Demand Resources?
   - Or download bundle post-install?
   - Impact on offline-first principle?

2. Android APK size optimization
   - APK splitting by ABI?
   - App Bundle format considerations?
   - Extraction from assets vs expansion files?

3. First-launch UX during 30-second extraction
   - Progress UI that doesn't drain battery
   - Handling app termination mid-extraction
   - Testing extraction on low-end devices

4. Tantivy binary integration
   - Pre-compiled libraries for which architectures?
   - iOS: arm64 only or include simulator?
   - Android: arm64-v8a, armeabi-v7a, x86_64?

5. Emergency UI implementation
   - Specific UIKit optimizations for instant response?
   - Android View recycling strategies?
   - Minimum touch target sizes for panic scenarios?

Please provide specific implementation guidance for these challenges.
```

## Architecture Recap (From Phase 1)

### UI Frameworks
- **iOS**: UIKit (not SwiftUI) - Direct control, no overhead
- **Android**: Traditional Views (not Compose) - RecyclerView efficiency

### Key Features
- Pure black (#000000) OLED theme only
- Search bar always visible at top
- 300ms search debounce
- No animations or transitions
- One-handed operation optimized

### Performance Requirements
- Launch to search: <2 seconds
- Search results: <100ms
- Memory usage: <150MB active
- Battery drain: <2% per hour

## Implementation Checklist

### iOS Project Setup
- [ ] Create Xcode project (iOS 14+)
- [ ] Configure for UIKit, no SwiftUI
- [ ] Add 249MB bundle to resources
- [ ] Configure build settings for size
- [ ] Create launch screen (pure black)

### Android Project Setup  
- [ ] Create Android Studio project (API 26+)
- [ ] Configure for Views, no Compose
- [ ] Add 249MB bundle to assets
- [ ] Configure ProGuard/R8
- [ ] Create splash screen (pure black)

### Shared Implementation
- [ ] Content extraction on first launch
- [ ] Progress UI during extraction
- [ ] SQLite initialization
- [ ] Basic search UI
- [ ] Error handling

## File Organization
```
/prepperapp/mobile/
├── ios/
│   ├── PrepperApp.xcodeproj
│   ├── PrepperApp/
│   │   ├── AppDelegate.swift
│   │   ├── ContentManager.swift
│   │   ├── SearchViewController.swift
│   │   └── Resources/
│   │       └── prepperapp-p0-v1.0.0.zip
│   └── PrepperAppTests/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── java/com/prepperapp/
│   │   │   ├── assets/
│   │   │   │   └── prepperapp-p0-v1.0.0.zip
│   │   │   └── res/
│   │   └── build.gradle
│   └── gradle/
└── shared/
    └── [existing FFI bridge code]
```

## Testing Focus
1. Extraction on devices with <1GB free space
2. Search during extraction (should fail gracefully)
3. App termination during extraction
4. Memory usage on 2GB RAM devices
5. Battery drain measurement

## Questions to Resolve with Gemini
1. Best approach for iOS 200MB limit?
2. Android architecture-specific APKs?
3. Extraction progress UI patterns?
4. Tantivy binary distribution strategy?
5. Accessibility in emergency scenarios?

---

**Remember**: 
1. Use `mcp__zen__thinkdeep` FIRST to thoroughly discuss implementation challenges
2. This app must work in life-threatening situations
3. Every decision impacts battery life and response time
4. Test on the lowest-end devices you can find
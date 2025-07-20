# Sprint 6 Prompt - Mobile App Development

## Context
You are continuing development of PrepperApp after successfully completing Sprint 5. The previous sprint achieved a major milestone: creating a 249MB mobile-deployable content bundle with 9,076 critical medical articles and sub-100ms search capability.

## Previous Work Summary
- **Sprint 5 Completion**: Mobile-optimized content bundle ready
  - SQLite database: 215MB (zstd compressed)
  - Tantivy index: 34MB (Basic indexing, no positional data)
  - Deployment package: `prepperapp-p0-v1.0.0.tar.gz`
  - Search validation: 4/9 queries had minor relevance issues (acceptable for v1.0)

## Sprint 6 Objectives
Create the mobile app scaffolding for iOS and Android that can integrate the content bundle and provide emergency-optimized UI.

## Key Requirements
1. **Native Performance**: Use Swift (iOS) and Kotlin (Android)
2. **Offline-First**: All functionality must work without connectivity
3. **Battery Efficiency**: Pure black OLED theme, no animations
4. **Fast Access**: Search bar always visible, <1 second to results
5. **Integration Ready**: Prepare for Tantivy FFI/JNI bridges

## IMPORTANT: Gemini 2.5 Pro Consultation
Before implementing ANY code or making architectural decisions, you MUST:

1. **Use mcp__zen__thinkdeep** to thoroughly analyze the mobile app architecture with Gemini 2.5 Pro
2. **Discuss**:
   - Optimal app structure for both iOS and Android
   - FFI/JNI bridge design patterns for Tantivy integration
   - Content bundle extraction and storage strategy
   - Emergency UI/UX patterns (one-handed use, panic mode)
   - Battery optimization techniques
   - Search integration architecture
3. **Consider**:
   - Should we use SwiftUI or UIKit for iOS?
   - Jetpack Compose or traditional Views for Android?
   - How to handle the 249MB bundle extraction on first launch?
   - Memory-mapped file access for the SQLite database
   - Thread-safe search with Tantivy bridges

## Technical Constraints
- **Bundle Size**: Apps must handle 249MB content extraction
- **Memory**: Keep active usage under 150MB
- **Battery**: Target <2% drain per hour of active use
- **Storage**: Support both internal and SD card (Android)

## Deliverables for Sprint 6
1. iOS app scaffolding with emergency UI
2. Android app scaffolding with OLED theme
3. Content extraction and storage logic
4. Basic search UI (prepare for Tantivy integration)
5. Documentation for FFI/JNI bridge requirements

## Files to Reference
- `/prepperapp/CLAUDE.md` - Project guidelines and principles
- `/prepperapp/SPRINT5_COMPLETION_REPORT.md` - Details on content bundle
- `/prepperapp/data/mobile-deployment/prepperapp-p0-v1.0.0/` - Bundle structure

## First Steps
1. Read CLAUDE.md to understand project principles
2. Review the mobile deployment bundle structure
3. Use mcp__zen__thinkdeep to plan the architecture with Gemini
4. Only after thorough planning, begin implementation

Remember: This is a life-critical app. Every decision must prioritize reliability, speed, and battery efficiency over features or aesthetics.
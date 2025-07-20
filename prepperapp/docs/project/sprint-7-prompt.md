# PrepperApp Sprint 7: iOS Content System Implementation

## Context for New Session

You are continuing work on PrepperApp, an offline-first survival knowledge base for iOS/Android. The app is designed for SHTF (Shit Hits The Fan) scenarios and must work with zero connectivity.

### Current State
- **Sprint 6 Complete**: iOS foundation with content-agnostic architecture
- **Working iOS App**: Tab navigation, emergency UI, search, browse
- **Test Content**: 17 emergency procedures (56KB) with SQLite search
- **Architecture**: Supports content from 10MB to 220GB via three-tier system

### Three-Tier Content Strategy
1. **Tier 1**: Essential Core (2-3GB) - Always on device
2. **Tier 2**: Adaptive Bundles (1-5GB each) - User selectable modules  
3. **Tier 3**: Complete Archive (220GB) - External USB/Lightning storage

### Key Files to Review
- `/docs/content/content-acquisition.md` - Full 220GB content breakdown
- `/docs/development/ios-first-strategy.md` - Current iOS approach
- `/iOS/PrepperApp/Services/ContentManager.swift` - Content loading system
- `CLAUDE.md` - Project guidelines and principles

## Sprint 7 Objectives

### Primary Goals
1. **Implement Tier 1 Content Delivery**
   - Design On-Demand Resources or custom downloader
   - Handle 2-3GB essential content
   - Background downloads with resume capability
   - Progress tracking and error handling

2. **Build Module System Foundation (Tier 2)**
   - Module discovery and metadata
   - Download queue management
   - Storage management UI
   - Module enable/disable functionality

3. **External Storage POC (Tier 3)**
   - Security-scoped bookmarks implementation
   - USB/Lightning drive detection
   - Federated search across all tiers

### IMPORTANT: Gemini 2.5 Pro Discussion Required

**Before implementing anything**, you MUST:

1. **Discuss thoroughly with Gemini 2.5 Pro** about:
   - Optimal content delivery strategy for iOS (On-Demand Resources vs custom)
   - Best practices for handling 2-3GB downloads on iOS
   - Security-scoped bookmarks implementation details
   - Performance optimizations for searching across 220GB
   - Battery-efficient background downloading
   - Storage management best practices

2. **Ask Gemini to review**:
   - Current ContentManager architecture
   - Proposed download manager design
   - External storage access patterns
   - Search federation strategies

3. **Get Gemini's input on**:
   - Potential optimizations we haven't considered
   - Common pitfalls with large content on iOS
   - Alternative approaches to three-tier architecture
   - User experience for storage management

4. **Present findings** to user before implementation

### Technical Constraints
- iOS 15+ minimum
- No third-party dependencies
- Battery efficiency is critical
- Must work 100% offline after content download
- Search must remain <100ms even with 220GB

### Success Criteria
- Can download and manage 2-3GB Tier 1 content
- Module system supports adding/removing content packs
- External storage POC demonstrates 220GB access
- All search queries complete in <100ms
- No degradation in battery efficiency

## Instructions for Assistant

1. Start by reading the key files mentioned above
2. **MANDATORY**: Engage in detailed discussion with Gemini 2.5 Pro about ALL aspects listed above
3. Present optimization findings and recommendations to user
4. Only proceed with implementation after user approves the plan
5. Focus on iOS implementation (Android is deferred)
6. Maintain content-agnostic architecture principles
7. Test thoroughly on multiple scenarios
8. Update documentation as you progress

Remember: The app must be ultra-reliable in emergency situations. Every decision should prioritize reliability, battery efficiency, and speed of access over features.

## Additional Context
- User is non-technical but knowledgeable about the domain
- User has iOS devices only for testing
- Primary market is iOS users
- External content is already downloaded to `/Volumes/Vid SSD/PrepperApp-Content/`
- Total content size is 220GB across 11 categories

Begin by discussing the implementation plan with Gemini 2.5 Pro, focusing on finding optimizations and identifying any necessary architectural changes before proceeding with development.
# iOS-First Development Strategy

**Created:** July 20, 2025  
**Status:** Active Development

## Overview

After consulting with Gemini 2.5 Pro and analyzing project constraints, PrepperApp is following an iOS-first development strategy. This document outlines the rationale, approach, and current implementation status.

## Key Decision Factors

1. **Founder Testing Capability**: Only iOS devices available for testing
2. **Primary Market**: iOS users are the initial target audience  
3. **External Storage**: iOS can access external drives (with user permission)
4. **Development Efficiency**: Focus resources on one platform first

## Content Strategy Update

### Original Vision
- Tier 1: 2-3GB on device
- Tier 2: 1-5GB modules  
- Tier 3: 220GB external archive

### iOS Reality Check
- **Good News**: External storage IS possible via security-scoped bookmarks
- **Challenge**: Requires one-time user setup through UIDocumentPicker
- **Decision**: Proceed with all tiers, but focus on Tiers 1-2 for MVP

## Current Implementation Status

### ✅ Completed

1. **Content Infrastructure**
   - `ContentManager.swift` - Discovers and loads content from multiple sources
   - `ContentModels.swift` - Manifest-driven content system
   - SQLite-based article storage
   - Fallback content for reliability

2. **Core UI Components**
   - `MainTabBarController` - Tab-based navigation
   - `EmergencyViewController` - Instant access to priority 0 content
   - `SearchViewController` - Primary interaction method
   - `BrowseViewController` - Category exploration
   - `ArticleDetailViewController` - Content display

3. **Test Content**
   - 17 emergency procedures (56KB)
   - Covers bleeding, CPR, choking, water, shelter
   - Bundled with app for offline development

4. **Content-Agnostic Design**
   - Apps adapt to any content size (10MB to 220GB)
   - Dynamic UI based on available features
   - No hardcoded assumptions

### 🚧 In Progress

1. **Search Enhancement**
   - Full-text search implementation
   - Search result ranking
   - Snippet extraction

2. **UI Polish**  
   - Emergency mode (larger text, stripped UI)
   - Gesture support for one-handed use
   - Accessibility features

### 📋 Planned

1. **Content Delivery (Tier 1)**
   - On-Demand Resources or custom downloader
   - 2-3GB of essential survival content
   - Background downloads with resume

2. **Module System (Tier 2)**
   - 1-5GB downloadable content packs
   - In-app purchase integration
   - Storage management UI

3. **External Storage (Tier 3)**
   - Proof of concept for 220GB access
   - Security-scoped bookmark implementation
   - Federated search across all content

## Architecture Decisions

### Content Discovery Priority
1. **Bundled** - Test content for development
2. **Documents** - Downloaded Tier 1/2 content  
3. **App Group** - Shared with extensions
4. **External** - Tier 3 via USB/Lightning drives

### UI Principles
- **Pure Black**: OLED battery optimization
- **High Contrast**: Emergency visibility
- **Large Touch Targets**: Shaking hands
- **Minimal Taps**: 2-second access rule

### Technical Choices
- **UIKit**: Mature, stable, performant
- **SQLite**: Fast queries, small footprint
- **No Dependencies**: Reliability over features

## Development Phases

### Phase 1: iOS MVP (Current)
- Basic search and browse
- Emergency quick access
- Test content only
- **Timeline**: 2-3 weeks

### Phase 2: Content System
- Tier 1 implementation
- Download manager
- Real medical content
- **Timeline**: 2-3 weeks

### Phase 3: Enhancement
- Tier 2 modules
- External storage POC
- Performance optimization
- **Timeline**: 3-4 weeks

### Phase 4: Android Port (Future)
- After iOS market validation
- Apply lessons learned
- Consider hiring Android developer
- **Timeline**: Post-iOS success

## Testing Strategy

### Device Coverage
- iPhone 15 Pro (primary development)
- iPhone 12 mini (small screen)
- iPhone 8 (older device)
- iPad (tablet layout)

### Test Scenarios  
- Airplane mode (offline)
- Low battery (< 20%)
- One-handed use
- Bright sunlight
- Panic simulation

## Success Metrics

1. **Performance**
   - Search results < 100ms
   - App launch < 2 seconds
   - Battery drain < 2% per hour

2. **Reliability**
   - Works 100% offline
   - No crashes in emergency use
   - Graceful degradation

3. **Usability**
   - Find bleeding control < 10 seconds
   - Readable in all conditions
   - Usable with one hand

## Lessons Learned

1. **External Storage Limitations**: iOS requires user interaction for external drive access. This is acceptable for power users but not suitable for primary content delivery.

2. **Content Size Reality**: Even 2-3GB is large for many users. Need smart content selection and compression.

3. **Search is King**: In emergencies, browsing is too slow. Search must be lightning fast and forgiving.

4. **Battery Matters**: Pure black UI and minimal processing are non-negotiable for emergency use.

## Next Steps

1. Complete search enhancements
2. Begin Tier 1 content integration  
3. Test on multiple devices
4. Gather early user feedback
5. Plan Android approach based on iOS learnings

---

*This document reflects the current iOS-first strategy. Updates will be made as development progresses and lessons are learned.*
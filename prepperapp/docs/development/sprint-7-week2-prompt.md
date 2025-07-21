# PrepperApp Sprint 7 Week 2: Module System Implementation

## Context for New Session

You are continuing work on PrepperApp Sprint 7. Week 1 successfully delivered the download infrastructure with smart chunking, background downloads, and progress tracking. Now we move to Week 2: Module System Foundation.

## Current State

### ✅ Week 1 Completed
- ContentDownloadManager with 100MB chunking
- Background URLSession support
- Progress tracking and persistence
- Download UI with pause/resume/cancel
- Storage preflight checks
- SHA-256 chunk validation
- Exponential backoff retry logic

### 📦 Content Downloads in Progress
The user is actively downloading the 220GB content archive. Key items already downloaded:
- Wikipedia ZIM file (87GB) - COMPLETE ✅
- Other content still downloading - DO NOT interfere with downloads

## Week 2 Objectives: Module System Foundation

### Primary Goals

1. **Module Discovery Service**
   - JSON-based module catalog
   - Module metadata (size, version, dependencies)
   - Category organization
   - Search/filter capabilities

2. **Module Browser UI**
   - Visual module cards with descriptions
   - Download size and storage impact
   - Dependency visualization
   - One-tap download initiation

3. **Module Management**
   - Enable/disable downloaded modules
   - Storage space reclamation
   - Module update checking
   - Dependency resolution

4. **Integration Points**
   - Hook into existing ContentDownloadManager
   - Update ContentManager for module loading
   - Extend search to include module status

## 🚨 CRITICAL: Gemini 2.5 Pro Discussion Required

Before implementing ANYTHING, you MUST have a thorough discussion with Gemini 2.5 Pro about:

### Architecture Questions
1. **Module Catalog Design**
   - Static JSON vs dynamic server API?
   - Versioning strategy for modules
   - How to handle module updates
   - Offline catalog caching

2. **Dependency Management**
   - Graph-based dependency resolution
   - Circular dependency prevention
   - Version compatibility checking
   - Graceful handling of missing dependencies

3. **Storage Architecture**
   - Module isolation strategies
   - Shared resource deduplication
   - Atomic module installation/removal
   - Rollback capabilities

4. **UI/UX Optimization**
   - Module discovery patterns
   - Visual dependency representation
   - Storage impact visualization
   - Download prioritization UI

### Performance Considerations
1. **Module Loading**
   - Lazy loading strategies
   - Memory-mapped module access
   - Module preloading based on usage
   - Background module indexing

2. **Search Integration**
   - Federated search across modules
   - Module-specific search indexes
   - Search result attribution
   - Performance with many modules

### Ask Gemini About
- Best practices for iOS module systems
- Lessons from App Store and On-Demand Resources
- Module signing and verification
- Differential updates for large modules
- User trust and security considerations

## Technical Constraints

- Maintain <100ms search performance
- Support offline module browsing
- No third-party dependencies
- Battery-efficient module loading
- Compatible with existing download infrastructure

## Implementation Notes

### Module Catalog Structure (Draft)
```json
{
  "version": "1.0",
  "modules": [
    {
      "id": "medical-advanced",
      "name": "Advanced Medical Procedures",
      "category": "medical",
      "size": 1073741824,
      "version": "2024.1",
      "dependencies": ["medical-basic"],
      "description": "Surgical procedures, advanced diagnostics",
      "priority": "high",
      "downloadUrl": "https://content.prepperapp.com/modules/medical-advanced.ppmod",
      "checksum": "sha256:..."
    }
  ]
}
```

### Module Storage Layout
```
Documents/
├── modules/
│   ├── catalog.json
│   ├── medical-basic/
│   │   ├── manifest.json
│   │   ├── content.db
│   │   └── assets/
│   └── medical-advanced/
│       ├── manifest.json
│       ├── content.db
│       └── assets/
```

## Success Criteria

1. **Module Discovery**
   - Browse available modules by category
   - Search modules by name/description
   - View module details and dependencies

2. **Download Integration**
   - One-tap module download
   - Progress tracked in Download Manager
   - Automatic dependency resolution

3. **Module Management**
   - Enable/disable modules without deletion
   - Clear storage space visualization
   - Module update notifications

4. **Performance**
   - Module list loads instantly
   - No impact on search performance
   - Minimal memory overhead

## ⚠️ Important Reminders

1. **Do NOT interfere with ongoing downloads** - The user is downloading 220GB of content
2. **Discuss thoroughly with Gemini 2.5 Pro** before implementation
3. **Test with mock data** - Don't rely on real module servers yet
4. **Maintain offline-first** principles
5. **Keep UI pure black** for OLED optimization

## Instructions for Assistant

1. Start by reviewing Week 1 implementation files:
   - `/docs/development/sprint-7-week1-progress.md`
   - `ContentDownloadManager.swift`
   - `DownloadModels.swift`

2. **MANDATORY**: Engage with Gemini 2.5 Pro about ALL architectural decisions

3. Present findings and optimizations to user before coding

4. Focus on module discovery and UI first

5. Create mock module catalog for testing

6. Update documentation as you progress

## Next Steps After Week 2

Week 3 will focus on:
- External storage integration (Tier 3)
- Security-scoped bookmarks
- 220GB content access
- Federated search optimization

Remember: The app must remain ultra-reliable for emergency use. Every decision should prioritize reliability, battery efficiency, and speed of access.

---

*Use `/clear` after loading this prompt to start with a fresh context window*
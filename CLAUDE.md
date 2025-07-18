# PrepperApp - AI Context & Guidelines

## Project Overview
PrepperApp is a native iOS/Android offline-first survival knowledge base designed for SHTF (Shit Hits The Fan) and TEOTWAWKI (The End Of The World As We Know It) scenarios. The app must function with zero connectivity and optimize for battery efficiency during emergencies.

## Core Principles
1. **Offline-First**: All functionality must work without internet/cellular connectivity
2. **Battery Efficiency**: Every design decision must consider power consumption
3. **Fast Access**: Information retrieval must be instant - lives may depend on it
4. **Modular Architecture**: Core essentials built-in, extended content via modules
5. **Evidence-Based**: Only proven, practical survival information - no fantasies

## Architecture Summary
- **Tier 1 (Core App)**: 500MB-1GB of critical 72-hour survival info
- **Tier 2 (Modules)**: 1-5GB downloadable content packs for specific needs
- **Tier 3 (Archive)**: External storage support for comprehensive references (Wikipedia, maps)

## Tech Stack
- **Languages**: Kotlin (Android), Swift (iOS) - native for maximum performance
- **Search Engine**: Tantivy (Rust) - pre-built indexes for instant search
- **Content Format**: ZIM files (compressed, indexed offline content)
- **Data Format**: FlatBuffers for structured data (zero-parse overhead)
- **Compression**: Zstandard with custom dictionaries
- **UI Theme**: Pure black OLED theme only (battery optimization)

## Content Philosophy
### MUST HAVE (Core App)
- Hemorrhage control, tourniquets, wound care
- Hypothermia/hyperthermia treatment
- Water purification methods
- Poisonous plant/animal identification
- Basic first aid procedures

### NICE TO HAVE (Modules)
- Comprehensive medical guides
- Regional foraging information
- Advanced shelter construction
- Communications/radio guides

### AVOID (No Value)
- Tactical combat scenarios
- Complex economic theories
- Esoteric chemistry
- Endless gear reviews
- Prepper fantasies

## Development Guidelines

### Code Quality
- Prioritize performance over elegance
- Minimize memory allocations
- Use async/await for all I/O operations
- Profile battery usage for every feature
- No background services or animations

### Testing Requirements
- Stress test with 100GB+ external storage
- Battery drain tests (target: <2% per hour active use)
- Search performance benchmarks (<100ms for any query)
- Offline functionality validation
- Low-memory device testing

### Documentation Standards
All documentation lives in `/docs` with clear categorization:
- Architecture decisions
- API specifications
- Content curation guides
- UI/UX guidelines
- Sprint tracking

## Current Sprint Focus
1. Create comprehensive documentation structure
2. Design content curation pipeline
3. Prototype Tantivy search integration
4. Create emergency-optimized UI mockups

## Key Commands
```bash
# Build commands (to be defined)
npm run lint
npm run typecheck
npm run test
npm run build:ios
npm run build:android
```

## External Resources
- ZIM Format: https://wiki.openzim.org/wiki/ZIM_file_format
- Tantivy: https://github.com/quickwit-oss/tantivy
- Kiwix (ZIM reader): https://github.com/kiwix/kiwix-lib

## Content Acquisition
For external content that needs to be downloaded (Wikipedia, maps, medical guides, etc.), see:
- **Content Acquisition Guide**: `/docs/content/content-acquisition.md`
- This file tracks all external downloads needed, with instructions for both automated and manual acquisition
- Check this file regularly for content download status and blockers

## AI Assistant Notes
When working on this project:
1. Always consider battery impact of any feature
2. Optimize for search speed and content compression
3. Focus on practical survival needs, not edge cases
4. Test on resource-constrained devices
5. Ensure all features work completely offline
6. Prioritize medical emergencies and water safety
7. Use pre-computation wherever possible (indexes, compressed assets)

## Contact
Project Lead: [To be defined]
Repository: [To be created]

Last Updated: 2025-07-18
# PrepperApp Sprint 1 - Initial Coding Prompt

## Project Context
You are starting development on PrepperApp, an offline-first survival knowledge base for iOS and Android. All documentation is in `/Users/michaelchang/Documents/claudecode/prepper/`. Read CLAUDE.md first for project overview.

## Sprint 1 Goals (2 weeks)
Build the technical foundation and prove core concepts work:
1. Create iOS and Android app shells with navigation
2. Implement Tantivy search integration (Rust → Swift/Kotlin bridges)
3. Basic ZIM file reader using Kiwix-lib
4. Search-first UI with emergency optimizations
5. Proof of concept with 100 sample articles

## Your First Actions

### 1. Review Critical Documentation
```bash
cd /Users/michaelchang/Documents/claudecode/prepper
cat CLAUDE.md  # Project overview and principles
cat docs/architecture/system-design.md  # Technical architecture
cat docs/architecture/search-architecture.md  # Tantivy integration details
cat docs/ui-ux/design-system.md  # Emergency UI requirements
cat docs/project/sprint-tracker.md  # Current sprint details
```

### 2. Consult with Gemini 2.5
After reviewing the docs, discuss your implementation plan with Gemini 2.5 Pro to:
- Validate the Tantivy mobile integration approach
- Optimize the Rust → Swift/Kotlin bridge design
- Identify potential performance bottlenecks
- Discuss battery optimization strategies
- Review the emergency UI implementation approach
- Get alternative perspectives on architecture decisions

Key discussion points for Gemini:
1. Is Tantivy the best choice for mobile search, or should we consider alternatives?
2. How can we minimize battery drain during search operations?
3. What's the most efficient way to handle 100GB+ external storage?
4. Should we use React Native instead of fully native for faster development?
5. How do we ensure <100ms search response times on older devices?

### 3. Create Project Structure
After Gemini consultation, set up the basic project structure:

```
prepperapp/
├── ios/                    # iOS native app (Swift)
├── android/                # Android native app (Kotlin)
├── rust/                   # Shared Rust libraries
│   ├── tantivy-mobile/    # Tantivy search engine wrapper
│   └── kiwix-mobile/      # ZIM reader wrapper
├── content/               # Sample content for testing
│   ├── core/             # 100 test articles
│   └── indexes/          # Pre-built Tantivy indexes
├── scripts/              # Build and utility scripts
└── tests/               # Cross-platform tests
```

### 4. Technical Priorities

#### Phase 1: Rust Libraries (Days 1-3)
1. Create `tantivy-mobile` crate with C FFI
2. Implement basic search operations
3. Create iOS/Android build scripts
4. Test on both platforms

#### Phase 2: Native App Shells (Days 4-6)
1. iOS app with search bar and results list
2. Android app with same functionality
3. Pure black OLED theme implementation
4. Large touch targets (48dp minimum)

#### Phase 3: Integration (Days 7-10)
1. Connect Rust libraries to native apps
2. Implement ZIM file reading
3. Create sample content
4. Performance testing

#### Phase 4: Polish & Testing (Days 11-14)
1. Battery usage optimization
2. Search performance tuning
3. UI stress testing
4. Documentation updates

## Key Technical Decisions to Implement

### Search Integration
- Use Tantivy 0.22+ with mobile optimizations
- Pre-built indexes for instant search
- Memory-mapped files for large indexes
- Fuzzy search with Levenshtein distance ≤ 2

### UI Implementation
- Pure black background (#000000) always
- White text only (#FFFFFF)
- No animations or transitions
- Search bar always visible at top
- One-handed operation design

### Performance Targets
- App launch to search: <1 second
- Search results: <100ms
- Memory usage: <150MB active
- Battery drain: <2% per hour

## Critical Code Examples

### Rust FFI for Tantivy
```rust
#[no_mangle]
pub extern "C" fn tantivy_search(
    query: *const c_char,
    limit: i32
) -> *mut SearchResults {
    // Implementation here
}
```

### iOS Bridge
```swift
class TantivyBridge {
    func search(_ query: String) -> [SearchResult] {
        // Call Rust FFI
    }
}
```

### Android Bridge
```kotlin
class TantivyBridge {
    external fun search(query: String): Array<SearchResult>
    
    companion object {
        init {
            System.loadLibrary("tantivy_mobile")
        }
    }
}
```

## Testing Requirements
- Create 100 sample survival articles covering:
  - Medical emergencies (30 articles)
  - Water safety (20 articles)
  - Dangerous plants/animals (20 articles)  
  - Shelter/fire (20 articles)
  - Navigation/signals (10 articles)

## Success Criteria for Sprint 1
- [ ] Both iOS and Android apps launch and display search
- [ ] Tantivy search returns results in <100ms
- [ ] Can read and display content from ZIM file
- [ ] Pure black OLED theme implemented
- [ ] Battery usage <2% per hour of active use
- [ ] All code has unit tests
- [ ] Documentation updated with learnings

## Remember
1. **Offline-first**: No network calls ever
2. **Battery-first**: Every decision optimizes power
3. **Speed-first**: Information access must be instant
4. **Simple-first**: No fancy features, just fast access to life-saving info

## Next Steps After Sprint 1
- Sprint 2: Module system for downloadable content
- Sprint 3: External storage support
- Sprint 4: Advanced search features

---

Start by reviewing the documentation, then consult with Gemini 2.5 Pro about the technical approach. After that consultation, begin with the Rust library implementation as it's the foundation everything else depends on.

Good luck! Lives may literally depend on this app working flawlessly offline.
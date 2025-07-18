# Sprint 4 Implementation Plan

Based on comprehensive consultation with Gemini 2.5 Pro, here's our implementation strategy for Sprint 4.

## Key Decisions & Insights

### Content Processing Strategy
- **Two-Stage Pipeline**: Python orchestrator + Rust indexer
- **Batch Processing**: Process 1,000-5,000 articles per batch to balance memory and efficiency
- **Streaming Architecture**: Avoid loading entire ZIM into memory
- **Checkpointing**: Save progress after each batch for resumability
- **Use tqdm**: For better progress reporting

### Index Optimization
- **Compression**: Use LZ4 block format (fastest decompression for mobile)
- **Schema Design**: 
  - Don't store `content` field (only index it)
  - Store only `id`, `title`, `summary` with LZ4 compression
  - Use simple tokenizer with stemming to reduce index size
- **Target**: <10% of original content size (~400MB from 4.2GB)

### Mobile Integration Patterns
- **Singleton Services**: `SearchService` on both platforms
- **Modern Async**: Swift async/await, Kotlin coroutines
- **JSON Serialization**: Direct Codable/kotlinx.serialization
- **FFI Memory Management**: Add `free_rust_string` function

### Performance Optimization
- **App Binary**: Use Rust release profile optimizations (LTO, strip, opt-level="z")
- **Asset Packaging**: Bundle as compressed `core_assets.zip`
- **Pre-warming**: Load index on app start, optional dummy search
- **Thread Count**: Test with 2 threads vs 4 for battery efficiency
- **Measurement Tools**: 
  - iOS: Instruments (Energy Log, Time Profiler)
  - Android: androidx.benchmark, Battery Historian

### UI/UX for Emergency Use
- **No Progressive Loading**: Keep simple one-shot search
- **Skeleton Screens**: Show during 1-second initialization
- **Emergency Cards**: 
  - Massive touch targets (min 100pt height)
  - Priority color indicators (red/yellow/gray)
  - High contrast, large fonts
  - Support Dynamic Type
- **Accessibility**: Voice search, haptic feedback

## Implementation Order

### Phase 1: Content Pipeline Infrastructure
1. Create `tantivy-indexer` Rust binary
2. Refactor `extract_curated_zim.py` for streaming/checkpointing
3. Add image extraction to content pipeline

### Phase 2: Content Processing
4. Download Wikipedia Medical ZIM (4.2GB)
5. Run extraction pipeline with medical priorities
6. Build and optimize Tantivy indexes

### Phase 3: Mobile Integration
7. Update FFI with `free_rust_string` function
8. Implement iOS SearchService with async/await
9. Implement Android SearchService with coroutines
10. Add index bundling and first-launch copy logic

### Phase 4: UI Implementation
11. Create skeleton screens for both platforms
12. Build emergency-optimized result cards
13. Add voice search capability
14. Implement haptic feedback

### Phase 5: Testing & Optimization
15. Profile on real devices (mid-range targets)
16. Measure cold start time (<1 second target)
17. Verify battery usage (<2% per hour)
18. Test with 2 vs 4 threads for optimal efficiency

## Code Templates

### Rust tantivy-indexer (Cargo.toml)
```toml
[dependencies]
tantivy = "0.22"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
anyhow = "1.0"
clap = { version = "4.0", features = ["derive"] }

[profile.release]
lto = "fat"
codegen-units = 1
panic = "abort"
strip = true
opt-level = "z"
```

### Python Batch Processing
```python
def process_batch(self, articles: List[Dict], batch_num: int):
    batch_file = self.temp_dir / f"batch_{batch_num:04d}.jsonl"
    with open(batch_file, 'w', encoding='utf-8') as f:
        for article in articles:
            f.write(json.dumps(article) + '\n')
    
    index_path = self.output_dir / "tantivy_index"
    cmd = ['tantivy-indexer', '--index', str(index_path), '--input', str(batch_file)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Indexing failed for batch {batch_num}")
```

### Swift SearchService Pattern
```swift
final class SearchService {
    static let shared = SearchService()
    private var managerPtr: OpaquePointer?
    
    func search(query: String, config: SearchConfig) async throws -> [SearchResult] {
        // Async FFI call with proper JSON handling
    }
}
```

### Kotlin SearchService Pattern
```kotlin
object SearchService {
    private var managerPtr: Long = 0L
    
    suspend fun search(query: String, config: SearchConfig): List<SearchResult> = 
        withContext(Dispatchers.IO) {
            // Coroutine-based FFI call
        }
}
```

## Success Criteria
- [ ] Wikipedia Medical processed to <400MB index
- [ ] Cold start to search ready: <1 second
- [ ] Search query latency: <100ms
- [ ] Battery drain: <2% per hour active use
- [ ] App size with core content: <200MB
- [ ] All tests passing on iOS 15+ and Android API 29+

## Next Steps
1. Start with creating the `tantivy-indexer` Rust binary
2. Refactor the Python extraction script for streaming
3. Begin the Wikipedia Medical download and processing

---

Generated: 2025-07-18
Sprint Duration: 2 weeks
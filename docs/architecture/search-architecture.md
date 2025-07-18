# PrepperApp Search Architecture

## Overview
PrepperApp uses Tantivy, a full-text search engine library written in Rust, to provide instant search capabilities across gigabytes of offline content. This document details the search architecture, integration approach, and optimization strategies.

## Why Tantivy?

### Performance Comparison
| Feature | Tantivy | Lucene | Bleve | SQLite FTS |
|---------|---------|--------|-------|------------|
| Query Speed | ~50ms | ~100ms | ~150ms | ~200ms |
| Index Size | 15% | 20% | 25% | 30% |
| Memory Usage | Low | Medium | High | Low |
| Startup Time | <10ms | ~500ms | ~100ms | <50ms |
| No GC Overhead | ✓ | ✗ | ✗ | ✓ |
| Mobile Optimized | ✓ | ✗ | ✗ | ✓ |

### Key Advantages
- **Zero Garbage Collection**: Rust's memory management eliminates GC pauses
- **Memory Mapped Files**: Efficient large index handling
- **SIMD Optimizations**: Hardware-accelerated search operations
- **Compact Indexes**: Smaller storage footprint critical for mobile

## Architecture Design

### High-Level Search Flow
```
User Query → Query Parser → Search Executor → Result Ranker → UI Renderer
     ↓            ↓              ↓               ↓              ↓
  (Input)    (Tokenize)    (Index Scan)    (BM25 Score)   (Display)
```

### Component Architecture
```
┌─────────────────────────────────────────────────────────┐
│                   Search Service                         │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │Query Parser │  │Index Manager │  │Result Processor│ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
├─────────────────────────────────────────────────────────┤
│                  Tantivy Engine                          │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │  Tokenizer  │  │   Searcher   │  │    Scorer     │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
├─────────────────────────────────────────────────────────┤
│                   Index Storage                          │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │Core Index   │  │Module Indexes│  │User Index     │ │
│  │(In Memory)  │  │(Lazy Loaded) │  │(Bookmarks)    │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Index Schema Design

### Field Definitions
```rust
// Tantivy schema for survival content
pub fn create_schema() -> Schema {
    let mut schema_builder = Schema::builder();
    
    // Primary fields
    schema_builder.add_text_field("title", TEXT | STORED);
    schema_builder.add_text_field("content", TEXT);
    schema_builder.add_text_field("summary", TEXT | STORED);
    
    // Categorization
    schema_builder.add_facet_field("category", INDEXED | STORED);
    schema_builder.add_u64_field("priority", INDEXED | STORED | FAST);
    
    // Metadata
    schema_builder.add_text_field("keywords", TEXT);
    schema_builder.add_date_field("updated", INDEXED | STORED);
    schema_builder.add_text_field("module_id", STRING | STORED);
    
    // Special fields
    schema_builder.add_text_field("phonetic", TEXT); // For fuzzy search
    schema_builder.add_bytes_field("embedding", STORED); // Future: vector search
    
    schema_builder.build()
}
```

### Tokenization Strategy
```rust
// Custom tokenizer for medical/survival content
pub fn create_tokenizer() -> TextAnalyzer {
    TextAnalyzer::from(SimpleTokenizer)
        .filter(RemoveLongFilter::limit(40))
        .filter(LowerCaser)
        .filter(StopWordFilter::new(custom_stopwords()))
        .filter(Stemmer::new(Language::English))
        .filter(SynonymFilter::new(medical_synonyms()))
}

// Preserve medical terms while stemming common words
fn custom_stopwords() -> Vec<&'static str> {
    vec!["the", "a", "an"] // Minimal stopwords
}

fn medical_synonyms() -> HashMap<String, Vec<String>> {
    hashmap! {
        "heart attack" => vec!["cardiac arrest", "MI", "myocardial infarction"],
        "bleeding" => vec!["hemorrhage", "blood loss"],
        "CPR" => vec!["cardiopulmonary resuscitation"],
        // ... extensive medical synonym mapping
    }
}
```

## Search Implementation

### iOS Integration (Swift)
```swift
// Swift wrapper for Tantivy via C FFI
public class SearchEngine {
    private let tantivy: OpaquePointer
    private let queue = DispatchQueue(label: "search", attributes: .concurrent)
    
    public init(indexPath: String) throws {
        // Initialize Tantivy through C bridge
        guard let engine = tantivy_create_engine(indexPath) else {
            throw SearchError.initializationFailed
        }
        self.tantivy = engine
    }
    
    public func search(_ query: String, limit: Int = 20) async throws -> [SearchResult] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let results = tantivy_search(self.tantivy, query, Int32(limit))
                continuation.resume(returning: self.parseResults(results))
            }
        }
    }
}
```

### Android Integration (Kotlin)
```kotlin
// Kotlin wrapper using JNI
class SearchEngine(private val indexPath: String) {
    companion object {
        init {
            System.loadLibrary("tantivy_jni")
        }
    }
    
    private external fun nativeCreateEngine(path: String): Long
    private external fun nativeSearch(engine: Long, query: String, limit: Int): Array<SearchResult>
    
    private val engineHandle: Long = nativeCreateEngine(indexPath)
    
    suspend fun search(query: String, limit: Int = 20): List<SearchResult> = 
        withContext(Dispatchers.IO) {
            nativeSearch(engineHandle, query, limit).toList()
        }
}
```

### Rust Core Implementation
```rust
// Core search implementation
#[no_mangle]
pub extern "C" fn tantivy_search(
    engine: *mut SearchEngine,
    query: *const c_char,
    limit: i32,
) -> *mut SearchResults {
    let engine = unsafe { &mut *engine };
    let query_str = unsafe { CStr::from_ptr(query).to_string_lossy() };
    
    // Parse query with error correction
    let parsed_query = match parse_query(&query_str) {
        Ok(q) => q,
        Err(_) => fuzzy_parse_query(&query_str), // Fallback to fuzzy
    };
    
    // Execute search
    let top_docs = engine.searcher.search(
        &parsed_query,
        &TopDocs::with_limit(limit as usize)
    ).unwrap();
    
    // Convert to FFI-safe format
    Box::into_raw(Box::new(convert_results(top_docs)))
}
```

## Search Features

### Query Types

#### 1. Simple Text Search
```
"tourniquet application"
→ Searches for documents containing both terms
```

#### 2. Phrase Search
```
"direct pressure"
→ Searches for exact phrase
```

#### 3. Fuzzy Search
```
"tornicut" (misspelled)
→ Matches "tourniquet" with edit distance ≤ 2
```

#### 4. Category Filtering
```
category:medical AND bleeding
→ Searches only medical content for bleeding
```

#### 5. Priority Boosting
```
emergency:true^2 AND water
→ Boosts emergency content in results
```

### Fuzzy Search Implementation
```rust
// Levenshtein automaton for fuzzy matching
pub fn create_fuzzy_query(term: &str, distance: u8) -> Box<dyn Query> {
    let term = Term::from_field_text(content_field, term);
    let automaton = LevenshteinAutomatonBuilder::new(distance, true)
        .build_dfa(term.text());
    
    Box::new(FuzzyTermQuery::new(term, distance, true))
}
```

### Search Suggestions
```rust
// Auto-complete using FST (Finite State Transducer)
pub struct SuggestionEngine {
    fst: Fst<MemoryMap>,
}

impl SuggestionEngine {
    pub fn suggest(&self, prefix: &str, limit: usize) -> Vec<String> {
        let matcher = Str::new(prefix).starts_with();
        self.fst.search(matcher)
            .take(limit)
            .map(|result| String::from_utf8(result.unwrap()).unwrap())
            .collect()
    }
}
```

## Performance Optimizations

### Index Loading Strategy
```rust
// Tiered index loading
pub struct IndexManager {
    core_index: Index,                    // Always in memory
    module_indexes: LruCache<String, Index>, // LRU cache
    external_indexes: HashMap<String, PathBuf>, // Lazy loaded
}

impl IndexManager {
    pub async fn load_core_index(&mut self) -> Result<()> {
        // Load core index into memory
        self.core_index = Index::open_in_dir(&self.core_path)?;
        
        // Pre-warm searcher
        let reader = self.core_index.reader()?;
        let _ = reader.searcher(); // Force load
        
        Ok(())
    }
    
    pub async fn search_all(&self, query: &str) -> Vec<SearchResult> {
        // Search core first (fastest)
        let mut results = self.search_core(query).await;
        
        // Search cached modules
        for (_, index) in self.module_indexes.iter() {
            results.extend(self.search_index(index, query).await);
        }
        
        // Only search external if needed
        if results.len() < MIN_RESULTS {
            results.extend(self.search_external(query).await);
        }
        
        results
    }
}
```

### Memory Management
```rust
// Aggressive memory management for mobile
pub struct MemoryAwareSearcher {
    memory_limit: usize,
    current_usage: AtomicUsize,
}

impl MemoryAwareSearcher {
    pub fn search(&self, query: &Query) -> Result<Vec<Document>> {
        // Check memory before search
        if self.current_usage.load(Ordering::Relaxed) > self.memory_limit * 0.8 {
            self.evict_caches();
        }
        
        // Use streaming iterator to avoid loading all results
        let collector = TopCollector::with_limit(20)
            .and_fast_field_collector(priority_field);
            
        let results = self.searcher.search(query, &collector)?;
        
        // Stream results instead of collecting all
        Ok(self.stream_documents(results))
    }
}
```

### Battery Optimization
```rust
// Power-aware search scheduling
pub struct PowerAwareSearch {
    low_power_mode: AtomicBool,
}

impl PowerAwareSearch {
    pub async fn search(&self, query: String) -> Vec<SearchResult> {
        if self.low_power_mode.load(Ordering::Relaxed) {
            // Simplified search in low power mode
            self.search_core_only(query).await
        } else {
            // Full search across all indexes
            self.search_all_indexes(query).await
        }
    }
    
    fn search_core_only(&self, query: String) -> Vec<SearchResult> {
        // Disable fuzzy matching
        // Reduce result count
        // Skip expensive ranking
    }
}
```

## Search Analytics

### Performance Metrics
```rust
#[derive(Debug)]
pub struct SearchMetrics {
    pub query_time_ms: u64,
    pub index_segments_accessed: usize,
    pub documents_scanned: usize,
    pub memory_used_bytes: usize,
}

impl SearchMetrics {
    pub fn log(&self) {
        if self.query_time_ms > 100 {
            warn!("Slow query detected: {:?}", self);
        }
        
        // Track for optimization
        METRICS.search_latency.observe(self.query_time_ms as f64);
        METRICS.docs_scanned.increment(self.documents_scanned as u64);
    }
}
```

### Query Patterns
```sql
-- Track common queries for optimization
CREATE TABLE search_analytics (
    query TEXT,
    normalized_query TEXT,
    result_count INTEGER,
    click_position INTEGER,
    query_time_ms INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Analyze for index optimization
SELECT normalized_query, COUNT(*) as frequency
FROM search_analytics
WHERE timestamp > datetime('now', '-7 days')
GROUP BY normalized_query
ORDER BY frequency DESC
LIMIT 100;
```

## Testing Strategy

### Unit Tests
```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_fuzzy_search() {
        let index = create_test_index();
        let results = search(&index, "tornicut"); // Misspelled
        
        assert!(results.iter().any(|r| r.title.contains("tourniquet")));
    }
    
    #[test]
    fn test_medical_synonyms() {
        let index = create_test_index();
        let results = search(&index, "heart attack");
        
        assert!(results.iter().any(|r| 
            r.content.contains("cardiac arrest") || 
            r.content.contains("myocardial infarction")
        ));
    }
}
```

### Performance Benchmarks
```rust
#[bench]
fn bench_search_common_query(b: &mut Bencher) {
    let index = setup_real_index();
    b.iter(|| {
        search(&index, "bleeding control")
    });
}

#[bench]
fn bench_fuzzy_search(b: &mut Bencher) {
    let index = setup_real_index();
    b.iter(|| {
        fuzzy_search(&index, "hemorrage", 2)
    });
}
```

## Future Enhancements

### Vector Search (Semantic)
```rust
// Future: Embedding-based semantic search
pub struct SemanticSearch {
    embeddings: Vec<(DocId, Vec<f32>)>,
}

impl SemanticSearch {
    pub fn search_semantic(&self, query_embedding: Vec<f32>) -> Vec<DocId> {
        // Cosine similarity search
        self.embeddings.iter()
            .map(|(id, embedding)| {
                (id, cosine_similarity(&query_embedding, embedding))
            })
            .sorted_by(|a, b| b.1.partial_cmp(&a.1).unwrap())
            .take(20)
            .map(|(id, _)| *id)
            .collect()
    }
}
```

### Multilingual Support
```rust
// Language-aware tokenization
let tokenizer = match language {
    Language::English => english_tokenizer(),
    Language::Spanish => spanish_tokenizer(),
    Language::French => french_tokenizer(),
    _ => simple_tokenizer(),
};
```
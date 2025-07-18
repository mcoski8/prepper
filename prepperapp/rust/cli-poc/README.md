# Tantivy Search PoC for PrepperApp

This is a command-line proof of concept for integrating Tantivy search engine into PrepperApp.

## Features Demonstrated

1. **Schema Design**
   - FAST fields for quick retrieval (id, title, category)
   - Full-text search fields (title, summary, content)
   - Priority field for relevance boosting
   - Optimized for mobile with minimal stored data

2. **Indexing**
   - Batch indexing of survival articles
   - Configurable buffer size (50MB)
   - Mobile-optimized merge policy

3. **Search Capabilities**
   - Multi-field search across title, summary, and content
   - Sub-100ms query performance
   - Relevance scoring with BM25

4. **Multi-Index Support**
   - Search across core and module indexes
   - Foundation for tiered content system

## Usage

### 1. Create an Index
```bash
cargo run -- create-index --path ./test-index
```

### 2. Index Sample Content
```bash
cargo run -- index-content --index-path ./test-index
```

### 3. Search the Index
```bash
cargo run -- search --index-path ./test-index --query "bleeding"
cargo run -- search --index-path ./test-index --query "water purification"
cargo run -- search --index-path ./test-index --query "hypothermia"
```

### 4. Test Multi-Index Search
First create and populate a second index:
```bash
cargo run -- create-index --path ./module-index
cargo run -- index-content --index-path ./module-index
```

Then search both:
```bash
cargo run -- multi-search --core-index ./test-index --module-index ./module-index --query "emergency"
```

## Performance Targets

- Index creation: <1 second
- Document indexing: <10ms per document
- Search latency: <100ms
- Memory usage: <50MB for core index

## Next Steps

1. Implement fuzzy search with Levenshtein distance
2. Add medical synonym mapping
3. Create FFI bindings for mobile
4. Test with larger datasets (10,000+ articles)
5. Implement incremental indexing
6. Add index compression

## Mobile Optimization Notes

- Use memory-mapped files (mmap) for large indexes
- Configure conservative merge policy during battery operation
- Implement time-bounded batch indexing for iOS
- Store only essential fields to minimize index size
# Federated Search Design

## Overview
PrepperApp needs to search across multiple content tiers:
- **Tier 1**: Internal 249MB P0 content (always available)
- **Tier 2**: External storage with P1/P2 content (optional, 220GB+)

## Search Flow

### 1. User Query Processing
```
User Input → Debounce (300ms) → Cancel Previous → Parse Query
```

### 2. Parallel Search Execution
```swift
// iOS Example
async {
    let tantivyResults = await searchTantivy(query, tier: .internal)
    let sqliteResults = await searchSQLite(query, tier: .internal)
    let externalResults = await searchExternal(query) // If available
    
    return mergeResults(tantivyResults, sqliteResults, externalResults)
}
```

### 3. Result Merging Strategy

#### Priority Order:
1. **Exact Title Matches** (SQLite) - Boost to top
2. **P0 Content** (Internal) - Critical survival info
3. **Relevance Score** (Tantivy) - Full-text ranking
4. **P1/P2 Content** (External) - Supplementary info

#### Deduplication:
- Use article ID as unique key
- Keep highest scoring version if duplicates exist

#### Unified Result Object:
```kotlin
data class SearchResult(
    val articleId: String,
    val title: String,
    val snippet: String,
    val score: Float,
    val priority: Priority, // P0, P1, P2
    val source: Source,     // INTERNAL, EXTERNAL
    val isExactMatch: Boolean
)
```

### 4. Query Routing Logic

#### Tantivy (Full-Text):
- All user queries
- Boolean search syntax
- Handles typos and stemming
- Returns relevance-scored results

#### SQLite (Structured):
- Title prefix matching: `SELECT * FROM articles WHERE title LIKE 'query%'`
- Direct ID lookups for article retrieval
- Metadata queries (priority, category)

#### External Storage:
- Only if mounted and index available
- Same Tantivy query as internal
- Results marked with EXTERNAL source

### 5. Performance Optimizations

#### Caching:
- Cache last 10 search results
- Invalidate on storage change
- Memory limit: 5MB for cache

#### Lazy Loading:
- Load article content only when selected
- Keep search results lightweight

#### Progressive Loading:
- Show internal results immediately
- Add external results as they arrive
- Update UI without disruption

### 6. Error Handling

#### External Storage Unavailable:
- Silently skip external search
- Show banner: "External content not available"
- Continue with internal results only

#### Search Timeout:
- Internal: 500ms timeout
- External: 2s timeout
- Show partial results if timeout

### 7. Implementation Example

```swift
// iOS SearchManager
class SearchManager {
    func federatedSearch(query: String) async -> [SearchResult] {
        // Cancel previous search
        currentTask?.cancel()
        
        // Start new search
        currentTask = Task {
            async let tantivyTask = searchTantivy(query)
            async let sqliteTask = searchSQLite(query)
            async let externalTask = searchExternalIfAvailable(query)
            
            let results = await [
                tantivyTask,
                sqliteTask,
                externalTask
            ]
            
            return mergeAndRank(results)
        }
        
        return await currentTask!.value
    }
    
    private func mergeAndRank(_ resultSets: [[SearchResult]]) -> [SearchResult] {
        var merged: [String: SearchResult] = [:]
        
        // Deduplicate and keep best score
        for results in resultSets {
            for result in results {
                if let existing = merged[result.articleId] {
                    if result.score > existing.score {
                        merged[result.articleId] = result
                    }
                } else {
                    merged[result.articleId] = result
                }
            }
        }
        
        // Sort by priority and score
        return merged.values.sorted { a, b in
            // Exact matches first
            if a.isExactMatch != b.isExactMatch {
                return a.isExactMatch
            }
            // Then by priority (P0 > P1 > P2)
            if a.priority != b.priority {
                return a.priority.rawValue < b.priority.rawValue
            }
            // Finally by score
            return a.score > b.score
        }
    }
}
```

## Testing Strategy

### Unit Tests:
- Test merge logic with various result combinations
- Verify deduplication works correctly
- Test timeout handling

### Integration Tests:
- Test with real Tantivy and SQLite data
- Verify external storage detection
- Test search cancellation

### Performance Tests:
- Measure merge time for 1000+ results
- Verify 500ms response time for internal search
- Test memory usage stays under 150MB
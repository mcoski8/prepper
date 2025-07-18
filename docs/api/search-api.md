# Search API Documentation

## Overview
The Search API provides high-performance full-text search capabilities across all content using Tantivy. It supports fuzzy matching, category filtering, and multi-module search with sub-100ms response times.

## Architecture

### Search Service Structure
```
┌─────────────────────────────────────────────────────────┐
│                    Search API                            │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │Query Parser │  │Index Manager │  │Result Ranker  │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
├─────────────────────────────────────────────────────────┤
│                  Tantivy Engine                          │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │  Tokenizer  │  │  Searcher    │  │   Scorer      │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## API Reference

### SearchService Interface

#### Initialize Search Service
```swift
// iOS Swift
protocol SearchServiceProtocol {
    func search(_ query: String, options: SearchOptions?) async throws -> SearchResults
    func suggest(_ prefix: String, limit: Int) async throws -> [String]
    func getSearchHistory() -> [SearchHistoryItem]
    func clearSearchHistory()
}

class SearchService: SearchServiceProtocol {
    private let tantivy: TantivyBridge
    private let indexManager: IndexManager
    
    init() throws {
        self.tantivy = try TantivyBridge()
        self.indexManager = IndexManager()
        
        // Load core index
        try indexManager.loadCoreIndex()
    }
}
```

```kotlin
// Android Kotlin
interface SearchService {
    suspend fun search(query: String, options: SearchOptions? = null): SearchResults
    suspend fun suggest(prefix: String, limit: Int = 10): List<String>
    fun getSearchHistory(): List<SearchHistoryItem>
    fun clearSearchHistory()
}

class SearchServiceImpl : SearchService {
    private val tantivy = TantivyEngine()
    private val indexManager = IndexManager()
    
    init {
        indexManager.loadCoreIndex()
    }
}
```

### Search Operations

#### Basic Search
```swift
struct SearchOptions {
    let moduleIds: [String]? = nil      // nil = search all
    let categories: [String]? = nil     // Filter by category
    let fuzzyEnabled: Bool = true       // Allow fuzzy matching
    let fuzzyDistance: Int = 2          // Max edit distance
    let limit: Int = 20                 // Results per page
    let offset: Int = 0                 // For pagination
    let sortBy: SortOption = .relevance
    let includeContent: Bool = false    // Include full content in results
}

enum SortOption {
    case relevance      // Default BM25 scoring
    case priority       // Emergency priority first
    case recency       // Recently updated first
    case alphabetical  // A-Z by title
}

func search(_ query: String, options: SearchOptions? = nil) async throws -> SearchResults {
    let opts = options ?? SearchOptions()
    
    // Parse query
    let parsedQuery = try parseQuery(query, fuzzy: opts.fuzzyEnabled)
    
    // Execute search
    let results = try await tantivy.search(
        query: parsedQuery,
        indexes: getIndexes(for: opts.moduleIds),
        limit: opts.limit,
        offset: opts.offset
    )
    
    // Apply filters
    let filtered = applyFilters(results, options: opts)
    
    // Sort results
    let sorted = sortResults(filtered, by: opts.sortBy)
    
    // Track search history
    trackSearch(query, resultCount: sorted.count)
    
    return SearchResults(
        query: query,
        results: sorted,
        totalCount: filtered.count,
        searchTime: results.searchTime,
        suggestions: results.suggestions
    )
}
```

#### Advanced Query Syntax
```swift
// Query parser implementation
func parseQuery(_ input: String, fuzzy: Bool = true) throws -> Query {
    let parser = QueryParser()
    
    // Handle special syntax
    // "exact phrase" - Phrase search
    // +required -excluded - Boolean operators
    // field:value - Field-specific search
    // wildcard* - Prefix matching
    
    let tokens = tokenize(input)
    var queries: [Query] = []
    
    for token in tokens {
        switch token.type {
        case .phrase:
            queries.append(PhraseQuery(token.value))
            
        case .required:
            queries.append(BoolQuery.must(TermQuery(token.value)))
            
        case .excluded:
            queries.append(BoolQuery.mustNot(TermQuery(token.value)))
            
        case .field:
            queries.append(FieldQuery(field: token.field, value: token.value))
            
        case .wildcard:
            queries.append(PrefixQuery(token.value.dropLast()))
            
        case .regular:
            if fuzzy {
                queries.append(FuzzyQuery(token.value, maxEdits: 2))
            } else {
                queries.append(TermQuery(token.value))
            }
        }
    }
    
    return BoolQuery.should(queries) // OR by default
}
```

### Search Results

#### Result Models
```swift
struct SearchResults {
    let query: String
    let results: [SearchResult]
    let totalCount: Int
    let searchTime: TimeInterval
    let suggestions: [String]
    let facets: [SearchFacet]?
}

struct SearchResult {
    let id: String
    let title: String
    let snippet: String          // Highlighted excerpt
    let url: String
    let moduleId: String
    let category: String
    let priority: Priority
    let score: Float             // Relevance score
    let highlights: [TextRange]  // For snippet highlighting
    let content: String?         // Full content if requested
}

struct SearchFacet {
    let field: String
    let values: [FacetValue]
}

struct FacetValue {
    let value: String
    let count: Int
}

struct TextRange {
    let start: Int
    let end: Int
}
```

### Auto-Suggestions

#### Implement Suggestions
```swift
class SuggestionEngine {
    private let fst: FiniteStateTransducer
    private let popularQueries: [String: Int] // Query -> frequency
    
    func suggest(_ prefix: String, limit: Int = 10) async throws -> [String] {
        // Get FST matches
        let fstMatches = fst.prefixSearch(prefix, limit: limit * 2)
        
        // Get popular queries matching prefix
        let popularMatches = popularQueries.keys
            .filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
            .sorted { popularQueries[$0]! > popularQueries[$1]! }
            .prefix(limit)
        
        // Combine and deduplicate
        var suggestions = Set(fstMatches)
        suggestions.formUnion(popularMatches)
        
        // Sort by relevance
        return Array(suggestions)
            .sorted { scoreForSuggestion($0, prefix: prefix) > scoreForSuggestion($1, prefix: prefix) }
            .prefix(limit)
            .map { $0 }
    }
    
    private func scoreForSuggestion(_ suggestion: String, prefix: String) -> Float {
        var score: Float = 0
        
        // Exact prefix match scores highest
        if suggestion.lowercased().hasPrefix(prefix.lowercased()) {
            score += 10
        }
        
        // Popular queries score higher
        if let frequency = popularQueries[suggestion] {
            score += Float(frequency) / 100
        }
        
        // Shorter suggestions score higher
        score += 5 / Float(suggestion.count)
        
        return score
    }
}
```

### Search Filters

#### Category Filtering
```swift
extension SearchService {
    func searchByCategory(_ query: String, categories: [String]) async throws -> SearchResults {
        let categoryQuery = BoolQuery.must([
            parseQuery(query),
            BoolQuery.should(categories.map { TermQuery(field: "category", value: $0) })
        ])
        
        return try await executeSearch(categoryQuery)
    }
}
```

#### Priority Filtering
```swift
extension SearchService {
    func searchCriticalOnly(_ query: String) async throws -> SearchResults {
        let priorityQuery = BoolQuery.must([
            parseQuery(query),
            TermQuery(field: "priority", value: "critical")
        ])
        
        return try await executeSearch(priorityQuery)
    }
}
```

### Search History

#### History Management
```swift
struct SearchHistoryItem: Codable {
    let query: String
    let timestamp: Date
    let resultCount: Int
    let clickedResults: [String] // Article IDs
}

class SearchHistoryManager {
    private let maxHistoryItems = 100
    private var history: [SearchHistoryItem] = []
    
    func addSearch(_ query: String, resultCount: Int) {
        let item = SearchHistoryItem(
            query: query,
            timestamp: Date(),
            resultCount: resultCount,
            clickedResults: []
        )
        
        history.append(item)
        
        // Trim old items
        if history.count > maxHistoryItems {
            history.removeFirst(history.count - maxHistoryItems)
        }
        
        // Persist
        saveHistory()
    }
    
    func recordClick(for query: String, articleId: String) {
        guard let index = history.lastIndex(where: { $0.query == query }) else { return }
        history[index].clickedResults.append(articleId)
        saveHistory()
    }
    
    func getFrequentSearches(limit: Int = 10) -> [String] {
        let frequencies = history.reduce(into: [String: Int]()) { counts, item in
            counts[item.query, default: 0] += 1
        }
        
        return frequencies
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
}
```

### Performance Optimization

#### Index Management
```swift
class IndexManager {
    private var coreIndex: Index?
    private var moduleIndexes: LRUCache<String, Index> = LRUCache(capacity: 5)
    private let queue = DispatchQueue(label: "index", attributes: .concurrent)
    
    func loadCoreIndex() throws {
        coreIndex = try Index.open(at: coreIndexPath)
        
        // Pre-warm the index
        let reader = try coreIndex!.reader()
        _ = reader.searcher() // Force load
    }
    
    func getIndex(for moduleId: String) async throws -> Index {
        // Check cache
        if let cached = moduleIndexes.get(moduleId) {
            return cached
        }
        
        // Load index
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    let index = try Index.open(at: self.indexPath(for: moduleId))
                    self.moduleIndexes.set(moduleId, index)
                    continuation.resume(returning: index)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

#### Query Optimization
```swift
extension SearchService {
    private func optimizeQuery(_ query: Query) -> Query {
        // Convert to DNF (Disjunctive Normal Form) for better performance
        let dnf = query.toDNF()
        
        // Apply query rewriting rules
        let rewritten = applyRewriteRules(dnf)
        
        // Add boosting for critical content
        let boosted = BoostQuery(
            query: rewritten,
            boosts: [
                ("priority:critical", 2.0),
                ("category:medical", 1.5),
                ("category:water", 1.5)
            ]
        )
        
        return boosted
    }
}
```

### Error Handling

#### Search Errors
```swift
enum SearchError: LocalizedError {
    case invalidQuery(String)
    case indexNotLoaded(String)
    case searchTimeout
    case tooManyResults(Int)
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery(let query):
            return "Invalid search query: \(query)"
        case .indexNotLoaded(let moduleId):
            return "Search index not loaded for module: \(moduleId)"
        case .searchTimeout:
            return "Search took too long and was cancelled"
        case .tooManyResults(let count):
            return "Too many results (\(count)). Please refine your search."
        case .noResults:
            return "No results found. Try different keywords."
        }
    }
}
```

### Testing

#### Search Tests
```swift
class SearchAPITests: XCTestCase {
    func testBasicSearch() async throws {
        let service = try SearchService()
        let results = try await service.search("bleeding")
        
        XCTAssertGreaterThan(results.results.count, 0)
        XCTAssertLessThan(results.searchTime, 0.1) // 100ms
    }
    
    func testFuzzySearch() async throws {
        let service = try SearchService()
        let results = try await service.search("hemorrage") // Misspelled
        
        let titles = results.results.map { $0.title.lowercased() }
        XCTAssertTrue(titles.contains { $0.contains("hemorrhage") })
    }
    
    func testCategoryFilter() async throws {
        let service = try SearchService()
        let options = SearchOptions(categories: ["medical"])
        let results = try await service.search("treatment", options: options)
        
        XCTAssertTrue(results.results.allSatisfy { $0.category == "medical" })
    }
    
    func testSuggestions() async throws {
        let service = try SearchService()
        let suggestions = try await service.suggest("tour", limit: 5)
        
        XCTAssertTrue(suggestions.contains("tourniquet"))
    }
}
```

## Performance Benchmarks

### Target Metrics
| Operation | Target | Acceptable |
|-----------|--------|------------|
| Simple search | <50ms | <100ms |
| Fuzzy search | <100ms | <200ms |
| Multi-module search | <150ms | <300ms |
| Suggestions | <20ms | <50ms |
| Index load | <500ms | <1000ms |

### Optimization Guidelines
1. Keep core index in memory always
2. Use memory-mapped files for large indexes
3. Implement query result caching
4. Pre-compute common query results
5. Use SIMD instructions where available
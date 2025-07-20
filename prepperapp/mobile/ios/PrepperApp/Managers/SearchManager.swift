import Foundation

class SearchManager {
    static let shared = SearchManager()
    
    private let databaseManager = DatabaseManager.shared
    private let tantivyBridge = TantivyBridge()
    private var isInitialized = false
    private let initQueue = DispatchQueue(label: "com.prepperapp.search.init")
    private var currentSearchTask: Task<[SearchResult], Error>?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func federatedSearch(query: String) async throws -> [SearchResult] {
        // Cancel previous search
        currentSearchTask?.cancel()
        
        // Ensure initialized
        try await ensureInitialized()
        
        // Create new search task
        let task = Task { () -> [SearchResult] in
            // Run searches in parallel
            async let tantivyResults = searchTantivy(query: query)
            async let sqliteResults = searchSQLite(query: query)
            
            // Check for cancellation
            try Task.checkCancellation()
            
            // Await both results
            let (tantivyRes, sqliteRes) = await (tantivyResults, sqliteResults)
            
            // Merge and rank results
            return mergeAndRank(tantivyRes, sqliteRes)
        }
        
        currentSearchTask = task
        return try await task.value
    }
    
    // MARK: - Private Methods
    
    private func ensureInitialized() async throws {
        guard !isInitialized else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            initQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PrepperAppError.searchFailed("Manager deallocated"))
                    return
                }
                
                guard !self.isInitialized else {
                    continuation.resume()
                    return
                }
                
                Task {
                    do {
                        // Initialize Tantivy if content is available
                        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let indexPath = documentsURL.appendingPathComponent("tantivy_index").path
                        
                        if FileManager.default.fileExists(atPath: indexPath) {
                            try await self.tantivyBridge.initialize(indexPath: indexPath)
                        }
                        
                        self.isInitialized = true
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func searchTantivy(query: String) async -> [SearchResult] {
        do {
            let tantivyResults = try await tantivyBridge.search(query: query, limit: 50)
            
            return tantivyResults.map { result in
                SearchResult(
                    articleId: result.docId,
                    title: result.title,
                    snippet: result.snippet ?? "",
                    score: result.score,
                    priority: .p0, // Will be updated from DB
                    source: .internal,
                    isExactMatch: false
                )
            }
        } catch {
            print("Tantivy search error: \(error)")
            return []
        }
    }
    
    private func searchSQLite(query: String) async -> [SearchResult] {
        do {
            // Exact title matches
            let exactMatches = try await databaseManager.searchExactTitle(query: query)
            
            // Prefix matches
            let prefixMatches = try await databaseManager.searchTitlePrefix(query: query)
            
            // Combine and mark exact matches
            var results: [SearchResult] = []
            
            for article in exactMatches {
                results.append(SearchResult(
                    articleId: article.id,
                    title: article.title,
                    snippet: String(article.content.prefix(200)) + "...",
                    score: 100.0, // High score for exact matches
                    priority: article.priority,
                    source: .internal,
                    isExactMatch: true
                ))
            }
            
            for article in prefixMatches {
                // Skip if already in exact matches
                if results.contains(where: { $0.articleId == article.id }) {
                    continue
                }
                
                results.append(SearchResult(
                    articleId: article.id,
                    title: article.title,
                    snippet: String(article.content.prefix(200)) + "...",
                    score: 50.0, // Medium score for prefix matches
                    priority: article.priority,
                    source: .internal,
                    isExactMatch: false
                ))
            }
            
            return results
        } catch {
            print("SQLite search error: \(error)")
            return []
        }
    }
    
    private func mergeAndRank(_ tantivyResults: [SearchResult], _ sqliteResults: [SearchResult]) -> [SearchResult] {
        var merged: [String: SearchResult] = [:]
        
        // Add SQLite results first (they have exact match info)
        for result in sqliteResults {
            merged[result.articleId] = result
        }
        
        // Add Tantivy results, updating scores if higher
        for result in tantivyResults {
            if let existing = merged[result.articleId] {
                // Keep the one with higher score, but preserve exact match flag
                if result.score > existing.score && !existing.isExactMatch {
                    var updated = result
                    updated.priority = existing.priority // Preserve priority from DB
                    merged[result.articleId] = updated
                }
            } else {
                merged[result.articleId] = result
            }
        }
        
        // Sort by priority and score
        let sorted = merged.values.sorted { a, b in
            // Exact matches first
            if a.isExactMatch != b.isExactMatch {
                return a.isExactMatch
            }
            // Then by priority (P0 > P1 > P2)
            if a.priority != b.priority {
                return a.priority < b.priority
            }
            // Finally by score
            return a.score > b.score
        }
        
        // Return top 100 results
        return Array(sorted.prefix(100))
    }
}
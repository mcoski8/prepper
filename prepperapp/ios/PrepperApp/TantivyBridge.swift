import Foundation

// MARK: - TantivyBridge
/// Swift wrapper for Tantivy search engine
final class TantivyBridge {
    
    // MARK: - Error Types
    enum TantivyError: LocalizedError {
        case indexCreationFailed
        case indexOpenFailed
        case searchFailed
        case indexingFailed
        case invalidPointer
        
        var errorDescription: String? {
            switch self {
            case .indexCreationFailed:
                return "Failed to create search index"
            case .indexOpenFailed:
                return "Failed to open search index"
            case .searchFailed:
                return "Search operation failed"
            case .indexingFailed:
                return "Failed to index document"
            case .invalidPointer:
                return "Invalid index reference"
            }
        }
    }
    
    // MARK: - Search Result Model
    struct SearchResult {
        let id: String
        let title: String
        let category: String
        let summary: String
        let priority: Int
        let score: Float
    }
    
    // MARK: - Index Statistics
    struct IndexStats {
        let documentCount: Int64
        let indexSizeBytes: Int64
        
        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            return formatter.string(fromByteCount: indexSizeBytes)
        }
    }
    
    // MARK: - Properties
    private let indexPointer: OpaquePointer
    private let queue = DispatchQueue(label: "com.prepperapp.tantivy", attributes: .concurrent)
    
    // MARK: - Initialization
    private init(pointer: OpaquePointer) {
        self.indexPointer = pointer
    }
    
    deinit {
        tantivy_free_index(indexPointer)
    }
    
    // MARK: - Public API
    
    /// Initialize Tantivy logging
    static func initializeLogging() {
        tantivy_init_logging()
    }
    
    /// Create a new index at the specified path
    static func createIndex(at path: String) throws -> TantivyBridge {
        guard let pointer = tantivy_create_index(path) else {
            throw TantivyError.indexCreationFailed
        }
        return TantivyBridge(pointer: pointer)
    }
    
    /// Open an existing index at the specified path
    static func openIndex(at path: String) throws -> TantivyBridge {
        guard let pointer = tantivy_open_index(path) else {
            throw TantivyError.indexOpenFailed
        }
        return TantivyBridge(pointer: pointer)
    }
    
    /// Add a document to the index
    func addDocument(
        id: String,
        title: String,
        category: String,
        priority: Int,
        summary: String,
        content: String
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TantivyError.invalidPointer)
                    return
                }
                
                let result = tantivy_add_document(
                    self.indexPointer,
                    id,
                    title,
                    category,
                    UInt64(priority),
                    summary,
                    content
                )
                
                if result == TANTIVY_SUCCESS {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TantivyError.indexingFailed)
                }
            }
        }
    }
    
    /// Commit changes to the index
    func commit() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TantivyError.invalidPointer)
                    return
                }
                
                let result = tantivy_commit(self.indexPointer)
                
                if result == TANTIVY_SUCCESS {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TantivyError.indexingFailed)
                }
            }
        }
    }
    
    /// Search the index
    func search(query: String, limit: Int = 10) async throws -> [SearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TantivyError.invalidPointer)
                    return
                }
                
                guard let results = tantivy_search(self.indexPointer, query, limit) else {
                    continuation.resume(throwing: TantivyError.searchFailed)
                    return
                }
                
                // Convert C results to Swift
                var swiftResults: [SearchResult] = []
                
                for i in 0..<results.pointee.count {
                    let result = results.pointee.results[i]
                    
                    let searchResult = SearchResult(
                        id: String(cString: result.id),
                        title: String(cString: result.title),
                        category: String(cString: result.category),
                        summary: String(cString: result.summary),
                        priority: Int(result.priority),
                        score: result.score
                    )
                    
                    swiftResults.append(searchResult)
                }
                
                // Free the C results
                tantivy_free_search_results(results)
                
                continuation.resume(returning: swiftResults)
            }
        }
    }
    
    /// Get index statistics
    func getStats() async -> IndexStats {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: IndexStats(documentCount: 0, indexSizeBytes: 0))
                    return
                }
                
                let stats = tantivy_get_index_stats(self.indexPointer)
                
                continuation.resume(returning: IndexStats(
                    documentCount: Int64(stats.num_docs),
                    indexSizeBytes: Int64(stats.index_size_bytes)
                ))
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Add multiple documents in a batch
    func addDocuments(_ documents: [(id: String, title: String, category: String, priority: Int, summary: String, content: String)]) async throws {
        for doc in documents {
            try await addDocument(
                id: doc.id,
                title: doc.title,
                category: doc.category,
                priority: doc.priority,
                summary: doc.summary,
                content: doc.content
            )
        }
        try await commit()
    }
}

// MARK: - Index Manager
/// Manages multiple Tantivy indexes (core + modules)
final class TantivyIndexManager {
    
    // MARK: - Properties
    private var coreIndex: TantivyBridge?
    private var moduleIndexes: [String: TantivyBridge] = [:]
    private let indexesDirectory: URL
    private let queue = DispatchQueue(label: "com.prepperapp.indexmanager", attributes: .concurrent)
    
    // MARK: - Initialization
    init() {
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.indexesDirectory = documentsPath.appendingPathComponent("TantivyIndexes")
        
        // Create indexes directory if needed
        try? FileManager.default.createDirectory(at: indexesDirectory, withIntermediateDirectories: true)
        
        // Initialize logging
        TantivyBridge.initializeLogging()
    }
    
    // MARK: - Core Index Management
    
    /// Initialize or open the core index
    func initializeCoreIndex() async throws {
        let coreIndexPath = indexesDirectory.appendingPathComponent("core").path
        
        if FileManager.default.fileExists(atPath: coreIndexPath) {
            coreIndex = try TantivyBridge.openIndex(at: coreIndexPath)
        } else {
            coreIndex = try TantivyBridge.createIndex(at: coreIndexPath)
            // Index default content
            try await indexDefaultContent()
        }
    }
    
    /// Search across all indexes
    func search(query: String, limit: Int = 10) async throws -> [TantivyBridge.SearchResult] {
        var allResults: [TantivyBridge.SearchResult] = []
        
        // Search core index
        if let core = coreIndex {
            let coreResults = try await core.search(query: query, limit: limit)
            allResults.append(contentsOf: coreResults)
        }
        
        // Search module indexes
        for (_, moduleIndex) in moduleIndexes {
            let moduleResults = try await moduleIndex.search(query: query, limit: limit)
            allResults.append(contentsOf: moduleResults)
        }
        
        // Sort by score and limit
        return Array(allResults.sorted { $0.score > $1.score }.prefix(limit))
    }
    
    /// Get combined statistics
    func getStats() async -> TantivyBridge.IndexStats {
        var totalDocs: Int64 = 0
        var totalSize: Int64 = 0
        
        if let core = coreIndex {
            let stats = await core.getStats()
            totalDocs += stats.documentCount
            totalSize += stats.indexSizeBytes
        }
        
        for (_, moduleIndex) in moduleIndexes {
            let stats = await moduleIndex.getStats()
            totalDocs += stats.documentCount
            totalSize += stats.indexSizeBytes
        }
        
        return TantivyBridge.IndexStats(documentCount: totalDocs, indexSizeBytes: totalSize)
    }
    
    // MARK: - Private Methods
    
    private func indexDefaultContent() async throws {
        guard let coreIndex = coreIndex else { return }
        
        // Sample survival content
        let documents = [
            (
                id: "med-001",
                title: "Controlling Severe Bleeding",
                category: "Medical",
                priority: 5,
                summary: "Life-saving techniques to stop hemorrhaging using tourniquets and pressure",
                content: "Severe bleeding can lead to death in minutes. Apply direct pressure immediately..."
            ),
            (
                id: "water-001",
                title: "Water Purification Methods",
                category: "Water",
                priority: 5,
                summary: "Essential methods to make water safe for drinking in emergencies",
                content: "Boiling water for 1 minute kills most pathogens..."
            ),
            (
                id: "shelter-001",
                title: "Emergency Shelter in Cold Weather",
                category: "Shelter",
                priority: 4,
                summary: "How to build emergency shelter to prevent hypothermia",
                content: "Hypothermia kills in hours. Find windbreak immediately..."
            )
        ]
        
        try await coreIndex.addDocuments(documents)
    }
}

// MARK: - Global Instance
extension TantivyIndexManager {
    static let shared = TantivyIndexManager()
}
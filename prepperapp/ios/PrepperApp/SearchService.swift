import Foundation

// MARK: - Models

/// Matches the Rust `MultiSearchResultItem`
struct SearchResult: Codable, Identifiable {
    let doc_id: String
    let title: String
    let summary: String
    let score: Float
    let module: String
    
    var id: String { doc_id }
}

/// Configuration for search
struct SearchConfig: Codable {
    let limit: Int
    let weights: [String: Float]?
    let module_filter: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case limit
        case weights
        case module_filter
    }
    
    init(limit: Int = 20, weights: [String: Float]? = nil, moduleFilter: [String]? = nil) {
        self.limit = limit
        self.weights = weights
        self.module_filter = moduleFilter
    }
}

/// Module statistics
struct ModuleStats: Codable {
    let name: String
    let num_docs: UInt64
    let estimated_size_bytes: UInt64
}

// MARK: - Errors

enum SearchError: LocalizedError {
    case managerNotInitialized
    case serializationFailed
    case searchFailed
    case moduleLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .managerNotInitialized:
            return "Search manager not initialized"
        case .serializationFailed:
            return "Failed to serialize/deserialize data"
        case .searchFailed:
            return "Search operation failed"
        case .moduleLoadFailed:
            return "Failed to load search module"
        }
    }
}

// MARK: - SearchService

/// Singleton service for managing search functionality
final class SearchService {
    static let shared = SearchService()
    
    private var managerPtr: OpaquePointer?
    private let backgroundQueue = DispatchQueue(label: "com.prepperapp.searchservice", qos: .userInitiated)
    
    /// Track loaded modules
    private var loadedModules = Set<String>()
    
    /// Is the search service ready
    @Published private(set) var isReady = false
    
    private init() {
        // Initialize the Rust multi-search manager
        self.managerPtr = init_multi_manager()
        
        if managerPtr != nil {
            print("SearchService: Multi-search manager initialized successfully")
        } else {
            print("SearchService: Failed to initialize multi-search manager")
        }
    }
    
    deinit {
        if let ptr = managerPtr {
            destroy_multi_manager(ptr)
        }
    }
    
    // MARK: - Index Management
    
    /// Prepares the core index on first launch
    func prepareCoreIndex() async throws {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, 
                                                  in: .userDomainMask).first else {
            throw SearchError.moduleLoadFailed
        }
        
        let indexesDir = appSupportURL.appendingPathComponent("TantivyIndexes")
        let coreIndexPath = indexesDir.appendingPathComponent("core")
        
        // Check if index already exists
        if fileManager.fileExists(atPath: coreIndexPath.path) {
            // Load existing index
            let loaded = await loadIndex(name: "core", path: coreIndexPath.path)
            if loaded {
                isReady = true
                print("SearchService: Core index loaded from disk")
            }
            return
        }
        
        // Copy from bundle if first launch
        guard let bundledIndexPath = Bundle.main.url(forResource: "core_index", 
                                                    withExtension: nil) else {
            print("SearchService: No bundled index found")
            return
        }
        
        do {
            try fileManager.createDirectory(at: indexesDir, 
                                          withIntermediateDirectories: true, 
                                          attributes: nil)
            
            // Extract bundled index (assuming it's compressed)
            if bundledIndexPath.pathExtension == "zip" {
                // TODO: Implement zip extraction
                print("SearchService: Need to extract bundled index")
            } else {
                try fileManager.copyItem(at: bundledIndexPath, to: coreIndexPath)
            }
            
            // Load the index
            let loaded = await loadIndex(name: "core", path: coreIndexPath.path)
            if loaded {
                isReady = true
                print("SearchService: Core index copied and loaded successfully")
            }
        } catch {
            print("SearchService: Error preparing core index: \(error)")
            throw SearchError.moduleLoadFailed
        }
    }
    
    /// Loads an index module into the manager
    func loadIndex(name: String, path: String) async -> Bool {
        await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self, let ptr = self.managerPtr else {
                    continuation.resume(returning: false)
                    return
                }
                
                let result = multi_manager_load_index(ptr, name, path)
                if result == 0 {
                    self.loadedModules.insert(name)
                    print("SearchService: Loaded module '\(name)' from \(path)")
                    continuation.resume(returning: true)
                } else {
                    print("SearchService: Failed to load module '\(name)'")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// Unloads a module
    func unloadModule(name: String) async -> Bool {
        await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self, let ptr = self.managerPtr else {
                    continuation.resume(returning: false)
                    return
                }
                
                let result = multi_manager_unload_index(ptr, name)
                if result == 0 {
                    self.loadedModules.remove(name)
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// Triggers a reload for a specific module
    func reloadModule(name: String) async -> Bool {
        await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let ptr = self?.managerPtr else {
                    continuation.resume(returning: false)
                    return
                }
                
                let result = multi_manager_reload_index(ptr, name)
                continuation.resume(returning: result == 0)
            }
        }
    }
    
    // MARK: - Search
    
    /// The primary search function
    func search(query: String, config: SearchConfig = SearchConfig()) async throws -> [SearchResult] {
        guard let ptr = managerPtr else { 
            throw SearchError.managerNotInitialized 
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundQueue.async {
                // Serialize config to JSON
                guard let configData = try? JSONEncoder().encode(config),
                      let configJson = String(data: configData, encoding: .utf8) else {
                    continuation.resume(throwing: SearchError.serializationFailed)
                    return
                }
                
                // FFI call returns a C-string (JSON)
                guard let resultPtr = multi_manager_search(ptr, query, configJson) else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Take ownership of the C-string
                let jsonString = String(cString: resultPtr)
                
                // Free the string from Rust
                free_rust_string(resultPtr)
                
                // Decode the JSON
                guard let jsonData = jsonString.data(using: .utf8) else {
                    continuation.resume(throwing: SearchError.serializationFailed)
                    return
                }
                
                do {
                    let results = try JSONDecoder().decode([SearchResult].self, from: jsonData)
                    continuation.resume(returning: results)
                } catch {
                    print("SearchService: JSON decode error: \(error)")
                    continuation.resume(throwing: SearchError.serializationFailed)
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Gets statistics for all loaded modules
    func getModuleStats() async throws -> [ModuleStats] {
        guard let ptr = managerPtr else { 
            throw SearchError.managerNotInitialized 
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundQueue.async {
                guard let resultPtr = multi_manager_get_stats(ptr) else {
                    continuation.resume(returning: [])
                    return
                }
                
                let jsonString = String(cString: resultPtr)
                free_rust_string(resultPtr)
                
                guard let jsonData = jsonString.data(using: .utf8) else {
                    continuation.resume(throwing: SearchError.serializationFailed)
                    return
                }
                
                do {
                    let stats = try JSONDecoder().decode([ModuleStats].self, from: jsonData)
                    continuation.resume(returning: stats)
                } catch {
                    continuation.resume(throwing: SearchError.serializationFailed)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Pre-warm the search engine with a dummy query
    func prewarmSearch() async {
        do {
            let config = SearchConfig(limit: 1)
            _ = try await search(query: "the", config: config)
            print("SearchService: Pre-warm completed")
        } catch {
            print("SearchService: Pre-warm failed: \(error)")
        }
    }
}
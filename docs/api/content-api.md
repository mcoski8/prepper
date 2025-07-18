# Content API - ZIM Reader Interface

## Overview
The Content API provides a unified interface for reading ZIM files, managing content modules, and serving articles to the UI layer. Built on top of Kiwix-lib, it handles decompression, caching, and content rendering.

## Architecture

### Core Components
```
┌─────────────────────────────────────────────────────────┐
│                    Content API                           │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │ ZIM Reader  │  │Content Cache │  │Module Manager │ │
│  │(Kiwix-lib)  │  │   (LRU)      │  │  (Lifecycle)  │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
├─────────────────────────────────────────────────────────┤
│                   Storage Layer                          │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │Internal ZIMs│  │External ZIMs │  │  User Data    │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## API Reference

### ContentService

#### Initialize Content Service
```swift
// iOS Swift
class ContentService {
    static let shared = ContentService()
    
    init() throws {
        // Initialize Kiwix-lib
        guard kiwix_init() == 0 else {
            throw ContentError.initializationFailed
        }
        
        // Load core content
        try loadCoreContent()
    }
}
```

```kotlin
// Android Kotlin
class ContentService {
    companion object {
        init {
            System.loadLibrary("kiwix")
        }
        
        @JvmStatic
        val instance: ContentService by lazy {
            ContentService().apply {
                loadCoreContent()
            }
        }
    }
}
```

#### Load ZIM File
```swift
// iOS
func loadZIMFile(at path: String) async throws -> ContentModule {
    return try await withCheckedThrowingContinuation { continuation in
        queue.async {
            let reader = kiwix_reader_new(path)
            guard reader != nil else {
                continuation.resume(throwing: ContentError.invalidZIMFile)
                return
            }
            
            let module = ContentModule(
                id: UUID().uuidString,
                reader: reader,
                path: path,
                metadata: self.extractMetadata(reader)
            )
            
            self.modules[module.id] = module
            continuation.resume(returning: module)
        }
    }
}
```

```kotlin
// Android
suspend fun loadZIMFile(path: String): ContentModule = withContext(Dispatchers.IO) {
    val reader = KiwixReader(path)
    if (!reader.isValid()) {
        throw ContentException("Invalid ZIM file")
    }
    
    val module = ContentModule(
        id = UUID.randomUUID().toString(),
        reader = reader,
        path = path,
        metadata = extractMetadata(reader)
    )
    
    modules[module.id] = module
    module
}
```

### Article Retrieval

#### Get Article by URL
```swift
protocol ContentReaderProtocol {
    func getArticle(url: String, moduleId: String?) async throws -> Article
    func getArticleHTML(url: String, moduleId: String?) async throws -> String
    func getArticleMetadata(url: String, moduleId: String?) async throws -> ArticleMetadata
}

extension ContentService: ContentReaderProtocol {
    func getArticle(url: String, moduleId: String? = nil) async throws -> Article {
        // Check cache first
        if let cached = cache.get(url) {
            return cached
        }
        
        // Find appropriate reader
        let reader = try getReader(for: moduleId)
        
        // Fetch article
        let article = try await fetchArticle(from: reader, url: url)
        
        // Cache and return
        cache.set(url, article)
        return article
    }
}
```

#### Article Data Model
```swift
struct Article: Codable {
    let id: String
    let url: String
    let title: String
    let content: String // HTML content
    let metadata: ArticleMetadata
    let moduleId: String
    let lastAccessed: Date
}

struct ArticleMetadata: Codable {
    let author: String?
    let date: Date?
    let category: String
    let tags: [String]
    let readingTime: Int // minutes
    let priority: Priority
    let relatedArticles: [String]
}

enum Priority: String, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
}
```

### Content Search

#### Search Within Content
```swift
func searchContent(_ query: String, in moduleId: String? = nil) async throws -> [SearchResult] {
    let modules = moduleId != nil ? [modules[moduleId!]].compactMap { $0 } : Array(modules.values)
    
    return try await withThrowingTaskGroup(of: [SearchResult].self) { group in
        for module in modules {
            group.addTask {
                try await self.searchModule(query, in: module)
            }
        }
        
        var results: [SearchResult] = []
        for try await moduleResults in group {
            results.append(contentsOf: moduleResults)
        }
        
        return results.sorted { $0.score > $1.score }
    }
}

private func searchModule(_ query: String, in module: ContentModule) async throws -> [SearchResult] {
    return try await withCheckedThrowingContinuation { continuation in
        queue.async {
            var results: [SearchResult] = []
            let searcher = kiwix_searcher_new(module.reader)
            kiwix_searcher_set_query(searcher, query)
            
            while kiwix_searcher_get_next_result(searcher) {
                let result = SearchResult(
                    title: String(cString: kiwix_searcher_get_title(searcher)),
                    url: String(cString: kiwix_searcher_get_url(searcher)),
                    snippet: String(cString: kiwix_searcher_get_snippet(searcher)),
                    score: kiwix_searcher_get_score(searcher),
                    moduleId: module.id
                )
                results.append(result)
            }
            
            kiwix_searcher_delete(searcher)
            continuation.resume(returning: results)
        }
    }
}
```

### Module Management

#### Module Lifecycle
```swift
protocol ModuleManagerProtocol {
    func installModule(from path: String) async throws -> ContentModule
    func uninstallModule(_ moduleId: String) async throws
    func updateModule(_ moduleId: String, from path: String) async throws
    func getInstalledModules() -> [ContentModule]
    func getModuleInfo(_ moduleId: String) -> ModuleInfo?
}

class ModuleManager: ModuleManagerProtocol {
    func installModule(from path: String) async throws -> ContentModule {
        // Verify integrity
        try await verifyModuleIntegrity(at: path)
        
        // Copy to app storage
        let destinationPath = try await copyToStorage(from: path)
        
        // Load module
        let module = try await contentService.loadZIMFile(at: destinationPath)
        
        // Update registry
        try await updateRegistry(module)
        
        // Notify observers
        NotificationCenter.default.post(
            name: .moduleInstalled,
            object: module
        )
        
        return module
    }
}
```

#### Module Info Structure
```swift
struct ModuleInfo: Codable {
    let id: String
    let name: String
    let description: String
    let version: String
    let size: Int64 // bytes
    let articleCount: Int
    let language: String
    let creator: String
    let publisher: String
    let date: Date
    let categories: [String]
    let icon: String? // Base64 encoded
    let requiredSpace: Int64 // Including indexes
}
```

### Content Rendering

#### HTML Processing
```swift
class ContentRenderer {
    private let cssOverride = """
        body {
            background: #000000 !important;
            color: #FFFFFF !important;
            font-family: -apple-system, system-ui !important;
            font-size: 18px !important;
            line-height: 1.6 !important;
            padding: 16px !important;
            margin: 0 !important;
        }
        
        a {
            color: #4A9EFF !important;
            text-decoration: none !important;
        }
        
        img {
            max-width: 100% !important;
            height: auto !important;
            display: block !important;
            margin: 16px auto !important;
        }
        
        pre, code {
            background: #1A1A1A !important;
            color: #E0E0E0 !important;
            padding: 8px !important;
            border-radius: 4px !important;
            overflow-x: auto !important;
        }
    """
    
    func renderArticle(_ article: Article, emergencyMode: Bool = false) -> String {
        var html = article.content
        
        // Inject CSS
        html = injectCSS(html, css: cssOverride)
        
        // Process images
        if emergencyMode {
            html = stripImages(html)
        } else {
            html = optimizeImages(html)
        }
        
        // Fix internal links
        html = rewriteInternalLinks(html, moduleId: article.moduleId)
        
        // Add navigation
        html = addNavigationBar(html, article: article)
        
        return html
    }
    
    private func rewriteInternalLinks(_ html: String, moduleId: String) -> String {
        // Convert ZIM URLs to app URLs
        let pattern = #"href="([^"]+)""#
        let regex = try! NSRegularExpression(pattern: pattern)
        
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: #"href="prepperapp://content/\#(moduleId)/$1""#
        )
    }
}
```

### Caching Strategy

#### LRU Cache Implementation
```swift
class ContentCache {
    private var cache: [String: CacheEntry] = [:]
    private var accessOrder: [String] = []
    private let maxSize: Int = 50 // Articles
    private let maxMemory: Int = 100_000_000 // 100MB
    private var currentMemory: Int = 0
    
    struct CacheEntry {
        let article: Article
        let size: Int
        var lastAccessed: Date
    }
    
    func get(_ key: String) -> Article? {
        guard let entry = cache[key] else { return nil }
        
        // Update access order
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        
        // Update last accessed
        cache[key]?.lastAccessed = Date()
        
        return entry.article
    }
    
    func set(_ key: String, _ article: Article) {
        let size = article.content.utf8.count
        
        // Evict if necessary
        while (cache.count >= maxSize || currentMemory + size > maxMemory) && !accessOrder.isEmpty {
            evictOldest()
        }
        
        // Add to cache
        cache[key] = CacheEntry(
            article: article,
            size: size,
            lastAccessed: Date()
        )
        accessOrder.append(key)
        currentMemory += size
    }
    
    private func evictOldest() {
        guard let oldest = accessOrder.first else { return }
        accessOrder.removeFirst()
        
        if let entry = cache.removeValue(forKey: oldest) {
            currentMemory -= entry.size
        }
    }
}
```

### Error Handling

#### Content Errors
```swift
enum ContentError: LocalizedError {
    case initializationFailed
    case invalidZIMFile
    case articleNotFound(url: String)
    case moduleNotFound(id: String)
    case insufficientStorage(required: Int64, available: Int64)
    case corruptedContent(details: String)
    case unsupportedVersion(version: String)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize content service"
        case .invalidZIMFile:
            return "Invalid or corrupted ZIM file"
        case .articleNotFound(let url):
            return "Article not found: \(url)"
        case .moduleNotFound(let id):
            return "Module not found: \(id)"
        case .insufficientStorage(let required, let available):
            return "Insufficient storage: need \(required) bytes, have \(available)"
        case .corruptedContent(let details):
            return "Corrupted content: \(details)"
        case .unsupportedVersion(let version):
            return "Unsupported ZIM version: \(version)"
        }
    }
}
```

### Platform-Specific Considerations

#### iOS Implementation Notes
```swift
// Handle app lifecycle
class ContentService {
    func handleMemoryWarning() {
        // Clear cache
        cache.clear()
        
        // Unload non-essential modules
        unloadInactiveModules()
    }
    
    func handleBackgroundMode() {
        // Save state
        saveState()
        
        // Release resources
        releaseNonEssentialResources()
    }
}
```

#### Android Implementation Notes
```kotlin
// Handle process death
class ContentService : LifecycleObserver {
    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    fun onAppBackgrounded() {
        // Save state
        saveState()
        
        // Reduce memory usage
        trimMemory()
    }
    
    @OnLifecycleEvent(Lifecycle.Event.ON_START)
    fun onAppForegrounded() {
        // Restore state
        restoreState()
        
        // Preload essential content
        preloadEssentials()
    }
}
```

## Testing

### Unit Tests
```swift
class ContentAPITests: XCTestCase {
    func testLoadZIMFile() async throws {
        let service = try ContentService()
        let module = try await service.loadZIMFile(at: testZIMPath)
        
        XCTAssertNotNil(module)
        XCTAssertEqual(module.metadata.language, "en")
    }
    
    func testArticleRetrieval() async throws {
        let service = try ContentService()
        let article = try await service.getArticle(url: "/A/First_aid")
        
        XCTAssertEqual(article.title, "First aid")
        XCTAssertTrue(article.content.contains("emergency"))
    }
    
    func testCacheEviction() {
        let cache = ContentCache()
        
        // Fill cache
        for i in 0..<60 {
            cache.set("article\(i)", createTestArticle(id: i))
        }
        
        // Verify eviction
        XCTAssertNil(cache.get("article0"))
        XCTAssertNotNil(cache.get("article59"))
    }
}
```

## Performance Benchmarks

### Target Metrics
- Module load time: <1 second
- Article retrieval: <100ms
- Search within module: <200ms
- Cache hit rate: >80%
- Memory usage: <150MB active
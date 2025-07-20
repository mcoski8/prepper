import Foundation
import SQLite3

class ContentManager {
    static let shared = ContentManager()
    
    private var database: OpaquePointer?
    private var currentManifest: ContentManifest?
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private init() {}
    
    // MARK: - Content Discovery
    
    func discoverContent(completion: @escaping (Result<ContentBundle, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check locations in priority order
            let locations: [(ContentLocation, URL?)] = [
                // 1. Bundled content (for development/testing)
                (.bundled, Bundle.main.url(forResource: "content_manifest", withExtension: "json", subdirectory: "Content")),
                
                // 2. Documents directory (downloaded content)
                (.documents, self.documentsDirectory.appendingPathComponent("content/content_manifest.json")),
                
                // 3. App group (for sharing between app extensions)
                (.appGroup, self.appGroupURL()?.appendingPathComponent("content/content_manifest.json"))
            ]
            
            for (location, url) in locations {
                if let url = url, FileManager.default.fileExists(atPath: url.path) {
                    do {
                        let data = try Data(contentsOf: url)
                        let manifest = try JSONDecoder.prepperDecoder.decode(ContentManifest.self, from: data)
                        
                        let bundle = ContentBundle(
                            manifest: manifest,
                            location: location,
                            isAvailable: true
                        )
                        
                        self.currentManifest = manifest
                        self.loadDatabase(for: manifest, at: location)
                        
                        DispatchQueue.main.async {
                            completion(.success(bundle))
                        }
                        return
                    } catch {
                        print("Failed to load manifest at \(location): \(error)")
                    }
                }
            }
            
            // No content found, create fallback
            let fallbackBundle = self.createFallbackContent()
            DispatchQueue.main.async {
                completion(.success(fallbackBundle))
            }
        }
    }
    
    // MARK: - Database Management
    
    private func loadDatabase(for manifest: ContentManifest, at location: ContentLocation) {
        guard let dbName = manifest.content.databases.first else { return }
        
        let dbURL: URL?
        switch location {
        case .bundled:
            dbURL = Bundle.main.url(forResource: dbName.replacingOccurrences(of: ".db", with: ""), 
                                   withExtension: "db", 
                                   subdirectory: "Content")
        case .documents:
            dbURL = documentsDirectory.appendingPathComponent("content/\(dbName)")
        case .appGroup:
            dbURL = appGroupURL()?.appendingPathComponent("content/\(dbName)")
        case .external(let url):
            dbURL = url.appendingPathComponent(dbName)
        case .onDemandResource:
            dbURL = nil // Handle ODR separately
        }
        
        guard let dbURL = dbURL else { return }
        
        // Open database in read-only mode
        if sqlite3_open_v2(dbURL.path, &database, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("Failed to open database: \(String(cString: sqlite3_errmsg(database)))")
            sqlite3_close(database)
            database = nil
        }
    }
    
    // MARK: - Search
    
    func search(query: String, limit: Int = 50) -> [SearchResult] {
        guard let database = database else { return [] }
        
        var results: [SearchResult] = []
        let searchQuery = "%\(query.lowercased())%"
        
        let sql = """
            SELECT id, title, content, category, priority, time_critical
            FROM articles
            WHERE search_text LIKE ?
            ORDER BY priority ASC, title ASC
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, searchQuery, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let article = Article(
                    id: String(cString: sqlite3_column_text(statement, 0)),
                    title: String(cString: sqlite3_column_text(statement, 1)),
                    content: String(cString: sqlite3_column_text(statement, 2)),
                    category: String(cString: sqlite3_column_text(statement, 3)),
                    priority: Int(sqlite3_column_int(statement, 4)),
                    timeCritical: sqlite3_column_text(statement, 5).map { String(cString: $0) },
                    searchText: nil
                )
                
                // Calculate basic relevance score
                let titleMatches = article.title.lowercased().contains(query.lowercased())
                let score: Float = titleMatches ? 1.0 : 0.5
                
                // Extract snippet
                let snippet = extractSnippet(from: article.content, query: query)
                
                results.append(SearchResult(
                    article: article,
                    score: score,
                    snippet: snippet
                ))
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func getArticle(id: String) -> Article? {
        guard let database = database else { return nil }
        
        let sql = """
            SELECT id, title, content, category, priority, time_critical
            FROM articles
            WHERE id = ?
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        var article: Article?
        
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, id, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                article = Article(
                    id: String(cString: sqlite3_column_text(statement, 0)),
                    title: String(cString: sqlite3_column_text(statement, 1)),
                    content: String(cString: sqlite3_column_text(statement, 2)),
                    category: String(cString: sqlite3_column_text(statement, 3)),
                    priority: Int(sqlite3_column_int(statement, 4)),
                    timeCritical: sqlite3_column_text(statement, 5).map { String(cString: $0) },
                    searchText: nil
                )
            }
        }
        
        sqlite3_finalize(statement)
        return article
    }
    
    func getArticlesByPriority(_ priority: Int) -> [Article] {
        guard let database = database else { return [] }
        
        var articles: [Article] = []
        let sql = """
            SELECT id, title, content, category, priority, time_critical
            FROM articles
            WHERE priority = ?
            ORDER BY title ASC
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(priority))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let article = Article(
                    id: String(cString: sqlite3_column_text(statement, 0)),
                    title: String(cString: sqlite3_column_text(statement, 1)),
                    content: String(cString: sqlite3_column_text(statement, 2)),
                    category: String(cString: sqlite3_column_text(statement, 3)),
                    priority: Int(sqlite3_column_int(statement, 4)),
                    timeCritical: sqlite3_column_text(statement, 5).map { String(cString: $0) },
                    searchText: nil
                )
                articles.append(article)
            }
        }
        
        sqlite3_finalize(statement)
        return articles
    }
    
    // MARK: - Helper Methods
    
    private func appGroupURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.prepperapp")
    }
    
    private func extractSnippet(from content: String, query: String, contextLength: Int = 100) -> String {
        let lowercasedContent = content.lowercased()
        let lowercasedQuery = query.lowercased()
        
        if let range = lowercasedContent.range(of: lowercasedQuery) {
            let startIndex = content.index(range.lowerBound, offsetBy: -contextLength, limitedBy: content.startIndex) ?? content.startIndex
            let endIndex = content.index(range.upperBound, offsetBy: contextLength, limitedBy: content.endIndex) ?? content.endIndex
            
            let snippet = String(content[startIndex..<endIndex])
            return "...\(snippet)..."
        }
        
        // If no match, return first part of content
        let endIndex = content.index(content.startIndex, offsetBy: contextLength * 2, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[content.startIndex..<endIndex]) + "..."
    }
    
    private func createFallbackContent() -> ContentBundle {
        // Create minimal in-memory database
        sqlite3_open(":memory:", &database)
        
        // Create schema
        let createTableSQL = """
            CREATE TABLE articles (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                category TEXT NOT NULL,
                priority INTEGER NOT NULL,
                time_critical TEXT,
                search_text TEXT
            )
        """
        sqlite3_exec(database, createTableSQL, nil, nil, nil)
        
        // Insert basic emergency content
        let emergencyContent = [
            ("1", "Stop Severe Bleeding", "Apply direct pressure with cloth. Press HARD. Do not remove first cloth.", "medical", 0),
            ("2", "CPR - Cardiac Arrest", "30 chest compressions (2 inches deep), 2 breaths. Repeat.", "medical", 0),
            ("3", "Choking", "5 back blows between shoulders, 5 abdominal thrusts. Repeat.", "medical", 0),
            ("4", "Emergency Water", "Boil 1 minute. Or add 8 drops unscented bleach per gallon, wait 30 min.", "water", 0),
            ("5", "Hypothermia", "Get dry. Insulate from ground. Create small shelter. Cover head.", "shelter", 0)
        ]
        
        for (id, title, content, category, priority) in emergencyContent {
            let searchText = "\(title) \(content)".lowercased()
            let insertSQL = """
                INSERT INTO articles (id, title, content, category, priority, search_text)
                VALUES (?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            sqlite3_prepare_v2(database, insertSQL, -1, &statement, nil)
            sqlite3_bind_text(statement, 1, id, -1, nil)
            sqlite3_bind_text(statement, 2, title, -1, nil)
            sqlite3_bind_text(statement, 3, content, -1, nil)
            sqlite3_bind_text(statement, 4, category, -1, nil)
            sqlite3_bind_int(statement, 5, Int32(priority))
            sqlite3_bind_text(statement, 6, searchText, -1, nil)
            sqlite3_step(statement)
            sqlite3_finalize(statement)
        }
        
        // Create fallback manifest
        let manifest = ContentManifest(
            version: "1.0",
            type: .fallback,
            name: "Emergency Basics",
            description: "Minimal emergency content",
            sizeMB: 0.01,
            requiresExternalStorage: false,
            minAppVersion: "1.0.0",
            created: Date(),
            content: ContentInfo(
                databases: ["memory"],
                indexes: [],
                categories: ["medical", "water", "shelter"],
                articleCount: 5,
                priorityLevels: [0],
                priority0Count: 5,
                features: ContentFeatures(
                    offlineMaps: false,
                    plantIdentification: false,
                    pillIdentification: false,
                    medicalProcedures: true,
                    survivalBasics: true,
                    emergencySignaling: false
                )
            ),
            uiConfig: UIConfig(
                searchPlaceholder: "Search emergency procedures...",
                homeScreenModules: [],
                enabledTabs: ["emergency", "search"],
                disabledFeatures: ["maps", "downloads"]
            ),
            searchConfig: SearchConfig(
                defaultLimit: 20,
                boostPriority0: 2.0,
                boostTitleMatch: 1.5
            )
        )
        
        currentManifest = manifest
        
        return ContentBundle(
            manifest: manifest,
            location: .bundled,
            isAvailable: true
        )
    }
    
    // MARK: - Public Properties
    
    var manifest: ContentManifest? {
        currentManifest
    }
    
    var availableCategories: [String] {
        currentManifest?.content.categories ?? []
    }
    
    var hasContent: Bool {
        database != nil
    }
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static let prepperDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.prepperapp.database", attributes: .concurrent)
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private init() {}
    
    // MARK: - Database Connection
    
    func openDatabase() throws {
        let dbPath = documentsURL.appendingPathComponent("prepperapp.db").path
        
        // Use initial DB if full DB not available
        let actualPath: String
        if FileManager.default.fileExists(atPath: dbPath) {
            actualPath = dbPath
        } else {
            let initialPath = documentsURL.appendingPathComponent("initial.db").path
            if FileManager.default.fileExists(atPath: initialPath) {
                actualPath = initialPath
            } else {
                throw PrepperAppError.databaseError("No database found")
            }
        }
        
        if sqlite3_open_v2(actualPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw PrepperAppError.databaseError("Unable to open database")
        }
        
        // Enable memory mapping for performance
        let mmapSize: Int64 = 215 * 1024 * 1024 // 215MB
        sqlite3_exec(db, "PRAGMA mmap_size=\(mmapSize)", nil, nil, nil)
        
        // Other optimizations
        sqlite3_exec(db, "PRAGMA query_only=1", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store=MEMORY", nil, nil, nil)
    }
    
    // MARK: - Search Methods
    
    func searchExactTitle(query: String) async throws -> [Article] {
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PrepperAppError.databaseError("Manager deallocated"))
                    return
                }
                
                do {
                    try self.ensureOpen()
                    
                    let sql = """
                        SELECT id, title, content, priority, category, last_updated
                        FROM articles
                        WHERE LOWER(title) = LOWER(?)
                        LIMIT 10
                    """
                    
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                        throw PrepperAppError.databaseError("Failed to prepare statement")
                    }
                    defer { sqlite3_finalize(statement) }
                    
                    sqlite3_bind_text(statement, 1, query, -1, SQLITE_TRANSIENT)
                    
                    var articles: [Article] = []
                    while sqlite3_step(statement) == SQLITE_ROW {
                        articles.append(try self.articleFromStatement(statement))
                    }
                    
                    continuation.resume(returning: articles)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func searchTitlePrefix(query: String) async throws -> [Article] {
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PrepperAppError.databaseError("Manager deallocated"))
                    return
                }
                
                do {
                    try self.ensureOpen()
                    
                    let sql = """
                        SELECT id, title, content, priority, category, last_updated
                        FROM articles
                        WHERE LOWER(title) LIKE LOWER(? || '%')
                        ORDER BY priority, title
                        LIMIT 50
                    """
                    
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                        throw PrepperAppError.databaseError("Failed to prepare statement")
                    }
                    defer { sqlite3_finalize(statement) }
                    
                    sqlite3_bind_text(statement, 1, query, -1, SQLITE_TRANSIENT)
                    
                    var articles: [Article] = []
                    while sqlite3_step(statement) == SQLITE_ROW {
                        articles.append(try self.articleFromStatement(statement))
                    }
                    
                    continuation.resume(returning: articles)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getArticle(id: String) async throws -> Article? {
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PrepperAppError.databaseError("Manager deallocated"))
                    return
                }
                
                do {
                    try self.ensureOpen()
                    
                    let sql = """
                        SELECT id, title, content, priority, category, last_updated
                        FROM articles
                        WHERE id = ?
                        LIMIT 1
                    """
                    
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                        throw PrepperAppError.databaseError("Failed to prepare statement")
                    }
                    defer { sqlite3_finalize(statement) }
                    
                    sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)
                    
                    if sqlite3_step(statement) == SQLITE_ROW {
                        let article = try self.articleFromStatement(statement)
                        continuation.resume(returning: article)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func ensureOpen() throws {
        guard db == nil else { return }
        try openDatabase()
    }
    
    private func articleFromStatement(_ statement: OpaquePointer?) throws -> Article {
        guard let statement = statement else {
            throw PrepperAppError.databaseError("Invalid statement")
        }
        
        let id = String(cString: sqlite3_column_text(statement, 0))
        let title = String(cString: sqlite3_column_text(statement, 1))
        
        // Handle compressed content
        let contentBlob = sqlite3_column_blob(statement, 2)
        let contentSize = sqlite3_column_bytes(statement, 2)
        let contentData = Data(bytes: contentBlob!, count: Int(contentSize))
        
        // Decompress if needed (check for zstd magic number)
        let content: String
        if contentData.starts(with: [0x28, 0xB5, 0x2F, 0xFD]) {
            // This is zstd compressed
            content = decompressZstd(data: contentData) ?? "[Content decompression failed]"
        } else {
            content = String(data: contentData, encoding: .utf8) ?? "[Content decode failed]"
        }
        
        let priorityInt = sqlite3_column_int(statement, 3)
        let priority = SearchResult.Priority(rawValue: Int(priorityInt)) ?? .p0
        
        let category = String(cString: sqlite3_column_text(statement, 4))
        
        var lastUpdated: Date?
        if sqlite3_column_type(statement, 5) != SQLITE_NULL {
            let timestamp = sqlite3_column_int64(statement, 5)
            lastUpdated = Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        
        return Article(
            id: id,
            title: title,
            content: content,
            priority: priority,
            category: category,
            lastUpdated: lastUpdated,
            metadata: nil
        )
    }
    
    private func decompressZstd(data: Data) -> String? {
        // For now, return placeholder - real implementation would use zstd library
        // In production, we'd link the zstd library and decompress here
        return "[Zstd decompression not yet implemented - content is compressed]"
    }
}
import Foundation
import CryptoKit

class ChunkValidator {
    
    // MARK: - Validation Methods
    
    static func validateChunk(at url: URL, expectedChecksum: String) -> Result<Void, ValidationError> {
        do {
            // Read file data
            let data = try Data(contentsOf: url)
            
            // Calculate SHA-256 checksum
            let checksum = calculateChecksum(for: data)
            
            // Compare checksums
            if checksum == expectedChecksum {
                return .success(())
            } else {
                return .failure(.checksumMismatch(expected: expectedChecksum, actual: checksum))
            }
        } catch {
            return .failure(.fileReadError(error))
        }
    }
    
    static func calculateChecksum(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func validateFileSize(at url: URL, expectedSize: Int64) -> Result<Void, ValidationError> {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? Int64 else {
                return .failure(.fileSizeUnavailable)
            }
            
            if fileSize == expectedSize {
                return .success(())
            } else {
                return .failure(.fileSizeMismatch(expected: expectedSize, actual: fileSize))
            }
        } catch {
            return .failure(.fileReadError(error))
        }
    }
    
    // MARK: - Chunk Assembly
    
    static func assembleChunks(
        from chunks: [DownloadChunk],
        in directory: URL,
        to destination: URL,
        progress: ((Float) -> Void)? = nil
    ) -> Result<Void, ValidationError> {
        
        // Verify all chunks are completed
        guard chunks.allSatisfy({ $0.status == .completed }) else {
            return .failure(.incompleteChunks)
        }
        
        // Sort chunks by index
        let sortedChunks = chunks.sorted { $0.index < $1.index }
        
        do {
            // Create output file
            FileManager.default.createFile(atPath: destination.path, contents: nil)
            guard let fileHandle = FileHandle(forWritingAtPath: destination.path) else {
                return .failure(.fileCreationFailed)
            }
            
            defer { fileHandle.closeFile() }
            
            // Assemble chunks
            for (index, chunk) in sortedChunks.enumerated() {
                let chunkPath = directory
                    .appendingPathComponent(chunk.taskId)
                    .appendingPathComponent("chunk-\(chunk.index)")
                
                // Validate chunk exists
                guard FileManager.default.fileExists(atPath: chunkPath.path) else {
                    return .failure(.chunkNotFound(index: chunk.index))
                }
                
                // Read and write chunk data
                let chunkData = try Data(contentsOf: chunkPath)
                fileHandle.write(chunkData)
                
                // Report progress
                let progressValue = Float(index + 1) / Float(sortedChunks.count)
                progress?(progressValue)
            }
            
            return .success(())
            
        } catch {
            // Clean up partial file
            try? FileManager.default.removeItem(at: destination)
            return .failure(.assemblyFailed(error))
        }
    }
    
    // MARK: - Content Verification
    
    static func verifyContentIntegrity(
        at path: URL,
        manifest: ContentManifest
    ) -> Result<Void, ValidationError> {
        
        // Check if it's a SQLite database
        if path.pathExtension == "db" {
            return verifySQLiteDatabase(at: path)
        }
        
        // Check if it's a ZIM file
        if path.pathExtension == "zim" {
            return verifyZIMFile(at: path)
        }
        
        // Generic file verification
        return .success(())
    }
    
    private static func verifySQLiteDatabase(at path: URL) -> Result<Void, ValidationError> {
        var db: OpaquePointer?
        
        // Try to open database
        if sqlite3_open_v2(path.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            sqlite3_close(db)
            return .failure(.invalidDatabase)
        }
        
        defer { sqlite3_close(db) }
        
        // Run integrity check
        var statement: OpaquePointer?
        let sql = "PRAGMA integrity_check"
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            return .failure(.invalidDatabase)
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            let result = String(cString: sqlite3_column_text(statement, 0))
            if result == "ok" {
                return .success(())
            } else {
                return .failure(.databaseCorrupted(result))
            }
        }
        
        return .failure(.invalidDatabase)
    }
    
    private static func verifyZIMFile(at path: URL) -> Result<Void, ValidationError> {
        do {
            let fileHandle = try FileHandle(forReadingFrom: path)
            defer { fileHandle.closeFile() }
            
            // Read ZIM magic number (72, 73, 77) = "ZIM"
            let magicData = fileHandle.readData(ofLength: 4)
            let magic = magicData.map { $0 }
            
            if magic.count >= 3 && magic[0] == 72 && magic[1] == 73 && magic[2] == 77 {
                return .success(())
            } else {
                return .failure(.invalidFileFormat("Not a valid ZIM file"))
            }
        } catch {
            return .failure(.fileReadError(error))
        }
    }
    
    // MARK: - Cleanup
    
    static func cleanupChunks(for taskId: String, in directory: URL) {
        let taskDirectory = directory.appendingPathComponent(taskId)
        try? FileManager.default.removeItem(at: taskDirectory)
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case checksumMismatch(expected: String, actual: String)
    case fileSizeMismatch(expected: Int64, actual: Int64)
    case fileReadError(Error)
    case fileSizeUnavailable
    case incompleteChunks
    case fileCreationFailed
    case chunkNotFound(index: Int)
    case assemblyFailed(Error)
    case invalidDatabase
    case databaseCorrupted(String)
    case invalidFileFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .checksumMismatch:
            return "Downloaded file is corrupted (checksum mismatch)"
        case .fileSizeMismatch(let expected, let actual):
            return "File size mismatch. Expected \(expected) bytes, got \(actual)"
        case .fileReadError(let error):
            return "Failed to read file: \(error.localizedDescription)"
        case .fileSizeUnavailable:
            return "Could not determine file size"
        case .incompleteChunks:
            return "Not all chunks have been downloaded"
        case .fileCreationFailed:
            return "Failed to create output file"
        case .chunkNotFound(let index):
            return "Chunk \(index) not found"
        case .assemblyFailed(let error):
            return "Failed to assemble chunks: \(error.localizedDescription)"
        case .invalidDatabase:
            return "Invalid or corrupted database file"
        case .databaseCorrupted(let message):
            return "Database corruption detected: \(message)"
        case .invalidFileFormat(let message):
            return "Invalid file format: \(message)"
        }
    }
}

// MARK: - Checksum Cache

class ChecksumCache {
    private let cacheFile: URL
    private var cache: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.prepperapp.checksum.cache")
    
    init(documentsDirectory: URL) {
        self.cacheFile = documentsDirectory.appendingPathComponent("checksum_cache.json")
        loadCache()
    }
    
    func getChecksum(for url: URL) -> String? {
        queue.sync {
            cache[url.path]
        }
    }
    
    func setChecksum(_ checksum: String, for url: URL) {
        queue.async { [weak self] in
            self?.cache[url.path] = checksum
            self?.saveCache()
        }
    }
    
    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: cacheFile)
            cache = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("Failed to load checksum cache: \(error)")
        }
    }
    
    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheFile)
        } catch {
            print("Failed to save checksum cache: \(error)")
        }
    }
}
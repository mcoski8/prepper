import Foundation
import Compression

class ContentManager {
    static let shared = ContentManager()
    
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let contentVersion = "1.0.0"
    
    // ODR tags
    private let initialContentTag = "initial-content"
    private let coreContentTag = "core-content"  // Tantivy index
    private let fullDatabaseTag = "full-database" // SQLite DB
    
    // Content state
    enum ContentState {
        case notExtracted
        case extracting(progress: Float)
        case partial  // Initial content only
        case complete
    }
    
    @Published private(set) var contentState: ContentState = .notExtracted
    private var currentResourceRequest: NSBundleResourceRequest?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func checkAndExtractContentIfNeeded() {
        let extractedMarkerPath = documentsURL.appendingPathComponent(".extracted_\(contentVersion)")
        
        if FileManager.default.fileExists(atPath: extractedMarkerPath.path) {
            contentState = .complete
            return
        }
        
        // Check for partial extraction
        let partialMarkerPath = documentsURL.appendingPathComponent(".partial_\(contentVersion)")
        if FileManager.default.fileExists(atPath: partialMarkerPath.path) {
            contentState = .partial
            // Continue with full database download
            downloadFullContent()
            return
        }
        
        // Start fresh extraction
        extractInitialContent()
    }
    
    // MARK: - Private Methods
    
    private func extractInitialContent() {
        // Initial content should be in main bundle
        guard let initialDBPath = Bundle.main.path(forResource: "initial", ofType: "db") else {
            print("Initial content not found in bundle")
            return
        }
        
        contentState = .extracting(progress: 0.1)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let destPath = self.documentsURL.appendingPathComponent("initial.db")
                try FileManager.default.copyItem(atPath: initialDBPath, toPath: destPath.path)
                
                // Mark partial extraction complete
                let partialMarker = self.documentsURL.appendingPathComponent(".partial_\(self.contentVersion)")
                try "".write(to: partialMarker, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    self.contentState = .partial
                    // Now download full content
                    self.downloadFullContent()
                }
            } catch {
                print("Failed to extract initial content: \(error)")
            }
        }
    }
    
    private func downloadFullContent() {
        // Request core content (Tantivy index) first
        let coreRequest = NSBundleResourceRequest(tags: [coreContentTag])
        coreRequest.loadingPriority = NSBundleResourceRequest.loadingPriorityUrgent
        
        self.currentResourceRequest = coreRequest
        
        coreRequest.beginAccessingResources { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Failed to download core content: \(error)")
                return
            }
            
            // Extract Tantivy index
            self.extractTantivyIndex {
                // Now download full database
                self.downloadFullDatabase()
            }
        }
    }
    
    private func downloadFullDatabase() {
        let dbRequest = NSBundleResourceRequest(tags: [fullDatabaseTag])
        dbRequest.loadingPriority = 0.8
        
        self.currentResourceRequest = dbRequest
        
        // Monitor progress
        let progressObserver = dbRequest.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.contentState = .extracting(progress: Float(progress.fractionCompleted))
            }
        }
        
        dbRequest.beginAccessingResources { [weak self] error in
            guard let self = self else { return }
            progressObserver.invalidate()
            
            if let error = error {
                print("Failed to download full database: \(error)")
                return
            }
            
            // Extract full database
            self.extractFullDatabase {
                self.finalizeExtraction()
            }
        }
    }
    
    private func extractTantivyIndex(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Get path from ODR bundle
            guard let indexPath = Bundle.main.path(forResource: "tantivy_index", ofType: "tar.gz", inDirectory: "OnDemandResources") else {
                print("Tantivy index not found in ODR")
                return
            }
            
            do {
                let destPath = self.documentsURL.appendingPathComponent("tantivy_index")
                try self.extractTarGz(from: indexPath, to: destPath.path)
                
                DispatchQueue.main.async {
                    completion()
                }
            } catch {
                print("Failed to extract Tantivy index: \(error)")
            }
        }
    }
    
    private func extractFullDatabase(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Get path from ODR bundle
            guard let dbPath = Bundle.main.path(forResource: "prepperapp", ofType: "db.gz", inDirectory: "OnDemandResources") else {
                print("Full database not found in ODR")
                return
            }
            
            do {
                let destPath = self.documentsURL.appendingPathComponent("prepperapp.db")
                try self.decompressGzip(from: dbPath, to: destPath.path)
                
                DispatchQueue.main.async {
                    completion()
                }
            } catch {
                print("Failed to extract full database: \(error)")
            }
        }
    }
    
    private func finalizeExtraction() {
        // Verify all required files exist
        let requiredFiles = ["initial.db", "prepperapp.db", "tantivy_index"]
        var allFilesExist = true
        
        for file in requiredFiles {
            let filePath = documentsURL.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: filePath.path) {
                allFilesExist = false
                break
            }
        }
        
        if allFilesExist {
            // Mark extraction complete
            let completeMarker = documentsURL.appendingPathComponent(".extracted_\(contentVersion)")
            try? "".write(to: completeMarker, atomically: true, encoding: .utf8)
            
            contentState = .complete
            
            // Clean up partial marker
            let partialMarker = documentsURL.appendingPathComponent(".partial_\(contentVersion)")
            try? FileManager.default.removeItem(at: partialMarker)
        }
    }
    
    // MARK: - Decompression Helpers
    
    private func extractTarGz(from sourcePath: String, to destPath: String) throws {
        // Simple tar.gz extraction using Process
        let task = Process()
        task.launchPath = "/usr/bin/tar"
        task.arguments = ["-xzf", sourcePath, "-C", destPath]
        
        try FileManager.default.createDirectory(atPath: destPath, withIntermediateDirectories: true)
        
        task.launch()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw NSError(domain: "ContentManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "tar extraction failed"])
        }
    }
    
    private func decompressGzip(from sourcePath: String, to destPath: String) throws {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destURL = URL(fileURLWithPath: destPath)
        
        guard let sourceData = try? Data(contentsOf: sourceURL) else {
            throw NSError(domain: "ContentManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read source file"])
        }
        
        guard let decompressedData = sourceData.gunzipped() else {
            throw NSError(domain: "ContentManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
        }
        
        try decompressedData.write(to: destURL)
    }
}

// MARK: - Data Extension for Gzip

extension Data {
    func gunzipped() -> Data? {
        guard self.count > 0 else { return nil }
        
        return self.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
            defer { buffer.deallocate() }
            
            let result = compression_decode_buffer(
                buffer, count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_ZLIB
            )
            
            guard result > 0 else { return nil }
            return Data(bytes: buffer, count: result)
        }
    }
}
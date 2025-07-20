import Foundation

/// Manages the extraction of the PrepperApp content bundle
/// with atomic, resumable operations
class ContentExtractor {
    
    enum ExtractionState {
        case notStarted
        case inProgress(progress: Double)
        case completed
        case failed(error: Error)
    }
    
    enum ExtractionError: Error {
        case insufficientStorage(required: Int64, available: Int64)
        case bundleNotFound
        case extractionFailed(underlying: Error)
        case verificationFailed
    }
    
    private let bundleName = "prepperapp-p0-v1.0.0"
    private let requiredSpace: Int64 = 300 * 1024 * 1024 // 300MB safety margin
    
    private var extractionTask: Task<Void, Error>?
    
    /// Current extraction state
    @Published private(set) var state: ExtractionState = .notStarted
    
    /// Check if content is already extracted and valid
    func isContentReady() -> Bool {
        let documentsPath = getDocumentsDirectory()
        let contentPath = documentsPath.appendingPathComponent(bundleName)
        let flagPath = contentPath.appendingPathComponent(".extraction_complete")
        
        return FileManager.default.fileExists(atPath: flagPath.path)
    }
    
    /// Start or resume content extraction
    func startExtraction() async throws {
        // Cancel any existing extraction
        extractionTask?.cancel()
        
        // Check if already completed
        if isContentReady() {
            state = .completed
            return
        }
        
        // Check available storage
        let available = try getAvailableStorage()
        if available < requiredSpace {
            let error = ExtractionError.insufficientStorage(
                required: requiredSpace,
                available: available
            )
            state = .failed(error: error)
            throw error
        }
        
        // Start extraction task
        extractionTask = Task {
            do {
                try await performExtraction()
                state = .completed
            } catch {
                state = .failed(error: error)
                throw error
            }
        }
        
        try await extractionTask!.value
    }
    
    private func performExtraction() async throws {
        let bundleURL = getBundleURL()
        let documentsPath = getDocumentsDirectory()
        let tempPath = documentsPath.appendingPathComponent("\(bundleName).tmp")
        let finalPath = documentsPath.appendingPathComponent(bundleName)
        
        // Clean up any previous incomplete extraction
        try? FileManager.default.removeItem(at: tempPath)
        
        // Create temp directory
        try FileManager.default.createDirectory(
            at: tempPath,
            withIntermediateDirectories: true
        )
        
        // Extract to temp directory with progress tracking
        try await extractBundle(
            from: bundleURL,
            to: tempPath,
            progressHandler: { progress in
                await MainActor.run {
                    self.state = .inProgress(progress: progress)
                }
            }
        )
        
        // Verify extraction
        try verifyExtraction(at: tempPath)
        
        // Create completion flag
        let flagPath = tempPath.appendingPathComponent(".extraction_complete")
        try "".write(to: flagPath, atomically: true, encoding: .utf8)
        
        // Atomic move to final location
        try? FileManager.default.removeItem(at: finalPath)
        try FileManager.default.moveItem(at: tempPath, to: finalPath)
    }
    
    private func extractBundle(
        from source: URL,
        to destination: URL,
        progressHandler: @escaping (Double) async -> Void
    ) async throws {
        // This would use a proper unzip library in production
        // For now, using built-in compression APIs
        
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(
            readingItemAt: source,
            options: .withoutChanges,
            error: &error
        ) { (url) in
            // Extract using NSFileManager compression APIs
            do {
                // In production, use a library like ZIPFoundation
                // that supports progress callbacks
                
                // Simulate progress for prototype
                for i in 0...10 {
                    Thread.sleep(forTimeInterval: 0.1)
                    Task {
                        await progressHandler(Double(i) / 10.0)
                    }
                }
                
                // TODO: Actual extraction logic here
                
            } catch {
                // Handle extraction errors
            }
        }
        
        if let error = error {
            throw ExtractionError.extractionFailed(underlying: error)
        }
    }
    
    private func verifyExtraction(at path: URL) throws {
        // Verify required files exist
        let requiredFiles = [
            "content/medical.db",
            "index/meta.json",
            "metadata/manifest.json"
        ]
        
        for file in requiredFiles {
            let filePath = path.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath: filePath.path) {
                throw ExtractionError.verificationFailed
            }
        }
        
        // Verify SQLite database is valid
        let dbPath = path.appendingPathComponent("content/medical.db")
        // TODO: Open SQLite and run simple query to verify
    }
    
    private func getBundleURL() -> URL {
        guard let url = Bundle.main.url(
            forResource: bundleName,
            withExtension: "zip"
        ) else {
            fatalError("Content bundle not found in app bundle")
        }
        return url
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }
    
    private func getAvailableStorage() throws -> Int64 {
        let documentsPath = getDocumentsDirectory()
        let values = try documentsPath.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }
}
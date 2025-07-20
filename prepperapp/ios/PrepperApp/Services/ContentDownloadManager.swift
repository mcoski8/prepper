import Foundation
import CommonCrypto

class ContentDownloadManager: NSObject {
    static let shared = ContentDownloadManager()
    
    // MARK: - Properties
    
    private let downloadQueue = OperationQueue()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let downloadTasksFile: URL
    private let contentDirectory: URL
    
    private var backgroundSession: URLSession!
    private var activeTasks: [String: DownloadTask] = [:]
    private var activeDownloads: [URLSessionDownloadTask: DownloadChunk] = [:]
    private var progressHandlers: [String: (DownloadProgress) -> Void] = [:]
    private var completionHandlers: [String: (Result<Void, Error>) -> Void] = [:]
    
    private let taskPersistenceQueue = DispatchQueue(label: "com.prepperapp.download.persistence")
    
    // MARK: - Initialization
    
    override private init() {
        self.downloadTasksFile = documentsDirectory.appendingPathComponent("download_tasks.json")
        self.contentDirectory = documentsDirectory.appendingPathComponent("content")
        
        super.init()
        
        // Create content directory if needed
        try? FileManager.default.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
        
        // Configure download queue
        downloadQueue.maxConcurrentOperationCount = DownloadConfiguration.maxConcurrentChunks
        downloadQueue.qualityOfService = .utility
        
        // Setup background session
        setupBackgroundSession()
        
        // Load persisted tasks
        loadPersistedTasks()
    }
    
    private func setupBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.prepperapp.content.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForRequest = DownloadConfiguration.downloadTimeout
        config.timeoutIntervalForResource = DownloadConfiguration.downloadTimeout * 10
        
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public API
    
    func downloadTier1Content(
        progress: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Check storage first
        guard let storageInfo = getStorageInfo() else {
            completion(.failure(DownloadError.invalidResponse))
            return
        }
        
        let requiredSpace: Int64 = 3 * 1024 * 1024 * 1024 // 3GB
        guard storageInfo.canAccommodateDownload(size: requiredSpace) else {
            completion(.failure(DownloadError.insufficientStorage(
                required: requiredSpace,
                available: storageInfo.availableSpace
            )))
            return
        }
        
        // Create download task
        let task = createTier1DownloadTask()
        
        // Store handlers
        progressHandlers[task.id] = progress
        completionHandlers[task.id] = completion
        
        // Start download
        startDownloadTask(task)
    }
    
    func pauseDownload(taskId: String) {
        guard var task = activeTasks[taskId] else { return }
        
        task.status = .paused
        task.updatedAt = Date()
        activeTasks[taskId] = task
        
        // Cancel active downloads for this task
        activeDownloads.forEach { (download, chunk) in
            if chunk.taskId == taskId {
                download.cancel()
            }
        }
        
        persistTasks()
    }
    
    func resumeDownload(taskId: String) {
        guard var task = activeTasks[taskId], task.status == .paused else { return }
        
        task.status = .downloading
        task.updatedAt = Date()
        activeTasks[taskId] = task
        
        // Resume downloading chunks
        downloadNextChunks(for: task)
        
        persistTasks()
    }
    
    func cancelDownload(taskId: String) {
        guard let task = activeTasks[taskId] else { return }
        
        // Cancel active downloads
        activeDownloads.forEach { (download, chunk) in
            if chunk.taskId == taskId {
                download.cancel()
            }
        }
        
        // Remove task
        activeTasks.removeValue(forKey: taskId)
        progressHandlers.removeValue(forKey: taskId)
        
        // Clean up partial downloads
        deletePartialDownloads(for: task)
        
        // Notify completion
        completionHandlers[taskId]?(.failure(DownloadError.cancelled))
        completionHandlers.removeValue(forKey: taskId)
        
        persistTasks()
    }
    
    func getAllDownloads() -> [DownloadTask] {
        Array(activeTasks.values).sorted { $0.priority < $1.priority }
    }
    
    func getDownloadProgress(for taskId: String) -> DownloadProgress? {
        guard let task = activeTasks[taskId] else { return nil }
        return calculateProgress(for: task)
    }
    
    // MARK: - Private Methods
    
    private func createTier1DownloadTask() -> DownloadTask {
        let taskId = UUID().uuidString
        let totalSize: Int64 = 3 * 1024 * 1024 * 1024 // 3GB
        
        // Create chunks
        var chunks: [DownloadChunk] = []
        var offset: Int64 = 0
        var chunkIndex = 0
        
        while offset < totalSize {
            let chunkSize = min(DownloadConfiguration.chunkSize, totalSize - offset)
            let chunk = DownloadChunk(
                id: "\(taskId)-\(chunkIndex)",
                taskId: taskId,
                index: chunkIndex,
                offset: offset,
                size: chunkSize,
                url: URL(string: "https://content.prepperapp.com/tier1/chunk-\(chunkIndex)")!, // TODO: Real URLs
                status: .pending,
                downloadedBytes: 0,
                checksum: nil,
                retryCount: 0,
                lastError: nil
            )
            chunks.append(chunk)
            
            offset += chunkSize
            chunkIndex += 1
        }
        
        return DownloadTask(
            id: taskId,
            contentType: .tier1Essential,
            totalSize: totalSize,
            chunks: chunks,
            status: .pending,
            priority: .critical,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            error: nil
        )
    }
    
    private func startDownloadTask(_ task: DownloadTask) {
        var mutableTask = task
        mutableTask.status = .downloading
        mutableTask.updatedAt = Date()
        activeTasks[task.id] = mutableTask
        
        downloadNextChunks(for: mutableTask)
        persistTasks()
    }
    
    private func downloadNextChunks(for task: DownloadTask) {
        let activeChunkCount = activeDownloads.values.filter { $0.taskId == task.id }.count
        let availableSlots = DownloadConfiguration.maxConcurrentChunks - activeChunkCount
        
        guard availableSlots > 0 else { return }
        
        let pendingChunks = task.chunks
            .filter { $0.status == .pending || ($0.status == .failed && $0.retryCount < DownloadConfiguration.maxRetries) }
            .sorted { $0.index < $1.index }
            .prefix(availableSlots)
        
        for chunk in pendingChunks {
            downloadChunk(chunk, for: task)
        }
    }
    
    private func downloadChunk(_ chunk: DownloadChunk, for task: DownloadTask) {
        var mutableChunk = chunk
        mutableChunk.status = .downloading
        
        // Create request with range header
        var request = URLRequest(url: chunk.url)
        let endByte = chunk.offset + chunk.size - 1
        request.setValue("bytes=\(chunk.offset)-\(endByte)", forHTTPHeaderField: "Range")
        
        let downloadTask = backgroundSession.downloadTask(with: request)
        activeDownloads[downloadTask] = mutableChunk
        
        downloadTask.resume()
    }
    
    private func calculateProgress(for task: DownloadTask) -> DownloadProgress {
        let completedBytes = task.chunks.reduce(0) { total, chunk in
            total + (chunk.status == .completed ? chunk.size : chunk.downloadedBytes)
        }
        
        let completedChunks = task.chunks.filter { $0.status == .completed }.count
        let currentChunk = task.chunks.first { $0.status == .downloading }
        let currentProgress = currentChunk?.progress ?? 0
        
        // Calculate speed (simplified - in real app, track over time)
        let downloadSpeed: Int64 = 1024 * 1024 // 1MB/s placeholder
        
        let remainingBytes = task.totalSize - completedBytes
        let estimatedTime = remainingBytes > 0 ? TimeInterval(remainingBytes / downloadSpeed) : nil
        
        return DownloadProgress(
            taskId: task.id,
            totalBytes: task.totalSize,
            downloadedBytes: completedBytes,
            chunksCompleted: completedChunks,
            totalChunks: task.chunks.count,
            currentChunkProgress: currentProgress,
            estimatedTimeRemaining: estimatedTime,
            downloadSpeed: downloadSpeed
        )
    }
    
    // MARK: - Storage Management
    
    private func getStorageInfo() -> StorageInfo? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsDirectory.path)
            guard let totalSpace = attributes[.systemSize] as? Int64,
                  let freeSpace = attributes[.systemFreeSize] as? Int64 else {
                return nil
            }
            
            // Calculate app usage
            let appUsage = calculateAppStorageUsage()
            
            return StorageInfo(
                totalSpace: totalSpace,
                availableSpace: freeSpace,
                usedByApp: appUsage
            )
        } catch {
            print("Failed to get storage info: \(error)")
            return nil
        }
    }
    
    private func calculateAppStorageUsage() -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    // MARK: - Persistence
    
    private func persistTasks() {
        taskPersistenceQueue.async { [weak self] in
            guard let self = self else { return }
            
            let tasks = Array(self.activeTasks.values)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            do {
                let data = try encoder.encode(tasks)
                try data.write(to: self.downloadTasksFile)
            } catch {
                print("Failed to persist download tasks: \(error)")
            }
        }
    }
    
    private func loadPersistedTasks() {
        taskPersistenceQueue.sync {
            guard FileManager.default.fileExists(atPath: downloadTasksFile.path) else { return }
            
            do {
                let data = try Data(contentsOf: downloadTasksFile)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let tasks = try decoder.decode([DownloadTask].self, from: data)
                for task in tasks {
                    activeTasks[task.id] = task
                    
                    // Resume downloading tasks
                    if task.status == .downloading {
                        downloadNextChunks(for: task)
                    }
                }
            } catch {
                print("Failed to load persisted tasks: \(error)")
            }
        }
    }
    
    private func deletePartialDownloads(for task: DownloadTask) {
        let taskDirectory = contentDirectory.appendingPathComponent(task.id)
        try? FileManager.default.removeItem(at: taskDirectory)
    }
}

// MARK: - URLSessionDownloadDelegate

extension ContentDownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let chunk = activeDownloads[downloadTask] else { return }
        
        // Verify and move file
        processDownloadedChunk(chunk, from: location)
        
        // Remove from active downloads
        activeDownloads.removeValue(forKey: downloadTask)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard var chunk = activeDownloads[downloadTask],
              let task = activeTasks[chunk.taskId] else { return }
        
        // Update chunk progress
        chunk.downloadedBytes = totalBytesWritten
        activeDownloads[downloadTask] = chunk
        
        // Calculate and report overall progress
        let progress = calculateProgress(for: task)
        progressHandlers[task.id]?(progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let chunk = activeDownloads[downloadTask] else { return }
        
        if let error = error {
            handleChunkDownloadError(chunk, error: error)
        }
        
        activeDownloads.removeValue(forKey: downloadTask)
    }
    
    private func processDownloadedChunk(_ chunk: DownloadChunk, from location: URL) {
        // TODO: Implement chunk validation and assembly
        // For now, just move to destination
        let chunkDestination = contentDirectory
            .appendingPathComponent(chunk.taskId)
            .appendingPathComponent("chunk-\(chunk.index)")
        
        do {
            try FileManager.default.createDirectory(at: chunkDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: chunkDestination)
            
            // Update chunk status
            if var task = activeTasks[chunk.taskId],
               let chunkIndex = task.chunks.firstIndex(where: { $0.id == chunk.id }) {
                task.chunks[chunkIndex].status = .completed
                task.updatedAt = Date()
                activeTasks[chunk.taskId] = task
                
                // Check if task is complete
                if task.isComplete {
                    completeDownloadTask(task)
                } else {
                    // Download next chunks
                    downloadNextChunks(for: task)
                }
                
                persistTasks()
            }
        } catch {
            handleChunkDownloadError(chunk, error: error)
        }
    }
    
    private func handleChunkDownloadError(_ chunk: DownloadChunk, error: Error) {
        guard var task = activeTasks[chunk.taskId],
              let chunkIndex = task.chunks.firstIndex(where: { $0.id == chunk.id }) else { return }
        
        // Update chunk with error
        task.chunks[chunkIndex].status = .failed
        task.chunks[chunkIndex].retryCount += 1
        task.chunks[chunkIndex].lastError = error.localizedDescription
        
        // Check if we should retry
        if task.chunks[chunkIndex].retryCount < DownloadConfiguration.maxRetries {
            // Schedule retry with exponential backoff
            let delay = calculateRetryDelay(retryCount: task.chunks[chunkIndex].retryCount)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.downloadNextChunks(for: task)
            }
        } else {
            // Too many retries, fail the task
            task.status = .failed
            task.error = "Chunk \(chunk.index) failed after \(DownloadConfiguration.maxRetries) retries"
            completionHandlers[task.id]?(.failure(DownloadError.tooManyRetries))
        }
        
        task.updatedAt = Date()
        activeTasks[chunk.taskId] = task
        persistTasks()
    }
    
    private func completeDownloadTask(_ task: DownloadTask) {
        var mutableTask = task
        mutableTask.status = .completed
        mutableTask.completedAt = Date()
        mutableTask.updatedAt = Date()
        activeTasks[task.id] = mutableTask
        
        // Notify completion
        completionHandlers[task.id]?(.success(()))
        
        // Clean up handlers
        progressHandlers.removeValue(forKey: task.id)
        completionHandlers.removeValue(forKey: task.id)
        
        persistTasks()
    }
    
    private func calculateRetryDelay(retryCount: Int) -> TimeInterval {
        let exponentialDelay = DownloadConfiguration.initialRetryDelay * pow(2.0, Double(retryCount - 1))
        return min(exponentialDelay, DownloadConfiguration.maxRetryDelay)
    }
}

// MARK: - URLSessionDelegate

extension ContentDownloadManager: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Notify app delegate that background downloads completed
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let completionHandler = appDelegate.backgroundSessionCompletionHandler {
                appDelegate.backgroundSessionCompletionHandler = nil
                completionHandler()
            }
        }
    }
}
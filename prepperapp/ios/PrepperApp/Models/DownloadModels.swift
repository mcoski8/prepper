import Foundation

// MARK: - Download Task Models

struct DownloadTask: Codable {
    let id: String
    let contentType: ContentType
    let totalSize: Int64
    let chunks: [DownloadChunk]
    var status: DownloadStatus
    var priority: DownloadPriority
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var error: String?
    
    var progress: Float {
        let completedBytes = chunks.reduce(0) { $0 + ($1.status == .completed ? $1.size : 0) }
        return Float(completedBytes) / Float(totalSize)
    }
    
    var isComplete: Bool {
        chunks.allSatisfy { $0.status == .completed }
    }
    
    var nextPendingChunk: DownloadChunk? {
        chunks.first { $0.status == .pending || $0.status == .failed }
    }
}

struct DownloadChunk: Codable {
    let id: String
    let taskId: String
    let index: Int
    let offset: Int64
    let size: Int64
    let url: URL
    var status: ChunkStatus
    var downloadedBytes: Int64
    var checksum: String?
    var retryCount: Int
    var lastError: String?
    
    var progress: Float {
        guard size > 0 else { return 0 }
        return Float(downloadedBytes) / Float(size)
    }
}

// MARK: - Enums

enum ContentType: String, Codable {
    case tier1Essential = "tier1_essential"
    case tier2Module = "tier2_module"
    case update = "update"
}

enum DownloadStatus: String, Codable {
    case pending
    case downloading
    case paused
    case completed
    case failed
    case verifying
}

enum ChunkStatus: String, Codable {
    case pending
    case downloading
    case completed
    case failed
    case verifying
}

enum DownloadPriority: Int, Codable, Comparable {
    case critical = 0  // Life-threatening content
    case high = 1      // Essential survival
    case medium = 2    // Important reference
    case low = 3       // Nice to have
    
    static func < (lhs: DownloadPriority, rhs: DownloadPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Download Configuration

struct DownloadConfiguration {
    static let chunkSize: Int64 = 100 * 1024 * 1024 // 100MB chunks
    static let maxConcurrentChunks = 2
    static let maxRetries = 10
    static let initialRetryDelay: TimeInterval = 1.0
    static let maxRetryDelay: TimeInterval = 300.0 // 5 minutes
    static let downloadTimeout: TimeInterval = 300.0 // 5 minutes per chunk
    static let minimumFreeSpace: Int64 = 500 * 1024 * 1024 // 500MB buffer
}

// MARK: - Storage Info

struct StorageInfo {
    let totalSpace: Int64
    let availableSpace: Int64
    let usedByApp: Int64
    
    var percentageUsed: Float {
        Float(totalSpace - availableSpace) / Float(totalSpace)
    }
    
    func canAccommodateDownload(size: Int64) -> Bool {
        availableSpace - DownloadConfiguration.minimumFreeSpace > size
    }
}

// MARK: - Progress Tracking

struct DownloadProgress {
    let taskId: String
    let totalBytes: Int64
    let downloadedBytes: Int64
    let chunksCompleted: Int
    let totalChunks: Int
    let currentChunkProgress: Float
    let estimatedTimeRemaining: TimeInterval?
    let downloadSpeed: Int64 // bytes per second
    
    var overallProgress: Float {
        guard totalBytes > 0 else { return 0 }
        return Float(downloadedBytes) / Float(totalBytes)
    }
    
    var formattedSpeed: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: downloadSpeed))/s"
    }
    
    var formattedTimeRemaining: String? {
        guard let time = estimatedTimeRemaining else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: time)
    }
}

// MARK: - Module Metadata

struct ContentModule: Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let sizeBytes: Int64
    let version: String
    let priority: DownloadPriority
    let dependencies: [String]
    let downloadURL: URL
    let checksumURL: URL
    let iconName: String?
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: sizeBytes)
    }
}

// MARK: - Download Errors

enum DownloadError: LocalizedError {
    case insufficientStorage(required: Int64, available: Int64)
    case networkError(underlying: Error)
    case checksumMismatch(expected: String, actual: String)
    case chunkDownloadFailed(chunkId: String, reason: String)
    case invalidResponse
    case cancelled
    case tooManyRetries
    
    var errorDescription: String? {
        switch self {
        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            return "Not enough storage. Need \(formatter.string(fromByteCount: required)), have \(formatter.string(fromByteCount: available))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .checksumMismatch:
            return "Downloaded file is corrupted"
        case .chunkDownloadFailed(let chunkId, let reason):
            return "Failed to download chunk \(chunkId): \(reason)"
        case .invalidResponse:
            return "Invalid server response"
        case .cancelled:
            return "Download cancelled"
        case .tooManyRetries:
            return "Download failed after multiple retries"
        }
    }
}
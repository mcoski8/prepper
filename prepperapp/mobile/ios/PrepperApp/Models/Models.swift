import Foundation

// MARK: - Search Result

struct SearchResult: Codable {
    let articleId: String
    let title: String
    let snippet: String
    let score: Float
    let priority: Priority
    let source: Source
    let isExactMatch: Bool
    
    enum Priority: Int, Codable, Comparable {
        case p0 = 0
        case p1 = 1
        case p2 = 2
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    enum Source: String, Codable {
        case initial = "INITIAL"
        case internal = "INTERNAL"
        case external = "EXTERNAL"
    }
}

// MARK: - Article

struct Article: Codable {
    let id: String
    let title: String
    let content: String
    let priority: SearchResult.Priority
    let category: String
    let lastUpdated: Date?
    let metadata: ArticleMetadata?
}

struct ArticleMetadata: Codable {
    let readingTime: Int? // in minutes
    let difficulty: String?
    let requiredSupplies: [String]?
    let relatedArticles: [String]?
}

// MARK: - Tantivy Bridge Models

struct TantivySearchRequest: Codable {
    let query: String
    let limit: Int
    let offset: Int
}

struct TantivySearchResponse: Codable {
    let success: [TantivySearchResult]?
    let error: String?
}

struct TantivySearchResult: Codable {
    let docId: String
    let score: Float
    let title: String
    let snippet: String?
}

// MARK: - Emergency Content

struct EmergencyArticle {
    static let hemorrhageControl = "hemorrhage-control"
    static let cprGuide = "cpr-guide"
    static let chokingResponse = "choking-response"
    static let shockTreatment = "shock-treatment"
    static let hypothermia = "hypothermia-treatment"
}

// MARK: - Content Bundle Manifest

struct ContentManifest: Codable {
    let version: String
    let generatedAt: Date
    let articleCount: Int
    let priority0Count: Int
    let priority1Count: Int
    let priority2Count: Int
    let totalSizeBytes: Int64
    let checksum: String
}

// MARK: - Error Types

enum PrepperAppError: LocalizedError {
    case contentNotAvailable
    case searchFailed(String)
    case articleNotFound
    case extractionFailed(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .contentNotAvailable:
            return "Content is not available. Please wait for download to complete."
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .articleNotFound:
            return "Article not found"
        case .extractionFailed(let message):
            return "Content extraction failed: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        }
    }
}
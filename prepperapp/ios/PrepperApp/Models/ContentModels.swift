import Foundation

// MARK: - Content Manifest Models

struct ContentManifest: Codable {
    let version: String
    let type: ContentType
    let name: String
    let description: String
    let sizeMB: Double
    let requiresExternalStorage: Bool
    let minAppVersion: String
    let created: Date
    let content: ContentInfo
    let uiConfig: UIConfig
    let searchConfig: SearchConfig
    
    enum CodingKeys: String, CodingKey {
        case version, type, name, description
        case sizeMB = "size_mb"
        case requiresExternalStorage = "requires_external_storage"
        case minAppVersion = "min_app_version"
        case created, content
        case uiConfig = "ui_config"
        case searchConfig = "search_config"
    }
}

enum ContentType: String, Codable {
    case test
    case tier1
    case tier2
    case tier3
    case fallback
}

struct ContentInfo: Codable {
    let databases: [String]
    let indexes: [String]
    let categories: [String]
    let articleCount: Int
    let priorityLevels: [Int]
    let priority0Count: Int
    let features: ContentFeatures
    
    enum CodingKeys: String, CodingKey {
        case databases, indexes, categories
        case articleCount = "article_count"
        case priorityLevels = "priority_levels"
        case priority0Count = "priority_0_count"
        case features
    }
}

struct ContentFeatures: Codable {
    let offlineMaps: Bool
    let plantIdentification: Bool
    let pillIdentification: Bool
    let medicalProcedures: Bool
    let survivalBasics: Bool
    let emergencySignaling: Bool
    
    enum CodingKeys: String, CodingKey {
        case offlineMaps = "offline_maps"
        case plantIdentification = "plant_identification"
        case pillIdentification = "pill_identification"
        case medicalProcedures = "medical_procedures"
        case survivalBasics = "survival_basics"
        case emergencySignaling = "emergency_signaling"
    }
}

struct UIConfig: Codable {
    let searchPlaceholder: String
    let homeScreenModules: [HomeModule]
    let enabledTabs: [String]
    let disabledFeatures: [String]
    
    enum CodingKeys: String, CodingKey {
        case searchPlaceholder = "search_placeholder"
        case homeScreenModules = "home_screen_modules"
        case enabledTabs = "enabled_tabs"
        case disabledFeatures = "disabled_features"
    }
}

struct HomeModule: Codable {
    let id: String
    let title: String
    let icon: String
    let priority: Int
    let queries: [String]
}

struct SearchConfig: Codable {
    let defaultLimit: Int
    let boostPriority0: Double
    let boostTitleMatch: Double
    
    enum CodingKeys: String, CodingKey {
        case defaultLimit = "default_limit"
        case boostPriority0 = "boost_priority_0"
        case boostTitleMatch = "boost_title_match"
    }
}

// MARK: - Article Models

struct Article: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let category: String
    let priority: Int
    let timeCritical: String?
    let searchText: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, category, priority
        case timeCritical = "time_critical"
        case searchText = "search_text"
    }
}

// MARK: - Content Bundle

struct ContentBundle {
    let manifest: ContentManifest
    let location: ContentLocation
    let isAvailable: Bool
}

enum ContentLocation {
    case bundled           // In app bundle
    case documents         // In app documents
    case appGroup          // In shared app group
    case external(URL)     // External storage
    case onDemandResource  // Apple ODR
}

// MARK: - Search Results

struct SearchResult {
    let article: Article
    let score: Float
    let snippet: String?
}
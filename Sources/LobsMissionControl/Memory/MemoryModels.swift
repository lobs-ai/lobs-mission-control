import Foundation

// MARK: - Memory Item

struct MemoryItem: Codable, Identifiable {
    let id: Int
    let path: String
    let agent: String
    let title: String
    let memoryType: String  // "long_term", "daily", "custom"
    let date: Date?
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case agent
        case title
        case memoryType = "memory_type"
        case date
        case updatedAt = "updated_at"
    }
    
    var typeBadgeColor: NSColor {
        switch memoryType {
        case "long_term": return .systemPurple
        case "daily": return .systemBlue
        case "custom": return .systemGreen
        default: return .systemGray
        }
    }
    
    var typeBadgeIcon: String {
        switch memoryType {
        case "long_term": return "brain.head.profile"
        case "daily": return "calendar"
        case "custom": return "doc.text"
        default: return "doc"
        }
    }
    
    var agentBadgeColor: NSColor {
        switch agent {
        case "main": return .systemBlue
        case "programmer": return .systemPurple
        case "writer": return .systemGreen
        case "researcher": return .systemOrange
        case "reviewer": return .systemPink
        case "architect": return .systemTeal
        default: return .systemGray
        }
    }
    
    var displayTitle: String {
        if memoryType == "long_term" {
            return "🧠 \(title)"
        }
        return title
    }
}

// MARK: - Memory Detail

struct MemoryDetail: Codable, Identifiable {
    let id: Int
    let path: String
    let agent: String
    let title: String
    let content: String
    let memoryType: String
    let date: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case agent
        case title
        case content
        case memoryType = "memory_type"
        case date
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Memory Search Result

struct MemorySearchResult: Codable, Identifiable {
    let id: Int
    let path: String
    let agent: String
    let title: String
    let snippet: String
    let memoryType: String
    let date: Date?
    let score: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case agent
        case title
        case snippet
        case memoryType = "memory_type"
        case date
        case score
    }
}

// MARK: - Agent Memory Info

struct AgentMemoryInfo: Codable, Identifiable {
    let agent: String
    let memoryCount: Int
    let lastUpdated: String?
    
    var id: String { agent }
    
    enum CodingKeys: String, CodingKey {
        case agent
        case memoryCount = "memory_count"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Sync Result

struct SyncResult: Codable {
    let new: Int
    let updated: Int
    let unchanged: Int
    let errors: [String]
}

#if os(macOS)
import AppKit
#else
import UIKit
#endif

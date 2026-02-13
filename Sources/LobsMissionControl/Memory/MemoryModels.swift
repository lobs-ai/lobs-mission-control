import Foundation

// MARK: - Memory Item

struct MemoryItem: Codable, Identifiable {
    let id: Int
    let path: String
    let title: String
    let memoryType: String  // "long_term", "daily", "custom"
    let date: Date?
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
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
    let title: String
    let content: String
    let memoryType: String
    let date: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
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
    let title: String
    let snippet: String
    let memoryType: String
    let date: Date?
    let score: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case title
        case snippet
        case memoryType = "memory_type"
        case date
        case score
    }
}

#if os(macOS)
import AppKit
#else
import UIKit
#endif

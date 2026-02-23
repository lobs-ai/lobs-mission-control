import Foundation

// MARK: - Knowledge Entry

struct KnowledgeEntry: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let path: String
    let title: String
    let type: KnowledgeType
    let tags: [String]
    let summary: String?
    let createdBy: String?
    let isCollection: Bool
    let parentPath: String?
    let contentHash: String
    let fileCreatedAt: Date
    let fileUpdatedAt: Date
    let indexedAt: Date
    
    var icon: String {
        type.icon
    }
    
    var displayType: String {
        type.displayName
    }
}

// MARK: - Knowledge Type

enum KnowledgeType: String, Codable, CaseIterable {
    case research
    case doc
    case design
    case decision
    
    var displayName: String {
        switch self {
        case .research: return "Research"
        case .doc: return "Doc"
        case .design: return "Design"
        case .decision: return "Decision"
        }
    }
    
    var icon: String {
        switch self {
        case .research: return "magnifyingglass.circle.fill"
        case .doc: return "doc.text.fill"
        case .design: return "paintbrush.fill"
        case .decision: return "checkmark.seal.fill"
        }
    }
    
    var badgeColor: String {
        switch self {
        case .research: return "blue"
        case .doc: return "green"
        case .design: return "purple"
        case .decision: return "orange"
        }
    }
}

// MARK: - Knowledge Browse Response

struct KnowledgeBrowseResponse: Codable {
    let entries: [KnowledgeEntry]
    let path: String?
    let total: Int
}

// MARK: - Knowledge Feed Response

struct KnowledgeFeedResponse: Codable {
    let entries: [KnowledgeEntry]
    let total: Int
}

// MARK: - Knowledge Content Response

struct KnowledgeContentResponse: Codable {
    let path: String
    let content: String
}

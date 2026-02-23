import XCTest
@testable import LobsMissionControl

final class KnowledgeTests: XCTestCase {
    
    // MARK: - Knowledge Type Tests
    
    func testKnowledgeTypeDisplayNames() {
        XCTAssertEqual(KnowledgeType.research.displayName, "Research")
        XCTAssertEqual(KnowledgeType.doc.displayName, "Doc")
        XCTAssertEqual(KnowledgeType.design.displayName, "Design")
        XCTAssertEqual(KnowledgeType.decision.displayName, "Decision")
    }
    
    func testKnowledgeTypeIcons() {
        XCTAssertEqual(KnowledgeType.research.icon, "magnifyingglass.circle.fill")
        XCTAssertEqual(KnowledgeType.doc.icon, "doc.text.fill")
        XCTAssertEqual(KnowledgeType.design.icon, "paintbrush.fill")
        XCTAssertEqual(KnowledgeType.decision.icon, "checkmark.seal.fill")
    }
    
    func testKnowledgeTypeBadgeColors() {
        XCTAssertEqual(KnowledgeType.research.badgeColor, "blue")
        XCTAssertEqual(KnowledgeType.doc.badgeColor, "green")
        XCTAssertEqual(KnowledgeType.design.badgeColor, "purple")
        XCTAssertEqual(KnowledgeType.decision.badgeColor, "orange")
    }
    
    func testKnowledgeTypeCodable() throws {
        let research = KnowledgeType.research
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(research)
        let decoded = try decoder.decode(KnowledgeType.self, from: data)
        
        XCTAssertEqual(decoded, research)
    }
    
    // MARK: - Knowledge Entry Tests
    
    func testKnowledgeEntryDecoding() throws {
        let json = """
        {
            "id": "entry-1",
            "path": "research/agent-patterns/README.md",
            "title": "Multi-Agent Patterns",
            "type": "research",
            "tags": ["agents", "architecture"],
            "summary": "Comparison of agent patterns",
            "created_by": "researcher",
            "is_collection": true,
            "parent_path": "research/",
            "content_hash": "abc123",
            "file_created_at": "2024-01-01T00:00:00Z",
            "file_updated_at": "2024-01-15T12:00:00Z",
            "indexed_at": "2024-01-15T12:05:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        let entry = try decoder.decode(KnowledgeEntry.self, from: json)
        
        XCTAssertEqual(entry.id, "entry-1")
        XCTAssertEqual(entry.path, "research/agent-patterns/README.md")
        XCTAssertEqual(entry.title, "Multi-Agent Patterns")
        XCTAssertEqual(entry.type, .research)
        XCTAssertEqual(entry.tags, ["agents", "architecture"])
        XCTAssertEqual(entry.summary, "Comparison of agent patterns")
        XCTAssertEqual(entry.createdBy, "researcher")
        XCTAssertTrue(entry.isCollection)
        XCTAssertEqual(entry.parentPath, "research/")
        XCTAssertEqual(entry.contentHash, "abc123")
    }
    
    func testKnowledgeEntryIcon() {
        let researchEntry = KnowledgeEntry(
            id: "1",
            path: "research/test",
            title: "Test",
            type: .research,
            tags: [],
            summary: nil,
            createdBy: nil,
            isCollection: false,
            parentPath: nil,
            contentHash: "hash",
            fileCreatedAt: Date(),
            fileUpdatedAt: Date(),
            indexedAt: Date()
        )
        
        XCTAssertEqual(researchEntry.icon, "magnifyingglass.circle.fill")
    }
    
    func testKnowledgeEntryDisplayType() {
        let docEntry = KnowledgeEntry(
            id: "1",
            path: "docs/test",
            title: "Test",
            type: .doc,
            tags: [],
            summary: nil,
            createdBy: nil,
            isCollection: false,
            parentPath: nil,
            contentHash: "hash",
            fileCreatedAt: Date(),
            fileUpdatedAt: Date(),
            indexedAt: Date()
        )
        
        XCTAssertEqual(docEntry.displayType, "Doc")
    }
    
    // MARK: - Response Model Tests
    
    func testKnowledgeFeedResponseDecoding() throws {
        let json = """
        {
            "entries": [
                {
                    "id": "entry-1",
                    "path": "research/test/README.md",
                    "title": "Test",
                    "type": "research",
                    "tags": [],
                    "summary": null,
                    "created_by": null,
                    "is_collection": true,
                    "parent_path": null,
                    "content_hash": "hash",
                    "file_created_at": "2024-01-01T00:00:00Z",
                    "file_updated_at": "2024-01-01T00:00:00Z",
                    "indexed_at": "2024-01-01T00:00:00Z"
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(KnowledgeFeedResponse.self, from: json)
        
        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.entries.count, 1)
        XCTAssertEqual(response.entries[0].id, "entry-1")
    }
    
    func testKnowledgeBrowseResponseDecoding() throws {
        let json = """
        {
            "entries": [],
            "path": "research/",
            "total": 0
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(KnowledgeBrowseResponse.self, from: json)
        
        XCTAssertEqual(response.path, "research/")
        XCTAssertEqual(response.total, 0)
        XCTAssertTrue(response.entries.isEmpty)
    }
    
    func testKnowledgeContentResponseDecoding() throws {
        let json = """
        {
            "path": "research/test.md",
            "content": "# Test\\n\\nThis is test content."
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(KnowledgeContentResponse.self, from: json)
        
        XCTAssertEqual(response.path, "research/test.md")
        XCTAssertEqual(response.content, "# Test\n\nThis is test content.")
    }
    
    // MARK: - Edge Cases
    
    func testKnowledgeEntryWithEmptyTags() throws {
        let json = """
        {
            "id": "entry-1",
            "path": "test.md",
            "title": "Test",
            "type": "doc",
            "tags": [],
            "summary": null,
            "created_by": null,
            "is_collection": false,
            "parent_path": null,
            "content_hash": "hash",
            "file_created_at": "2024-01-01T00:00:00Z",
            "file_updated_at": "2024-01-01T00:00:00Z",
            "indexed_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        let entry = try decoder.decode(KnowledgeEntry.self, from: json)
        
        XCTAssertTrue(entry.tags.isEmpty)
        XCTAssertNil(entry.summary)
        XCTAssertNil(entry.createdBy)
    }
    
    func testKnowledgeEntryEquality() {
        let date1 = Date()
        let date2 = date1
        
        let entry1 = KnowledgeEntry(
            id: "1",
            path: "test.md",
            title: "Test",
            type: .doc,
            tags: ["test"],
            summary: "Summary",
            createdBy: "author",
            isCollection: false,
            parentPath: nil,
            contentHash: "hash",
            fileCreatedAt: date1,
            fileUpdatedAt: date1,
            indexedAt: date1
        )
        
        let entry2 = KnowledgeEntry(
            id: "1",
            path: "test.md",
            title: "Test",
            type: .doc,
            tags: ["test"],
            summary: "Summary",
            createdBy: "author",
            isCollection: false,
            parentPath: nil,
            contentHash: "hash",
            fileCreatedAt: date2,
            fileUpdatedAt: date2,
            indexedAt: date2
        )
        
        XCTAssertEqual(entry1, entry2)
    }
    
    func testKnowledgeEntryHashable() {
        let entry1 = KnowledgeEntry(
            id: "1",
            path: "test.md",
            title: "Test",
            type: .doc,
            tags: [],
            summary: nil,
            createdBy: nil,
            isCollection: false,
            parentPath: nil,
            contentHash: "hash",
            fileCreatedAt: Date(),
            fileUpdatedAt: Date(),
            indexedAt: Date()
        )
        
        let entry2 = KnowledgeEntry(
            id: "2",
            path: "test2.md",
            title: "Test 2",
            type: .research,
            tags: [],
            summary: nil,
            createdBy: nil,
            isCollection: false,
            parentPath: nil,
            contentHash: "hash2",
            fileCreatedAt: Date(),
            fileUpdatedAt: Date(),
            indexedAt: Date()
        )
        
        var set = Set<KnowledgeEntry>()
        set.insert(entry1)
        set.insert(entry2)
        
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(entry1))
        XCTAssertTrue(set.contains(entry2))
    }
}

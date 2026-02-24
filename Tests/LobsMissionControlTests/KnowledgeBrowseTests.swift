import XCTest
@testable import LobsMissionControl

/// Tests for knowledge browse view topic grouping functionality.
final class KnowledgeBrowseTests: XCTestCase {
    
    // MARK: - Topic Extraction Tests
    
    func testExtractTopicFromResearchPath() {
        let path = "research/ai-agents/implementation.md"
        let expectedTopic = "ai-agents"
        
        // We need to extract the topic from the path
        let components = path.split(separator: "/").map(String.init)
        let topic = components.count >= 2 ? components[1] : "Other"
        
        XCTAssertEqual(topic, expectedTopic, "Should extract topic from research path")
    }
    
    func testExtractTopicFromNestedPath() {
        let path = "research/task-management/guides/setup.md"
        let expectedTopic = "task-management"
        
        let components = path.split(separator: "/").map(String.init)
        let topic = components.count >= 2 ? components[1] : "Other"
        
        XCTAssertEqual(topic, expectedTopic, "Should extract topic from deeply nested path")
    }
    
    func testExtractTopicFromShortPath() {
        let path = "tools/cli.md"
        let expectedTopic = "tools"
        
        let components = path.split(separator: "/").map(String.init)
        let topic = components.count >= 2 ? components[1] : (components.count >= 1 ? components[0] : "Other")
        
        XCTAssertEqual(topic, expectedTopic, "Should extract topic from short path")
    }
    
    func testExtractTopicFromSingleFile() {
        let path = "README.md"
        let expectedTopic = "README.md"
        
        let components = path.split(separator: "/").map(String.init)
        let topic = components.count >= 2 ? components[1] : (components.count >= 1 ? components[0] : "Other")
        
        XCTAssertEqual(topic, expectedTopic, "Should handle single file path")
    }
    
    // MARK: - Topic Name Formatting Tests
    
    func testFormatTopicNameWithHyphens() {
        let topic = "ai-agents"
        let expected = "Ai Agents"
        
        let formatted = formatTopicName(topic)
        
        XCTAssertEqual(formatted, expected, "Should format hyphenated topic names")
    }
    
    func testFormatTopicNameWithUnderscores() {
        let topic = "task_management"
        let expected = "Task Management"
        
        let formatted = formatTopicName(topic)
        
        XCTAssertEqual(formatted, expected, "Should format underscored topic names")
    }
    
    func testFormatTopicNameMixed() {
        let topic = "ai_ml-research"
        let expected = "Ai Ml Research"
        
        let formatted = formatTopicName(topic)
        
        XCTAssertEqual(formatted, expected, "Should format mixed separator topic names")
    }
    
    func testFormatTopicNameSingleWord() {
        let topic = "tools"
        let expected = "Tools"
        
        let formatted = formatTopicName(topic)
        
        XCTAssertEqual(formatted, expected, "Should capitalize single word topics")
    }
    
    // MARK: - Entry Grouping Tests
    
    func testGroupEntriesByTopic() {
        let entries = [
            createMockEntry(path: "research/ai-agents/doc1.md", title: "Doc 1"),
            createMockEntry(path: "research/ai-agents/doc2.md", title: "Doc 2"),
            createMockEntry(path: "research/task-management/doc3.md", title: "Doc 3"),
            createMockEntry(path: "design/ui/wireframes.md", title: "Wireframes"),
        ]
        
        let groupedByTopic = Dictionary(grouping: entries) { entry in
            extractTopic(from: entry.path)
        }
        
        XCTAssertEqual(groupedByTopic.keys.count, 3, "Should have 3 unique topics")
        XCTAssertEqual(groupedByTopic["ai-agents"]?.count, 2, "Should have 2 entries in ai-agents topic")
        XCTAssertEqual(groupedByTopic["task-management"]?.count, 1, "Should have 1 entry in task-management topic")
        XCTAssertEqual(groupedByTopic["ui"]?.count, 1, "Should have 1 entry in ui topic")
    }
    
    func testSortTopicsAlphabetically() {
        let topics = ["zebra", "alpha", "beta", "charlie"]
        let sorted = topics.sorted()
        
        XCTAssertEqual(sorted, ["alpha", "beta", "charlie", "zebra"], "Topics should be sorted alphabetically")
    }
    
    // MARK: - Helper Functions (mirroring KnowledgeBrowseView logic)
    
    private func extractTopic(from path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        
        // If path is like "research/<topic>/<file>", extract the topic
        if components.count >= 2 {
            // Skip first component (research/design/etc) and get second
            return components[1]
        }
        
        // If path is like "<topic>/<file>", use first component
        if components.count >= 1 {
            return components[0]
        }
        
        return "Other"
    }
    
    private func formatTopicName(_ topic: String) -> String {
        topic
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
    
    private func createMockEntry(path: String, title: String, isCollection: Bool = false) -> KnowledgeEntry {
        KnowledgeEntry(
            id: UUID().uuidString,
            path: path,
            title: title,
            type: .research,
            tags: [],
            summary: nil,
            createdBy: nil,
            isCollection: isCollection,
            parentPath: nil,
            contentHash: "abc123",
            fileCreatedAt: Date(),
            fileUpdatedAt: Date(),
            indexedAt: Date()
        )
    }
}

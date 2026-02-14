import XCTest
@testable import LobsMissionControl

/// Tests for AgentDocument JSON decoding with missing client-side fields
///
/// This test suite validates:
/// - Documents can be decoded from server JSON without isRead/isStarred
/// - Default values are applied for missing client-side fields
/// - All server fields are properly decoded
/// - Custom init(from:) handles optional fields correctly
final class AgentDocumentDecodingTests: XCTestCase {
  
  // MARK: - Decoding With Missing Client Fields
  
  func testDecodeDocumentWithoutIsReadField() throws {
    // Server JSON doesn't include isRead (client-side only)
    let json = """
    {
      "id": "test-doc-1",
      "title": "Test Document",
      "filename": "test.md",
      "relative_path": "reports/test.md",
      "content": "Test content",
      "content_is_truncated": false,
      "source": "writer",
      "date": "2024-01-01T12:00:00Z"
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    // Should decode successfully with default value
    XCTAssertEqual(document.id, "test-doc-1")
    XCTAssertEqual(document.title, "Test Document")
    XCTAssertFalse(document.isRead, "isRead should default to false when missing")
  }
  
  func testDecodeDocumentWithoutIsStarredField() throws {
    // Server JSON doesn't include isStarred (client-side only)
    let json = """
    {
      "id": "test-doc-2",
      "title": "Another Document",
      "filename": "another.md",
      "relative_path": "research/topic/another.md",
      "content": "Research content",
      "content_is_truncated": false,
      "source": "researcher",
      "date": "2024-01-02T12:00:00Z"
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    // Should decode successfully with default value
    XCTAssertEqual(document.id, "test-doc-2")
    XCTAssertFalse(document.isStarred, "isStarred should default to false when missing")
  }
  
  func testDecodeDocumentWithBothClientFieldsMissing() throws {
    // Typical server response without any client-side fields
    let json = """
    {
      "id": "test-doc-3",
      "title": "Typical Server Response",
      "filename": "typical.md",
      "relative_path": "reports/pending/typical.md",
      "content": "This is what the server actually sends",
      "content_is_truncated": false,
      "source": "writer",
      "status": "pending",
      "project_id": "project-123",
      "task_id": "task-456",
      "date": "2024-01-03T12:00:00Z",
      "summary": "A summary of the document"
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    // All server fields should decode correctly
    XCTAssertEqual(document.id, "test-doc-3")
    XCTAssertEqual(document.title, "Typical Server Response")
    XCTAssertEqual(document.source, .writer)
    XCTAssertEqual(document.status, .pending)
    XCTAssertEqual(document.projectId, "project-123")
    XCTAssertEqual(document.taskId, "task-456")
    XCTAssertEqual(document.summary, "A summary of the document")
    
    // Client fields should have defaults
    XCTAssertFalse(document.isRead)
    XCTAssertFalse(document.isStarred)
  }
  
  // MARK: - Decoding With Client Fields Present
  
  func testDecodeDocumentWithIsReadTrue() throws {
    // If server somehow sends isRead, it should be respected
    let json = """
    {
      "id": "test-doc-4",
      "title": "Document With IsRead",
      "filename": "with-read.md",
      "relative_path": "reports/with-read.md",
      "content": "Content",
      "content_is_truncated": false,
      "source": "writer",
      "date": "2024-01-04T12:00:00Z",
      "is_read": true
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    XCTAssertTrue(document.isRead, "isRead should be true when provided")
  }
  
  func testDecodeDocumentWithIsStarredTrue() throws {
    // If server somehow sends isStarred, it should be respected
    let json = """
    {
      "id": "test-doc-5",
      "title": "Document With IsStarred",
      "filename": "starred.md",
      "relative_path": "reports/starred.md",
      "content": "Content",
      "content_is_truncated": false,
      "source": "writer",
      "date": "2024-01-05T12:00:00Z",
      "is_starred": true
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    XCTAssertTrue(document.isStarred, "isStarred should be true when provided")
  }
  
  // MARK: - Optional Fields
  
  func testDecodeDocumentWithOptionalFieldsMissing() throws {
    // Minimal document with only required fields
    let json = """
    {
      "id": "test-doc-6",
      "title": "Minimal Document",
      "filename": "minimal.md",
      "relative_path": "reports/minimal.md",
      "content": "Minimal content",
      "content_is_truncated": false,
      "source": "researcher",
      "date": "2024-01-06T12:00:00Z"
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    // Optional fields should be nil
    XCTAssertNil(document.status)
    XCTAssertNil(document.topic)
    XCTAssertNil(document.topicId)
    XCTAssertNil(document.projectId)
    XCTAssertNil(document.taskId)
    XCTAssertNil(document.summary)
  }
  
  func testDecodeDocumentWithAllOptionalFieldsPresent() throws {
    // Document with all optional fields
    let json = """
    {
      "id": "test-doc-7",
      "title": "Complete Document",
      "filename": "complete.md",
      "relative_path": "research/ai/complete.md",
      "content": "Complete content",
      "content_is_truncated": true,
      "source": "researcher",
      "status": "approved",
      "topic": "ai",
      "topic_id": "topic-123",
      "project_id": "project-789",
      "task_id": "task-101",
      "date": "2024-01-07T12:00:00Z",
      "summary": "Complete summary"
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    // All optional fields should be present
    XCTAssertEqual(document.status, .approved)
    XCTAssertEqual(document.topic, "ai")
    XCTAssertEqual(document.topicId, "topic-123")
    XCTAssertEqual(document.projectId, "project-789")
    XCTAssertEqual(document.taskId, "task-101")
    XCTAssertEqual(document.summary, "Complete summary")
    XCTAssertTrue(document.contentIsTruncated)
  }
  
  // MARK: - Array Decoding
  
  func testDecodeMultipleDocumentsWithoutClientFields() throws {
    // Array of documents as returned by /api/documents endpoint
    let json = """
    [
      {
        "id": "doc-1",
        "title": "First Document",
        "filename": "first.md",
        "relative_path": "reports/first.md",
        "content": "First content",
        "content_is_truncated": false,
        "source": "writer",
        "date": "2024-01-01T12:00:00Z"
      },
      {
        "id": "doc-2",
        "title": "Second Document",
        "filename": "second.md",
        "relative_path": "research/topic/second.md",
        "content": "Second content",
        "content_is_truncated": false,
        "source": "researcher",
        "date": "2024-01-02T12:00:00Z"
      }
    ]
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let documents = try decoder.decode([AgentDocument].self, from: data)
    
    XCTAssertEqual(documents.count, 2)
    XCTAssertEqual(documents[0].id, "doc-1")
    XCTAssertEqual(documents[1].id, "doc-2")
    XCTAssertFalse(documents[0].isRead)
    XCTAssertFalse(documents[0].isStarred)
    XCTAssertFalse(documents[1].isRead)
    XCTAssertFalse(documents[1].isStarred)
  }
  
  // MARK: - DocumentSource Decoding
  
  func testDecodeWriterSource() throws {
    let json = """
    {
      "id": "test-doc-8",
      "title": "Writer Document",
      "filename": "writer.md",
      "relative_path": "reports/writer.md",
      "content": "Content",
      "content_is_truncated": false,
      "source": "writer",
      "date": "2024-01-08T12:00:00Z"
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    XCTAssertEqual(document.source, .writer)
  }
  
  func testDecodeResearcherSource() throws {
    let json = """
    {
      "id": "test-doc-9",
      "title": "Researcher Document",
      "filename": "researcher.md",
      "relative_path": "research/topic/researcher.md",
      "content": "Content",
      "content_is_truncated": false,
      "source": "researcher",
      "date": "2024-01-09T12:00:00Z"
    }
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let document = try decoder.decode(AgentDocument.self, from: data)
    
    XCTAssertEqual(document.source, .researcher)
  }
  
  // MARK: - DocumentStatus Decoding
  
  func testDecodeAllDocumentStatuses() throws {
    let statuses: [DocumentStatus] = [.pending, .approved, .rejected]
    
    for status in statuses {
      let json = """
      {
        "id": "test-\(status.rawValue)",
        "title": "Document",
        "filename": "doc.md",
        "relative_path": "reports/doc.md",
        "content": "Content",
        "content_is_truncated": false,
        "source": "writer",
        "status": "\(status.rawValue)",
        "date": "2024-01-10T12:00:00Z"
      }
      """
      
      let data = json.data(using: .utf8)!
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      decoder.dateDecodingStrategy = .iso8601
      
      let document = try decoder.decode(AgentDocument.self, from: data)
      
      XCTAssertEqual(document.status, status, "Status \(status.rawValue) should decode correctly")
    }
  }
  
  // MARK: - Integration Test
  
  func testDecodeRealWorldServerResponse() throws {
    // Simulate actual server response from /api/documents endpoint
    let json = """
    [
      {
        "id": "reports/pending/feature-spec.md",
        "title": "Feature Specification",
        "filename": "feature-spec.md",
        "relative_path": "reports/pending/feature-spec.md",
        "content": "# Feature Spec\\n\\nThis document describes...",
        "content_is_truncated": false,
        "source": "writer",
        "status": "pending",
        "project_id": "lobs-dashboard",
        "task_id": "task-abc123",
        "date": "2024-01-15T14:30:00Z",
        "summary": "Specification for new dashboard feature"
      },
      {
        "id": "research/ai-agents/llm-comparison.md",
        "title": "LLM Model Comparison",
        "filename": "llm-comparison.md",
        "relative_path": "research/ai-agents/llm-comparison.md",
        "content": "# LLM Comparison\\n\\nThis research compares...",
        "content_is_truncated": true,
        "source": "researcher",
        "topic": "ai-agents",
        "topic_id": "topic-ai-001",
        "date": "2024-01-16T09:15:00Z",
        "summary": "Comparative analysis of GPT-4, Claude, and Gemini"
      }
    ]
    """
    
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    // This should not throw - the fix allows decoding without isRead/isStarred
    let documents = try decoder.decode([AgentDocument].self, from: data)
    
    XCTAssertEqual(documents.count, 2)
    
    // First document (report)
    XCTAssertEqual(documents[0].id, "reports/pending/feature-spec.md")
    XCTAssertEqual(documents[0].source, .writer)
    XCTAssertEqual(documents[0].status, .pending)
    XCTAssertFalse(documents[0].isRead)
    XCTAssertFalse(documents[0].isStarred)
    
    // Second document (research)
    XCTAssertEqual(documents[1].id, "research/ai-agents/llm-comparison.md")
    XCTAssertEqual(documents[1].source, .researcher)
    XCTAssertEqual(documents[1].topic, "ai-agents")
    XCTAssertEqual(documents[1].topicId, "topic-ai-001")
    XCTAssertFalse(documents[1].isRead)
    XCTAssertFalse(documents[1].isStarred)
  }
}

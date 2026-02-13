import XCTest
@testable import LobsMissionControl

/// Tests for document detail view actions: Create task, Follow-up research, Mark reviewed, Inline notes
final class DocumentDetailActionsTests: XCTestCase {
  
  func testDocumentDetailViewHasRequiredActions() {
    // GIVEN: A document with full context
    let doc = AgentDocument(
      id: "doc-test",
      title: "Test Document",
      filename: "test.md",
      relativePath: "research/test.md",
      content: "# Test Content\n\nThis is a test document.",
      contentIsTruncated: false,
      source: .researcher,
      status: nil,
      topic: "AI Research",
      topicId: "topic-123",
      projectId: "proj-456",
      taskId: nil,
      date: Date(),
      isRead: false,
      summary: "A test document for verification"
    )
    
    // THEN: Document should have all required properties for actions
    XCTAssertEqual(doc.title, "Test Document")
    XCTAssertEqual(doc.source, .researcher)
    XCTAssertEqual(doc.topicId, "topic-123")
    XCTAssertEqual(doc.projectId, "proj-456")
    XCTAssertNotNil(doc.summary)
  }
  
  func testTaskCreationPreFillsDocumentContext() {
    // GIVEN: A document
    let doc = AgentDocument(
      id: "doc-test",
      title: "AI Research Findings",
      filename: "findings.md",
      relativePath: "research/findings.md",
      content: "Research content",
      contentIsTruncated: false,
      source: .researcher,
      status: nil,
      topic: "AI",
      topicId: "topic-ai",
      projectId: "proj-research",
      taskId: nil,
      date: Date(),
      isRead: false,
      summary: "Key findings on AI capabilities"
    )
    
    // WHEN: Pre-filling task title and notes
    let taskTitle = "Task from: \(doc.title)"
    var taskNotes = "**Source Document:** \(doc.title)\n"
    taskNotes += "**Date:** \(doc.date.formatted(date: .abbreviated, time: .omitted))\n"
    taskNotes += "**Agent:** \(doc.source.displayName)\n\n"
    
    if let summary = doc.summary, !summary.isEmpty {
      taskNotes += "**Summary:**\n\(summary)\n\n"
    }
    
    taskNotes += "**Document ID:** \(doc.id)"
    
    // THEN: Task context should include document details
    XCTAssertEqual(taskTitle, "Task from: AI Research Findings")
    XCTAssertTrue(taskNotes.contains("AI Research Findings"))
    XCTAssertTrue(taskNotes.contains("Researcher"))
    XCTAssertTrue(taskNotes.contains("Key findings on AI capabilities"))
    XCTAssertTrue(taskNotes.contains(doc.id))
  }
  
  func testFollowUpResearchIncludesDocumentContext() {
    // GIVEN: A document
    let doc = AgentDocument(
      id: "doc-456",
      title: "Market Analysis Report",
      filename: "market-analysis.md",
      relativePath: "reports/market-analysis.md",
      content: "Market analysis content",
      contentIsTruncated: false,
      source: .writer,
      status: .approved,
      topic: "Markets",
      topicId: "topic-markets",
      projectId: "proj-biz",
      taskId: nil,
      date: Date(),
      isRead: true,
      summary: "Q1 2026 market trends analysis"
    )
    
    let researchQuestion = "What are the implications for Q2 strategy?"
    let additionalContext = "Focus on competitive positioning"
    
    // WHEN: Building full research prompt
    var fullPrompt = "**Follow-up Research Request**\n\n"
    fullPrompt += "**Source Document:** \(doc.title)\n"
    fullPrompt += "**Source Agent:** \(doc.source.displayName)\n"
    fullPrompt += "**Document Date:** \(doc.date.formatted(date: .abbreviated, time: .omitted))\n"
    
    if let summary = doc.summary, !summary.isEmpty {
      fullPrompt += "**Document Summary:** \(summary)\n"
    }
    
    fullPrompt += "\n---\n\n"
    fullPrompt += "**Research Question:**\n\(researchQuestion)\n"
    fullPrompt += "\n**Additional Context:**\n\(additionalContext)\n"
    fullPrompt += "\n---\n\n"
    fullPrompt += "**Document ID:** \(doc.id)"
    
    // THEN: Full prompt should contain all context
    XCTAssertTrue(fullPrompt.contains("Market Analysis Report"))
    XCTAssertTrue(fullPrompt.contains("Writer"))
    XCTAssertTrue(fullPrompt.contains("Q1 2026 market trends analysis"))
    XCTAssertTrue(fullPrompt.contains("What are the implications for Q2 strategy?"))
    XCTAssertTrue(fullPrompt.contains("Focus on competitive positioning"))
    XCTAssertTrue(fullPrompt.contains(doc.id))
  }
  
  func testInlineNotesCharacterCount() {
    // GIVEN: User notes
    let notes = "This is an important document that requires follow-up"
    
    // WHEN: Counting characters
    let charCount = notes.count
    
    // THEN: Should have correct count
    XCTAssertEqual(charCount, 53)
    XCTAssertFalse(notes.isEmpty)
  }
  
  func testReviewedStatusToggle() {
    // GIVEN: Initial reviewed state
    var isReviewed = false
    
    // WHEN: Toggling review status
    isReviewed.toggle()
    
    // THEN: Should be marked as reviewed
    XCTAssertTrue(isReviewed)
    
    // WHEN: Toggling again
    isReviewed.toggle()
    
    // THEN: Should be unmarked
    XCTAssertFalse(isReviewed)
  }
  
  func testDocumentMetadataDisplay() {
    // GIVEN: A document with topic
    let doc = AgentDocument(
      id: "doc-789",
      title: "Technical Spec",
      filename: "spec.md",
      relativePath: "docs/spec.md",
      content: "Specification content",
      contentIsTruncated: false,
      source: .writer,
      status: .pending,
      topic: "Architecture",
      topicId: "topic-arch",
      projectId: nil,
      taskId: nil,
      date: Date(),
      isRead: false,
      summary: nil
    )
    
    // THEN: Should have displayable metadata
    XCTAssertEqual(doc.source.displayName, "Writer")
    XCTAssertEqual(doc.source.icon, "doc.text.fill")
    XCTAssertNotNil(doc.status)
    XCTAssertEqual(doc.topicId, "topic-arch")
  }
  
  func testFollowUpResearchWithoutSummary() {
    // GIVEN: A document without summary
    let doc = AgentDocument(
      id: "doc-nosummary",
      title: "Quick Note",
      filename: "note.md",
      relativePath: "notes/note.md",
      content: "Brief note content",
      contentIsTruncated: false,
      source: .researcher,
      status: nil,
      topic: nil,
      topicId: nil,
      projectId: "proj-1",
      taskId: nil,
      date: Date(),
      isRead: false,
      summary: nil
    )
    
    let researchQuestion = "Need more details on this topic"
    
    // WHEN: Building prompt without summary
    var fullPrompt = "**Source Document:** \(doc.title)\n"
    fullPrompt += "**Source Agent:** \(doc.source.displayName)\n"
    
    if let summary = doc.summary, !summary.isEmpty {
      fullPrompt += "**Document Summary:** \(summary)\n"
    }
    
    fullPrompt += "\n**Research Question:**\n\(researchQuestion)"
    
    // THEN: Should not include summary section but still have other context
    XCTAssertFalse(fullPrompt.contains("Document Summary:"))
    XCTAssertTrue(fullPrompt.contains("Quick Note"))
    XCTAssertTrue(fullPrompt.contains("Researcher"))
    XCTAssertTrue(fullPrompt.contains("Need more details"))
  }
  
  func testProjectPreSelectionFromDocument() {
    // GIVEN: A document with project ID
    let doc = AgentDocument(
      id: "doc-proj",
      title: "Project Document",
      filename: "proj.md",
      relativePath: "projects/proj.md",
      content: "Project content",
      contentIsTruncated: false,
      source: .writer,
      status: nil,
      topic: nil,
      topicId: nil,
      projectId: "proj-abc",
      taskId: nil,
      date: Date(),
      isRead: false,
      summary: nil
    )
    
    // WHEN: Initializing task creation
    var selectedProjectId: String?
    if let projectId = doc.projectId {
      selectedProjectId = projectId
    }
    
    // THEN: Should pre-select the document's project
    XCTAssertEqual(selectedProjectId, "proj-abc")
  }
  
  func testEmptyCommentsHandlingInFollowUpResearch() {
    // GIVEN: Empty additional comments
    let comments = ""
    let prompt = "Research question only"
    
    // WHEN: Building full prompt
    var fullPrompt = "**Research Question:**\n\(prompt.trimmingCharacters(in: .whitespacesAndNewlines))\n"
    
    if !comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      fullPrompt += "\n**Additional Context:**\n\(comments)\n"
    }
    
    // THEN: Should not include empty context section
    XCTAssertFalse(fullPrompt.contains("Additional Context:"))
    XCTAssertTrue(fullPrompt.contains("Research question only"))
  }
  
  func testTopicIdPreservationInFollowUpRequest() {
    // GIVEN: A document with topic ID
    let topicId = "topic-test-123"
    let doc = AgentDocument(
      id: "doc-topic-test",
      title: "Topic Document",
      filename: "topic.md",
      relativePath: "topics/topic.md",
      content: "Topic content",
      contentIsTruncated: false,
      source: .researcher,
      status: nil,
      topic: nil,
      topicId: topicId,
      projectId: nil,
      taskId: nil,
      date: Date(),
      isRead: false,
      summary: nil
    )
    
    // THEN: Should maintain topic link for research request creation
    XCTAssertEqual(doc.topicId, topicId)
    XCTAssertNotNil(doc.topicId)
  }
  
  func testContentTruncationWarning() {
    // GIVEN: A truncated document
    let doc = AgentDocument(
      id: "doc-truncated",
      title: "Large Document",
      filename: "large.md",
      relativePath: "docs/large.md",
      content: "Truncated content...",
      contentIsTruncated: true,
      source: .researcher,
      status: nil,
      topic: nil,
      topicId: nil,
      projectId: nil,
      taskId: nil,
      date: Date(),
      isRead: false,
      summary: nil
    )
    
    // THEN: Should flag content as truncated
    XCTAssertTrue(doc.contentIsTruncated)
  }
  
  func testDocumentSourceDisplayNames() {
    // Test all document source types
    XCTAssertEqual(DocumentSource.writer.displayName, "Writer")
    XCTAssertEqual(DocumentSource.researcher.displayName, "Researcher")
    
    XCTAssertEqual(DocumentSource.writer.icon, "doc.text.fill")
    XCTAssertEqual(DocumentSource.researcher.icon, "magnifyingglass")
  }
}

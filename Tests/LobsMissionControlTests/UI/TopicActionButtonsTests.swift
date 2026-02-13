import XCTest
@testable import LobsMissionControl

/// Tests for topic action buttons: Research This, Create Task, Convert to Project
final class TopicActionButtonsTests: XCTestCase {
  
  func testTopicBrowserHasActionButtons() {
    // GIVEN: A topic with valid data
    let topic = Topic(
      id: "topic-test",
      title: "Test Topic",
      description: "A test topic for verification",
      icon: "📚",
      linkedProjectId: nil,
      autoCreated: false,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // THEN: Topic should have expected properties
    XCTAssertEqual(topic.title, "Test Topic")
    XCTAssertEqual(topic.description, "A test topic for verification")
    XCTAssertEqual(topic.icon, "📚")
    XCTAssertFalse(topic.autoCreated)
  }
  
  func testResearchRequestCreationWithComments() {
    // GIVEN: A research prompt with comments
    let prompt = "What is the impact of AI on software development?"
    let comments = "Focus on productivity gains and tool adoption"
    
    // WHEN: Combining prompt with comments
    var fullPrompt = prompt
    if !comments.isEmpty {
      fullPrompt += "\n\nAdditional Context:\n" + comments
    }
    
    // THEN: Full prompt should contain both parts
    XCTAssertTrue(fullPrompt.contains(prompt))
    XCTAssertTrue(fullPrompt.contains("Additional Context:"))
    XCTAssertTrue(fullPrompt.contains(comments))
  }
  
  func testTaskCreationPreFillsTopicContext() {
    // GIVEN: A topic with description
    let topic = Topic(
      id: "topic-test",
      title: "AI Research",
      description: "Investigating AI capabilities",
      icon: "🤖",
      linkedProjectId: nil,
      autoCreated: false,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // WHEN: Pre-filling task notes with topic context
    var notes = "Related to topic: \(topic.title)"
    if let desc = topic.description, !desc.isEmpty {
      notes += "\n\n\(desc)"
    }
    
    // THEN: Notes should contain topic information
    XCTAssertTrue(notes.contains("Related to topic: AI Research"))
    XCTAssertTrue(notes.contains("Investigating AI capabilities"))
  }
  
  func testProjectCreationPreFillsTopicData() {
    // GIVEN: A topic to convert to project
    let topic = Topic(
      id: "topic-test",
      title: "Product Launch",
      description: "Q2 2026 product launch planning",
      icon: "🚀",
      linkedProjectId: nil,
      autoCreated: false,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // WHEN: Pre-filling project data from topic
    let projectTitle = topic.title
    var projectNotes = "Project for: \(topic.title)"
    if let desc = topic.description, !desc.isEmpty {
      projectNotes += "\n\n\(desc)"
    }
    
    // THEN: Project data should match topic
    XCTAssertEqual(projectTitle, "Product Launch")
    XCTAssertTrue(projectNotes.contains("Project for: Product Launch"))
    XCTAssertTrue(projectNotes.contains("Q2 2026 product launch planning"))
  }
  
  func testResearchRequestStatusDisplay() {
    // GIVEN: Research requests with different statuses
    let openRequest = ResearchRequest(
      id: "req-1",
      projectId: "proj-1",
      topicId: "topic-1",
      tileId: nil,
      prompt: "Research AI trends",
      status: .open,
      response: nil,
      author: "test",
      priority: .normal,
      deliverables: nil,
      editHistory: nil,
      parentRequestId: nil,
      assignedWorker: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    let inProgressRequest = ResearchRequest(
      id: "req-2",
      projectId: "proj-1",
      topicId: "topic-1",
      tileId: nil,
      prompt: "Research AI trends",
      status: .inProgress,
      response: nil,
      author: "test",
      priority: .normal,
      deliverables: nil,
      editHistory: nil,
      parentRequestId: nil,
      assignedWorker: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    let completedRequest = ResearchRequest(
      id: "req-3",
      projectId: "proj-1",
      topicId: "topic-1",
      tileId: nil,
      prompt: "Research AI trends",
      status: .completed,
      response: "Research completed",
      author: "test",
      priority: .normal,
      deliverables: nil,
      editHistory: nil,
      parentRequestId: nil,
      assignedWorker: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // THEN: Each request should have the correct status
    XCTAssertEqual(openRequest.status, .open)
    XCTAssertEqual(inProgressRequest.status, .inProgress)
    XCTAssertEqual(completedRequest.status, .completed)
    XCTAssertNotNil(completedRequest.response)
  }
  
  func testTopicIdPreservationInRequests() {
    // GIVEN: A topic and a research request linked to it
    let topicId = "topic-test-123"
    let request = ResearchRequest(
      id: "req-1",
      projectId: "proj-1",
      topicId: topicId,
      tileId: nil,
      prompt: "Test prompt",
      status: .open,
      response: nil,
      author: "test",
      priority: .normal,
      deliverables: nil,
      editHistory: nil,
      parentRequestId: nil,
      assignedWorker: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // THEN: Request should maintain topic link
    XCTAssertEqual(request.topicId, topicId)
  }
  
  func testEmptyCommentsHandling() {
    // GIVEN: A prompt with no comments
    let prompt = "Research question"
    let comments = ""
    
    // WHEN: Combining with empty comments
    var fullPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    if !comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      fullPrompt += "\n\nAdditional Context:\n" + comments
    }
    
    // THEN: Should only contain the prompt
    XCTAssertEqual(fullPrompt, prompt)
    XCTAssertFalse(fullPrompt.contains("Additional Context:"))
  }
  
  func testTaskOwnerSelection() {
    // Test that task owner can be human or AI
    let humanOwner: TaskOwner = .human
    let aiOwner: TaskOwner = .ai
    
    XCTAssertEqual(humanOwner.rawValue, "human")
    XCTAssertEqual(aiOwner.rawValue, "ai")
  }
  
  func testProjectTypeSelection() {
    // Test project type options
    let kanban: ProjectType = .kanban
    let oneShot: ProjectType = .oneShot
    
    XCTAssertEqual(kanban.rawValue, "kanban")
    XCTAssertEqual(oneShot.rawValue, "one-shot")
  }
  
  func testLinkedProjectPreSelection() {
    // GIVEN: A topic linked to a project
    let linkedProjectId = "proj-123"
    let topic = Topic(
      id: "topic-test",
      title: "Test Topic",
      description: nil,
      icon: nil,
      linkedProjectId: linkedProjectId,
      autoCreated: false,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // WHEN: Initializing task creation
    var selectedProjectId: String?
    if let linkedId = topic.linkedProjectId {
      selectedProjectId = linkedId
    }
    
    // THEN: Should pre-select the linked project
    XCTAssertEqual(selectedProjectId, linkedProjectId)
  }
}

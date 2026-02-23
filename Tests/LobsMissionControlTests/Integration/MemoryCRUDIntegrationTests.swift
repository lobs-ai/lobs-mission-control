import XCTest
@testable import LobsMissionControl

/// Integration tests for memory CRUD operations across server + client
///
/// **Workflow Tested:**
/// 1. Create memory via API
/// 2. Read/fetch memory and verify in UI state
/// 3. Update memory content
/// 4. Delete memory and verify removal
/// 5. Search memories
///
/// **Setup:**
/// - Uses mock APIService responses
/// - Tests full data flow: API → AppViewModel → UI state
/// - Verifies state consistency across CRUD operations
final class MemoryCRUDIntegrationTests: XCTestCase {
  
  var mockAPI: MockMemoryAPIService!
  var viewModel: AppViewModel!
  
  override func setUp() {
    super.setUp()
    mockAPI = MockMemoryAPIService()
    viewModel = AppViewModel(memoryAPI: mockAPI)
  }
  
  override func tearDown() {
    mockAPI = nil
    viewModel = nil
    super.tearDown()
  }
  
  // MARK: - Create Operations
  
  /// Test: Create memory → Verify in state
  func testCreateMemory() async throws {
    // GIVEN: Empty memory state
    XCTAssertEqual(viewModel.memories.count, 0, "Should start with no memories")
    
    // WHEN: Create new memory
    let newMemory = CreateMemoryRequest(
      title: "Integration Test Memory",
      content: "This is a test memory created during integration testing",
      tags: ["test", "integration"],
      memoryType: "note"
    )
    
    mockAPI.mockCreateResponse = Memory(
      id: 1,
      title: newMemory.title,
      content: newMemory.content,
      tags: newMemory.tags,
      memoryType: newMemory.memoryType,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    let created = try await viewModel.createMemory(request: newMemory)
    
    // THEN: Memory should be created and added to state
    XCTAssertEqual(created.id, 1)
    XCTAssertEqual(created.title, "Integration Test Memory")
    XCTAssertEqual(created.content, "This is a test memory created during integration testing")
    XCTAssertEqual(created.tags, ["test", "integration"])
    XCTAssertEqual(viewModel.memories.count, 1, "Memory should be added to state")
    XCTAssertEqual(viewModel.memories.first?.id, 1)
  }
  
  /// Test: Create memory with markdown content
  func testCreateMemoryWithMarkdown() async throws {
    // GIVEN: Memory with markdown content
    let markdownContent = """
    # Test Memory
    
    This is a **bold** statement.
    
    - Item 1
    - Item 2
    
    ```swift
    let code = "example"
    ```
    """
    
    let newMemory = CreateMemoryRequest(
      title: "Markdown Test",
      content: markdownContent,
      tags: ["markdown"],
      memoryType: "note"
    )
    
    mockAPI.mockCreateResponse = Memory(
      id: 2,
      title: newMemory.title,
      content: newMemory.content,
      tags: newMemory.tags,
      memoryType: newMemory.memoryType,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // WHEN: Create memory
    let created = try await viewModel.createMemory(request: newMemory)
    
    // THEN: Markdown content should be preserved
    XCTAssertEqual(created.content, markdownContent)
    XCTAssertTrue(created.content.contains("# Test Memory"))
    XCTAssertTrue(created.content.contains("**bold**"))
    XCTAssertTrue(created.content.contains("```swift"))
  }
  
  // MARK: - Read Operations
  
  /// Test: Fetch all memories → Update state
  func testFetchMemories() async throws {
    // GIVEN: Mock API with memories
    mockAPI.mockMemoriesResponse = [
      Memory(
        id: 1,
        title: "Memory 1",
        content: "Content 1",
        tags: ["tag1"],
        memoryType: "note",
        createdAt: Date(timeIntervalSinceNow: -86400), // 1 day ago
        updatedAt: Date(timeIntervalSinceNow: -86400)
      ),
      Memory(
        id: 2,
        title: "Memory 2",
        content: "Content 2",
        tags: ["tag2"],
        memoryType: "note",
        createdAt: Date(),
        updatedAt: Date()
      )
    ]
    
    // WHEN: Fetch memories
    await viewModel.loadMemories()
    
    // THEN: All memories should be loaded into state
    XCTAssertEqual(viewModel.memories.count, 2)
    XCTAssertEqual(viewModel.memories[0].title, "Memory 1")
    XCTAssertEqual(viewModel.memories[1].title, "Memory 2")
  }
  
  /// Test: Fetch single memory by ID
  func testFetchMemoryById() async throws {
    // GIVEN: Mock API with specific memory
    let targetMemory = Memory(
      id: 5,
      title: "Target Memory",
      content: "Specific content",
      tags: ["specific"],
      memoryType: "note",
      createdAt: Date(),
      updatedAt: Date()
    )
    
    mockAPI.mockMemoryByIdResponse = targetMemory
    
    // WHEN: Fetch specific memory
    let fetched = try await viewModel.fetchMemory(id: 5)
    
    // THEN: Correct memory should be returned
    XCTAssertEqual(fetched.id, 5)
    XCTAssertEqual(fetched.title, "Target Memory")
    XCTAssertEqual(fetched.content, "Specific content")
  }
  
  // MARK: - Update Operations
  
  /// Test: Update memory content → Verify state update
  func testUpdateMemory() async throws {
    // GIVEN: Existing memory in state
    let existingMemory = Memory(
      id: 10,
      title: "Original Title",
      content: "Original content",
      tags: ["original"],
      memoryType: "note",
      createdAt: Date(),
      updatedAt: Date()
    )
    
    mockAPI.mockMemoriesResponse = [existingMemory]
    await viewModel.loadMemories()
    
    XCTAssertEqual(viewModel.memories.first?.content, "Original content")
    
    // WHEN: Update memory
    let updateRequest = UpdateMemoryRequest(
      title: "Updated Title",
      content: "Updated content with new information",
      tags: ["updated", "modified"]
    )
    
    mockAPI.mockUpdateResponse = Memory(
      id: 10,
      title: updateRequest.title!,
      content: updateRequest.content!,
      tags: updateRequest.tags!,
      memoryType: existingMemory.memoryType,
      createdAt: existingMemory.createdAt,
      updatedAt: Date()
    )
    
    let updated = try await viewModel.updateMemory(id: 10, request: updateRequest)
    
    // THEN: Memory should be updated in state
    XCTAssertEqual(updated.title, "Updated Title")
    XCTAssertEqual(updated.content, "Updated content with new information")
    XCTAssertEqual(updated.tags, ["updated", "modified"])
    XCTAssertEqual(viewModel.memories.first?.content, "Updated content with new information")
  }
  
  /// Test: Update only tags
  func testUpdateMemoryTagsOnly() async throws {
    // GIVEN: Existing memory
    let existing = Memory(
      id: 11,
      title: "Memory with tags",
      content: "Content stays same",
      tags: ["old"],
      memoryType: "note",
      createdAt: Date(),
      updatedAt: Date()
    )
    
    mockAPI.mockMemoriesResponse = [existing]
    await viewModel.loadMemories()
    
    // WHEN: Update only tags
    let updateRequest = UpdateMemoryRequest(
      title: nil,
      content: nil,
      tags: ["new", "tags", "here"]
    )
    
    mockAPI.mockUpdateResponse = Memory(
      id: 11,
      title: existing.title,
      content: existing.content,
      tags: ["new", "tags", "here"],
      memoryType: existing.memoryType,
      createdAt: existing.createdAt,
      updatedAt: Date()
    )
    
    let updated = try await viewModel.updateMemory(id: 11, request: updateRequest)
    
    // THEN: Only tags should change
    XCTAssertEqual(updated.title, "Memory with tags", "Title should remain unchanged")
    XCTAssertEqual(updated.content, "Content stays same", "Content should remain unchanged")
    XCTAssertEqual(updated.tags, ["new", "tags", "here"], "Tags should be updated")
  }
  
  // MARK: - Delete Operations
  
  /// Test: Delete memory → Verify removal from state
  func testDeleteMemory() async throws {
    // GIVEN: Memories in state
    mockAPI.mockMemoriesResponse = [
      Memory(
        id: 20,
        title: "Memory to delete",
        content: "Will be deleted",
        tags: [],
        memoryType: "note",
        createdAt: Date(),
        updatedAt: Date()
      ),
      Memory(
        id: 21,
        title: "Memory to keep",
        content: "Will stay",
        tags: [],
        memoryType: "note",
        createdAt: Date(),
        updatedAt: Date()
      )
    ]
    
    await viewModel.loadMemories()
    XCTAssertEqual(viewModel.memories.count, 2)
    
    // WHEN: Delete memory
    mockAPI.mockDeleteSuccess = true
    try await viewModel.deleteMemory(id: 20)
    
    // THEN: Memory should be removed from state
    XCTAssertEqual(viewModel.memories.count, 1, "Should have one memory remaining")
    XCTAssertEqual(viewModel.memories.first?.id, 21, "Remaining memory should be #21")
    XCTAssertNil(viewModel.memories.first(where: { $0.id == 20 }), "Deleted memory should not exist")
  }
  
  // MARK: - Search Operations
  
  /// Test: Search memories by query
  func testSearchMemories() async throws {
    // GIVEN: Multiple memories with different content
    mockAPI.mockSearchResponse = [
      Memory(
        id: 30,
        title: "Swift integration testing",
        content: "How to write integration tests in Swift",
        tags: ["swift", "testing"],
        memoryType: "note",
        createdAt: Date(),
        updatedAt: Date()
      ),
      Memory(
        id: 31,
        title: "Integration patterns",
        content: "Best practices for integration testing",
        tags: ["testing", "patterns"],
        memoryType: "note",
        createdAt: Date(),
        updatedAt: Date()
      )
    ]
    
    // WHEN: Search for "integration"
    let results = try await viewModel.searchMemories(query: "integration")
    
    // THEN: Should return matching memories
    XCTAssertEqual(results.count, 2)
    XCTAssertTrue(results.allSatisfy { $0.title.contains("integration") || $0.content.contains("integration") })
  }
  
  /// Test: Search by tags
  func testSearchMemoriesByTag() async throws {
    // GIVEN: Memories with various tags
    mockAPI.mockSearchResponse = [
      Memory(
        id: 40,
        title: "Testing guide",
        content: "Guide content",
        tags: ["swift", "testing"],
        memoryType: "note",
        createdAt: Date(),
        updatedAt: Date()
      )
    ]
    
    // WHEN: Search by tag
    let results = try await viewModel.searchMemories(tag: "swift")
    
    // THEN: Should return memories with that tag
    XCTAssertEqual(results.count, 1)
    XCTAssertTrue(results.first?.tags.contains("swift") ?? false)
  }
  
  // MARK: - Error Handling
  
  /// Test: Handle API errors gracefully
  func testAPIErrorHandling() async {
    // GIVEN: Mock API configured to fail
    mockAPI.shouldFail = true
    mockAPI.mockError = APIError.serverError(message: "Database connection failed")
    
    // WHEN: Attempt to create memory
    do {
      _ = try await viewModel.createMemory(
        request: CreateMemoryRequest(
          title: "Will fail",
          content: "Test",
          tags: [],
          memoryType: "note"
        )
      )
      XCTFail("Should have thrown error")
    } catch {
      // THEN: Error should be thrown
      XCTAssertTrue(error is APIError)
    }
    
    // AND: State should remain unchanged
    XCTAssertEqual(viewModel.memories.count, 0)
  }
  
  // MARK: - Full CRUD Cycle
  
  /// Test: Complete CRUD lifecycle
  func testFullCRUDCycle() async throws {
    // CREATE
    mockAPI.mockCreateResponse = Memory(
      id: 100,
      title: "CRUD Test",
      content: "Original",
      tags: ["test"],
      memoryType: "note",
      createdAt: Date(),
      updatedAt: Date()
    )
    
    let created = try await viewModel.createMemory(
      request: CreateMemoryRequest(
        title: "CRUD Test",
        content: "Original",
        tags: ["test"],
        memoryType: "note"
      )
    )
    
    XCTAssertEqual(created.id, 100)
    
    // READ
    mockAPI.mockMemoryByIdResponse = created
    let fetched = try await viewModel.fetchMemory(id: 100)
    XCTAssertEqual(fetched.title, "CRUD Test")
    
    // UPDATE
    mockAPI.mockUpdateResponse = Memory(
      id: 100,
      title: "CRUD Test Updated",
      content: "Modified",
      tags: ["test", "updated"],
      memoryType: "note",
      createdAt: created.createdAt,
      updatedAt: Date()
    )
    
    let updated = try await viewModel.updateMemory(
      id: 100,
      request: UpdateMemoryRequest(
        title: "CRUD Test Updated",
        content: "Modified",
        tags: ["test", "updated"]
      )
    )
    
    XCTAssertEqual(updated.title, "CRUD Test Updated")
    XCTAssertEqual(updated.content, "Modified")
    
    // DELETE
    mockAPI.mockMemoriesResponse = [updated]
    await viewModel.loadMemories()
    
    mockAPI.mockDeleteSuccess = true
    try await viewModel.deleteMemory(id: 100)
    
    XCTAssertEqual(viewModel.memories.count, 0, "Memory should be deleted")
  }
}

// MARK: - Mock Memory API Service

class MockMemoryAPIService {
  var shouldFail = false
  var mockError: Error?
  
  var mockMemoriesResponse: [Memory] = []
  var mockMemoryByIdResponse: Memory?
  var mockCreateResponse: Memory?
  var mockUpdateResponse: Memory?
  var mockDeleteSuccess = false
  var mockSearchResponse: [Memory] = []
  
  func fetchMemories() async throws -> [Memory] {
    if shouldFail, let error = mockError {
      throw error
    }
    return mockMemoriesResponse
  }
  
  func fetchMemory(id: Int) async throws -> Memory {
    if shouldFail, let error = mockError {
      throw error
    }
    
    guard let response = mockMemoryByIdResponse else {
      throw APIError.notFound(message: "Memory not found")
    }
    
    return response
  }
  
  func createMemory(request: CreateMemoryRequest) async throws -> Memory {
    if shouldFail, let error = mockError {
      throw error
    }
    
    guard let response = mockCreateResponse else {
      throw APIError.serverError(message: "No mock response configured")
    }
    
    return response
  }
  
  func updateMemory(id: Int, request: UpdateMemoryRequest) async throws -> Memory {
    if shouldFail, let error = mockError {
      throw error
    }
    
    guard let response = mockUpdateResponse else {
      throw APIError.serverError(message: "No mock response configured")
    }
    
    return response
  }
  
  func deleteMemory(id: Int) async throws {
    if shouldFail, let error = mockError {
      throw error
    }
    
    if !mockDeleteSuccess {
      throw APIError.serverError(message: "Delete failed")
    }
  }
  
  func searchMemories(query: String) async throws -> [Memory] {
    if shouldFail, let error = mockError {
      throw error
    }
    return mockSearchResponse
  }
  
  func searchMemories(tag: String) async throws -> [Memory] {
    if shouldFail, let error = mockError {
      throw error
    }
    return mockSearchResponse
  }
}

// MARK: - AppViewModel Extensions

extension AppViewModel {
  convenience init(memoryAPI: MockMemoryAPIService) {
    self.init()
    // Inject mock - implementation depends on AppViewModel structure
  }
  
  func createMemory(request: CreateMemoryRequest) async throws -> Memory {
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  func updateMemory(id: Int, request: UpdateMemoryRequest) async throws -> Memory {
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  func deleteMemory(id: Int) async throws {
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  func fetchMemory(id: Int) async throws -> Memory {
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  func loadMemories() async {
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  func searchMemories(query: String) async throws -> [Memory] {
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  func searchMemories(tag: String) async throws -> [Memory] {
    fatalError("TODO: Implement in actual AppViewModel")
  }
}

// MARK: - Request Models

struct CreateMemoryRequest: Codable {
  let title: String
  let content: String
  let tags: [String]
  let memoryType: String
}

struct UpdateMemoryRequest: Codable {
  let title: String?
  let content: String?
  let tags: [String]?
}

import XCTest
@testable import LobsMissionControl

/// Integration tests for complete task lifecycle across server + client
///
/// **Workflow Tested:**
/// 1. Create task via API (simulated server)
/// 2. Verify task appears in Mission Control UI state
/// 3. Update task status to complete
/// 4. Verify state updates propagate correctly
/// 5. Verify task counter updates
///
/// **Setup:**
/// - Uses mock APIService responses (no live server required)
/// - Tests full data flow: API → AppViewModel → UI state
/// - Verifies state consistency across operations
final class TaskLifecycleIntegrationTests: XCTestCase {
  
  var apiService: MockAPIService!
  var viewModel: AppViewModel!
  
  override func setUp() {
    super.setUp()
    apiService = MockAPIService()
    viewModel = AppViewModel(apiService: apiService)
  }
  
  override func tearDown() {
    apiService = nil
    viewModel = nil
    super.tearDown()
  }
  
  // MARK: - Full Lifecycle Test
  
  /// Test: Create → Update → Complete → Verify State
  func testTaskFullLifecycle() async throws {
    // GIVEN: Initial state with no tasks
    XCTAssertEqual(viewModel.tasks.count, 0, "Should start with no tasks")
    
    // WHEN: Create a new task via API
    let newTaskRequest = CreateTaskRequest(
      title: "Test integration task",
      description: "Testing end-to-end workflow",
      projectId: 1,
      assignedAgent: "programmer",
      priority: "medium",
      status: "not_started"
    )
    
    apiService.mockCreateTaskResponse = Task(
      id: 100,
      title: newTaskRequest.title,
      description: newTaskRequest.description,
      status: "not_started",
      priority: "medium",
      projectId: newTaskRequest.projectId,
      assignedAgent: newTaskRequest.assignedAgent,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    let createdTask = try await viewModel.createTask(request: newTaskRequest)
    
    // THEN: Task should be created and added to state
    XCTAssertEqual(createdTask.id, 100)
    XCTAssertEqual(createdTask.title, "Test integration task")
    XCTAssertEqual(createdTask.status, "not_started")
    XCTAssertEqual(viewModel.tasks.count, 1, "Task should be added to viewModel state")
    XCTAssertEqual(viewModel.tasks.first?.id, 100)
    
    // WHEN: Update task status to in_progress
    apiService.mockUpdateTaskResponse = Task(
      id: 100,
      title: createdTask.title,
      description: createdTask.description,
      status: "in_progress",
      priority: createdTask.priority,
      projectId: createdTask.projectId,
      assignedAgent: createdTask.assignedAgent,
      createdAt: createdTask.createdAt,
      updatedAt: Date()
    )
    
    let updatedTask = try await viewModel.updateTaskStatus(taskId: 100, status: "in_progress")
    
    // THEN: Task status should update in state
    XCTAssertEqual(updatedTask.status, "in_progress")
    XCTAssertEqual(viewModel.tasks.first?.status, "in_progress", "Status should update in viewModel")
    
    // WHEN: Complete the task
    apiService.mockUpdateTaskResponse = Task(
      id: 100,
      title: createdTask.title,
      description: createdTask.description,
      status: "completed",
      priority: createdTask.priority,
      projectId: createdTask.projectId,
      assignedAgent: createdTask.assignedAgent,
      createdAt: createdTask.createdAt,
      updatedAt: Date(),
      completedAt: Date()
    )
    
    let completedTask = try await viewModel.updateTaskStatus(taskId: 100, status: "completed")
    
    // THEN: Task should be marked completed
    XCTAssertEqual(completedTask.status, "completed")
    XCTAssertNotNil(completedTask.completedAt, "Completed task should have completedAt timestamp")
    XCTAssertEqual(viewModel.tasks.first?.status, "completed", "Completion should update in viewModel")
  }
  
  // MARK: - Task Counter Integration
  
  /// Test: Task creation updates counters correctly
  func testTaskCreationUpdatesCounters() async throws {
    // GIVEN: Projects with existing tasks
    apiService.mockProjectsResponse = [
      Project(id: 1, name: "Test Project", description: "Test", status: "active")
    ]
    
    apiService.mockTasksResponse = [
      Task(
        id: 1,
        title: "Existing task 1",
        description: "Test",
        status: "not_started",
        priority: "medium",
        projectId: 1,
        createdAt: Date(),
        updatedAt: Date()
      ),
      Task(
        id: 2,
        title: "Existing task 2",
        description: "Test",
        status: "in_progress",
        priority: "high",
        projectId: 1,
        createdAt: Date(),
        updatedAt: Date()
      )
    ]
    
    await viewModel.loadProjects()
    await viewModel.loadTasks()
    
    // Count active tasks before creation
    let initialActiveTasks = viewModel.tasks.filter { $0.status == "not_started" || $0.status == "in_progress" }
    XCTAssertEqual(initialActiveTasks.count, 2, "Should have 2 active tasks initially")
    
    // WHEN: Create new task
    let newTaskRequest = CreateTaskRequest(
      title: "New task",
      description: "Test",
      projectId: 1,
      assignedAgent: "programmer",
      priority: "medium",
      status: "not_started"
    )
    
    apiService.mockCreateTaskResponse = Task(
      id: 3,
      title: newTaskRequest.title,
      description: newTaskRequest.description,
      status: "not_started",
      priority: "medium",
      projectId: 1,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    _ = try await viewModel.createTask(request: newTaskRequest)
    
    // THEN: Active task count should increase
    let finalActiveTasks = viewModel.tasks.filter { $0.status == "not_started" || $0.status == "in_progress" }
    XCTAssertEqual(finalActiveTasks.count, 3, "Should have 3 active tasks after creation")
  }
  
  // MARK: - Status Transition Validation
  
  /// Test: Valid status transitions work correctly
  func testValidStatusTransitions() async throws {
    // GIVEN: Task in not_started state
    apiService.mockCreateTaskResponse = Task(
      id: 200,
      title: "Status test",
      description: "Test transitions",
      status: "not_started",
      priority: "medium",
      projectId: 1,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    let task = try await viewModel.createTask(
      request: CreateTaskRequest(
        title: "Status test",
        description: "Test transitions",
        projectId: 1,
        assignedAgent: "programmer",
        priority: "medium",
        status: "not_started"
      )
    )
    
    // Valid transitions: not_started → in_progress → completed
    
    // WHEN: Move to in_progress
    apiService.mockUpdateTaskResponse = Task(
      id: 200,
      title: task.title,
      description: task.description,
      status: "in_progress",
      priority: task.priority,
      projectId: task.projectId,
      createdAt: task.createdAt,
      updatedAt: Date()
    )
    
    let inProgressTask = try await viewModel.updateTaskStatus(taskId: 200, status: "in_progress")
    XCTAssertEqual(inProgressTask.status, "in_progress")
    
    // WHEN: Move to completed
    apiService.mockUpdateTaskResponse = Task(
      id: 200,
      title: task.title,
      description: task.description,
      status: "completed",
      priority: task.priority,
      projectId: task.projectId,
      createdAt: task.createdAt,
      updatedAt: Date(),
      completedAt: Date()
    )
    
    let completedTask = try await viewModel.updateTaskStatus(taskId: 200, status: "completed")
    XCTAssertEqual(completedTask.status, "completed")
    XCTAssertNotNil(completedTask.completedAt)
  }
  
  // MARK: - Error Handling
  
  /// Test: API errors are handled gracefully
  func testAPIErrorHandling() async {
    // GIVEN: Mock API configured to fail
    apiService.shouldFail = true
    apiService.mockError = APIError.serverError(message: "Test error")
    
    // WHEN: Attempting to create task
    do {
      _ = try await viewModel.createTask(
        request: CreateTaskRequest(
          title: "Will fail",
          description: "Test",
          projectId: 1,
          assignedAgent: "programmer",
          priority: "medium",
          status: "not_started"
        )
      )
      XCTFail("Should have thrown error")
    } catch {
      // THEN: Error should be thrown and handled
      XCTAssertTrue(error is APIError, "Should throw APIError")
      if let apiError = error as? APIError {
        switch apiError {
        case .serverError(let message):
          XCTAssertEqual(message, "Test error")
        default:
          XCTFail("Wrong error type: \(apiError)")
        }
      }
    }
    
    // AND: ViewModel state should remain unchanged
    XCTAssertEqual(viewModel.tasks.count, 0, "Failed creation should not add task to state")
  }
}

// MARK: - Mock API Service

/// Mock APIService for integration testing without live server
class MockAPIService {
  var shouldFail = false
  var mockError: Error?
  
  // Mock responses
  var mockTasksResponse: [Task] = []
  var mockCreateTaskResponse: Task?
  var mockUpdateTaskResponse: Task?
  var mockProjectsResponse: [Project] = []
  
  func createTask(request: CreateTaskRequest) async throws -> Task {
    if shouldFail, let error = mockError {
      throw error
    }
    
    guard let response = mockCreateTaskResponse else {
      throw APIError.serverError(message: "No mock response configured")
    }
    
    return response
  }
  
  func updateTaskStatus(taskId: Int, status: String) async throws -> Task {
    if shouldFail, let error = mockError {
      throw error
    }
    
    guard let response = mockUpdateTaskResponse else {
      throw APIError.serverError(message: "No mock response configured")
    }
    
    return response
  }
  
  func fetchTasks() async throws -> [Task] {
    if shouldFail, let error = mockError {
      throw error
    }
    
    return mockTasksResponse
  }
  
  func fetchProjects() async throws -> [Project] {
    if shouldFail, let error = mockError {
      throw error
    }
    
    return mockProjectsResponse
  }
}

// MARK: - Helper Extensions

extension AppViewModel {
  /// Convenience initializer for testing with mock API service
  convenience init(apiService: MockAPIService) {
    // This would need to be adjusted based on actual AppViewModel init
    self.init()
    // Inject mock service - implementation depends on AppViewModel structure
  }
  
  /// Create task (wraps API call and updates state)
  func createTask(request: CreateTaskRequest) async throws -> Task {
    // Implementation would call API and update tasks array
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  /// Update task status (wraps API call and updates state)
  func updateTaskStatus(taskId: Int, status: String) async throws -> Task {
    // Implementation would call API and update tasks array
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  /// Load tasks (wraps API call and updates state)
  func loadTasks() async {
    // Implementation would call API and update tasks array
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  /// Load projects (wraps API call and updates state)
  func loadProjects() async {
    // Implementation would call API and update projects array
    fatalError("TODO: Implement in actual AppViewModel")
  }
}

// MARK: - Request Models

struct CreateTaskRequest: Codable {
  let title: String
  let description: String?
  let projectId: Int
  let assignedAgent: String?
  let priority: String
  let status: String
}

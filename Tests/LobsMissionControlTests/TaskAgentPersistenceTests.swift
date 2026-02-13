import XCTest
@testable import LobsMissionControl

/// Tests that the agent field is preserved when creating tasks.
///
/// ## Context
/// User reported: "creating task it removes the assigned agent and i have to reassign it after creating the task"
///
/// ## Root Cause
/// The `api.addTask()` call in `submitTaskToLobs()` was not passing the `agent` parameter,
/// so when the server response came back, it would overwrite the local task without the agent field.
///
/// ## Fix
/// 1. Added `agent` parameter to `TaskCreateRequest` struct
/// 2. Added `agent` parameter to `APIService.addTask()` method
/// 3. Updated all calls to `api.addTask()` to pass the `agent` field
final class TaskAgentPersistenceTests: XCTestCase {
  
  // MARK: - API Service Tests
  
  /// Test that TaskCreateRequest includes agent field
  func testTaskCreateRequestHasAgentField() throws {
    // Verify the TaskCreateRequest struct has the agent field in its definition
    let apiServiceCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/APIService.swift")
    
    // Find TaskCreateRequest struct
    XCTAssertTrue(apiServiceCode.contains("private struct TaskCreateRequest: Codable"),
                  "TaskCreateRequest struct should exist")
    
    // Extract the struct definition
    let structSection = extractSection(from: apiServiceCode,
                                        startMarker: "private struct TaskCreateRequest: Codable",
                                        endMarker: "private struct TaskUpdateRequest")
    
    // Verify agent field is declared
    XCTAssertTrue(structSection.contains("let agent: String?"),
                  "TaskCreateRequest should have 'let agent: String?' field")
    
    // Verify agent is in CodingKeys
    XCTAssertTrue(structSection.contains("case agent"),
                  "TaskCreateRequest CodingKeys should include 'case agent'")
  }
  
  /// Test that addTask method accepts agent parameter
  func testAddTaskMethodAcceptsAgentParameter() throws {
    let apiServiceCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/APIService.swift")
    
    // Find addTask function
    XCTAssertTrue(apiServiceCode.contains("func addTask("),
                  "addTask function should exist")
    
    // Extract the function signature
    let functionSection = extractSection(from: apiServiceCode,
                                          startMarker: "func addTask(",
                                          endMarker: ") async throws -> DashboardTask")
    
    // Verify agent parameter is declared
    XCTAssertTrue(functionSection.contains("agent: String?"),
                  "addTask should accept 'agent: String?' parameter")
  }
  
  /// Test that addTask passes agent to TaskCreateRequest
  func testAddTaskPassesAgentToRequest() throws {
    let apiServiceCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/APIService.swift")
    
    // Find the addTask function body
    let functionSection = extractSection(from: apiServiceCode,
                                          startMarker: "func addTask(",
                                          endMarker: "func saveExistingTask")
    
    // Verify TaskCreateRequest is initialized with agent
    XCTAssertTrue(functionSection.contains("let create = TaskCreateRequest("),
                  "addTask should create TaskCreateRequest")
    
    // Verify agent is passed to the request
    XCTAssertTrue(functionSection.contains("agent: agent"),
                  "addTask should pass agent parameter to TaskCreateRequest")
  }
  
  // MARK: - AppViewModel Tests
  
  /// Test that submitTaskToLobs passes agent to api.addTask
  func testSubmitTaskToLobsPassesAgent() throws {
    let appViewModelCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/AppViewModel.swift")
    
    // Find submitTaskToLobs function
    XCTAssertTrue(appViewModelCode.contains("func submitTaskToLobs("),
                  "submitTaskToLobs function should exist")
    
    // Extract the function body
    let functionSection = extractSection(from: appViewModelCode,
                                          startMarker: "func submitTaskToLobs(title: String, notes: String?, agent: String?, autoPush: Bool)",
                                          endMarker: "func duplicateTask")
    
    // Verify the function creates a task with agent
    XCTAssertTrue(functionSection.contains("agent: agent"),
                  "submitTaskToLobs should create DashboardTask with agent parameter")
    
    // Verify api.addTask is called with agent
    XCTAssertTrue(functionSection.contains("let savedTask = try await api.addTask("),
                  "submitTaskToLobs should call api.addTask")
    
    // Find the api.addTask call
    let addTaskCallSection = extractSection(from: functionSection,
                                             startMarker: "let savedTask = try await api.addTask(",
                                             endMarker: "await MainActor.run")
    
    XCTAssertTrue(addTaskCallSection.contains("agent: agent"),
                  "api.addTask call should include agent parameter")
  }
  
  /// Test that bulk task creation passes agent field
  func testBulkTaskCreationPassesAgent() throws {
    let appViewModelCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/AppViewModel.swift")
    
    // Find the bulk task creation code (creates multiple tasks from templates)
    // This is where tasks are created in a loop
    let bulkCreationPattern = "for task in newTasks {"
    XCTAssertTrue(appViewModelCode.contains(bulkCreationPattern),
                  "Bulk task creation code should exist")
    
    // Extract the section with the loop
    let lines = appViewModelCode.components(separatedBy: .newlines)
    guard let loopStartIndex = lines.firstIndex(where: { $0.contains(bulkCreationPattern) }) else {
      XCTFail("Could not find bulk task creation loop")
      return
    }
    
    // Get a reasonable section of code around the loop
    let sectionStart = max(0, loopStartIndex - 5)
    let sectionEnd = min(lines.count, loopStartIndex + 20)
    let loopSection = lines[sectionStart..<sectionEnd].joined(separator: "\n")
    
    // Verify api.addTask is called with agent from task
    XCTAssertTrue(loopSection.contains("api.addTask("),
                  "Bulk creation should call api.addTask")
    XCTAssertTrue(loopSection.contains("agent: task.agent"),
                  "Bulk creation should pass task.agent to api.addTask")
  }
  
  // MARK: - Integration Test Pattern
  
  /// Test that the complete flow preserves agent assignment
  func testAgentPreservationFlowPattern() throws {
    let apiServiceCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/APIService.swift")
    let appViewModelCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/AppViewModel.swift")
    
    // Verify the complete chain:
    // 1. TaskCreateRequest has agent field
    XCTAssertTrue(apiServiceCode.contains("let agent: String?"),
                  "Step 1: TaskCreateRequest should have agent field")
    
    // 2. addTask accepts agent parameter
    let addTaskSection = extractSection(from: apiServiceCode,
                                         startMarker: "func addTask(",
                                         endMarker: ") async throws -> DashboardTask")
    XCTAssertTrue(addTaskSection.contains("agent: String?"),
                  "Step 2: addTask should accept agent parameter")
    
    // 3. addTask passes agent to TaskCreateRequest
    let addTaskBodySection = extractSection(from: apiServiceCode,
                                             startMarker: "let create = TaskCreateRequest(",
                                             endMarker: "return try await request(")
    XCTAssertTrue(addTaskBodySection.contains("agent: agent"),
                  "Step 3: addTask should pass agent to TaskCreateRequest")
    
    // 4. submitTaskToLobs passes agent to api.addTask
    let submitSection = extractSection(from: appViewModelCode,
                                        startMarker: "let savedTask = try await api.addTask(",
                                        endMarker: "await MainActor.run")
    XCTAssertTrue(submitSection.contains("agent: agent"),
                  "Step 4: submitTaskToLobs should pass agent to api.addTask")
  }
  
  // MARK: - Regression Tests
  
  /// Test that agent field has proper default value
  func testAgentParameterHasDefaultValue() throws {
    let apiServiceCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/APIService.swift")
    
    // Extract addTask signature
    let signatureSection = extractSection(from: apiServiceCode,
                                           startMarker: "func addTask(",
                                           endMarker: ") async throws -> DashboardTask")
    
    // Verify agent has default value of nil
    XCTAssertTrue(signatureSection.contains("agent: String? = nil"),
                  "agent parameter should have default value of nil for backward compatibility")
  }
  
  /// Test that all api.addTask calls are updated
  func testAllAddTaskCallsIncludeAgent() throws {
    let appViewModelCode = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/AppViewModel.swift")
    
    // Count api.addTask calls
    let addTaskCalls = appViewModelCode.components(separatedBy: "api.addTask(")
    XCTAssertGreaterThan(addTaskCalls.count, 1,
                         "Should have at least one api.addTask call")
    
    // For each call, verify agent parameter is included or can be omitted (default nil)
    // We have 2 known calls:
    // 1. submitTaskToLobs - should explicitly pass agent
    // 2. bulk creation - should explicitly pass task.agent
    
    // Find submitTaskToLobs call
    let submitSection = extractSection(from: appViewModelCode,
                                        startMarker: "func submitTaskToLobs",
                                        endMarker: "func duplicateTask")
    let submitAddTaskCall = extractSection(from: submitSection,
                                            startMarker: "let savedTask = try await api.addTask(",
                                            endMarker: ")")
    XCTAssertTrue(submitAddTaskCall.contains("agent:"),
                  "submitTaskToLobs api.addTask call should include agent parameter")
    
    // Find bulk creation call
    let bulkPattern = "for task in newTasks {"
    if appViewModelCode.contains(bulkPattern) {
      let lines = appViewModelCode.components(separatedBy: .newlines)
      if let loopIndex = lines.firstIndex(where: { $0.contains(bulkPattern) }) {
        let loopSection = lines[loopIndex..<min(loopIndex + 20, lines.count)].joined(separator: "\n")
        if loopSection.contains("api.addTask(") {
          XCTAssertTrue(loopSection.contains("agent:"),
                        "Bulk creation api.addTask call should include agent parameter")
        }
      }
    }
  }
  
  // MARK: - Helper Methods
  
  /// Extract a section of source code between two markers
  private func extractSection(from source: String, startMarker: String, endMarker: String) -> String {
    guard let startRange = source.range(of: startMarker),
          let endRange = source.range(of: endMarker, range: startRange.upperBound..<source.endIndex) else {
      return ""
    }
    return String(source[startRange.lowerBound..<endRange.lowerBound])
  }
}

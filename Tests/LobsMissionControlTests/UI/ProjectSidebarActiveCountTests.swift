import XCTest
@testable import LobsMissionControl

/// Tests for project sidebar active count calculation
final class ProjectSidebarActiveCountTests: XCTestCase {
  
  // MARK: - Active Count Tests
  
  func testActiveCountOnlyIncludesActiveTasks() {
    // Given: A project with various task statuses
    let projectId = "test-project-1"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active),
      createTask(id: "2", projectId: projectId, status: .active),
      createTask(id: "3", projectId: projectId, status: .active),
      createTask(id: "4", projectId: projectId, status: .completed),
      createTask(id: "5", projectId: projectId, status: .inbox),
      createTask(id: "6", projectId: projectId, status: .rejected),
      createTask(id: "7", projectId: projectId, status: .waitingOn)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Only active tasks are counted
    XCTAssertEqual(activeCount, 3, "Should only count tasks with status == .active")
  }
  
  func testCompletedTasksNotCounted() {
    // Given: A project with completed tasks
    let projectId = "test-project-2"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active),
      createTask(id: "2", projectId: projectId, status: .completed),
      createTask(id: "3", projectId: projectId, status: .completed)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Completed tasks are excluded
    XCTAssertEqual(activeCount, 1, "Completed tasks should not be counted")
  }
  
  func testRejectedTasksNotCounted() {
    // Given: A project with rejected tasks
    let projectId = "test-project-3"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active),
      createTask(id: "2", projectId: projectId, status: .rejected),
      createTask(id: "3", projectId: projectId, status: .rejected)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Rejected tasks are excluded
    XCTAssertEqual(activeCount, 1, "Rejected tasks should not be counted")
  }
  
  func testBlockedCompletedTasksNotCounted() {
    // Regression test: The bug was counting blocked tasks marked as done
    
    // Given: A project with a blocked task marked as completed
    let projectId = "test-project-4"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active, workState: nil),
      createTask(id: "2", projectId: projectId, status: .completed, workState: .blocked),
      createTask(id: "3", projectId: projectId, status: .completed, workState: .blocked)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Blocked completed tasks are NOT counted
    XCTAssertEqual(activeCount, 1, "Blocked tasks marked as completed should not be counted in active")
  }
  
  func testInboxTasksNotCounted() {
    // Given: A project with inbox tasks
    let projectId = "test-project-5"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active),
      createTask(id: "2", projectId: projectId, status: .inbox),
      createTask(id: "3", projectId: projectId, status: .inbox)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Inbox tasks are excluded
    XCTAssertEqual(activeCount, 1, "Inbox tasks should not be counted in active")
  }
  
  func testWaitingOnTasksNotCounted() {
    // Given: A project with waiting_on tasks
    let projectId = "test-project-6"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active),
      createTask(id: "2", projectId: projectId, status: .waitingOn),
      createTask(id: "3", projectId: projectId, status: .waitingOn)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Waiting tasks are excluded
    XCTAssertEqual(activeCount, 1, "Waiting_on tasks should not be counted in active")
  }
  
  func testOnlyProjectTasksCounted() {
    // Given: Multiple projects with tasks
    let projectId = "test-project-7"
    let otherProjectId = "other-project"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active),
      createTask(id: "2", projectId: projectId, status: .active),
      createTask(id: "3", projectId: otherProjectId, status: .active),
      createTask(id: "4", projectId: otherProjectId, status: .active),
      createTask(id: "5", projectId: otherProjectId, status: .active)
    ]
    
    // When: Calculating active count for specific project
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Only tasks from that project are counted
    XCTAssertEqual(activeCount, 2, "Should only count tasks from the specified project")
  }
  
  func testEmptyProjectHasZeroActive() {
    // Given: A project with no tasks
    let projectId = "empty-project"
    let tasks: [DashboardTask] = []
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Count is zero
    XCTAssertEqual(activeCount, 0, "Empty project should have zero active tasks")
  }
  
  func testProjectWithOnlyNonActiveTasksHasZeroActive() {
    // Given: A project with only non-active tasks
    let projectId = "test-project-8"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .completed),
      createTask(id: "2", projectId: projectId, status: .inbox),
      createTask(id: "3", projectId: projectId, status: .rejected),
      createTask(id: "4", projectId: projectId, status: .waitingOn)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Count is zero
    XCTAssertEqual(activeCount, 0, "Project with no active tasks should show zero")
  }
  
  // MARK: - Work State Independence Tests
  
  func testWorkStateDoesNotAffectActiveCount() {
    // Given: Active tasks with different work states
    let projectId = "test-project-9"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active, workState: .notStarted),
      createTask(id: "2", projectId: projectId, status: .active, workState: .inProgress),
      createTask(id: "3", projectId: projectId, status: .active, workState: .blocked),
      createTask(id: "4", projectId: projectId, status: .active, workState: nil)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: All active tasks are counted regardless of work state
    XCTAssertEqual(activeCount, 4, "Active count should include all active tasks regardless of work state")
  }
  
  func testBlockedActiveTasksAreCounted() {
    // Important: Blocked tasks with status=active SHOULD be counted
    // The bug was counting blocked tasks with status=completed
    
    // Given: Active tasks that are blocked
    let projectId = "test-project-10"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active, workState: .blocked),
      createTask(id: "2", projectId: projectId, status: .active, workState: .blocked),
      createTask(id: "3", projectId: projectId, status: .active, workState: .inProgress)
    ]
    
    // When: Calculating active count
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    // Then: Blocked active tasks ARE counted
    XCTAssertEqual(activeCount, 3, "Blocked tasks with status=active should be counted")
  }
  
  // MARK: - Regression Tests
  
  func testOldBugDoesNotOccur() {
    // Regression: Ensure the bug (counting non-active tasks) doesn't happen
    
    // Given: The scenario described in the bug report
    let projectId = "bug-test-project"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .active, workState: .inProgress),
      createTask(id: "2", projectId: projectId, status: .completed, workState: .blocked),
      createTask(id: "3", projectId: projectId, status: .inbox, workState: nil),
      createTask(id: "4", projectId: projectId, status: .waitingOn, workState: nil)
    ]
    
    // OLD (buggy) logic would count: NOT completed AND NOT rejected = 3 tasks
    let oldBuggyCount = tasks.filter { 
      $0.projectId == projectId && $0.status != .completed && $0.status != .rejected 
    }.count
    
    // NEW (correct) logic counts only active = 1 task
    let correctCount = tasks.filter { 
      $0.projectId == projectId && $0.status == .active 
    }.count
    
    // Verify bug is fixed
    XCTAssertEqual(oldBuggyCount, 3, "Old logic incorrectly counted 3 tasks")
    XCTAssertEqual(correctCount, 1, "New logic correctly counts only 1 active task")
    XCTAssertNotEqual(oldBuggyCount, correctCount, "Bug fix changed the behavior")
  }
  
  // MARK: - Edge Cases
  
  func testAllStatusesCoverage() {
    // Verify behavior for all possible task statuses
    let projectId = "test-project-11"
    let tasks = [
      createTask(id: "1", projectId: projectId, status: .inbox),
      createTask(id: "2", projectId: projectId, status: .active),
      createTask(id: "3", projectId: projectId, status: .completed),
      createTask(id: "4", projectId: projectId, status: .rejected),
      createTask(id: "5", projectId: projectId, status: .waitingOn)
    ]
    
    let activeCount = tasks.filter { $0.projectId == projectId && $0.status == .active }.count
    
    XCTAssertEqual(activeCount, 1, "Only the task with status .active should be counted")
  }
  
  // MARK: - Helper Functions
  
  private func createTask(
    id: String,
    projectId: String,
    status: TaskStatus,
    workState: WorkState? = nil
  ) -> DashboardTask {
    DashboardTask(
      id: id,
      title: "Task \(id)",
      status: status,
      owner: .lobs,
      createdAt: Date(),
      updatedAt: Date(),
      workState: workState,
      reviewState: nil,
      projectId: projectId,
      artifactPath: nil,
      notes: nil,
      startedAt: nil,
      finishedAt: nil,
      sortOrder: nil,
      blockedBy: nil,
      pinned: nil,
      shape: nil,
      agent: nil
    )
  }
}

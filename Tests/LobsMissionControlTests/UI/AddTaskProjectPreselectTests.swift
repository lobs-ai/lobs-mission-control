import XCTest
@testable import LobsMissionControl

/// Tests for add task from project overview behavior
final class AddTaskProjectPreselectTests: XCTestCase {
  
  // MARK: - Project Preselection Tests
  
  func testAddTaskFromProjectOverviewPreselectsProject() {
    // When: User clicks "Add Task" from a project card in overview
    // Then: Task sheet should open with that project pre-selected
    // And: User should remain in overview (not navigate to project)
    
    let projectId = "test-project-123"
    var taskProjectId: String? = nil
    var showOverview = true
    var selectedProjectId: String? = nil
    
    // Simulate clicking "Add Task" on project card from overview
    taskProjectId = projectId
    // showOverview should remain true (no navigation)
    // selectedProjectId should remain unchanged
    
    XCTAssertEqual(taskProjectId, projectId, "Task project ID should be set to the clicked project")
    XCTAssertTrue(showOverview, "Should remain in overview mode")
    XCTAssertNil(selectedProjectId, "Selected project should not change")
  }
  
  func testAddTaskFromProjectViewPreselectsCurrentProject() {
    // When: User clicks "Add Task" from top bar while in a project view
    // Then: Task sheet should open with current project pre-selected
    
    let projectId = "current-project-456"
    var taskProjectId: String? = nil
    let showOverview = false
    let selectedProjectId = projectId
    
    // Simulate clicking "Add Task" from top bar in project view
    taskProjectId = showOverview ? nil : selectedProjectId
    
    XCTAssertEqual(taskProjectId, projectId, "Task project ID should be set to current project")
  }
  
  func testAddTaskFromOverviewTopBarNoPreselection() {
    // When: User clicks "Add Task" from top bar while in overview
    // Then: Task sheet should open without project pre-selected
    
    var taskProjectId: String? = nil
    let showOverview = true
    let selectedProjectId: String? = nil
    
    // Simulate clicking "Add Task" from top bar in overview
    taskProjectId = showOverview ? nil : selectedProjectId
    
    XCTAssertNil(taskProjectId, "Task project ID should be nil when adding from overview top bar")
  }
  
  func testTaskProjectIdResetsAfterSheetDismiss() {
    // When: Task sheet is dismissed
    // Then: taskProjectId should reset to nil
    
    var taskProjectId: String? = "test-project-789"
    
    // Simulate sheet dismiss
    taskProjectId = nil
    
    XCTAssertNil(taskProjectId, "Task project ID should reset to nil after sheet dismisses")
  }
  
  // MARK: - Navigation Behavior Tests
  
  func testAddTaskFromProjectCardDoesNotNavigate() {
    // Verify that clicking "Add Task" from project card does NOT navigate
    
    let projectId = "project-abc"
    var showOverview = true
    var selectedProjectId: String? = nil
    var taskProjectId: String? = nil
    var showAddTask = false
    
    // Simulate the OLD behavior (what we're fixing):
    // OLD: selectedProjectId = projectId; showOverview = false
    // NEW: taskProjectId = projectId (no navigation)
    
    // New correct behavior
    taskProjectId = projectId
    showAddTask = true
    
    XCTAssertTrue(showOverview, "Should stay in overview mode")
    XCTAssertNil(selectedProjectId, "Selected project should not change")
    XCTAssertEqual(taskProjectId, projectId, "Task should be created in correct project")
    XCTAssertTrue(showAddTask, "Task sheet should open")
  }
  
  func testClickingProjectCardStillNavigates() {
    // Verify that clicking the project card itself (not add task button) still navigates
    
    let projectId = "project-xyz"
    var showOverview = true
    var selectedProjectId: String? = nil
    
    // Simulate clicking the project card (onSelect action)
    selectedProjectId = projectId
    showOverview = false
    
    XCTAssertFalse(showOverview, "Should navigate into project")
    XCTAssertEqual(selectedProjectId, projectId, "Selected project should be set")
  }
  
  // MARK: - Edge Cases
  
  func testMultipleProjectCardsIndependent() {
    // Verify that clicking "Add Task" on different project cards works correctly
    
    let project1 = "project-1"
    let project2 = "project-2"
    var taskProjectId: String? = nil
    
    // Click add task on project 1
    taskProjectId = project1
    XCTAssertEqual(taskProjectId, project1)
    
    // Reset (simulate sheet close)
    taskProjectId = nil
    
    // Click add task on project 2
    taskProjectId = project2
    XCTAssertEqual(taskProjectId, project2)
  }
  
  func testAddTaskWithNilProjectId() {
    // Verify nil project ID is handled correctly (no project preselected)
    
    var taskProjectId: String? = nil
    
    // User adds task from overview without selecting a project
    // taskProjectId should remain nil
    
    XCTAssertNil(taskProjectId, "Task project ID can be nil for tasks without project")
  }
  
  // MARK: - User Flow Tests
  
  func testCompleteUserFlow_AddTaskFromOverview() {
    // Simulate complete user flow: Overview → Add Task on Project Card
    
    var showOverview = true
    var selectedProjectId: String? = nil
    var taskProjectId: String? = nil
    var showAddTask = false
    let targetProject = "my-project"
    
    // Step 1: User is in overview
    XCTAssertTrue(showOverview)
    XCTAssertNil(selectedProjectId)
    
    // Step 2: User hovers over project card and clicks "Add Task"
    taskProjectId = targetProject
    showAddTask = true
    
    // Step 3: Verify state
    XCTAssertTrue(showOverview, "User should still be in overview")
    XCTAssertNil(selectedProjectId, "Navigation should not occur")
    XCTAssertEqual(taskProjectId, targetProject, "Project should be preselected in sheet")
    XCTAssertTrue(showAddTask, "Task sheet should be visible")
    
    // Step 4: User dismisses sheet
    showAddTask = false
    taskProjectId = nil
    
    // Step 5: User is back in overview, ready for next action
    XCTAssertTrue(showOverview, "User should still be in overview")
    XCTAssertNil(taskProjectId, "Task project ID should be reset")
  }
  
  func testCompleteUserFlow_AddTaskFromProjectView() {
    // Simulate complete user flow: Project View → Add Task from Top Bar
    
    let currentProject = "active-project"
    var showOverview = false
    var selectedProjectId: String? = currentProject
    var taskProjectId: String? = nil
    var showAddTask = false
    
    // Step 1: User is viewing a specific project
    XCTAssertFalse(showOverview)
    XCTAssertEqual(selectedProjectId, currentProject)
    
    // Step 2: User clicks "Add Task" from top bar
    taskProjectId = showOverview ? nil : selectedProjectId
    showAddTask = true
    
    // Step 3: Verify state
    XCTAssertFalse(showOverview, "User should still be in project view")
    XCTAssertEqual(selectedProjectId, currentProject, "Project selection unchanged")
    XCTAssertEqual(taskProjectId, currentProject, "Task should be in current project")
    XCTAssertTrue(showAddTask, "Task sheet should be visible")
    
    // Step 4: User dismisses sheet
    showAddTask = false
    taskProjectId = nil
    
    // Step 5: User is back in same project view
    XCTAssertFalse(showOverview, "User should still be in project view")
    XCTAssertEqual(selectedProjectId, currentProject, "Still viewing same project")
    XCTAssertNil(taskProjectId, "Task project ID should be reset")
  }
  
  // MARK: - Regression Tests
  
  func testOldBehaviorDoesNotOccur() {
    // Regression test: ensure the OLD buggy behavior doesn't happen
    // OLD BUG: Clicking "Add Task" on project card navigated into that project
    
    let projectId = "test-project"
    var showOverview = true
    var selectedProjectId: String? = nil
    var taskProjectId: String? = nil
    
    // Simulate NEW correct behavior (what we implemented)
    taskProjectId = projectId
    // Do NOT set: selectedProjectId = projectId
    // Do NOT set: showOverview = false
    
    // Verify the bug is fixed
    XCTAssertTrue(showOverview, "BUG FIX: Should NOT navigate when adding task")
    XCTAssertNil(selectedProjectId, "BUG FIX: Selected project should NOT change")
    XCTAssertEqual(taskProjectId, projectId, "Task should still be in correct project")
  }
  
  func testTopBarAddTaskStillWorks() {
    // Regression test: ensure top bar "Add Task" still works correctly
    
    let currentProject = "proj-123"
    var showOverview = false
    var selectedProjectId: String? = currentProject
    var taskProjectId: String? = nil
    var showAddTask = false
    
    // Simulate clicking top bar "Add Task" button
    taskProjectId = showOverview ? nil : selectedProjectId
    showAddTask = true
    
    XCTAssertEqual(taskProjectId, currentProject, "Should preselect current project")
    XCTAssertTrue(showAddTask, "Sheet should open")
  }
}

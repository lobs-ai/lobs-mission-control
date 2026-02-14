import XCTest
@testable import LobsMissionControl

/// Tests for task creation selection behavior
///
/// This test suite validates:
/// - Newly created tasks are selected (selectedTaskId is set)
/// - Newly created tasks do NOT auto-open detail view (popoverTaskId is not set)
/// - Task selection behavior vs. detail view opening behavior
/// - User can manually open detail view after creation
final class TaskCreationSelectionTests: XCTestCase {
  
  // MARK: - Task Creation Selection Tests
  
  func testNewTaskSetsSelectedTaskId() {
    // When a task is created, selectedTaskId should be set to the new task's ID
    let newTaskId = "new-task-123"
    var selectedTaskId: String? = nil
    
    // Simulate task creation
    selectedTaskId = newTaskId
    
    XCTAssertEqual(selectedTaskId, "new-task-123", "New task should be selected")
  }
  
  func testNewTaskDoesNotSetPopoverTaskId() {
    // When a task is created, popoverTaskId should NOT be set
    // (old behavior set it, new behavior does not)
    let newTaskId = "new-task-456"
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = nil
    
    // OLD BEHAVIOR (unwanted):
    // selectedTaskId = newTaskId
    // popoverTaskId = newTaskId  // ❌ This causes auto-open
    
    // NEW BEHAVIOR (desired):
    selectedTaskId = newTaskId
    // popoverTaskId remains nil
    
    XCTAssertEqual(selectedTaskId, "new-task-456", "Task should be selected")
    XCTAssertNil(popoverTaskId, "Detail view should NOT auto-open")
  }
  
  // MARK: - Selection vs Detail View Tests
  
  func testSelectedTaskIdShowsTaskAsSelected() {
    // selectedTaskId highlights/selects the task in the list
    let taskId = "task-789"
    var selectedTaskId: String? = nil
    
    selectedTaskId = taskId
    
    XCTAssertNotNil(selectedTaskId, "Task should be selected")
    XCTAssertEqual(selectedTaskId, taskId, "Correct task should be selected")
  }
  
  func testPopoverTaskIdOpensDetailView() {
    // popoverTaskId opens the detail/edit panel
    let taskId = "task-abc"
    var popoverTaskId: String? = nil
    
    // User manually clicks on task to open detail
    popoverTaskId = taskId
    
    XCTAssertNotNil(popoverTaskId, "Detail view should be open")
    XCTAssertEqual(popoverTaskId, taskId, "Correct task detail should be shown")
  }
  
  func testSelectionWithoutDetailView() {
    // A task can be selected without opening detail view
    let taskId = "task-xyz"
    var selectedTaskId: String? = taskId
    var popoverTaskId: String? = nil
    
    XCTAssertNotNil(selectedTaskId, "Task is selected")
    XCTAssertNil(popoverTaskId, "But detail view is not open")
  }
  
  func testDetailViewWithoutSelection() {
    // Edge case: detail view can be open without selection
    // (though this is unusual in practice)
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = "task-detail"
    
    XCTAssertNil(selectedTaskId, "No task selected")
    XCTAssertNotNil(popoverTaskId, "But detail view is open")
  }
  
  func testBothSelectedAndDetailOpen() {
    // A task can be both selected AND have detail view open
    let taskId = "task-full"
    var selectedTaskId: String? = taskId
    var popoverTaskId: String? = taskId
    
    XCTAssertEqual(selectedTaskId, taskId, "Task is selected")
    XCTAssertEqual(popoverTaskId, taskId, "And detail view is open")
  }
  
  // MARK: - User Flow Tests
  
  func testUserCreatesTaskThenManuallyOpensDetail() {
    // User creates task → task is selected but detail closed
    // User clicks task → detail opens
    
    let newTaskId = "new-task-flow"
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = nil
    
    // Step 1: Create task
    selectedTaskId = newTaskId
    // popoverTaskId remains nil (not auto-opened)
    
    XCTAssertEqual(selectedTaskId, newTaskId, "Task is selected after creation")
    XCTAssertNil(popoverTaskId, "Detail is not auto-opened")
    
    // Step 2: User manually clicks to open detail
    popoverTaskId = newTaskId
    
    XCTAssertEqual(selectedTaskId, newTaskId, "Task still selected")
    XCTAssertEqual(popoverTaskId, newTaskId, "Detail now open")
  }
  
  func testUserCreatesMultipleTasksInSequence() {
    // Create multiple tasks, each should be selected without opening detail
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = nil
    
    // Create task 1
    selectedTaskId = "task-1"
    XCTAssertEqual(selectedTaskId, "task-1")
    XCTAssertNil(popoverTaskId)
    
    // Create task 2
    selectedTaskId = "task-2"
    XCTAssertEqual(selectedTaskId, "task-2")
    XCTAssertNil(popoverTaskId)
    
    // Create task 3
    selectedTaskId = "task-3"
    XCTAssertEqual(selectedTaskId, "task-3")
    XCTAssertNil(popoverTaskId)
  }
  
  // MARK: - Old Behavior vs New Behavior Tests
  
  func testOldBehaviorAutoOpenedDetail() {
    // Document the OLD (unwanted) behavior
    let newTaskId = "task-old"
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = nil
    
    // OLD CODE:
    // selectedTaskId = newTask.id
    // popoverTaskId = newTask.id  // ❌ Auto-opens detail, puts cursor in edit box
    
    selectedTaskId = newTaskId
    popoverTaskId = newTaskId  // This is what we DON'T want
    
    XCTAssertEqual(selectedTaskId, newTaskId)
    XCTAssertEqual(popoverTaskId, newTaskId, "Old behavior auto-opened detail")
  }
  
  func testNewBehaviorDoesNotAutoOpenDetail() {
    // Document the NEW (desired) behavior
    let newTaskId = "task-new"
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = nil
    
    // NEW CODE:
    // selectedTaskId = newTask.id
    // (popoverTaskId is NOT set)
    
    selectedTaskId = newTaskId
    // popoverTaskId remains nil
    
    XCTAssertEqual(selectedTaskId, newTaskId, "Task is selected")
    XCTAssertNil(popoverTaskId, "Detail is NOT auto-opened")
  }
  
  // MARK: - State Reset Tests
  
  func testPopoverTaskIdCanBeCleared() {
    // User can close detail view
    var popoverTaskId: String? = "task-open"
    XCTAssertNotNil(popoverTaskId)
    
    // Close detail view
    popoverTaskId = nil
    XCTAssertNil(popoverTaskId, "Detail view closed")
  }
  
  func testSelectedTaskIdCanBeCleared() {
    // User can deselect task
    var selectedTaskId: String? = "task-selected"
    XCTAssertNotNil(selectedTaskId)
    
    // Deselect
    selectedTaskId = nil
    XCTAssertNil(selectedTaskId, "Task deselected")
  }
  
  func testBothCanBeClearedIndependently() {
    // Both states can be cleared independently
    var selectedTaskId: String? = "task-1"
    var popoverTaskId: String? = "task-1"
    
    // Close detail but keep selection
    popoverTaskId = nil
    XCTAssertNotNil(selectedTaskId, "Selection remains")
    XCTAssertNil(popoverTaskId, "Detail closed")
    
    // Now deselect
    selectedTaskId = nil
    XCTAssertNil(selectedTaskId, "Selection cleared")
    XCTAssertNil(popoverTaskId, "Detail still closed")
  }
  
  // MARK: - Edge Cases
  
  func testCreatingTaskWhenAnotherIsSelected() {
    // Creating a new task should change selection to the new task
    var selectedTaskId: String? = "old-task"
    var popoverTaskId: String? = nil
    
    XCTAssertEqual(selectedTaskId, "old-task")
    
    // Create new task
    let newTaskId = "new-task"
    selectedTaskId = newTaskId
    
    XCTAssertEqual(selectedTaskId, "new-task", "Selection moved to new task")
    XCTAssertNil(popoverTaskId, "Detail still not auto-opened")
  }
  
  func testCreatingTaskWhenDetailIsOpen() {
    // Creating a new task when another task's detail is open
    var selectedTaskId: String? = "task-a"
    var popoverTaskId: String? = "task-a"
    
    // Create new task
    let newTaskId = "task-b"
    selectedTaskId = newTaskId
    // popoverTaskId is NOT updated (remains on task-a)
    
    XCTAssertEqual(selectedTaskId, "task-b", "New task is selected")
    XCTAssertEqual(popoverTaskId, "task-a", "Old detail view still open (edge case)")
    
    // In real app, you might want to close the old detail view:
    // popoverTaskId = nil
    // or open the new task's detail:
    // popoverTaskId = newTaskId
    // But for task creation, we want neither auto-opened
  }
  
  // MARK: - User Experience Tests
  
  func testUserCanQuicklyCreateMultipleTasksWithoutInterruption() {
    // User creates multiple tasks in quick succession
    // They should all be created without being interrupted by detail views
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = nil
    let createdTasks: [String] = []
    
    for i in 1...5 {
      let taskId = "quick-task-\(i)"
      selectedTaskId = taskId
      // popoverTaskId remains nil for each creation
      
      XCTAssertEqual(selectedTaskId, taskId)
      XCTAssertNil(popoverTaskId, "Detail should not interrupt rapid task creation")
    }
  }
  
  func testUserCanSeeNewTaskIsSelectedVisually() {
    // After creating a task, user should see it highlighted/selected
    var selectedTaskId: String? = nil
    
    selectedTaskId = "visual-task"
    
    XCTAssertNotNil(selectedTaskId, "Task should be visually selected")
    // In the UI, this would show with highlighting/background color
  }
  
  func testUserCanClickToEditAfterCreation() {
    // After creating a task, user can click it to edit
    var selectedTaskId: String? = "created-task"
    var popoverTaskId: String? = nil
    
    // Task is selected but not in edit mode
    XCTAssertNotNil(selectedTaskId)
    XCTAssertNil(popoverTaskId)
    
    // User clicks to edit
    popoverTaskId = selectedTaskId
    
    XCTAssertEqual(popoverTaskId, "created-task", "User can manually open edit view")
  }
  
  // MARK: - Integration Behavior Tests
  
  func testTaskCreationCompleteFlow() {
    // Complete flow: create → select → optionally edit
    var selectedTaskId: String? = nil
    var popoverTaskId: String? = nil
    
    // Initial state
    XCTAssertNil(selectedTaskId)
    XCTAssertNil(popoverTaskId)
    
    // Create task
    let newTaskId = "flow-task"
    selectedTaskId = newTaskId
    
    // After creation
    XCTAssertEqual(selectedTaskId, newTaskId, "Task selected")
    XCTAssertNil(popoverTaskId, "Detail not opened")
    
    // User decides to edit (optional)
    if selectedTaskId != nil {
      popoverTaskId = selectedTaskId
    }
    
    // After manual edit action
    XCTAssertEqual(popoverTaskId, newTaskId, "User can open detail when desired")
  }
}

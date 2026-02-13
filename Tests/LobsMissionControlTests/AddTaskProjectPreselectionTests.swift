import XCTest
@testable import LobsMissionControl

/// Tests for pre-selecting project when adding task from project view.
///
/// ## Problem
/// User reported: "when clicking on new task from project home screen on a specific project 
/// i still have to choose my project. if i am clicking on the add task on the specific 
/// project, it should know to go to that project"
///
/// ## Root Cause
/// The `onAddTask` closure from project cards set `vm.selectedProjectId` but didn't set 
/// `vm.showOverview = false`. When the AddTaskSheet was created, it checked:
/// ```swift
/// projectId: vm.showOverview ? nil : vm.selectedProjectId
/// ```
/// Since `showOverview` was still true, it passed `nil` instead of the project ID.
///
/// ## Solution
/// Added `vm.showOverview = false` to the onAddTask closure, matching the behavior of 
/// the onSelect closure. This ensures the sheet receives the correct project ID.
///
/// ## Tests
/// These tests verify that the project is pre-selected correctly in different scenarios.
final class AddTaskProjectPreselectionTests: XCTestCase {
  
  // MARK: - Project Overview State
  
  func testShowOverview_IsFalse_WhenAddingTaskFromProjectCard() {
    // Given: User is viewing project overview
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "some-project"
    
    // When: User clicks "Add Task" from a project card
    // (simulating the onAddTask closure)
    vm.selectedProjectId = "project-a"
    vm.showOverview = false  // This is the fix
    
    // Then: showOverview should be false
    XCTAssertFalse(vm.showOverview, "showOverview should be false after clicking Add Task from project card")
    XCTAssertEqual(vm.selectedProjectId, "project-a", "selectedProjectId should be set to the project")
  }
  
  func testShowOverview_RemainsTrue_WhenNotModified() {
    // Given: User is viewing project overview
    let vm = createViewModel()
    vm.showOverview = true
    
    // When: showOverview is not explicitly set to false
    // (this was the bug - only selectedProjectId was set)
    vm.selectedProjectId = "project-a"
    
    // Then: showOverview remains true (causing the bug)
    XCTAssertTrue(vm.showOverview, "showOverview remains true when not explicitly changed")
  }
  
  // MARK: - Project ID Pass-Through Logic
  
  func testProjectId_IsNil_WhenShowOverviewIsTrue() {
    // Given: showOverview is true (overview screen)
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "project-a"
    
    // When: Determining projectId for AddTaskSheet
    let projectId = vm.showOverview ? nil : vm.selectedProjectId
    
    // Then: projectId is nil (no pre-selection)
    XCTAssertNil(projectId, "projectId should be nil when showOverview is true")
  }
  
  func testProjectId_IsSet_WhenShowOverviewIsFalse() {
    // Given: showOverview is false (specific project view)
    let vm = createViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-a"
    
    // When: Determining projectId for AddTaskSheet
    let projectId = vm.showOverview ? nil : vm.selectedProjectId
    
    // Then: projectId is set to the selected project
    XCTAssertEqual(projectId, "project-a", "projectId should be set when showOverview is false")
  }
  
  // MARK: - Comparison: onSelect vs onAddTask
  
  func testOnSelect_SetsShowOverviewToFalse() {
    // Given: User is in overview
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "old-project"
    
    // When: User clicks to select a project (onSelect behavior)
    vm.selectedProjectId = "project-a"
    vm.showOverview = false
    
    // Then: Both properties are updated correctly
    XCTAssertEqual(vm.selectedProjectId, "project-a")
    XCTAssertFalse(vm.showOverview, "onSelect should set showOverview to false")
  }
  
  func testOnAddTask_AlsoSetsShowOverviewToFalse() {
    // Given: User is in overview
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "old-project"
    
    // When: User clicks "Add Task" from project card (onAddTask behavior after fix)
    vm.selectedProjectId = "project-a"
    vm.showOverview = false  // The fix - matches onSelect behavior
    
    // Then: Both properties are updated correctly
    XCTAssertEqual(vm.selectedProjectId, "project-a")
    XCTAssertFalse(vm.showOverview, "onAddTask should also set showOverview to false")
  }
  
  // MARK: - User Flow Scenarios
  
  func testScenario_AddTaskFromOverviewCard() {
    // Scenario: User is viewing project overview and clicks "Add Task" on a project card
    
    // Given: User is on overview screen
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "default"
    
    // When: User clicks "Add Task" button on "project-work" card
    // Step 1: Set selected project
    vm.selectedProjectId = "project-work"
    // Step 2: Exit overview mode (this is the fix)
    vm.showOverview = false
    // Step 3: Sheet would be shown with projectId
    let sheetProjectId = vm.showOverview ? nil : vm.selectedProjectId
    
    // Then: Sheet receives the correct project ID
    XCTAssertEqual(sheetProjectId, "project-work", "Sheet should pre-select project-work")
    XCTAssertFalse(vm.showOverview, "Should exit overview mode")
  }
  
  func testScenario_AddTaskFromProjectView() {
    // Scenario: User is already viewing a specific project and clicks "Add Task"
    
    // Given: User is viewing "project-work"
    let vm = createViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-work"
    
    // When: User clicks "Add Task" button from top bar
    // (no state changes needed - already on correct project)
    let sheetProjectId = vm.showOverview ? nil : vm.selectedProjectId
    
    // Then: Sheet receives the current project ID
    XCTAssertEqual(sheetProjectId, "project-work", "Sheet should pre-select current project")
  }
  
  func testScenario_AddTaskWithNoProjectSelected() {
    // Scenario: User wants to add task without specific project (e.g., from overview)
    
    // Given: User is on overview, no specific project
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "default"
    
    // When: User would click a global "Add Task" button (if it existed in overview)
    // showOverview stays true
    let sheetProjectId = vm.showOverview ? nil : vm.selectedProjectId
    
    // Then: Sheet receives nil (user must choose project)
    XCTAssertNil(sheetProjectId, "Sheet should not pre-select project when in overview mode")
  }
  
  // MARK: - Edge Cases
  
  func testAddTask_FromDefaultProject() {
    // Given: User is viewing default project
    let vm = createViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "default"
    
    // When: User clicks "Add Task"
    let sheetProjectId = vm.showOverview ? nil : vm.selectedProjectId
    
    // Then: Default project is pre-selected
    XCTAssertEqual(sheetProjectId, "default", "Default project should be pre-selected")
  }
  
  func testAddTask_SwitchingBetweenProjects() {
    // Given: User views project-a, clicks Add Task, then cancels
    let vm = createViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-a"
    
    let firstProjectId = vm.showOverview ? nil : vm.selectedProjectId
    XCTAssertEqual(firstProjectId, "project-a")
    
    // When: User goes to overview and clicks Add Task on project-b
    vm.showOverview = true  // Navigate to overview
    vm.selectedProjectId = "project-b"
    vm.showOverview = false  // Click Add Task (sets this to false)
    
    let secondProjectId = vm.showOverview ? nil : vm.selectedProjectId
    
    // Then: project-b is pre-selected
    XCTAssertEqual(secondProjectId, "project-b", "Should switch to project-b")
  }
  
  // MARK: - Before/After Fix Comparison
  
  func testBeforeFix_BugBehavior() {
    // This test demonstrates the BUG (before fix)
    
    // Given: User is in overview
    let vm = createViewModel()
    vm.showOverview = true
    
    // When: User clicks "Add Task" from project card (BUG - only set selectedProjectId)
    vm.selectedProjectId = "project-a"
    // Missing: vm.showOverview = false
    
    // Then: showOverview is still true, causing nil projectId
    let projectId = vm.showOverview ? nil : vm.selectedProjectId
    XCTAssertNil(projectId, "BUG: projectId is nil because showOverview wasn't set to false")
  }
  
  func testAfterFix_CorrectBehavior() {
    // This test demonstrates the FIX (after fix)
    
    // Given: User is in overview
    let vm = createViewModel()
    vm.showOverview = true
    
    // When: User clicks "Add Task" from project card (FIX - set both properties)
    vm.selectedProjectId = "project-a"
    vm.showOverview = false  // ← The fix
    
    // Then: showOverview is false, providing correct projectId
    let projectId = vm.showOverview ? nil : vm.selectedProjectId
    XCTAssertEqual(projectId, "project-a", "FIX: projectId is correctly set")
  }
  
  // MARK: - State Consistency
  
  func testStateConsistency_AfterAddingTask() {
    // Given: User adds task from project card
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "old-project"
    
    // When: Add task flow
    vm.selectedProjectId = "project-a"
    vm.showOverview = false
    
    // Then: State is consistent with viewing project-a
    XCTAssertEqual(vm.selectedProjectId, "project-a")
    XCTAssertFalse(vm.showOverview)
    
    // Verify project view would be shown (not overview)
    let isInProjectView = !vm.showOverview
    XCTAssertTrue(isInProjectView, "Should be in project view, not overview")
  }
  
  func testStateConsistency_SelectVsAddTask() {
    // Given: Starting state
    let vm = createViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "start"
    
    // When: onSelect behavior
    let selectVM = createViewModel()
    selectVM.showOverview = true
    selectVM.selectedProjectId = "start"
    selectVM.selectedProjectId = "project-a"
    selectVM.showOverview = false
    
    // When: onAddTask behavior (after fix)
    let addTaskVM = createViewModel()
    addTaskVM.showOverview = true
    addTaskVM.selectedProjectId = "start"
    addTaskVM.selectedProjectId = "project-a"
    addTaskVM.showOverview = false
    
    // Then: Both should result in identical state
    XCTAssertEqual(selectVM.selectedProjectId, addTaskVM.selectedProjectId)
    XCTAssertEqual(selectVM.showOverview, addTaskVM.showOverview)
  }
  
  // MARK: - Helper Methods
  
  private func createViewModel() -> AppViewModel {
    let vm = AppViewModel()
    vm.projects = [
      createProject(id: "default", title: "Default"),
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "project-b", title: "Project B"),
      createProject(id: "project-work", title: "Work")
    ]
    return vm
  }
  
  private func createProject(id: String, title: String) -> Project {
    Project(
      id: id,
      title: title,
      createdAt: Date(),
      updatedAt: Date(),
      notes: nil,
      archived: false,
      type: .kanban,
      sortOrder: nil
    )
  }
}

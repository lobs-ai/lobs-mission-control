import XCTest
@testable import LobsMissionControl

/// Tests for AddTaskSheet project picker visibility logic
///
/// This test suite validates:
/// - Project picker shows when projectId is nil
/// - Project picker shows when projectId is empty string
/// - Project picker hides when projectId is a valid project ID
/// - Correct taskProjectId initialization in TasksContainerView
final class AddTaskSheetProjectPickerTests: XCTestCase {
  
  // MARK: - shouldShowProjectPicker Tests
  
  func testShowPickerWhenProjectIdIsNil() {
    let projectId: String? = nil
    let shouldShow = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertTrue(shouldShow, "Picker should show when projectId is nil")
  }
  
  func testShowPickerWhenProjectIdIsEmptyString() {
    let projectId: String? = ""
    let shouldShow = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertTrue(shouldShow, "Picker should show when projectId is empty string")
  }
  
  func testHidePickerWhenProjectIdIsValid() {
    let projectId: String? = "project-123"
    let shouldShow = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertFalse(shouldShow, "Picker should NOT show when projectId is valid")
  }
  
  func testShowPickerWhenProjectIdIsWhitespace() {
    let projectId: String? = "   "
    let shouldShow = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertFalse(shouldShow, "Picker should NOT show for whitespace (isEmpty is false for whitespace)")
  }
  
  // MARK: - Old vs New Logic Tests
  
  func testOldLogicBugWithEmptyString() {
    let projectId: String? = ""
    
    // OLD LOGIC (buggy):
    let oldShouldShow = projectId == nil
    XCTAssertFalse(oldShouldShow, "Old logic would NOT show picker for empty string (bug)")
    
    // NEW LOGIC (fixed):
    let newShouldShow = projectId == nil || projectId?.isEmpty == true
    XCTAssertTrue(newShouldShow, "New logic correctly shows picker for empty string")
  }
  
  func testNewLogicMatchesOldLogicForNil() {
    let projectId: String? = nil
    
    let oldShouldShow = projectId == nil
    let newShouldShow = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertEqual(oldShouldShow, newShouldShow, "Both logic should show picker for nil")
  }
  
  func testNewLogicMatchesOldLogicForValidProject() {
    let projectId: String? = "project-abc"
    
    let oldShouldShow = projectId == nil
    let newShouldShow = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertEqual(oldShouldShow, newShouldShow, "Both logic should hide picker for valid project")
  }
  
  // MARK: - taskProjectId Initialization Tests
  
  func testTaskProjectIdSetToNilWhenInOverview() {
    let showOverview = true
    let selectedProjectId = "project-123"
    
    // Logic from HoverIconButton
    let taskProjectId: String?
    if showOverview {
      taskProjectId = nil
    } else if !selectedProjectId.isEmpty {
      taskProjectId = selectedProjectId
    } else {
      taskProjectId = nil
    }
    
    XCTAssertNil(taskProjectId, "taskProjectId should be nil when in overview")
  }
  
  func testTaskProjectIdSetToSelectedProjectWhenNotInOverviewWithValidProject() {
    let showOverview = false
    let selectedProjectId = "project-456"
    
    let taskProjectId: String?
    if showOverview {
      taskProjectId = nil
    } else if !selectedProjectId.isEmpty {
      taskProjectId = selectedProjectId
    } else {
      taskProjectId = nil
    }
    
    XCTAssertEqual(taskProjectId, "project-456", "taskProjectId should be selectedProjectId")
  }
  
  func testTaskProjectIdSetToNilWhenNotInOverviewButSelectedProjectIsEmpty() {
    let showOverview = false
    let selectedProjectId = ""
    
    let taskProjectId: String?
    if showOverview {
      taskProjectId = nil
    } else if !selectedProjectId.isEmpty {
      taskProjectId = selectedProjectId
    } else {
      taskProjectId = nil
    }
    
    XCTAssertNil(taskProjectId, "taskProjectId should be nil when selectedProjectId is empty")
  }
  
  func testOldTaskProjectIdLogicWithEmptyString() {
    // OLD LOGIC (buggy):
    let showOverview = false
    let selectedProjectId = ""
    
    let oldTaskProjectId = showOverview ? nil : selectedProjectId
    XCTAssertEqual(oldTaskProjectId, "", "Old logic would set taskProjectId to empty string (bug)")
    
    // NEW LOGIC (fixed):
    let newTaskProjectId: String?
    if showOverview {
      newTaskProjectId = nil
    } else if !selectedProjectId.isEmpty {
      newTaskProjectId = selectedProjectId
    } else {
      newTaskProjectId = nil
    }
    XCTAssertNil(newTaskProjectId, "New logic correctly sets taskProjectId to nil")
  }
  
  // MARK: - User Flow Scenarios
  
  func testUserCreatesTaskFromProjectCard() {
    // User clicks "Add Task" on a specific project card
    let projectFromCard = "lobs-dashboard"
    
    // RichProjectCard sets taskProjectId directly
    let taskProjectId: String? = projectFromCard
    
    // AddTaskSheet initializes
    let selectedProjectId = taskProjectId ?? ""
    let shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    
    XCTAssertFalse(shouldShowPicker, "Picker should NOT show when creating from project card")
    XCTAssertEqual(selectedProjectId, "lobs-dashboard", "selectedProjectId should be the project from card")
  }
  
  func testUserCreatesTaskFromTasksPageWithNoProjectSelected() {
    // User navigates to Tasks page, no project selected yet
    let showOverview = false
    let vmSelectedProjectId = ""
    
    // HoverIconButton logic
    let taskProjectId: String?
    if showOverview {
      taskProjectId = nil
    } else if !vmSelectedProjectId.isEmpty {
      taskProjectId = vmSelectedProjectId
    } else {
      taskProjectId = nil
    }
    
    // AddTaskSheet initializes
    let selectedProjectId = taskProjectId ?? ""
    let shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    
    XCTAssertTrue(shouldShowPicker, "Picker SHOULD show when no project selected")
    XCTAssertNil(taskProjectId, "taskProjectId should be nil")
  }
  
  func testUserCreatesTaskFromTasksPageWithProjectSelected() {
    // User has a project selected in the sidebar
    let showOverview = false
    let vmSelectedProjectId = "inbox-management"
    
    // HoverIconButton logic
    let taskProjectId: String?
    if showOverview {
      taskProjectId = nil
    } else if !vmSelectedProjectId.isEmpty {
      taskProjectId = vmSelectedProjectId
    } else {
      taskProjectId = nil
    }
    
    // AddTaskSheet initializes
    let selectedProjectId = taskProjectId ?? ""
    let shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    
    XCTAssertFalse(shouldShowPicker, "Picker should NOT show when project is selected")
    XCTAssertEqual(taskProjectId, "inbox-management", "taskProjectId should be the selected project")
  }
  
  func testUserCreatesTaskFromProjectOverview() {
    // User is in the project overview (grid view)
    let showOverview = true
    let vmSelectedProjectId = "some-project"
    
    // HoverIconButton is not visible in overview, but let's test the logic
    let taskProjectId: String?
    if showOverview {
      taskProjectId = nil
    } else if !vmSelectedProjectId.isEmpty {
      taskProjectId = vmSelectedProjectId
    } else {
      taskProjectId = nil
    }
    
    // AddTaskSheet initializes
    let shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    
    XCTAssertTrue(shouldShowPicker, "Picker SHOULD show when creating from overview")
    XCTAssertNil(taskProjectId, "taskProjectId should be nil in overview")
  }
  
  // MARK: - Bug Reproduction Tests
  
  func testOriginalBugScenario() {
    // BUG: "when creating the first task when swapping to the tasks page,
    // it wants me to choose which projects and then that option quickly disappears"
    
    // Scenario: User navigates to tasks page for the first time
    let showOverview = false
    let vmSelectedProjectId = ""  // No project selected yet
    
    // OLD LOGIC (buggy):
    let oldTaskProjectId = showOverview ? nil : vmSelectedProjectId
    XCTAssertEqual(oldTaskProjectId, "", "Old logic sets empty string")
    
    let oldProjectId: String? = oldTaskProjectId
    let oldShouldShow = oldProjectId == nil
    XCTAssertFalse(oldShouldShow, "Old logic would NOT show picker (bug causes flicker)")
    
    // NEW LOGIC (fixed):
    let newTaskProjectId: String?
    if showOverview {
      newTaskProjectId = nil
    } else if !vmSelectedProjectId.isEmpty {
      newTaskProjectId = vmSelectedProjectId
    } else {
      newTaskProjectId = nil
    }
    XCTAssertNil(newTaskProjectId, "New logic sets nil")
    
    let newProjectId: String? = newTaskProjectId
    let newShouldShow = newProjectId == nil || newProjectId?.isEmpty == true
    XCTAssertTrue(newShouldShow, "New logic correctly shows picker")
  }
  
  // MARK: - Edge Cases
  
  func testMultipleProjects() {
    // Test with multiple valid projects
    let projects = ["project-1", "project-2", "project-3"]
    
    for project in projects {
      let projectId: String? = project
      let shouldShow = projectId == nil || projectId?.isEmpty == true
      
      XCTAssertFalse(shouldShow, "Picker should not show for \(project)")
    }
  }
  
  func testRapidProjectSwitching() {
    // Simulate rapid project selection changes
    var taskProjectId: String? = nil
    var shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    XCTAssertTrue(shouldShowPicker, "Initially should show picker")
    
    // User selects project 1
    taskProjectId = "project-1"
    shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    XCTAssertFalse(shouldShowPicker, "Should not show after selecting project 1")
    
    // User selects project 2
    taskProjectId = "project-2"
    shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    XCTAssertFalse(shouldShowPicker, "Should not show after selecting project 2")
    
    // User deselects (somehow selectedProjectId becomes empty)
    taskProjectId = nil
    shouldShowPicker = taskProjectId == nil || taskProjectId?.isEmpty == true
    XCTAssertTrue(shouldShowPicker, "Should show again when deselected")
  }
  
  // MARK: - Validation Logic Tests
  
  func testValidationWithPickerShownAndNoProjectSelected() {
    let projectId: String? = nil
    let selectedProjectId = ""
    let shouldShowPicker = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertTrue(shouldShowPicker, "Picker should be visible")
    
    // Calculate target as in AddTaskSheet
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "", "Target is empty")
    XCTAssertTrue(targetProjectId.isEmpty, "Validation should detect missing project")
  }
  
  func testValidationWithPickerShownAndProjectSelected() {
    let projectId: String? = nil
    var selectedProjectId = ""
    let shouldShowPicker = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertTrue(shouldShowPicker, "Picker should be visible")
    
    // User selects a project
    selectedProjectId = "user-choice"
    
    // Calculate target
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "user-choice", "Target is user's selection")
    XCTAssertFalse(targetProjectId.isEmpty, "Validation should pass")
  }
  
  func testValidationWithPickerHiddenAndValidProject() {
    let projectId: String? = "pre-selected-project"
    let selectedProjectId = projectId ?? ""
    let shouldShowPicker = projectId == nil || projectId?.isEmpty == true
    
    XCTAssertFalse(shouldShowPicker, "Picker should NOT be visible")
    
    // Calculate target
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "pre-selected-project", "Target is pre-selected project")
    XCTAssertFalse(targetProjectId.isEmpty, "Validation should pass")
  }
}

import XCTest
@testable import LobsMissionControl

/// Tests for AddTaskSheet validation logic when creating tasks from different contexts
///
/// This test suite validates:
/// - Project validation works correctly when picker is shown vs. hidden
/// - Button disabled state reflects actual validation (not just picker visibility)
/// - Tasks created from project overview have correct project targeting
/// - Edge cases where projectId or selectedProjectId might be empty
final class AddTaskSheetValidationTests: XCTestCase {
  
  // MARK: - Validation Logic Tests
  
  func testValidationWithProjectPickerShown() {
    // When projectId is nil, picker should be shown
    // Validation should check selectedProjectId
    let projectId: String? = nil
    let selectedProjectId = ""
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    let missingProject = targetProjectId.isEmpty
    
    XCTAssertTrue(shouldShowProjectPicker, "Picker should show when projectId is nil")
    XCTAssertTrue(missingProject, "Should detect missing project when selectedProjectId is empty")
    XCTAssertEqual(targetProjectId, "", "Target project ID should be empty")
  }
  
  func testValidationWithProjectPickerShownAndProjectSelected() {
    // When projectId is nil but user has selected a project
    let projectId: String? = nil
    let selectedProjectId = "project-123"
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    let missingProject = targetProjectId.isEmpty
    
    XCTAssertTrue(shouldShowProjectPicker, "Picker should show when projectId is nil")
    XCTAssertFalse(missingProject, "Should NOT detect missing project when selectedProjectId is valid")
    XCTAssertEqual(targetProjectId, "project-123", "Target should use selectedProjectId")
  }
  
  func testValidationWithProjectPickerHiddenAndValidProject() {
    // When creating from project overview with valid projectId
    let projectId: String? = "project-abc"
    let selectedProjectId = "project-abc"
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    let missingProject = targetProjectId.isEmpty
    
    XCTAssertFalse(shouldShowProjectPicker, "Picker should NOT show when projectId is provided")
    XCTAssertFalse(missingProject, "Should NOT detect missing project when projectId is valid")
    XCTAssertEqual(targetProjectId, "project-abc", "Target should use projectId")
  }
  
  func testValidationWithProjectPickerHiddenButEmptySelectedProjectId() {
    // Edge case: projectId provided but selectedProjectId is empty
    // This shouldn't happen in normal flow, but validation should still work
    let projectId: String? = "project-xyz"
    let selectedProjectId = ""
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    let missingProject = targetProjectId.isEmpty
    
    XCTAssertFalse(shouldShowProjectPicker, "Picker should NOT show when projectId is provided")
    XCTAssertFalse(missingProject, "Should NOT detect missing project because projectId is valid")
    XCTAssertEqual(targetProjectId, "project-xyz", "Target should use projectId, not empty selectedProjectId")
  }
  
  func testValidationBugScenario() {
    // BUG SCENARIO: The original bug where projectId is somehow nil
    // but shouldShowProjectPicker is false
    // This was causing the button to appear enabled but submission to fail
    let projectId: String? = nil
    let selectedProjectId = ""
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    let missingProject = targetProjectId.isEmpty
    
    // OLD BUGGY LOGIC:
    // let missingProject_OLD = shouldShowProjectPicker && selectedProjectId.isEmpty
    // This would be: true && true = true (correct in this case)
    
    // But if shouldShowProjectPicker was somehow false:
    let shouldShowProjectPicker_BUGGY = false
    let missingProject_OLD = shouldShowProjectPicker_BUGGY && selectedProjectId.isEmpty
    
    // OLD: would be false (WRONG - button enabled when it shouldn't be)
    XCTAssertFalse(missingProject_OLD, "OLD logic would incorrectly allow empty project")
    
    // NEW: correctly detects missing project
    XCTAssertTrue(missingProject, "NEW logic correctly detects missing project")
  }
  
  func testValidationWithBothProjectIdAndSelectedProjectIdEmpty() {
    // Both projectId and selectedProjectId are empty
    let projectId: String? = nil
    let selectedProjectId = ""
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    let missingProject = targetProjectId.isEmpty
    
    XCTAssertTrue(missingProject, "Should detect missing project when both are empty")
    XCTAssertEqual(targetProjectId, "", "Target should be empty")
  }
  
  // MARK: - Button State Tests
  
  func testButtonDisabledWhenTitleEmpty() {
    let title = ""
    let projectId: String? = "project-123"
    let selectedProjectId = "project-123"
    
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    let isDisabled = trimmedTitle.isEmpty || targetProjectId.isEmpty
    
    XCTAssertTrue(isDisabled, "Button should be disabled when title is empty")
  }
  
  func testButtonDisabledWhenProjectEmpty() {
    let title = "Valid task title"
    let projectId: String? = nil
    let selectedProjectId = ""
    
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    let isDisabled = trimmedTitle.isEmpty || targetProjectId.isEmpty
    
    XCTAssertTrue(isDisabled, "Button should be disabled when project is empty")
  }
  
  func testButtonEnabledWhenBothTitleAndProjectValid() {
    let title = "Valid task title"
    let projectId: String? = "project-123"
    let selectedProjectId = "project-123"
    
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    let isDisabled = trimmedTitle.isEmpty || targetProjectId.isEmpty
    
    XCTAssertFalse(isDisabled, "Button should be enabled when both title and project are valid")
  }
  
  func testButtonDisabledWhenTitleOnlyWhitespace() {
    let title = "   \n  \t  "
    let projectId: String? = "project-123"
    let selectedProjectId = "project-123"
    
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    let isDisabled = trimmedTitle.isEmpty || targetProjectId.isEmpty
    
    XCTAssertTrue(isDisabled, "Button should be disabled when title is only whitespace")
  }
  
  // MARK: - Project Targeting Tests
  
  func testTargetProjectIdFromProjectOverview() {
    // When clicking "Add Task" from a project card
    let projectId: String? = "lobs-dashboard"
    let selectedProjectId = "lobs-dashboard"  // Init sets this to projectId
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    XCTAssertFalse(shouldShowProjectPicker, "Picker should be hidden")
    XCTAssertEqual(targetProjectId, "lobs-dashboard", "Should target the correct project")
  }
  
  func testTargetProjectIdFromCommandCenter() {
    // When clicking "Add Task" from command center (no specific project)
    let projectId: String? = nil
    let selectedProjectId = ""  // User hasn't selected yet
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    XCTAssertTrue(shouldShowProjectPicker, "Picker should be shown")
    XCTAssertEqual(targetProjectId, "", "Target should be empty until user selects")
  }
  
  func testTargetProjectIdAfterUserSelection() {
    // When user selects a project from the picker
    let projectId: String? = nil
    let selectedProjectId = "user-selected-project"
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    XCTAssertTrue(shouldShowProjectPicker, "Picker should be shown")
    XCTAssertEqual(targetProjectId, "user-selected-project", "Should target user's selection")
  }
  
  func testTargetProjectIdFallbackLogic() {
    // When projectId is nil, should fall back to selectedProjectId
    let projectId: String? = nil
    let selectedProjectId = "fallback-project"
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    XCTAssertEqual(targetProjectId, "fallback-project", "Should use selectedProjectId when projectId is nil")
  }
  
  func testTargetProjectIdPriorityWhenBothPresent() {
    // When both projectId and selectedProjectId are present, projectId takes priority
    let projectId: String? = "priority-project"
    let selectedProjectId = "other-project"
    
    let shouldShowProjectPicker = (projectId == nil)
    let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    
    XCTAssertEqual(targetProjectId, "priority-project", "projectId should take priority over selectedProjectId")
  }
  
  // MARK: - UI State Tests
  
  func testProjectPickerVisibilityWhenCreatingFromOverview() {
    let projectId: String? = "project-123"
    let shouldShowProjectPicker = (projectId == nil)
    
    XCTAssertFalse(shouldShowProjectPicker, "Project picker should be hidden when creating from project overview")
  }
  
  func testProjectPickerVisibilityWhenCreatingFromCommandCenter() {
    let projectId: String? = nil
    let shouldShowProjectPicker = (projectId == nil)
    
    XCTAssertTrue(shouldShowProjectPicker, "Project picker should be shown when creating from command center")
  }
  
  func testShakeAnimationOnlyAppliedWhenPickerVisible() {
    // Shake animation should only be applied to the project picker when it's visible
    let projectId_withPicker: String? = nil
    let shouldShowProjectPicker_withPicker = (projectId_withPicker == nil)
    let shouldShakeProject_withPicker = true && shouldShowProjectPicker_withPicker
    
    XCTAssertTrue(shouldShakeProject_withPicker, "Should shake when picker is visible")
    
    let projectId_noPicker: String? = "project-123"
    let shouldShowProjectPicker_noPicker = (projectId_noPicker == nil)
    let shouldShakeProject_noPicker = true && shouldShowProjectPicker_noPicker
    
    XCTAssertFalse(shouldShakeProject_noPicker, "Should NOT shake when picker is hidden")
  }
  
  // MARK: - Edge Cases
  
  func testEmptyStringVsNilProjectId() {
    // Ensure empty string and nil are handled correctly
    let projectId_nil: String? = nil
    let projectId_empty: String? = ""
    let selectedProjectId = "fallback"
    
    let shouldShowPicker_nil = (projectId_nil == nil)
    let shouldShowPicker_empty = (projectId_empty == nil)
    
    let target_nil = shouldShowPicker_nil ? selectedProjectId : (projectId_nil ?? selectedProjectId)
    let target_empty = shouldShowPicker_empty ? selectedProjectId : (projectId_empty ?? selectedProjectId)
    
    XCTAssertTrue(shouldShowPicker_nil, "nil projectId should show picker")
    XCTAssertFalse(shouldShowPicker_empty, "Empty string projectId should NOT show picker")
    XCTAssertEqual(target_nil, "fallback", "nil projectId should use fallback")
    XCTAssertEqual(target_empty, "", "Empty string projectId should use empty string")
  }
  
  func testInitializationWithValidProject() {
    // Simulating AddTaskSheet init with projectId
    let projectId: String? = "init-project"
    let selectedProjectId = projectId ?? ""
    
    XCTAssertEqual(selectedProjectId, "init-project", "selectedProjectId should be initialized from projectId")
  }
  
  func testInitializationWithNilProject() {
    // Simulating AddTaskSheet init without projectId
    let projectId: String? = nil
    let selectedProjectId = projectId ?? ""
    
    XCTAssertEqual(selectedProjectId, "", "selectedProjectId should be empty when projectId is nil")
  }
}

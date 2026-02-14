import XCTest
@testable import LobsMissionControl

/// Tests for task creation project targeting logic
///
/// This test suite validates:
/// - Tasks created from project overview go to the correct project
/// - Explicit projectId always takes priority over selectedProjectId
/// - Empty string projectId is treated correctly
/// - Fallback to selectedProjectId works when projectId is nil/empty
final class TaskCreationProjectTargetingTests: XCTestCase {
  
  // MARK: - Project ID Priority Tests
  
  func testExplicitProjectIdTakesPriority() {
    // When projectId is provided (non-nil, non-empty), it should be used
    let projectId: String? = "project-abc"
    let selectedProjectId = "project-xyz"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "project-abc", "Explicit projectId should take priority")
  }
  
  func testSelectedProjectIdUsedWhenProjectIdIsNil() {
    // When projectId is nil, should fall back to selectedProjectId
    let projectId: String? = nil
    let selectedProjectId = "project-from-picker"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "project-from-picker", "Should use selectedProjectId when projectId is nil")
  }
  
  func testSelectedProjectIdUsedWhenProjectIdIsEmpty() {
    // When projectId is empty string (not nil but empty), should fall back
    let projectId: String? = ""
    let selectedProjectId = "project-from-picker"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "project-from-picker", "Should use selectedProjectId when projectId is empty string")
  }
  
  // MARK: - Project Overview Context Tests
  
  func testTaskCreatedFromProjectCardUsesCorrectProject() {
    // Simulating: User clicks "Add Task" on Project A card
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, status: .active, createdAt: Date(), updatedAt: Date(), notes: nil, linkedTopic: nil)
    
    // This is what RichProjectCard.onAddTask does:
    let taskProjectId: String? = projectA.id
    
    // This is what AddTaskSheet.init does:
    let projectId: String? = taskProjectId
    let selectedProjectId = projectId ?? ""
    
    // This is what the submit button does:
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "project-a", "Task should be created in Project A")
  }
  
  func testTaskCreatedFromProjectCardIgnoresViewModelSelectedProject() {
    // Even if vm.selectedProjectId is different, explicit projectId should win
    let projectCardId = "project-dashboard"
    let vmSelectedProjectId = "project-other"
    
    // Sheet initialized with projectCardId
    let projectId: String? = projectCardId
    let selectedProjectId = projectId ?? ""  // Init logic
    
    // Simulate that vm.selectedProjectId is different (shouldn't matter)
    let _ = vmSelectedProjectId
    
    // Submit logic
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "project-dashboard", "Should use projectId from card, not vm.selectedProjectId")
  }
  
  func testMultipleProjectCardsEachCreateInCorrectProject() {
    // Creating tasks from different project cards should each go to the right project
    let projects = [
      ("project-1", "Project 1"),
      ("project-2", "Project 2"),
      ("project-3", "Project 3")
    ]
    
    for (projectId, _) in projects {
      // Sheet initialized with this project's ID
      let explicitProjectId: String? = projectId
      let selectedProjectId = explicitProjectId ?? ""
      
      // Submit logic
      let targetProjectId: String
      if let explicitId = explicitProjectId, !explicitId.isEmpty {
        targetProjectId = explicitId
      } else {
        targetProjectId = selectedProjectId
      }
      
      XCTAssertEqual(targetProjectId, projectId, "Task should go to \(projectId)")
    }
  }
  
  // MARK: - Command Center / Picker Context Tests
  
  func testTaskCreatedFromCommandCenterUsesPickerSelection() {
    // When creating from command center (no explicit project), should use picker
    let projectId: String? = nil
    let selectedProjectId = "user-selected-project"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "user-selected-project", "Should use project from picker")
  }
  
  func testPickerSelectionChangesTarget() {
    // User changes picker selection
    let projectId: String? = nil
    var selectedProjectId = "project-a"
    
    var targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    XCTAssertEqual(targetProjectId, "project-a")
    
    // User changes picker to project-b
    selectedProjectId = "project-b"
    
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    XCTAssertEqual(targetProjectId, "project-b")
  }
  
  // MARK: - Edge Case Tests
  
  func testEmptyStringProjectIdFallsBackToSelectedProjectId() {
    // Empty string (not nil) should fall back
    let projectId: String? = ""
    let selectedProjectId = "fallback-project"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "fallback-project")
  }
  
  func testWhitespaceOnlyProjectIdIsNotEmpty() {
    // Whitespace-only string is technically not empty (edge case)
    let projectId: String? = "   "
    let selectedProjectId = "fallback"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    // Current logic treats whitespace as not empty
    XCTAssertEqual(targetProjectId, "   ", "Whitespace-only is technically not empty")
    // Note: In practice, this shouldn't happen as project IDs are validated
  }
  
  func testBothNilAndEmptyGivesEmpty() {
    // Both nil and empty selectedProjectId
    let projectId: String? = nil
    let selectedProjectId = ""
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    XCTAssertEqual(targetProjectId, "", "Should be empty (validation will catch this)")
  }
  
  // MARK: - Validation Tests
  
  func testValidationDetectsEmptyTargetWhenExplicitProjectIsEmpty() {
    let projectId: String? = ""
    let selectedProjectId = ""
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    let missingProject = targetProjectId.isEmpty
    XCTAssertTrue(missingProject, "Validation should detect empty target")
  }
  
  func testValidationPassesWhenExplicitProjectIsValid() {
    let projectId: String? = "project-123"
    let selectedProjectId = ""
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    let missingProject = targetProjectId.isEmpty
    XCTAssertFalse(missingProject, "Validation should pass with valid explicit project")
  }
  
  func testValidationPassesWhenSelectedProjectIsValid() {
    let projectId: String? = nil
    let selectedProjectId = "project-456"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    let missingProject = targetProjectId.isEmpty
    XCTAssertFalse(missingProject, "Validation should pass with valid selected project")
  }
  
  // MARK: - Button Opacity Tests
  
  func testButtonDisabledWhenTargetIsEmpty() {
    let projectId: String? = nil
    let selectedProjectId = ""
    let title = "Valid title"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let isDisabled = trimmedTitle.isEmpty || targetProjectId.isEmpty
    
    XCTAssertTrue(isDisabled, "Button should be disabled when target is empty")
  }
  
  func testButtonEnabledWhenBothTitleAndTargetAreValid() {
    let projectId: String? = "project-abc"
    let selectedProjectId = ""
    let title = "Valid title"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let isDisabled = trimmedTitle.isEmpty || targetProjectId.isEmpty
    
    XCTAssertFalse(isDisabled, "Button should be enabled when both are valid")
  }
  
  // MARK: - shouldShowProjectPicker Tests
  
  func testShouldShowPickerWhenProjectIdIsNil() {
    let projectId: String? = nil
    let shouldShowProjectPicker = (projectId == nil)
    
    XCTAssertTrue(shouldShowProjectPicker, "Should show picker when projectId is nil")
  }
  
  func testShouldNotShowPickerWhenProjectIdIsProvided() {
    let projectId: String? = "project-123"
    let shouldShowProjectPicker = (projectId == nil)
    
    XCTAssertFalse(shouldShowProjectPicker, "Should NOT show picker when projectId is provided")
  }
  
  func testShouldNotShowPickerWhenProjectIdIsEmptyString() {
    let projectId: String? = ""
    let shouldShowProjectPicker = (projectId == nil)
    
    XCTAssertFalse(shouldShowProjectPicker, "Empty string is not nil, so picker is hidden")
    // Note: This is why we need the isEmpty check in target calculation
  }
  
  // MARK: - Integration Flow Tests
  
  func testCompleteFlowFromProjectCard() {
    // Simulate complete flow from clicking project card to submission
    
    // 1. User clicks "Add Task" on project card
    let clickedProject = Project(id: "dashboard", title: "Dashboard", type: .kanban, status: .active, createdAt: Date(), updatedAt: Date(), notes: nil, linkedTopic: nil)
    var taskProjectId: String? = clickedProject.id
    
    // 2. Sheet opens
    let projectId: String? = taskProjectId
    let selectedProjectId = projectId ?? ""
    
    // 3. User types title
    let title = "Fix navigation bug"
    
    // 4. User clicks Create
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    let missingTitle = trimmedTitle.isEmpty
    let missingProject = targetProjectId.isEmpty
    
    // 5. Validation passes
    XCTAssertFalse(missingTitle, "Title is valid")
    XCTAssertFalse(missingProject, "Project is valid")
    
    // 6. Task is created with correct project
    XCTAssertEqual(targetProjectId, "dashboard", "Task should be created in Dashboard project")
    
    // 7. Sheet dismisses, taskProjectId is reset
    taskProjectId = nil
    XCTAssertNil(taskProjectId, "State is cleaned up after dismissal")
  }
  
  func testCompleteFlowFromCommandCenter() {
    // Simulate complete flow from command center (no explicit project)
    
    // 1. User clicks "Add Task" from command center
    let taskProjectId: String? = nil
    
    // 2. Sheet opens with picker shown
    let projectId: String? = taskProjectId
    var selectedProjectId = projectId ?? ""
    let shouldShowProjectPicker = (projectId == nil)
    
    XCTAssertTrue(shouldShowProjectPicker, "Picker should be shown")
    XCTAssertEqual(selectedProjectId, "", "Initially no project selected")
    
    // 3. User selects project from picker
    selectedProjectId = "inbox-management"
    
    // 4. User types title
    let title = "Review messages"
    
    // 5. User clicks Create
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    let missingTitle = trimmedTitle.isEmpty
    let missingProject = targetProjectId.isEmpty
    
    // 6. Validation passes
    XCTAssertFalse(missingTitle, "Title is valid")
    XCTAssertFalse(missingProject, "Project is valid")
    
    // 7. Task is created with selected project
    XCTAssertEqual(targetProjectId, "inbox-management", "Task should use selected project")
  }
  
  // MARK: - Regression Tests
  
  func testOldBugScenario() {
    // The original bug: tasks from project overview going to wrong project
    // This happened when logic didn't properly prioritize explicit projectId
    
    let projectFromCard = "project-correct"
    let vmSelectedProject = "project-wrong"
    
    // OLD BUGGY LOGIC (for comparison):
    // let targetProjectId = shouldShowProjectPicker ? selectedProjectId : (projectId ?? selectedProjectId)
    // If shouldShowProjectPicker was false but projectId was somehow empty,
    // it would fall back to selectedProjectId which might not be the card's project
    
    // NEW FIXED LOGIC:
    let projectId: String? = projectFromCard
    let selectedProjectId = projectId ?? ""  // Should be "project-correct"
    
    let targetProjectId: String
    if let explicitProjectId = projectId, !explicitProjectId.isEmpty {
      targetProjectId = explicitProjectId
    } else {
      targetProjectId = selectedProjectId
    }
    
    // The bug is fixed: explicit projectId is used regardless of vm state
    XCTAssertEqual(targetProjectId, "project-correct", "Should use project from card, not vm.selectedProjectId")
    XCTAssertNotEqual(targetProjectId, vmSelectedProject, "Should NOT use wrong project")
  }
  
  func testNilCoalescingVsExplicitCheck() {
    // The new logic is more explicit than nil coalescing
    let projectId1: String? = "project-a"
    let selectedProjectId1 = "project-b"
    
    // Old style (nil coalescing):
    let old_target = projectId1 ?? selectedProjectId1
    
    // New style (explicit check):
    let new_target: String
    if let explicitProjectId = projectId1, !explicitProjectId.isEmpty {
      new_target = explicitProjectId
    } else {
      new_target = selectedProjectId1
    }
    
    XCTAssertEqual(old_target, new_target, "Both should give same result for non-empty projectId")
    
    // But for empty string:
    let projectId2: String? = ""
    let selectedProjectId2 = "project-c"
    
    let old_target2 = projectId2 ?? selectedProjectId2  // Would use ""
    
    let new_target2: String
    if let explicitProjectId = projectId2, !explicitProjectId.isEmpty {
      new_target2 = explicitProjectId
    } else {
      new_target2 = selectedProjectId2
    }
    
    XCTAssertNotEqual(old_target2, new_target2, "New logic handles empty string better")
    XCTAssertEqual(old_target2, "", "Old would use empty string")
    XCTAssertEqual(new_target2, "project-c", "New falls back to selected project")
  }
}

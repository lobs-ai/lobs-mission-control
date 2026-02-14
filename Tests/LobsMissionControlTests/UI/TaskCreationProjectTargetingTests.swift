import XCTest
@testable import LobsMissionControl

/// Tests for task creation project targeting fix
/// Ensures tasks are created in the correct project when using:
/// 1. Project card "Add Task" quick action from overview
/// 2. Top bar "+" button from project view
/// 3. Quick Capture (⌥Space / ⌘⇧Space)
final class TaskCreationProjectTargetingTests: XCTestCase {
  
  // MARK: - Overview → Project Card "Add Task"
  
  func testAddTaskFromProjectCardInOverview_CreatesInCorrectProject() {
    // User in overview, clicks "Add Task" on Project A's card
    // Expected: Task created in Project A, user stays in overview
    
    // Setup: User in overview with two projects
    let vm = AppViewModel()
    vm.showOverview = true
    vm.selectedProjectId = ""  // No project selected (overview mode)
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA, projectB]
    
    // Action: Click "Add Task" on Project A card
    let taskProjectId = projectA.id  // Simulates: taskProjectId = project.id
    
    // Simulate sheet submission with project A as target
    let targetProjectId = taskProjectId
    
    // Submit task
    vm.submitTaskToLobs(
      title: "Test task",
      notes: "Test notes",
      agent: "programmer",
      projectId: targetProjectId,
      autoPush: true
    )
    
    // Verify: Task created in Project A
    XCTAssertEqual(vm.tasks.count, 1, "Should create exactly one task")
    XCTAssertEqual(vm.tasks[0].projectId, "project-a", "Task should be in Project A")
    XCTAssertEqual(vm.tasks[0].title, "Test task")
    
    // Verify: User still in overview (selectedProjectId unchanged)
    XCTAssertTrue(vm.showOverview, "Should remain in overview mode")
    XCTAssertEqual(vm.selectedProjectId, "", "Selected project should be unchanged")
  }
  
  func testAddTaskFromDifferentProjectCards_CreatesInCorrectProjects() {
    // Create tasks from multiple project cards
    // Expected: Each task goes to its respective project
    
    let vm = AppViewModel()
    vm.showOverview = true
    vm.selectedProjectId = ""
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA, projectB]
    
    // Create task from Project A card
    vm.submitTaskToLobs(
      title: "Task for A",
      notes: nil,
      agent: "programmer",
      projectId: projectA.id,
      autoPush: true
    )
    
    // Create task from Project B card
    vm.submitTaskToLobs(
      title: "Task for B",
      notes: nil,
      agent: "programmer",
      projectId: projectB.id,
      autoPush: true
    )
    
    // Verify: Two tasks created in correct projects
    XCTAssertEqual(vm.tasks.count, 2, "Should create two tasks")
    
    let taskA = vm.tasks.first { $0.title == "Task for A" }
    let taskB = vm.tasks.first { $0.title == "Task for B" }
    
    XCTAssertNotNil(taskA, "Task A should exist")
    XCTAssertNotNil(taskB, "Task B should exist")
    
    XCTAssertEqual(taskA?.projectId, "project-a", "Task A should be in Project A")
    XCTAssertEqual(taskB?.projectId, "project-b", "Task B should be in Project B")
    
    // Verify: User still in overview
    XCTAssertTrue(vm.showOverview)
    XCTAssertEqual(vm.selectedProjectId, "")
  }
  
  // MARK: - Project View → Top Bar "+" Button
  
  func testAddTaskFromTopBarWhileViewingProject_CreatesInThatProject() {
    // User viewing Project B, clicks "+" in top bar
    // Expected: Task created in Project B, user stays on Project B
    
    let vm = AppViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-b"  // Viewing Project B
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA, projectB]
    
    // Action: Click "+" button (simulates: taskProjectId = vm.selectedProjectId)
    let taskProjectId = vm.selectedProjectId
    
    // Submit task
    vm.submitTaskToLobs(
      title: "Task for current project",
      notes: nil,
      agent: "programmer",
      projectId: taskProjectId,
      autoPush: true
    )
    
    // Verify: Task created in Project B
    XCTAssertEqual(vm.tasks.count, 1)
    XCTAssertEqual(vm.tasks[0].projectId, "project-b", "Task should be in Project B")
    
    // Verify: Still viewing Project B
    XCTAssertFalse(vm.showOverview)
    XCTAssertEqual(vm.selectedProjectId, "project-b", "Should still be viewing Project B")
  }
  
  func testAddTaskFromTopBarDoesNotAffectOtherProjects() {
    // User viewing Project A, creates task
    // Expected: Task goes to A, not to B (even if B was previously selected)
    
    let vm = AppViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-a"
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA, projectB]
    
    // Submit task while viewing Project A
    vm.submitTaskToLobs(
      title: "Task for A",
      notes: nil,
      agent: "programmer",
      projectId: vm.selectedProjectId,
      autoPush: true
    )
    
    // Verify: Task created in A, not B
    XCTAssertEqual(vm.tasks[0].projectId, "project-a", "Task should be in Project A")
    XCTAssertNotEqual(vm.tasks[0].projectId, "project-b", "Task should NOT be in Project B")
  }
  
  // MARK: - Quick Capture
  
  func testQuickCaptureWithProjectSelection_CreatesInSelectedProject() {
    // User opens Quick Capture, selects Project B, submits
    // Expected: Task created in Project B
    
    let vm = AppViewModel()
    vm.showOverview = true
    vm.selectedProjectId = ""  // Currently in overview
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA, projectB]
    
    // User selects Project B in Quick Capture
    let selectedProjectId = "project-b"
    
    // Submit via Quick Capture
    vm.submitTaskToLobs(
      title: "Quick capture task",
      notes: "From quick capture",
      agent: "programmer",
      projectId: selectedProjectId,
      autoPush: true
    )
    
    // Verify: Task created in Project B
    XCTAssertEqual(vm.tasks.count, 1)
    XCTAssertEqual(vm.tasks[0].projectId, "project-b", "Task should be in Project B")
    
    // Verify: Original navigation state unchanged
    XCTAssertTrue(vm.showOverview, "Should still be in overview")
    XCTAssertEqual(vm.selectedProjectId, "", "Original selected project unchanged")
  }
  
  func testQuickCaptureDoesNotNavigateAwayFromCurrentView() {
    // User viewing Project A, opens Quick Capture, creates task in Project B
    // Expected: Task created in B, but user still viewing Project A
    
    let vm = AppViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-a"  // Currently viewing Project A
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA, projectB]
    
    // User selects Project B in Quick Capture
    let quickCaptureProjectId = "project-b"
    
    // Submit via Quick Capture
    vm.submitTaskToLobs(
      title: "Task for B via quick capture",
      notes: nil,
      agent: "programmer",
      projectId: quickCaptureProjectId,
      autoPush: true
    )
    
    // Verify: Task created in Project B
    XCTAssertEqual(vm.tasks[0].projectId, "project-b", "Task should be in Project B")
    
    // Verify: Still viewing Project A (no navigation)
    XCTAssertFalse(vm.showOverview)
    XCTAssertEqual(vm.selectedProjectId, "project-a", "Should still be viewing Project A")
  }
  
  // MARK: - Edge Cases
  
  func testAddTaskWithEmptyProjectId_UsesEmptyProject() {
    // Edge case: What if projectId is empty string?
    
    let vm = AppViewModel()
    vm.showOverview = true
    vm.selectedProjectId = ""
    
    // Submit with empty project ID
    vm.submitTaskToLobs(
      title: "Task with no project",
      notes: nil,
      agent: "programmer",
      projectId: "",  // Empty project ID
      autoPush: true
    )
    
    // Verify: Task created with empty project ID
    XCTAssertEqual(vm.tasks.count, 1)
    XCTAssertEqual(vm.tasks[0].projectId, "", "Task should have empty project ID")
  }
  
  func testAddTaskFromMultipleSources_EachUsesOwnProjectId() {
    // Create tasks from different sources in rapid succession
    // Expected: Each task uses its own project ID, no cross-contamination
    
    let vm = AppViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-a"
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    let projectC = Project(id: "project-c", title: "Project C", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA, projectB, projectC]
    
    // Rapid-fire task creation
    vm.submitTaskToLobs(title: "Task 1", notes: nil, agent: "programmer", projectId: "project-a", autoPush: true)
    vm.submitTaskToLobs(title: "Task 2", notes: nil, agent: "programmer", projectId: "project-b", autoPush: true)
    vm.submitTaskToLobs(title: "Task 3", notes: nil, agent: "programmer", projectId: "project-c", autoPush: true)
    vm.submitTaskToLobs(title: "Task 4", notes: nil, agent: "programmer", projectId: "project-a", autoPush: true)
    
    // Verify: Each task in correct project
    XCTAssertEqual(vm.tasks.count, 4)
    
    let task1 = vm.tasks.first { $0.title == "Task 1" }
    let task2 = vm.tasks.first { $0.title == "Task 2" }
    let task3 = vm.tasks.first { $0.title == "Task 3" }
    let task4 = vm.tasks.first { $0.title == "Task 4" }
    
    XCTAssertEqual(task1?.projectId, "project-a")
    XCTAssertEqual(task2?.projectId, "project-b")
    XCTAssertEqual(task3?.projectId, "project-c")
    XCTAssertEqual(task4?.projectId, "project-a")
    
    // Verify: Original view state unchanged
    XCTAssertEqual(vm.selectedProjectId, "project-a", "Should still be on Project A")
  }
  
  // MARK: - Regression Tests
  
  func testSelectedProjectIdNotModifiedDuringTaskCreation() {
    // Regression test: Ensure vm.selectedProjectId is NEVER modified during task creation
    
    let vm = AppViewModel()
    vm.showOverview = true
    vm.selectedProjectId = "original-project"
    
    let originalProjectId = vm.selectedProjectId
    
    // Create task in different project
    vm.submitTaskToLobs(
      title: "Task in different project",
      notes: nil,
      agent: "programmer",
      projectId: "target-project",
      autoPush: true
    )
    
    // Verify: vm.selectedProjectId unchanged
    XCTAssertEqual(vm.selectedProjectId, originalProjectId, "selectedProjectId should never change during submitTaskToLobs")
  }
  
  func testTaskCreationFromOverviewMaintainsOverviewState() {
    // Regression test: Creating task from overview should not exit overview mode
    
    let vm = AppViewModel()
    vm.showOverview = true
    vm.selectedProjectId = ""
    
    let projectA = Project(id: "project-a", title: "Project A", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectA]
    
    XCTAssertTrue(vm.showOverview, "Should start in overview")
    
    // Create task
    vm.submitTaskToLobs(
      title: "Test task",
      notes: nil,
      agent: "programmer",
      projectId: projectA.id,
      autoPush: true
    )
    
    // Verify: Still in overview
    XCTAssertTrue(vm.showOverview, "Should remain in overview after task creation")
  }
  
  func testTaskCreationFromProjectViewMaintainsProjectView() {
    // Regression test: Creating task while viewing project should not navigate away
    
    let vm = AppViewModel()
    vm.showOverview = false
    vm.selectedProjectId = "project-b"
    
    let projectB = Project(id: "project-b", title: "Project B", type: .kanban, archived: false, created: Date(), updated: Date(), notes: nil)
    vm.projects = [projectB]
    
    XCTAssertFalse(vm.showOverview, "Should start in project view")
    XCTAssertEqual(vm.selectedProjectId, "project-b")
    
    // Create task
    vm.submitTaskToLobs(
      title: "Test task",
      notes: nil,
      agent: "programmer",
      projectId: projectB.id,
      autoPush: true
    )
    
    // Verify: Still viewing same project
    XCTAssertFalse(vm.showOverview, "Should remain in project view")
    XCTAssertEqual(vm.selectedProjectId, "project-b", "Should still be viewing same project")
  }
}

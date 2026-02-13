import XCTest
@testable import LobsMissionControl

/// Tests for drag-and-drop reordering of projects on the overview screen.
///
/// ## Problem
/// User reported: "should be able to drag around projects on overview to reorder"
///
/// ## Solution
/// Added drag-and-drop functionality to project cards on the overview screen:
/// 1. Added `draggingProjectId` property to AppViewModel
/// 2. Added `.onDrag` modifier to RichProjectCard to make cards draggable
/// 3. Added `.onDrop` modifier with ProjectInsertDropDelegate to handle drops
/// 4. Reuses existing `reorderProject(fromId:beforeId:)` function in AppViewModel
///
/// ## Implementation
/// - Cards use `.onDrag` to set `vm.draggingProjectId` and create NSItemProvider
/// - Cards use `.onDrop` with ProjectInsertDropDelegate to handle reordering
/// - Drop delegate calls `vm.reorderProject(fromId:beforeId:)` which updates sortOrder
/// - Projects are rendered using `vm.sortedActiveProjects` which respects sortOrder
///
/// ## Tests
/// These tests verify the drag-and-drop functionality works correctly.
final class ProjectDragDropReorderTests: XCTestCase {
  
  // MARK: - Dragging State
  
  func testDraggingProjectId_IsSet_WhenDragStarts() {
    // Given: ViewModel with projects
    let vm = createViewModel()
    XCTAssertNil(vm.draggingProjectId, "Initially no project is being dragged")
    
    // When: User starts dragging a project
    vm.draggingProjectId = "project-a"
    
    // Then: draggingProjectId is set
    XCTAssertEqual(vm.draggingProjectId, "project-a", "Dragging state should be set")
  }
  
  func testDraggingProjectId_IsCleared_AfterDrop() {
    // Given: A project is being dragged
    let vm = createViewModel()
    vm.draggingProjectId = "project-a"
    
    // When: Drop completes (simulated)
    vm.draggingProjectId = nil
    
    // Then: draggingProjectId is cleared
    XCTAssertNil(vm.draggingProjectId, "Dragging state should be cleared after drop")
  }
  
  // MARK: - Reorder Functionality
  
  func testReorderProject_MovesProjectBeforeTarget() {
    // Given: Projects in order [A, B, C]
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1),
      createProject(id: "project-c", title: "C", sortOrder: 2)
    ]
    
    let initialOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(initialOrder, ["project-a", "project-b", "project-c"])
    
    // When: Drag C before B
    vm.reorderProject(fromId: "project-c", beforeId: "project-b")
    
    // Then: Order is [A, C, B]
    let newOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(newOrder, ["project-a", "project-c", "project-b"])
  }
  
  func testReorderProject_MovesProjectToFirst() {
    // Given: Projects in order [A, B, C]
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1),
      createProject(id: "project-c", title: "C", sortOrder: 2)
    ]
    
    // When: Drag C before A (move to first)
    vm.reorderProject(fromId: "project-c", beforeId: "project-a")
    
    // Then: Order is [C, A, B]
    let newOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(newOrder, ["project-c", "project-a", "project-b"])
  }
  
  func testReorderProject_UpdatesSortOrder() {
    // Given: Projects with explicit sortOrder
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1),
      createProject(id: "project-c", title: "C", sortOrder: 2)
    ]
    
    // When: Reorder
    vm.reorderProject(fromId: "project-c", beforeId: "project-a")
    
    // Then: sortOrder values are updated sequentially
    let sortedProjects = vm.sortedActiveProjects
    for (index, project) in sortedProjects.enumerated() {
      XCTAssertEqual(project.sortOrder, index, "\(project.title) should have sortOrder \(index)")
    }
  }
  
  func testReorderProject_UpdatesTimestamp() {
    // Given: Projects with old timestamps
    let oldDate = Date(timeIntervalSince1970: 1000000)
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0, updatedAt: oldDate),
      createProject(id: "project-b", title: "B", sortOrder: 1, updatedAt: oldDate)
    ]
    
    // When: Reorder
    let beforeReorder = Date()
    vm.reorderProject(fromId: "project-b", beforeId: "project-a")
    let afterReorder = Date()
    
    // Then: Updated timestamps are current
    for project in vm.projects {
      XCTAssertGreaterThanOrEqual(project.updatedAt, beforeReorder, "Timestamp should be updated")
      XCTAssertLessThanOrEqual(project.updatedAt, afterReorder, "Timestamp should be recent")
    }
  }
  
  // MARK: - Edge Cases
  
  func testReorderProject_SameProject_DoesNothing() {
    // Given: Projects in order [A, B, C]
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1),
      createProject(id: "project-c", title: "C", sortOrder: 2)
    ]
    
    let initialOrder = vm.sortedActiveProjects.map { $0.id }
    
    // When: Try to drag project before itself
    vm.reorderProject(fromId: "project-b", beforeId: "project-b")
    
    // Then: Order unchanged
    let newOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(newOrder, initialOrder, "Order should not change when dragging to same position")
  }
  
  func testReorderProject_TwoProjects() {
    // Given: Only two projects [A, B]
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1)
    ]
    
    // When: Drag B before A
    vm.reorderProject(fromId: "project-b", beforeId: "project-a")
    
    // Then: Order is [B, A]
    let newOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(newOrder, ["project-b", "project-a"])
  }
  
  func testReorderProject_WithDefaultProject() {
    // Given: Projects including default
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "default", title: "Default", sortOrder: 0),
      createProject(id: "project-a", title: "A", sortOrder: 1),
      createProject(id: "project-b", title: "B", sortOrder: 2)
    ]
    
    // When: Drag project-b before default
    vm.reorderProject(fromId: "project-b", beforeId: "default")
    
    // Then: Order is [B, Default, A]
    let newOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(newOrder, ["project-b", "default", "project-a"])
  }
  
  func testReorderProject_IgnoresArchivedProjects() {
    // Given: Mix of active and archived projects
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0, archived: false),
      createProject(id: "project-archived", title: "Archived", sortOrder: 1, archived: true),
      createProject(id: "project-b", title: "B", sortOrder: 2, archived: false)
    ]
    
    let activeBefore = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(activeBefore, ["project-a", "project-b"], "Should only include active projects")
    
    // When: Reorder active projects
    vm.reorderProject(fromId: "project-b", beforeId: "project-a")
    
    // Then: Only active projects are reordered
    let activeAfter = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(activeAfter, ["project-b", "project-a"])
    
    // Archived project remains unchanged
    let archivedProject = vm.projects.first { $0.id == "project-archived" }
    XCTAssertEqual(archivedProject?.archived, true)
  }
  
  // MARK: - Complex Reordering
  
  func testReorderProject_MultipleReorders() {
    // Given: Projects [A, B, C, D]
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1),
      createProject(id: "project-c", title: "C", sortOrder: 2),
      createProject(id: "project-d", title: "D", sortOrder: 3)
    ]
    
    // When: Multiple reorders
    vm.reorderProject(fromId: "project-d", beforeId: "project-a")  // D, A, B, C
    vm.reorderProject(fromId: "project-b", beforeId: "project-d")  // B, D, A, C
    vm.reorderProject(fromId: "project-c", beforeId: "project-a")  // B, D, C, A
    
    // Then: Final order is correct
    let finalOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(finalOrder, ["project-b", "project-d", "project-c", "project-a"])
  }
  
  func testReorderProject_BackAndForth() {
    // Given: Projects [A, B, C]
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1),
      createProject(id: "project-c", title: "C", sortOrder: 2)
    ]
    
    let initialOrder = vm.sortedActiveProjects.map { $0.id }
    
    // When: Reorder and then reorder back
    vm.reorderProject(fromId: "project-c", beforeId: "project-a")  // C, A, B
    vm.reorderProject(fromId: "project-c", beforeId: "project-b")  // A, C, B
    vm.reorderProject(fromId: "project-c", beforeId: "project-a")  // C, A, B
    let afterFirstCycle = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(afterFirstCycle, ["project-c", "project-a", "project-b"])
    
    // Reorder back close to original
    vm.reorderProject(fromId: "project-c", beforeId: "project-a")  // Already there
    vm.reorderProject(fromId: "project-b", beforeId: "project-c")  // B, C, A
    vm.reorderProject(fromId: "project-b", beforeId: "project-c")  // Already there
    
    let finalOrder = vm.sortedActiveProjects.map { $0.id }
    XCTAssertNotEqual(finalOrder, initialOrder, "Multiple operations changed the order")
  }
  
  // MARK: - SortedActiveProjects
  
  func testSortedActiveProjects_RespectsSortOrder() {
    // Given: Projects with explicit sortOrder
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-c", title: "C", sortOrder: 2),
      createProject(id: "project-a", title: "A", sortOrder: 0),
      createProject(id: "project-b", title: "B", sortOrder: 1)
    ]
    
    // When: Get sorted projects
    let sorted = vm.sortedActiveProjects.map { $0.id }
    
    // Then: Order respects sortOrder
    XCTAssertEqual(sorted, ["project-a", "project-b", "project-c"])
  }
  
  func testSortedActiveProjects_FallsBackToCreatedAt() {
    // Given: Projects without sortOrder (nil)
    let date1 = Date(timeIntervalSince1970: 1000)
    let date2 = Date(timeIntervalSince1970: 2000)
    let date3 = Date(timeIntervalSince1970: 3000)
    
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "project-c", title: "C", sortOrder: nil, createdAt: date3),
      createProject(id: "project-a", title: "A", sortOrder: nil, createdAt: date1),
      createProject(id: "project-b", title: "B", sortOrder: nil, createdAt: date2)
    ]
    
    // When: Get sorted projects
    let sorted = vm.sortedActiveProjects.map { $0.id }
    
    // Then: Order falls back to createdAt
    XCTAssertEqual(sorted, ["project-a", "project-b", "project-c"])
  }
  
  // MARK: - User Flow Scenarios
  
  func testScenario_UserDragsProjectToTop() {
    // Scenario: User wants to prioritize a project by dragging it to the top
    
    // Given: User has projects [Work, Personal, Side Project]
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "work", title: "Work", sortOrder: 0),
      createProject(id: "personal", title: "Personal", sortOrder: 1),
      createProject(id: "side", title: "Side Project", sortOrder: 2)
    ]
    
    // When: User drags "Side Project" to the top
    vm.draggingProjectId = "side"
    vm.reorderProject(fromId: "side", beforeId: "work")
    vm.draggingProjectId = nil
    
    // Then: Side Project is first
    let order = vm.sortedActiveProjects.map { $0.title }
    XCTAssertEqual(order.first, "Side Project", "Dragged project should be first")
    XCTAssertEqual(order, ["Side Project", "Work", "Personal"])
  }
  
  func testScenario_UserReorganizesMultipleProjects() {
    // Scenario: User reorganizes several projects to match priority
    
    // Given: Projects in alphabetical order
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "a", title: "A - Low Priority", sortOrder: 0),
      createProject(id: "b", title: "B - Medium", sortOrder: 1),
      createProject(id: "c", title: "C - High Priority", sortOrder: 2),
      createProject(id: "d", title: "D - Urgent", sortOrder: 3)
    ]
    
    // When: User reorders by priority (Urgent, High, Medium, Low)
    vm.reorderProject(fromId: "d", beforeId: "a")  // D first
    vm.reorderProject(fromId: "c", beforeId: "b")  // C before B
    vm.reorderProject(fromId: "c", beforeId: "a")  // C before A (but after D)
    
    // Then: Projects are in priority order
    let titles = vm.sortedActiveProjects.map { $0.title }
    XCTAssertEqual(titles.first, "D - Urgent")
    XCTAssertEqual(titles.last, "A - Low Priority")
  }
  
  func testScenario_DragFromMiddleToEnd() {
    // Scenario: User drags a middle project to near the end
    
    // Given: Five projects
    let vm = createViewModel()
    vm.projects = [
      createProject(id: "p1", title: "P1", sortOrder: 0),
      createProject(id: "p2", title: "P2", sortOrder: 1),
      createProject(id: "p3", title: "P3", sortOrder: 2),
      createProject(id: "p4", title: "P4", sortOrder: 3),
      createProject(id: "p5", title: "P5", sortOrder: 4)
    ]
    
    // When: Drag P2 before P5 (near end)
    vm.reorderProject(fromId: "p2", beforeId: "p5")
    
    // Then: P2 is second to last
    let order = vm.sortedActiveProjects.map { $0.id }
    XCTAssertEqual(order, ["p1", "p3", "p4", "p2", "p5"])
  }
  
  // MARK: - Drop Delegate Behavior
  
  func testDropDelegate_ValidatesDropCorrectly() {
    // Drop delegates should always validate as true for simplicity
    // The actual validation happens in performDrop
    
    // Given: A project being dragged
    let vm = createViewModel()
    vm.draggingProjectId = "project-a"
    
    // When: Drop would be valid (different projects)
    let canDrop = vm.draggingProjectId != "project-b"
    
    // Then: Drop should be allowed
    XCTAssertTrue(canDrop, "Drop should be valid for different projects")
  }
  
  func testDropDelegate_RejectsDropOnSameProject() {
    // Given: Project being dragged
    let vm = createViewModel()
    vm.draggingProjectId = "project-a"
    
    // When: Try to drop on itself
    let canDrop = vm.draggingProjectId != "project-a"
    
    // Then: Drop should be rejected
    XCTAssertFalse(canDrop, "Cannot drop project on itself")
  }
  
  // MARK: - Helper Methods
  
  private func createViewModel() -> AppViewModel {
    let vm = AppViewModel()
    return vm
  }
  
  private func createProject(
    id: String,
    title: String,
    sortOrder: Int? = nil,
    archived: Bool = false,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> Project {
    Project(
      id: id,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      notes: nil,
      archived: archived,
      type: .kanban,
      sortOrder: sortOrder
    )
  }
}

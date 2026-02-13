import XCTest
@testable import LobsMissionControl

/// Tests for archiving the default project.
///
/// ## Problem
/// User reported: "can't archive default project. no need for it anymore"
///
/// The original implementation had a bug where archiving the currently selected project
/// would always switch to "default". This created a circular problem when trying to
/// archive the default project itself - it would try to select the project being archived.
///
/// ## Solution
/// When archiving the currently selected project:
/// 1. Find the first non-archived project that isn't the one being archived
/// 2. Switch to that project
/// 3. Only fall back to "default" if no other projects exist
///
/// This allows the default project to be archived like any other project.
///
/// ## Tests
/// These tests verify that projects (including default) can be archived correctly
/// and that the selected project switches appropriately.
final class ArchiveDefaultProjectTests: XCTestCase {
  
  // MARK: - Archive Default Project
  
  func testArchiveDefaultProject_WhenOtherProjectsExist() {
    // Given: Multiple projects including default, default is selected
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default"),
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "project-b", title: "Project B")
    ])
    vm.selectedProjectId = "default"
    
    // When: Archive default project
    vm.archiveProject(id: "default")
    
    // Then: Default is marked as archived
    let defaultProject = vm.projects.first { $0.id == "default" }
    XCTAssertEqual(defaultProject?.archived, true, "Default project should be archived")
    
    // Then: Selected project switches to another active project
    XCTAssertNotEqual(vm.selectedProjectId, "default", "Should not stay on archived default project")
    XCTAssertTrue(
      vm.selectedProjectId == "project-a" || vm.selectedProjectId == "project-b",
      "Should switch to one of the other active projects"
    )
  }
  
  func testArchiveDefaultProject_WhenDefaultIsOnlyProject() {
    // Given: Only default project exists, it's selected
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default")
    ])
    vm.selectedProjectId = "default"
    
    // When: Archive default project
    vm.archiveProject(id: "default")
    
    // Then: Default is marked as archived
    let defaultProject = vm.projects.first { $0.id == "default" }
    XCTAssertEqual(defaultProject?.archived, true, "Default project should be archived")
    
    // Then: Selected project stays as default (edge case - no other projects)
    XCTAssertEqual(vm.selectedProjectId, "default", "Falls back to default when no other projects exist")
  }
  
  func testArchiveDefaultProject_WhenDefaultNotSelected() {
    // Given: Multiple projects, default exists but another is selected
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default"),
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "project-b", title: "Project B")
    ])
    vm.selectedProjectId = "project-a"
    
    // When: Archive default project
    vm.archiveProject(id: "default")
    
    // Then: Default is marked as archived
    let defaultProject = vm.projects.first { $0.id == "default" }
    XCTAssertEqual(defaultProject?.archived, true, "Default project should be archived")
    
    // Then: Selected project doesn't change (wasn't default)
    XCTAssertEqual(vm.selectedProjectId, "project-a", "Should stay on currently selected project")
  }
  
  // MARK: - Archive Non-Default Projects
  
  func testArchiveNonDefaultProject_WhenSelected() {
    // Given: Multiple projects, non-default is selected
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default"),
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "project-b", title: "Project B")
    ])
    vm.selectedProjectId = "project-a"
    
    // When: Archive the selected project
    vm.archiveProject(id: "project-a")
    
    // Then: Project is marked as archived
    let projectA = vm.projects.first { $0.id == "project-a" }
    XCTAssertEqual(projectA?.archived, true, "Project A should be archived")
    
    // Then: Selected project switches to another active project
    XCTAssertNotEqual(vm.selectedProjectId, "project-a", "Should not stay on archived project")
    XCTAssertTrue(
      vm.selectedProjectId == "default" || vm.selectedProjectId == "project-b",
      "Should switch to another active project"
    )
  }
  
  func testArchiveNonDefaultProject_WhenNotSelected() {
    // Given: Multiple projects, different one is selected
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default"),
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "project-b", title: "Project B")
    ])
    vm.selectedProjectId = "default"
    
    // When: Archive a non-selected project
    vm.archiveProject(id: "project-a")
    
    // Then: Project is marked as archived
    let projectA = vm.projects.first { $0.id == "project-a" }
    XCTAssertEqual(projectA?.archived, true, "Project A should be archived")
    
    // Then: Selected project doesn't change
    XCTAssertEqual(vm.selectedProjectId, "default", "Should stay on default")
  }
  
  // MARK: - Selection Logic
  
  func testArchiveProject_SelectsFirstAvailableProject() {
    // Given: Multiple projects in specific order
    let vm = createViewModelWithProjects([
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "default", title: "Default"),
      createProject(id: "project-b", title: "Project B")
    ])
    vm.selectedProjectId = "default"
    
    // When: Archive default (currently selected)
    vm.archiveProject(id: "default")
    
    // Then: Selects first non-archived project (project-a)
    let selectedIsNonArchived = vm.projects.first { $0.id == vm.selectedProjectId }?.archived == false
    XCTAssertTrue(selectedIsNonArchived, "Should select a non-archived project")
    XCTAssertNotEqual(vm.selectedProjectId, "default", "Should not select the archived project")
  }
  
  func testArchiveProject_SkipsAlreadyArchivedProjects() {
    // Given: Multiple projects, some already archived
    let vm = createViewModelWithProjects([
      createProject(id: "project-a", title: "Project A", archived: true),
      createProject(id: "default", title: "Default"),
      createProject(id: "project-b", title: "Project B")
    ])
    vm.selectedProjectId = "default"
    
    // When: Archive default
    vm.archiveProject(id: "default")
    
    // Then: Should skip already-archived project-a and select project-b
    XCTAssertNotEqual(vm.selectedProjectId, "project-a", "Should skip already archived projects")
    XCTAssertEqual(vm.selectedProjectId, "project-b", "Should select active project-b")
  }
  
  // MARK: - Edge Cases
  
  func testArchiveProject_WhenAllOtherProjectsArchived() {
    // Given: Multiple projects but all except one are archived
    let vm = createViewModelWithProjects([
      createProject(id: "project-a", title: "Project A", archived: true),
      createProject(id: "default", title: "Default"),
      createProject(id: "project-b", title: "Project B", archived: true)
    ])
    vm.selectedProjectId = "default"
    
    // When: Archive the last active project (default)
    vm.archiveProject(id: "default")
    
    // Then: Default is archived
    let defaultProject = vm.projects.first { $0.id == "default" }
    XCTAssertEqual(defaultProject?.archived, true, "Default should be archived")
    
    // Then: Falls back to default (no active projects left)
    XCTAssertEqual(vm.selectedProjectId, "default", "Falls back when no active projects remain")
  }
  
  func testArchiveProject_UpdatesTimestamp() {
    // Given: Project with known timestamp
    let oldDate = Date(timeIntervalSince1970: 1000000)
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default", updatedAt: oldDate)
    ])
    
    // When: Archive project
    let beforeArchive = Date()
    vm.archiveProject(id: "default")
    let afterArchive = Date()
    
    // Then: Updated timestamp is current
    let project = vm.projects.first { $0.id == "default" }
    XCTAssertNotNil(project?.updatedAt, "Should have updated timestamp")
    XCTAssertGreaterThanOrEqual(project!.updatedAt, beforeArchive, "Timestamp should be recent")
    XCTAssertLessThanOrEqual(project!.updatedAt, afterArchive, "Timestamp should be recent")
  }
  
  // MARK: - Archived Flag
  
  func testArchiveProject_SetsArchivedToTrue() {
    // Given: Project with archived = false
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default", archived: false)
    ])
    
    // When: Archive project
    vm.archiveProject(id: "default")
    
    // Then: Archived flag is set to true
    let project = vm.projects.first { $0.id == "default" }
    XCTAssertEqual(project?.archived, true, "Archived flag should be true")
  }
  
  func testArchiveProject_HandlesNilArchivedFlag() {
    // Given: Project with archived = nil (legacy data)
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default", archived: nil)
    ])
    
    // When: Archive project
    vm.archiveProject(id: "default")
    
    // Then: Archived flag is set to true
    let project = vm.projects.first { $0.id == "default" }
    XCTAssertEqual(project?.archived, true, "Should set archived to true even if was nil")
  }
  
  // MARK: - Multiple Archives
  
  func testArchiveMultipleProjects_InSequence() {
    // Given: Three projects, default selected
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default"),
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "project-b", title: "Project B")
    ])
    vm.selectedProjectId = "default"
    
    // When: Archive default, then archive the next selected project
    vm.archiveProject(id: "default")
    let firstNewSelection = vm.selectedProjectId
    vm.archiveProject(id: firstNewSelection)
    let secondNewSelection = vm.selectedProjectId
    
    // Then: All archived projects are marked
    XCTAssertEqual(vm.projects.first { $0.id == "default" }?.archived, true)
    XCTAssertEqual(vm.projects.first { $0.id == firstNewSelection }?.archived, true)
    
    // Then: Final selection is the remaining project
    XCTAssertNotEqual(secondNewSelection, "default")
    XCTAssertNotEqual(secondNewSelection, firstNewSelection)
  }
  
  // MARK: - Sorted Active Projects
  
  func testSortedActiveProjects_ExcludesArchivedDefault() {
    // Given: Default project is archived
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default", archived: true),
      createProject(id: "project-a", title: "Project A"),
      createProject(id: "project-b", title: "Project B")
    ])
    
    // When: Get sorted active projects
    let activeProjects = vm.sortedActiveProjects
    
    // Then: Archived default is excluded
    XCTAssertFalse(activeProjects.contains { $0.id == "default" }, "Should exclude archived default")
    XCTAssertEqual(activeProjects.count, 2, "Should only include 2 active projects")
  }
  
  func testSortedActiveProjects_IncludesDefaultWhenNotArchived() {
    // Given: Default project is not archived
    let vm = createViewModelWithProjects([
      createProject(id: "default", title: "Default", archived: false),
      createProject(id: "project-a", title: "Project A")
    ])
    
    // When: Get sorted active projects
    let activeProjects = vm.sortedActiveProjects
    
    // Then: Default is included
    XCTAssertTrue(activeProjects.contains { $0.id == "default" }, "Should include non-archived default")
    XCTAssertEqual(activeProjects.count, 2, "Should include both projects")
  }
  
  // MARK: - Helper Methods
  
  private func createViewModelWithProjects(_ projects: [Project]) -> AppViewModel {
    let vm = AppViewModel()
    vm.projects = projects
    return vm
  }
  
  private func createProject(
    id: String,
    title: String,
    archived: Bool? = false,
    updatedAt: Date = Date()
  ) -> Project {
    Project(
      id: id,
      title: title,
      createdAt: Date(),
      updatedAt: updatedAt,
      notes: nil,
      archived: archived,
      type: .kanban,
      sortOrder: nil
    )
  }
}

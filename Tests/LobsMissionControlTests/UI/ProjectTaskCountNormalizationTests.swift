import XCTest
@testable import LobsMissionControl

final class ProjectTaskCountNormalizationTests: XCTestCase {
  func testDefaultProjectCountsTasksWithNilProjectId() {
    let now = Date()
    let tasks: [DashboardTask] = [
      DashboardTask(id: "nil-project", title: "Nil Project", status: .active, createdAt: now, updatedAt: now, projectId: nil),
      DashboardTask(id: "default-project", title: "Default Project", status: .active, createdAt: now, updatedAt: now, projectId: "default"),
      DashboardTask(id: "other", title: "Other", status: .active, createdAt: now, updatedAt: now, projectId: "project-a")
    ]

    let defaultProjectTaskIds = tasks
      .filter { $0.normalizedProjectId == "default" }
      .map(\.id)

    XCTAssertEqual(defaultProjectTaskIds, ["nil-project", "default-project"])
  }

  func testNonDefaultProjectCountUsesNormalizedProjectId() {
    let now = Date()
    let tasks: [DashboardTask] = [
      DashboardTask(id: "1", title: "A", status: .active, createdAt: now, updatedAt: now, projectId: "project-a"),
      DashboardTask(id: "2", title: "B", status: .inbox, createdAt: now, updatedAt: now, projectId: nil),
      DashboardTask(id: "3", title: "C", status: .completed, createdAt: now, updatedAt: now, projectId: "project-a")
    ]

    let projectATaskIds = tasks
      .filter { $0.normalizedProjectId == "project-a" }
      .map(\.id)

    XCTAssertEqual(projectATaskIds, ["1", "3"])
  }
}

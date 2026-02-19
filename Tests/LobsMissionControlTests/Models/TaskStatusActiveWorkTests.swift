import XCTest
@testable import LobsMissionControl

final class TaskStatusActiveWorkTests: XCTestCase {
  func testIsActiveWorkIncludesCanonicalActiveStatuses() {
    XCTAssertTrue(TaskStatus.active.isActiveWork)
    XCTAssertTrue(TaskStatus.waitingOn.isActiveWork)
  }

  func testIsActiveWorkIncludesServerLifecycleAliases() {
    XCTAssertTrue(TaskStatus.other("not_started").isActiveWork)
    XCTAssertTrue(TaskStatus.other("in_progress").isActiveWork)
    XCTAssertTrue(TaskStatus.other("IN-PROGRESS").isActiveWork)
  }

  func testIsActiveWorkExcludesCompletedAndArchivedLikeStatuses() {
    XCTAssertFalse(TaskStatus.completed.isActiveWork)
    XCTAssertFalse(TaskStatus.rejected.isActiveWork)
    XCTAssertFalse(TaskStatus.inbox.isActiveWork)
    XCTAssertFalse(TaskStatus.other("done").isActiveWork)
    XCTAssertFalse(TaskStatus.other("archived").isActiveWork)
  }

  func testDashboardActiveTasksFilterIncludesNotStartedAndInProgressButExcludesTerminalStates() {
    let now = Date()
    let tasks: [DashboardTask] = [
      DashboardTask(id: "not-started", title: "not started", status: .other("not_started"), createdAt: now, updatedAt: now),
      DashboardTask(id: "in-progress", title: "in progress", status: .other("in_progress"), createdAt: now, updatedAt: now),
      DashboardTask(id: "active", title: "active", status: .active, createdAt: now, updatedAt: now),
      DashboardTask(id: "completed", title: "completed", status: .completed, createdAt: now, updatedAt: now),
      DashboardTask(id: "cancelled", title: "cancelled", status: .other("cancelled"), createdAt: now, updatedAt: now),
      DashboardTask(id: "archived", title: "archived", status: .other("archived"), createdAt: now, updatedAt: now),
    ]

    let activeTasks = tasks.filter { $0.status.isActiveWork }

    XCTAssertEqual(activeTasks.map(\.id), ["not-started", "in-progress", "active"])
    XCTAssertEqual(activeTasks.count, 3)
  }
}

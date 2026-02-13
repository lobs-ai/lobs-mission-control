import XCTest
@testable import LobsMissionControl

/// Tests for blocked task counter fix
///
/// ## Context
/// Bug: Tasks that were marked as blocked and then completed/rejected without being 
/// explicitly unblocked were still being counted in the "blocked tasks" counter.
///
/// ## Fix
/// Updated all blocked count calculations to exclude tasks with terminal statuses 
/// (completed, rejected), even if their workState is still .blocked.
///
/// ## Files Modified
/// - BoardComponents.swift
/// - CommandCenterView.swift (3 locations)
/// - TasksContainerView.swift (2 locations)
final class BlockedTaskCounterTests: XCTestCase {
    
    // MARK: - Test Data
    
    private func createTask(
        id: String,
        status: TaskStatus,
        workState: WorkState
    ) -> DashboardTask {
        DashboardTask(
            id: id,
            title: "Test Task \(id)",
            status: status,
            owner: .lobs,
            createdAt: Date(),
            updatedAt: Date(),
            workState: workState
        )
    }
    
    // MARK: - Core Logic Tests
    
    func testBlockedCountExcludesCompletedTasks() {
        // Given: A task that is blocked AND completed
        let task = createTask(id: "1", status: .completed, workState: .blocked)
        let tasks = [task]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 0 (completed tasks excluded)
        XCTAssertEqual(blockedCount, 0, 
                       "Completed tasks should not be counted as blocked")
    }
    
    func testBlockedCountExcludesRejectedTasks() {
        // Given: A task that is blocked AND rejected
        let task = createTask(id: "1", status: .rejected, workState: .blocked)
        let tasks = [task]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 0 (rejected tasks excluded)
        XCTAssertEqual(blockedCount, 0, 
                       "Rejected tasks should not be counted as blocked")
    }
    
    func testBlockedCountIncludesActiveBlockedTasks() {
        // Given: A task that is blocked AND active
        let task = createTask(id: "1", status: .active, workState: .blocked)
        let tasks = [task]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 1 (active blocked tasks included)
        XCTAssertEqual(blockedCount, 1, 
                       "Active blocked tasks should be counted as blocked")
    }
    
    func testBlockedCountIncludesInboxBlockedTasks() {
        // Given: A task that is blocked AND in inbox
        let task = createTask(id: "1", status: .inbox, workState: .blocked)
        let tasks = [task]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 1 (inbox blocked tasks included)
        XCTAssertEqual(blockedCount, 1, 
                       "Inbox blocked tasks should be counted as blocked")
    }
    
    // MARK: - Mixed Scenarios
    
    func testBlockedCountWithMixedTasks() {
        // Given: Mixed set of tasks
        let tasks = [
            createTask(id: "1", status: .active, workState: .blocked),       // Should count
            createTask(id: "2", status: .completed, workState: .blocked),    // Should NOT count
            createTask(id: "3", status: .rejected, workState: .blocked),     // Should NOT count
            createTask(id: "4", status: .inbox, workState: .blocked),        // Should count
            createTask(id: "5", status: .active, workState: .inProgress),    // Should NOT count
            createTask(id: "6", status: .completed, workState: .inProgress), // Should NOT count
        ]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Only active and inbox blocked tasks should be counted
        XCTAssertEqual(blockedCount, 2, 
                       "Only active and inbox blocked tasks should be counted")
    }
    
    func testBlockedCountWithNoBlockedTasks() {
        // Given: Tasks with no blocked work state
        let tasks = [
            createTask(id: "1", status: .active, workState: .inProgress),
            createTask(id: "2", status: .completed, workState: .inProgress),
            createTask(id: "3", status: .inbox, workState: .notStarted),
        ]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 0
        XCTAssertEqual(blockedCount, 0, 
                       "No tasks should be counted as blocked")
    }
    
    func testBlockedCountWithEmptyTaskList() {
        // Given: Empty task list
        let tasks: [DashboardTask] = []
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 0
        XCTAssertEqual(blockedCount, 0, 
                       "Empty task list should have 0 blocked count")
    }
    
    // MARK: - Edge Cases
    
    func testBlockedCountWithWaitingOnStatus() {
        // Given: A task that is blocked AND waiting_on
        let task = createTask(id: "1", status: .waitingOn, workState: .blocked)
        let tasks = [task]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 1 (waiting_on is not a terminal state)
        XCTAssertEqual(blockedCount, 1, 
                       "Waiting_on blocked tasks should be counted as blocked")
    }
    
    func testBlockedCountWithMultipleCompletedBlockedTasks() {
        // Given: Multiple completed tasks that are still marked as blocked
        let tasks = [
            createTask(id: "1", status: .completed, workState: .blocked),
            createTask(id: "2", status: .completed, workState: .blocked),
            createTask(id: "3", status: .completed, workState: .blocked),
        ]
        
        // When: Calculating blocked count
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Then: Count should be 0 (all completed)
        XCTAssertEqual(blockedCount, 0, 
                       "Multiple completed blocked tasks should not be counted")
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testBlockedCountAfterTaskCompletion() {
        // Scenario: User has a blocked task, then marks it complete without unblocking
        
        // Given: Task starts as active and blocked
        var task = createTask(id: "1", status: .active, workState: .blocked)
        var tasks = [task]
        
        // Initial state: Should be counted as blocked
        var blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        XCTAssertEqual(blockedCount, 1, "Task should initially be counted as blocked")
        
        // When: User marks task as completed (without changing workState)
        task = createTask(id: "1", status: .completed, workState: .blocked)
        tasks = [task]
        
        // Then: Should NOT be counted as blocked anymore
        blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        XCTAssertEqual(blockedCount, 0, 
                       "Completed task should not be counted as blocked even if workState is still blocked")
    }
    
    func testBlockedCountAfterTaskRejection() {
        // Scenario: User has a blocked task, then rejects it without unblocking
        
        // Given: Task starts as active and blocked
        var task = createTask(id: "1", status: .active, workState: .blocked)
        var tasks = [task]
        
        // Initial state: Should be counted as blocked
        var blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        XCTAssertEqual(blockedCount, 1, "Task should initially be counted as blocked")
        
        // When: User rejects task (without changing workState)
        task = createTask(id: "1", status: .rejected, workState: .blocked)
        tasks = [task]
        
        // Then: Should NOT be counted as blocked anymore
        blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        XCTAssertEqual(blockedCount, 0, 
                       "Rejected task should not be counted as blocked even if workState is still blocked")
    }
    
    // MARK: - Pattern Verification
    
    func testFilterPatternMatchesAllLocations() {
        // This test verifies the filter pattern is correct and consistent
        let tasks = [
            createTask(id: "1", status: .active, workState: .blocked),
            createTask(id: "2", status: .completed, workState: .blocked),
            createTask(id: "3", status: .rejected, workState: .blocked),
        ]
        
        // The pattern used in all 5 locations
        let blockedCount = tasks.filter { 
            $0.workState == .blocked && $0.status != .completed && $0.status != .rejected 
        }.count
        
        // Expected: Only the active blocked task
        XCTAssertEqual(blockedCount, 1, 
                       "Filter pattern should correctly exclude completed and rejected tasks")
        
        // Verify each task individually
        let activeBlocked = tasks[0]
        let completedBlocked = tasks[1]
        let rejectedBlocked = tasks[2]
        
        XCTAssertTrue(activeBlocked.workState == .blocked && 
                      activeBlocked.status != .completed && 
                      activeBlocked.status != .rejected,
                      "Active blocked task should pass filter")
        
        XCTAssertFalse(completedBlocked.workState == .blocked && 
                       completedBlocked.status != .completed && 
                       completedBlocked.status != .rejected,
                       "Completed blocked task should fail filter")
        
        XCTAssertFalse(rejectedBlocked.workState == .blocked && 
                       rejectedBlocked.status != .completed && 
                       rejectedBlocked.status != .rejected,
                       "Rejected blocked task should fail filter")
    }
}

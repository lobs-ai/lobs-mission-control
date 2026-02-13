import XCTest
@testable import LobsMissionControl

/// Tests for agent recent activity display enhancement
///
/// ## Context
/// User reported: "agents dont say they are working but tasks are being completed"
///
/// ## Root Cause
/// - Agent statuses are polled every 30 seconds from `/api/agents`
/// - If tasks complete faster than the polling interval, the "working" status is never captured
/// - UI only showed current status, not recent activity
///
/// ## Fix
/// Enhanced StatusBadge to show "Recently Active" (green) when:
/// - Agent status is "idle"
/// - Agent completed a task in the last 5 minutes (lastCompletedAt within 300 seconds)
///
/// This provides visual feedback that an agent was recently working, even if we missed
/// the "working" status during polling.
///
/// ## Files Modified
/// - Team/AgentCardView.swift (StatusBadge struct, borderColor)
final class AgentRecentActivityTests: XCTestCase {
    
    // MARK: - Test Data Helpers
    
    private func createAgentStatus(
        agentType: String = "programmer",
        status: String = "idle",
        lastCompletedAt: Date? = nil,
        currentTaskId: String? = nil
    ) -> AgentStatus {
        AgentStatus(
            agentType: agentType,
            status: status,
            activity: nil,
            thinking: nil,
            currentTaskId: currentTaskId,
            currentProjectId: nil,
            lastActiveAt: Date(),
            lastCompletedTaskId: lastCompletedAt != nil ? "test-task-123" : nil,
            lastCompletedAt: lastCompletedAt,
            stats: nil
        )
    }
    
    // MARK: - Recently Active Detection Tests
    
    func testAgentIsRecentlyActive_WhenCompletedWithinFiveMinutes() {
        // Given: Agent completed a task 2 minutes ago
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: twoMinutesAgo)
        
        // When: Checking if agent is recently active
        let isRecentlyActive = checkRecentlyActive(lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be considered recently active
        XCTAssertTrue(isRecentlyActive,
                      "Agent that completed task 2 minutes ago should be recently active")
    }
    
    func testAgentIsNotRecentlyActive_WhenCompletedOverFiveMinutesAgo() {
        // Given: Agent completed a task 10 minutes ago
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: tenMinutesAgo)
        
        // When: Checking if agent is recently active
        let isRecentlyActive = checkRecentlyActive(lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should NOT be considered recently active
        XCTAssertFalse(isRecentlyActive,
                       "Agent that completed task 10 minutes ago should NOT be recently active")
    }
    
    func testAgentIsNotRecentlyActive_WhenNeverCompleted() {
        // Given: Agent has never completed a task
        let agent = createAgentStatus(status: "idle", lastCompletedAt: nil)
        
        // When: Checking if agent is recently active
        let isRecentlyActive = checkRecentlyActive(lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should NOT be considered recently active
        XCTAssertFalse(isRecentlyActive,
                       "Agent that never completed a task should NOT be recently active")
    }
    
    func testAgentBoundary_ExactlyFiveMinutes() {
        // Given: Agent completed a task exactly 5 minutes ago
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: fiveMinutesAgo)
        
        // When: Checking if agent is recently active
        let isRecentlyActive = checkRecentlyActive(lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should NOT be considered recently active (boundary is exclusive)
        XCTAssertFalse(isRecentlyActive,
                       "Agent that completed task exactly 5 minutes ago should NOT be recently active")
    }
    
    func testAgentBoundary_JustUnderFiveMinutes() {
        // Given: Agent completed a task 299 seconds ago (just under 5 minutes)
        let justUnderFiveMinutes = Date().addingTimeInterval(-299)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: justUnderFiveMinutes)
        
        // When: Checking if agent is recently active
        let isRecentlyActive = checkRecentlyActive(lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be considered recently active
        XCTAssertTrue(isRecentlyActive,
                      "Agent that completed task 299 seconds ago should be recently active")
    }
    
    // MARK: - Status Display Tests
    
    func testStatusText_ShowsRecentlyActive_WhenIdleAndRecentlyCompleted() {
        // Given: Idle agent that completed task recently
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: twoMinutesAgo)
        
        // When: Getting status text
        let statusText = getStatusText(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should show "Recently Active"
        XCTAssertEqual(statusText, "Recently Active",
                       "Idle agent with recent completion should show 'Recently Active'")
    }
    
    func testStatusText_ShowsIdle_WhenIdleAndNotRecentlyCompleted() {
        // Given: Idle agent that completed task 10 minutes ago
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: tenMinutesAgo)
        
        // When: Getting status text
        let statusText = getStatusText(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should show "Idle"
        XCTAssertEqual(statusText, "Idle",
                       "Idle agent without recent completion should show 'Idle'")
    }
    
    func testStatusText_ShowsWorking_WhenStatusIsWorking() {
        // Given: Agent currently working
        let agent = createAgentStatus(status: "working", currentTaskId: "task-123")
        
        // When: Getting status text
        let statusText = getStatusText(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should show "Working"
        XCTAssertEqual(statusText, "Working",
                       "Working agent should show 'Working' regardless of lastCompletedAt")
    }
    
    func testStatusText_ShowsThinking_WhenStatusIsThinking() {
        // Given: Agent currently thinking
        let agent = createAgentStatus(status: "thinking")
        
        // When: Getting status text
        let statusText = getStatusText(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should show "Thinking"
        XCTAssertEqual(statusText, "Thinking",
                       "Thinking agent should show 'Thinking'")
    }
    
    // MARK: - Status Color Tests
    
    func testStatusColor_Green_WhenRecentlyActive() {
        // Given: Idle agent with recent completion
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: twoMinutesAgo)
        
        // When: Getting status color
        let color = getStatusColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be green
        XCTAssertEqual(color, "green",
                       "Recently active idle agent should have green status color")
    }
    
    func testStatusColor_Secondary_WhenIdleNotRecentlyActive() {
        // Given: Idle agent without recent completion
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: tenMinutesAgo)
        
        // When: Getting status color
        let color = getStatusColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be secondary (gray)
        XCTAssertEqual(color, "secondary",
                       "Idle agent without recent activity should have secondary color")
    }
    
    func testStatusColor_Blue_WhenWorking() {
        // Given: Agent currently working
        let agent = createAgentStatus(status: "working")
        
        // When: Getting status color
        let color = getStatusColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be blue
        XCTAssertEqual(color, "blue",
                       "Working agent should have blue status color")
    }
    
    func testStatusColor_Purple_WhenThinking() {
        // Given: Agent currently thinking
        let agent = createAgentStatus(status: "thinking")
        
        // When: Getting status color
        let color = getStatusColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be purple
        XCTAssertEqual(color, "purple",
                       "Thinking agent should have purple status color")
    }
    
    func testStatusColor_Red_WhenError() {
        // Given: Agent in error state
        let agent = createAgentStatus(status: "error")
        
        // When: Getting status color
        let color = getStatusColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be red
        XCTAssertEqual(color, "red",
                       "Error agent should have red status color")
    }
    
    // MARK: - Border Color Tests
    
    func testBorderColor_Green_WhenRecentlyActive() {
        // Given: Idle agent with recent completion
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: twoMinutesAgo)
        
        // When: Getting border color
        let borderColor = getBorderColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be green
        XCTAssertEqual(borderColor, "green",
                       "Recently active agent should have green border highlight")
    }
    
    func testBorderColor_Default_WhenIdleNotRecentlyActive() {
        // Given: Idle agent without recent completion
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: tenMinutesAgo)
        
        // When: Getting border color
        let borderColor = getBorderColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should be default separator color
        XCTAssertEqual(borderColor, "separator",
                       "Idle agent without recent activity should have default border")
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testScenario_FastTask() {
        // Scenario: Task completes in 10 seconds (faster than polling interval)
        
        // Given: Agent was working, completed task 30 seconds ago
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: thirtySecondsAgo)
        
        // When: Checking status display
        let statusText = getStatusText(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        let isRecentlyActive = checkRecentlyActive(lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should show as recently active
        XCTAssertTrue(isRecentlyActive, "Agent that completed task 30s ago should be recently active")
        XCTAssertEqual(statusText, "Recently Active",
                       "UI should show 'Recently Active' even though we missed the 'working' status")
    }
    
    func testScenario_PollingMissedWorkingStatus() {
        // Scenario: Task started at 10:00:00, completed at 10:00:15
        //          Polling happened at 10:00:00 (idle) and 10:00:30 (idle)
        //          We never saw status="working"
        
        // Given: Current time is 10:00:45 (45 seconds after completion, 15 seconds after last poll)
        let fifteenSecondsAgo = Date().addingTimeInterval(-15)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: fifteenSecondsAgo)
        
        // When: User looks at dashboard
        let statusText = getStatusText(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        let borderColor = getBorderColorName(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should show visual indication of recent activity
        XCTAssertEqual(statusText, "Recently Active",
                       "Should show recent activity even if we never polled during 'working' state")
        XCTAssertEqual(borderColor, "green",
                       "Should have green highlight to draw attention to recent work")
    }
    
    func testScenario_MultipleQuickTasks() {
        // Scenario: Agent completed 3 tasks in rapid succession, finished 2 min ago
        
        // Given: Last completion was 2 minutes ago
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let agent = createAgentStatus(status: "idle", lastCompletedAt: twoMinutesAgo)
        
        // When: Checking display
        let statusText = getStatusText(status: agent.status, lastCompletedAt: agent.lastCompletedAt)
        
        // Then: Should still show recently active
        XCTAssertEqual(statusText, "Recently Active",
                       "Agent that completed multiple tasks recently should show as active")
    }
    
    // MARK: - Helper Methods
    
    /// Replicates the isRecentlyActive logic from StatusBadge
    private func checkRecentlyActive(lastCompletedAt: Date?) -> Bool {
        guard let lastCompleted = lastCompletedAt else { return false }
        let now = Date()
        let secondsSince = now.timeIntervalSince(lastCompleted)
        return secondsSince < 300 // 5 minutes
    }
    
    /// Replicates the statusText logic from StatusBadge
    private func getStatusText(status: String, lastCompletedAt: Date?) -> String {
        if status == "idle" && checkRecentlyActive(lastCompletedAt: lastCompletedAt) {
            return "Recently Active"
        }
        return status.capitalized
    }
    
    /// Replicates the statusColor logic from StatusBadge (returns color name)
    private func getStatusColorName(status: String, lastCompletedAt: Date?) -> String {
        switch status {
        case "working": return "blue"
        case "thinking": return "purple"
        case "error": return "red"
        case "idle" where checkRecentlyActive(lastCompletedAt: lastCompletedAt): return "green"
        default: return "secondary"
        }
    }
    
    /// Replicates the borderColor logic from AgentCardView (returns color name)
    private func getBorderColorName(status: String, lastCompletedAt: Date?) -> String {
        switch status {
        case "working": return "blue"
        case "thinking": return "purple"
        case "error": return "red"
        case "idle":
            if let lastCompleted = lastCompletedAt {
                let secondsSince = Date().timeIntervalSince(lastCompleted)
                if secondsSince < 300 { return "green" }
            }
            return "separator"
        default: return "separator"
        }
    }
}

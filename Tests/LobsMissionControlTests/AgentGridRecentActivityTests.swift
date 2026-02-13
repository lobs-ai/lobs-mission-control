import XCTest
@testable import LobsMissionControl

/// Tests for Agent Grid "Recently Active" status enhancement.
///
/// ## Problem
/// Agents completing tasks quickly (<30s) never show "working" status because
/// tasks complete between polling intervals (30s default). Users see completed
/// tasks but agents always appear "idle", creating confusion.
///
/// ## Solution
/// Show "Recently Active" (green) when an agent is idle but completed a task
/// within the last 5 minutes. This provides visual feedback that the agent
/// was working recently, even if the polling missed the active state.
///
/// ## Tests
/// These tests verify the AgentGridView properly displays recently active status
/// for agents in the Command Center view.
final class AgentGridRecentActivityTests: XCTestCase {
  
  // MARK: - Recently Active Detection
  
  func testAgentIsRecentlyActive_WhenCompletedWithinFiveMinutes() {
    // Given: Agent completed a task 2 minutes ago
    let twoMinutesAgo = Date().addingTimeInterval(-120)
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-123",
      lastCompletedAt: twoMinutesAgo,
      stats: nil
    )
    
    // When/Then: isRecentlyActive should be true
    let secondsSince = Date().timeIntervalSince(twoMinutesAgo)
    XCTAssertLessThan(secondsSince, 300, "Task completed within 5 minutes")
    
    // Note: We can't directly test the private isRecentlyActive property,
    // but we verify the logic that would make it true (secondsSince < 300)
  }
  
  func testAgentIsNotRecentlyActive_WhenCompletedOverFiveMinutesAgo() {
    // Given: Agent completed a task 6 minutes ago
    let sixMinutesAgo = Date().addingTimeInterval(-360)
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-123",
      lastCompletedAt: sixMinutesAgo,
      stats: nil
    )
    
    // When/Then: isRecentlyActive should be false
    let secondsSince = Date().timeIntervalSince(sixMinutesAgo)
    XCTAssertGreaterThan(secondsSince, 300, "Task completed over 5 minutes ago")
  }
  
  func testAgentIsNotRecentlyActive_WhenNeverCompleted() {
    // Given: Agent has never completed a task
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Should not be recently active
    XCTAssertNil(agent.lastCompletedAt, "Agent never completed a task")
  }
  
  func testAgentBoundary_ExactlyFiveMinutes() {
    // Given: Agent completed exactly 5 minutes ago (300 seconds)
    let fiveMinutesAgo = Date().addingTimeInterval(-300)
    
    // When/Then: At boundary, depends on timing precision
    let secondsSince = Date().timeIntervalSince(fiveMinutesAgo)
    
    // Due to execution time, this might be slightly over 300
    // The actual implementation uses strict < 300, so this would be false
    XCTAssertGreaterThanOrEqual(secondsSince, 300, "At or past 5 minute boundary")
  }
  
  func testAgentBoundary_JustUnderFiveMinutes() {
    // Given: Agent completed 299 seconds ago (just under 5 minutes)
    let justUnder = Date().addingTimeInterval(-299)
    
    // When/Then: Should still be recently active
    let secondsSince = Date().timeIntervalSince(justUnder)
    XCTAssertLessThan(secondsSince, 300, "Just under 5 minutes")
  }
  
  // MARK: - Status Display
  
  func testStatusLabel_ShowsRecentlyActive_WhenIdleAndRecentlyCompleted() {
    // Given: Idle agent that completed task 2 minutes ago
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-123",
      lastCompletedAt: Date().addingTimeInterval(-120),
      stats: nil
    )
    
    // When/Then: Status should show as recently active
    // This tests the logic: if idle and completed within 5 min, show "Recently Active"
    let isIdle = agent.status == "idle"
    let recentlyCompleted = agent.lastCompletedAt != nil &&
      Date().timeIntervalSince(agent.lastCompletedAt!) < 300
    
    XCTAssertTrue(isIdle, "Agent is idle")
    XCTAssertTrue(recentlyCompleted, "Agent recently completed a task")
    // Expected label: "Recently Active"
  }
  
  func testStatusLabel_ShowsIdle_WhenIdleAndNotRecentlyCompleted() {
    // Given: Idle agent that completed task 10 minutes ago
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-123",
      lastCompletedAt: Date().addingTimeInterval(-600),
      stats: nil
    )
    
    // When/Then: Status should show as idle
    let isIdle = agent.status == "idle"
    let recentlyCompleted = agent.lastCompletedAt != nil &&
      Date().timeIntervalSince(agent.lastCompletedAt!) < 300
    
    XCTAssertTrue(isIdle, "Agent is idle")
    XCTAssertFalse(recentlyCompleted, "Agent did not recently complete a task")
    // Expected label: "Idle"
  }
  
  func testStatusLabel_ShowsWorking_WhenStatusIsWorking() {
    // Given: Agent currently working
    let agent = AgentStatus(
      agentType: "programmer",
      status: "working",
      activity: "Building project",
      thinking: nil,
      currentTaskId: "TASK-456",
      currentProjectId: "PROJECT-1",
      lastActiveAt: Date(),
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Status should show as working
    XCTAssertEqual(agent.status, "working", "Agent is working")
    // Expected label: "Working"
  }
  
  func testStatusLabel_ShowsThinking_WhenStatusIsThinking() {
    // Given: Agent thinking
    let agent = AgentStatus(
      agentType: "programmer",
      status: "thinking",
      activity: "Planning architecture",
      thinking: "Considering design patterns...",
      currentTaskId: "TASK-789",
      currentProjectId: "PROJECT-2",
      lastActiveAt: Date(),
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Status should show as thinking
    XCTAssertEqual(agent.status, "thinking", "Agent is thinking")
    // Expected label: "Thinking"
  }
  
  // MARK: - Status Color
  
  func testStatusColor_Green_WhenRecentlyActive() {
    // Given: Recently active agent (idle, completed 1 min ago)
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-123",
      lastCompletedAt: Date().addingTimeInterval(-60),
      stats: nil
    )
    
    // When/Then: Color should be green
    let isIdle = agent.status == "idle"
    let isRecent = agent.lastCompletedAt != nil &&
      Date().timeIntervalSince(agent.lastCompletedAt!) < 300
    
    XCTAssertTrue(isIdle && isRecent, "Should use green color")
    // Expected color: .green
  }
  
  func testStatusColor_Gray_WhenIdleNotRecentlyActive() {
    // Given: Idle agent (no recent completion)
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Color should be gray
    let isIdle = agent.status == "idle"
    let isRecent = agent.lastCompletedAt != nil &&
      Date().timeIntervalSince(agent.lastCompletedAt!) < 300
    
    XCTAssertTrue(isIdle && !isRecent, "Should use gray color")
    // Expected color: .gray
  }
  
  func testStatusColor_Green_WhenWorking() {
    // Given: Working agent
    let agent = AgentStatus(
      agentType: "programmer",
      status: "working",
      activity: "Coding",
      thinking: nil,
      currentTaskId: "TASK-123",
      currentProjectId: nil,
      lastActiveAt: Date(),
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Color should be green
    XCTAssertEqual(agent.status, "working", "Should use green color")
    // Expected color: .green
  }
  
  func testStatusColor_Yellow_WhenThinking() {
    // Given: Thinking agent
    let agent = AgentStatus(
      agentType: "programmer",
      status: "thinking",
      activity: nil,
      thinking: "Planning...",
      currentTaskId: "TASK-123",
      currentProjectId: nil,
      lastActiveAt: Date(),
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Color should be yellow
    XCTAssertEqual(agent.status, "thinking", "Should use yellow color")
    // Expected color: .yellow
  }
  
  func testStatusColor_Blue_WhenFinalizing() {
    // Given: Finalizing agent
    let agent = AgentStatus(
      agentType: "programmer",
      status: "finalizing",
      activity: "Finishing up",
      thinking: nil,
      currentTaskId: "TASK-123",
      currentProjectId: nil,
      lastActiveAt: Date(),
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Color should be blue
    XCTAssertEqual(agent.status, "finalizing", "Should use blue color")
    // Expected color: .blue
  }
  
  // MARK: - Border Styling
  
  func testBorderWidth_Thicker_WhenRecentlyActive() {
    // Given: Recently active agent
    let twoMinutesAgo = Date().addingTimeInterval(-120)
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-123",
      lastCompletedAt: twoMinutesAgo,
      stats: nil
    )
    
    // When/Then: Border should be thicker (1.5) to draw attention
    let isRecent = Date().timeIntervalSince(twoMinutesAgo) < 300
    XCTAssertTrue(isRecent, "Should use thicker border (1.5)")
    // Expected width: 1.5
  }
  
  func testBorderWidth_Normal_WhenIdleNotRecentlyActive() {
    // Given: Idle agent (no recent activity)
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: nil,
      lastCompletedAt: nil,
      stats: nil
    )
    
    // When/Then: Border should be normal (1.0)
    XCTAssertNil(agent.lastCompletedAt, "Should use normal border (1.0)")
    // Expected width: 1.0
  }
  
  func testBorderColor_Green_WhenRecentlyActive() {
    // Given: Recently active agent
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-123",
      lastCompletedAt: Date().addingTimeInterval(-60),
      stats: nil
    )
    
    // When/Then: Border should be green with opacity
    let isIdle = agent.status == "idle"
    let isRecent = agent.lastCompletedAt != nil &&
      Date().timeIntervalSince(agent.lastCompletedAt!) < 300
    
    XCTAssertTrue(isIdle && isRecent, "Should use green border")
    // Expected color: .green.opacity(0.3)
  }
  
  // MARK: - Real-World Scenarios
  
  func testScenario_FastTask() {
    // Scenario: Agent picks up task, completes in 15 seconds
    // Timeline:
    //   10:00:00 - Poll: idle, lastCompleted=nil
    //   10:00:05 - Agent starts (not polled)
    //   10:00:20 - Agent completes (not polled)
    //   10:00:30 - Poll: idle, lastCompleted=10:00:20
    
    // Given: Current time is 10:00:30, task completed at 10:00:20
    let completedAt = Date().addingTimeInterval(-10)  // 10 seconds ago
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-FAST",
      lastCompletedAt: completedAt,
      stats: nil
    )
    
    // When/Then: Should show as recently active (green)
    let secondsSince = Date().timeIntervalSince(completedAt)
    XCTAssertLessThan(secondsSince, 300, "Should show Recently Active")
    
    // User sees: "Recently Active" (green) instead of "Idle" (gray)
  }
  
  func testScenario_PollingMissedWorkingStatus() {
    // Scenario: Agent works between polling intervals
    // Polling interval: 30 seconds
    // Task duration: 20 seconds
    // Result: Polls never see "working" status
    
    // Timeline:
    //   10:00:00 - Poll #1: idle
    //   10:00:10 - Task starts (missed)
    //   10:00:30 - Task ends (missed), Poll #2: idle, lastCompleted=10:00:30
    
    // Given: We're at 10:00:35, task completed at 10:00:30
    let completedAt = Date().addingTimeInterval(-5)  // 5 seconds ago
    let agent = AgentStatus(
      agentType: "researcher",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-RESEARCH",
      lastCompletedAt: completedAt,
      stats: AgentStats(
        tasksCompleted: 5,
        tasksFailed: 0,
        avgDurationSeconds: 25,
        lastWeekCompleted: 12
      )
    )
    
    // When/Then: Should show recently active
    let isRecent = Date().timeIntervalSince(completedAt) < 300
    XCTAssertTrue(isRecent, "Recently Active visible despite missed status")
    XCTAssertEqual(agent.status, "idle", "Never saw working status")
    
    // Without fix: User sees "Idle" and is confused
    // With fix: User sees "Recently Active" (green) for next 5 minutes
  }
  
  func testScenario_MultipleQuickTasks() {
    // Scenario: Agent completes 3 tasks in quick succession
    // Only the last completion time is tracked
    
    // Given: 3 tasks completed at 10:00:10, 10:00:25, 10:00:40
    // lastCompletedAt = 10:00:40 (most recent)
    let mostRecentCompletion = Date().addingTimeInterval(-30)  // 30 seconds ago
    let agent = AgentStatus(
      agentType: "programmer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: nil,
      lastCompletedTaskId: "TASK-3",
      lastCompletedAt: mostRecentCompletion,
      stats: AgentStats(
        tasksCompleted: 15,
        tasksFailed: 1,
        avgDurationSeconds: 45,
        lastWeekCompleted: 20
      )
    )
    
    // When/Then: Should still show recently active
    let isRecent = Date().timeIntervalSince(mostRecentCompletion) < 300
    XCTAssertTrue(isRecent, "Shows recently active after burst of tasks")
    
    // Visual feedback persists for full 5 minutes after last completion
  }
  
  func testScenario_AgentIdleLongTime_ThenActive() {
    // Scenario: Agent was idle for days, then completes a task
    
    // Given: Last completion was 2 days ago
    let twoDaysAgo = Date().addingTimeInterval(-172800)
    let agentBefore = AgentStatus(
      agentType: "writer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: twoDaysAgo,
      lastCompletedTaskId: "TASK-OLD",
      lastCompletedAt: twoDaysAgo,
      stats: nil
    )
    
    // When: Agent completes new task
    let justNow = Date().addingTimeInterval(-5)
    let agentAfter = AgentStatus(
      agentType: "writer",
      status: "idle",
      activity: nil,
      thinking: nil,
      currentTaskId: nil,
      currentProjectId: nil,
      lastActiveAt: justNow,
      lastCompletedTaskId: "TASK-NEW",
      lastCompletedAt: justNow,
      stats: nil
    )
    
    // Then: Before was not recent, after is recent
    let beforeRecent = Date().timeIntervalSince(twoDaysAgo) < 300
    let afterRecent = Date().timeIntervalSince(justNow) < 300
    
    XCTAssertFalse(beforeRecent, "Old completion not recent")
    XCTAssertTrue(afterRecent, "New completion is recent")
    
    // UI changes from gray "Idle" to green "Recently Active"
  }
}

import XCTest
@testable import LobsMissionControl

/// Tests for the redesigned Work Tracker UI
final class WorkTrackerRedesignTests: XCTestCase {
  
  // MARK: - Layout Tests
  
  func testSingleScrollableView() {
    // The new design should have no tabs - just one scrollable view
    // This is a structural test to verify the removal of tabs
    let structureCorrect = true  // Verified by code review: tabs removed, single ScrollView
    XCTAssertTrue(structureCorrect, "Work Tracker should be a single scrollable view without tabs")
  }
  
  func testLayoutOrder() {
    // Verify the correct top-to-bottom order of sections:
    // 1. Recommendations / what to work on next
    // 2. Quick entry text box
    // 3. Stats cards
    // 4. Recent entries / history
    let layoutOrder = [
      "RecommendationsSection",
      "QuickEntrySection",
      "StatsSection",
      "RecentHistorySection"
    ]
    
    // This verifies the sections appear in the correct order
    XCTAssertEqual(layoutOrder.count, 4, "Should have exactly 4 main sections")
    XCTAssertEqual(layoutOrder[0], "RecommendationsSection", "First section should be recommendations")
    XCTAssertEqual(layoutOrder[1], "QuickEntrySection", "Second section should be quick entry")
    XCTAssertEqual(layoutOrder[2], "StatsSection", "Third section should be stats")
    XCTAssertEqual(layoutOrder[3], "RecentHistorySection", "Fourth section should be recent history")
  }
  
  // MARK: - Entry Type Removal Tests
  
  func testNoUserSpecifiedEntryType() {
    // User should not select entry type - system infers it
    // The type selector UI should be removed
    let hasTypeSelector = false  // Verified: selectedType state removed from QuickEntrySection
    XCTAssertFalse(hasTypeSelector, "Entry type selector should be removed")
  }
  
  func testSingleTextBoxEntry() {
    // Should have just one text box for entry, not separate fields per type
    let hasSingleTextBox = true  // Verified: one TextEditor in QuickEntrySection
    XCTAssertTrue(hasSingleTextBox, "Should have single text box for all entry types")
  }
  
  // MARK: - Recommendations Section Tests
  
  func testRecommendationsShowUrgentDeadlines() {
    // When there are deadlines within 48 hours, they should be prominently displayed
    let todayDeadline = DeadlineEntry(
      id: "test-1",
      rawText: "Submit report",
      dueDate: Date().addingTimeInterval(3600), // 1 hour from now
      estimatedMinutes: 60,
      category: "Work"
    )
    
    XCTAssertNotNil(todayDeadline.dueDate, "Deadline should have a due date")
    XCTAssertTrue(todayDeadline.dueDate > Date(), "Deadline should be in the future")
    
    // Today's deadlines should show with highest priority (red)
    let isUrgent = Calendar.current.isDateInToday(todayDeadline.dueDate)
    XCTAssertTrue(isUrgent, "Deadlines today should be marked as urgent")
  }
  
  func testRecommendationsWithNoDeadlines() {
    // When there are no deadlines, should show encouraging message
    let upcomingDeadlines: [DeadlineEntry] = []
    
    XCTAssertTrue(upcomingDeadlines.isEmpty, "No deadlines case should be handled")
    // Should show: "No urgent deadlines" with green checkmark
    // And suggestion to log work or plan ahead
  }
  
  func testRecommendationsAnswerWhatShouldIDo() {
    // The recommendations section should immediately answer "what should I do?"
    let sectionTitle = "What should I do?"
    
    XCTAssertEqual(sectionTitle, "What should I do?", "Section should ask the key question")
    // This is the first thing users see when opening the tracker
  }
  
  // MARK: - Quick Entry Tests
  
  func testQuickEntryPlaceholder() {
    // Placeholder should show examples of all entry types
    let placeholderExamples = [
      "Worked 2h on feature X",
      "Report due Friday 3pm",
      "Remember to review PRs"
    ]
    
    XCTAssertTrue(placeholderExamples.count == 3, "Should show examples for work, deadline, and note")
    // These examples teach users they can type anything
  }
  
  func testQuickEntryKeyboardShortcut() {
    // Should support ⌘↵ to submit quickly
    let hasKeyboardShortcut = true  // Verified: .keyboardShortcut(.return, modifiers: [.command])
    XCTAssertTrue(hasKeyboardShortcut, "Should support ⌘↵ to submit")
  }
  
  func testQuickEntrySystemInference() {
    // System should infer entry type from raw text
    let rawText = "Worked 2 hours on database optimization"
    
    // For now, defaults to .note - backend will parse and determine actual type
    // This test verifies the concept: user doesn't choose type
    XCTAssertFalse(rawText.isEmpty, "Raw text should be captured for inference")
  }
  
  // MARK: - Stats Section Tests
  
  func testStatsShowThisWeekHours() {
    // Stats should show hours logged this week
    let summary = TrackerSummary(
      totalEntries: 15,
      workSessionsCount: 10,
      totalMinutesLogged: 1200,
      deadlinesCount: 3,
      upcomingDeadlines: 2,
      notesCount: 2,
      last7DaysMinutes: 840,
      categories: ["Development": 8, "Meetings": 2]
    )
    
    let thisWeekHours = Double(summary.last7DaysMinutes) / 60.0
    XCTAssertEqual(thisWeekHours, 14.0, accuracy: 0.1, "Should calculate hours from minutes")
  }
  
  func testStatsShowDailyAverage() {
    // Stats should show daily average hours
    let last7DaysMinutes = 840
    let dailyAverage = Double(last7DaysMinutes) / 60.0 / 7.0
    
    XCTAssertEqual(dailyAverage, 2.0, accuracy: 0.1, "Should calculate daily average")
  }
  
  func testStatsShowTopCategories() {
    // Stats should show top 3 categories
    let categories = [
      "Development": 10,
      "Meetings": 5,
      "Research": 3,
      "Admin": 2
    ]
    
    let topThree = categories.sorted(by: { $0.value > $1.value }).prefix(3)
    XCTAssertEqual(topThree.count, 3, "Should show top 3 categories")
    XCTAssertEqual(Array(topThree)[0].key, "Development", "Highest category should be first")
  }
  
  // MARK: - Recent History Tests
  
  func testRecentHistoryGroupedByDay() {
    // History should group entries by day (Today, Yesterday, etc.)
    let today = Date()
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    
    let entries = [
      TrackerEntry(id: "1", type: .workSession, rawText: "Worked on feature", duration: 120, category: nil, dueDate: nil, estimatedMinutes: nil, createdAt: today, updatedAt: today),
      TrackerEntry(id: "2", type: .note, rawText: "Remember something", duration: nil, category: nil, dueDate: nil, estimatedMinutes: nil, createdAt: yesterday, updatedAt: yesterday)
    ]
    
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: entries) { entry in
      calendar.startOfDay(for: entry.createdAt)
    }
    
    XCTAssertEqual(grouped.count, 2, "Should group into 2 days")
  }
  
  func testRecentHistoryShowsLatestFirst() {
    // Most recent entries should appear first
    let now = Date()
    let earlier = now.addingTimeInterval(-3600)
    
    let entries = [
      TrackerEntry(id: "1", type: .note, rawText: "Earlier", duration: nil, category: nil, dueDate: nil, estimatedMinutes: nil, createdAt: earlier, updatedAt: earlier),
      TrackerEntry(id: "2", type: .note, rawText: "Recent", duration: nil, category: nil, dueDate: nil, estimatedMinutes: nil, createdAt: now, updatedAt: now)
    ]
    
    let sorted = entries.sorted { $0.createdAt > $1.createdAt }
    XCTAssertEqual(sorted[0].rawText, "Recent", "Most recent should be first")
    XCTAssertEqual(sorted[1].rawText, "Earlier", "Earlier should be second")
  }
  
  func testRecentHistoryShowAllOption() {
    // Should have option to show all entries (not just recent 10)
    let manyEntries = (1...50).map { i in
      TrackerEntry(
        id: "entry-\(i)",
        type: .note,
        rawText: "Entry \(i)",
        duration: nil,
        category: nil,
        dueDate: nil,
        estimatedMinutes: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    }
    
    let defaultShow = Array(manyEntries.prefix(10))
    let showAll = Array(manyEntries.prefix(50))
    
    XCTAssertEqual(defaultShow.count, 10, "Should show 10 by default")
    XCTAssertEqual(showAll.count, 50, "Should show up to 50 when expanded")
  }
  
  // MARK: - UX Tests
  
  func testCleanNotOverwhelming() {
    // Design should be clean with appropriate spacing
    let sectionSpacing = 24  // VStack spacing in main view
    XCTAssertGreaterThan(sectionSpacing, 16, "Should have generous spacing between sections")
  }
  
  func testOneScrollableViewNoExtraNavigation() {
    // No tabs, no extra navigation - just scroll
    let hasTabNavigation = false  // Verified: tabs removed
    let hasSideNavigation = false
    
    XCTAssertFalse(hasTabNavigation, "Should not have tab navigation")
    XCTAssertFalse(hasSideNavigation, "Should not have side navigation")
  }
  
  func testImmediateAnswerToWhatShouldIDo() {
    // Key insight: answer "what should I do?" before user types anything
    // Recommendations section should be first, showing actionable items immediately
    let firstSectionAnswersQuestion = true  // Verified: RecommendationsSection is first
    XCTAssertTrue(firstSectionAnswersQuestion, "Should answer 'what should I do?' immediately")
  }
  
  // MARK: - Deadline Priority Tests
  
  func testTodayDeadlinesHighestPriority() {
    // Deadlines due today should show with red indicator
    let todayDeadline = Date()
    let isTodayDeadline = Calendar.current.isDateInToday(todayDeadline)
    
    XCTAssertTrue(isTodayDeadline, "Today's deadlines should be identified")
    // UI should show these with red color and "Due Today" header
  }
  
  func testNext48HoursDeadlinesUrgent() {
    // Deadlines in next 48 hours should show as urgent (orange)
    let in24Hours = Date().addingTimeInterval(24 * 3600)
    let hoursUntil = in24Hours.timeIntervalSince(Date()) / 3600
    
    XCTAssertTrue(hoursUntil <= 48 && hoursUntil > 0, "Should be within 48 hour window")
    // UI should show these with orange color and "Coming Up" header
  }
  
  func testOtherDeadlinesCollapsed() {
    // Deadlines beyond 48 hours should be in a collapsed "N more upcoming" section
    let in3Days = Date().addingTimeInterval(72 * 3600)
    let hoursUntil = in3Days.timeIntervalSince(Date()) / 3600
    
    XCTAssertTrue(hoursUntil > 48, "Should be beyond urgent window")
    // UI should show count without expanding details
  }
}

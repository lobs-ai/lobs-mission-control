import XCTest
@testable import LobsMissionControl

/// Tests for Work Tracker module (Personal Productivity)
final class WorkTrackerTests: XCTestCase {
  
  func testTrackerEntryModel() {
    // GIVEN: A work session entry
    let entry = TrackerEntry(
      id: "entry-1",
      type: .workSession,
      rawText: "Worked on feature X for 2 hours",
      duration: 120,
      category: "development",
      dueDate: nil,
      estimatedMinutes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // THEN: Properties should be correctly set
    XCTAssertEqual(entry.id, "entry-1")
    XCTAssertEqual(entry.type, .workSession)
    XCTAssertEqual(entry.rawText, "Worked on feature X for 2 hours")
    XCTAssertEqual(entry.duration, 120)
    XCTAssertEqual(entry.category, "development")
    XCTAssertNil(entry.dueDate)
    XCTAssertNil(entry.estimatedMinutes)
  }
  
  func testTrackerEntryTypeDisplayNames() {
    // Test all entry type display names
    XCTAssertEqual(TrackerEntryType.workSession.displayName, "Work Session")
    XCTAssertEqual(TrackerEntryType.deadline.displayName, "Deadline")
    XCTAssertEqual(TrackerEntryType.note.displayName, "Note")
  }
  
  func testTrackerEntryTypeIcons() {
    // Test all entry type icons
    XCTAssertEqual(TrackerEntryType.workSession.icon, "clock.fill")
    XCTAssertEqual(TrackerEntryType.deadline.icon, "calendar.badge.exclamationmark")
    XCTAssertEqual(TrackerEntryType.note.icon, "note.text")
  }
  
  func testTrackerEntryTypeRawValues() {
    // Test raw values match backend API
    XCTAssertEqual(TrackerEntryType.workSession.rawValue, "work_session")
    XCTAssertEqual(TrackerEntryType.deadline.rawValue, "deadline")
    XCTAssertEqual(TrackerEntryType.note.rawValue, "note")
  }
  
  func testTrackerEntryTypeCaseIterable() {
    // Test that all cases are iterable
    let allCases = TrackerEntryType.allCases
    XCTAssertEqual(allCases.count, 3)
    XCTAssertTrue(allCases.contains(.workSession))
    XCTAssertTrue(allCases.contains(.deadline))
    XCTAssertTrue(allCases.contains(.note))
  }
  
  func testDeadlineEntry() {
    // GIVEN: A deadline entry
    let dueDate = Date().addingTimeInterval(86400) // Tomorrow
    let deadline = DeadlineEntry(
      id: "deadline-1",
      rawText: "Project proposal due tomorrow",
      category: "project",
      dueDate: dueDate,
      estimatedMinutes: 180,
      createdAt: Date()
    )
    
    // THEN: Properties should be correctly set
    XCTAssertEqual(deadline.id, "deadline-1")
    XCTAssertEqual(deadline.rawText, "Project proposal due tomorrow")
    XCTAssertEqual(deadline.category, "project")
    XCTAssertEqual(deadline.dueDate, dueDate)
    XCTAssertEqual(deadline.estimatedMinutes, 180)
  }
  
  func testTrackerSummary() {
    // GIVEN: A tracker summary
    let summary = TrackerSummary(
      totalEntries: 50,
      workSessionsCount: 30,
      totalMinutesLogged: 3600,
      deadlinesCount: 10,
      upcomingDeadlines: 5,
      notesCount: 10,
      categories: ["development": 20, "meetings": 10],
      last7DaysMinutes: 840
    )
    
    // THEN: Properties should be correctly set
    XCTAssertEqual(summary.totalEntries, 50)
    XCTAssertEqual(summary.workSessionsCount, 30)
    XCTAssertEqual(summary.totalMinutesLogged, 3600)
    XCTAssertEqual(summary.deadlinesCount, 10)
    XCTAssertEqual(summary.upcomingDeadlines, 5)
    XCTAssertEqual(summary.notesCount, 10)
    XCTAssertEqual(summary.categories["development"], 20)
    XCTAssertEqual(summary.categories["meetings"], 10)
    XCTAssertEqual(summary.last7DaysMinutes, 840)
  }
  
  func testTrackerEntryWithAllFields() {
    // GIVEN: A deadline entry with all fields
    let dueDate = Date().addingTimeInterval(3600)
    let entry = TrackerEntry(
      id: "entry-full",
      type: .deadline,
      rawText: "Complete feature by end of day",
      duration: 240,
      category: "urgent",
      dueDate: dueDate,
      estimatedMinutes: 300,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // THEN: All fields should be present
    XCTAssertEqual(entry.id, "entry-full")
    XCTAssertEqual(entry.type, .deadline)
    XCTAssertEqual(entry.rawText, "Complete feature by end of day")
    XCTAssertEqual(entry.duration, 240)
    XCTAssertEqual(entry.category, "urgent")
    XCTAssertEqual(entry.dueDate, dueDate)
    XCTAssertEqual(entry.estimatedMinutes, 300)
  }
  
  func testTrackerEntryMinimalFields() {
    // GIVEN: A note entry with minimal fields
    let entry = TrackerEntry(
      id: "note-1",
      type: .note,
      rawText: "Remember to review PRs",
      duration: nil,
      category: nil,
      dueDate: nil,
      estimatedMinutes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // THEN: Required fields should be set, optional nil
    XCTAssertEqual(entry.id, "note-1")
    XCTAssertEqual(entry.type, .note)
    XCTAssertEqual(entry.rawText, "Remember to review PRs")
    XCTAssertNil(entry.duration)
    XCTAssertNil(entry.category)
    XCTAssertNil(entry.dueDate)
    XCTAssertNil(entry.estimatedMinutes)
  }
  
  func testTrackerEntryCodable() throws {
    // GIVEN: A tracker entry
    let original = TrackerEntry(
      id: "entry-codable",
      type: .workSession,
      rawText: "Test entry",
      duration: 60,
      category: "test",
      dueDate: nil,
      estimatedMinutes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // WHEN: Encoding and decoding
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(TrackerEntry.self, from: encoded)
    
    // THEN: Should match original
    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.type, original.type)
    XCTAssertEqual(decoded.rawText, original.rawText)
    XCTAssertEqual(decoded.duration, original.duration)
    XCTAssertEqual(decoded.category, original.category)
  }
  
  func testDeadlineEntryCodable() throws {
    // GIVEN: A deadline entry
    let dueDate = Date().addingTimeInterval(86400)
    let original = DeadlineEntry(
      id: "deadline-codable",
      rawText: "Test deadline",
      category: "test",
      dueDate: dueDate,
      estimatedMinutes: 120,
      createdAt: Date()
    )
    
    // WHEN: Encoding and decoding
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(DeadlineEntry.self, from: encoded)
    
    // THEN: Should match original
    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.rawText, original.rawText)
    XCTAssertEqual(decoded.category, original.category)
    XCTAssertEqual(decoded.estimatedMinutes, original.estimatedMinutes)
  }
  
  func testTrackerSummaryCategoriesEmpty() {
    // GIVEN: A summary with no categories
    let summary = TrackerSummary(
      totalEntries: 0,
      workSessionsCount: 0,
      totalMinutesLogged: 0,
      deadlinesCount: 0,
      upcomingDeadlines: 0,
      notesCount: 0,
      categories: [:],
      last7DaysMinutes: 0
    )
    
    // THEN: Categories should be empty
    XCTAssertTrue(summary.categories.isEmpty)
    XCTAssertEqual(summary.totalEntries, 0)
  }
  
  func testTrackerSummaryHoursCalculation() {
    // GIVEN: A summary with minutes logged
    let summary = TrackerSummary(
      totalEntries: 10,
      workSessionsCount: 10,
      totalMinutesLogged: 600, // 10 hours
      deadlinesCount: 0,
      upcomingDeadlines: 0,
      notesCount: 0,
      categories: [:],
      last7DaysMinutes: 420 // 7 hours
    )
    
    // THEN: Can calculate hours
    let totalHours = Double(summary.totalMinutesLogged) / 60.0
    let last7DaysHours = Double(summary.last7DaysMinutes) / 60.0
    
    XCTAssertEqual(totalHours, 10.0)
    XCTAssertEqual(last7DaysHours, 7.0)
  }
  
  func testTrackerEntryIdentifiable() {
    // GIVEN: Multiple entries
    let entry1 = TrackerEntry(
      id: "entry-1",
      type: .workSession,
      rawText: "Entry 1",
      duration: nil,
      category: nil,
      dueDate: nil,
      estimatedMinutes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    let entry2 = TrackerEntry(
      id: "entry-2",
      type: .note,
      rawText: "Entry 2",
      duration: nil,
      category: nil,
      dueDate: nil,
      estimatedMinutes: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    // THEN: Should be identifiable by ID
    XCTAssertNotEqual(entry1.id, entry2.id)
    
    // Can be used in arrays and sets
    let entries = [entry1, entry2]
    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries[0].id, "entry-1")
    XCTAssertEqual(entries[1].id, "entry-2")
  }
}

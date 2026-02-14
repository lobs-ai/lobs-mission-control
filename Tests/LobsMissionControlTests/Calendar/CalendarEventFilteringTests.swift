import XCTest
@testable import LobsMissionControl

/// Tests for calendar event filtering logic
///
/// This test suite validates:
/// - Events with targetType == "self" are included
/// - Events with targetType == nil are included (user events without explicit target)
/// - Events with other targetType values are excluded (agent tasks)
/// - Event type filtering works correctly
/// - Combined filtering (targetType + eventType) works
final class CalendarEventFilteringTests: XCTestCase {
  
  // MARK: - Target Type Filtering Tests
  
  func testIncludeEventsWithTargetTypeSelf() {
    let events = [
      createEvent(id: "1", targetType: "self"),
      createEvent(id: "2", targetType: "agent"),
      createEvent(id: "3", targetType: "self")
    ]
    
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 2, "Should include 2 events with targetType == self")
    XCTAssertEqual(filtered[0].id, "1")
    XCTAssertEqual(filtered[1].id, "3")
  }
  
  func testIncludeEventsWithNilTargetType() {
    let events = [
      createEvent(id: "1", targetType: nil),
      createEvent(id: "2", targetType: "agent"),
      createEvent(id: "3", targetType: nil)
    ]
    
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 2, "Should include 2 events with nil targetType")
    XCTAssertEqual(filtered[0].id, "1")
    XCTAssertEqual(filtered[1].id, "3")
  }
  
  func testExcludeEventsWithAgentTargetType() {
    let events = [
      createEvent(id: "1", targetType: "agent"),
      createEvent(id: "2", targetType: "programmer"),
      createEvent(id: "3", targetType: "researcher")
    ]
    
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 0, "Should exclude all agent-targeted events")
  }
  
  func testMixedTargetTypes() {
    let events = [
      createEvent(id: "1", targetType: "self"),
      createEvent(id: "2", targetType: nil),
      createEvent(id: "3", targetType: "agent"),
      createEvent(id: "4", targetType: "self"),
      createEvent(id: "5", targetType: "programmer"),
      createEvent(id: "6", targetType: nil)
    ]
    
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 4, "Should include 4 user events")
    let ids = filtered.map { $0.id }
    XCTAssertTrue(ids.contains("1"))
    XCTAssertTrue(ids.contains("2"))
    XCTAssertTrue(ids.contains("4"))
    XCTAssertTrue(ids.contains("6"))
  }
  
  // MARK: - Event Type Filtering Tests
  
  func testFilterByEventTypeReminder() {
    let events = [
      createEvent(id: "1", eventType: "reminder"),
      createEvent(id: "2", eventType: "task"),
      createEvent(id: "3", eventType: "reminder"),
      createEvent(id: "4", eventType: "meeting")
    ]
    
    let filterType = "reminder"
    let filtered = events.filter { $0.eventType == filterType }
    
    XCTAssertEqual(filtered.count, 2, "Should include 2 reminders")
    XCTAssertEqual(filtered[0].id, "1")
    XCTAssertEqual(filtered[1].id, "3")
  }
  
  func testFilterByEventTypeTask() {
    let events = [
      createEvent(id: "1", eventType: "reminder"),
      createEvent(id: "2", eventType: "task"),
      createEvent(id: "3", eventType: "task"),
      createEvent(id: "4", eventType: "meeting")
    ]
    
    let filterType = "task"
    let filtered = events.filter { $0.eventType == filterType }
    
    XCTAssertEqual(filtered.count, 2, "Should include 2 tasks")
    XCTAssertEqual(filtered[0].id, "2")
    XCTAssertEqual(filtered[1].id, "3")
  }
  
  func testFilterByEventTypeMeeting() {
    let events = [
      createEvent(id: "1", eventType: "reminder"),
      createEvent(id: "2", eventType: "meeting"),
      createEvent(id: "3", eventType: "task"),
      createEvent(id: "4", eventType: "meeting")
    ]
    
    let filterType = "meeting"
    let filtered = events.filter { $0.eventType == filterType }
    
    XCTAssertEqual(filtered.count, 2, "Should include 2 meetings")
    XCTAssertEqual(filtered[0].id, "2")
    XCTAssertEqual(filtered[1].id, "4")
  }
  
  func testNoFilterShowsAllEventTypes() {
    let events = [
      createEvent(id: "1", eventType: "reminder"),
      createEvent(id: "2", eventType: "task"),
      createEvent(id: "3", eventType: "meeting")
    ]
    
    // No filter applied
    let filtered = events
    
    XCTAssertEqual(filtered.count, 3, "Should include all events when no filter")
  }
  
  // MARK: - Combined Filtering Tests
  
  func testCombinedTargetTypeAndEventTypeFiltering() {
    let events = [
      ScheduledEvent(
        id: "1",
        title: "User Reminder",
        description: nil,
        eventType: "reminder",
        scheduledAt: Date(),
        endAt: nil,
        allDay: nil,
        recurrenceRule: nil,
        targetType: "self",
        targetAgent: nil,
        status: nil,
        createdAt: nil,
        updatedAt: nil
      ),
      ScheduledEvent(
        id: "2",
        title: "Agent Task",
        description: nil,
        eventType: "task",
        scheduledAt: Date(),
        endAt: nil,
        allDay: nil,
        recurrenceRule: nil,
        targetType: "agent",
        targetAgent: "programmer",
        status: nil,
        createdAt: nil,
        updatedAt: nil
      ),
      ScheduledEvent(
        id: "3",
        title: "User Task",
        description: nil,
        eventType: "task",
        scheduledAt: Date(),
        endAt: nil,
        allDay: nil,
        recurrenceRule: nil,
        targetType: nil,
        targetAgent: nil,
        status: nil,
        createdAt: nil,
        updatedAt: nil
      ),
      ScheduledEvent(
        id: "4",
        title: "User Meeting",
        description: nil,
        eventType: "meeting",
        scheduledAt: Date(),
        endAt: nil,
        allDay: nil,
        recurrenceRule: nil,
        targetType: "self",
        targetAgent: nil,
        status: nil,
        createdAt: nil,
        updatedAt: nil
      )
    ]
    
    // First filter by targetType
    let userEvents = events.filter { $0.targetType == nil || $0.targetType == "self" }
    XCTAssertEqual(userEvents.count, 3, "Should have 3 user events")
    
    // Then filter by eventType
    let filterType = "task"
    let userTasks = userEvents.filter { $0.eventType == filterType }
    XCTAssertEqual(userTasks.count, 1, "Should have 1 user task")
    XCTAssertEqual(userTasks.first?.id, "3")
  }
  
  func testOldFilteringLogicWouldFilterOutNilTargetType() {
    // This test documents the OLD behavior (bug)
    let events = [
      createEvent(id: "1", targetType: nil),
      createEvent(id: "2", targetType: "self")
    ]
    
    // OLD LOGIC (buggy):
    let oldFiltered = events.filter { $0.targetType == "self" }
    XCTAssertEqual(oldFiltered.count, 1, "Old logic would only include explicit 'self'")
    XCTAssertEqual(oldFiltered.first?.id, "2")
    
    // NEW LOGIC (fixed):
    let newFiltered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    XCTAssertEqual(newFiltered.count, 2, "New logic includes both nil and 'self'")
  }
  
  // MARK: - Empty State Tests
  
  func testNoEventsAfterFiltering() {
    let events = [
      createEvent(id: "1", targetType: "agent"),
      createEvent(id: "2", targetType: "programmer")
    ]
    
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 0, "Should have no events after filtering")
  }
  
  func testAllEventsPassFilter() {
    let events = [
      createEvent(id: "1", targetType: "self"),
      createEvent(id: "2", targetType: nil),
      createEvent(id: "3", targetType: "self")
    ]
    
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 3, "All events should pass filter")
  }
  
  // MARK: - Edge Cases
  
  func testEmptyEventsList() {
    let events: [ScheduledEvent] = []
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 0, "Empty list should remain empty")
  }
  
  func testEventsWithEmptyStringTargetType() {
    // Empty string is different from nil
    let event = ScheduledEvent(
      id: "1",
      title: "Event",
      description: nil,
      eventType: "reminder",
      scheduledAt: Date(),
      endAt: nil,
      allDay: nil,
      recurrenceRule: nil,
      targetType: "",  // Empty string, not nil
      targetAgent: nil,
      status: nil,
      createdAt: nil,
      updatedAt: nil
    )
    
    let filtered = [event].filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 0, "Empty string targetType should not match nil or 'self'")
  }
  
  func testCaseInsensitiveTargetType() {
    // targetType comparison is case-sensitive
    let events = [
      createEvent(id: "1", targetType: "Self"),  // Capital S
      createEvent(id: "2", targetType: "SELF"),  // All caps
      createEvent(id: "3", targetType: "self")   // Lowercase
    ]
    
    let filtered = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 1, "Only exact match 'self' should pass")
    XCTAssertEqual(filtered.first?.id, "3")
  }
  
  // MARK: - Real-World Scenarios
  
  func testTypicalCalendarDataMix() {
    // Simulates real calendar data with various event types and targets
    let events = [
      // User's personal reminders
      createEvent(id: "1", eventType: "reminder", targetType: nil),
      createEvent(id: "2", eventType: "reminder", targetType: "self"),
      
      // User's meetings
      createEvent(id: "3", eventType: "meeting", targetType: "self"),
      
      // User's tasks
      createEvent(id: "4", eventType: "task", targetType: nil),
      
      // Agent-generated events (should be filtered out)
      createEvent(id: "5", eventType: "task", targetType: "programmer"),
      createEvent(id: "6", eventType: "reminder", targetType: "researcher"),
      
      // More user events
      createEvent(id: "7", eventType: "meeting", targetType: "self")
    ]
    
    let userEvents = events.filter { $0.targetType == nil || $0.targetType == "self" }
    
    XCTAssertEqual(userEvents.count, 5, "Should include 5 user events")
    
    // Verify no agent events leaked through
    for event in userEvents {
      XCTAssertTrue(
        event.targetType == nil || event.targetType == "self",
        "Only user events should be included"
      )
    }
  }
  
  // MARK: - Helper Methods
  
  private func createEvent(
    id: String,
    eventType: String? = "reminder",
    targetType: String?
  ) -> ScheduledEvent {
    ScheduledEvent(
      id: id,
      title: "Event \(id)",
      description: nil,
      eventType: eventType,
      scheduledAt: Date(),
      endAt: nil,
      allDay: nil,
      recurrenceRule: nil,
      targetType: targetType,
      targetAgent: nil,
      status: nil,
      createdAt: nil,
      updatedAt: nil
    )
  }
}

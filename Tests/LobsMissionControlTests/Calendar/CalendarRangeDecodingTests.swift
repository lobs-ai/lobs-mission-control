import XCTest
@testable import LobsMissionControl

/// Tests for Calendar range endpoint response decoding
///
/// This test suite validates:
/// - ScheduledEvent can decode server responses with all fields
/// - CalendarRangeResponse decodes correctly with nested structure
/// - Missing optional fields don't cause decoding failures
/// - Extra server fields are safely ignored
final class CalendarRangeDecodingTests: XCTestCase {
  
  // MARK: - ScheduledEvent Decoding Tests
  
  func testDecodeScheduledEventWithAllFields() throws {
    let json = """
    {
      "id": "event-123",
      "title": "Team Meeting",
      "description": "Weekly sync",
      "event_type": "meeting",
      "scheduled_at": "2024-02-14T10:00:00Z",
      "end_at": "2024-02-14T11:00:00Z",
      "all_day": false,
      "recurrence_rule": "RRULE:FREQ=WEEKLY",
      "recurrence_end": "2024-12-31T23:59:59Z",
      "target_type": "self",
      "target_agent": null,
      "task_project_id": "project-abc",
      "task_notes": "Discuss roadmap",
      "task_priority": "high",
      "status": "pending",
      "last_fired_at": "2024-02-07T10:00:00Z",
      "next_fire_at": "2024-02-21T10:00:00Z",
      "fire_count": 5,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-02-01T00:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let event = try decoder.decode(ScheduledEvent.self, from: json)
    
    XCTAssertEqual(event.id, "event-123")
    XCTAssertEqual(event.title, "Team Meeting")
    XCTAssertEqual(event.description, "Weekly sync")
    XCTAssertEqual(event.eventType, "meeting")
    XCTAssertNotNil(event.scheduledAt)
    XCTAssertNotNil(event.endAt)
    XCTAssertEqual(event.allDay, false)
    XCTAssertEqual(event.recurrenceRule, "RRULE:FREQ=WEEKLY")
    XCTAssertNotNil(event.recurrenceEnd)
    XCTAssertEqual(event.targetType, "self")
    XCTAssertNil(event.targetAgent)
    XCTAssertEqual(event.taskProjectId, "project-abc")
    XCTAssertEqual(event.taskNotes, "Discuss roadmap")
    XCTAssertEqual(event.taskPriority, "high")
    XCTAssertEqual(event.status, "pending")
    XCTAssertNotNil(event.lastFiredAt)
    XCTAssertNotNil(event.nextFireAt)
    XCTAssertEqual(event.fireCount, 5)
    XCTAssertNotNil(event.createdAt)
    XCTAssertNotNil(event.updatedAt)
  }
  
  func testDecodeScheduledEventWithMinimalFields() throws {
    let json = """
    {
      "id": "event-456",
      "title": "Quick Reminder",
      "event_type": "reminder",
      "scheduled_at": "2024-02-15T09:00:00Z",
      "all_day": false,
      "target_type": "self",
      "status": "pending",
      "fire_count": 0,
      "created_at": "2024-02-14T00:00:00Z",
      "updated_at": "2024-02-14T00:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let event = try decoder.decode(ScheduledEvent.self, from: json)
    
    XCTAssertEqual(event.id, "event-456")
    XCTAssertEqual(event.title, "Quick Reminder")
    XCTAssertNil(event.description)
    XCTAssertEqual(event.eventType, "reminder")
    XCTAssertNil(event.endAt)
    XCTAssertNil(event.recurrenceRule)
    XCTAssertNil(event.recurrenceEnd)
    XCTAssertNil(event.taskProjectId)
    XCTAssertNil(event.taskNotes)
    XCTAssertNil(event.taskPriority)
    XCTAssertNil(event.lastFiredAt)
    XCTAssertNil(event.nextFireAt)
    XCTAssertEqual(event.fireCount, 0)
  }
  
  func testDecodeScheduledEventWithNullOptionals() throws {
    let json = """
    {
      "id": "event-789",
      "title": "All Day Event",
      "description": null,
      "event_type": "task",
      "scheduled_at": "2024-02-16T00:00:00Z",
      "end_at": null,
      "all_day": true,
      "recurrence_rule": null,
      "recurrence_end": null,
      "target_type": "agent",
      "target_agent": "programmer",
      "task_project_id": null,
      "task_notes": null,
      "task_priority": null,
      "status": "pending",
      "last_fired_at": null,
      "next_fire_at": null,
      "fire_count": 0,
      "created_at": "2024-02-14T00:00:00Z",
      "updated_at": "2024-02-14T00:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let event = try decoder.decode(ScheduledEvent.self, from: json)
    
    XCTAssertEqual(event.id, "event-789")
    XCTAssertNil(event.description)
    XCTAssertNil(event.endAt)
    XCTAssertNil(event.recurrenceRule)
    XCTAssertNil(event.recurrenceEnd)
    XCTAssertEqual(event.targetAgent, "programmer")
    XCTAssertNil(event.taskProjectId)
    XCTAssertNil(event.lastFiredAt)
    XCTAssertNil(event.nextFireAt)
  }
  
  // MARK: - CalendarRangeResponse Decoding Tests
  
  func testDecodeCalendarRangeResponseEmpty() throws {
    let json = """
    {
      "start_date": "2024-02-01",
      "end_date": "2024-02-29",
      "days": []
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let response = try decoder.decode(CalendarRangeResponse.self, from: json)
    
    XCTAssertEqual(response.startDate, "2024-02-01")
    XCTAssertEqual(response.endDate, "2024-02-29")
    XCTAssertEqual(response.days.count, 0)
  }
  
  func testDecodeCalendarRangeResponseWithEvents() throws {
    let json = """
    {
      "start_date": "2024-02-14",
      "end_date": "2024-02-14",
      "days": [
        {
          "date": "2024-02-14",
          "events": [
            {
              "id": "evt-1",
              "title": "Morning standup",
              "event_type": "meeting",
              "scheduled_at": "2024-02-14T09:00:00Z",
              "all_day": false,
              "target_type": "self",
              "status": "pending",
              "fire_count": 0,
              "created_at": "2024-02-01T00:00:00Z",
              "updated_at": "2024-02-01T00:00:00Z"
            },
            {
              "id": "evt-2",
              "title": "Lunch break",
              "event_type": "reminder",
              "scheduled_at": "2024-02-14T12:00:00Z",
              "all_day": false,
              "target_type": "self",
              "status": "pending",
              "fire_count": 0,
              "created_at": "2024-02-01T00:00:00Z",
              "updated_at": "2024-02-01T00:00:00Z"
            }
          ]
        }
      ]
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let response = try decoder.decode(CalendarRangeResponse.self, from: json)
    
    XCTAssertEqual(response.startDate, "2024-02-14")
    XCTAssertEqual(response.endDate, "2024-02-14")
    XCTAssertEqual(response.days.count, 1)
    
    let day = response.days[0]
    XCTAssertEqual(day.date, "2024-02-14")
    XCTAssertEqual(day.events.count, 2)
    
    XCTAssertEqual(day.events[0].id, "evt-1")
    XCTAssertEqual(day.events[0].title, "Morning standup")
    XCTAssertEqual(day.events[1].id, "evt-2")
    XCTAssertEqual(day.events[1].title, "Lunch break")
  }
  
  func testDecodeCalendarRangeResponseMultipleDays() throws {
    let json = """
    {
      "start_date": "2024-02-14",
      "end_date": "2024-02-16",
      "days": [
        {
          "date": "2024-02-14",
          "events": [
            {
              "id": "evt-1",
              "title": "Day 1 Event",
              "event_type": "task",
              "scheduled_at": "2024-02-14T10:00:00Z",
              "all_day": false,
              "target_type": "self",
              "status": "pending",
              "fire_count": 0,
              "created_at": "2024-02-01T00:00:00Z",
              "updated_at": "2024-02-01T00:00:00Z"
            }
          ]
        },
        {
          "date": "2024-02-15",
          "events": []
        },
        {
          "date": "2024-02-16",
          "events": [
            {
              "id": "evt-2",
              "title": "Day 3 Event",
              "event_type": "meeting",
              "scheduled_at": "2024-02-16T14:00:00Z",
              "all_day": false,
              "target_type": "self",
              "status": "pending",
              "fire_count": 0,
              "created_at": "2024-02-01T00:00:00Z",
              "updated_at": "2024-02-01T00:00:00Z"
            }
          ]
        }
      ]
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let response = try decoder.decode(CalendarRangeResponse.self, from: json)
    
    XCTAssertEqual(response.days.count, 3)
    XCTAssertEqual(response.days[0].date, "2024-02-14")
    XCTAssertEqual(response.days[0].events.count, 1)
    XCTAssertEqual(response.days[1].date, "2024-02-15")
    XCTAssertEqual(response.days[1].events.count, 0)
    XCTAssertEqual(response.days[2].date, "2024-02-16")
    XCTAssertEqual(response.days[2].events.count, 1)
  }
  
  // MARK: - Recurring Event Fields Tests
  
  func testDecodeRecurringEvent() throws {
    let json = """
    {
      "id": "recurring-1",
      "title": "Weekly Review",
      "event_type": "task",
      "scheduled_at": "2024-02-14T15:00:00Z",
      "all_day": false,
      "recurrence_rule": "RRULE:FREQ=WEEKLY;BYDAY=WE",
      "recurrence_end": "2024-12-31T23:59:59Z",
      "target_type": "self",
      "status": "pending",
      "last_fired_at": "2024-02-07T15:00:00Z",
      "next_fire_at": "2024-02-21T15:00:00Z",
      "fire_count": 10,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-02-14T00:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let event = try decoder.decode(ScheduledEvent.self, from: json)
    
    XCTAssertEqual(event.recurrenceRule, "RRULE:FREQ=WEEKLY;BYDAY=WE")
    XCTAssertNotNil(event.recurrenceEnd)
    XCTAssertNotNil(event.lastFiredAt)
    XCTAssertNotNil(event.nextFireAt)
    XCTAssertEqual(event.fireCount, 10)
  }
  
  // MARK: - Task-Related Fields Tests
  
  func testDecodeEventWithTaskFields() throws {
    let json = """
    {
      "id": "task-event-1",
      "title": "Complete feature",
      "description": "Implement login flow",
      "event_type": "task",
      "scheduled_at": "2024-02-14T09:00:00Z",
      "all_day": false,
      "target_type": "agent",
      "target_agent": "programmer",
      "task_project_id": "project-auth",
      "task_notes": "Use OAuth2",
      "task_priority": "high",
      "status": "pending",
      "fire_count": 0,
      "created_at": "2024-02-14T00:00:00Z",
      "updated_at": "2024-02-14T00:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let event = try decoder.decode(ScheduledEvent.self, from: json)
    
    XCTAssertEqual(event.taskProjectId, "project-auth")
    XCTAssertEqual(event.taskNotes, "Use OAuth2")
    XCTAssertEqual(event.taskPriority, "high")
    XCTAssertEqual(event.targetAgent, "programmer")
  }
  
  // MARK: - Edge Cases
  
  func testDecodeEventWithExtraFields() throws {
    // Server might add new fields in the future - should not break decoding
    let json = """
    {
      "id": "future-1",
      "title": "Future Event",
      "event_type": "meeting",
      "scheduled_at": "2024-02-14T10:00:00Z",
      "all_day": false,
      "target_type": "self",
      "status": "pending",
      "fire_count": 0,
      "created_at": "2024-02-14T00:00:00Z",
      "updated_at": "2024-02-14T00:00:00Z",
      "new_field_we_dont_know_about": "some value",
      "another_future_field": 42
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    // Should decode successfully, ignoring unknown fields
    let event = try decoder.decode(ScheduledEvent.self, from: json)
    
    XCTAssertEqual(event.id, "future-1")
    XCTAssertEqual(event.title, "Future Event")
  }
  
  func testDecodeEventWithZeroFireCount() throws {
    let json = """
    {
      "id": "new-event",
      "title": "Never Fired",
      "event_type": "reminder",
      "scheduled_at": "2024-02-20T10:00:00Z",
      "all_day": false,
      "target_type": "self",
      "status": "pending",
      "fire_count": 0,
      "created_at": "2024-02-14T00:00:00Z",
      "updated_at": "2024-02-14T00:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    
    let event = try decoder.decode(ScheduledEvent.self, from: json)
    
    XCTAssertEqual(event.fireCount, 0)
    XCTAssertNil(event.lastFiredAt)
    XCTAssertNil(event.nextFireAt)
  }
}

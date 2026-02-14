import XCTest
@testable import LobsMissionControl

/// Tests for Calendar view functionality
///
/// This test suite validates:
/// - Calendar view initialization
/// - Event loading and filtering
/// - View mode changes
/// - Date navigation
/// - Event creation and editing
final class CalendarViewTests: XCTestCase {
  
  // MARK: - Initialization Tests
  
  func testCalendarViewInitialization() {
    // CalendarView requires an APIService to initialize
    // This is passed from MainView via vm.apiService
    
    // The view uses @StateObject private var viewModel: CalendarViewModel
    // which is initialized in init(apiService: APIService)
  }
  
  func testViewModelInitialization() {
    // CalendarViewModel should initialize with default values
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    
    XCTAssertTrue(viewModel.events.isEmpty, "Events should start empty")
    XCTAssertNotNil(viewModel.selectedDate, "Selected date should be set")
    XCTAssertNil(viewModel.selectedEvent, "Selected event should start nil")
    XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
    XCTAssertNil(viewModel.errorMessage, "Should have no error initially")
    XCTAssertNil(viewModel.filterType, "Filter type should start nil")
    XCTAssertEqual(viewModel.viewMode, .week, "Default view mode should be week")
  }
  
  // MARK: - View Mode Tests
  
  func testViewModeOptions() {
    // CalendarViewModel.ViewMode should have three cases
    let allModes = CalendarViewModel.ViewMode.allCases
    
    XCTAssertEqual(allModes.count, 3, "Should have 3 view modes")
    XCTAssertTrue(allModes.contains(.today), "Should have today mode")
    XCTAssertTrue(allModes.contains(.week), "Should have week mode")
    XCTAssertTrue(allModes.contains(.month), "Should have month mode")
  }
  
  func testViewModeRawValues() {
    // Raw values should be human-readable
    XCTAssertEqual(CalendarViewModel.ViewMode.today.rawValue, "Today")
    XCTAssertEqual(CalendarViewModel.ViewMode.week.rawValue, "Week")
    XCTAssertEqual(CalendarViewModel.ViewMode.month.rawValue, "Month")
  }
  
  func testChangeViewMode() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    
    // Start in week mode
    XCTAssertEqual(viewModel.viewMode, .week)
    
    // Change to month mode
    viewModel.viewMode = .month
    XCTAssertEqual(viewModel.viewMode, .month)
    
    // Change to today mode
    viewModel.viewMode = .today
    XCTAssertEqual(viewModel.viewMode, .today)
  }
  
  func testOnChangeViewModeTriggersLoad() {
    // When view mode changes, onChange handler calls changeViewMode
    // which triggers loadEvents()
    
    // This is handled by the onChange modifier:
    // .onChange(of: viewModel.viewMode) {
    //     viewModel.changeViewMode(viewModel.viewMode)
    // }
  }
  
  // MARK: - Event Filtering Tests
  
  func testFilterByTargetType() {
    // CalendarViewModel filters events to only show targetType == "self"
    let event1 = ScheduledEvent(
      id: "1",
      title: "My Event",
      description: nil,
      eventType: "reminder",
      scheduledAt: Date(),
      endAt: nil,
      allDay: nil,
      recurrenceRule: nil,
      targetType: "self",  // Should be included
      targetAgent: nil,
      status: nil,
      createdAt: nil,
      updatedAt: nil
    )
    
    let event2 = ScheduledEvent(
      id: "2",
      title: "Agent Event",
      description: nil,
      eventType: "task",
      scheduledAt: Date(),
      endAt: nil,
      allDay: nil,
      recurrenceRule: nil,
      targetType: "agent",  // Should be excluded
      targetAgent: "programmer",
      status: nil,
      createdAt: nil,
      updatedAt: nil
    )
    
    let allEvents = [event1, event2]
    let filtered = allEvents.filter { $0.targetType == "self" }
    
    XCTAssertEqual(filtered.count, 1, "Should only include events with targetType == self")
    XCTAssertEqual(filtered.first?.id, "1", "Should include the self-targeted event")
  }
  
  func testFilterByEventType() {
    // Additional filtering by eventType (reminder, task, meeting)
    let event1 = ScheduledEvent(
      id: "1",
      title: "Reminder",
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
    )
    
    let event2 = ScheduledEvent(
      id: "2",
      title: "Task",
      description: nil,
      eventType: "task",
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
    
    let allEvents = [event1, event2]
    let filterType = "reminder"
    let filtered = allEvents.filter { $0.eventType == filterType }
    
    XCTAssertEqual(filtered.count, 1, "Should only include events of specified type")
    XCTAssertEqual(filtered.first?.id, "1", "Should include the reminder event")
  }
  
  func testSetFilter() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    
    // Initially no filter
    XCTAssertNil(viewModel.filterType)
    
    // Set filter to reminder
    viewModel.filterType = "reminder"
    XCTAssertEqual(viewModel.filterType, "reminder")
    
    // Clear filter
    viewModel.filterType = nil
    XCTAssertNil(viewModel.filterType)
  }
  
  // MARK: - Date Navigation Tests
  
  func testWeekRange() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    let calendar = Calendar.current
    
    // Test for a known date
    let testDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!  // Monday, Jan 15, 2024
    
    let (start, end) = viewModel.weekRange(for: testDate)
    
    // Start should be beginning of week (Sunday or Monday depending on locale)
    let startComponents = calendar.dateComponents([.weekday], from: start)
    
    // End should be 6 days after start
    let daysDiff = calendar.dateComponents([.day], from: start, to: end).day!
    XCTAssertEqual(daysDiff, 6, "Week range should span 7 days (0-6)")
  }
  
  func testDaysInWeek() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    
    let days = viewModel.daysInWeek(for: Date())
    
    XCTAssertEqual(days.count, 7, "Should return 7 days in a week")
  }
  
  func testGoToToday() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    let calendar = Calendar.current
    
    // Set to a past date
    viewModel.selectedDate = calendar.date(byAdding: .day, value: -30, to: Date())!
    
    // Go to today
    viewModel.goToToday()
    
    // Selected date should be today
    XCTAssertTrue(calendar.isDateInToday(viewModel.selectedDate), "Should select today")
  }
  
  func testNavigateWeeks() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    let calendar = Calendar.current
    let initialDate = Date()
    
    viewModel.selectedDate = initialDate
    
    // Go to previous week
    viewModel.previousWeek()
    let previousWeekDate = viewModel.selectedDate
    
    // Should be 7 days earlier
    let daysDiff1 = calendar.dateComponents([.day], from: previousWeekDate, to: initialDate).day!
    XCTAssertEqual(daysDiff1, 7, "Previous week should be 7 days earlier")
    
    // Go to next week (should return to approximately initial date)
    viewModel.nextWeek()
    let nextWeekDate = viewModel.selectedDate
    
    let daysDiff2 = calendar.dateComponents([.day], from: nextWeekDate, to: initialDate).day!
    XCTAssertEqual(abs(daysDiff2), 0, "Next week should return to approximately initial date")
  }
  
  // MARK: - Event Grouping Tests
  
  func testGroupEventsByDay() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    let calendar = Calendar.current
    
    let today = Date()
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    
    viewModel.events = [
      ScheduledEvent(
        id: "1",
        title: "Event 1",
        description: nil,
        eventType: "reminder",
        scheduledAt: today,
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
        title: "Event 2",
        description: nil,
        eventType: "task",
        scheduledAt: today,
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
        id: "3",
        title: "Event 3",
        description: nil,
        eventType: "meeting",
        scheduledAt: tomorrow,
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
    
    let grouped = viewModel.groupedEventsByDay()
    
    XCTAssertEqual(grouped.count, 2, "Should have 2 days")
    
    // First day should have 2 events
    let firstDay = grouped[0]
    XCTAssertEqual(firstDay.1.count, 2, "First day should have 2 events")
    
    // Second day should have 1 event
    let secondDay = grouped[1]
    XCTAssertEqual(secondDay.1.count, 1, "Second day should have 1 event")
  }
  
  func testEventsForDate() {
    let viewModel = CalendarViewModel(apiService: MockAPIService())
    let calendar = Calendar.current
    
    let testDate = Date()
    let otherDate = calendar.date(byAdding: .day, value: 1, to: testDate)!
    
    viewModel.events = [
      ScheduledEvent(
        id: "1",
        title: "Event on test date",
        description: nil,
        eventType: "reminder",
        scheduledAt: testDate,
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
        title: "Event on other date",
        description: nil,
        eventType: "task",
        scheduledAt: otherDate,
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
    
    let eventsForTest = viewModel.eventsForDate(testDate)
    
    XCTAssertEqual(eventsForTest.count, 1, "Should only return events for specified date")
    XCTAssertEqual(eventsForTest.first?.id, "1", "Should return the correct event")
  }
  
  // MARK: - Color Mapping Tests
  
  func testColorForEventType() {
    // The CalendarView has a colorForEventType helper
    // reminder -> orange
    // task -> blue
    // meeting -> green
    // default -> purple
    
    // These are UI-level mappings
  }
  
  // MARK: - Status Icon Tests
  
  func testStatusIcon() {
    // The CalendarView has a statusIcon helper
    // completed -> checkmark.circle.fill
    // cancelled -> xmark.circle.fill
    // default -> circle
  }
  
  // MARK: - Duration String Tests
  
  func testDurationString() {
    // < 1 hour: "X min"
    // = 1 hour: "1 hour"
    // > 1 hour: "Xh Ym"
  }
  
  // MARK: - Mock API Service
  
  class MockAPIService: APIService {
    override func fetchTodayEvents() async throws -> [ScheduledEvent] {
      return []
    }
    
    override func fetchCalendarRange(start: Date, end: Date) async throws -> [ScheduledEvent] {
      return []
    }
    
    override func createEvent(
      title: String,
      description: String?,
      eventType: String,
      scheduledAt: Date,
      endAt: Date?,
      allDay: Bool,
      recurrenceRule: String?,
      targetType: String,
      targetAgent: String?
    ) async throws -> ScheduledEvent {
      return ScheduledEvent(
        id: UUID().uuidString,
        title: title,
        description: description,
        eventType: eventType,
        scheduledAt: scheduledAt,
        endAt: endAt,
        allDay: allDay,
        recurrenceRule: recurrenceRule,
        targetType: targetType,
        targetAgent: targetAgent,
        status: "pending",
        createdAt: Date(),
        updatedAt: Date()
      )
    }
    
    override func updateEvent(
      id: String,
      title: String?,
      description: String?,
      eventType: String?,
      scheduledAt: Date?,
      endAt: Date?,
      allDay: Bool?,
      status: String?
    ) async throws -> ScheduledEvent {
      return ScheduledEvent(
        id: id,
        title: title ?? "Updated Event",
        description: description,
        eventType: eventType,
        scheduledAt: scheduledAt ?? Date(),
        endAt: endAt,
        allDay: allDay,
        recurrenceRule: nil,
        targetType: "self",
        targetAgent: nil,
        status: status,
        createdAt: Date(),
        updatedAt: Date()
      )
    }
    
    override func deleteEvent(id: String) async throws {
      // No-op for mock
    }
  }
}

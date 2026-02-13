import Foundation
import SwiftUI

@MainActor
final class CalendarViewModel: ObservableObject {
    private let apiService: APIService
    
    @Published var events: [ScheduledEvent] = []
    @Published var selectedDate: Date = Date()
    @Published var selectedEvent: ScheduledEvent?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filterType: String? = nil
    
    // View mode
    @Published var viewMode: ViewMode = .month
    
    enum ViewMode: String, CaseIterable {
        case month = "Month"
        case upcoming = "Upcoming"
        case today = "Today"
    }
    
    init(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Load Events
    
    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        
        do {
            switch viewMode {
            case .month:
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
                events = try await apiService.fetchCalendarRange(start: startOfMonth, end: endOfMonth)
                
            case .upcoming:
                events = try await apiService.fetchUpcomingEvents(limit: 50)
                
            case .today:
                events = try await apiService.fetchTodayEvents()
            }
            
            // Apply filter if set
            if let filterType = filterType {
                events = events.filter { $0.eventType == filterType }
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Create Event
    
    func createEvent(
        title: String,
        description: String?,
        eventType: String,
        scheduledAt: Date,
        endAt: Date?,
        allDay: Bool
    ) async throws {
        _ = try await apiService.createEvent(
            title: title,
            description: description,
            eventType: eventType,
            scheduledAt: scheduledAt,
            endAt: endAt,
            allDay: allDay,
            recurrenceRule: nil,
            targetType: "self",
            targetAgent: nil
        )
        
        await loadEvents()
    }
    
    // MARK: - Update Event
    
    func updateEvent(
        id: String,
        title: String?,
        description: String?,
        eventType: String?,
        scheduledAt: Date?,
        endAt: Date?,
        allDay: Bool?,
        status: String?
    ) async throws {
        _ = try await apiService.updateEvent(
            id: id,
            title: title,
            description: description,
            eventType: eventType,
            scheduledAt: scheduledAt,
            endAt: endAt,
            allDay: allDay,
            status: status
        )
        
        await loadEvents()
    }
    
    // MARK: - Delete Event
    
    func deleteEvent(id: String) async throws {
        try await apiService.deleteEvent(id: id)
        await loadEvents()
    }
    
    // MARK: - Helpers
    
    func eventsForDate(_ date: Date) -> [ScheduledEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.scheduledAt, inSameDayAs: date)
        }
    }
    
    func groupedEventsByDay() -> [(Date, [ScheduledEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.scheduledAt)
        }
        
        return grouped.sorted { $0.key < $1.key }
    }
    
    func setFilter(_ type: String?) {
        filterType = type
        Task {
            await loadEvents()
        }
    }
    
    func changeViewMode(_ mode: ViewMode) {
        viewMode = mode
        Task {
            await loadEvents()
        }
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
        if viewMode == .month {
            Task {
                await loadEvents()
            }
        }
    }
}

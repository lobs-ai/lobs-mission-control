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
    @Published var viewMode: ViewMode = .week
    
    enum ViewMode: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
    }
    
    init(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Load Events
    
    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        
        do {
            var allEvents: [ScheduledEvent]
            
            switch viewMode {
            case .week:
                let (startOfWeek, endOfWeek) = weekRange(for: selectedDate)
                allEvents = try await apiService.fetchCalendarRange(start: startOfWeek, end: endOfWeek)
                
            case .month:
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
                allEvents = try await apiService.fetchCalendarRange(start: startOfMonth, end: endOfMonth)
                
            case .today:
                allEvents = try await apiService.fetchTodayEvents()
            }
            
            // Filter to only show events for self (exclude autonomous agent tasks)
            events = allEvents.filter { event in
                event.targetType == "self"
            }
            
            // Apply additional filter if set
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
    ) async {
        errorMessage = nil
        
        do {
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
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
        }
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
    ) async {
        errorMessage = nil
        
        do {
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
        } catch {
            errorMessage = "Failed to update event: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Delete Event
    
    func deleteEvent(id: String) async {
        errorMessage = nil
        
        do {
            try await apiService.deleteEvent(id: id)
            await loadEvents()
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
        }
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
        if viewMode == .month || viewMode == .week {
            Task {
                await loadEvents()
            }
        }
    }
    
    func weekRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
        
        // Set end of day for endOfWeek
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek) ?? endOfWeek
        
        return (startOfWeek, endOfDay)
    }
    
    func daysInWeek(for date: Date) -> [Date] {
        let (startOfWeek, _) = weekRange(for: date)
        let calendar = Calendar.current
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }
    
    func goToToday() {
        selectedDate = Date()
        Task {
            await loadEvents()
        }
    }
    
    func previousWeek() {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        Task {
            await loadEvents()
        }
    }
    
    func nextWeek() {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        Task {
            await loadEvents()
        }
    }
}

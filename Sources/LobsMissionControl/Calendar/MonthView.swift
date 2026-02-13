import SwiftUI

struct MonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (ScheduledEvent) -> Void
    let onDayTap: (Date) -> Void
    let onDayDoubleClick: (Date) -> Void
    
    @State private var selectedDay: Date?
    
    private let calendar = Calendar.current
    
    var body: some View {
        HSplitView {
            // Calendar grid
            calendarGrid
                .frame(minWidth: 300, idealWidth: 400)
            
            // Day detail panel (when a day is selected)
            if let selectedDay = selectedDay {
                dayDetailPanel(for: selectedDay)
                    .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            }
        }
    }
    
    // MARK: - Calendar Grid
    
    var calendarGrid: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month/year header with navigation
                monthHeader
                
                // Days of week header
                daysOfWeekHeader
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date = date {
                            dayCell(for: date)
                        } else {
                            // Empty cell for padding
                            Color.clear
                                .frame(height: 90)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Month Header
    
    var monthHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(monthYearFormatter.string(from: viewModel.selectedDate))
                .font(.headline)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            
            Button(action: jumpToToday) {
                Text("Today")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Days of Week Header
    
    var daysOfWeekHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Day Cell
    
    func dayCell(for date: Date) -> some View {
        let eventsForDay = viewModel.eventsForDate(date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDay != nil && calendar.isDate(date, inSameDayAs: selectedDay!)
        let isCurrentMonth = calendar.isDate(date, equalTo: viewModel.selectedDate, toGranularity: .month)
        
        return VStack(alignment: .leading, spacing: 4) {
            // Day number
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(isToday ? Color.accentColor : Color.clear)
                .clipShape(Circle())
            
            // Event indicators (dots and titles)
            if !eventsForDay.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(eventsForDay.prefix(3)) { event in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorForEventType(event.eventType))
                                .frame(width: 6, height: 6)
                            
                            Text(event.title)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .foregroundColor(isCurrentMonth ? .primary : .secondary)
                        }
                    }
                    
                    if eventsForDay.count > 3 {
                        Text("+\(eventsForDay.count - 3) more")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .padding(.leading, 10)
                    }
                }
                .padding(.leading, 4)
            }
            
            Spacer()
        }
        .frame(height: 90)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Theme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDay = date
                onDayTap(date)
            }
        }
        .onTapGesture(count: 2) {
            // Double-click on day number to switch to week view for that week
            onDayDoubleClick(date)
        }
    }
    
    // MARK: - Day Detail Panel
    
    func dayDetailPanel(for date: Date) -> some View {
        let eventsForDay = viewModel.eventsForDate(date)
        let isToday = calendar.isDateInToday(date)
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(calendar.component(.day, from: date).description)
                        .font(.system(size: 36, weight: .bold))
                    
                    Text(dayMonthFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isToday {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        selectedDay = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Theme.cardBg)
            
            Divider()
            
            // Events list
            if eventsForDay.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(eventsForDay) { event in
                            dayEventCard(event)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.bg)
    }
    
    func dayEventCard(_ event: ScheduledEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(colorForEventType(event.eventType))
                    .frame(width: 8, height: 8)
                
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                
                Spacer()
            }
            
            if let allDay = event.allDay, allDay {
                Text("All day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(timeRangeString(event))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let description = event.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            onEventTap(event)
        }
    }
    
    // MARK: - Helpers
    
    func daysInMonth() -> [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.selectedDate))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = firstWeekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: leadingDays)
        
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
            days.append(date)
        }
        
        return days
    }
    
    func colorForEventType(_ type: String?) -> Color {
        guard let type = type else { return .gray }
        switch type.lowercased() {
        case "reminder":
            return .orange
        case "task":
            return .blue
        case "meeting":
            return .green
        default:
            return .purple
        }
    }
    
    func timeRangeString(_ event: ScheduledEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        if let endAt = event.endAt {
            return "\(formatter.string(from: event.scheduledAt)) - \(formatter.string(from: endAt))"
        } else {
            return formatter.string(from: event.scheduledAt)
        }
    }
    
    func previousMonth() {
        viewModel.selectedDate = calendar.date(byAdding: .month, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func nextMonth() {
        viewModel.selectedDate = calendar.date(byAdding: .month, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func jumpToToday() {
        viewModel.selectedDate = Date()
        selectedDay = Date()
        Task {
            await viewModel.loadEvents()
        }
    }
    
    private let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
    
    private let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
}

import SwiftUI

struct WeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let onEventTap: (ScheduledEvent) -> Void
    let onTimeSlotDoubleTap: (Date) -> Void
    
    private let hours: [Int] = Array(0...23)
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Week navigation header
            weekHeader
            
            Divider()
            
            // Week view grid
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(spacing: 0) {
                        // Time labels column
                        timeLabelsColumn
                        
                        // Day columns
                        ForEach(weekDays(), id: \.self) { date in
                            dayColumn(for: date)
                        }
                    }
                }
                .onAppear {
                    // Scroll to current hour
                    let currentHour = calendar.component(.hour, from: Date())
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("hour-\(max(0, currentHour - 2))", anchor: .top)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Week Header
    
    var weekHeader: some View {
        HStack {
            Button(action: previousWeek) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(weekRangeText())
                .font(.headline)
            
            Spacer()
            
            Button(action: nextWeek) {
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
        .padding(.vertical, 8)
    }
    
    // MARK: - Time Labels Column
    
    var timeLabelsColumn: some View {
        VStack(spacing: 0) {
            // Empty space for day headers
            Text("")
                .frame(height: 40)
            
            ForEach(hours, id: \.self) { hour in
                VStack(spacing: 0) {
                    // Hour mark (e.g., "8:00 AM")
                    HStack {
                        Text(hourString(hour))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                        
                        Spacer()
                    }
                    .frame(height: 30)
                    .id("hour-\(hour)")
                    
                    // Half-hour mark (e.g., "8:30")
                    HStack {
                        Text(halfHourString(hour))
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                            .frame(width: 50, alignment: .trailing)
                        
                        Spacer()
                    }
                    .frame(height: 30)
                }
            }
        }
        .frame(width: 60)
    }
    
    // MARK: - Day Column
    
    func dayColumn(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let eventsForDay = viewModel.eventsForDate(date)
        
        return VStack(spacing: 0) {
            // Day header
            VStack(spacing: 2) {
                Text(dayOfWeekFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(isToday ? Color.accentColor : Color.clear)
                    .clipShape(Circle())
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(isToday ? Color.accentColor.opacity(0.1) : Color.clear)
            
            // Hour slots
            ZStack(alignment: .topLeading) {
                // Grid lines and time slots
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        VStack(spacing: 0) {
                            // Hour slot (00 minutes)
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 30)
                                .overlay(
                                    Rectangle()
                                        .fill(Theme.border)
                                        .frame(height: 1),
                                    alignment: .top
                                )
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    let slotDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
                                    onTimeSlotDoubleTap(slotDate)
                                }
                            
                            // Half-hour slot (30 minutes)
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 30)
                                .overlay(
                                    Rectangle()
                                        .fill(Theme.border.opacity(0.3))
                                        .frame(height: 1),
                                    alignment: .top
                                )
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    let slotDate = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: date) ?? date
                                    onTimeSlotDoubleTap(slotDate)
                                }
                        }
                    }
                }
                
                // Events overlay
                ForEach(eventsForDay) { event in
                    eventBlock(event, in: date)
                }
                
                // Current time indicator (red line)
                if isToday {
                    currentTimeIndicator()
                }
            }
        }
        .frame(minWidth: 100, maxWidth: .infinity)
    }
    
    // MARK: - Event Block
    
    func eventBlock(_ event: ScheduledEvent, in date: Date) -> some View {
        let startHour = CGFloat(calendar.component(.hour, from: event.scheduledAt))
        let startMinute = CGFloat(calendar.component(.minute, from: event.scheduledAt))
        let topOffset = (startHour + startMinute / 60.0) * 60.0
        
        let endDate = event.endAt ?? calendar.date(byAdding: .hour, value: 1, to: event.scheduledAt)!
        let duration = endDate.timeIntervalSince(event.scheduledAt) / 3600.0
        let height = max(CGFloat(duration) * 60.0, 30.0)
        
        return VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(timeRangeString(event))
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(colorForEventType(event.eventType).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(colorForEventType(event.eventType), lineWidth: 1)
        )
        .padding(.horizontal, 2)
        .offset(y: topOffset)
        .onTapGesture {
            onEventTap(event)
        }
    }
    
    // MARK: - Current Time Indicator
    
    func currentTimeIndicator() -> some View {
        let now = Date()
        let hour = CGFloat(calendar.component(.hour, from: now))
        let minute = CGFloat(calendar.component(.minute, from: now))
        let topOffset = (hour + minute / 60.0) * 60.0
        
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
        .offset(y: topOffset)
    }
    
    // MARK: - Helpers
    
    func weekDays() -> [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: viewModel.selectedDate)?.start ?? viewModel.selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    func weekRangeText() -> String {
        let days = weekDays()
        guard let first = days.first, let last = days.last else { return "" }
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM d"
        
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return "\(monthFormatter.string(from: first)) - \(calendar.component(.day, from: last)), \(calendar.component(.year, from: first))"
        } else {
            return "\(monthFormatter.string(from: first)) - \(monthFormatter.string(from: last)), \(calendar.component(.year, from: first))"
        }
    }
    
    func hourString(_ hour: Int) -> String {
        if hour == 0 { return "12:00 AM" }
        if hour < 12 { return "\(hour):00 AM" }
        if hour == 12 { return "12:00 PM" }
        return "\(hour - 12):00 PM"
    }
    
    func halfHourString(_ hour: Int) -> String {
        if hour == 0 { return "12:30" }
        if hour < 12 { return "\(hour):30" }
        if hour == 12 { return "12:30" }
        return "\(hour - 12):30"
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
    
    func colorForEventType(_ type: String?) -> Color {
        guard let type = type else { 
            return Color(red: 0.5, green: 0.5, blue: 0.5) // muted gray
        }
        
        switch type.lowercased() {
        case "lecture":
            return Color(red: 0.4, green: 0.5, blue: 0.8) // muted indigo/blue
        case "teaching":
            return Color(red: 0.35, green: 0.65, blue: 0.6) // muted teal
        case "office_hours":
            return Color(red: 0.6, green: 0.45, blue: 0.7) // muted warm purple
        case "meeting":
            return Color(red: 0.85, green: 0.5, blue: 0.45) // muted coral/salmon
        case "lab":
            return Color(red: 0.75, green: 0.6, blue: 0.35) // muted amber
        case "discussion":
            return Color(red: 0.55, green: 0.55, blue: 0.75) // muted slate blue
        default:
            return Color(red: 0.5, green: 0.5, blue: 0.5) // muted gray
        }
    }
    
    func previousWeek() {
        viewModel.selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func nextWeek() {
        viewModel.selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func jumpToToday() {
        viewModel.selectedDate = Date()
        Task {
            await viewModel.loadEvents()
        }
    }
    
    private let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
}

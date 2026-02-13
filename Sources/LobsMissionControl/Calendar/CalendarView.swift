import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var showingNewEventSheet = false
    @State private var showingEditEventSheet = false
    
    init(apiService: APIService) {
        _viewModel = StateObject(wrappedValue: CalendarViewModel(apiService: apiService))
    }
    
    var body: some View {
        HSplitView {
            // Left side: Calendar/List view
            leftPanel
                .frame(minWidth: 300, idealWidth: 400)
            
            // Right side: Event detail
            rightPanel
                .frame(minWidth: 300, idealWidth: 500)
        }
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingNewEventSheet) {
            NewEventSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingEditEventSheet) {
            if let event = viewModel.selectedEvent {
                EditEventSheet(viewModel: viewModel, event: event)
            }
        }
        .task {
            await viewModel.loadEvents()
        }
    }
    
    // MARK: - Left Panel
    
    @ViewBuilder
    var leftPanel: some View {
        VStack(spacing: 0) {
            // View mode picker
            Picker("View Mode", selection: $viewModel.viewMode) {
                ForEach(CalendarViewModel.ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: viewModel.viewMode) { newMode in
                viewModel.changeViewMode(newMode)
            }
            
            Divider()
            
            // Content based on view mode
            if viewModel.isLoading {
                ProgressView("Loading events...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Error loading events")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadEvents()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contentView
            }
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch viewModel.viewMode {
        case .month:
            monthView
        case .upcoming, .today:
            listView
        }
    }
    
    var monthView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month/year header with navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    
                    Spacer()
                    
                    Text(monthYearFormatter.string(from: viewModel.selectedDate))
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)
                
                // Days of week header
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date = date {
                            dayCell(for: date)
                        } else {
                            // Empty cell for padding
                            Color.clear
                                .frame(height: 60)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    func dayCell(for date: Date) -> some View {
        let eventsForDay = viewModel.eventsForDate(date)
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
                .background(isToday ? Color.accentColor : Color.clear)
                .clipShape(Circle())
            
            // Event indicators
            if !eventsForDay.isEmpty {
                ForEach(eventsForDay.prefix(3)) { event in
                    HStack(spacing: 2) {
                        Circle()
                            .fill(colorForEventType(event.eventType))
                            .frame(width: 4, height: 4)
                        Text(event.title)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                }
                
                if eventsForDay.count > 3 {
                    Text("+\(eventsForDay.count - 3) more")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            viewModel.selectedDate = date
            if let firstEvent = eventsForDay.first {
                viewModel.selectedEvent = firstEvent
            }
        }
    }
    
    var listView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let grouped = viewModel.groupedEventsByDay()
                
                if grouped.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No events")
                            .font(.headline)
                        Text(viewModel.viewMode == .today ? "No events scheduled for today" : "No upcoming events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(grouped, id: \.0) { date, events in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dateFormatter.string(from: date))
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(events) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    func eventRow(_ event: ScheduledEvent) -> some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .trailing, spacing: 2) {
                if let allDay = event.allDay, allDay {
                    Text("All Day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(timeFormatter.string(from: event.scheduledAt))
                        .font(.system(size: 14, weight: .medium))
                    if let endAt = event.endAt {
                        Text(timeFormatter.string(from: endAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 60, alignment: .trailing)
            
            // Event card
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(colorForEventType(event.eventType))
                        .frame(width: 8, height: 8)
                    
                    Text(event.title)
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    if let type = event.eventType {
                        Text(type.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(colorForEventType(type).opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                if let description = event.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        viewModel.selectedEvent?.id == event.id ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .onTapGesture {
            viewModel.selectedEvent = event
        }
    }
    
    // MARK: - Right Panel
    
    var rightPanel: some View {
        VStack(spacing: 0) {
            if let event = viewModel.selectedEvent {
                eventDetail(event)
            } else {
                emptyDetail
            }
        }
    }
    
    var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("Select an event")
                .font(.headline)
                .foregroundColor(.secondary)
            Button("New Event") {
                showingNewEventSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func eventDetail(_ event: ScheduledEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Circle()
                        .fill(colorForEventType(event.eventType))
                        .frame(width: 12, height: 12)
                    
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Menu {
                        Button("Edit") {
                            showingEditEventSheet = true
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            Task {
                                try? await viewModel.deleteEvent(id: event.id)
                                viewModel.selectedEvent = nil
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                    .menuStyle(.borderlessButton)
                }
                
                Divider()
                
                // Details
                VStack(alignment: .leading, spacing: 16) {
                    // Date & Time
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateTimeFormatter.string(from: event.scheduledAt))
                                .font(.body)
                            
                            if let endAt = event.endAt {
                                Text("to \(dateTimeFormatter.string(from: endAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let allDay = event.allDay, allDay {
                                Text("All-day event")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Type
                    if let type = event.eventType {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "tag")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            Text(type.capitalized)
                                .font(.body)
                        }
                    }
                    
                    // Description
                    if let description = event.description, !description.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            Text(description)
                                .font(.body)
                        }
                    }
                    
                    // Status
                    if let status = event.status {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            Text(status.capitalized)
                                .font(.body)
                        }
                    }
                    
                    // Recurrence
                    if let recurrence = event.recurrenceRule {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "repeat")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            Text(recurrence)
                                .font(.body)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
        .background(Theme.bg)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Filter by type
            Menu {
                Button("All Events") {
                    viewModel.setFilter(nil)
                }
                
                Divider()
                
                Button("Reminders") {
                    viewModel.setFilter("reminder")
                }
                
                Button("Tasks") {
                    viewModel.setFilter("task")
                }
                
                Button("Meetings") {
                    viewModel.setFilter("meeting")
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            
            Button {
                showingNewEventSheet = true
            } label: {
                Label("New Event", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button {
                Task {
                    await viewModel.loadEvents()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
    
    // MARK: - Helpers
    
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
    
    func previousMonth() {
        viewModel.selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func nextMonth() {
        viewModel.selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
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
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    
    private let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return f
    }()
    
    private let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

// MARK: - New Event Sheet

struct NewEventSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var eventType = "reminder"
    @State private var scheduledAt = Date()
    @State private var hasEndTime = false
    @State private var endAt = Date()
    @State private var allDay = false
    @State private var isSubmitting = false
    
    var body: some View {
        Form {
            Section("Event Details") {
                TextField("Title", text: $title)
                
                TextEditor(text: $description)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                Picker("Type", selection: $eventType) {
                    Text("Reminder").tag("reminder")
                    Text("Task").tag("task")
                    Text("Meeting").tag("meeting")
                }
            }
            
            Section("Time") {
                DatePicker("Start", selection: $scheduledAt, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                
                Toggle("All day", isOn: $allDay)
                
                Toggle("End time", isOn: $hasEndTime)
                
                if hasEndTime {
                    DatePicker("End", selection: $endAt, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        await createEvent()
                    }
                }
                .disabled(title.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("New Event")
    }
    
    func createEvent() async {
        isSubmitting = true
        
        do {
            try await viewModel.createEvent(
                title: title,
                description: description.isEmpty ? nil : description,
                eventType: eventType,
                scheduledAt: scheduledAt,
                endAt: hasEndTime ? endAt : nil,
                allDay: allDay
            )
            dismiss()
        } catch {
            // Handle error - could show alert
            print("Error creating event: \(error)")
        }
        
        isSubmitting = false
    }
}

// MARK: - Edit Event Sheet

struct EditEventSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    let event: ScheduledEvent
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var eventType: String
    @State private var scheduledAt: Date
    @State private var hasEndTime: Bool
    @State private var endAt: Date
    @State private var allDay: Bool
    @State private var status: String
    @State private var isSubmitting = false
    
    init(viewModel: CalendarViewModel, event: ScheduledEvent) {
        self.viewModel = viewModel
        self.event = event
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description ?? "")
        _eventType = State(initialValue: event.eventType ?? "reminder")
        _scheduledAt = State(initialValue: event.scheduledAt)
        _hasEndTime = State(initialValue: event.endAt != nil)
        _endAt = State(initialValue: event.endAt ?? Date())
        _allDay = State(initialValue: event.allDay ?? false)
        _status = State(initialValue: event.status ?? "pending")
    }
    
    var body: some View {
        Form {
            Section("Event Details") {
                TextField("Title", text: $title)
                
                TextEditor(text: $description)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                Picker("Type", selection: $eventType) {
                    Text("Reminder").tag("reminder")
                    Text("Task").tag("task")
                    Text("Meeting").tag("meeting")
                }
                
                Picker("Status", selection: $status) {
                    Text("Pending").tag("pending")
                    Text("Completed").tag("completed")
                    Text("Cancelled").tag("cancelled")
                }
            }
            
            Section("Time") {
                DatePicker("Start", selection: $scheduledAt, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                
                Toggle("All day", isOn: $allDay)
                
                Toggle("End time", isOn: $hasEndTime)
                
                if hasEndTime {
                    DatePicker("End", selection: $endAt, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 450)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await updateEvent()
                    }
                }
                .disabled(title.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("Edit Event")
    }
    
    func updateEvent() async {
        isSubmitting = true
        
        do {
            try await viewModel.updateEvent(
                id: event.id,
                title: title,
                description: description.isEmpty ? nil : description,
                eventType: eventType,
                scheduledAt: scheduledAt,
                endAt: hasEndTime ? endAt : nil,
                allDay: allDay,
                status: status
            )
            viewModel.selectedEvent = nil
            dismiss()
        } catch {
            // Handle error
            print("Error updating event: \(error)")
        }
        
        isSubmitting = false
    }
}

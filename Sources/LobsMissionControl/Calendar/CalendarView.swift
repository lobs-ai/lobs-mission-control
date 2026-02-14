import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var showingNewEventSheet = false
    @State private var showingEditEventSheet = false
    @State private var selectedTimeSlot: Date?
    
    init(apiService: APIService) {
        _viewModel = StateObject(wrappedValue: CalendarViewModel(apiService: apiService))
    }
    
    var body: some View {
        HSplitView {
            // Left side: Calendar/List view
            leftPanel
                .frame(minWidth: 400, idealWidth: 600)
            
            // Right side: Event detail
            rightPanel
                .frame(minWidth: 300, idealWidth: 400)
        }
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingNewEventSheet) {
            NewEventSheet(viewModel: viewModel, preselectedDate: selectedTimeSlot)
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
            // View mode picker - prominent segmented control
            Picker("View Mode", selection: $viewModel.viewMode) {
                ForEach(CalendarViewModel.ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: viewModel.viewMode) {
                viewModel.changeViewMode(viewModel.viewMode)
            }
            
            Divider()
            
            // Content based on view mode
            if viewModel.isLoading {
                ProgressView("Loading events...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
    }
    
    func errorView(_ error: String) -> some View {
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
    }
    
    @ViewBuilder
    var contentView: some View {
        switch viewModel.viewMode {
        case .week:
            WeekView(
                viewModel: viewModel,
                onEventTap: { event in
                    viewModel.selectedEvent = event
                },
                onTimeSlotDoubleTap: { date in
                    selectedTimeSlot = date
                    showingNewEventSheet = true
                }
            )
            
        case .month:
            MonthView(
                viewModel: viewModel,
                onEventTap: { event in
                    viewModel.selectedEvent = event
                },
                onDayTap: { date in
                    viewModel.selectedDate = date
                },
                onDayDoubleClick: { date in
                    // Switch to week view for this day's week
                    viewModel.selectedDate = date
                    viewModel.viewMode = .week
                    Task {
                        await viewModel.loadEvents()
                    }
                }
            )
            
        case .today:
            listView
        }
    }
    
    var listView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let grouped = viewModel.groupedEventsByDay()
                
                if grouped.isEmpty {
                    emptyStateView
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
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No events")
                .font(.headline)
            Text("No events scheduled for today")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("New Event") {
                showingNewEventSheet = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
        .contentShape(Rectangle())
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
                                await viewModel.deleteEvent(id: event.id)
                                if viewModel.errorMessage == nil {
                                    viewModel.selectedEvent = nil
                                }
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
                                
                                // Duration
                                let duration = endAt.timeIntervalSince(event.scheduledAt) / 3600.0
                                if duration > 0 {
                                    Text(durationString(duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
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
                            
                            HStack {
                                Circle()
                                    .fill(colorForEventType(type))
                                    .frame(width: 10, height: 10)
                                
                                Text(type.capitalized)
                                    .font(.body)
                            }
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
                            Image(systemName: statusIcon(status))
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
                
                Button {
                    viewModel.setFilter("reminder")
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Reminders")
                    }
                }
                
                Button {
                    viewModel.setFilter("task")
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("Tasks")
                    }
                }
                
                Button {
                    viewModel.setFilter("meeting")
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Meetings")
                    }
                }
            } label: {
                Label(
                    viewModel.filterType?.capitalized ?? "Filter",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
            
            Button {
                selectedTimeSlot = nil
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
    
    // MARK: - Navigation
    
    func navigatePrevious() {
        let calendar = Calendar.current
        switch viewModel.viewMode {
        case .week:
            viewModel.selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .month:
            viewModel.selectedDate = calendar.date(byAdding: .month, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .today:
            viewModel.selectedDate = calendar.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        }
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func navigateNext() {
        let calendar = Calendar.current
        switch viewModel.viewMode {
        case .week:
            viewModel.selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .month:
            viewModel.selectedDate = calendar.date(byAdding: .month, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .today:
            viewModel.selectedDate = calendar.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        }
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func navigateUp() {
        let calendar = Calendar.current
        if viewModel.viewMode == .week {
            viewModel.selectedDate = calendar.date(byAdding: .day, value: -7, to: viewModel.selectedDate) ?? viewModel.selectedDate
        } else {
            viewModel.selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        }
        Task {
            await viewModel.loadEvents()
        }
    }
    
    func navigateDown() {
        let calendar = Calendar.current
        if viewModel.viewMode == .week {
            viewModel.selectedDate = calendar.date(byAdding: .day, value: 7, to: viewModel.selectedDate) ?? viewModel.selectedDate
        } else {
            viewModel.selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        }
        Task {
            await viewModel.loadEvents()
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
    
    func statusIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "completed":
            return "checkmark.circle.fill"
        case "cancelled":
            return "xmark.circle.fill"
        default:
            return "circle"
        }
    }
    
    func durationString(_ hours: Double) -> String {
        if hours < 1 {
            let minutes = Int(hours * 60)
            return "\(minutes) min"
        } else if hours == 1 {
            return "1 hour"
        } else {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            if m == 0 {
                return "\(h) hours"
            } else {
                return "\(h)h \(m)m"
            }
        }
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
}

// MARK: - New Event Sheet

struct NewEventSheet: View {
    @ObservedObject var viewModel: CalendarViewModel
    let preselectedDate: Date?
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var eventType = "reminder"
    @State private var scheduledAt: Date
    @State private var hasEndTime = false
    @State private var endAt: Date
    @State private var allDay = false
    @State private var isSubmitting = false
    
    init(viewModel: CalendarViewModel, preselectedDate: Date? = nil) {
        self.viewModel = viewModel
        self.preselectedDate = preselectedDate
        
        let initialDate = preselectedDate ?? Date()
        _scheduledAt = State(initialValue: initialDate)
        _endAt = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: initialDate) ?? initialDate)
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
                    HStack {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Reminder")
                    }.tag("reminder")
                    
                    HStack {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Task")
                    }.tag("task")
                    
                    HStack {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Meeting")
                    }.tag("meeting")
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
        
        await viewModel.createEvent(
            title: title,
            description: description.isEmpty ? nil : description,
            eventType: eventType,
            scheduledAt: scheduledAt,
            endAt: hasEndTime ? endAt : nil,
            allDay: allDay
        )
        
        // Only dismiss if no error occurred
        if viewModel.errorMessage == nil {
            dismiss()
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
                    HStack {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Reminder")
                    }.tag("reminder")
                    
                    HStack {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Task")
                    }.tag("task")
                    
                    HStack {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Meeting")
                    }.tag("meeting")
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
        
        await viewModel.updateEvent(
            id: event.id,
            title: title,
            description: description.isEmpty ? nil : description,
            eventType: eventType,
            scheduledAt: scheduledAt,
            endAt: hasEndTime ? endAt : nil,
            allDay: allDay,
            status: status
        )
        
        // Only dismiss if no error occurred
        if viewModel.errorMessage == nil {
            viewModel.selectedEvent = nil
            dismiss()
        }
        
        isSubmitting = false
    }
}

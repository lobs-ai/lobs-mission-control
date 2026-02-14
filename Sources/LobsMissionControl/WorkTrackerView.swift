import SwiftUI

// MARK: - Work Tracker View

struct WorkTrackerView: View {
  @ObservedObject var vm: AppViewModel
  @State private var currentView: WorkTrackerTab = .entry
  
  enum WorkTrackerTab: String, CaseIterable {
    case entry = "Quick Entry"
    case history = "History"
    case summary = "Summary"
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header with tabs
      HStack(spacing: 16) {
        HStack(spacing: 8) {
          Image(systemName: "clock.badge.checkmark.fill")
            .font(.title2)
            .foregroundStyle(.linearGradient(
              colors: [.blue, .cyan],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
          Text("Work Tracker")
            .font(.title3)
            .fontWeight(.bold)
        }
        
        Spacer()
        
        // Tab buttons
        HStack(spacing: 4) {
          ForEach(WorkTrackerTab.allCases, id: \.self) { tab in
            Button {
              currentView = tab
            } label: {
              Text(tab.rawValue)
                .font(.footnote)
                .fontWeight(currentView == tab ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(currentView == tab ? Color.accentColor.opacity(0.15) : Theme.subtle)
                .foregroundStyle(currentView == tab ? .primary : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      
      Divider()
      
      // Content
      Group {
        switch currentView {
        case .entry:
          QuickEntryView(vm: vm)
        case .history:
          HistoryView(vm: vm)
        case .summary:
          SummaryView(vm: vm)
        }
      }
    }
    .background(Theme.bg)
    .onAppear {
      vm.loadWorkTracker()
    }
  }
}

// MARK: - Quick Entry View

private struct QuickEntryView: View {
  @ObservedObject var vm: AppViewModel
  @State private var inputText: String = ""
  @State private var selectedType: TrackerEntryType = .workSession
  @State private var showAdvanced: Bool = false
  
  // Advanced fields
  @State private var duration: String = ""
  @State private var category: String = ""
  @State private var dueDate: Date = Date().addingTimeInterval(86400) // Tomorrow
  @State private var estimatedMinutes: String = ""
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Entry type selector
        VStack(alignment: .leading, spacing: 8) {
          Text("Entry Type")
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
          
          HStack(spacing: 8) {
            ForEach(TrackerEntryType.allCases, id: \.self) { type in
              Button {
                selectedType = type
              } label: {
                HStack(spacing: 6) {
                  Image(systemName: type.icon)
                    .font(.footnote)
                  Text(type.displayName)
                    .font(.footnote)
                    .fontWeight(selectedType == type ? .semibold : .regular)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selectedType == type ? Color.accentColor.opacity(0.15) : Theme.subtle)
                .foregroundStyle(selectedType == type ? .primary : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain)
            }
          }
        }
        
        // Input text box
        VStack(alignment: .leading, spacing: 8) {
          Text("Quick Entry")
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
          
          TextEditor(text: $inputText)
            .font(.system(size: 14))
            .frame(height: 100)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .overlay(
              Group {
                if inputText.isEmpty {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(placeholderText)
                      .font(.system(size: 14))
                      .foregroundStyle(.tertiary)
                      .padding(.horizontal, 12)
                      .padding(.vertical, 16)
                    Spacer()
                  }
                  .allowsHitTesting(false)
                }
              },
              alignment: .topLeading
            )
        }
        
        // Advanced options toggle
        Button {
          showAdvanced.toggle()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
              .font(.footnote)
            Text("Advanced Options")
              .font(.callout)
              .fontWeight(.medium)
          }
          .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        
        if showAdvanced {
          VStack(alignment: .leading, spacing: 16) {
            // Duration (for work sessions)
            if selectedType == .workSession {
              VStack(alignment: .leading, spacing: 6) {
                Text("Duration (minutes)")
                  .font(.callout)
                  .foregroundStyle(.secondary)
                TextField("e.g., 120", text: $duration)
                  .textFieldStyle(.roundedBorder)
              }
            }
            
            // Category
            VStack(alignment: .leading, spacing: 6) {
              Text("Category")
                .font(.callout)
                .foregroundStyle(.secondary)
              TextField("e.g., Development, Meetings, Research", text: $category)
                .textFieldStyle(.roundedBorder)
            }
            
            // Due date (for deadlines)
            if selectedType == .deadline {
              VStack(alignment: .leading, spacing: 6) {
                Text("Due Date")
                  .font(.callout)
                  .foregroundStyle(.secondary)
                DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                  .labelsHidden()
              }
              
              VStack(alignment: .leading, spacing: 6) {
                Text("Estimated Minutes")
                  .font(.callout)
                  .foregroundStyle(.secondary)
                TextField("e.g., 180", text: $estimatedMinutes)
                  .textFieldStyle(.roundedBorder)
              }
            }
          }
          .padding(.leading, 12)
        }
        
        // Submit button
        Button {
          submitEntry()
        } label: {
          HStack {
            Image(systemName: "plus.circle.fill")
            Text("Add Entry")
          }
          .font(.callout)
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(Color.accentColor)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        // Recent entries preview
        if !vm.trackerEntries.isEmpty {
          Divider()
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Recent Entries")
              .font(.callout)
              .fontWeight(.semibold)
              .foregroundStyle(.secondary)
            
            ForEach(vm.trackerEntries.prefix(3)) { entry in
              RecentEntryRow(entry: entry)
            }
          }
        }
      }
      .padding(20)
    }
  }
  
  private var placeholderText: String {
    switch selectedType {
    case .workSession:
      return "e.g., \"Worked on feature X for 2 hours\" or \"Meeting with team - 1h\""
    case .deadline:
      return "e.g., \"Project proposal due next Friday\" or \"Submit report by EOD\""
    case .note:
      return "e.g., \"Remember to review PRs\" or \"Follow up with client about requirements\""
    }
  }
  
  private func submitEntry() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    let durationInt = Int(duration.trimmingCharacters(in: .whitespacesAndNewlines))
    let estimatedInt = Int(estimatedMinutes.trimmingCharacters(in: .whitespacesAndNewlines))
    let cat = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category
    
    vm.addWorkTrackerEntry(
      type: selectedType,
      rawText: text,
      duration: durationInt,
      category: cat,
      dueDate: selectedType == .deadline ? dueDate : nil,
      estimatedMinutes: selectedType == .deadline ? estimatedInt : nil
    )
    
    // Clear form
    inputText = ""
    duration = ""
    category = ""
    estimatedMinutes = ""
    showAdvanced = false
  }
}

// MARK: - Recent Entry Row

private struct RecentEntryRow: View {
  let entry: TrackerEntry
  
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: entry.type.icon)
        .font(.footnote)
        .foregroundStyle(entryColor)
        .frame(width: 20)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.rawText)
          .font(.callout)
          .lineLimit(2)
        
        HStack(spacing: 8) {
          if let category = entry.category {
            Text(category)
              .font(.system(size: 11))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.blue.opacity(0.12))
              .foregroundStyle(.blue)
              .clipShape(Capsule())
          }
          
          if let duration = entry.duration {
            Text("\(duration)m")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
          
          Spacer()
          
          Text(relativeTime(entry.createdAt))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
    }
    .padding(10)
    .background(Theme.subtle)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
  
  private var entryColor: Color {
    switch entry.type {
    case .workSession: return .blue
    case .deadline: return .orange
    case .note: return .purple
    }
  }
}

// MARK: - History View

private struct HistoryView: View {
  @ObservedObject var vm: AppViewModel
  @State private var filterType: TrackerEntryType? = nil
  
  private var filteredEntries: [TrackerEntry] {
    if let filterType {
      return vm.trackerEntries.filter { $0.type == filterType }
    }
    return vm.trackerEntries
  }
  
  private var groupedByDay: [(Date, [TrackerEntry])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: filteredEntries) { entry in
      calendar.startOfDay(for: entry.createdAt)
    }
    return grouped.sorted { $0.key > $1.key }
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Filter bar
      HStack(spacing: 8) {
        Text("Filter:")
          .font(.callout)
          .foregroundStyle(.secondary)
        
        Button {
          filterType = nil
        } label: {
          Text("All")
            .font(.footnote)
            .fontWeight(filterType == nil ? .semibold : .regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(filterType == nil ? Color.accentColor.opacity(0.15) : Theme.subtle)
            .foregroundStyle(filterType == nil ? .primary : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        
        ForEach(TrackerEntryType.allCases, id: \.self) { type in
          Button {
            filterType = (filterType == type) ? nil : type
          } label: {
            HStack(spacing: 4) {
              Image(systemName: type.icon)
                .font(.system(size: 10))
              Text(type.displayName)
            }
            .font(.footnote)
            .fontWeight(filterType == type ? .semibold : .regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(filterType == type ? Color.accentColor.opacity(0.15) : Theme.subtle)
            .foregroundStyle(filterType == type ? .primary : .secondary)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
        
        Spacer()
        
        Text("\(filteredEntries.count) entries")
          .font(.footnote)
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      
      Divider()
      
      // Entries grouped by day
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 20) {
          if groupedByDay.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: "clock.badge.xmark")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
              Text("No entries yet")
                .font(.title3)
                .foregroundStyle(.secondary)
              Text("Start tracking your work in the Quick Entry tab")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
          } else {
            ForEach(groupedByDay, id: \.0) { day, entries in
              VStack(alignment: .leading, spacing: 12) {
                // Day header
                Text(dayLabel(day))
                  .font(.callout)
                  .fontWeight(.bold)
                  .foregroundStyle(.secondary)
                
                // Entries for this day
                ForEach(entries) { entry in
                  HistoryEntryRow(entry: entry, vm: vm)
                }
              }
            }
          }
        }
        .padding(20)
      }
    }
  }
  
  private func dayLabel(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "Today"
    } else if calendar.isDateInYesterday(date) {
      return "Yesterday"
    } else {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      return formatter.string(from: date)
    }
  }
}

// MARK: - History Entry Row

private struct HistoryEntryRow: View {
  let entry: TrackerEntry
  @ObservedObject var vm: AppViewModel
  @State private var showDeleteConfirm: Bool = false
  
  var body: some View {
    HStack(spacing: 12) {
      // Time
      VStack(spacing: 2) {
        Text(timeString(entry.createdAt))
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundStyle(.secondary)
      }
      .frame(width: 50, alignment: .trailing)
      
      // Type icon
      Image(systemName: entry.type.icon)
        .font(.body)
        .foregroundStyle(entryColor)
        .frame(width: 24)
      
      // Content
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.rawText)
          .font(.callout)
        
        HStack(spacing: 8) {
          if let category = entry.category {
            HStack(spacing: 4) {
              Image(systemName: "folder.fill")
                .font(.system(size: 9))
              Text(category)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.12))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
          }
          
          if let duration = entry.duration {
            HStack(spacing: 3) {
              Image(systemName: "clock.fill")
                .font(.system(size: 9))
              Text("\(duration)m")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          }
          
          if let dueDate = entry.dueDate {
            HStack(spacing: 3) {
              Image(systemName: "calendar")
                .font(.system(size: 9))
              Text("Due: \(dueDateString(dueDate))")
            }
            .font(.system(size: 11))
            .foregroundStyle(isPastDue(dueDate) ? .red : .orange)
          }
        }
      }
      
      Spacer()
      
      // Delete button
      Button {
        showDeleteConfirm = true
      } label: {
        Image(systemName: "trash")
          .font(.footnote)
          .foregroundStyle(.red)
      }
      .buttonStyle(.plain)
      .help("Delete entry")
      .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm) {
        Button("Delete", role: .destructive) {
          vm.deleteWorkTrackerEntry(id: entry.id)
        }
        Button("Cancel", role: .cancel) {}
      }
    }
    .padding(12)
    .background(Theme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
  
  private var entryColor: Color {
    switch entry.type {
    case .workSession: return .blue
    case .deadline: return .orange
    case .note: return .purple
    }
  }
  
  private func timeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
  
  private func dueDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
  
  private func isPastDue(_ date: Date) -> Bool {
    return date < Date()
  }
}

// MARK: - Summary View

private struct SummaryView: View {
  @ObservedObject var vm: AppViewModel
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if let summary = vm.trackerSummary {
          // Stats overview
          LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
          ], spacing: 16) {
            StatCard(
              title: "Total Entries",
              value: "\(summary.totalEntries)",
              icon: "list.bullet",
              color: .blue
            )
            
            StatCard(
              title: "Work Sessions",
              value: "\(summary.workSessionsCount)",
              icon: "clock.fill",
              color: .green
            )
            
            StatCard(
              title: "Total Hours",
              value: String(format: "%.1f", Double(summary.totalMinutesLogged) / 60.0),
              icon: "timer",
              color: .purple
            )
            
            StatCard(
              title: "Deadlines",
              value: "\(summary.deadlinesCount)",
              icon: "calendar.badge.exclamationmark",
              color: .orange
            )
            
            StatCard(
              title: "Upcoming",
              value: "\(summary.upcomingDeadlines)",
              icon: "calendar.badge.clock",
              color: .red
            )
            
            StatCard(
              title: "Notes",
              value: "\(summary.notesCount)",
              icon: "note.text",
              color: .cyan
            )
          }
          
          // Last 7 days
          VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
              .font(.title3)
              .fontWeight(.bold)
            
            HStack(spacing: 16) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Hours Logged")
                  .font(.callout)
                  .foregroundStyle(.secondary)
                Text(String(format: "%.1f", Double(summary.last7DaysMinutes) / 60.0))
                  .font(.system(size: 32, weight: .bold, design: .rounded))
                  .foregroundStyle(.blue)
              }
              
              Spacer()
              
              VStack(alignment: .trailing, spacing: 4) {
                Text("Daily Average")
                  .font(.callout)
                  .foregroundStyle(.secondary)
                Text(String(format: "%.1f", Double(summary.last7DaysMinutes) / 60.0 / 7.0))
                  .font(.system(size: 24, weight: .semibold, design: .rounded))
                  .foregroundStyle(.green)
              }
            }
            .padding(16)
            .background(Theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          
          // Categories breakdown
          if !summary.categories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              Text("Hours by Category")
                .font(.title3)
                .fontWeight(.bold)
              
              ForEach(summary.categories.sorted(by: { $0.value > $1.value }), id: \.key) { category, count in
                HStack(spacing: 12) {
                  Text(category)
                    .font(.callout)
                    .fontWeight(.medium)
                  
                  Spacer()
                  
                  Text("\(count) entries")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
            }
          }
          
          // Upcoming deadlines
          if !vm.upcomingDeadlines.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              Text("Upcoming Deadlines")
                .font(.title3)
                .fontWeight(.bold)
              
              ForEach(vm.upcomingDeadlines) { deadline in
                DeadlineCard(deadline: deadline)
              }
            }
          }
        } else {
          // Loading state
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.5)
            Text("Loading summary...")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 60)
        }
      }
      .padding(20)
    }
  }
}

// MARK: - Stat Card

private struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(color)
        Spacer()
      }
      
      Text(value)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
      
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - Deadline Card

private struct DeadlineCard: View {
  let deadline: DeadlineEntry
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "calendar.badge.exclamationmark")
        .font(.title3)
        .foregroundStyle(isPastDue ? .red : .orange)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(deadline.rawText)
          .font(.callout)
          .fontWeight(.medium)
        
        HStack(spacing: 8) {
          Text(dueDateString)
            .font(.footnote)
            .foregroundStyle(isPastDue ? .red : .secondary)
          
          if let est = deadline.estimatedMinutes {
            Text("Est: \(est)m")
              .font(.footnote)
              .foregroundStyle(.tertiary)
          }
          
          if let cat = deadline.category {
            Text(cat)
              .font(.system(size: 10))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.blue.opacity(0.12))
              .foregroundStyle(.blue)
              .clipShape(Capsule())
          }
        }
      }
      
      Spacer()
      
      Text(relativeTimeUntil(deadline.dueDate))
        .font(.footnote)
        .fontWeight(.semibold)
        .foregroundStyle(isPastDue ? .red : .orange)
    }
    .padding(12)
    .background(Theme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(isPastDue ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
    )
  }
  
  private var isPastDue: Bool {
    deadline.dueDate < Date()
  }
  
  private var dueDateString: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: deadline.dueDate)
  }
}

// MARK: - Helpers

private func relativeTime(_ date: Date) -> String {
  let seconds = Date().timeIntervalSince(date)
  if seconds < 0 { return "just now" }
  if seconds < 60 { return "just now" }
  let minutes = Int(seconds / 60)
  if minutes < 60 { return "\(minutes)m ago" }
  let hours = Int(seconds / 3600)
  if hours < 24 { return "\(hours)h ago" }
  let days = Int(seconds / 86400)
  return "\(days)d ago"
}

private func relativeTimeUntil(_ date: Date) -> String {
  let seconds = date.timeIntervalSince(Date())
  if seconds < 0 {
    let pastSeconds = abs(seconds)
    if pastSeconds < 3600 { return "Overdue!" }
    let hours = Int(pastSeconds / 3600)
    if hours < 24 { return "\(hours)h overdue" }
    let days = Int(pastSeconds / 86400)
    return "\(days)d overdue"
  }
  
  if seconds < 3600 {
    let minutes = Int(seconds / 60)
    return "in \(minutes)m"
  }
  let hours = Int(seconds / 3600)
  if hours < 24 { return "in \(hours)h" }
  let days = Int(seconds / 86400)
  return "in \(days)d"
}

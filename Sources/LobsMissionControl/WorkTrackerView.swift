import SwiftUI

// MARK: - Work Tracker View

struct WorkTrackerView: View {
  @ObservedObject var vm: AppViewModel
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // Header
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
          
          Spacer()
          
          // Refresh button
          Button {
            vm.loadWorkTracker()
          } label: {
            Image(systemName: "arrow.clockwise")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .help("Refresh")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        
        // 1. AI ANALYSIS
        AIAnalysisSection(vm: vm)
        
        // 2. RECOMMENDATIONS & WHAT TO DO NEXT
        RecommendationsSection(vm: vm)
        
        // 3. QUICK ENTRY TEXT BOX
        QuickEntrySection(vm: vm)
        
        // 4. STATS CARDS
        StatsSection(vm: vm)
        
        // 5. RECENT ENTRIES / HISTORY
        RecentHistorySection(vm: vm)
      }
      .padding(.bottom, 20)
    }
    .background(Theme.bg)
    .onAppear {
      vm.loadWorkTracker()
    }
  }
}

// MARK: - 1. AI Analysis Section

private struct AIAnalysisSection: View {
  @ObservedObject var vm: AppViewModel
  
  var body: some View {
    if let analysis = vm.trackerAnalysis {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "brain.head.profile")
            .font(.callout)
            .foregroundStyle(.linearGradient(
              colors: [.purple, .pink],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
          Text("AI Analysis")
            .font(.headline)
            .foregroundStyle(.secondary)
          
          Spacer()
          
          // Timestamp
          if analysis.updatedAt.timeIntervalSinceNow > -3600 {
            Text(relativeTime(analysis.updatedAt))
              .font(.caption)
              .foregroundStyle(.tertiary)
          } else {
            Text(absoluteTime(analysis.updatedAt))
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.horizontal, 20)
        
        // Analysis content card
        VStack(alignment: .leading, spacing: 10) {
          // Markdown-style text rendering
          Text(analysis.rawText)
            .font(.system(size: 13, design: .default))
            .foregroundStyle(.primary)
            .lineSpacing(4)
            .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          LinearGradient(
            colors: [
              Color.purple.opacity(0.05),
              Color.pink.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              LinearGradient(
                colors: [
                  Color.purple.opacity(0.2),
                  Color.pink.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
      }
    } else {
      // No analysis yet - subtle placeholder
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: "brain.head.profile")
            .font(.callout)
            .foregroundStyle(.tertiary)
          Text("AI Analysis")
            .font(.headline)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.horizontal, 20)
        
        HStack(spacing: 8) {
          Image(systemName: "sparkles")
            .font(.footnote)
            .foregroundStyle(.quaternary)
          Text("No analysis available yet")
            .font(.footnote)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
      }
    }
  }
  
  private func relativeTime(_ date: Date) -> String {
    let seconds = abs(date.timeIntervalSinceNow)
    if seconds < 60 {
      return "just now"
    } else if seconds < 3600 {
      let minutes = Int(seconds / 60)
      return "\(minutes)m ago"
    } else {
      let hours = Int(seconds / 3600)
      return "\(hours)h ago"
    }
  }
  
  private func absoluteTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

// MARK: - 2. Recommendations Section

private struct RecommendationsSection: View {
  @ObservedObject var vm: AppViewModel
  
  private var hasUpcomingDeadlines: Bool {
    !vm.upcomingDeadlines.isEmpty
  }
  
  private var urgentDeadlines: [DeadlineEntry] {
    vm.upcomingDeadlines.filter { deadline in
      let hoursUntil = deadline.dueDate.timeIntervalSince(Date()) / 3600
      return hoursUntil <= 48 && hoursUntil > 0 // Next 48 hours
    }
  }
  
  private var todayDeadlines: [DeadlineEntry] {
    let calendar = Calendar.current
    return vm.upcomingDeadlines.filter { deadline in
      calendar.isDateInToday(deadline.dueDate)
    }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("What should I do?")
        .font(.headline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
      
      if hasUpcomingDeadlines {
        VStack(alignment: .leading, spacing: 10) {
          // Today's deadlines (highest priority)
          if !todayDeadlines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Due Today")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .padding(.horizontal, 20)
              
              ForEach(todayDeadlines) { deadline in
                UrgentDeadlineCard(deadline: deadline, isTodayDeadline: true)
                  .padding(.horizontal, 20)
              }
            }
          }
          
          // Urgent deadlines (next 48 hours)
          if !urgentDeadlines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text(todayDeadlines.isEmpty ? "Coming Up" : "Also Coming Up")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .padding(.horizontal, 20)
              
              ForEach(urgentDeadlines) { deadline in
                UrgentDeadlineCard(deadline: deadline, isTodayDeadline: false)
                  .padding(.horizontal, 20)
              }
            }
          }
          
          // All other upcoming deadlines (collapsed view)
          let otherDeadlines = vm.upcomingDeadlines.filter { deadline in
            !todayDeadlines.contains(where: { $0.id == deadline.id }) &&
            !urgentDeadlines.contains(where: { $0.id == deadline.id })
          }
          
          if !otherDeadlines.isEmpty {
            Button {
              // Could expand to show all
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "calendar")
                  .font(.footnote)
                Text("\(otherDeadlines.count) more upcoming")
                  .font(.footnote)
                  .fontWeight(.medium)
              }
              .foregroundStyle(.blue)
              .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
          }
        }
      } else {
        // No deadlines - show encouragement
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .font(.title3)
              .foregroundStyle(.green)
            Text("No urgent deadlines")
              .font(.callout)
              .fontWeight(.medium)
          }
          .padding(.horizontal, 20)
          
          Text("Great! Consider logging your current work or planning ahead.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
      }
    }
  }
}

private struct UrgentDeadlineCard: View {
  let deadline: DeadlineEntry
  let isTodayDeadline: Bool
  
  var body: some View {
    HStack(spacing: 12) {
      // Priority indicator
      Circle()
        .fill(isTodayDeadline ? Color.red : Color.orange)
        .frame(width: 8, height: 8)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(deadline.rawText)
          .font(.callout)
          .fontWeight(.medium)
        
        HStack(spacing: 8) {
          Text(dueDateString)
            .font(.footnote)
            .foregroundStyle(.secondary)
          
          if let est = deadline.estimatedMinutes {
            HStack(spacing: 3) {
              Image(systemName: "clock")
                .font(.system(size: 9))
              Text("\(est)m")
            }
            .font(.system(size: 11))
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
        .foregroundStyle(isTodayDeadline ? .red : .orange)
    }
    .padding(12)
    .background(Theme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isTodayDeadline ? Color.red.opacity(0.3) : Color.orange.opacity(0.2), lineWidth: 2)
    )
  }
  
  private var dueDateString: String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: deadline.dueDate)
  }
}

// MARK: - 3. Quick Entry Section

private struct QuickEntrySection: View {
  @ObservedObject var vm: AppViewModel
  @State private var inputText: String = ""
  @FocusState private var isInputFocused: Bool
  
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Quick Entry")
        .font(.headline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
      
      VStack(alignment: .leading, spacing: 8) {
        // Single text box - system infers type
        TextEditor(text: $inputText)
          .font(.system(size: 14))
          .frame(height: 80)
          .padding(10)
          .background(Color(NSColor.textBackgroundColor))
          .cornerRadius(10)
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(isInputFocused ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: isInputFocused ? 2 : 1)
          )
          .overlay(
            Group {
              if inputText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Type anything - system will figure it out:")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                  Text("  • \"Worked 2h on feature X\"")
                    .font(.system(size: 12))
                    .foregroundStyle(.quaternary)
                  Text("  • \"Report due Friday 3pm\"")
                    .font(.system(size: 12))
                    .foregroundStyle(.quaternary)
                  Text("  • \"Remember to review PRs\"")
                    .font(.system(size: 12))
                    .foregroundStyle(.quaternary)
                  Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .allowsHitTesting(false)
              }
            },
            alignment: .topLeading
          )
          .focused($isInputFocused)
        
        // Submit button
        HStack {
          Spacer()
          
          Button {
            submitEntry()
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "plus.circle.fill")
                .font(.footnote)
              Text("Add Entry")
                .fontWeight(.semibold)
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.2) : Color.accentColor)
            .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
          .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .keyboardShortcut(.return, modifiers: [.command])
        }
      }
      .padding(.horizontal, 20)
      
      // Hint about keyboard shortcut
      Text("⌘↵ to submit")
        .font(.system(size: 11))
        .foregroundStyle(.quaternary)
        .padding(.horizontal, 20)
    }
  }
  
  private func submitEntry() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    // System infers type - for now, we'll use .note as default
    // In the future, backend could parse and determine type
    vm.addWorkTrackerEntry(
      type: .note,  // System will infer
      rawText: text,
      duration: nil,
      category: nil,
      dueDate: nil,
      estimatedMinutes: nil
    )
    
    // Clear form
    inputText = ""
    isInputFocused = false
  }
}

// MARK: - 4. Stats Section

private struct StatsSection: View {
  @ObservedObject var vm: AppViewModel
  
  private var thisWeekHours: Double {
    guard let summary = vm.trackerSummary else { return 0 }
    return Double(summary.last7DaysMinutes) / 60.0
  }
  
  private var dailyAverage: Double {
    thisWeekHours / 7.0
  }
  
  private var categoriesCount: Int {
    vm.trackerSummary?.categories.count ?? 0
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("This Week")
        .font(.headline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
      
      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 12) {
        // Hours this week
        CompactStatCard(
          title: "Hours Logged",
          value: String(format: "%.1f", thisWeekHours),
          subtitle: "this week",
          icon: "clock.fill",
          color: .blue
        )
        
        // Daily average
        CompactStatCard(
          title: "Daily Avg",
          value: String(format: "%.1f", dailyAverage),
          subtitle: "hours/day",
          icon: "chart.line.uptrend.xyaxis",
          color: .green
        )
        
        // Categories
        CompactStatCard(
          title: "Categories",
          value: "\(categoriesCount)",
          subtitle: "tracked",
          icon: "folder.fill",
          color: .purple
        )
      }
      .padding(.horizontal, 20)
      
      // Top categories (if any)
      if let summary = vm.trackerSummary, !summary.categories.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Top Categories")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
          
          let topCategories = summary.categories.sorted(by: { $0.value > $1.value }).prefix(3)
          HStack(spacing: 8) {
            ForEach(Array(topCategories), id: \.key) { category, count in
              HStack(spacing: 6) {
                Circle()
                  .fill(Color.blue)
                  .frame(width: 6, height: 6)
                Text(category)
                  .font(.footnote)
                  .fontWeight(.medium)
                Text("×\(count)")
                  .font(.system(size: 11))
                  .foregroundStyle(.secondary)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Color.blue.opacity(0.08))
              .clipShape(Capsule())
            }
            Spacer()
          }
          .padding(.horizontal, 20)
        }
      }
    }
  }
}

private struct CompactStatCard: View {
  let title: String
  let value: String
  let subtitle: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(color)
      
      Text(value)
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
      
      VStack(spacing: 2) {
        Text(title)
          .font(.caption)
          .fontWeight(.medium)
        Text(subtitle)
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(Theme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

// MARK: - 5. Recent History Section

private struct RecentHistorySection: View {
  @ObservedObject var vm: AppViewModel
  @State private var showingAll: Bool = false
  
  private var recentEntries: [TrackerEntry] {
    let sorted = vm.trackerEntries.sorted { $0.createdAt > $1.createdAt }
    return showingAll ? Array(sorted.prefix(50)) : Array(sorted.prefix(10))
  }
  
  private var hasMore: Bool {
    vm.trackerEntries.count > 10
  }
  
  private var groupedByDay: [(Date, [TrackerEntry])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: recentEntries) { entry in
      calendar.startOfDay(for: entry.createdAt)
    }
    return grouped.sorted { $0.key > $1.key }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent Entries")
          .font(.headline)
          .foregroundStyle(.secondary)
        
        Spacer()
        
        if hasMore {
          Button {
            showingAll.toggle()
          } label: {
            Text(showingAll ? "Show Less" : "Show All")
              .font(.footnote)
              .fontWeight(.medium)
              .foregroundStyle(.blue)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
      
      if recentEntries.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "clock.badge.xmark")
            .font(.system(size: 36))
            .foregroundStyle(.tertiary)
          Text("No entries yet")
            .font(.callout)
            .foregroundStyle(.secondary)
          Text("Start tracking your work above")
            .font(.footnote)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
      } else {
        LazyVStack(alignment: .leading, spacing: 16) {
          ForEach(groupedByDay, id: \.0) { day, entries in
            VStack(alignment: .leading, spacing: 10) {
              // Day header
              Text(dayLabel(day))
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
              
              // Entries for this day
              ForEach(entries) { entry in
                CompactEntryRow(entry: entry, vm: vm)
                  .padding(.horizontal, 20)
              }
            }
          }
        }
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
      formatter.dateFormat = "EEEE, MMM d"
      return formatter.string(from: date)
    }
  }
}

private struct CompactEntryRow: View {
  let entry: TrackerEntry
  @ObservedObject var vm: AppViewModel
  @State private var showDeleteConfirm: Bool = false
  
  var body: some View {
    HStack(spacing: 10) {
      // Time + icon
      VStack(alignment: .trailing, spacing: 2) {
        Text(timeString(entry.createdAt))
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundStyle(.secondary)
        
        Image(systemName: entry.type.icon)
          .font(.system(size: 11))
          .foregroundStyle(entryColor.opacity(0.6))
      }
      .frame(width: 48, alignment: .trailing)
      
      // Content
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.rawText)
          .font(.callout)
          .lineLimit(2)
        
        if entry.category != nil || entry.duration != nil {
          HStack(spacing: 6) {
            if let category = entry.category {
              HStack(spacing: 3) {
                Image(systemName: "folder.fill")
                  .font(.system(size: 8))
                Text(category)
              }
              .font(.system(size: 10))
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(Color.blue.opacity(0.1))
              .foregroundStyle(.blue)
              .clipShape(Capsule())
            }
            
            if let duration = entry.duration {
              HStack(spacing: 2) {
                Image(systemName: "clock")
                  .font(.system(size: 8))
                Text("\(duration)m")
              }
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
            }
          }
        }
      }
      
      Spacer()
      
      // Delete button (appears on hover)
      Button {
        showDeleteConfirm = true
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .opacity(0.6)
      .help("Delete entry")
      .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm) {
        Button("Delete", role: .destructive) {
          vm.deleteWorkTrackerEntry(id: entry.id)
        }
        Button("Cancel", role: .cancel) {}
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Theme.subtle.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
  
  private var entryColor: Color {
    switch entry.type {
    case .workSession: return .blue
    case .deadline: return .orange
    case .note: return .purple
    case .analysis: return .mint
    }
  }
  
  private func timeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

// MARK: - Helpers

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
    if minutes < 5 { return "Very soon!" }
    return "in \(minutes)m"
  }
  let hours = Int(seconds / 3600)
  if hours < 24 { return "in \(hours)h" }
  let days = Int(seconds / 86400)
  if days == 1 { return "tomorrow" }
  return "in \(days)d"
}

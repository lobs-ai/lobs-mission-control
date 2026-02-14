import SwiftUI
import Charts

// MARK: - Detailed Statistics View

/// Shows comprehensive task analytics across projects with weekly breakdown.
/// Adapted from the old dashboard OverviewView DetailedStatsView.
struct DetailedStatsView: View {
  let tasks: [DashboardTask]
  let projects: [Project]
  
  @State private var weekOffset: Int = 0
  @Environment(\.dismiss) private var dismiss
  
  private let calendar = Calendar.current
  
  // MARK: - Week Navigation
  
  /// Start of the selected week (Monday).
  private var weekStart: Date {
    let now = Date()
    let shifted = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now) ?? now
    var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: shifted)
    comps.weekday = 2 // Monday
    return calendar.date(from: comps) ?? shifted
  }
  
  /// End of the selected week (Sunday 23:59:59).
  private var weekEnd: Date {
    calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
  }
  
  /// Human-readable week label.
  private var weekLabel: String {
    if weekOffset == 0 { return "This Week" }
    if weekOffset == -1 { return "Last Week" }
    let df = DateFormatter()
    df.dateFormat = "MMM d"
    let start = df.string(from: weekStart)
    let end = df.string(from: calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart)
    return "\(start) – \(end)"
  }
  
  private var isCurrentWeek: Bool { weekOffset == 0 }
  
  // MARK: - Weekly Data
  
  /// Tasks completed during the selected week.
  private var completedThisWeek: [DashboardTask] {
    tasks.filter { task in
      guard task.status == .completed else { return false }
      let completionDate = task.finishedAt ?? task.updatedAt
      return completionDate >= weekStart && completionDate < weekEnd
    }
  }
  
  /// Tasks created during the selected week.
  private var createdThisWeek: [DashboardTask] {
    tasks.filter { $0.createdAt >= weekStart && $0.createdAt < weekEnd }
  }
  
  /// Tasks updated during the selected week.
  private var updatedThisWeek: [DashboardTask] {
    tasks.filter { $0.updatedAt >= weekStart && $0.updatedAt < weekEnd }
  }
  
  // MARK: - All-Time Data
  
  // Status breakdown (all-time for context)
  private var statusBreakdown: [(String, Int, Color)] {
    let active = tasks.filter { $0.status == .active || $0.status == .waitingOn }.count
    let completed = tasks.filter { $0.status == .completed }.count
    let inbox = tasks.filter { $0.status == .inbox }.count
    let rejected = tasks.filter { $0.status == .rejected }.count
    return [
      ("Active", active, Color.orange),
      ("Completed", completed, Color.green),
      ("Inbox", inbox, Color.blue),
      ("Rejected", rejected, Color.red),
    ].filter { $0.1 > 0 }
  }
  
  // Tasks per project
  private var tasksPerProject: [(String, Int, Int, Int)] {
    projects.map { project in
      let projectTasks = tasks.filter { ($0.projectId ?? "default") == project.id }
      let active = projectTasks.filter { $0.status == .active }.count
      let completed = projectTasks.filter { $0.status == .completed }.count
      return (project.title, projectTasks.count, active, completed)
    }
    .sorted { $0.1 > $1.1 }
  }
  
  // Weekly per-project completions
  private var weeklyCompletionsByProject: [(String, Int)] {
    var counts: [String: Int] = [:]
    for task in completedThisWeek {
      let projectId = task.projectId ?? "default"
      let name = projects.first(where: { $0.id == projectId })?.title ?? "No Project"
      counts[name, default: 0] += 1
    }
    return counts.sorted { $0.value > $1.value }
  }
  
  // Completion rate (all-time)
  private var completionRate: Double {
    let completable = tasks.filter { $0.status == .completed || $0.status == .active || $0.status == .waitingOn }
    guard !completable.isEmpty else { return 0 }
    let completed = completable.filter { $0.status == .completed }.count
    return Double(completed) / Double(completable.count)
  }
  
  // Average time to complete (days) — for tasks completed this week
  private var avgCompletionDaysThisWeek: Double? {
    let completed = completedThisWeek
    guard !completed.isEmpty else { return nil }
    let totalDays = completed.reduce(0.0) { sum, task in
      let started = task.startedAt ?? task.createdAt
      return sum + task.updatedAt.timeIntervalSince(started) / 86400
    }
    return totalDays / Double(completed.count)
  }
  
  // Owner breakdown (active tasks)
  private var ownerBreakdown: [(String, Int)] {
    var counts: [String: Int] = [:]
    for task in tasks where task.status == .active {
      counts[task.resolvedOwner.rawValue, default: 0] += 1
    }
    return counts.sorted { $0.value > $1.value }
  }
  
  // MARK: - Body
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Detailed Statistics")
            .font(.title.bold())
          Text("Task analytics across all projects")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()
      .background(Color(NSColor.windowBackgroundColor))
      
      Divider()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // Week navigation
          weekNavigationHeader
          
          // Weekly summary metrics
          weeklyMetrics
          
          // Three-column layout
          HStack(alignment: .top, spacing: 16) {
            // Column 1: Weekly completions
            weeklyCompletionsColumn
            
            // Column 2: Status & project breakdown
            statusAndProjectsColumn
            
            // Column 3: Owner breakdown & created tasks
            ownerAndCreatedColumn
          }
        }
        .padding()
      }
      .background(Color(NSColor.controlBackgroundColor))
    }
  }
  
  // MARK: - Subviews
  
  private var weekNavigationHeader: some View {
    HStack(spacing: 12) {
      Image(systemName: "chart.bar.xaxis")
        .font(.title3)
        .foregroundStyle(Color.purple)
      
      Text("Weekly View")
        .font(.headline)
      
      Spacer()
      
      // Week navigation controls
      HStack(spacing: 8) {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) { weekOffset -= 1 }
        } label: {
          Image(systemName: "chevron.left")
            .font(.footnote.weight(.semibold))
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        
        Text(weekLabel)
          .font(.callout)
          .fontWeight(.semibold)
          .frame(minWidth: 140)
          .animation(.none, value: weekOffset)
        
        Button {
          withAnimation(.easeInOut(duration: 0.2)) { weekOffset += 1 }
        } label: {
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .padding(8)
            .background(isCurrentWeek ? Color(NSColor.controlBackgroundColor).opacity(0.3) : Color(NSColor.controlBackgroundColor))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isCurrentWeek)
        
        if weekOffset != 0 {
          Button {
            withAnimation(.easeInOut(duration: 0.2)) { weekOffset = 0 }
          } label: {
            Text("Today")
              .font(.footnote.weight(.medium))
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color.accentColor.opacity(0.15))
              .foregroundStyle(Color.accentColor)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
  
  private var weeklyMetrics: some View {
    HStack(spacing: 16) {
      MetricCard(
        title: "Completed",
        value: "\(completedThisWeek.count)",
        icon: "checkmark.circle.fill",
        color: Color.green
      )
      MetricCard(
        title: "Created",
        value: "\(createdThisWeek.count)",
        icon: "plus.circle.fill",
        color: Color.blue
      )
      MetricCard(
        title: "Updated",
        value: "\(updatedThisWeek.count)",
        icon: "arrow.triangle.2.circlepath",
        color: Color.orange
      )
      if let avgDays = avgCompletionDaysThisWeek {
        MetricCard(
          title: "Avg Completion",
          value: avgDays < 1 ? String(format: "%.0fh", avgDays * 24) : String(format: "%.1fd", avgDays),
          icon: "clock",
          color: Color.orange
        )
      }
      MetricCard(
        title: "Completion Rate",
        value: String(format: "%.0f%%", completionRate * 100),
        icon: "percent",
        color: Color.green
      )
    }
  }
  
  private var weeklyCompletionsColumn: some View {
    StatsCard {
      VStack(alignment: .leading, spacing: 12) {
        Text("Completed This Week")
          .font(.callout)
          .fontWeight(.semibold)
        
        if weeklyCompletionsByProject.isEmpty {
          Text("No completions this week")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
        } else {
          // Per-project summary
          ForEach(weeklyCompletionsByProject, id: \.0) { name, count in
            HStack(spacing: 8) {
              RoundedRectangle(cornerRadius: 3)
                .fill(Color.green)
                .frame(width: 4, height: 16)
              Text(name)
                .font(.callout)
                .lineLimit(1)
              Spacer()
              Text("\(count)")
                .font(.callout)
                .fontWeight(.medium)
                .monospacedDigit()
            }
          }
          
          Divider()
          
          // Individual completed tasks
          ForEach(completedThisWeek.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(10), id: \.id) { task in
            HStack(spacing: 6) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.green)
              Text(task.title)
                .font(.footnote)
                .lineLimit(1)
              Spacer()
              if let started = task.startedAt {
                let dur = task.updatedAt.timeIntervalSince(started)
                Text(formatDuration(dur))
                  .font(.system(size: 11))
                  .foregroundStyle(.tertiary)
              }
            }
          }
        }
      }
    }
  }
  
  private var statusAndProjectsColumn: some View {
    StatsCard {
      VStack(alignment: .leading, spacing: 12) {
        Text("Tasks by Status")
          .font(.callout)
          .fontWeight(.semibold)
        
        ForEach(statusBreakdown, id: \.0) { label, count, color in
          HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
              .fill(color)
              .frame(width: 4, height: 16)
            Text(label)
              .font(.callout)
              .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
              RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.3))
                .frame(width: tasks.isEmpty ? 0 : geo.size.width * CGFloat(count) / CGFloat(tasks.count))
            }
            .frame(height: 16)
            Text("\(count)")
              .font(.callout)
              .fontWeight(.medium)
              .monospacedDigit()
              .frame(width: 30, alignment: .trailing)
          }
        }
        
        Divider()
        
        // Tasks per project
        Text("Tasks per Project")
          .font(.callout)
          .fontWeight(.semibold)
        
        ForEach(tasksPerProject, id: \.0) { name, total, active, completed in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(name)
                .font(.callout)
                .lineLimit(1)
              Spacer()
              Text("\(total)")
                .font(.callout)
                .fontWeight(.medium)
                .monospacedDigit()
            }
            HStack(spacing: 4) {
              if completed > 0 {
                Text("\(completed) done")
                  .font(.system(size: 11))
                  .foregroundStyle(Color.green)
              }
              if active > 0 {
                Text("\(active) active")
                  .font(.system(size: 11))
                  .foregroundStyle(Color.orange)
              }
            }
          }
          Divider()
        }
      }
    }
  }
  
  private var ownerAndCreatedColumn: some View {
    StatsCard {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Active by Owner")
            .font(.callout)
            .fontWeight(.semibold)
          
          if ownerBreakdown.isEmpty {
            Text("No active tasks")
              .font(.footnote)
              .foregroundStyle(.secondary)
          } else {
            ForEach(ownerBreakdown, id: \.0) { owner, count in
              HStack {
                Text(owner.capitalized)
                  .font(.callout)
                Spacer()
                Text("\(count)")
                  .font(.callout)
                  .fontWeight(.medium)
                  .monospacedDigit()
              }
            }
          }
        }
        
        Divider()
        
        // Created this week list
        VStack(alignment: .leading, spacing: 8) {
          Text("Created This Week")
            .font(.callout)
            .fontWeight(.semibold)
          
          if createdThisWeek.isEmpty {
            Text("No tasks created this week")
              .font(.footnote)
              .foregroundStyle(.secondary)
          } else {
            ForEach(createdThisWeek.sorted(by: { $0.createdAt > $1.createdAt }).prefix(8), id: \.id) { task in
              HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                  .font(.system(size: 10))
                  .foregroundStyle(Color.blue)
                Text(task.title)
                  .font(.footnote)
                  .lineLimit(1)
                Spacer()
                Text(task.status.rawValue)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
    }
  }
  
  // MARK: - Helpers
  
  private func formatDuration(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(seconds / 60)
    if totalMinutes < 60 { return "\(totalMinutes)m" }
    let hours = totalMinutes / 60
    let mins = totalMinutes % 60
    if hours < 24 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
    let days = hours / 24
    return "\(days)d"
  }
}

// MARK: - Metric Card

private struct MetricCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(color)
        Text(value)
          .font(.title2.bold())
          .foregroundStyle(color)
      }
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(Color(NSColor.windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(color.opacity(0.2), lineWidth: 1)
    )
  }
}

// MARK: - Stats Card

private struct StatsCard<Content: View>: View {
  let content: Content
  
  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }
  
  var body: some View {
    content
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(Color(NSColor.windowBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.primary.opacity(0.08), lineWidth: 1)
      )
  }
}

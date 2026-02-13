import SwiftUI

// MARK: - Command Center View (Home Screen)

struct CommandCenterView: View {
  @ObservedObject var vm: AppViewModel
  
  var onSelectProject: (String) -> Void
  var onNewTask: (() -> Void)? = nil
  var onOpenInbox: ((String?) -> Void)? = nil
  var onOpenMemory: (() -> Void)? = nil
  var onOpenStatus: (() -> Void)? = nil
  var onStartResearch: (() -> Void)? = nil
  var onOpenChat: (() -> Void)? = nil
  
  @AppStorage("lastCommandCenterVisit") private var lastVisitTimestamp: Double = Date().timeIntervalSince1970
  @State private var showWhileYouWereAway = false
  @State private var whileYouWereAwayExpanded = false
  
  private var lastVisit: Date {
    Date(timeIntervalSince1970: lastVisitTimestamp)
  }
  
  // Calculate "While You Were Away" stats
  private var activitySinceLastVisit: (tasks: Int, inbox: Int, errors: Int) {
    var completedTasks = 0
    var newInbox = 0
    var errors = 0
    
    for task in vm.tasks where task.status == .completed {
      let completionDate = task.finishedAt ?? task.updatedAt
      if completionDate > lastVisit {
        completedTasks += 1
      }
    }
    
    for item in vm.inboxItems where item.modifiedAt > lastVisit {
      newInbox += 1
    }
    
    // Check worker history for recent errors
    if let history = vm.workerHistory {
      errors = history.runs.filter { run in
        (run.succeeded == false) && (run.endedAt ?? run.startedAt ?? Date.distantPast) > lastVisit
      }.count
    }
    
    return (completedTasks, newInbox, errors)
  }
  
  // Active tasks
  private var activeTasks: [DashboardTask] {
    vm.tasks.filter { $0.status == .active }
      .sorted { $0.updatedAt > $1.updatedAt }
  }
  
  // Recent inbox items
  private var recentInboxItems: [InboxItem] {
    vm.inboxItems.sorted { $0.modifiedAt > $1.modifiedAt }
      .prefix(3)
      .map { $0 }
  }
  
  // System health from worker status
  private var systemHealth: (server: String, orchestrator: String, workers: Int) {
    let serverStatus = vm.config != nil ? "healthy" : "down"
    let orchestratorStatus = vm.workerStatus != nil ? "running" : "unknown"
    let activeWorkers = (vm.workerStatus?.active == true) ? 1 : 0
    return (serverStatus, orchestratorStatus, activeWorkers)
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Header
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Command Center")
              .font(.largeTitle.bold())
            Text(greetingText())
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          
          Spacer()
          
          // Quick Actions
          HStack(spacing: 12) {
            QuickActionButton(
              icon: "plus.circle.fill",
              label: "New Task",
              color: .blue,
              action: { onNewTask?() }
            )
            
            QuickActionButton(
              icon: "brain.head.profile",
              label: "Capture Thought",
              color: .purple,
              action: { onOpenMemory?() }
            )
            
            QuickActionButton(
              icon: "magnifyingglass.circle.fill",
              label: "Start Research",
              color: .orange,
              action: { onStartResearch?() }
            )
            
            QuickActionButton(
              icon: "message.circle.fill",
              label: "Open Chat",
              color: .green,
              action: { onOpenChat?() }
            )
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        
        // Main grid of cards
        LazyVGrid(columns: [
          GridItem(.flexible()),
          GridItem(.flexible())
        ], spacing: 16) {
          // While You Were Away (full width)
          if showWhileYouWereAway {
            WhileYouWereAwayCard(
              activity: activitySinceLastVisit,
              isExpanded: $whileYouWereAwayExpanded,
              recentTasks: activeTasks.prefix(5).map { $0 }
            )
            .gridCellColumns(2)
          }
          
          // Active Tasks
          ActiveTasksCard(
            tasks: activeTasks,
            onViewAll: {
              // Switch to first active project
              if let firstProject = vm.sortedActiveProjects.first {
                onSelectProject(firstProject.id)
              }
            }
          )
          
          // Inbox
          InboxCard(
            unreadCount: vm.unreadInboxCount,
            recentItems: recentInboxItems,
            onViewAll: { onOpenInbox?(nil) }
          )
          
          // System Health
          SystemHealthCard(
            health: systemHealth,
            onViewDetails: { onOpenStatus?() }
          )
          
          // Recent Memories
          RecentMemoriesCard(
            onViewAll: { onOpenMemory?() }
          )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .onAppear {
      // Check if there's activity since last visit
      let activity = activitySinceLastVisit
      showWhileYouWereAway = (activity.tasks + activity.inbox + activity.errors) > 0
      
      // Update last visit timestamp on disappear
    }
    .onDisappear {
      lastVisitTimestamp = Date().timeIntervalSince1970
    }
  }
  
  private func greetingText() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    var greeting: String
    
    switch hour {
    case 0..<12: greeting = "Good morning"
    case 12..<17: greeting = "Good afternoon"
    default: greeting = "Good evening"
    }
    
    return "\(greeting)! Here's what's happening."
  }
}

// MARK: - While You Were Away Card

private struct WhileYouWereAwayCard: View {
  let activity: (tasks: Int, inbox: Int, errors: Int)
  @Binding var isExpanded: Bool
  let recentTasks: [DashboardTask]
  
  var body: some View {
    HomeCardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "clock.arrow.circlepath")
            .font(.title2)
            .foregroundStyle(.blue)
          Text("While You Were Away")
            .font(.title3.bold())
          
          Spacer()
          
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              isExpanded.toggle()
            }
          } label: {
            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
              .font(.title3)
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
        
        // Summary
        HStack(spacing: 20) {
          if activity.tasks > 0 {
            ActivityStat(
              icon: "checkmark.circle.fill",
              count: activity.tasks,
              label: activity.tasks == 1 ? "task completed" : "tasks completed",
              color: .green
            )
          }
          
          if activity.inbox > 0 {
            ActivityStat(
              icon: "tray.fill",
              count: activity.inbox,
              label: activity.inbox == 1 ? "new inbox item" : "new inbox items",
              color: .blue
            )
          }
          
          if activity.errors > 0 {
            ActivityStat(
              icon: "exclamationmark.triangle.fill",
              count: activity.errors,
              label: activity.errors == 1 ? "error" : "errors",
              color: .red
            )
          }
          
          if activity.tasks == 0 && activity.inbox == 0 && activity.errors == 0 {
            Text("No new activity")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        
        // Expanded details
        if isExpanded && !recentTasks.isEmpty {
          Divider()
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Recent Activity")
              .font(.caption.bold())
              .foregroundStyle(.secondary)
            
            ForEach(recentTasks.prefix(5)) { task in
              HStack(spacing: 8) {
                Circle()
                  .fill(statusColor(task.status))
                  .frame(width: 6, height: 6)
                Text(task.title)
                  .font(.caption)
                  .lineLimit(1)
                Spacer()
                Text(timeAgoString(task.updatedAt))
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
              }
            }
          }
        }
      }
    }
  }
  
  private func statusColor(_ status: TaskStatus) -> Color {
    switch status {
    case .completed: return .green
    case .active: return .blue
    case .rejected: return .red
    default: return .gray
    }
  }
  
  private func timeAgoString(_ date: Date) -> String {
    let elapsed = Date().timeIntervalSince(date)
    if elapsed < 60 {
      return "just now"
    } else if elapsed < 3600 {
      return "\(Int(elapsed/60))m ago"
    } else if elapsed < 86400 {
      return "\(Int(elapsed/3600))h ago"
    } else {
      return "\(Int(elapsed/86400))d ago"
    }
  }
}

private struct ActivityStat: View {
  let icon: String
  let count: Int
  let label: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.body)
        .foregroundStyle(color)
      VStack(alignment: .leading, spacing: 2) {
        Text("\(count)")
          .font(.title3.bold())
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Active Tasks Card

private struct ActiveTasksCard: View {
  let tasks: [DashboardTask]
  let onViewAll: () -> Void
  
  var body: some View {
    HomeCardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "checklist")
            .font(.title3)
            .foregroundStyle(.blue)
          Text("Active Tasks")
            .font(.headline)
          
          Spacer()
          
          if !tasks.isEmpty {
            Text("\(tasks.count)")
              .font(.title2.bold())
              .foregroundStyle(.blue)
          }
        }
        
        if tasks.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("No active tasks")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(tasks.prefix(3)) { task in
              TaskRow(task: task)
            }
          }
          
          if tasks.count > 3 {
            Divider()
            Button {
              onViewAll()
            } label: {
              HStack {
                Text("View all \(tasks.count) tasks")
                  .font(.caption.bold())
                Spacer()
                Image(systemName: "arrow.right")
                  .font(.caption)
              }
              .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

private struct TaskRow: View {
  let task: DashboardTask
  
  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(workStateColor(task.workState))
        .frame(width: 8, height: 8)
      
      Text(task.title)
        .font(.subheadline)
        .lineLimit(1)
      
      Spacer()
      
      if let workState = task.workState {
        Text(workState.rawValue)
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(workStateColor(workState).opacity(0.2))
          .foregroundStyle(workStateColor(workState))
          .clipShape(Capsule())
      }
    }
  }
  
  private func workStateColor(_ state: WorkState?) -> Color {
    switch state {
    case .inProgress: return .blue
    case .blocked: return .red
    case .notStarted: return .gray
    case .other: return .orange
    case .none: return .gray
    }
  }
}

// MARK: - Inbox Card

private struct InboxCard: View {
  let unreadCount: Int
  let recentItems: [InboxItem]
  let onViewAll: () -> Void
  
  var body: some View {
    HomeCardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "tray.fill")
            .font(.title3)
            .foregroundStyle(.orange)
          Text("Inbox")
            .font(.headline)
          
          Spacer()
          
          if unreadCount > 0 {
            Text("\(unreadCount)")
              .font(.title2.bold())
              .foregroundStyle(.orange)
          }
        }
        
        if recentItems.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("Inbox empty")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(recentItems.prefix(3)) { item in
              InboxItemRow(item: item)
            }
          }
          
          Divider()
          Button {
            onViewAll()
          } label: {
            HStack {
              Text("View all")
                .font(.caption.bold())
              Spacer()
              Image(systemName: "arrow.right")
                .font(.caption)
            }
            .foregroundStyle(.orange)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

private struct InboxItemRow: View {
  let item: InboxItem
  
  var body: some View {
    HStack(spacing: 8) {
      if !item.isRead {
        Circle()
          .fill(Color.blue)
          .frame(width: 8, height: 8)
      } else {
        Circle()
          .stroke(Color.gray.opacity(0.3), lineWidth: 1)
          .frame(width: 8, height: 8)
      }
      
      Text(item.title)
        .font(.subheadline)
        .lineLimit(1)
      
      Spacer()
      
      Text(timeAgoString(item.modifiedAt))
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }
  
  private func timeAgoString(_ date: Date) -> String {
    let elapsed = Date().timeIntervalSince(date)
    if elapsed < 60 {
      return "just now"
    } else if elapsed < 3600 {
      return "\(Int(elapsed/60))m ago"
    } else if elapsed < 86400 {
      return "\(Int(elapsed/3600))h ago"
    } else {
      return "\(Int(elapsed/86400))d ago"
    }
  }
}

// MARK: - System Health Card

private struct SystemHealthCard: View {
  let health: (server: String, orchestrator: String, workers: Int)
  let onViewDetails: () -> Void
  
  var body: some View {
    HomeCardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "heart.circle.fill")
            .font(.title3)
            .foregroundStyle(.pink)
          Text("System Health")
            .font(.headline)
          
          Spacer()
          
          StatusDot(status: health.server)
        }
        
        VStack(alignment: .leading, spacing: 8) {
          HealthRow(label: "Server", status: health.server)
          HealthRow(label: "Orchestrator", status: health.orchestrator)
          HealthRow(label: "Active Workers", value: "\(health.workers)")
        }
        
        Divider()
        Button {
          onViewDetails()
        } label: {
          HStack {
            Text("View details")
              .font(.caption.bold())
            Spacer()
            Image(systemName: "arrow.right")
              .font(.caption)
          }
          .foregroundStyle(.pink)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct HealthRow: View {
  var label: String
  var status: String? = nil
  var value: String? = nil
  
  var body: some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      
      Spacer()
      
      if let status = status {
        HStack(spacing: 4) {
          Circle()
            .fill(statusColor(status))
            .frame(width: 6, height: 6)
          Text(status.capitalized)
            .font(.caption.bold())
        }
      } else if let value = value {
        Text(value)
          .font(.caption.bold())
      }
    }
  }
  
  private func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "healthy", "running": return .green
    case "degraded", "warning": return .orange
    case "down", "stopped": return .red
    default: return .gray
    }
  }
}

private struct StatusDot: View {
  let status: String
  
  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 12, height: 12)
  }
  
  private var color: Color {
    switch status.lowercased() {
    case "healthy", "running": return .green
    case "degraded", "warning": return .orange
    case "down", "stopped": return .red
    default: return .gray
    }
  }
}

// MARK: - Recent Memories Card

private struct RecentMemoriesCard: View {
  let onViewAll: () -> Void
  
  var body: some View {
    HomeCardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "brain.head.profile")
            .font(.title3)
            .foregroundStyle(.purple)
          Text("Recent Memories")
            .font(.headline)
          
          Spacer()
        }
        
        // Placeholder - would need to fetch from API
        VStack(spacing: 8) {
          Image(systemName: "brain")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
          Text("Memory integration coming soon")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        
        Divider()
        Button {
          onViewAll()
        } label: {
          HStack {
            Text("View all memories")
              .font(.caption.bold())
            Spacer()
            Image(systemName: "arrow.right")
              .font(.caption)
          }
          .foregroundStyle(.purple)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
  let icon: String
  let label: String
  let color: Color
  let action: () -> Void
  
  var body: some View {
    Button {
      action()
    } label: {
      VStack(spacing: 6) {
        Image(systemName: icon)
          .font(.title2)
          .foregroundStyle(color)
        Text(label)
          .font(.caption)
          .foregroundStyle(.primary)
      }
      .frame(width: 100, height: 70)
      .background(color.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(color.opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Card Container

private struct HomeCardContainer<Content: View>: View {
  let content: Content
  
  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }
  
  var body: some View {
    content
      .padding(16)
      .background(Color(NSColor.windowBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.primary.opacity(0.1), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
  }
}

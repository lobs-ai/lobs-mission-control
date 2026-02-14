import SwiftUI

// MARK: - Command Center View (Home Screen)

struct CommandCenterView: View {
  @ObservedObject var vm: AppViewModel
  
  var onSelectProject: (String) -> Void
  var onNewTask: (() -> Void)? = nil
  var onOpenInbox: ((String?) -> Void)? = nil
  var onOpenMemory: (() -> Void)? = nil
  var onOpenStatus: (() -> Void)? = nil
  var onOpenTeam: (() -> Void)? = nil
  var onStartResearch: (() -> Void)? = nil
  var onOpenChat: (() -> Void)? = nil
  var memoryViewModel: MemoryViewModel?
  
  @State private var upcomingEvents: [ScheduledEvent] = []
  @State private var recentMemories: [MemoryItem] = []
  @State private var showNewTaskSheet = false
  @State private var showAllActivitySheet = false
  @State private var showDetailedStats = false
  @State private var selectedTask: DashboardTask? = nil
  
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
  
  // Active agents count
  private var activeAgentsCount: Int {
    vm.agentStatuses.values.filter { $0.status == "working" || $0.status == "thinking" }.count
  }
  
  // List of working agents
  private var workingAgents: [String] {
    vm.agentStatuses.values
      .filter { $0.status == "working" || $0.status == "thinking" }
      .map { $0.agentType }
      .sorted()
  }
  
  // MARK: - Stats
  
  private var activeTasksCount: Int {
    vm.tasks.filter { $0.status == .active }.count
  }
  
  private var completedThisWeek: Int {
    let calendar = Calendar.current
    var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
    comps.weekday = 2 // Monday
    let weekStart = calendar.date(from: comps) ?? Date()
    let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
    return vm.tasks.filter { task in
      guard task.status == .completed else { return false }
      let completionDate = task.finishedAt ?? task.updatedAt
      return completionDate >= weekStart && completionDate < weekEnd
    }.count
  }
  
  private var blockedTasksCount: Int {
    vm.tasks.filter { $0.workState == .blocked && $0.status != .completed && $0.status != .rejected }.count
  }
  
  private var inboxTasksCount: Int {
    vm.tasks.filter { $0.status == .inbox }.count
  }
  
  private var staleTasksCount: Int {
    let cutoff = Date().addingTimeInterval(-7 * 86400)
    return vm.tasks.filter { t in
      (t.status == .active || t.status == .inbox) && t.updatedAt < cutoff
    }.count
  }
  
  // MARK: - Activity Feed
  
  fileprivate enum ActivityEvent: Identifiable {
    case taskCompleted(DashboardTask)
    case inboxItem(InboxItem)
    case workerRun(WorkerHistoryRun)
    
    var id: String {
      switch self {
      case .taskCompleted(let t):
        return "task-completed-\(t.id)-\(t.updatedAt.timeIntervalSince1970)"
      case .inboxItem(let item):
        return "inbox-\(item.id)-\(item.modifiedAt.timeIntervalSince1970)"
      case .workerRun(let run):
        return "worker-\(run.id)"
      }
    }
    
    var date: Date {
      switch self {
      case .taskCompleted(let t):
        return t.finishedAt ?? t.updatedAt
      case .inboxItem(let item):
        return item.modifiedAt
      case .workerRun(let run):
        return run.endedAt ?? run.startedAt ?? Date.distantPast
      }
    }
  }
  
  private var activityFeed: [ActivityEvent] {
    let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var events: [ActivityEvent] = []
    
    // Task completions
    for t in vm.tasks where t.status == .completed {
      let completionDate = t.finishedAt ?? t.updatedAt
      if completionDate >= weekAgo {
        events.append(.taskCompleted(t))
      }
    }
    
    // Inbox items
    for item in vm.inboxItems where item.modifiedAt >= weekAgo {
      events.append(.inboxItem(item))
    }
    
    // Worker runs - removed from recent activity display
    // (keeping enum case for potential future use)
    
    return events
      .sorted { $0.date > $1.date }
      .prefix(25)
      .map { $0 }
  }
  
  var body: some View {
    ZStack(alignment: .top) {
      // Gradient background at top
      LinearGradient(
        gradient: Gradient(colors: [
          Color.blue.opacity(0.08),
          Color.purple.opacity(0.05),
          Color.clear
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 300)
      .ignoresSafeArea()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Header
          VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 6) {
                Text("Command Center")
                  .font(.system(size: 36, weight: .bold))
                Text(greetingText())
                  .font(.title3)
                  .foregroundStyle(.secondary)
              }
              
              Spacer()
              
              // Software Update Badge (top right)
              if vm.dashboardUpdateAvailable {
                SoftwareUpdateBadge(
                  onTap: { onOpenStatus?() }
                )
                .transition(.scale.combined(with: .opacity))
              }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            
            // Quick Actions
            HStack(spacing: 14) {
              QuickActionButton(
                icon: "plus.circle.fill",
                label: "New Task",
                color: .blue,
                action: { showNewTaskSheet = true }
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
            .padding(.horizontal, 24)
          }
          
          // Stats Cards Row
          StatsCardsRow(
            activeTasksCount: activeTasksCount,
            completedThisWeek: completedThisWeek,
            blockedTasksCount: blockedTasksCount,
            inboxCount: vm.unreadInboxCount,
            inboxTasksCount: inboxTasksCount,
            staleTasksCount: staleTasksCount,
            onShowDetails: { showDetailedStats.toggle() }
          )
          .padding(.horizontal, 24)
          
          // Detailed stats
          if showDetailedStats {
            DetailedStatsSection(vm: vm)
              .padding(.horizontal, 24)
              .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
          }
          
          // Recent Activity
          ActivityFeedSection(
            events: activityFeed,
            vm: vm,
            onShowAll: { showAllActivitySheet = true },
            onOpenTask: { task in selectedTask = task },
            onOpenInbox: { itemId in onOpenInbox?(itemId) }
          )
          .padding(.horizontal, 24)
          
          // Projects Grid
          ProjectCardsSection(
            projects: vm.sortedActiveProjects,
            tasks: vm.tasks,
            onSelectProject: onSelectProject
          )
          .padding(.horizontal, 24)
          
          // Bottom cards grid
          LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
          ], spacing: 20) {
            // System Health
            SystemHealthCard(
              health: systemHealth,
              onViewDetails: { onOpenStatus?() }
            )
            
            // Team
            TeamCard(
              activeAgents: activeAgentsCount,
              workingAgents: workingAgents,
              onViewDetails: { onOpenTeam?() }
            )
            
            // Upcoming Events
            UpcomingEventsCard(
              events: upcomingEvents
            )
            
            // Recent Memories
            RecentMemoriesCard(
              memories: recentMemories,
              onViewAll: { onOpenMemory?() }
            )
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 28)
        }
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .onAppear {
      // Load calendar events
      Task {
        do {
          upcomingEvents = try await vm.api.fetchUpcomingEvents(limit: 5)
        } catch {
          print("Failed to load upcoming events: \(error)")
        }
      }
      
      // Load recent memories
      Task {
        if let memVM = memoryViewModel {
          await memVM.loadMemories()
          recentMemories = Array(memVM.memories.prefix(3))
        }
      }
    }
    .sheet(isPresented: $showNewTaskSheet) {
      NewTaskSheet(vm: vm, isPresented: $showNewTaskSheet)
    }
    .sheet(isPresented: $showAllActivitySheet) {
      ActivitySheetView(
        vm: vm,
        events: activityFeed,
        onOpenTask: { task in
          selectedTask = task
        },
        onOpenInbox: { itemId in
          onOpenInbox?(itemId)
        }
      )
      .frame(minWidth: 640, minHeight: 620)
    }
    .sheet(item: $selectedTask) { task in
      TaskDetailSheet(task: task, vm: vm)
        .frame(minWidth: 480, minHeight: 500)
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

// MARK: - Stats Cards Row

private struct StatsCardsRow: View {
  let activeTasksCount: Int
  let completedThisWeek: Int
  let blockedTasksCount: Int
  let inboxCount: Int
  let inboxTasksCount: Int
  let staleTasksCount: Int
  let onShowDetails: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Overview")
          .font(.headline.bold())
        Spacer()
        Button(action: onShowDetails) {
          HStack(spacing: 4) {
            Image(systemName: "chart.bar")
              .font(.caption)
            Text("Details")
              .font(.caption)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.accentColor.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
      }
      
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          StatCard(label: "Active Tasks", value: "\(activeTasksCount)", icon: "flame.fill", color: .orange)
          StatCard(label: "Done This Week", value: "\(completedThisWeek)", icon: "checkmark.circle.fill", color: .green)
          
          if blockedTasksCount > 0 {
            StatCard(label: "Blocked", value: "\(blockedTasksCount)", icon: "exclamationmark.octagon.fill", color: .red)
          }
          
          if inboxTasksCount > 0 {
            StatCard(label: "Inbox Tasks", value: "\(inboxTasksCount)", icon: "tray.full.fill", color: .blue)
          }
          
          if inboxCount > 0 {
            StatCard(label: "Inbox Items", value: "\(inboxCount)", icon: "envelope.badge", color: .red)
          }
          
          if staleTasksCount > 0 {
            StatCard(label: "Stale", value: "\(staleTasksCount)", icon: "exclamationmark.triangle.fill", color: .orange)
          }
        }
      }
    }
  }
}

private struct StatCard: View {
  let label: String
  let value: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.footnote)
          .foregroundStyle(color)
        Text(label)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Text(value)
        .font(.title)
        .fontWeight(.bold)
        .foregroundStyle(color)
    }
    .frame(minWidth: 120)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(Color(NSColor.windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
  }
}

// MARK: - Detailed Stats Section

private struct DetailedStatsSection: View {
  @ObservedObject var vm: AppViewModel
  
  private var projectStats: [(project: Project, active: Int, completed: Int, blocked: Int)] {
    vm.sortedActiveProjects.map { project in
      let projectTasks = vm.tasks.filter { $0.projectId == project.id }
      return (
        project: project,
        active: projectTasks.filter { $0.status == .active }.count,
        completed: projectTasks.filter { $0.status == .completed }.count,
        blocked: projectTasks.filter { $0.workState == .blocked && $0.status != .completed && $0.status != .rejected }.count
      )
    }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Breakdown by Project")
        .font(.headline.bold())
      
      VStack(spacing: 0) {
        ForEach(projectStats, id: \.project.id) { stat in
          VStack(spacing: 8) {
            HStack {
              Text(stat.project.title)
                .font(.subheadline.bold())
              Spacer()
            }
            
            HStack(spacing: 12) {
              if stat.active > 0 {
                StatBadge(label: "Active", count: stat.active, color: .orange)
              }
              if stat.completed > 0 {
                StatBadge(label: "Done", count: stat.completed, color: .green)
              }
              if stat.blocked > 0 {
                StatBadge(label: "Blocked", count: stat.blocked, color: .red)
              }
              Spacer()
            }
          }
          .padding(12)
          
          if stat.project.id != projectStats.last?.project.id {
            Divider()
          }
        }
      }
      .background(Color(NSColor.windowBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.primary.opacity(0.1), lineWidth: 1)
      )
    }
  }
}

private struct StatBadge: View {
  let label: String
  let count: Int
  let color: Color
  
  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.caption2)
      Text("\(count)")
        .font(.caption2.bold())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(color.opacity(0.15))
    .foregroundStyle(color)
    .clipShape(Capsule())
  }
}

// MARK: - Activity Feed Section

private struct ActivityFeedSection: View {
  let events: [CommandCenterView.ActivityEvent]
  @ObservedObject var vm: AppViewModel
  let onShowAll: () -> Void
  let onOpenTask: (DashboardTask) -> Void
  let onOpenInbox: (String?) -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "clock.arrow.circlepath")
          .foregroundStyle(.indigo)
        Text("Recent Activity")
          .font(.headline.bold())
        Spacer()
        if !events.isEmpty {
          Button(action: onShowAll) {
            Text("View all")
              .font(.caption.bold())
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
      
      if events.isEmpty {
        Text("No activity in the last 7 days")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
          .background(Color(NSColor.windowBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 12))
      } else {
        VStack(spacing: 0) {
          ForEach(Array(events.prefix(10).enumerated()), id: \.element.id) { idx, event in
            ActivityEventRow(
              vm: vm,
              event: event,
              onOpenTask: onOpenTask,
              onOpenInbox: onOpenInbox
            )
            if idx < min(9, events.count - 1) {
              Divider().padding(.leading, 36)
            }
          }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
      }
    }
  }
}

private struct ActivityEventRow: View {
  @ObservedObject var vm: AppViewModel
  let event: CommandCenterView.ActivityEvent
  let onOpenTask: (DashboardTask) -> Void
  let onOpenInbox: (String?) -> Void
  
  @State private var isHovering = false
  
  var body: some View {
    Button {
      switch event {
      case .taskCompleted(let t):
        onOpenTask(t)
      case .inboxItem(let item):
        onOpenInbox(item.id)
      case .workerRun:
        break
      }
    } label: {
      HStack(spacing: 10) {
        icon
          .font(.footnote)
          .frame(width: 24)
        
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.footnote)
            .fontWeight(.medium)
            .lineLimit(1)
          
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
        
        Spacer()
        
        Text(relativeTime(event.date))
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
    }
    .buttonStyle(.plain)
    .disabled(!isClickable)
    .onHover { h in isHovering = h }
  }
  
  private var isClickable: Bool {
    switch event {
    case .workerRun:
      return false
    default:
      return true
    }
  }
  
  private var title: String {
    switch event {
    case .taskCompleted(let t):
      return "Completed: \(t.title)"
    case .inboxItem(let item):
      return "Inbox: \(item.title)"
    case .workerRun:
      return "Worker ran"
    }
  }
  
  private var subtitle: String {
    switch event {
    case .taskCompleted(let t):
      let projectId = t.projectId ?? "default"
      let projectName = vm.projects.first(where: { $0.id == projectId })?.title ?? projectId
      return "\(projectName) · \(t.owner?.rawValue ?? "unassigned")"
    case .inboxItem(let item):
      return item.summary
    case .workerRun(let run):
      let tasks = run.tasksCompleted ?? 0
      let dur = formatDuration(start: run.startedAt, end: run.endedAt)
      return "\(tasks) task(s) · \(dur)"
    }
  }
  
  @ViewBuilder
  private var icon: some View {
    switch event {
    case .taskCompleted:
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .inboxItem:
      Image(systemName: "tray.circle.fill")
        .foregroundStyle(.blue)
    case .workerRun:
      Image(systemName: "gearshape.2.fill")
        .foregroundStyle(.purple)
    }
  }
  
  private func formatDuration(start: Date?, end: Date?) -> String {
    guard let start, let end else { return "" }
    let s = max(0, end.timeIntervalSince(start))
    if s < 60 { return "\(Int(s))s" }
    if s < 3600 { return "\(Int(s/60))m" }
    return String(format: "%.1fh", s/3600)
  }
  
  private func relativeTime(_ date: Date) -> String {
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

// MARK: - Projects Cards Section

private struct ProjectCardsSection: View {
  let projects: [Project]
  let tasks: [DashboardTask]
  let onSelectProject: (String) -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Projects")
        .font(.headline.bold())
      
      if projects.isEmpty {
        Text("No active projects")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
          .background(Color(NSColor.windowBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 12))
      } else {
        LazyVGrid(columns: [
          GridItem(.flexible()),
          GridItem(.flexible())
        ], spacing: 16) {
          ForEach(projects) { project in
            ProjectCard(
              project: project,
              tasks: tasks.filter { $0.projectId == project.id },
              onTap: { onSelectProject(project.id) }
            )
          }
        }
      }
    }
  }
}

private struct ProjectCard: View {
  let project: Project
  let tasks: [DashboardTask]
  let onTap: () -> Void
  
  @State private var isHovering = false
  
  private var activeCount: Int { tasks.filter { $0.status == .active }.count }
  private var completedCount: Int { tasks.filter { $0.status == .completed }.count }
  private var inboxCount: Int { tasks.filter { $0.status == .inbox }.count }
  private var blockedCount: Int { tasks.filter { $0.workState == .blocked && $0.status != .completed && $0.status != .rejected }.count }
  private var totalCount: Int { tasks.count }
  
  private var lastActivity: Date? {
    tasks.map(\.updatedAt).max()
  }
  
  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        // Title row
        HStack(spacing: 8) {
          Image(systemName: projectIcon(project.type))
            .font(.body)
            .foregroundStyle(projectColor(project.type))
          
          Text(project.title)
            .font(.callout.bold())
            .lineLimit(1)
          
          Spacer()
          
          Text(project.type?.rawValue.capitalized ?? "Default")
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(projectColor(project.type).opacity(0.15))
            .foregroundStyle(projectColor(project.type))
            .clipShape(Capsule())
        }
        
        // Counts
        HStack(spacing: 12) {
          if activeCount > 0 {
            CountBadge(label: "Active", count: activeCount, color: .orange)
          }
          if inboxCount > 0 {
            CountBadge(label: "Inbox", count: inboxCount, color: .blue)
          }
          if completedCount > 0 {
            CountBadge(label: "Done", count: completedCount, color: .green)
          }
          if blockedCount > 0 {
            CountBadge(label: "Blocked", count: blockedCount, color: .red)
          }
          Spacer()
          if totalCount > 0 {
            Text("\(totalCount) total")
              .font(.footnote)
              .foregroundStyle(.tertiary)
          }
        }
        
        // Last activity
        if let last = lastActivity {
          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.system(size: 11))
              .foregroundStyle(.tertiary)
            Text("Last activity: \(relativeTime(last))")
              .font(.footnote)
              .foregroundStyle(.tertiary)
          }
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
      .contentShape(Rectangle())
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(NSColor.windowBackgroundColor))
          .shadow(color: .black.opacity(isHovering ? 0.08 : 0.03), radius: isHovering ? 8 : 4, y: 2)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isHovering ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: isHovering ? 1.5 : 1)
      )
      .scaleEffect(isHovering ? 1.01 : 1.0)
      .animation(.easeOut(duration: 0.15), value: isHovering)
    }
    .buttonStyle(.plain)
    .onHover { h in isHovering = h }
  }
  
  private func projectIcon(_ type: ProjectType?) -> String {
    switch type {
    case .kanban: return "rectangle.3.group.fill"
    case .research: return "magnifyingglass"
    case .tracker: return "checklist"
    case .none: return "folder.fill"
    }
  }
  
  private func projectColor(_ type: ProjectType?) -> Color {
    switch type {
    case .kanban: return .blue
    case .research: return .purple
    case .tracker: return .green
    case .none: return .gray
    }
  }
  
  private func relativeTime(_ date: Date) -> String {
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

private struct CountBadge: View {
  let label: String
  let count: Int
  let color: Color
  
  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.caption2)
      Text("\(count)")
        .font(.caption2.bold())
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(color.opacity(0.15))
    .foregroundStyle(color)
    .clipShape(Capsule())
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

// MARK: - Team Card

private struct TeamCard: View {
  let activeAgents: Int
  let workingAgents: [String]
  let onViewDetails: () -> Void
  
  var body: some View {
    HomeCardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "person.3.fill")
            .font(.title3)
            .foregroundStyle(.blue)
          Text("Team")
            .font(.headline)
          
          Spacer()
          
          if activeAgents > 0 {
            Text("\(activeAgents)")
              .font(.title2.bold())
              .foregroundStyle(.blue)
          }
        }
        
        if workingAgents.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "zzz")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("All agents idle")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text("Working Now")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .textCase(.uppercase)
            
            ForEach(workingAgents.prefix(3), id: \.self) { agentType in
              HStack(spacing: 8) {
                Text(agentEmoji(agentType))
                  .font(.caption)
                
                Text(agentType.capitalized)
                  .font(.subheadline)
                
                Spacer()
                
                HStack(spacing: 4) {
                  Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                  Text("Active")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
              }
            }
          }
        }
        
        Divider()
        Button {
          onViewDetails()
        } label: {
          HStack {
            Text("View team")
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
  
  private func agentEmoji(_ type: String) -> String {
    switch type {
    case "programmer": return "🛠️"
    case "researcher": return "🔬"
    case "writer": return "✍️"
    case "reviewer": return "👁️"
    case "architect": return "🏗️"
    default: return "🤖"
    }
  }
}

// MARK: - Upcoming Events Card

private struct UpcomingEventsCard: View {
  let events: [ScheduledEvent]
  
  var body: some View {
    HomeCardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "calendar.circle.fill")
            .font(.title3)
            .foregroundStyle(.orange)
          Text("Upcoming Events")
            .font(.headline)
          
          Spacer()
        }
        
        if events.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "calendar")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("No upcoming events")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
        } else {
          VStack(spacing: 10) {
            ForEach(events) { event in
              HStack(spacing: 10) {
                VStack(alignment: .center, spacing: 2) {
                  Text(dayText(event.scheduledAt))
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                  Text(dateText(event.scheduledAt))
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                }
                .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                  Text(event.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                  
                  HStack(spacing: 4) {
                    if let type = event.eventType {
                      Text(typeIcon(type))
                        .font(.caption2)
                      Text(type.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    
                    if !isAllDay(event) {
                      Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                      Text(timeText(event.scheduledAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                  }
                }
                
                Spacer()
              }
              .padding(.vertical, 4)
            }
          }
        }
      }
    }
  }
  
  private func dayText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    return formatter.string(from: date)
  }
  
  private func dateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter.string(from: date)
  }
  
  private func timeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
  
  private func isAllDay(_ event: ScheduledEvent) -> Bool {
    event.allDay ?? false
  }
  
  private func typeIcon(_ type: String) -> String {
    switch type.lowercased() {
    case "reminder": return "⏰"
    case "task": return "✅"
    case "meeting": return "👥"
    default: return "📅"
    }
  }
}

// MARK: - Recent Memories Card

private struct RecentMemoriesCard: View {
  let memories: [MemoryItem]
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
        
        if memories.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "brain")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
            Text("No recent memories")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
        } else {
          VStack(spacing: 8) {
            ForEach(memories) { memory in
              HStack(spacing: 10) {
                Image(systemName: memory.typeBadgeIcon)
                  .font(.caption)
                  .foregroundStyle(.purple)
                  .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                  Text(memory.displayTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                  
                  HStack(spacing: 4) {
                    Text(agentEmoji(memory.agent))
                      .font(.caption2)
                    Text(memory.agent.capitalized)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                    Text("•")
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                    Text(formatDate(memory.updatedAt))
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                  }
                }
                
                Spacer()
              }
              .padding(.vertical, 4)
            }
          }
        }
        
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
  
  private func agentEmoji(_ agent: String) -> String {
    switch agent {
    case "main": return "👤"
    case "programmer": return "💻"
    case "writer": return "✍️"
    case "researcher": return "🔍"
    case "reviewer": return "👀"
    case "architect": return "🏗️"
    default: return "🤖"
    }
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
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
      .frame(minHeight: 220, alignment: .top)
      .padding(20)
      .background(Color(NSColor.windowBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.primary.opacity(0.08), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
  }
}

// MARK: - Activity Sheet View

private struct ActivitySheetView: View {
  @ObservedObject var vm: AppViewModel
  let events: [CommandCenterView.ActivityEvent]
  let onOpenTask: (DashboardTask) -> Void
  let onOpenInbox: (String?) -> Void
  
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Recent Activity")
          .font(.title3.bold())
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(16)
      
      Divider()
      
      ScrollView {
        LazyVStack(spacing: 0) {
          if events.isEmpty {
            Text("No activity")
              .font(.callout)
              .foregroundStyle(.secondary)
              .padding(20)
              .frame(maxWidth: .infinity, alignment: .center)
          } else {
            ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
              ActivityEventRow(
                vm: vm,
                event: event,
                onOpenTask: { t in
                  onOpenTask(t)
                  dismiss()
                },
                onOpenInbox: { itemId in
                  onOpenInbox(itemId)
                  dismiss()
                }
              )
              if idx < events.count - 1 {
                Divider().padding(.leading, 36)
              }
            }
          }
        }
        .padding(16)
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
  }
}

// MARK: - Task Detail Sheet

private struct TaskDetailSheet: View {
  let task: DashboardTask
  @ObservedObject var vm: AppViewModel
  
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(task.title)
          .font(.title3.bold())
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(16)
      
      Divider()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let projectId = task.projectId {
            if let project = vm.projects.first(where: { $0.id == projectId }) {
              HStack {
                Text("Project:")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                Text(project.title)
                  .font(.subheadline.bold())
              }
            }
          }
          
          HStack {
            Text("Status:")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Text(task.status.rawValue.capitalized)
              .font(.subheadline.bold())
          }
          
          if let workState = task.workState {
            HStack {
              Text("Work State:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text(workState.rawValue)
                .font(.subheadline.bold())
            }
          }
          
          HStack {
            Text("Owner:")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Text(task.resolvedOwner.rawValue)
              .font(.subheadline.bold())
          }
          
          if let notes = task.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Notes:")
                .font(.subheadline.bold())
              Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(16)
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
  }
}

// MARK: - New Task Sheet

private struct NewTaskSheet: View {
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var title = ""
  @State private var selectedProjectId: String? = nil
  @State private var notes = ""
  @State private var isCreating = false
  @State private var errorMessage: String?
  
  var body: some View {
    VStack(spacing: 0) {
      sheetHeader
      Divider()
      sheetForm
      Divider()
      sheetFooter
    }
    .frame(width: 500, height: 500)
    .background(Color(NSColor.controlBackgroundColor))
  }

  private var sheetHeader: some View {
    HStack {
      Text("New Task")
        .font(.title2.bold())
      Spacer()
      Button {
        isPresented = false
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title3)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
  }

  private var sheetForm: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        titleField
        projectPicker
        notesField
        errorBanner
      }
      .padding()
    }
  }

  private var titleField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Title")
        .font(.subheadline.bold())
      TextField("What needs to be done?", text: $title)
        .textFieldStyle(.plain)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
  }

  private var projectPicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Project")
        .font(.subheadline.bold())
      Picker("Select Project", selection: $selectedProjectId) {
        Text("No Project").tag(nil as String?)
        ForEach(vm.sortedActiveProjects, id: \.id) { project in
          Text(project.title).tag(project.id as String?)
        }
      }
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(8)
      .background(Color(NSColor.controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.primary.opacity(0.1), lineWidth: 1)
      )
    }
  }

  private var notesField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Notes (Optional)")
        .font(.subheadline.bold())
      TextEditor(text: $notes)
        .font(.body)
        .frame(minHeight: 100)
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let error = errorMessage {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.red.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  private var sheetFooter: some View {
    HStack(spacing: 12) {
      Button("Cancel") {
        isPresented = false
      }
      .keyboardShortcut(.escape)
        
        Spacer()
        
        Button {
          createTask()
        } label: {
          HStack(spacing: 6) {
            if isCreating {
              ProgressView()
                .scaleEffect(0.7)
                .frame(width: 14, height: 14)
            }
            Text("Create Task")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(title.isEmpty || isCreating)
        .keyboardShortcut(.return)
      }
      .padding()
      .background(Color(NSColor.windowBackgroundColor))
  }

  private func createTask() {
    guard !title.isEmpty else { return }
    
    isCreating = true
    errorMessage = nil
    
    Task {
      do {
        let _ = try await vm.api.addTask(
          title: title,
          owner: .lobs,
          status: .inbox,
          projectId: selectedProjectId,
          workState: .notStarted,
          reviewState: .pending,
          notes: notes.isEmpty ? nil : notes
        )
        
        // Reload tasks
        await MainActor.run { vm.reload() }
        
        // Close sheet on success
        await MainActor.run {
          isPresented = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isCreating = false
        }
      }
    }
  }
}

// MARK: - Software Update Badge

private struct SoftwareUpdateBadge: View {
  let onTap: () -> Void
  
  @State private var isHovering = false
  @State private var isPulsing = true
  
  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 8) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.title3)
          .foregroundStyle(.white)
          .scaleEffect(isPulsing ? 1.1 : 1.0)
          .animation(
            .easeInOut(duration: 1.5)
              .repeatForever(autoreverses: true),
            value: isPulsing
          )
        
        VStack(alignment: .leading, spacing: 2) {
          Text("Update Available")
            .font(.caption.bold())
            .foregroundStyle(.white)
          
          Text("Tap to view")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.85))
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(
            LinearGradient(
              colors: [Color.blue, Color.blue.opacity(0.8)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .shadow(color: Color.blue.opacity(isHovering ? 0.5 : 0.3), radius: isHovering ? 12 : 8, x: 0, y: 4)
      )
      .scaleEffect(isHovering ? 1.03 : 1.0)
      .animation(.easeOut(duration: 0.2), value: isHovering)
    }
    .buttonStyle(.plain)
    .onHover { h in isHovering = h }
    .onAppear {
      isPulsing = true
    }
  }
}

import SwiftUI

struct StatusView: View {
  @StateObject private var viewModel: StatusViewModel
  @Binding var isPresented: Bool
  
  init(apiService: APIService, isPresented: Binding<Bool>) {
    _viewModel = StateObject(wrappedValue: StatusViewModel(apiService: apiService))
    _isPresented = isPresented
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        HStack(spacing: 8) {
          Image(systemName: "chart.bar.fill")
            .font(.title2)
            .foregroundStyle(.linearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
          Text("System Status")
            .font(.title2.bold())
        }
        
        Spacer()
        
        if let lastRefresh = viewModel.lastRefresh {
          Text("Updated \(timeAgoString(lastRefresh))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Button {
          Task { await viewModel.loadAll() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.body)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        
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
      
      Divider()
      
      if viewModel.isLoading && viewModel.overview == nil {
        // Initial loading state
        VStack(spacing: 16) {
          ProgressView()
          Text("Loading system status...")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.error, viewModel.overview == nil {
        // Error state
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 48))
            .foregroundStyle(.orange)
          Text(error)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
          Button("Retry") {
            Task { await viewModel.loadAll() }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      } else {
        // Main content
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            // Health cards grid
            LazyVGrid(columns: [
              GridItem(.flexible()),
              GridItem(.flexible()),
              GridItem(.flexible())
            ], spacing: 16) {
              ServerCard(server: viewModel.overview?.server)
              OrchestratorCard(
                orchestrator: viewModel.overview?.orchestrator,
                workers: viewModel.overview?.workers,
                onPause: { Task { await viewModel.pauseOrchestrator() } },
                onResume: { Task { await viewModel.resumeOrchestrator() } }
              )
              WorkersCard(workers: viewModel.overview?.workers)
            }
            
            // Software Updates
            UpdatesSection(apiService: viewModel.apiService)
            
            // Agents grid
            if let agents = viewModel.overview?.agents, !agents.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("Agents")
                  .font(.title3.bold())
                  .padding(.horizontal, 4)
                
                LazyVGrid(columns: [
                  GridItem(.flexible()),
                  GridItem(.flexible()),
                  GridItem(.flexible()),
                  GridItem(.flexible())
                ], spacing: 12) {
                  ForEach(agents) { agent in
                    AgentCard(agent: agent)
                  }
                }
              }
            }
            
            // Activity & Costs row
            HStack(alignment: .top, spacing: 16) {
              // Activity feed
              VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                  .font(.title3.bold())
                  .padding(.horizontal, 4)
                
                ActivityFeed(events: viewModel.activity)
              }
              .frame(maxWidth: .infinity)
              
              // Cost summary
              if let costs = viewModel.costs {
                VStack(alignment: .leading, spacing: 12) {
                  Text("Cost Summary")
                    .font(.title3.bold())
                    .padding(.horizontal, 4)
                  
                  CostSummaryView(costs: costs)
                }
                .frame(width: 320)
              }
            }
          }
          .padding()
        }
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .onAppear {
      viewModel.startAutoRefresh()
    }
    .onDisappear {
      viewModel.stopAutoRefresh()
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

// MARK: - Server Card

private struct ServerCard: View {
  let server: SystemOverview.ServerHealth?
  
  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "server.rack")
            .font(.title3)
            .foregroundStyle(.blue)
          Text("Server")
            .font(.headline)
          Spacer()
          StatusDot(status: server?.status ?? "unknown")
        }
        
        if let server = server {
          VStack(alignment: .leading, spacing: 6) {
            StatRow(label: "Uptime", value: formatUptime(server.uptimeSeconds))
            StatRow(label: "Version", value: server.version)
          }
        } else {
          Text("No data")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
  
  private func formatUptime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    if hours > 24 {
      let days = hours / 24
      return "\(days)d \(hours % 24)h"
    } else if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else {
      return "\(minutes)m"
    }
  }
}

// MARK: - Orchestrator Card

private struct OrchestratorCard: View {
  let orchestrator: SystemOverview.OrchestratorStatus?
  let workers: SystemOverview.WorkersStatus?
  let onPause: () -> Void
  let onResume: () -> Void
  
  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "gearshape.2.fill")
            .font(.title3)
            .foregroundStyle(.purple)
          Text("Orchestrator")
            .font(.headline)
          Spacer()
          if let orchestrator = orchestrator {
            StateBadge(state: derivedState(orchestrator))
          }
        }
        
        if let orchestrator = orchestrator {
          VStack(alignment: .leading, spacing: 8) {
            // Workers info
            if let workers = workers {
              StatRow(label: "Active Workers", value: "\(workers.active)")
            }
            
            // Control button
            HStack(spacing: 8) {
              if orchestrator.running && !orchestrator.paused {
                Button {
                  onPause()
                } label: {
                  Label("Pause", systemImage: "pause.fill")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
              } else if orchestrator.paused {
                Button {
                  onResume()
                } label: {
                  Label("Resume", systemImage: "play.fill")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
              }
            }
          }
        } else {
          Text("No data")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
  
  private func derivedState(_ orchestrator: SystemOverview.OrchestratorStatus) -> String {
    if orchestrator.paused {
      return "paused"
    } else if orchestrator.running {
      return "running"
    } else {
      return "stopped"
    }
  }
}

// MARK: - Workers Card

private struct WorkersCard: View {
  let workers: SystemOverview.WorkersStatus?
  
  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "person.3.fill")
            .font(.title3)
            .foregroundStyle(.green)
          Text("Workers")
            .font(.headline)
          Spacer()
          if let workers = workers {
            Text("\(workers.active)")
              .font(.title2.bold())
              .foregroundStyle(.green)
          }
        }
        
        if let workers = workers {
          VStack(alignment: .leading, spacing: 6) {
            StatRow(label: "Active", value: "\(workers.active)")
            StatRow(label: "Completed", value: "\(workers.totalCompleted)")
            StatRow(label: "Failed", value: "\(workers.totalFailed)")
          }
        } else {
          Text("No data")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

// MARK: - Agent Card

private struct AgentCard: View {
  let agent: SystemOverview.AgentStatusSummary
  
  var body: some View {
    CardContainer(compact: true) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: agentIcon(agent.type))
            .font(.body)
            .foregroundStyle(agentColor(agent.type))
          Text(agent.type.capitalized)
            .font(.subheadline.bold())
          Spacer()
          StatusDot(status: agent.status)
        }
        
        VStack(alignment: .leading, spacing: 4) {
          if let lastActive = agent.lastActive, let date = parseISO(lastActive) {
            Text("Last active \(timeAgoString(date))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          } else {
            Text("Never active")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
  }
  
  private func agentIcon(_ type: String) -> String {
    switch type.lowercased() {
    case "programmer": return "hammer.fill"
    case "writer": return "doc.text.fill"
    case "researcher": return "magnifyingglass"
    case "reviewer": return "checkmark.seal.fill"
    case "architect": return "building.columns.fill"
    default: return "gearshape.fill"
    }
  }
  
  private func agentColor(_ type: String) -> Color {
    switch type.lowercased() {
    case "programmer": return .blue
    case "writer": return .purple
    case "researcher": return .orange
    case "reviewer": return .green
    case "architect": return .indigo
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
  
  private func parseISO(_ str: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    if let d = f.date(from: str) { return d }
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: str) { return d }
    let nf = DateFormatter()
    nf.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    nf.timeZone = TimeZone(identifier: "UTC")
    return nf.date(from: str)
  }
}

// MARK: - Activity Feed

private struct ActivityFeed: View {
  let events: [ActivityEvent]
  @State private var expandedEventId: String?
  
  var body: some View {
    CardContainer {
      if events.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "clock.badge.questionmark")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
          Text("No recent activity")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(events) { event in
              ActivityEventRow(
                event: event,
                isExpanded: expandedEventId == event.id,
                onToggleExpand: {
                  withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEventId = (expandedEventId == event.id) ? nil : event.id
                  }
                }
              )
              
              if event.id != events.last?.id {
                Divider()
                  .padding(.leading, 36)
              }
            }
          }
        }
        .frame(maxHeight: 500)
      }
    }
  }
}

private struct ActivityEventRow: View {
  let event: ActivityEvent
  let isExpanded: Bool
  let onToggleExpand: () -> Void
  
  var body: some View {
    Button {
      if event.details != nil {
        onToggleExpand()
      }
    } label: {
      HStack(alignment: .top, spacing: 12) {
        // Icon
        Image(systemName: event.displayType.icon)
          .font(.body)
          .foregroundStyle(eventColor(event.displayType.color))
          .frame(width: 24, height: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          // Title
          Text(event.title)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(isExpanded ? nil : 2)
          
          // Timestamp
          Text(timeAgoString(event.timestamp))
            .font(.caption)
            .foregroundStyle(.secondary)
          
          // Details (if expanded)
          if isExpanded, let details = event.details {
            Text(details)
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.top, 4)
              .lineLimit(nil)
          }
        }
        
        Spacer()
        
        if event.details != nil {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.vertical, 12)
      .padding(.horizontal, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
  
  private func eventColor(_ colorName: String) -> Color {
    switch colorName {
    case "green": return .green
    case "blue": return .blue
    case "red": return .red
    case "orange": return .orange
    case "gray": return .gray
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

// MARK: - Cost Summary View

private struct CostSummaryView: View {
  let costs: CostSummary
  
  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 16) {
        // Time periods
        VStack(alignment: .leading, spacing: 12) {
          CostPeriodRow(label: "Today", period: costs.today)
          Divider()
          CostPeriodRow(label: "This Week", period: costs.week)
          Divider()
          CostPeriodRow(label: "This Month", period: costs.month)
        }
        
        // By agent
        if !costs.byAgent.isEmpty {
          Divider()
          
          VStack(alignment: .leading, spacing: 8) {
            Text("By Agent")
              .font(.caption.bold())
              .foregroundStyle(.secondary)
            
            ForEach(costs.byAgent.sorted(by: { $0.tokensTotal > $1.tokensTotal })) { cost in
              HStack {
                Text(cost.type.capitalized)
                  .font(.caption)
                Spacer()
                Text("$\(cost.estimatedCost, specifier: "%.2f")")
                  .font(.caption.bold())
              }
            }
          }
        }
      }
    }
  }
}

private struct CostPeriodRow: View {
  let label: String
  let period: CostSummary.Period
  
  var body: some View {
    HStack {
      Text(label)
        .font(.subheadline.bold())
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text("$\(period.estimatedCost, specifier: "%.2f")")
          .font(.subheadline.bold())
          .foregroundStyle(.green)
        Text("\(formattedTokens(period.tokensUsed)) tokens")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }
  
  private func formattedTokens(_ count: Int) -> String {
    if count >= 1_000_000 {
      return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
      return String(format: "%.1fK", Double(count) / 1_000)
    } else {
      return "\(count)"
    }
  }
}

// MARK: - Helper Components

private struct CardContainer<Content: View>: View {
  let compact: Bool
  let content: Content
  
  init(compact: Bool = false, @ViewBuilder content: () -> Content) {
    self.compact = compact
    self.content = content()
  }
  
  var body: some View {
    content
      .padding(compact ? 12 : 16)
      .background(Color(NSColor.controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.primary.opacity(0.1), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
  }
}

private struct StatusDot: View {
  let status: String
  
  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 12, height: 12)
      .overlay(
        Circle()
          .stroke(color.opacity(0.3), lineWidth: 2)
      )
  }
  
  private var color: Color {
    switch status.lowercased() {
    case "healthy", "up", "running": return .green
    case "degraded", "warning": return .orange
    case "down", "error", "stopped": return .red
    default: return .gray
    }
  }
}

private struct HealthDot: View {
  let health: String
  
  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 8, height: 8)
  }
  
  private var color: Color {
    switch health.lowercased() {
    case "healthy": return .green
    case "warning": return .orange
    case "error": return .red
    default: return .gray
    }
  }
}

private struct StateBadge: View {
  let state: String
  
  var body: some View {
    Text(state.capitalized)
      .font(.caption.bold())
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.2))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }
  
  private var color: Color {
    switch state.lowercased() {
    case "running": return .green
    case "paused": return .orange
    case "stopped": return .red
    default: return .gray
    }
  }
}

private struct StatRow: View {
  let label: String
  let value: String
  
  var body: some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.caption.bold())
    }
  }
}

// MARK: - Software Updates Section

private struct UpdatesSection: View {
  let apiService: APIService
  @State private var updateCheck: UpdateCheckResponse?
  @State private var isChecking = false
  @State private var pullingRepo: String?
  @State private var pullResult: UpdatePullResponse?
  @State private var selfUpdateResult: SelfUpdateResponse?
  @State private var isSelfUpdating = false
  @State private var error: String?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
          .font(.title3)
          .foregroundStyle(.blue)
        Text("Software Updates")
          .font(.title3.bold())
        
        Spacer()
        
        if isChecking {
          ProgressView()
            .scaleEffect(0.7)
        }
        
        Button {
          Task { await checkUpdates() }
        } label: {
          Label("Check Now", systemImage: "arrow.clockwise")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .disabled(isChecking)
      }
      .padding(.horizontal, 4)
      
      if let error = error {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
          Text(error)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      
      if let check = updateCheck {
        if check.hasUpdates {
          // Show banner
          HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
              .foregroundStyle(.blue)
            Text("Updates available")
              .font(.subheadline.bold())
            Spacer()
            Text("\(check.repos.filter(\.hasUpdate).count) repo(s)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(12)
          .background(Color.blue.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        
        LazyVGrid(columns: [
          GridItem(.flexible()),
          GridItem(.flexible()),
          GridItem(.flexible())
        ], spacing: 12) {
          ForEach(check.repos) { repo in
            if repo.name == "lobs-mission-control" {
              RepoCard(
                repo: repo,
                isPulling: isSelfUpdating,
                pullLabel: isSelfUpdating ? "Updating..." : "Update & Relaunch",
                onPull: { Task { await selfUpdate() } }
              )
            } else {
              RepoCard(
                repo: repo,
                isPulling: pullingRepo == repo.name,
                onPull: { Task { await pullRepo(repo.name) } }
              )
            }
          }
        }
        
        if let result = selfUpdateResult {
          SelfUpdateResultBanner(result: result, onRelaunch: relaunchApp)
        }
        
        if let result = pullResult {
          PullResultBanner(result: result)
        }
      } else if !isChecking {
        CardContainer {
          HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
              .font(.title2)
              .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
              Text("No update check yet")
                .font(.subheadline)
              Text("Click \"Check Now\" to scan for updates")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
          }
          .padding(.vertical, 8)
        }
      }
    }
    .onAppear {
      Task { await checkUpdates() }
    }
  }
  
  private func checkUpdates() async {
    isChecking = true
    error = nil
    defer { isChecking = false }
    
    do {
      updateCheck = try await apiService.checkForUpdates()
    } catch {
      self.error = "Failed to check updates: \(error.localizedDescription)"
    }
  }
  
  private func selfUpdate() async {
    isSelfUpdating = true
    selfUpdateResult = nil
    defer { isSelfUpdating = false }
    
    do {
      let result = try await apiService.selfUpdateMissionControl()
      selfUpdateResult = result
      if result.success {
        // Refresh update check
        try? await Task.sleep(nanoseconds: 500_000_000)
        updateCheck = try await apiService.checkForUpdates()
      }
    } catch {
      selfUpdateResult = SelfUpdateResponse(
        success: false, pullOutput: error.localizedDescription,
        buildOutput: "", newCommit: nil, binaryPath: nil
      )
    }
  }
  
  private func relaunchApp() {
    guard let binaryPath = selfUpdateResult?.binaryPath else { return }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "sleep 1 && open \"\(binaryPath)\""]
    try? process.run()
    NSApplication.shared.terminate(nil)
  }
  
  private func pullRepo(_ name: String) async {
    pullingRepo = name
    pullResult = nil
    defer { pullingRepo = nil }
    
    do {
      pullResult = try await apiService.pullUpdate(repo: name)
      // Refresh the update check after pulling
      if pullResult?.success == true {
        try? await Task.sleep(nanoseconds: 500_000_000)
        updateCheck = try await apiService.checkForUpdates()
      }
    } catch {
      pullResult = UpdatePullResponse(
        repo: name, success: false,
        output: error.localizedDescription,
        newCommit: nil, needsRestart: false
      )
    }
  }
}

private struct RepoCard: View {
  let repo: RepoUpdateInfo
  let isPulling: Bool
  var pullLabel: String? = nil
  let onPull: () -> Void
  
  var body: some View {
    CardContainer {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: repoIcon)
            .font(.body)
            .foregroundStyle(repo.hasUpdate ? .blue : .green)
          Text(repo.name)
            .font(.subheadline.bold())
          Spacer()
          if repo.hasUpdate {
            Text("\(repo.behind) behind")
              .font(.caption2.bold())
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.blue.opacity(0.2))
              .foregroundStyle(.blue)
              .clipShape(Capsule())
          } else if repo.error == nil {
            Image(systemName: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.green)
          }
        }
        
        if let error = repo.error {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
        } else {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(repo.localCommit)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
              Text(repo.localMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            
            if repo.hasUpdate, let remoteMsg = repo.remoteMessage, let remoteCommit = repo.remoteCommit {
              HStack {
                Image(systemName: "arrow.down")
                  .font(.caption2)
                  .foregroundStyle(.blue)
                Text(remoteCommit)
                  .font(.system(.caption, design: .monospaced))
                  .foregroundStyle(.blue)
                Text(remoteMsg)
                  .font(.caption)
                  .foregroundStyle(.blue)
                  .lineLimit(1)
              }
            }
            
            Text("branch: \(repo.branch)")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          
          if repo.hasUpdate {
            Button {
              onPull()
            } label: {
              HStack {
                if isPulling {
                  ProgressView()
                    .scaleEffect(0.6)
                } else {
                  Image(systemName: "arrow.down.circle.fill")
                }
                Text(pullLabel ?? (isPulling ? "Pulling..." : "Pull Update"))
              }
              .font(.caption.bold())
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(Color.blue.opacity(0.2))
              .foregroundStyle(.blue)
              .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(isPulling)
          }
        }
      }
    }
  }
  
  private var repoIcon: String {
    switch repo.name {
    case "lobs-server": return "server.rack"
    case "lobs-mission-control": return "desktopcomputer"
    case "lobs-mobile": return "iphone"
    default: return "folder.fill"
    }
  }
}

private struct SelfUpdateResultBanner: View {
  let result: SelfUpdateResponse
  let onRelaunch: () -> Void
  
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundStyle(result.success ? .green : .red)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(result.success ? "Mission Control updated" : "Update failed")
          .font(.caption.bold())
        
        if let newCommit = result.newCommit {
          Text("Now at \(newCommit)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        
        if !result.success {
          Text(result.buildOutput.isEmpty ? result.pullOutput : result.buildOutput)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
      }
      
      Spacer()
      
      if result.success {
        Button {
          onRelaunch()
        } label: {
          Label("Relaunch", systemImage: "arrow.clockwise.circle.fill")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.2))
            .foregroundStyle(.green)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(12)
    .background((result.success ? Color.green : Color.red).opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

private struct PullResultBanner: View {
  let result: UpdatePullResponse
  
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundStyle(result.success ? .green : .red)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(result.success ? "Updated \(result.repo)" : "Failed to update \(result.repo)")
          .font(.caption.bold())
        
        if let newCommit = result.newCommit {
          Text("Now at \(newCommit)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        
        if result.needsRestart {
          Text("⚠️ Server restart required to apply changes")
            .font(.caption2)
            .foregroundStyle(.orange)
        }
        
        if !result.success {
          Text(result.output)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
      }
      
      Spacer()
    }
    .padding(12)
    .background((result.success ? Color.green : Color.red).opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

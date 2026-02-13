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
                onPause: { Task { await viewModel.pauseOrchestrator() } },
                onResume: { Task { await viewModel.resumeOrchestrator() } }
              )
              WorkersCard(workers: viewModel.overview?.workers)
            }
            
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
            if let uptime = server.uptime {
              StatRow(label: "Uptime", value: formatUptime(uptime))
            }
            if let version = server.version {
              StatRow(label: "Version", value: version)
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
  
  private func formatUptime(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds / 3600)
    let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
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
          if let state = orchestrator?.state {
            StateBadge(state: state)
          }
        }
        
        if let orchestrator = orchestrator {
          VStack(alignment: .leading, spacing: 8) {
            if let uptime = orchestrator.uptime {
              StatRow(label: "Uptime", value: formatUptime(uptime))
            }
            
            HStack(spacing: 8) {
              if orchestrator.state == "running" {
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
              } else if orchestrator.state == "paused" {
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
  
  private func formatUptime(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds / 3600)
    let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
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
            Text("\(workers.activeCount)")
              .font(.title2.bold())
              .foregroundStyle(.green)
          }
        }
        
        if let workers = workers {
          VStack(alignment: .leading, spacing: 6) {
            StatRow(label: "Active", value: "\(workers.activeCount)")
            StatRow(label: "Completed", value: "\(workers.completedCount)")
            StatRow(label: "Failed", value: "\(workers.failedCount)")
          }
          
          if !workers.activeWorkers.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
              Text("Active Workers")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
              ForEach(workers.activeWorkers) { worker in
                HStack(spacing: 6) {
                  Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                  Text(worker.agentType)
                    .font(.caption)
                  if let title = worker.taskTitle {
                    Text("→")
                      .font(.caption)
                      .foregroundStyle(.tertiary)
                    Text(title)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
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
}

// MARK: - Agent Card

private struct AgentCard: View {
  let agent: SystemOverview.AgentStatusSummary
  
  var body: some View {
    CardContainer(compact: true) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: agentIcon(agent.agentType))
            .font(.body)
            .foregroundStyle(agentColor(agent.agentType))
          Text(agent.agentType.capitalized)
            .font(.subheadline.bold())
          Spacer()
          if let health = agent.health {
            HealthDot(health: health)
          }
        }
        
        VStack(alignment: .leading, spacing: 4) {
          if let lastActive = agent.lastActive {
            Text("Last active \(timeAgoString(lastActive))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          } else {
            Text("Never active")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          
          if let activeCount = agent.activeTaskCount, activeCount > 0 {
            Text("\(activeCount) active \(activeCount == 1 ? "task" : "tasks")")
              .font(.caption2)
              .foregroundStyle(.blue)
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
            
            ForEach(costs.byAgent.sorted(by: { $0.value.tokensUsed > $1.value.tokensUsed }), id: \.key) { agent, cost in
              HStack {
                Text(agent.capitalized)
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

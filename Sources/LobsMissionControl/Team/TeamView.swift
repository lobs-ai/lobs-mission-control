import SwiftUI

struct TeamView: View {
  @StateObject private var viewModel: TeamViewModel
  @Environment(\.dismiss) private var dismiss
  
  init(apiService: APIService) {
    _viewModel = StateObject(wrappedValue: TeamViewModel(apiService: apiService))
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        Color(NSColor.windowBackgroundColor)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            // Overall Team Status Header
            OverallTeamStatusView(viewModel: viewModel)
            
            // Agent Cards Grid
            LazyVGrid(columns: [
              GridItem(.flexible()),
              GridItem(.flexible())
            ], spacing: 16) {
              ForEach(viewModel.sortedAgents) { agent in
                AgentCardView(agent: agent)
              }
            }
            
            // Worker History
            if !viewModel.recentWorkerRuns.isEmpty {
              WorkerHistoryView(runs: viewModel.recentWorkerRuns)
            }
          }
          .padding(24)
        }
        
        if viewModel.isLoading && viewModel.agentStatuses.isEmpty {
          ProgressView("Loading team data...")
        }
      }
      .navigationTitle("Team")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .primaryAction) {
          Button {
            Task {
              await viewModel.refresh()
            }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .disabled(viewModel.isLoading)
        }
      }
      .onAppear {
        viewModel.startRefreshing()
      }
      .onDisappear {
        viewModel.stopRefreshing()
      }
    }
    .frame(minWidth: 900, minHeight: 700)
  }
}

// MARK: - Overall Team Status

private struct OverallTeamStatusView: View {
  @ObservedObject var viewModel: TeamViewModel
  
  var body: some View {
    HStack(spacing: 20) {
      TeamStatCard(
        icon: "person.3.fill",
        title: "Active Agents",
        value: "\(viewModel.activeAgentsCount)",
        subtitle: "working now",
        color: .blue
      )
      
      TeamStatCard(
        icon: "checkmark.circle.fill",
        title: "Tasks Today",
        value: "\(viewModel.totalTasksCompletedToday)",
        subtitle: "completed",
        color: .green
      )
      
      TeamStatCard(
        icon: "server.rack",
        title: "Active Workers",
        value: "\(viewModel.activeWorkersCount)",
        subtitle: viewModel.activeWorkersCount == 1 ? "running" : "idle",
        color: viewModel.activeWorkersCount > 0 ? .purple : .secondary
      )
    }
  }
}

// MARK: - Team Stat Card

private struct TeamStatCard: View {
  let icon: String
  let title: String
  let value: String
  let subtitle: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.title)
        .foregroundStyle(color)
        .frame(width: 44, height: 44)
        .background(color.opacity(0.1))
        .cornerRadius(10)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(value)
            .font(.system(size: 24, weight: .bold, design: .rounded))
          
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      
      Spacer()
    }
    .padding(16)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(12)
  }
}

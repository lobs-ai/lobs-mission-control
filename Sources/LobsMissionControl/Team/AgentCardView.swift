import SwiftUI

struct AgentCardView: View {
  let agent: AgentStatus
  @State private var isExpanded: Bool = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header: Emoji + Name + Status Badge
      HStack(alignment: .top, spacing: 10) {
        Text(agent.emoji)
          .font(.system(size: 32))
        
        VStack(alignment: .leading, spacing: 4) {
          Text(agent.displayName)
            .font(.headline)
          
          StatusBadge(status: agent.status)
        }
        
        Spacer()
        
        HealthIndicator(agent: agent)
      }
      
      // Current Activity
      if let activity = agent.activity, !activity.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Current Activity")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
          
          Text(activity)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .lineLimit(2)
        }
        .padding(.vertical, 6)
      }
      
      // Current Task
      if let taskId = agent.currentTaskId {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.blue)
          
          VStack(alignment: .leading, spacing: 2) {
            Text("Working on task")
              .font(.caption2)
              .foregroundStyle(.secondary)
            
            Text(taskId)
              .font(.caption)
              .foregroundStyle(.primary)
              .lineLimit(1)
          }
        }
      }
      
      Divider()
        .padding(.vertical, 4)
      
      // Stats Section
      VStack(alignment: .leading, spacing: 8) {
        if let stats = agent.stats {
          HStack(spacing: 16) {
            StatItem(
              label: "Completed",
              value: "\(stats.tasksCompleted ?? 0)"
            )
            
            StatItem(
              label: "Failed",
              value: "\(stats.tasksFailed ?? 0)"
            )
            
            if let avgDuration = stats.avgDurationSeconds {
              StatItem(
                label: "Avg Duration",
                value: formatDuration(avgDuration)
              )
            }
          }
        }
        
        // Last Completed
        if let lastCompletedAt = agent.lastCompletedAt {
          HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
              .font(.caption2)
              .foregroundStyle(.green)
            
            Text("Last completed \(timeAgo(lastCompletedAt))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        } else {
          HStack(spacing: 6) {
            Image(systemName: "moon.zzz")
              .font(.caption2)
              .foregroundStyle(.secondary)
            
            Text("No tasks completed yet")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(16)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(borderColor, lineWidth: 1)
    )
    .onTapGesture {
      withAnimation {
        isExpanded.toggle()
      }
    }
    .popover(isPresented: $isExpanded) {
      AgentDetailPopover(agent: agent)
    }
  }
  
  private var borderColor: Color {
    switch agent.status {
    case "working": return .blue.opacity(0.3)
    case "thinking": return .purple.opacity(0.3)
    case "error": return .red.opacity(0.3)
    default: return Color(NSColor.separatorColor)
    }
  }
  
  private func formatDuration(_ seconds: Int) -> String {
    if seconds < 60 {
      return "\(seconds)s"
    } else if seconds < 3600 {
      return "\(seconds / 60)m"
    } else {
      let hours = seconds / 3600
      let mins = (seconds % 3600) / 60
      return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
  }
  
  private func timeAgo(_ date: Date) -> String {
    let now = Date()
    let diff = now.timeIntervalSince(date)
    
    if diff < 60 {
      return "just now"
    } else if diff < 3600 {
      let mins = Int(diff / 60)
      return "\(mins)m ago"
    } else if diff < 86400 {
      let hours = Int(diff / 3600)
      return "\(hours)h ago"
    } else {
      let days = Int(diff / 86400)
      return "\(days)d ago"
    }
  }
}

// MARK: - Status Badge

private struct StatusBadge: View {
  let status: String
  
  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(statusColor)
        .frame(width: 6, height: 6)
      
      Text(statusText)
        .font(.caption)
        .foregroundStyle(statusColor)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(statusColor.opacity(0.1))
    .cornerRadius(8)
  }
  
  private var statusText: String {
    status.capitalized
  }
  
  private var statusColor: Color {
    switch status {
    case "working": return .blue
    case "thinking": return .purple
    case "error": return .red
    default: return .secondary
    }
  }
}

// MARK: - Health Indicator

private struct HealthIndicator: View {
  let agent: AgentStatus
  
  var body: some View {
    Circle()
      .fill(healthColor)
      .frame(width: 12, height: 12)
      .help(healthTooltip)
  }
  
  private var healthColor: Color {
    if agent.status == "error" {
      return .red
    }
    
    guard let lastActive = agent.lastActiveAt else {
      return .gray
    }
    
    let now = Date()
    let diff = now.timeIntervalSince(lastActive)
    
    // Green if active within last hour
    if diff < 3600 {
      return .green
    } else if diff < 86400 {
      // Yellow if within last 24 hours
      return .yellow
    } else {
      // Red if older than 24 hours
      return .red
    }
  }
  
  private var healthTooltip: String {
    if agent.status == "error" {
      return "Agent error"
    }
    
    guard let lastActive = agent.lastActiveAt else {
      return "Never active"
    }
    
    let now = Date()
    let diff = now.timeIntervalSince(lastActive)
    
    if diff < 3600 {
      return "Healthy - active recently"
    } else if diff < 86400 {
      return "Inactive for \(Int(diff / 3600)) hours"
    } else {
      return "Inactive for \(Int(diff / 86400)) days"
    }
  }
}

// MARK: - Stat Item

private struct StatItem: View {
  let label: String
  let value: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(.body, design: .rounded).weight(.semibold))
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Agent Detail Popover

private struct AgentDetailPopover: View {
  let agent: AgentStatus
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      HStack(spacing: 12) {
        Text(agent.emoji)
          .font(.system(size: 48))
        
        VStack(alignment: .leading, spacing: 4) {
          Text(agent.displayName)
            .font(.title2)
            .fontWeight(.bold)
          
          HStack(spacing: 6) {
            Circle()
              .fill(statusColor(agent.status))
              .frame(width: 8, height: 8)
            Text(agent.status.capitalized)
              .font(.subheadline)
              .foregroundStyle(statusColor(agent.status))
          }
        }
        
        Spacer()
      }
      
      Divider()
      
      // Current Activity Section
      if let activity = agent.activity, !activity.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Label("Current Activity", systemImage: "bolt.fill")
            .font(.headline)
            .foregroundStyle(.blue)
          
          Text(activity)
            .font(.body)
            .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(8)
      }
      
      // Current Task
      if let taskId = agent.currentTaskId {
        VStack(alignment: .leading, spacing: 6) {
          Label("Current Task", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(.green)
          
          Text(taskId)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.secondary)
          
          if let projectId = agent.currentProjectId {
            HStack(spacing: 4) {
              Text("Project:")
                .font(.caption)
                .foregroundStyle(.secondary)
              Text(projectId)
                .font(.caption)
                .fontWeight(.medium)
            }
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.06))
        .cornerRadius(8)
      }
      
      // Statistics
      if let stats = agent.stats {
        VStack(alignment: .leading, spacing: 12) {
          Text("Performance")
            .font(.headline)
          
          Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            GridRow {
              Label("Completed", systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text("\(stats.tasksCompleted ?? 0)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
              Spacer()
            }
            
            GridRow {
              Label("Failed", systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text("\(stats.tasksFailed ?? 0)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(stats.tasksFailed ?? 0 > 0 ? .red : .primary)
              Spacer()
            }
            
            if let avgDuration = stats.avgDurationSeconds {
              GridRow {
                Label("Avg Duration", systemImage: "clock")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                Text(formatDuration(avgDuration))
                  .font(.system(.title3, design: .rounded).weight(.semibold))
                Spacer()
              }
            }
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
      }
      
      // Recent Activity
      if let lastCompletedAt = agent.lastCompletedAt {
        HStack(spacing: 6) {
          Image(systemName: "clock.arrow.circlepath")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Last completed \(timeAgo(lastCompletedAt))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      
      if let lastActiveAt = agent.lastActiveAt {
        HStack(spacing: 6) {
          Image(systemName: "clock")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("Last active \(timeAgo(lastActiveAt))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(20)
    .frame(width: 450)
  }
  
  private func statusColor(_ status: String) -> Color {
    switch status {
    case "working": return .blue
    case "thinking": return .purple
    case "error": return .red
    default: return .secondary
    }
  }
  
  private func formatDuration(_ seconds: Int) -> String {
    if seconds < 60 {
      return "\(seconds)s"
    } else if seconds < 3600 {
      return "\(seconds / 60)m"
    } else {
      let hours = seconds / 3600
      let mins = (seconds % 3600) / 60
      return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
  }
  
  private func timeAgo(_ date: Date) -> String {
    let now = Date()
    let diff = now.timeIntervalSince(date)
    
    if diff < 60 {
      return "just now"
    } else if diff < 3600 {
      let mins = Int(diff / 60)
      return "\(mins)m ago"
    } else if diff < 86400 {
      let hours = Int(diff / 3600)
      return "\(hours)h ago"
    } else {
      let days = Int(diff / 86400)
      return "\(days)d ago"
    }
  }
}

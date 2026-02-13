import SwiftUI

struct WorkerHistoryView: View {
  let runs: [WorkerHistoryRun]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recent Worker Runs")
        .font(.headline)
      
      if runs.isEmpty {
        Text("No worker runs yet")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.vertical, 20)
      } else {
        ScrollView {
          VStack(spacing: 8) {
            ForEach(runs) { run in
              WorkerRunRow(run: run)
            }
          }
        }
        .frame(maxHeight: 400)
      }
    }
    .padding(16)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(12)
  }
}

// MARK: - Worker Run Row

private struct WorkerRunRow: View {
  let run: WorkerHistoryRun
  
  var body: some View {
    HStack(spacing: 12) {
      // Success/Failure indicator
      Image(systemName: run.succeeded == true ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.title3)
        .foregroundStyle(run.succeeded == true ? .green : .red)
      
      VStack(alignment: .leading, spacing: 4) {
        // Agent type + task count
        HStack(spacing: 6) {
          let agentType = run.agentType
          Text(agentEmoji(agentType))
            .font(.caption)
          Text(agentType.capitalized)
            .font(.subheadline.weight(.medium))
          
          if let taskCount = run.tasksCompleted, taskCount > 0 {
            Text("•")
              .foregroundStyle(.secondary)
              .font(.caption)
            Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        
        // Duration + Time
        HStack(spacing: 6) {
          if let duration = runDuration {
            Text(duration)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          
          if let startedAt = run.startedAt {
            Text("•")
              .foregroundStyle(.secondary)
              .font(.caption2)
            Text(timeAgo(startedAt))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        
        // Failure reason if failed
        if run.succeeded == false, let reason = run.timeoutReason {
          Text(reason)
            .font(.caption2)
            .foregroundStyle(.red)
        }
      }
      
      Spacer()
      
      // Token usage
      VStack(alignment: .trailing, spacing: 2) {
        if let tokens = run.totalTokens {
          Text("\(formatNumber(tokens)) tokens")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        
        if let cost = run.totalCostUSD {
          Text(String(format: "$%.4f", cost))
            .font(.caption2.weight(.medium))
            .foregroundStyle(.orange)
        }
      }
    }
    .padding(10)
    .background(Color(NSColor.textBackgroundColor))
    .cornerRadius(8)
  }
  
  private var runDuration: String? {
    guard let startedAt = run.startedAt,
          let endedAt = run.endedAt else { return nil }
    
    let duration = endedAt.timeIntervalSince(startedAt)
    
    if duration < 60 {
      return "\(Int(duration))s"
    } else if duration < 3600 {
      let mins = Int(duration / 60)
      let secs = Int(duration.truncatingRemainder(dividingBy: 60))
      return secs > 0 ? "\(mins)m \(secs)s" : "\(mins)m"
    } else {
      let hours = Int(duration / 3600)
      let mins = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
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
  
  private func formatNumber(_ num: Int) -> String {
    if num >= 1_000_000 {
      return String(format: "%.1fM", Double(num) / 1_000_000)
    } else if num >= 1_000 {
      return String(format: "%.1fK", Double(num) / 1_000)
    } else {
      return "\(num)"
    }
  }
}

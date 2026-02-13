import SwiftUI

// MARK: - Row helpers (extracted from deleted OverviewView)

private struct OverviewTaskRow: View {
  let task: DashboardTask
  let projectName: String?
  var showTimestamp: Bool = false
  var onTap: (() -> Void)? = nil

  var body: some View {
    Button(action: { onTap?() }) {
      HStack(spacing: 10) {
        Image(systemName: "circle.fill")
          .font(.system(size: 6))
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 2) {
          Text(task.title).font(.body)
          if let proj = projectName {
            Text(proj).font(.caption).foregroundStyle(.secondary)
          }
        }
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct OverviewResearchRow: View {
  let request: ResearchRequest
  let projectName: String?
  var onTap: (() -> Void)? = nil

  var body: some View {
    Button(action: { onTap?() }) {
      HStack(spacing: 10) {
        Image(systemName: "circle.fill")
          .font(.system(size: 6))
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 2) {
          Text(request.prompt).font(.body).lineLimit(1)
          if let proj = projectName {
            Text(proj).font(.caption).foregroundStyle(.secondary)
          }
        }
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct WorkerStatusCard: View {
  let status: WorkerStatus
  var history: WorkerHistory? = nil
  var tasks: [DashboardTask] = []
  @State private var showHistory = false
  @State private var showLiveDetails = false
  @State private var showUsageDetail = false
  @State private var selectedUsagePeriod: UsagePeriod = .today
  
  /// Extract task ID from filename (e.g., "ABCD1234-5678-90AB-CDEF-1234567890AB.json" -> "ABCD1234-5678-90AB-CDEF-1234567890AB")
  private func taskIdFromFilename(_ filename: String) -> String? {
    guard filename.hasSuffix(".json") else { return nil }
    return String(filename.dropLast(5))
  }
  
  /// Look up task title from filename or raw task string
  private func resolveTaskDisplay(_ taskString: String?) -> String? {
    guard let taskString = taskString else { return nil }
    
    // If it starts with "research:" or doesn't look like a filename, return as-is
    if taskString.lowercased().hasPrefix("research:") || !taskString.contains("-") || !taskString.hasSuffix(".json") {
      return taskString
    }
    
    // Try to extract task ID and look up the actual task
    guard let taskId = taskIdFromFilename(taskString),
          let task = tasks.first(where: { $0.id == taskId }) else {
      return taskString
    }
    
    return task.title
  }

  enum UsagePeriod: String, CaseIterable {
    case today = "Today"
    case thisWeek = "Week"
    case thisMonth = "Month"
    case allTime = "All"

    func includes(_ date: Date) -> Bool {
      let cal = Calendar.current
      switch self {
      case .today:
        return cal.isDateInToday(date)
      case .thisWeek:
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date.distantPast
        return date >= start
      case .thisMonth:
        let start = cal.dateInterval(of: .month, for: Date())?.start ?? Date.distantPast
        return date >= start
      case .allTime:
        return true
      }
    }
  }

  private var isActive: Bool {
    guard status.active else { return false }
    // Defensive: if the status file claims "active" but we also have an endedAt,
    // treat it as inactive.
    if status.endedAt != nil { return false }

    // If the last heartbeat is stale, treat the worker as not running.
    // This prevents the dashboard from showing a phantom worker when a worker
    // crashes or fails to write an end marker.
    let cutoff: TimeInterval = 10 * 60
    if let hb = status.lastHeartbeat {
      return Date().timeIntervalSince(hb) <= cutoff
    }
    if let started = status.startedAt {
      return Date().timeIntervalSince(started) <= cutoff
    }
    return false
  }

  private var isStale: Bool {
    status.active && !isActive
  }

  // isStale is derived from the effective active state (see above).

  private var runningDuration: String? {
    guard let started = status.startedAt else { return nil }
    let seconds = Date().timeIntervalSince(started)
    let minutes = Int(seconds / 60)
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    let mins = minutes % 60
    return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
  }

  var body: some View {
    HStack(spacing: 14) {
      // Status indicator
      ZStack {
        Circle()
          .fill(isStale ? Color.orange.opacity(0.15) : (isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.1)))
          .frame(width: 40, height: 40)
        Image(systemName: isStale ? "exclamationmark.triangle.fill" : (isActive ? "bolt.fill" : "moon.zzz.fill"))
          .font(.system(size: 18))
          .foregroundStyle(isStale ? .orange : (isActive ? .green : .secondary))
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text("Lobs Worker")
            .font(.callout)
            .fontWeight(.semibold)

          // Status pill
          Text(isStale ? "Stale" : (isActive ? "Active" : "Idle"))
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
              isStale
                ? Color.orange.opacity(0.15)
                : (isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
            )
            .foregroundStyle(
              isStale
                ? .orange
                : (isActive ? .green : .secondary)
            )
            .clipShape(Capsule())
        }

        if isActive {
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
              if let task = status.currentTask, let displayTask = resolveTaskDisplay(task) {
                let isResearch = task.lowercased().hasPrefix("research:")
                HStack(spacing: 4) {
                  Image(systemName: isResearch ? "magnifyingglass" : "hammer.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isResearch ? .purple : .secondary)
                  Text(displayTask)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }

              if let completed = status.tasksCompleted, completed > 0 {
                HStack(spacing: 4) {
                  Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                  Text("\(completed) done")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
              }

              if let duration = runningDuration {
                HStack(spacing: 4) {
                  Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                  Text(duration)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
              }

              if let heartbeat = status.lastHeartbeat {
                Text("· \(relativeTime(heartbeat))")
                  .font(.footnote)
                  .foregroundStyle(.tertiary)
              }
            }

            // Expandable live details
            if (status.currentProject != nil) || (status.taskLog?.isEmpty == false) || (status.inputTokens != nil) || (status.outputTokens != nil) {
              Button {
                withAnimation(.easeInOut(duration: 0.2)) { showLiveDetails.toggle() }
              } label: {
                HStack(spacing: 6) {
                  Image(systemName: showLiveDetails ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                  Text("Live details")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
              }
              .buttonStyle(.plain)

              if showLiveDetails {
                VStack(alignment: .leading, spacing: 6) {
                  if let p = status.currentProject, !p.isEmpty {
                    Text("Project: \(p)")
                      .font(.system(size: 11))
                      .foregroundStyle(.tertiary)
                  }
                  if let inTok = status.inputTokens, let outTok = status.outputTokens {
                    Text("Tokens: \(formatTokenCount(inTok + outTok))")
                      .font(.system(size: 11).monospacedDigit())
                      .foregroundStyle(.tertiary)
                  }
                  if let log = status.taskLog, !log.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                      Text("This run:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                      ForEach(Array(log.suffix(5).enumerated()), id: \.offset) { _, e in
                        let displayTask = resolveTaskDisplay(e.task) ?? e.task ?? "(task)"
                        Text("• \(displayTask)")
                          .font(.system(size: 11))
                          .foregroundStyle(.tertiary)
                          .lineLimit(1)
                      }
                    }
                  }
                }
                .padding(.top, 2)
              }
            }
          }
        } else {
          // Idle state: show completion summary if available
          HStack(spacing: 12) {
            if let completed = status.tasksCompleted, completed > 0 {
              HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 10))
                  .foregroundStyle(.green)
                Text("Completed \(completed) task\(completed == 1 ? "" : "s")")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }

            // Show session duration if we have start and end times
            if let started = status.startedAt, let ended = status.endedAt {
              let duration = ended.timeIntervalSince(started)
              let minutes = Int(duration / 60)
              HStack(spacing: 4) {
                Image(systemName: "clock")
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
                Text(minutes < 60
                  ? "in \(max(1, minutes))m"
                  : "in \(minutes / 60)h \(minutes % 60)m")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }

            if let heartbeat = status.lastHeartbeat {
              Text("· \(relativeTime(heartbeat))")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            }
          }
        }
      }

      Spacer()
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: Theme.cardRadius)
        .fill(Theme.cardBg)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.cardRadius)
        .stroke(isActive ? Color.green.opacity(0.2) : Theme.border, lineWidth: isActive ? 1.5 : 0.5)
    )

    // Per-project usage breakdown
    if let history = history, !history.runs.isEmpty {
      // Project breakdown removed (simplified token tracking)
    }

    // Recent runs history + usage summary
    if let history = history, !history.runs.isEmpty {
      let runsWithEnd = history.runs.filter { $0.endedAt != nil }
      let filteredRuns = runsWithEnd.filter { run in
        guard let ended = run.endedAt else { return false }
        return selectedUsagePeriod.includes(ended)
      }
      let periodTokens = filteredRuns.reduce(0) { total, run in
        let totalForRun = run.totalTokens ?? ((run.inputTokens ?? 0) + (run.outputTokens ?? 0))
        return total + totalForRun
      }
      let periodSpend = filteredRuns.reduce(0.0) { $0 + ($1.totalCostUSD ?? 0) }
      let avgTokens = filteredRuns.isEmpty ? 0 : Int(Double(periodTokens) / Double(filteredRuns.count))
      let avgSpend = filteredRuns.isEmpty ? 0.0 : (periodSpend / Double(filteredRuns.count))

      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 10) {
          Button {
            withAnimation(.easeInOut(duration: 0.2)) { showHistory.toggle() }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: showHistory ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
              Text("Recent Runs")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)

          HStack(spacing: 4) {
            ForEach(UsagePeriod.allCases, id: \.self) { p in
              Button {
                withAnimation(.easeInOut(duration: 0.15)) { selectedUsagePeriod = p }
              } label: {
                Text(p.rawValue)
                  .font(.system(size: 11, weight: selectedUsagePeriod == p ? .semibold : .regular))
                  .foregroundStyle(selectedUsagePeriod == p ? .primary : .secondary)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 4)
                  .background(selectedUsagePeriod == p ? Color.primary.opacity(0.1) : Color.clear)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }

          Spacer()

          if periodTokens > 0 {
            HStack(spacing: 10) {
              HStack(spacing: 4) {
                Image(systemName: "cpu")
                  .font(.system(size: 10))
                  .foregroundStyle(.purple.opacity(0.8))
                Text(formatTokenCount(periodTokens))
                  .font(.system(size: 11, weight: .medium).monospacedDigit())
                  .foregroundStyle(.secondary)
              }
              if periodSpend > 0 {
                Text("$\(periodSpend, specifier: "%.2f")")
                  .font(.system(size: 11, weight: .medium).monospacedDigit())
                  .foregroundStyle(.secondary)
              }
              Button("Details") { showUsageDetail = true }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
            }
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)

        if periodTokens > 0, filteredRuns.count > 0 {
          Text("Avg/run: \(formatTokenCount(avgTokens)) tok, $\(avgSpend, specifier: "%.2f")")
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }

        if showHistory {
          Divider().padding(.horizontal, 14)
          VStack(alignment: .leading, spacing: 6) {
            ForEach(history.runs.suffix(10).reversed()) { run in
              WorkerHistoryRow(run: run)
            }
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
        }
      }
      .background(
        RoundedRectangle(cornerRadius: Theme.cardRadius)
          .fill(Theme.cardBg)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.cardRadius)
          .stroke(Theme.border, lineWidth: 0.5)
      )
      .sheet(isPresented: $showUsageDetail) {
        WorkerUsageDetailSheet(
          history: history,
          period: selectedUsagePeriod,
          tasks: tasks
        )
        .frame(minWidth: 560, minHeight: 520)
      }
    }
  }
}

// MARK: - Worker Project Usage Breakdown
// Removed: simplified AI usage tracking to per-run totals only.

private struct WorkerHistoryRow: View {
  let run: WorkerHistoryRun
  @State private var expanded = false

  private var hasTaskDetails: Bool {
    // Show expand chevron if there's task log, commits, files, or compare URL
    if let log = run.taskLog, !log.isEmpty { return true }
    if let commits = run.commitSHAs, !commits.isEmpty { return true }
    if let files = run.filesModified, !files.isEmpty { return true }
    return false
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Main row (clickable if has task details)
      Button {
        if hasTaskDetails {
          withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
        }
      } label: {
        HStack(spacing: 10) {
          // Expand indicator
          if hasTaskDetails {
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
              .font(.system(size: 8, weight: .semibold))
              .foregroundStyle(.tertiary)
              .frame(width: 10)
          } else {
            Spacer().frame(width: 10)
          }

          // Tasks count
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 10))
              .foregroundStyle(run.tasksCompleted ?? 0 > 0 ? .green : .secondary)
            Text("\(run.tasksCompleted ?? 0)")
              .font(.footnote.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .frame(width: 36, alignment: .leading)

          // Duration
          if let started = run.startedAt, let ended = run.endedAt {
            let minutes = Int(ended.timeIntervalSince(started) / 60)
            HStack(spacing: 4) {
              Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
              Text(minutes < 60
                ? "\(max(1, minutes))m"
                : "\(minutes / 60)h \(minutes % 60)m")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .frame(width: 50, alignment: .leading)
          }

          // Timestamp
          if let ended = run.endedAt {
            Text(relativeTime(ended))
              .font(.footnote)
              .foregroundStyle(.tertiary)
          }

          // Tokens for the run
          if let inTok = run.inputTokens, let outTok = run.outputTokens, (inTok + outTok) > 0 {
            HStack(spacing: 3) {
              Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 9))
                .foregroundStyle(.purple.opacity(0.7))
              Text("\(formatTokenCount(inTok))/\(formatTokenCount(outTok))")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.purple.opacity(0.7))
            }
            .frame(width: 90, alignment: .leading)
            .help("Input/Output tokens")
          } else if let tokens = run.totalTokens, tokens > 0 {
            HStack(spacing: 2) {
              Image(systemName: "cpu")
                .font(.system(size: 9))
                .foregroundStyle(.purple.opacity(0.7))
              Text(formatTokenCount(tokens))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.purple.opacity(0.7))
            }
            .frame(width: 70, alignment: .leading)
          }

          // Cost (optional per-run total)
          if let cost = run.totalCostUSD, cost > 0 {
            HStack(spacing: 2) {
              Text("$\(cost, specifier: "%.2f")")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .frame(width: 60, alignment: .leading)
          }

          // Project tags from task log
          if let log = run.taskLog, !log.isEmpty {
            let projects = Array(Set(log.compactMap { $0.project })).sorted()
            if !projects.isEmpty {
              HStack(spacing: 3) {
                ForEach(projects.prefix(3), id: \.self) { proj in
                  Text(proj)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
                }
                if projects.count > 3 {
                  Text("+\(projects.count - 3)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }
              }
            }
          }

          if run.timeoutReason != nil {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 10))
              .foregroundStyle(.orange)
              .help("Session timed out")
          }

          Spacer()
        }
      }
      .buttonStyle(.plain)

      // Expanded task detail rows
      if expanded, let log = run.taskLog, !log.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(Array(log.enumerated()), id: \.offset) { _, entry in
            HStack(spacing: 8) {
              Spacer().frame(width: 20)
              Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

              Text(entry.task ?? "Unknown task")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

              Spacer()

              if let proj = entry.project {
                Text(proj)
                  .font(.system(size: 9, weight: .medium))
                  .padding(.horizontal, 4)
                  .padding(.vertical, 1)
                  .background(Color.accentColor.opacity(0.08))
                  .foregroundStyle(.tertiary)
                  .clipShape(Capsule())
              }

              // (Per-task token/cost fields removed; per-run totals only)

            }
            .padding(.vertical, 2)
          }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
      }

      // Audit details (commits, files, compare link)
      if expanded {
        VStack(alignment: .leading, spacing: 6) {
          // Commits pushed
          if let commits = run.commitSHAs, !commits.isEmpty {
            HStack(spacing: 8) {
              Spacer().frame(width: 20)
              Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9))
                .foregroundStyle(.purple)
              Text("Commits: \(commits.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

              // Show first few commit SHAs
              HStack(spacing: 4) {
                ForEach(commits.prefix(3), id: \.self) { sha in
                  Text(String(sha.prefix(7)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(Capsule())
                }
                if commits.count > 3 {
                  Text("+\(commits.count - 3)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }
              }
            }
            .padding(.vertical, 2)
          }

          // Files modified
          if let files = run.filesModified, !files.isEmpty {
            HStack(spacing: 8) {
              Spacer().frame(width: 20)
              Image(systemName: "doc.text")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
              Text("Files: \(files.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

              // Show first few files
              HStack(spacing: 4) {
                ForEach(files.prefix(3), id: \.self) { file in
                  Text(URL(fileURLWithPath: file).lastPathComponent)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(Capsule())
                }
                if files.count > 3 {
                  Text("+\(files.count - 3)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }
              }
            }
            .padding(.vertical, 2)
          }

      }
    }
  }
}
}


// MARK: - Token Count Formatter

private func formatTokenCount(_ tokens: Int) -> String {
  if tokens >= 1_000_000 {
    return String(format: "%.1fM", Double(tokens) / 1_000_000)
  } else if tokens >= 1_000 {
    return String(format: "%.0fK", Double(tokens) / 1_000)
  }
  return "\(tokens)"
}

// MARK: - Timeline / Gantt-lite

private struct TimelineSheetView: View {
  let tasks: [DashboardTask]
  let projects: [Project]

  @Environment(\.dismiss) private var dismiss

  @State private var selectedProjectId: String = "all"
  @State private var daysBack: Int = 14

  private var filteredTasks: [DashboardTask] {
    let now = Date()
    let cutoff = now.addingTimeInterval(TimeInterval(-daysBack) * 86400)
    return tasks.filter { t in
      let pid = t.projectId ?? "default"
      if selectedProjectId != "all" && pid != selectedProjectId { return false }
      // Include tasks that intersect the window.
      let end = (t.status == .completed ? (t.finishedAt ?? t.updatedAt) : now)
      return end >= cutoff
    }
    .sorted { a, b in
      let aEnd = (a.status == .completed ? (a.finishedAt ?? a.updatedAt) : Date())
      let bEnd = (b.status == .completed ? (b.finishedAt ?? b.updatedAt) : Date())
      if aEnd != bEnd { return aEnd > bEnd }
      return a.createdAt > b.createdAt
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Timeline")
          .font(.title2)
          .fontWeight(.bold)
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }

      HStack(spacing: 12) {
        Picker("Project", selection: $selectedProjectId) {
          Text("All").tag("all")
          ForEach(projects.filter { !($0.archived ?? false) }) { p in
            Text(p.title).tag(p.id)
          }
        }
        .pickerStyle(.menu)

        Picker("Range", selection: $daysBack) {
          Text("7d").tag(7)
          Text("14d").tag(14)
          Text("30d").tag(30)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)

        Spacer()

        Text("Showing \\(filteredTasks.count) tasks")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      // Explanation and legend
      VStack(alignment: .leading, spacing: 6) {
        Text("Each bar shows a task's lifespan — from creation to completion (or now if still open). Longer bars mean longer-lived tasks.")
          .font(.footnote)
          .foregroundStyle(.secondary)

        HStack(spacing: 16) {
          TimelineLegendItem(color: .green.opacity(0.8), label: "Completed")
          TimelineLegendItem(color: .orange.opacity(0.8), label: "Active")
          TimelineLegendItem(color: .red.opacity(0.8), label: "Blocked")
          TimelineLegendItem(color: .gray.opacity(0.6), label: "Other")
        }
      }

      TimelineChart(tasks: filteredTasks)
    }
    .padding(20)
  }
}

private struct TimelineChart: View {
  let tasks: [DashboardTask]

  private var domain: (min: Date, max: Date) {
    let now = Date()
    let starts = tasks.map { $0.createdAt }
    let ends = tasks.map { t in
      t.status == .completed ? (t.finishedAt ?? t.updatedAt) : now
    }
    let minD = (starts.min() ?? now)
    let maxD = (ends.max() ?? now)
    // Avoid zero-width domain
    if maxD <= minD {
      return (minD.addingTimeInterval(-86400), maxD.addingTimeInterval(86400))
    }
    return (minD, maxD)
  }

  var body: some View {
    GeometryReader { geo in
      let width = max(1, geo.size.width - 180)
      let minD = domain.min
      let maxD = domain.max
      let span = max(1, maxD.timeIntervalSince(minD))

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(tasks) { task in
            TimelineRow(task: task, minDate: minD, span: span, barWidth: width)
              .frame(height: 22)
          }
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
      }
    }
    .background(Theme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    .overlay(
      RoundedRectangle(cornerRadius: Theme.cardRadius)
        .stroke(Theme.border, lineWidth: 0.5)
    )
  }
}

private struct TimelineRow: View {
  let task: DashboardTask
  let minDate: Date
  let span: TimeInterval
  let barWidth: CGFloat

  private var endDate: Date {
    if task.status == .completed { return task.finishedAt ?? task.updatedAt }
    return Date()
  }

  private var barColor: Color {
    if task.status == .completed { return .green.opacity(0.8) }
    if task.workState == .blocked { return .red.opacity(0.8) }
    if task.status == .active { return .orange.opacity(0.8) }
    return .gray.opacity(0.6)
  }

  var body: some View {
    HStack(spacing: 10) {
      Text(task.title)
        .font(.footnote)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .frame(width: 170, alignment: .leading)

      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.secondary.opacity(0.08))
          .frame(height: 12)

        let startX = CGFloat(task.createdAt.timeIntervalSince(minDate) / span) * barWidth
        let endX = CGFloat(endDate.timeIntervalSince(minDate) / span) * barWidth
        let w = max(3, endX - startX)

        RoundedRectangle(cornerRadius: 6)
          .fill(barColor)
          .frame(width: w, height: 12)
          .offset(x: startX)
      }
      .frame(width: barWidth, height: 12)
    }
  }
}

private struct TimelineLegendItem: View {
  let color: Color
  let label: String

  var body: some View {
    HStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 3)
        .fill(color)
        .frame(width: 14, height: 8)
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Overview "View All" Sheets

private struct OverviewTaskListSheet: View {
  let title: String
  let subtitle: String?
  let tasks: [DashboardTask]
  @ObservedObject var vm: AppViewModel
  let showTimestamp: Bool
  let onTapTask: (DashboardTask) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.title3)
            .fontWeight(.bold)
          if let subtitle {
            Text(subtitle)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(20)

      Divider()

      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
            OverviewTaskRow(
              task: task,
              projectName: vm.projects.first(where: { $0.id == (task.projectId ?? "default") })?.title,
              showTimestamp: showTimestamp,
              onTap: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                  onTapTask(task)
                }
              }
            )
            if idx < tasks.count - 1 {
              Divider().padding(.leading, 32)
            }
          }
        }
        .padding(.vertical, 6)
      }
    }
    .background(Theme.boardBg)
  }
}

private struct OverviewResearchRequestListSheet: View {
  let title: String
  let requests: [ResearchRequest]
  let projects: [Project]
  let onSelectProject: (String) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.title3)
            .fontWeight(.bold)
          Text("\(requests.count) open")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(20)

      Divider()

      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Array(requests.enumerated()), id: \.element.id) { idx, req in
            OverviewResearchRow(
              request: req,
              projectName: projects.first(where: { $0.id == req.projectId })?.title,
              onTap: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                  onSelectProject(req.projectId)
                }
              }
            )
            if idx < requests.count - 1 {
              Divider().padding(.leading, 32)
            }
          }
        }
        .padding(.vertical, 6)
      }
    }
    .background(Theme.boardBg)
  }
}

// MARK: - Relative Time Helper

private func relativeTime(_ date: Date) -> String {
  let now = Date()
  let seconds = now.timeIntervalSince(date)
  if seconds < 0 { return "just now" } // future date — treat as now
  if seconds < 60 { return "just now" }
  let minutes = Int(seconds / 60)
  if minutes < 60 { return "\(minutes)m ago" }
  let hours = Int(seconds / 3600)
  if hours < 24 { return "\(hours)h ago" }
  let days = Int(seconds / 86400)
  if days < 30 { return "\(days)d ago" }
  let months = Int(seconds / 2_592_000)
  return "\(months)mo ago"
}

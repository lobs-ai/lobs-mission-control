import SwiftUI

struct WorkflowDetailView: View {
    let workflow: WorkflowDefinition
    let apiService: APIService

    @State private var selectedNode: WorkflowNode? = nil
    @State private var recentRuns: [WorkflowRun] = []
    @State private var selectedRun: WorkflowRun? = nil
    @State private var runTrace: WorkflowRunTrace? = nil
    @State private var isLoadingRuns = false
    @State private var selectedTab: DetailTab = .graph

    enum DetailTab: String, CaseIterable {
        case graph = "Graph"
        case runs = "Runs"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedTab {
            case .graph:
                graphAndDetail
            case .runs:
                runsView
            }
        }
        .task { await loadRuns() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(workflow.name)
                            .font(.title2.bold())

                        statusBadge
                    }

                    if let desc = workflow.description {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("v\(workflow.version)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)

                    Text("\(workflow.nodes.count) nodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let trigger = workflow.trigger {
                triggerInfo(trigger)
            }
        }
        .padding()
    }

    private var statusBadge: some View {
        Text(workflow.isActive ? "Active" : "Inactive")
            .font(.caption2.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(workflow.isActive ? Color.green : Color.gray)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func triggerInfo(_ trigger: WorkflowTrigger) -> some View {
        HStack(spacing: 6) {
            Image(systemName: triggerIcon(trigger))
                .foregroundColor(.secondary)
                .font(.caption)

            switch trigger.type {
            case "schedule":
                Text("Cron: \(trigger.cron ?? "?")")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                if let tz = trigger.timezone {
                    Text("(\(tz))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case "event":
                Text("Event: \(trigger.eventPattern ?? "?")")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            case "task_match":
                Text("Tasks: \(trigger.agentTypes?.joined(separator: ", ") ?? "?")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            default:
                Text("Manual trigger")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func triggerIcon(_ trigger: WorkflowTrigger) -> String {
        switch trigger.type {
        case "schedule": return "clock"
        case "event": return "bolt.fill"
        case "task_match": return "checkmark.circle"
        default: return "hand.tap"
        }
    }

    // MARK: - Graph + Detail Split

    private var graphAndDetail: some View {
        HSplitView {
            WorkflowGraphView(
                nodes: workflow.nodes,
                edges: workflow.edges,
                selectedNode: $selectedNode,
                runNodeStates: selectedRun?.nodeStates,
                currentRunNode: selectedRun?.currentNode
            )
            .frame(minWidth: 400)

            nodeDetailPanel
                .frame(minWidth: 260, idealWidth: 300)
        }
    }

    // MARK: - Node Detail Panel

    private var nodeDetailPanel: some View {
        VStack(spacing: 0) {
            if let node = selectedNode {
                ScrollView {
                    NodeDetailCard(node: node, runState: selectedRun?.nodeStates?[node.id])
                        .padding()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.title)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Click a node")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Select a node in the graph to see its configuration and failure policy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Runs

    private var runsView: some View {
        VStack(spacing: 0) {
            if isLoadingRuns {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if recentRuns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "play.slash")
                        .font(.title)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No runs yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(recentRuns, selection: $selectedRun) { run in
                    RunRow(run: run)
                        .tag(run)
                }
                .listStyle(.inset)
                .onChange(of: selectedRun) { run in
                    if let run = run {
                        Task { await loadTrace(run) }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadRuns() async {
        isLoadingRuns = true
        do {
            recentRuns = try await apiService.fetchWorkflowRuns(workflowId: workflow.id)
        } catch {
            recentRuns = []
        }
        isLoadingRuns = false
    }

    private func loadTrace(_ run: WorkflowRun) async {
        do {
            runTrace = try await apiService.fetchWorkflowRunTrace(runId: run.id)
        } catch {
            runTrace = nil
        }
    }
}

// MARK: - Run Row

private struct RunRow: View {
    let run: WorkflowRun

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(run.triggerType)
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(run.id.prefix(8))
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
                if let started = run.startedAt {
                    Text(started)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        let (icon, color) = runStatusInfo(run.status)
        Image(systemName: icon)
            .foregroundColor(color)
    }

    private func runStatusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "completed": return ("checkmark.circle.fill", .green)
        case "failed": return ("xmark.circle.fill", .red)
        case "running": return ("arrow.circlepath", .blue)
        case "cancelled": return ("minus.circle.fill", .orange)
        default: return ("clock", .gray)
        }
    }
}

// MARK: - Node Detail Card

struct NodeDetailCard: View {
    let node: WorkflowNode
    let runState: NodeState?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                nodeTypeIcon(node.type)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.id)
                        .font(.headline)
                    Text(node.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Run state (if available)
            if let state = runState {
                runStateSection(state)
                Divider()
            }

            // Config
            if let config = node.config, !config.isEmpty {
                configSection(config)
                Divider()
            }

            // On Success
            if let onSuccess = node.onSuccess {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.green)
                    Text("On Success →")
                        .font(.caption.weight(.medium))
                    Text(onSuccess)
                        .font(.caption.monospaced())
                        .foregroundColor(.green)
                }
            }

            // Failure Policy
            if let policy = node.onFailure {
                failurePolicySection(policy)
            }

            // Timeout
            if let timeout = node.timeoutSeconds {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text("Timeout: \(timeout)s")
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private func runStateSection(_ state: NodeState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Run State")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                let (icon, color) = nodeStatusInfo(state.status ?? "unknown")
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(state.status ?? "unknown")
                    .font(.subheadline.weight(.medium))

                if let attempts = state.attempts, attempts > 1 {
                    Text("(\(attempts) attempts)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let error = state.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(6)
            }
        }
    }

    @ViewBuilder
    private func configSection(_ config: [String: AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Configuration")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            ForEach(Array(config.keys.sorted()), id: \.self) { key in
                HStack(alignment: .top, spacing: 6) {
                    Text(key)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(width: 80, alignment: .trailing)

                    Text(config[key]?.stringValue ?? "null")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func failurePolicySection(_ policy: WorkflowFailurePolicy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Failure Policy")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            if let retry = policy.retry {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.blue)
                    Text("Retry: \(retry)×")
                        .font(.caption)
                }
            }

            if let fallback = policy.fallback {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.right")
                        .foregroundColor(.orange)
                    Text("Fallback → \(fallback)")
                        .font(.caption.monospaced())
                }
            }

            if let escalate = policy.escalateAfter {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Escalate after \(escalate) attempts")
                        .font(.caption)
                }
            }

            if let abortOn = policy.abortOn, !abortOn.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.octagon")
                        .foregroundColor(.red)
                    Text("Abort on: \(abortOn.joined(separator: ", "))")
                        .font(.caption)
                }
            }
        }
    }

    private func nodeStatusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "completed": return ("checkmark.circle.fill", .green)
        case "failed": return ("xmark.circle.fill", .red)
        case "running": return ("arrow.circlepath", .blue)
        case "pending": return ("clock", .gray)
        default: return ("questionmark.circle", .gray)
        }
    }

    private func nodeTypeIcon(_ type: String) -> some View {
        let (icon, color) = nodeTypeInfo(type)
        return Image(systemName: icon)
            .foregroundColor(color)
    }

    private func nodeTypeInfo(_ type: String) -> (String, Color) {
        switch type {
        case "spawn_agent": return ("person.crop.circle.badge.plus", .blue)
        case "send_to_session": return ("paperplane.fill", .cyan)
        case "tool_call": return ("terminal", .green)
        case "branch": return ("arrow.triangle.branch", .purple)
        case "gate": return ("hand.raised.fill", .orange)
        case "notify": return ("bell.fill", .yellow)
        case "cleanup": return ("trash", .gray)
        case "python_call": return ("chevron.left.forwardslash.chevron.right", .indigo)
        case "for_each": return ("arrow.3.trianglepath", .teal)
        case "sub_workflow": return ("square.stack.3d.down.right", .pink)
        case "reflect": return ("brain.head.profile", .mint)
        default: return ("questionmark.circle", .gray)
        }
    }
}

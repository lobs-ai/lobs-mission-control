import SwiftUI

struct WorkflowsView: View {
    let apiService: APIService

    @State private var workflows: [WorkflowDefinition] = []
    @State private var selectedWorkflow: WorkflowDefinition? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var filterActive: Bool = false

    private var filtered: [WorkflowDefinition] {
        if filterActive {
            return workflows.filter(\.isActive)
        }
        return workflows
    }

    private var systemWorkflows: [WorkflowDefinition] {
        filtered.filter { $0.metadata?.system == true || $0.metadata?.category == "system" }
    }

    private var taskWorkflows: [WorkflowDefinition] {
        filtered.filter { $0.metadata?.system != true && $0.metadata?.category != "system" }
    }

    var body: some View {
        HSplitView {
            workflowList
                .frame(minWidth: 280, idealWidth: 320)

            if let wf = selectedWorkflow {
                WorkflowDetailView(workflow: wf, apiService: apiService)
                    .id(wf.id + "-v\(wf.version)")
            } else {
                emptyState
            }
        }
        .task { await loadWorkflows() }
    }

    // MARK: - Sidebar List

    private var workflowList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Workflows")
                    .font(.title2.bold())
                Spacer()
                Toggle("Active Only", isOn: $filterActive)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if workflows.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Workflows")
                        .font(.headline)
                    Text("Workflows will appear when defined in the server.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List(selection: $selectedWorkflow) {
                    if !taskWorkflows.isEmpty {
                        Section("Task Workflows") {
                            ForEach(taskWorkflows) { wf in
                                WorkflowRow(workflow: wf)
                                    .tag(wf)
                            }
                        }
                    }
                    if !systemWorkflows.isEmpty {
                        Section("System Workflows") {
                            ForEach(systemWorkflows) { wf in
                                WorkflowRow(workflow: wf)
                                    .tag(wf)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Select a workflow")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Choose a workflow from the sidebar to view its nodes and execution graph.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private func loadWorkflows() async {
        isLoading = true
        errorMessage = nil
        do {
            workflows = try await apiService.fetchWorkflows(activeOnly: false)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Workflow Row

private struct WorkflowRow: View {
    let workflow: WorkflowDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(workflow.isActive ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)

                Text(workflow.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("v\(workflow.version)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Label("\(workflow.nodeCount)", systemImage: "circle.grid.3x3")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let trigger = workflow.trigger {
                    triggerBadge(trigger)
                }
            }

            if let desc = workflow.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func triggerBadge(_ trigger: WorkflowTrigger) -> some View {
        let (icon, label) = triggerInfo(trigger)
        Label(label, systemImage: icon)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(triggerColor(trigger))
            .clipShape(Capsule())
    }

    private func triggerInfo(_ trigger: WorkflowTrigger) -> (String, String) {
        switch trigger.type {
        case "schedule":
            return ("clock", trigger.cron ?? "schedule")
        case "event":
            return ("bolt.fill", trigger.eventPattern ?? "event")
        case "task_match":
            let agents = trigger.agentTypes?.joined(separator: ", ") ?? "task"
            return ("checkmark.circle", agents)
        default:
            return ("questionmark.circle", trigger.type ?? "manual")
        }
    }

    private func triggerColor(_ trigger: WorkflowTrigger) -> Color {
        switch trigger.type {
        case "schedule": return .blue
        case "event": return .purple
        case "task_match": return .orange
        default: return .gray
        }
    }
}

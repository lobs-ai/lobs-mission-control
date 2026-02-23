import SwiftUI

struct SweepHistoryView: View {
    @ObservedObject var vm: AppViewModel
    
    @State private var sweeps: [SweepCycle] = []
    @State private var selectedSweep: SweepCycle? = nil
    @State private var sweepDetails: SweepDetails? = nil
    @State private var isLoading: Bool = false
    @State private var isLoadingDetails: Bool = false
    @State private var searchText: String = ""
    @State private var expandedSweepIds: Set<String> = []
    
    private var filteredSweeps: [SweepCycle] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return sweeps
        }
        
        return sweeps.filter { sweep in
            sweep.summary?.lowercased().contains(q) == true ||
            sweep.sweepType.lowercased().contains(q) ||
            sweep.status.lowercased().contains(q)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.3.trianglepath")
                        .font(.title2)
                        .foregroundStyle(.linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    Text("Sweep History")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                Spacer()
                
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    TextField("Search sweeps…", text: $searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 160)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Refresh
                Button {
                    Task { await loadSweeps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Refresh sweeps")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Content
            if filteredSweeps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("No sweep history")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "Sweep cycles will appear here" : "No sweeps match your search")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSweeps) { sweep in
                            SweepCard(
                                sweep: sweep,
                                isExpanded: expandedSweepIds.contains(sweep.id),
                                sweepDetails: selectedSweep?.id == sweep.id ? sweepDetails : nil,
                                isLoadingDetails: isLoadingDetails && selectedSweep?.id == sweep.id,
                                onToggleExpand: {
                                    toggleExpand(sweep)
                                },
                                onOpenTask: { taskId in
                                    if let task = vm.tasks.first(where: { $0.id == taskId }) {
                                        vm.selectTask(task)
                                    }
                                }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task { await loadSweeps() }
        }
    }
    
    private func loadSweeps() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            sweeps = try await vm.apiService?.fetchSweeps(limit: 100) ?? []
        } catch {
            print("Failed to load sweeps: \(error)")
        }
    }
    
    private func toggleExpand(_ sweep: SweepCycle) {
        if expandedSweepIds.contains(sweep.id) {
            expandedSweepIds.remove(sweep.id)
            if selectedSweep?.id == sweep.id {
                selectedSweep = nil
                sweepDetails = nil
            }
        } else {
            expandedSweepIds.insert(sweep.id)
            selectedSweep = sweep
            Task { await loadSweepDetails(sweep.id) }
        }
    }
    
    private func loadSweepDetails(_ sweepId: String) async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        
        do {
            sweepDetails = try await vm.apiService?.fetchSweepDetails(sweepId: sweepId)
        } catch {
            print("Failed to load sweep details: \(error)")
        }
    }
}

// MARK: - Sweep Card

private struct SweepCard: View {
    let sweep: SweepCycle
    let isExpanded: Bool
    let sweepDetails: SweepDetails?
    let isLoadingDetails: Bool
    let onToggleExpand: () -> Void
    let onOpenTask: (String) -> Void
    
    @State private var isHovering = false
    
    private var statusColor: Color {
        switch sweep.status.lowercased() {
        case "completed": return .green
        case "pending", "in_progress": return .orange
        case "failed": return .red
        default: return .secondary
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Sweep header (always visible)
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(sweep.displayDate)
                                .font(.headline)
                            
                            // Status badge
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                                Text(sweep.status.capitalized)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.12))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())
                            
                            // Type badge
                            Text(sweep.sweepType.capitalized)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.12))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                        
                        if let summary = sweep.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(isExpanded ? nil : 2)
                        }
                    }
                    
                    Spacer()
                    
                    // Stats
                    HStack(spacing: 16) {
                        StatBadge(
                            label: "Total",
                            value: sweep.totalProposed,
                            color: .blue
                        )
                        
                        if sweep.approvedCount > 0 {
                            StatBadge(
                                label: "Approved",
                                value: sweep.approvedCount,
                                color: .green
                            )
                        }
                        
                        if sweep.rejectedCount > 0 {
                            StatBadge(
                                label: "Rejected",
                                value: sweep.rejectedCount,
                                color: .red
                            )
                        }
                        
                        if sweep.deferredCount > 0 {
                            StatBadge(
                                label: "Deferred",
                                value: sweep.deferredCount,
                                color: .orange
                            )
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHovering ? Color.secondary.opacity(0.05) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in isHovering = h }
            
            // Expanded content (decisions)
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                
                if isLoadingDetails {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading decisions…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                } else if let details = sweepDetails {
                    if details.decisions.isEmpty {
                        Text("No decisions in this sweep")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(20)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(details.decisions) { decision in
                                DecisionRow(
                                    decision: decision,
                                    onOpenTask: onOpenTask
                                )
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Decision Row

private struct DecisionRow: View {
    let decision: SweepDecision
    let onOpenTask: (String) -> Void
    
    @State private var isHovering = false
    
    private var decisionColor: Color {
        switch decision.decision.lowercased() {
        case "approved": return .green
        case "rejected": return .red
        case "deferred": return .blue
        default: return .secondary
        }
    }
    
    private var riskColor: Color {
        switch decision.riskTier.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .green
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Decision badge
            VStack(spacing: 4) {
                Circle()
                    .fill(decisionColor)
                    .frame(width: 12, height: 12)
                
                Text(decision.decision.prefix(3).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(decisionColor)
            }
            .frame(width: 50)
            
            // Initiative info
            VStack(alignment: .leading, spacing: 4) {
                Text(decision.initiativeTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                
                if let description = decision.initiativeDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    // Category
                    HStack(spacing: 3) {
                        Image(systemName: "tag")
                            .font(.system(size: 9))
                        Text(decision.initiativeCategory)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                    
                    // Risk tier
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 9))
                        Text(decision.riskTier)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(riskColor.opacity(0.15))
                    .foregroundStyle(riskColor)
                    .clipShape(Capsule())
                    
                    // Decided by
                    HStack(spacing: 3) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 9))
                        Text(decision.decidedBy)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                }
                
                if let rationale = decision.rationale, !rationale.isEmpty {
                    Text("Rationale: \(rationale)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Task link (if approved and created)
            if let taskId = decision.taskId {
                Button {
                    onOpenTask(taskId)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Task")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Open linked task: \(taskId)")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.04) : Color.clear)
        )
        .onHover { h in isHovering = h }
    }
}

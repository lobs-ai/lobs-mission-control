import SwiftUI

// MARK: - Intelligence View

struct IntelligenceView: View {
  @ObservedObject var vm: AppViewModel
  
  @State private var selectedTab: IntelligenceTab = .initiatives
  @State private var initiatives: [InitiativeReviewItem] = []
  @State private var selectedInitiative: InitiativeReviewItem? = nil
  @State private var searchText: String = ""
  @State private var statusFilter: String = "all"
  @State private var categoryFilter: String = "all"
  @State private var agentFilter: String = "all"
  @State private var sortOrder: SortOrder = .dateDesc
  @State private var isLoading: Bool = false
  @State private var selectedIds: Set<String> = []
  @State private var showBatchActions: Bool = false
  
  // Reflections state
  @State private var reflections: [ReflectionCycle] = []
  @State private var expandedReflectionId: String? = nil
  @State private var intelligenceSummary: IntelligenceSummary? = nil
  @State private var agentTypeFilter: String = "all"
  
  enum IntelligenceTab: String, CaseIterable {
    case initiatives = "Initiatives"
    case reflections = "Reflections"
    case sweeps = "Sweep History"
  }
  
  enum SortOrder: String, CaseIterable {
    case dateDesc = "Newest First"
    case dateAsc = "Oldest First"
    case titleAsc = "Title A-Z"
    case riskDesc = "High Risk First"
  }
  
  private var pendingReviewCount: Int {
    initiatives.filter { $0.status.lowercased() == "pending_review" }.count
  }
  
  private var filteredInitiatives: [InitiativeReviewItem] {
    var items = initiatives
    
    // Filter by status
    if statusFilter != "all" {
      items = items.filter { $0.status.lowercased() == statusFilter }
    }
    
    // Filter by category
    if categoryFilter != "all" {
      items = items.filter { $0.category.lowercased() == categoryFilter }
    }
    
    // Filter by agent
    if agentFilter != "all" {
      items = items.filter { $0.proposedByAgent.lowercased() == agentFilter }
    }
    
    // Search filter
    let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !q.isEmpty {
      items = items.filter { item in
        item.title.lowercased().contains(q)
        || (item.description ?? "").lowercased().contains(q)
        || item.category.lowercased().contains(q)
        || item.proposedByAgent.lowercased().contains(q)
      }
    }
    
    // Sort
    switch sortOrder {
    case .dateDesc:
      items.sort { ($0.updatedAt ?? $0.createdAt ?? .distantPast) > ($1.updatedAt ?? $1.createdAt ?? .distantPast) }
    case .dateAsc:
      items.sort { ($0.updatedAt ?? $0.createdAt ?? .distantPast) < ($1.updatedAt ?? $1.createdAt ?? .distantPast) }
    case .titleAsc:
      items.sort { $0.title < $1.title }
    case .riskDesc:
      items.sort { riskTierValue($0.riskTier) > riskTierValue($1.riskTier) }
    }
    
    return items
  }
  
  private var groupedInitiatives: [(String, [InitiativeReviewItem])] {
    let grouped = Dictionary(grouping: filteredInitiatives) { $0.status }
    let order = ["proposed", "lobs_review", "pending_review", "pending", "approved", "deferred", "rejected"]
    return order.compactMap { status in
      guard let items = grouped[status], !items.isEmpty else { return nil }
      return (status, items)
    }
  }
  
  private var availableCategories: [String] {
    Array(Set(initiatives.map { $0.category })).sorted()
  }
  
  private var availableAgents: [String] {
    Array(Set(initiatives.map { $0.proposedByAgent })).sorted()
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header with tabs
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "brain.fill")
              .font(.title2)
              .foregroundStyle(.linearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ))
            
            Text("Intelligence")
              .font(.title2)
              .fontWeight(.bold)
            
            if isLoading {
              ProgressView()
                .scaleEffect(0.7)
            }
          }
          
          Spacer()
          
          // Tab switcher
          HStack(spacing: 8) {
            Picker("View", selection: $selectedTab) {
              ForEach(IntelligenceTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
              }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            
            // Badge for pending reviews (initiatives tab only)
            if selectedTab == .initiatives && pendingReviewCount > 0 {
              Text("\(pendingReviewCount)")
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        
        Divider()
        
        // Tab-specific header (only for initiatives)
        if selectedTab == .initiatives {
          initiativesHeader
        }
      }
      .background(.ultraThinMaterial)
      
      Divider()
      
      // Content based on selected tab
      switch selectedTab {
      case .initiatives:
        initiativesContent
      case .reflections:
        reflectionsContent
      case .sweeps:
        SweepHistoryView(vm: vm)
      }
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      vm.ensureIntelligenceLoaded()
      switch selectedTab {
      case .initiatives:
        Task { await loadInitiatives() }
      case .reflections:
        Task { await loadReflections() }
      case .sweeps:
        break // SweepHistoryView loads its own data
      }
    }
    .onChange(of: selectedTab) { oldValue, newValue in
      switch newValue {
      case .initiatives:
        if initiatives.isEmpty {
          Task { await loadInitiatives() }
        }
      case .reflections:
        if reflections.isEmpty {
          Task { await loadReflections() }
        }
      case .sweeps:
        break
      }
    }
  }
  
  // MARK: - Initiatives Header
  
  private var initiativesHeader: some View {
    HStack(spacing: 12) {
      // Search
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
          .font(.footnote)
        TextField("Search initiatives…", text: $searchText)
          .textFieldStyle(.plain)
          .frame(width: 160)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.secondary.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      
      // Filters
      Menu {
        Button("All Statuses") { statusFilter = "all" }
        Divider()
        Button("Needs Review") { statusFilter = "pending_review" }
        Button("Pending Review") { statusFilter = "lobs_review" }
        Button("Approved") { statusFilter = "approved" }
        Button("Rejected") { statusFilter = "rejected" }
        Button("Deferred") { statusFilter = "deferred" }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "line.3.horizontal.decrease.circle")
          Text(statusFilter == "all" ? "All" : statusFilter.capitalized)
            .font(.footnote)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      
      // Sort
      Picker("Sort", selection: $sortOrder) {
        ForEach(SortOrder.allCases, id: \.self) { order in
          Text(order.rawValue).tag(order)
        }
      }
      .pickerStyle(.menu)
      .frame(width: 140)
      
      // Refresh
      Button {
        Task { await loadInitiatives() }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.body)
          .padding(6)
          .background(Color.secondary.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .help("Refresh initiatives")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
  }
  
  // MARK: - Initiatives Content
  
  private var initiativesContent: some View {
    VStack(spacing: 0) {
      
      // Batch actions bar (shown when items selected)
      if !selectedIds.isEmpty {
        HStack(spacing: 12) {
          Text("\(selectedIds.count) selected")
            .font(.callout)
            .fontWeight(.semibold)
          
          Spacer()
          
          Button("Approve") {
            Task { await batchDecide(decision: "approve") }
          }
          .buttonStyle(.borderedProminent)
          .tint(.green)
          
          Button("Defer") {
            Task { await batchDecide(decision: "defer") }
          }
          .buttonStyle(.bordered)
          
          Button("Reject") {
            Task { await batchDecide(decision: "reject") }
          }
          .buttonStyle(.bordered)
          .tint(.red)
          
          Button("Clear") {
            selectedIds.removeAll()
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.1))
        
        Divider()
      }
      
      // Main content split view
      HSplitView {
        // Left: Initiative list
        ScrollView {
          LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
            if filteredInitiatives.isEmpty {
              VStack(spacing: 12) {
                Image(systemName: "tray")
                  .font(.system(size: 36))
                  .foregroundStyle(.quaternary)
                Text("No initiatives")
                  .font(.callout)
                  .foregroundStyle(.secondary)
                Text(searchText.isEmpty ? "Agent initiatives will appear here" : "No initiatives match your search")
                  .font(.footnote)
                  .foregroundStyle(.tertiary)
              }
              .frame(maxWidth: .infinity)
              .padding(.top, 60)
            } else {
              ForEach(groupedInitiatives, id: \.0) { status, items in
                Section {
                  ForEach(items) { item in
                    InitiativeRow(
                      item: item,
                      isSelected: selectedInitiative?.id == item.id,
                      isChecked: selectedIds.contains(item.id),
                      onSelect: {
                        selectedInitiative = item
                      },
                      onToggleCheck: {
                        if selectedIds.contains(item.id) {
                          selectedIds.remove(item.id)
                        } else {
                          selectedIds.insert(item.id)
                        }
                      }
                    )
                  }
                } header: {
                  HStack {
                    Text(statusDisplayName(status))
                      .font(.headline)
                      .foregroundStyle(.primary)
                    Text("\(items.count)")
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                    Spacer()
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .background(.ultraThinMaterial)
                }
              }
            }
          }
          .padding(12)
        }
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 400)
        
        // Right: Detail viewer
        if let item = selectedInitiative {
          InitiativeDetailView(
            item: item,
            vm: vm,
            onDecision: { decision, notes in
              Task { await decideInitiative(id: item.id, decision: decision, notes: notes) }
            },
            onOpenTask: { taskId in
              if let task = vm.tasks.first(where: { $0.id == taskId }) {
                vm.selectTask(task)
              }
            }
          )
          .frame(minWidth: 500, idealWidth: 700)
        } else {
          VStack(spacing: 12) {
            Image(systemName: "brain")
              .font(.system(size: 40))
              .foregroundStyle(.quaternary)
            Text("Select an initiative to review")
              .font(.callout)
              .foregroundStyle(.tertiary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }
  
  // MARK: - Reflections Content
  
  private var reflectionsContent: some View {
    VStack(spacing: 0) {
      // Header with filter
      HStack(spacing: 12) {
        // Agent filter
        Menu {
          Button("All Agents") { agentTypeFilter = "all" }
          Divider()
          ForEach(availableAgentTypes, id: \.self) { agentType in
            Button(agentType.capitalized) { agentTypeFilter = agentType }
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "person.3.fill")
            Text(agentTypeFilter == "all" ? "All Agents" : agentTypeFilter.capitalized)
              .font(.footnote)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.secondary.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        
        Spacer()
        
        // Refresh button
        Button {
          Task { await loadReflections() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.body)
            .padding(6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("Refresh reflections")
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      
      Divider()
      
      // Content
      ScrollView {
        LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
          if filteredReflections.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: "brain")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
              Text("No reflections")
                .font(.callout)
                .foregroundStyle(.secondary)
              Text(agentTypeFilter == "all" ? "Reflection cycles will appear here" : "No reflections for this agent type")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
          } else {
            ForEach(groupedReflections, id: \.key) { dateGroup in
              Section {
                ForEach(dateGroup.value) { reflection in
                  ReflectionCard(
                    reflection: reflection,
                    initiatives: initiativesForReflection(reflection),
                    isExpanded: expandedReflectionId == reflection.id,
                    onToggleExpand: {
                      withAnimation {
                        expandedReflectionId = expandedReflectionId == reflection.id ? nil : reflection.id
                      }
                    }
                  )
                }
              } header: {
                HStack {
                  Text(dateGroup.key)
                    .font(.headline)
                    .foregroundStyle(.primary)
                  Text("\(dateGroup.value.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                  Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
              }
            }
          }
        }
        .padding(12)
      }
    }
  }
  
  private var filteredReflections: [ReflectionCycle] {
    if agentTypeFilter == "all" {
      return reflections
    } else {
      return reflections.filter { reflection in
        reflection.agents.contains { agent in
          agent.lowercased().contains(agentTypeFilter.lowercased())
        }
      }
    }
  }
  
  private var groupedReflections: [(key: String, value: [ReflectionCycle])] {
    let grouped = Dictionary(grouping: filteredReflections) { reflection in
      formatDateGroup(reflection.startedAt)
    }
    return grouped.sorted { $0.key > $1.key }
  }
  
  private var availableAgentTypes: [String] {
    let allAgents = reflections.flatMap { $0.agents }
    let uniqueTypes = Set(allAgents.map { agent in
      // Extract agent type from names like "programmer", "researcher", etc.
      agent.lowercased().split(separator: "-").first.map(String.init) ?? agent.lowercased()
    })
    return Array(uniqueTypes).sorted()
  }
  
  private func initiativesForReflection(_ reflection: ReflectionCycle) -> [InitiativeReviewItem] {
    return initiatives.filter { initiative in
      reflection.proposedInitiatives.contains(initiative.id)
    }
  }
  
  private func formatDateGroup(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "Today"
    } else if calendar.isDateInYesterday(date) {
      return "Yesterday"
    } else {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      return formatter.string(from: date)
    }
  }
  
  // MARK: - Loading Functions
  
  private func loadInitiatives() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
      initiatives = try await vm.apiService?.loadInitiatives() ?? []
      print("✅ [Intelligence] Loaded \(initiatives.count) initiatives")
    } catch {
      print("❌ [Intelligence] Failed to load initiatives: \(error)")
      await MainActor.run {
        vm.flashError("Failed to load initiatives: \(error.localizedDescription)")
      }
    }
  }
  
  private func loadReflections() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
      guard let apiService = vm.apiService else { return }
      async let summaryTask = apiService.fetchIntelligenceSummary()
      async let reflectionsTask = apiService.fetchReflections(limit: 50)
      async let initiativesTask = apiService.loadInitiatives(limit: 200)
      
      intelligenceSummary = try await summaryTask
      reflections = try await reflectionsTask
      initiatives = try await initiativesTask
    } catch {
      await MainActor.run {
        vm.flashError("Failed to load intelligence data: \(error.localizedDescription)")
      }
    }
  }
  
  private func decideInitiative(id: String, decision: String, notes: String?) async {
    do {
      let updated = try await vm.apiService?.decideInitiative(id: id, decision: decision, notes: notes)
      // Update local list
      if let updated = updated, let idx = initiatives.firstIndex(where: { $0.id == id }) {
        initiatives[idx] = updated
      }
      // Clear selection if no longer pending
      if selectedInitiative?.id == id && decision != "lobs_review" {
        selectedInitiative = nil
      }
      await loadInitiatives()
    } catch {
      await MainActor.run {
        vm.flashError("Failed to update initiative: \(error.localizedDescription)")
      }
    }
  }
  
  private func batchDecide(decision: String) async {
    do {
      try await vm.apiService?.batchDecideInitiatives(ids: Array(selectedIds), decision: decision)
      selectedIds.removeAll()
      await loadInitiatives()
    } catch {
      await MainActor.run {
        vm.flashError("Failed to batch update initiatives: \(error.localizedDescription)")
      }
    }
  }
  
  private func statusDisplayName(_ status: String) -> String {
    switch status.lowercased() {
    case "pending_review": return "Needs Review"
    case "lobs_review": return "Pending Review"
    case "approved": return "Approved"
    case "rejected": return "Rejected"
    case "deferred": return "Deferred"
    default: return status.capitalized
    }
  }
  
  private func riskTierValue(_ tier: String) -> Int {
    switch tier.lowercased() {
    case "critical": return 4
    case "high": return 3
    case "medium": return 2
    case "low": return 1
    default: return 0
    }
  }
}

// MARK: - Initiative Row

private struct InitiativeRow: View {
  let item: InitiativeReviewItem
  let isSelected: Bool
  let isChecked: Bool
  let onSelect: () -> Void
  let onToggleCheck: () -> Void
  
  @State private var isHovering = false
  
  private var statusColor: Color {
    switch item.status.lowercased() {
    case "lobs_review", "pending": return .orange
    case "approved": return .green
    case "rejected": return .red
    case "deferred": return .blue
    default: return .secondary
    }
  }
  
  private var riskColor: Color {
    switch item.riskTier.lowercased() {
    case "critical": return .red
    case "high": return .orange
    case "medium": return .yellow
    case "low": return .green
    default: return .secondary
    }
  }
  
  var body: some View {
    HStack(spacing: 12) {
      // Checkbox
      Button {
        onToggleCheck()
      } label: {
        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
          .font(.title3)
          .foregroundStyle(isChecked ? .blue : .secondary)
      }
      .buttonStyle(.plain)
      .help("Select for batch actions")
      
      Button(action: onSelect) {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(item.title)
              .font(.subheadline)
              .fontWeight(.semibold)
              .lineLimit(2)
            Spacer()
          }
          
          if let description = item.description, !description.isEmpty {
            Text(description)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          
          HStack(spacing: 8) {
            // Agent
            HStack(spacing: 3) {
              Image(systemName: "person.circle")
                .font(.system(size: 9))
              Text(item.proposedByAgent.capitalized)
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.12))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
            
            // Category
            HStack(spacing: 3) {
              Image(systemName: "tag")
                .font(.system(size: 9))
              Text(item.category)
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
              Text(item.riskTier)
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(riskColor.opacity(0.15))
            .foregroundStyle(riskColor)
            .clipShape(Capsule())
            
            // Status
            Circle()
              .fill(statusColor)
              .frame(width: 6, height: 6)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovering ? Color.secondary.opacity(0.05) : Color.clear))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
      }
      .buttonStyle(.plain)
      .onHover { h in isHovering = h }
    }
  }
}

// MARK: - Initiative Detail View

private struct InitiativeDetailView: View {
  let item: InitiativeReviewItem
  @ObservedObject var vm: AppViewModel
  let onDecision: (String, String?) -> Void
  let onOpenTask: (String) -> Void
  
  @State private var decisionNotes: String = ""
  @State private var showApproveConfirm: Bool = false
  @State private var showRejectConfirm: Bool = false
  @State private var threadMessages: [InboxThreadMessage] = []
  @State private var isLoadingThread: Bool = false
  @State private var newMessageText: String = ""
  @State private var isSendingMessage: Bool = false
  @State private var showDiscussion: Bool = true
  
  private var isPending: Bool {
    item.status.lowercased() == "lobs_review" || item.status.lowercased() == "pending"
  }
  
  private var statusColor: Color {
    switch item.status.lowercased() {
    case "lobs_review", "pending": return .orange
    case "approved": return .green
    case "rejected": return .red
    case "deferred": return .blue
    default: return .secondary
    }
  }
  
  private var riskColor: Color {
    switch item.riskTier.lowercased() {
    case "critical": return .red
    case "high": return .orange
    case "medium": return .yellow
    case "low": return .green
    default: return .secondary
    }
  }
  
  @ViewBuilder
  private var linkedTasksSection: some View {
    let linkedTaskIds = item.allTaskIds
    if !linkedTaskIds.isEmpty {
      Divider()
      
      VStack(alignment: .leading, spacing: 12) {
        Text(linkedTaskIds.count == 1 ? "Linked Task" : "Linked Tasks")
          .font(.headline)
        
        ForEach(linkedTaskIds, id: \.self) { taskId in
          linkedTaskButton(for: taskId)
        }
      }
    }
  }
  
  @ViewBuilder
  private func linkedTaskButton(for taskId: String) -> some View {
    let task = vm.tasks.first(where: { $0.id == taskId })
    let taskExists = task != nil
    
    Button {
      onOpenTask(taskId)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "arrowshape.turn.up.right")
        
        if let task = task {
          VStack(alignment: .leading, spacing: 2) {
            Text(task.title)
              .font(.body)
              .lineLimit(1)
            
            HStack(spacing: 6) {
              if let project = vm.projects.first(where: { $0.id == (task.projectId ?? "default") }) {
                Text(project.title)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              
              Text("•")
                .font(.caption)
                .foregroundStyle(.tertiary)
              
              Text(task.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } else {
          Text("Task Not Loaded")
            .font(.body)
            .foregroundStyle(.secondary)
            .italic()
        }
        
        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
    }
    .buttonStyle(.bordered)
    .disabled(!taskExists)
    .help(taskId)
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Title
        Text(item.title)
          .font(.title2)
          .fontWeight(.bold)
        
        // Metadata
        HStack(spacing: 12) {
          Label(item.proposedByAgent.capitalized, systemImage: "person.circle")
          Label(item.category, systemImage: "tag")
          Label(item.riskTier, systemImage: "exclamationmark.triangle")
            .foregroundStyle(riskColor)
          Label(item.status.capitalized, systemImage: "circle.fill")
            .foregroundStyle(statusColor)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        
        if let createdAt = item.createdAt {
          Text("Created: \(createdAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        if let updatedAt = item.updatedAt {
          Text("Updated: \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Divider()
        
        // Description
        VStack(alignment: .leading, spacing: 8) {
          Text("Proposal")
            .font(.headline)
          
          if let description = item.description, !description.isEmpty {
            Text(description)
              .font(.body)
              .textSelection(.enabled)
          } else {
            Text("No description provided")
              .font(.body)
              .foregroundStyle(.secondary)
              .italic()
          }
        }
        
        Divider()
        
        // Additional metadata
        VStack(alignment: .leading, spacing: 8) {
          Text("Details")
            .font(.headline)
          
          if let owner = item.ownerAgent {
            Label("Suggested Owner: \(owner.capitalized)", systemImage: "person.badge.shield.checkmark")
              .font(.caption)
          }
          
          if let selectedAgent = item.selectedAgent {
            Label("Selected Agent: \(selectedAgent.capitalized)", systemImage: "person.badge.gearshape")
              .font(.caption)
          }
          
          if let effort = item.estimatedEffort {
            Label("Estimated Effort: \(effort)", systemImage: "gauge")
              .font(.caption)
          }
          
          if let projectId = item.selectedProjectId {
            Label("Project: \(projectId)", systemImage: "folder")
              .font(.caption)
          }
        }
        
        // Linked Tasks Section
        linkedTasksSection
        
        // Decision section (for pending items)
        if isPending {
          Divider()
          
          VStack(alignment: .leading, spacing: 12) {
            Text("Make Decision")
              .font(.headline)
            
            TextEditor(text: $decisionNotes)
              .font(.body)
              .frame(minHeight: 60, maxHeight: 120)
              .padding(8)
              .background(Color.secondary.opacity(0.1))
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
            
            Text("Optional notes about your decision")
              .font(.caption)
              .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
              Button {
                onDecision("approve", decisionNotes.isEmpty ? nil : decisionNotes)
                decisionNotes = ""
              } label: {
                HStack {
                  Image(systemName: "checkmark.circle.fill")
                  Text("Approve")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .tint(.green)
              .help("Approve this initiative")
              
              Button {
                onDecision("defer", decisionNotes.isEmpty ? nil : decisionNotes)
                decisionNotes = ""
              } label: {
                HStack {
                  Image(systemName: "clock.fill")
                  Text("Defer")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .help("Defer decision to later")
              
              Button {
                onDecision("reject", decisionNotes.isEmpty ? nil : decisionNotes)
                decisionNotes = ""
              } label: {
                HStack {
                  Image(systemName: "xmark.circle.fill")
                  Text("Reject")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .tint(.red)
              .help("Reject this initiative")
            }
          }
        } else if let decisionSummary = item.decisionSummary, !decisionSummary.isEmpty {
          Divider()
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Decision Notes")
              .font(.headline)
            
            Text(decisionSummary)
              .font(.body)
              .textSelection(.enabled)
          }
        }
        
        if let rationale = item.rationale, !rationale.isEmpty {
          Divider()
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Rationale")
              .font(.headline)
            
            Text(rationale)
              .font(.body)
              .textSelection(.enabled)
          }
        }
        
        if let feedback = item.learningFeedback, !feedback.isEmpty {
          Divider()
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Learning Feedback")
              .font(.headline)
            
            Text(feedback)
              .font(.body)
              .textSelection(.enabled)
          }
        }
        
        // Discussion/Thread Section
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
          Button {
            showDiscussion.toggle()
          } label: {
            HStack {
              Image(systemName: showDiscussion ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
              
              Text("Discussion")
                .font(.headline)
              
              if !threadMessages.isEmpty {
                Text("(\(threadMessages.count))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              
              Spacer()
            }
          }
          .buttonStyle(.plain)
          
          if showDiscussion {
            VStack(alignment: .leading, spacing: 8) {
              if isLoadingThread {
                HStack {
                  ProgressView()
                    .scaleEffect(0.7)
                  Text("Loading discussion...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
              } else if threadMessages.isEmpty {
                Text("No messages yet. Start the conversation below.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .italic()
                  .padding(.vertical, 8)
              } else {
                ScrollView {
                  VStack(alignment: .leading, spacing: 12) {
                    ForEach(threadMessages) { message in
                      InitiativeThreadBubble(message: message)
                    }
                  }
                  .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
              }
              
              Divider()
              
              // Message input
              VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: $newMessageText)
                  .font(.body)
                  .frame(minHeight: 60, maxHeight: 100)
                  .padding(8)
                  .background(Color.secondary.opacity(0.1))
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                  )
                
                HStack {
                  Text("Ask questions or provide feedback about this initiative")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  
                  Spacer()
                  
                  Button {
                    sendMessage()
                  } label: {
                    HStack(spacing: 4) {
                      if isSendingMessage {
                        ProgressView()
                          .scaleEffect(0.7)
                      } else {
                        Image(systemName: "paperplane.fill")
                      }
                      Text("Send")
                    }
                  }
                  .buttonStyle(.borderedProminent)
                  .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingMessage)
                }
              }
            }
          }
        }
      }
      .padding(20)
      .onAppear {
        loadThread()
      }
    }
  }
  
  private func loadThread() {
    guard !isLoadingThread else { return }
    isLoadingThread = true
    
    Task {
      do {
        let messages = try await vm.apiService?.fetchInitiativeThread(id: item.id) ?? []
        await MainActor.run {
          threadMessages = messages
          isLoadingThread = false
        }
      } catch {
        await MainActor.run {
          isLoadingThread = false
          // Silently fail - thread might not exist yet
        }
      }
    }
  }
  
  private func sendMessage() {
    let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !isSendingMessage else { return }
    
    isSendingMessage = true
    
    Task {
      do {
        let message = try await vm.apiService?.sendInitiativeMessage(id: item.id, text: text)
        await MainActor.run {
          if let message = message {
            threadMessages.append(message)
          }
          newMessageText = ""
          isSendingMessage = false
        }
      } catch {
        await MainActor.run {
          isSendingMessage = false
          vm.flashError("Failed to send message: \(error.localizedDescription)")
        }
      }
    }
  }
}

// MARK: - Reflection Card

private struct ReflectionCard: View {
  let reflection: ReflectionCycle
  let initiatives: [InitiativeReviewItem]
  let isExpanded: Bool
  let onToggleExpand: () -> Void
  
  @State private var isHovering = false
  
  private var statusColor: Color {
    switch reflection.status {
    case .completed:
      return .green
    case .failed:
      return .red
    case .running:
      return .orange
    case .pending:
      return .blue
    }
  }
  
  private var statusIcon: String {
    switch reflection.status {
    case .completed:
      return "checkmark.circle.fill"
    case .failed:
      return "xmark.circle.fill"
    case .running:
      return "arrow.triangle.2.circlepath.circle.fill"
    case .pending:
      return "clock.fill"
    }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header (always visible)
      Button(action: onToggleExpand) {
        HStack(spacing: 12) {
          // Status indicator
          Image(systemName: statusIcon)
            .font(.title3)
            .foregroundStyle(statusColor)
          
          VStack(alignment: .leading, spacing: 4) {
            // Agent names
            HStack(spacing: 6) {
              ForEach(reflection.agents.prefix(3), id: \.self) { agent in
                HStack(spacing: 3) {
                  Image(systemName: "person.circle.fill")
                    .font(.system(size: 9))
                  Text(agent.capitalized)
                    .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
              }
              
              if reflection.agents.count > 3 {
                Text("+\(reflection.agents.count - 3) more")
                  .font(.system(size: 11))
                  .foregroundStyle(.secondary)
              }
            }
            
            // Date and status
            HStack(spacing: 8) {
              Text(reflection.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
              
              Text("•")
                .foregroundStyle(.tertiary)
              
              Text(reflection.status.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(statusColor)
              
              if reflection.status == .completed, let completedAt = reflection.completedAt {
                Text("•")
                  .foregroundStyle(.tertiary)
                
                let duration = completedAt.timeIntervalSince(reflection.startedAt)
                Text("Duration: \(formatDuration(duration))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            
            // Quick stats
            HStack(spacing: 12) {
              if !reflection.inefficiencies.isEmpty {
                Label("\(reflection.inefficiencies.count)", systemImage: "exclamationmark.triangle")
                  .font(.caption)
                  .foregroundStyle(.orange)
              }
              
              if !reflection.missedOpportunities.isEmpty {
                Label("\(reflection.missedOpportunities.count)", systemImage: "lightbulb")
                  .font(.caption)
                  .foregroundStyle(.yellow)
              }
              
              if !reflection.systemRisks.isEmpty {
                Label("\(reflection.systemRisks.count)", systemImage: "shield.slash")
                  .font(.caption)
                  .foregroundStyle(.red)
              }
              
              if !reflection.proposedInitiatives.isEmpty {
                Label("\(reflection.proposedInitiatives.count)", systemImage: "tray.full")
                  .font(.caption)
                  .foregroundStyle(.blue)
              }
            }
          }
          
          Spacer()
          
          // Expand/collapse chevron
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(isHovering ? Color.secondary.opacity(0.05) : Color.clear)
        )
      }
      .buttonStyle(.plain)
      .onHover { h in isHovering = h }
      
      // Expanded detail
      if isExpanded {
        VStack(alignment: .leading, spacing: 16) {
          Divider()
          
          // Error message (if failed)
          if reflection.status == .failed, let errorMessage = reflection.errorMessage {
            VStack(alignment: .leading, spacing: 6) {
              Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
              
              Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
            .padding(10)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          
          // Show "No findings" message if all arrays are empty
          let hasFindings = !reflection.inefficiencies.isEmpty 
                           || !reflection.missedOpportunities.isEmpty 
                           || !reflection.systemRisks.isEmpty 
                           || !reflection.identityAdjustments.isEmpty
                           || !reflection.proposedInitiatives.isEmpty
          
          if !hasFindings && reflection.status == .completed {
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
                Text("No Findings")
                  .font(.subheadline)
                  .fontWeight(.semibold)
              }
              
              Text("This reflection cycle completed successfully but found no inefficiencies, missed opportunities, system risks, or identity adjustments to report.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          } else if !hasFindings && reflection.status == .running {
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) {
                ProgressView()
                  .scaleEffect(0.7)
                Text("Reflection In Progress")
                  .font(.subheadline)
                  .fontWeight(.semibold)
              }
              
              Text("This reflection cycle is currently running. Findings will appear here when the analysis is complete.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.orange.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          
          // Inefficiencies
          if !reflection.inefficiencies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("Inefficiencies Detected", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
              
              ForEach(Array(reflection.inefficiencies.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                  Text("•")
                    .foregroundStyle(.orange)
                  Text(item)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
          
          // Missed Opportunities
          if !reflection.missedOpportunities.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("Missed Opportunities", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)
              
              ForEach(Array(reflection.missedOpportunities.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                  Text("•")
                    .foregroundStyle(.yellow)
                  Text(item)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
          
          // System Risks
          if !reflection.systemRisks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("System Risks", systemImage: "shield.slash.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
              
              ForEach(Array(reflection.systemRisks.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                  Text("•")
                    .foregroundStyle(.red)
                  Text(item)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
          
          // Identity Adjustments
          if !reflection.identityAdjustments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("Identity Adjustments", systemImage: "person.badge.key.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)
              
              ForEach(Array(reflection.identityAdjustments.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                  Text("•")
                    .foregroundStyle(.purple)
                  Text(item)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
          
          // Proposed Initiatives with Decision Status
          if !initiatives.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Label("Proposed Initiatives", systemImage: "tray.full.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
              
              ForEach(initiatives) { initiative in
                HStack(spacing: 8) {
                  // Decision status emoji
                  Text(decisionEmoji(for: initiative.status))
                    .font(.body)
                  
                  VStack(alignment: .leading, spacing: 2) {
                    Text(initiative.title)
                      .font(.caption)
                      .fontWeight(.medium)
                      .lineLimit(1)
                    
                    HStack(spacing: 6) {
                      Text(initiative.category)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                      
                      Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                      
                      Text(initiative.status.capitalized)
                        .font(.system(size: 10))
                        .foregroundStyle(statusColorForInitiative(initiative.status))
                    }
                  }
                  
                  Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
              }
            }
          } else if !reflection.proposedInitiatives.isEmpty {
            // Initiatives exist but not loaded
            VStack(alignment: .leading, spacing: 8) {
              Label("Proposed Initiatives", systemImage: "tray.full.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
              
              Text("Proposed \(reflection.proposedInitiatives.count) initiative(s) — details not loaded")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
            }
          }
          
          // Batch ID (for debugging/reference)
          Text("Batch ID: \(reflection.batchId)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.secondary.opacity(0.03))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
    )
  }
  
  private func decisionEmoji(for status: String) -> String {
    switch status.lowercased() {
    case "approved":
      return "✅"
    case "rejected":
      return "❌"
    case "deferred":
      return "⏸️"
    case "lobs_review", "pending":
      return "🟡"
    default:
      return "⚪️"
    }
  }
  
  private func statusColorForInitiative(_ status: String) -> Color {
    switch status.lowercased() {
    case "approved":
      return .green
    case "rejected":
      return .red
    case "deferred":
      return .blue
    case "lobs_review", "pending":
      return .orange
    default:
      return .secondary
    }
  }
  
  private func formatDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    
    if hours > 0 {
      return "\(hours)h \(remainingMinutes)m"
    } else if minutes > 0 {
      return "\(minutes)m"
    } else {
      return "<1m"
    }
  }
}

// MARK: - Initiative Thread Bubble

private struct InitiativeThreadBubble: View {
  let message: InboxThreadMessage
  
  private var isRafe: Bool {
    message.author.lowercased() == "rafe"
  }
  
  private var authorColor: Color {
    isRafe ? .blue : .purple
  }
  
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      // Author avatar
      ZStack {
        Circle()
          .fill(authorColor.opacity(0.15))
          .frame(width: 28, height: 28)
        Text(isRafe ? "R" : String(message.author.prefix(1).uppercased()))
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(authorColor)
      }
      
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(message.author.capitalized)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(authorColor)
          
          Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        
        Text(message.text)
          .font(.body)
          .textSelection(.enabled)
      }
      
      Spacer()
    }
    .padding(10)
    .background(Color.secondary.opacity(0.03))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

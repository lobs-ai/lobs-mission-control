import SwiftUI

/// TasksContainerView — redesigned with sidebar navigation and rich project overview
struct TasksContainerView: View {
    @EnvironmentObject var vm: AppViewModel
    
    @AppStorage("autoPush") private var autoPush = true
    @State private var showAddTask = false
    @State private var showCreateProject = false
    @State private var showAllDone = false
    @State private var showAllRejected = false
    @State private var quickAddText = ""
    @State private var projectSearchText = ""
    @State private var showArchivedProjects = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar with project list
            projectSidebar
            
            Divider()
            
            // Main content area
            VStack(spacing: 0) {
                // Top bar with controls
                topBar
                
                Divider()
                
                // Content based on selection
                mainContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.boardBg)
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(
                vm: vm,
                autoPush: $autoPush,
                projectId: vm.showOverview ? nil : vm.selectedProjectId
            )
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectSheet(vm: vm)
        }
    }
    
    // MARK: - Project Sidebar
    
    private var projectSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Projects")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                
                // Toggle archived
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showArchivedProjects.toggle()
                    }
                } label: {
                    Image(systemName: showArchivedProjects ? "archivebox.fill" : "archivebox")
                        .font(.caption)
                        .foregroundStyle(showArchivedProjects ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help(showArchivedProjects ? "Hide archived" : "Show archived")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // Search projects
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search…", text: $projectSearchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Project list
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Overview
                    SidebarProjectItem(
                        title: "Overview",
                        icon: "house.fill",
                        color: .blue,
                        isSelected: vm.showOverview,
                        taskCount: nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.showOverview = true
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Projects
                    ForEach(filteredProjects) { project in
                        SidebarProjectItem(
                            title: project.title,
                            icon: projectIcon(project.resolvedType),
                            color: projectColor(project.resolvedType),
                            isSelected: !vm.showOverview && vm.selectedProjectId == project.id,
                            taskCount: taskCount(for: project.id),
                            isArchived: project.archived == true
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                vm.selectedProjectId = project.id
                                vm.showOverview = false
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // New project button
            Button {
                showCreateProject = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.footnote)
                    Text("New Project")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 220)
        .background(Theme.bg)
    }
    
    private var filteredProjects: [Project] {
        let projects = showArchivedProjects 
            ? vm.projects 
            : vm.sortedActiveProjects
        
        if projectSearchText.isEmpty {
            return projects
        }
        
        return projects.filter { project in
            project.title.localizedCaseInsensitiveContains(projectSearchText)
        }
    }
    
    private func taskCount(for projectId: String) -> Int {
        vm.tasks.filter { $0.projectId == projectId && $0.status != .completed && $0.status != .rejected }.count
    }
    
    private func projectIcon(_ type: ProjectType) -> String {
        switch type {
        case .kanban: return "rectangle.3.group.fill"
        case .research: return "doc.text.magnifyingglass"
        case .tracker: return "chart.bar.fill"
        }
    }
    
    private func projectColor(_ type: ProjectType) -> Color {
        switch type {
        case .kanban: return .blue
        case .research: return .purple
        case .tracker: return .green
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(spacing: 12) {
            // Project breadcrumb
            if !vm.showOverview {
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(vm.selectedProject?.title ?? "Project")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Task count badges (when viewing a project)
                if !vm.selectedProjectId.isEmpty {
                    let projectTasks = vm.tasks.filter { $0.projectId == vm.selectedProjectId }
                    let activeCount = projectTasks.filter { $0.status == .active }.count
                    let blockedCount = projectTasks.filter { $0.workState == .blocked && $0.status != .completed && $0.status != .rejected }.count
                    
                    HStack(spacing: 8) {
                        if activeCount > 0 {
                            TaskCountBadge(label: "Active", count: activeCount, color: .orange)
                        }
                        if blockedCount > 0 {
                            TaskCountBadge(label: "Blocked", count: blockedCount, color: .red)
                        }
                    }
                }
                
                // Search (hidden in overview)
                searchField
                
                // Filters (hidden in overview)
                ownerFilter
                shapeFilter
            } else {
                // Overview mode breadcrumb
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Overview")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Overview stats
                let activeTasks = vm.tasks.filter { $0.status != .completed && $0.status != .rejected }.count
                let totalTasks = vm.tasks.count
                let activeProjects = vm.sortedActiveProjects.count
                
                HStack(spacing: 12) {
                    OverviewStat(label: "Projects", value: "\(activeProjects)", icon: "folder.fill", color: .blue)
                    OverviewStat(label: "Tasks", value: "\(totalTasks) (\(activeTasks) active)", icon: "flame.fill", color: .orange)
                }
            }
            
            // Add task button
            if !vm.showOverview {
                HoverIconButton(
                    icon: "plus",
                    tooltip: "New Task (⌘N)",
                    shortcut: "⌘N"
                ) {
                    showAddTask = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.bg)
    }
    
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.footnote)
            TextField("Search tasks…", text: $vm.searchText)
                .textFieldStyle(.plain)
                .font(.callout)
                .frame(width: 180)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.subtle)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var ownerFilter: some View {
        Menu {
            Button { vm.ownerFilter = "all" } label: {
                Label("All tasks", systemImage: vm.ownerFilter == "all" ? "checkmark" : "")
            }
            Button { vm.ownerFilter = "lobs" } label: {
                Label("Lobs only", systemImage: vm.ownerFilter == "lobs" ? "checkmark" : "")
            }
            Button { vm.ownerFilter = "rafe" } label: {
                Label("Rafe only", systemImage: vm.ownerFilter == "rafe" ? "checkmark" : "")
            }
            Divider()
            Button { vm.ownerFilter = "other" } label: {
                Label("Other", systemImage: vm.ownerFilter == "other" ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.footnote)
                if vm.ownerFilter != "all" {
                    Text(vm.ownerFilter.capitalized)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(vm.ownerFilter != "all" ? Color.accentColor.opacity(0.12) : Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    private var shapeFilter: some View {
        Menu {
            Button {
                vm.shapeFilter = nil
            } label: {
                Label("Any type", systemImage: vm.shapeFilter == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(TaskShape.allCases, id: \.self) { shape in
                Button {
                    vm.shapeFilter = vm.shapeFilter == shape ? nil : shape
                } label: {
                    Label(
                        "\(shapeIcon(shape)) \(shapeLabel(shape))",
                        systemImage: vm.shapeFilter == shape ? "checkmark" : ""
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.footnote)
                if let shape = vm.shapeFilter {
                    Text("\(shapeIcon(shape))")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(vm.shapeFilter != nil ? Color.accentColor.opacity(0.12) : Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        if vm.showOverview {
            overviewContent
        } else if vm.isResearchProject {
            ResearchDocView(vm: vm)
                .id("research-\(vm.selectedProjectId)")
        } else if vm.isTrackerProject {
            TrackerBoardView(vm: vm)
        } else {
            BoardView(
                vm: vm,
                showAllDone: $showAllDone,
                showAllRejected: $showAllRejected,
                autoPush: $autoPush,
                quickAddText: $quickAddText
            )
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with sort/filter
                HStack {
                    Text("All Projects")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Sort options
                    Menu {
                        Button {
                            // TODO: Implement sorting
                        } label: {
                            Label("Sort by Activity", systemImage: "clock")
                        }
                        Button {
                            // TODO: Implement sorting
                        } label: {
                            Label("Sort by Name", systemImage: "textformat")
                        }
                        Button {
                            // TODO: Implement sorting
                        } label: {
                            Label("Sort by Tasks", systemImage: "number")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                            Text("Sort")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.subtle)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Project cards grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 20)
                ], spacing: 20) {
                    // New Project card
                    NewProjectCard {
                        showCreateProject = true
                    }
                    
                    // Existing projects
                    ForEach(vm.sortedActiveProjects) { project in
                        RichProjectCard(
                            project: project,
                            tasks: vm.tasks.filter { $0.projectId == project.id },
                            vm: vm,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    vm.selectedProjectId = project.id
                                    vm.showOverview = false
                                }
                            },
                            onAddTask: {
                                vm.selectedProjectId = project.id
                                vm.showOverview = false
                                showAddTask = true
                            },
                            onArchive: {
                                vm.archiveProject(id: project.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    // Helper functions
    private func shapeIcon(_ shape: TaskShape) -> String {
        switch shape {
        case .deep: return "🎯"
        case .shallow: return "⚡️"
        case .creative: return "✨"
        case .waiting: return "⏳"
        case .admin: return "📋"
        }
    }
    
    private func shapeLabel(_ shape: TaskShape) -> String {
        shape.rawValue.capitalized
    }
}

// MARK: - Sidebar Project Item

private struct SidebarProjectItem: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let taskCount: Int?
    var isArchived: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? color : .secondary)
                    .frame(width: 16)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if let count = taskCount, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? color.opacity(0.2) : Theme.subtle)
                        .foregroundStyle(isSelected ? color : .secondary)
                        .clipShape(Capsule())
                }
                
                if isArchived {
                    Image(systemName: "archivebox.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color.opacity(0.12) : (isHovering ? Theme.subtle : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { h in isHovering = h }
    }
}

// MARK: - Task Count Badge

private struct TaskCountBadge: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Overview Stat

private struct OverviewStat: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.callout)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - New Project Card

private struct NewProjectCard: View {
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("New Project")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Create a new project to organize your tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                            .foregroundStyle(Color.blue.opacity(isHovering ? 0.4 : 0.2))
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { h in isHovering = h }
    }
}

// MARK: - Rich Project Card

private struct RichProjectCard: View {
    let project: Project
    let tasks: [DashboardTask]
    @ObservedObject var vm: AppViewModel
    let onSelect: () -> Void
    let onAddTask: () -> Void
    let onArchive: () -> Void
    
    @State private var isHovering = false
    
    private var activeCount: Int { tasks.filter { $0.status == .active }.count }
    private var completedCount: Int { tasks.filter { $0.status == .completed }.count }
    private var blockedCount: Int { tasks.filter { $0.workState == .blocked && $0.status != .completed && $0.status != .rejected }.count }
    private var totalCount: Int { tasks.count }
    
    private var completionPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount) * 100
    }
    
    private var lastActivity: Date? {
        tasks.map(\.updatedAt).max()
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: projectIcon(project.resolvedType))
                        .font(.title3)
                        .foregroundStyle(projectColor(project.resolvedType))
                        .frame(width: 32, height: 32)
                        .background(projectColor(project.resolvedType).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Text(project.resolvedType.rawValue.capitalized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(projectColor(project.resolvedType).opacity(0.15))
                                .foregroundStyle(projectColor(project.resolvedType))
                                .clipShape(Capsule())
                            
                            if let last = lastActivity {
                                Text("• \(relativeTime(last))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Task counts
                HStack(spacing: 10) {
                    if activeCount > 0 {
                        StatBadge(label: "Active", count: activeCount, color: .orange)
                    }
                    if completedCount > 0 {
                        StatBadge(label: "Done", count: completedCount, color: .green)
                    }
                    if blockedCount > 0 {
                        StatBadge(label: "Blocked", count: blockedCount, color: .red)
                    }
                    Spacer()
                }
                
                // Progress bar
                if totalCount > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(completionPercentage))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.1))
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.8), Color.green],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * (completionPercentage / 100))
                            }
                        }
                        .frame(height: 6)
                    }
                }
                
                // Notes preview
                if let notes = project.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                // Quick actions (show on hover)
                if isHovering {
                    HStack(spacing: 8) {
                        QuickActionButton(icon: "plus", label: "Add Task", color: .blue) {
                            onAddTask()
                        }
                        
                        QuickActionButton(icon: "archivebox", label: "Archive", color: .orange) {
                            onArchive()
                        }
                        
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBg)
                    .shadow(color: .black.opacity(isHovering ? 0.08 : 0.04), radius: isHovering ? 12 : 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHovering ? projectColor(project.resolvedType).opacity(0.3) : Theme.border, lineWidth: isHovering ? 1.5 : 1)
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { h in 
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = h
            }
        }
    }
    
    private func projectIcon(_ type: ProjectType) -> String {
        switch type {
        case .kanban: return "rectangle.3.group.fill"
        case .research: return "doc.text.magnifyingglass"
        case .tracker: return "chart.bar.fill"
        }
    }
    
    private func projectColor(_ type: ProjectType) -> Color {
        switch type {
        case .kanban: return .blue
        case .research: return .purple
        case .tracker: return .green
        }
    }
    
    private func relativeTime(_ date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 {
            return "just now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed/60))m ago"
        } else if elapsed < 86400 {
            return "\(Int(elapsed/3600))h ago"
        } else if elapsed < 604800 {
            return "\(Int(elapsed/86400))d ago"
        } else {
            return "\(Int(elapsed/604800))w ago"
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHovering ? color.opacity(0.15) : color.opacity(0.08))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { h in isHovering = h }
    }
}

import SwiftUI

/// TasksContainerView wraps the existing board/project functionality from ContentView
/// without rewriting it. This allows the sidebar navigation to work while preserving
/// all the complex task management logic.
struct TasksContainerView: View {
    @EnvironmentObject var vm: AppViewModel
    
    @AppStorage("autoPush") private var autoPush = true
    @State private var showAddTask = false
    @State private var showAllDone = false
    @State private var showAllRejected = false
    @State private var quickAddText = ""
    @State private var requestSearchFocus = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with project picker and controls
            topBar
            
            Divider()
            
            // Main content area
            Group {
                if vm.showOverview {
                    // Overview mode - show all projects
                    overviewContent
                } else if vm.isResearchProject {
                    // Research project view
                    ResearchDocView(vm: vm)
                        .id("research-\(vm.selectedProjectId)")
                } else if vm.isTrackerProject {
                    // Tracker project view
                    TrackerBoardView(vm: vm)
                } else {
                    // Standard Kanban board
                    BoardView(
                        vm: vm,
                        showAllDone: $showAllDone,
                        showAllRejected: $showAllRejected,
                        autoPush: $autoPush,
                        quickAddText: $quickAddText
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Theme.boardBg)
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(
                vm: vm,
                autoPush: $autoPush,
                projectId: vm.showOverview ? nil : vm.selectedProjectId
            )
        }
    }
    
    // Top bar with project picker and task controls
    private var topBar: some View {
        HStack(spacing: 12) {
            // Project picker
            projectPicker
            
            Spacer()
            
            // Search (hidden in overview)
            if !vm.showOverview {
                searchField
            }
            
            // Filter (hidden in overview)
            if !vm.showOverview {
                ownerFilter
                shapeFilter
            }
            
            // Home/Overview button
            HoverIconButton(
                icon: "house.fill",
                tooltip: "Overview (⌘⇧O)",
                activeBg: vm.showOverview ? Color.accentColor.opacity(0.15) : nil,
                shortcut: "⌘⇧O"
            ) {
                vm.showOverview = true
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.bg)
    }
    
    // Project picker dropdown
    private var projectPicker: some View {
        Menu {
            let activeProjects = vm.sortedActiveProjects
            
            Button {
                vm.showOverview = true
            } label: {
                Label("Overview", systemImage: vm.showOverview ? "checkmark" : "house")
            }
            
            Divider()
            
            ForEach(activeProjects) { project in
                Button {
                    vm.selectedProjectId = project.id
                    vm.showOverview = false
                } label: {
                    Label(
                        project.title,
                        systemImage: !vm.showOverview && vm.selectedProjectId == project.id ? "checkmark" : ""
                    )
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: vm.showOverview ? "house.fill" : "folder.fill")
                    .foregroundStyle(.secondary)
                Text(vm.showOverview ? "Overview" : (vm.selectedProject?.title ?? "Select Project"))
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
    }
    
    // Search field
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.footnote)
            TextField("Search tasks…", text: $vm.searchText)
                .textFieldStyle(.plain)
                .frame(width: 180)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.subtle)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // Owner filter dropdown
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
                if vm.ownerFilter != "all" {
                    Text(vm.ownerFilter.capitalized)
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(vm.ownerFilter != "all" ? Color.accentColor.opacity(0.12) : Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    // Shape filter dropdown
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
                if let shape = vm.shapeFilter {
                    Text("\(shapeIcon(shape)) \(shapeLabel(shape))")
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(vm.shapeFilter != nil ? Color.accentColor.opacity(0.12) : Theme.subtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    // Overview content showing project grid
    private var overviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("All Projects")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
                ], spacing: 16) {
                    ForEach(vm.sortedActiveProjects) { project in
                        ProjectCard(project: project) {
                            vm.selectedProjectId = project.id
                            vm.showOverview = false
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Helper functions for shape icons and labels
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

// Simple project card for overview
private struct ProjectCard: View {
    let project: Project
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: projectIcon)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if project.archived == true {
                        Image(systemName: "archivebox")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                if let notes = project.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(height: 140)
    }
    
    private var projectIcon: String {
        switch project.resolvedType {
        case .kanban: return "list.bullet.rectangle"
        case .research: return "doc.text.magnifyingglass"
        case .tracker: return "chart.bar"
        }
    }
}

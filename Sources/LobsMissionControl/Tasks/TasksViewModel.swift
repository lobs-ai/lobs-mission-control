import Foundation
import SwiftUI

/// ViewModel for Tasks & Projects - manages kanban boards, task lifecycle, and project organization
@MainActor
final class TasksViewModel: ObservableObject {
    
    // MARK: - Published State
    
    // Tasks
    @Published var tasks: [DashboardTask] = [] {
        didSet { invalidateFilteredTasksCache() }
    }
    @Published var selectedTaskId: String? = nil
    @Published var multiSelectedTaskIds: Set<String> = []
    
    // Projects
    @Published var projects: [Project] = []
    @Published var selectedProjectId: String = "default"
    @Published var projectReadme: String = ""
    @Published var projectLastCommitAt: [String: Date] = [:]
    
    // Templates
    @Published var templates: [TaskTemplate] = []
    
    // Filters & Search
    @Published var searchText: String = "" {
        didSet { invalidateFilteredTasksCache() }
    }
    @Published var showInboxOnly: Bool = false {
        didSet { invalidateFilteredTasksCache() }
    }
    @Published var ownerFilter: String = "all" {
        didSet { invalidateFilteredTasksCache() }
    }
    @Published var shapeFilter: TaskShape? = nil {
        didSet { invalidateFilteredTasksCache() }
    }
    
    // UI State
    @Published var artifactText: String = "(select a task)"
    @Published var isGitBusy: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Dependencies
    
    private let apiService: APIService
    
    // Cached filtered tasks for performance
    private var _cachedFilteredTasks: [DashboardTask] = []
    private var _filteredTasksCacheValid: Bool = false
    
    // Pending task creates (outbox for offline resilience)
    private var pendingTaskCreates: [PendingTaskCreate] = []
    
    // MARK: - Initialization
    
    init(apiService: APIService) {
        self.apiService = apiService
        loadPendingTaskCreates()
        loadTemplates()
    }
    
    // MARK: - Computed Properties
    
    var isMultiSelectActive: Bool {
        !multiSelectedTaskIds.isEmpty
    }
    
    var selectedProject: Project? {
        projects.first(where: { $0.id == selectedProjectId })
    }
    
    var filteredTasks: [DashboardTask] {
        if !_filteredTasksCacheValid {
            recomputeFilteredTasks()
        }
        return _cachedFilteredTasks
    }
    
    var columns: [AnyTaskColumn] {
        let activeCol = AnyTaskColumn(title: "Active", dropStatus: .active) { t in
            t.status.isBoardActive
        }
        
        return [
            activeCol,
            .init(title: "Done", dropStatus: .completed) { t in
                t.status == .completed
            },
            .init(title: "Rejected", dropStatus: .rejected) { $0.status == .rejected },
        ]
    }
    
    // MARK: - Data Loading
    
    func loadTasks() async {
        do {
            let loadedTasks = try await apiService.fetchTasks()
            await MainActor.run {
                self.tasks = loadedTasks
                self.sortTasksForUX(&self.tasks)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load tasks: \(error.localizedDescription)"
            }
        }
    }
    
    func loadProjects() async {
        do {
            let loadedProjects = try await apiService.fetchProjects()
            await MainActor.run {
                self.projects = loadedProjects
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load projects: \(error.localizedDescription)"
            }
        }
    }
    
    func loadTemplates() {
        // TODO: Implement template loading from disk
        // For now, use empty array
        templates = []
    }
    
    func loadProjectReadme() {
        guard selectedProjectId != "default" else {
            projectReadme = ""
            return
        }
        
        Task {
            do {
                let content = try await apiService.loadProjectReadme(projectId: selectedProjectId)
                await MainActor.run {
                    self.projectReadme = content
                }
            } catch {
                await MainActor.run {
                    self.projectReadme = ""
                }
            }
        }
    }
    
    // MARK: - Task Actions
    
    func approveSelected(autoPush: Bool = true) {
        guard let id = selectedTaskId else { return }
        optimisticUpdate(taskId: id) {
            $0.reviewState = .approved
            $0.status = .active
            $0.workState = .notStarted
            if $0.startedAt == nil { $0.startedAt = Date() }
        }
    }
    
    func requestChangesSelected(autoPush: Bool = true) {
        guard let id = selectedTaskId else { return }
        optimisticUpdate(taskId: id) { $0.reviewState = .changesRequested }
    }
    
    func rejectSelected(autoPush: Bool = true) {
        guard let id = selectedTaskId else { return }
        optimisticUpdate(taskId: id) {
            $0.reviewState = .rejected
            $0.status = .rejected
        }
    }
    
    func completeSelected(autoPush: Bool = true) {
        guard let id = selectedTaskId else { return }
        optimisticUpdate(taskId: id) {
            $0.status = .completed
            $0.workState = nil
            if $0.finishedAt == nil { $0.finishedAt = Date() }
        }
        autoUnblockDependents(of: id, autoPush: autoPush)
    }
    
    func markDoneSelected(autoPush: Bool = true) {
        guard let id = selectedTaskId else { return }
        optimisticUpdate(taskId: id) {
            $0.status = .completed
            $0.reviewState = .approved
            $0.workState = nil
        }
    }
    
    func reopenSelected(autoPush: Bool = true) {
        guard let id = selectedTaskId else { return }
        optimisticUpdate(taskId: id) {
            $0.status = .active
            $0.workState = .notStarted
            $0.reviewState = .approved
        }
    }
    
    func toggleBlockSelected(autoPush: Bool = true) {
        guard let id = selectedTaskId else { return }
        let currentlyBlocked = tasks.first(where: { $0.id == id })?.workState == .blocked
        let newState: WorkState = currentlyBlocked ? .inProgress : .blocked
        optimisticUpdate(taskId: id) { $0.workState = newState }
    }
    
    func submitTaskToLobs(
        title: String,
        notes: String?,
        agent: String?,
        projectId: String?,
        autoPush: Bool = true,
        modelTier: String? = nil
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else { return }
        
        let effectiveProjectId = projectId ?? (projects.contains(where: { $0.id == selectedProjectId }) ? selectedProjectId : nil)
        
        let now = Date()
        let newTask = DashboardTask(
            id: UUID().uuidString,
            title: trimmedTitle,
            status: .active,
            owner: .lobs,
            createdAt: now,
            updatedAt: now,
            workState: .notStarted,
            reviewState: .approved,
            projectId: effectiveProjectId,
            artifactPath: nil,
            notes: trimmedNotes,
            startedAt: now,
            finishedAt: nil,
            agent: agent,
            trackingMode: nil,
            githubIssueNumber: nil,
            githubIssueUrl: nil,
            githubIssueState: nil,
            githubSyncedAt: nil,
            workspaceContext: nil,
            userContext: nil,
            modelTier: modelTier
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            tasks.append(newTask)
            sortTasksForUX(&tasks)
        }
        
        selectedTaskId = newTask.id
        
        // Persist to server
        Task {
            do {
                let created = try await apiService.createTask(task: newTask)
                await MainActor.run {
                    // Update with server response
                    if let idx = self.tasks.firstIndex(where: { $0.id == newTask.id }) {
                        self.tasks[idx] = created
                    }
                    self.successMessage = "Task created"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create task: \(error.localizedDescription)"
                    // Remove optimistically added task on failure
                    self.tasks.removeAll { $0.id == newTask.id }
                }
            }
        }
    }
    
    func deleteTask(taskId: String) {
        // Optimistically remove
        tasks.removeAll { $0.id == taskId }
        
        Task {
            do {
                try await apiService.deleteTask(taskId: taskId)
                await MainActor.run {
                    self.successMessage = "Task deleted"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete task: \(error.localizedDescription)"
                    // Force reload on failure
                    Task { await self.loadTasks() }
                }
            }
        }
    }
    
    func updateTaskTitleAndNotes(taskId: String, title: String, notes: String?) {
        editTask(taskId: taskId, title: title, notes: notes, autoPush: true)
    }
    
    func editTask(taskId: String, title: String, notes: String?, autoPush: Bool = true) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        optimisticUpdate(taskId: taskId) {
            $0.title = trimmedTitle
            $0.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    func moveTask(taskId: String, to status: TaskStatus) {
        optimisticUpdate(taskId: taskId) { $0.status = status }
    }
    
    func reorderTask(taskId: String, to status: TaskStatus, beforeTaskId: String?) {
        // Get tasks in this column sorted by current order
        var columnTasks = filteredTasks.filter { t in
            switch status {
            case .active:
                return t.status.isBoardActive
            case .completed: return t.status == .completed
            case .rejected: return t.status == .rejected
            default: return t.status == status
            }
        }
        
        // Remove the dragged task from column if already there
        columnTasks.removeAll { $0.id == taskId }
        
        // Insert at position
        if let beforeId = beforeTaskId,
           let idx = columnTasks.firstIndex(where: { $0.id == beforeId }) {
            // Create a placeholder task for insertion
            let placeholder = DashboardTask(
                id: taskId,
                title: "",
                status: status,
                owner: .lobs,
                createdAt: Date(),
                updatedAt: Date()
            )
            columnTasks.insert(placeholder, at: idx)
        } else {
            let placeholder = DashboardTask(
                id: taskId,
                title: "",
                status: status,
                owner: .lobs,
                createdAt: Date(),
                updatedAt: Date()
            )
            columnTasks.append(placeholder)
        }
        
        // Assign sortOrder
        for (i, t) in columnTasks.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == t.id }) {
                tasks[idx].sortOrder = i
                tasks[idx].status = status
            }
        }
        
        // Persist all affected tasks via API
        Task {
            do {
                for t in columnTasks {
                    if let task = tasks.first(where: { $0.id == t.id }) {
                        try await apiService.setStatus(taskId: task.id, status: task.status)
                        try await apiService.setSortOrder(taskId: task.id, sortOrder: task.sortOrder)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save reorder: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Multi-Select
    
    func toggleMultiSelect(taskId: String) {
        if multiSelectedTaskIds.contains(taskId) {
            multiSelectedTaskIds.remove(taskId)
        } else {
            multiSelectedTaskIds.insert(taskId)
        }
    }
    
    func clearMultiSelect() {
        multiSelectedTaskIds.removeAll()
    }
    
    // MARK: - Bulk Actions
    
    func bulkMoveSelected(to status: TaskStatus) {
        guard !multiSelectedTaskIds.isEmpty else { return }
        let ids = multiSelectedTaskIds
        
        withAnimation(.easeInOut(duration: 0.25)) {
            for id in ids {
                if let idx = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[idx].status = status
                    if status == .completed {
                        tasks[idx].workState = nil
                        if tasks[idx].finishedAt == nil { tasks[idx].finishedAt = Date() }
                    } else if status == .active {
                        tasks[idx].workState = .notStarted
                        if tasks[idx].startedAt == nil { tasks[idx].startedAt = Date() }
                    }
                }
            }
        }
        
        // Persist via API
        Task {
            do {
                for id in ids {
                    if let task = tasks.first(where: { $0.id == id }) {
                        try await apiService.saveExistingTask(task)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save bulk move: \(error.localizedDescription)"
                }
            }
        }
        
        clearMultiSelect()
        
        // Auto-unblock dependents for completed tasks
        if status == .completed {
            for id in ids {
                autoUnblockDependents(of: id, autoPush: true)
            }
        }
    }
    
    func bulkApproveSelected() {
        guard !multiSelectedTaskIds.isEmpty else { return }
        let ids = multiSelectedTaskIds
        
        for id in ids {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    tasks[idx].reviewState = .approved
                    tasks[idx].status = .active
                    tasks[idx].workState = .notStarted
                    tasks[idx].updatedAt = Date()
                    if tasks[idx].startedAt == nil { tasks[idx].startedAt = Date() }
                }
            }
        }
        
        Task {
            do {
                for id in ids {
                    if let task = tasks.first(where: { $0.id == id }) {
                        try await apiService.saveExistingTask(task)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save bulk approve: \(error.localizedDescription)"
                }
            }
        }
        
        clearMultiSelect()
    }
    
    func bulkRejectSelected() {
        guard !multiSelectedTaskIds.isEmpty else { return }
        let ids = multiSelectedTaskIds
        
        for id in ids {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    tasks[idx].reviewState = .rejected
                    tasks[idx].status = .rejected
                    tasks[idx].updatedAt = Date()
                }
            }
        }
        
        Task {
            do {
                for id in ids {
                    if let task = tasks.first(where: { $0.id == id }) {
                        try await apiService.saveExistingTask(task)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save bulk reject: \(error.localizedDescription)"
                }
            }
        }
        
        clearMultiSelect()
    }
    
    // MARK: - Task Properties
    
    func setTaskShape(taskId: String, shape: TaskShape?, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) { $0.shape = shape }
    }
    
    func setTaskAgent(taskId: String, agent: String?, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) { $0.agent = agent }
    }
    
    func togglePinTask(taskId: String, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) {
            $0.pinned = !($0.pinned ?? false)
        }
    }
    
    func startTimer(taskId: String, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) {
            $0.startedAt = Date()
            $0.finishedAt = nil
        }
    }
    
    func stopTimer(taskId: String, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) {
            $0.finishedAt = Date()
        }
    }
    
    func resetTimer(taskId: String, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) {
            $0.startedAt = nil
            $0.finishedAt = nil
        }
    }
    
    // MARK: - Dependencies
    
    func addBlocker(taskId: String, blockerTaskId: String, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) {
            var blockers = $0.blockedBy ?? []
            if !blockers.contains(blockerTaskId) {
                blockers.append(blockerTaskId)
                $0.blockedBy = blockers
            }
        }
    }
    
    func removeBlocker(taskId: String, blockerTaskId: String, autoPush: Bool = true) {
        optimisticUpdate(taskId: taskId) {
            $0.blockedBy?.removeAll { $0 == blockerTaskId }
        }
    }
    
    // MARK: - Projects
    
    func createProject(title: String, notes: String?, type: ProjectType = .kanban) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let id = uniqueProjectId(for: trimmedTitle)
        
        let now = Date()
        let p = Project(
            id: id,
            title: trimmedTitle,
            createdAt: now,
            updatedAt: now,
            notes: (trimmedNotes?.isEmpty == true) ? nil : trimmedNotes,
            archived: false,
            type: type
        )
        projects.append(p)
        selectedProjectId = p.id
        
        Task {
            do {
                _ = try await apiService.createProject(id: id, title: trimmedTitle, type: type, notes: trimmedNotes)
                
                if let notes = trimmedNotes, !notes.isEmpty {
                    try await apiService.saveProjectReadme(projectId: id, content: notes)
                }
                
                await MainActor.run {
                    self.successMessage = "Project created"
                    Task { await self.loadProjects() }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func renameProject(id: String, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].title = trimmed
            projects[idx].updatedAt = Date()
        }
        
        Task {
            do {
                try await apiService.renameProject(id: id, newTitle: trimmed)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to rename project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func updateProjectNotes(id: String, notes: String?) {
        let clean = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].notes = (clean?.isEmpty == true) ? nil : clean
            projects[idx].updatedAt = Date()
        }
        
        if id == selectedProjectId {
            projectReadme = clean ?? ""
        }
        
        Task {
            do {
                try await apiService.updateProjectNotes(id: id, notes: clean)
                try await apiService.saveProjectReadme(projectId: id, content: clean ?? "")
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func saveProjectReadme(content: String) {
        guard selectedProjectId != "default" else { return }
        
        projectReadme = content
        
        Task {
            do {
                try await apiService.saveProjectReadme(projectId: selectedProjectId, content: content)
                await MainActor.run {
                    self.successMessage = "README saved"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save README: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteProject(id: String) {
        guard id != "default" else { return }
        
        projects.removeAll { $0.id == id }
        
        if selectedProjectId == id {
            selectedProjectId = "default"
        }
        
        Task {
            do {
                try await apiService.deleteProject(id: id)
                await MainActor.run {
                    self.successMessage = "Project deleted"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete project: \(error.localizedDescription)"
                    Task { await self.loadProjects() }
                }
            }
        }
    }
    
    func archiveProject(id: String) {
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].archived = true
            projects[idx].updatedAt = Date()
        }
        
        Task {
            do {
                try await apiService.archiveProject(id: id)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to archive project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func unarchiveProject(id: String) {
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].archived = false
            projects[idx].updatedAt = Date()
        }
        
        Task {
            do {
                try await apiService.unarchiveProject(id: id)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to unarchive project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Templates
    
    func saveTemplate(_ template: TaskTemplate) {
        // TODO: Implement template persistence
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.append(template)
        }
    }
    
    func stampTemplate(_ template: TaskTemplate, autoPush: Bool = true) {
        for item in template.items {
            submitTaskToLobs(
                title: item.title,
                notes: item.notes,
                agent: nil,
                projectId: selectedProjectId,
                autoPush: autoPush
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func optimisticUpdate(taskId: String, mutation: (inout DashboardTask) -> Void) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[idx]
        mutation(&task)
        task.updatedAt = Date()
        tasks[idx] = task
        
        // Persist to server
        Task {
            do {
                try await apiService.saveExistingTask(task)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save task: \(error.localizedDescription)"
                    // Reload on failure
                    Task { await self.loadTasks() }
                }
            }
        }
    }
    
    private func autoUnblockDependents(of completedTaskId: String, autoPush: Bool) {
        // Find all tasks that are blocked by this task
        for idx in tasks.indices {
            if let blockers = tasks[idx].blockedBy, blockers.contains(completedTaskId) {
                tasks[idx].blockedBy?.removeAll { $0 == completedTaskId }
                
                // If no more blockers, auto-approve if still in inbox
                if tasks[idx].blockedBy?.isEmpty == true, tasks[idx].status == .inbox {
                    tasks[idx].reviewState = .approved
                    tasks[idx].status = .active
                    tasks[idx].workState = .notStarted
                }
                
                // Persist change
                let task = tasks[idx]
                Task {
                    try? await apiService.saveExistingTask(task)
                }
            }
        }
    }
    
    private func sortTasksForUX(_ tasks: inout [DashboardTask]) {
        tasks.sort { a, b in
            // Pinned first
            let ap = a.pinned ?? false
            let bp = b.pinned ?? false
            if ap != bp { return ap }
            
            // Then by sortOrder if present
            if let ao = a.sortOrder, let bo = b.sortOrder {
                return ao < bo
            }
            
            // Then by creation date (newest first)
            return a.createdAt > b.createdAt
        }
    }
    
    private func invalidateFilteredTasksCache() {
        _filteredTasksCacheValid = false
    }
    
    private func recomputeFilteredTasks() {
        var out = tasks
        
        // Project scoping
        out = out.filter { t in
            (t.projectId ?? "default") == selectedProjectId
        }
        
        // Inbox is a filter, not a column
        if showInboxOnly {
            out = out.filter { $0.status == .inbox }
        } else {
            out = out.filter { $0.status != .inbox }
        }
        
        // Search filter
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            out = out.filter { t in
                let hay = (t.title + "\n" + (t.notes ?? "")).lowercased()
                return hay.contains(q)
            }
        }
        
        // Owner filter
        switch ownerFilter {
        case "lobs":
            out = out.filter { if case .lobs = $0.resolvedOwner { return true } else { return false } }
        case "rafe":
            out = out.filter { if case .rafe = $0.resolvedOwner { return true } else { return false } }
        case "other":
            out = out.filter { if case .other = $0.resolvedOwner { return true } else { return false } }
        default:
            break
        }
        
        // Shape filter
        if let shapeFilter {
            out = out.filter { $0.shape == shapeFilter }
        }
        
        // Pinned tasks float to top within their column grouping
        out.sort { a, b in
            let ap = a.pinned ?? false
            let bp = b.pinned ?? false
            if ap != bp { return ap }
            return false // preserve existing order for non-pinned
        }
        
        _cachedFilteredTasks = out
        _filteredTasksCacheValid = true
    }
    
    private func uniqueProjectId(for title: String) -> String {
        let base = title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        
        var candidate = base
        var counter = 1
        
        while projects.contains(where: { $0.id == candidate }) {
            candidate = "\(base)-\(counter)"
            counter += 1
        }
        
        return candidate
    }
    
    private func loadPendingTaskCreates() {
        // TODO: Implement pending task creates loading from disk
        pendingTaskCreates = []
    }
    
    private func savePendingTaskCreates() {
        // TODO: Implement pending task creates persistence
    }
}

// MARK: - Helper Struct

private struct PendingTaskCreate: Codable {
    let id: String
    let title: String
    let notes: String?
    let agent: String?
    let projectId: String?
    let createdAt: Date
}

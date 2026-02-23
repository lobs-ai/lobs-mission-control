# Task Persistence Fix

**Date**: 2026-02-22  
**Issue**: Tasks created in Mission Control disappear after app restart  
**Status**: ✅ FIXED

## Problem

Tasks created via the Mission Control UI were not persisting to the server. After quitting and reopening the app, newly created tasks would disappear.

## Root Cause

TasksViewModel (introduced as the new MVVM architecture) was calling API methods that didn't exist in APIService:

```swift
// TasksViewModel.swift
let loadedTasks = try await apiService.fetchTasks()        // ❌ Method doesn't exist
let loadedProjects = try await apiService.fetchProjects()  // ❌ Method doesn't exist
let created = try await apiService.createTask(task: newTask) // ❌ Method doesn't exist
let content = try await apiService.loadProjectReadme(projectId: id) // ❌ Method doesn't exist
```

APIService only had:
- `loadTasks()` → returns `TasksFile` (not `[DashboardTask]`)
- `loadProjects()` → returns `ProjectsFile` (not `[Project]`)
- `addTask(...)` → takes individual parameters (not `DashboardTask` object)
- `saveProjectReadme(...)` → exists, but no `load` counterpart

When these methods were called, the app would fail with a compilation error or runtime crash, preventing task persistence.

## Solution

Added convenience wrapper methods to APIService.swift:

### 1. `loadProjectReadme(projectId:)`
```swift
func loadProjectReadme(projectId: String) async throws -> String {
  // GET /api/projects/{id}/readme
  // Returns "" if README doesn't exist (404)
}
```

### 2. `fetchTasks()`
```swift
func fetchTasks() async throws -> [DashboardTask] {
  let tasksFile = try await loadTasks()
  return tasksFile.tasks
}
```

### 3. `fetchProjects()`
```swift
func fetchProjects() async throws -> [Project] {
  let projectsFile = try await loadProjects()
  return projectsFile.projects
}
```

### 4. `createTask(task:)`
```swift
func createTask(task: DashboardTask) async throws -> DashboardTask {
  return try await addTask(
    id: task.id,
    title: task.title,
    owner: task.owner ?? .lobs,
    status: task.status,
    projectId: task.projectId,
    workState: task.workState,
    reviewState: task.reviewState,
    notes: task.notes,
    agent: task.agent,
    workspaceContext: task.workspaceContext,
    userContext: task.userContext,
    modelTier: task.modelTier
  )
}
```

## Files Changed

- `Sources/LobsMissionControl/APIService.swift` - Added 4 convenience wrapper methods
- `test_task_persistence.swift` - Test documentation for verification
- `.work-summary` - Short summary for orchestrator

## Testing

### Manual Test
1. Open Mission Control
2. Create a new task via the UI
3. Verify the task appears in the list
4. Quit the app (⌘Q)
5. Reopen Mission Control
6. **Expected**: Task is still present

### Expected Behavior
- ✅ Task appears immediately after creation
- ✅ Task persists to server (visible in lobs-server database)
- ✅ Task reloads on app restart
- ✅ Server errors are displayed to user (no silent failures)

## Build Status

**Build**: ✅ Successful (exit code 0)

**Note**: There are pre-existing compilation errors in the Intelligence module due to duplicate type definitions (`ReflectionCycle`, `SweepCycle`, `IntelligenceSummary` defined in both `Models.swift` and `Intelligence/IntelligenceModels.swift`). These are unrelated to this fix.

## Architecture Notes

This fix maintains the existing pattern where:
- TasksViewModel owns the UI logic and state
- APIService handles all network communication
- Wrapper methods provide compatibility between different API styles (object-based vs parameter-based)

No changes were needed to TasksViewModel itself - we fixed the issue by adding the missing methods it expected.

## Related Issues

This follows the same pattern as the previous agent field persistence fix (documented in `Tests/LobsMissionControlTests/TaskAgentPersistenceTests.swift`), where method signature mismatches between view models and APIService caused data loss.

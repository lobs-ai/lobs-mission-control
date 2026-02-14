# Fix: Add Task from Project Overview

## Problem
When clicking "Add Task" from a project card in the overview, the app would navigate into that project before opening the add task sheet. This was disruptive to the user flow - they wanted to stay in overview and just create a task in that project.

## User Impact
**Before:**
1. User views project overview
2. Hovers over project card
3. Clicks "Add Task" quick action
4. **App navigates into the project** ❌
5. Add task sheet opens

**After:**
1. User views project overview
2. Hovers over project card
3. Clicks "Add Task" quick action
4. **Stays in overview** ✅
5. Add task sheet opens with project pre-selected

## Root Cause
In `TasksContainerView.swift`, the `onAddTask` closure for `RichProjectCard` was setting:
- `vm.selectedProjectId = project.id`
- `vm.showOverview = false`

This caused the app to navigate into the project before opening the sheet.

## Solution
Introduced a new state variable `taskProjectId` to track which project a task should be created in, separate from the navigation state.

### Changes Made

**1. Added new state variable:**
```swift
@State private var taskProjectId: String? = nil  // Project to create task in
```

**2. Updated AddTaskSheet initialization:**
```swift
.sheet(isPresented: $showAddTask, onDismiss: {
    taskProjectId = nil  // Reset after sheet closes
}) {
    AddTaskSheet(
        vm: vm,
        autoPush: $autoPush,
        projectId: taskProjectId  // Use taskProjectId instead of selectedProjectId
    )
}
```

**3. Fixed RichProjectCard onAddTask:**
```swift
// OLD (caused navigation):
onAddTask: {
    vm.selectedProjectId = project.id
    vm.showOverview = false
    showAddTask = true
}

// NEW (stays in overview):
onAddTask: {
    taskProjectId = project.id
    showAddTask = true
}
```

**4. Updated top bar "Add Task" button:**
```swift
// Set taskProjectId based on current context
taskProjectId = vm.showOverview ? nil : vm.selectedProjectId
showAddTask = true
```

## Architecture
The fix separates two concerns:
1. **Navigation state** - `vm.selectedProjectId` and `vm.showOverview`
2. **Task creation context** - `taskProjectId`

This allows the add task sheet to know which project to pre-select without affecting navigation.

## Behavior Matrix

| Context | Action | Navigation | Task Project |
|---------|--------|------------|--------------|
| Overview | Click project card | Navigate to project | N/A |
| Overview | Click "Add Task" on card | **Stay in overview** ✅ | Pre-select that project |
| Overview | Click top bar "Add Task" | Stay in overview | No project selected |
| Project view | Click top bar "Add Task" | Stay in project | Pre-select current project |

## Edge Cases Handled
1. **Sheet dismissal** - `taskProjectId` resets to `nil` via `onDismiss`
2. **Multiple project cards** - Each card sets `taskProjectId` independently
3. **Context switching** - Top bar respects current view mode
4. **Nil project** - Tasks can be created without project from overview

## Testing
Created comprehensive test suite: `AddTaskProjectPreselectTests.swift`

**Test coverage (14 tests):**
- ✅ Project preselection from overview
- ✅ Project preselection from project view
- ✅ No preselection from overview top bar
- ✅ Task project ID resets after dismiss
- ✅ No navigation when adding from overview
- ✅ Project card click still navigates
- ✅ Multiple project cards work independently
- ✅ Nil project ID handled correctly
- ✅ Complete user flow simulations
- ✅ Regression tests for old buggy behavior

## Files Changed
- `Sources/LobsMissionControl/TasksContainerView.swift` - Core fix (4 changes)
- `Tests/LobsMissionControlTests/UI/AddTaskProjectPreselectTests.swift` - Test suite (247 lines)
- `docs/fixes/ADD_TASK_PROJECT_OVERVIEW_FIX.md` - This document

## Build Status
✅ Build successful (19.56s)
✅ No breaking changes
✅ Backward compatible

## User Experience Impact
**Improvement:** Users can now quickly add tasks to projects while browsing the overview without being pulled out of their browsing flow. This makes task creation much faster and less disruptive, especially when creating multiple tasks across different projects.

**Time saved:** ~2-3 seconds per task (no need to navigate back to overview after each add)

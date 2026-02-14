# Team View - Orchestrator Status Fix

## Problem
The Team view was not correctly tracking and displaying active worker status. It was calling three separate endpoints:
- `/api/worker/status` - for worker info
- `/api/agents` - for agent statuses (but incomplete data)
- `/api/worker/history` - for historical runs

This approach missed key fields like `current_task_id` and `activity` that are only available via the orchestrator's unified status endpoint.

## Solution
Switched to using the orchestrator's unified status endpoint: `/api/orchestrator/status`

This endpoint returns a comprehensive view of the entire system:
```json
{
  "running": bool,
  "paused": bool,
  "worker": {
    "active": bool,
    "workerId": string,
    "currentTask": string,
    "currentProject": string,
    ...
  },
  "agents": {
    "programmer": {
      "agent_type": "programmer",
      "status": "idle|working|thinking|finalizing",
      "activity": "Description of current work",
      "thinking": "Current thinking snippet",
      "current_task_id": "task-123",
      "current_project_id": "proj-456",
      "last_active_at": "ISO8601",
      "last_completed_task_id": "task-789",
      "last_completed_at": "ISO8601",
      "stats": {...}
    },
    ...
  },
  "poll_interval": int
}
```

## Changes Made

### 1. Models.swift
Added `OrchestratorStatus` struct:
```swift
struct OrchestratorStatus: Codable {
  var running: Bool
  var paused: Bool
  var worker: WorkerStatus?
  var agents: [String: AgentStatus]
  var pollInterval: Int?
}
```

### 2. APIService.swift
Added unified status method:
```swift
func loadOrchestratorStatus() async throws -> OrchestratorStatus {
  return try await request(
    method: "GET",
    path: "/api/orchestrator/status"
  )
}
```

### 3. TeamViewModel.swift
Updated `refresh()` to use the new endpoint:
```swift
func refresh() async {
  isLoading = true
  error = nil
  
  do {
    // Load orchestrator status (includes worker + agents in one call)
    async let orchestratorStatus = try apiService.loadOrchestratorStatus()
    async let history = try apiService.loadWorkerHistory()
    
    let status = try await orchestratorStatus
    agentStatuses = status.agents
    workerStatus = status.worker
    workerHistory = try await history
  } catch {
    self.error = error.localizedDescription
  }
  
  isLoading = false
}
```

### 4. Tests
Created `TeamViewStatusTests.swift` with 11 test cases:
- OrchestratorStatus decoding
- AgentStatus with active task
- AgentStatus idle state
- WorkerStatus active/inactive
- Multiple agents
- Edge cases (paused orchestrator, etc.)

## Benefits

1. **Accurate real-time status**: Now shows exactly what agents are working on
2. **Reduced API calls**: One call instead of two for worker+agent data
3. **Consistent data**: All status comes from the same source (orchestrator)
4. **Better UX**: Users see current task IDs and activity descriptions in real-time

## UI Impact

The `AgentCardView` already had support for displaying:
- `currentTaskId` - shown in the card when an agent is working
- `activity` - displayed as "Current Activity" section
- `status` - used for badge coloring (working/idle/thinking)

These fields were not being populated before because the old `/api/agents` endpoint didn't include them. Now they work correctly.

## Polling Frequency

The Team view polls every 5 seconds (configured in `TeamViewModel.startRefreshing()`), ensuring near-real-time updates of agent activity.

## Related Files
- `Sources/LobsMissionControl/Models.swift`
- `Sources/LobsMissionControl/APIService.swift`
- `Sources/LobsMissionControl/Team/TeamViewModel.swift`
- `Sources/LobsMissionControl/Team/AgentCardView.swift` (no changes needed)
- `Tests/LobsMissionControlTests/UI/TeamViewStatusTests.swift`

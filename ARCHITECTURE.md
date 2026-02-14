# Architecture — Lobs Mission Control

High-level overview of the app structure, data flow, and key components.

## App Structure

```
┌─────────────────────────────────────────────────────────┐
│  LobsMissionControlApp                                  │
│  ├─ AppViewModel (@StateObject, injected globally)      │
│  ├─ OrchestratorManager (@StateObject)                  │
│  └─ MainView / OnboardingView                           │
└─────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼─────┐    ┌──────▼──────┐   ┌─────▼──────┐
   │ Sidebar  │    │   Detail    │   │  Modals    │
   │  Nav     │    │   Views     │   │  & Sheets  │
   └──────────┘    └─────────────┘   └────────────┘
```

**Sidebar sections:**
- Command Center (dashboard)
- Tasks (kanban boards per project)
- Inbox (agent proposals)
- Chat (WebSocket messaging)
- Memory (personal knowledge)
- Knowledge/Topics (research workspaces)
- Work Tracker (session timeline)
- Team (agent grid)
- Calendar (events & schedule)
- Status (health & analytics)

**Detail views:**
Each section has a dedicated view (e.g., `CommandCenterView`, `TasksView`, `ChatView`) that renders based on `vm.selectedTab`.

## Data Flow

```
┌──────────────┐
│    User      │
│  Interaction │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│           SwiftUI Views                      │
│  • Read: @EnvironmentObject var vm          │
│  • Write: vm.someProperty = ...              │
│  • Actions: vm.createTask(), vm.sendChat()   │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│          AppViewModel (@MainActor)           │
│  • Central state holder                      │
│  • @Published properties trigger UI updates  │
│  • Owns APIService instance                  │
│  • Coordinates WebSocket, polling, caching   │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│            APIService                        │
│  • REST API calls (async/await)              │
│  • WebSocket client (chat, live updates)     │
│  • JSON encoding/decoding                    │
│  • Error handling & retries                  │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│          lobs-server (FastAPI)               │
│  • Task orchestration                        │
│  • Agent coordination                        │
│  • Memory & knowledge storage                │
│  • Calendar integration                      │
│  • WebSocket relay                           │
└──────────────────────────────────────────────┘
```

## Key Components

### AppViewModel
**Role:** Central state manager (MVVM pattern)  
**Responsibilities:**
- Holds all app state (`@Published` properties)
- Owns single `APIService` instance
- Coordinates polling, WebSocket, background tasks
- Manages cache invalidation
- Persists config to disk

**Key properties:**
- `tasks`, `projects`, `agents`, `inbox`, `memories`, `chatMessages`
- `selectedTab`, `selectedProject`, `selectedTaskStatus`
- `config` (server URL, API token)

### APIService
**Role:** Network layer abstraction  
**Responsibilities:**
- HTTP requests via `URLSession` (REST API)
- WebSocket connection (`URLSessionWebSocketTask`)
- JSON encoding/decoding with `.convertFromSnakeCase`
- Error handling, retries, auth headers

**Key methods:**
- `fetchTasks()`, `createTask()`, `updateTask()`, `deleteTask()`
- `fetchProjects()`, `fetchAgents()`, `fetchInbox()`
- `sendChatMessage()`, `connectWebSocket()`, `disconnectWebSocket()`

### Models (Models.swift)
**Core models:**
- `Task`, `Project`, `Agent`, `InboxItem`, `Memory`, `ChatMessage`
- `WorkSession`, `Event`, `Topic`, `Document`

All models:
- Conform to `Codable` (JSON serialization)
- Use Swift naming conventions (camelCase)
- Decoded automatically from snake_case API responses

### CacheManager
**Role:** Local persistence for offline resilience  
**Responsibilities:**
- Cache API responses to disk
- Serve cached data when offline
- Invalidate on successful API updates

### OrchestratorManager
**Role:** Monitor lobs-orchestrator daemon status  
**Responsibilities:**
- Poll `/api/orchestrator/status`
- Display worker queue, active tasks
- Provide pause/resume controls

## Navigation Structure

```swift
NavigationSplitView {
    // Sidebar
    List(selection: $vm.selectedTab) {
        NavigationLink("Command Center", value: SelectedTab.commandCenter)
        NavigationLink("Tasks", value: SelectedTab.tasks)
        NavigationLink("Inbox", value: SelectedTab.inbox)
        // ... etc
    }
} detail: {
    // Detail view based on selection
    switch vm.selectedTab {
    case .commandCenter: CommandCenterView()
    case .tasks: TasksView()
    case .inbox: InboxView()
    // ... etc
    }
}
```

**Benefits:**
- Native macOS sidebar behavior
- State restoration (selected tab persisted)
- Deep linking support (future)

## WebSocket Real-Time Updates

```
User sends chat → ChatView → vm.sendChatMessage()
                                    ↓
                              APIService.sendMessage()
                                    ↓
                            WebSocket → lobs-server
                                    ↓
                     Server broadcasts response
                                    ↓
                     APIService receives message
                                    ↓
               Delegates to AppViewModel.handleWebSocketMessage()
                                    ↓
                        vm.chatMessages.append(newMessage)
                                    ↓
                       SwiftUI auto-updates ChatView
```

**Key points:**
- WebSocket lifecycle managed in APIService
- Messages forwarded to AppViewModel
- `@Published` properties trigger view updates
- Reconnect logic handles network interruptions

## Onboarding Flow

First-run experience to configure server connection:

1. **OnboardingView** (container)
2. **OnboardingServerSetupView** (enter URL + token)
3. **OnboardingVerificationView** (test connection)
4. **OnboardingDoneView** (success)

Config saved to `~/Library/Application Support/LobsMissionControl/config.json`.

## Feature Modules

### Calendar
- **CalendarView:** Month/week views, event list
- **CalendarViewModel:** Fetch events, filter by date
- Integration with lobs-server `/api/calendar/*` endpoints

### Memory
- **MemoryView:** Timeline browser with search
- **MemorySearchView:** Full-text search across memories
- **MemoryViewModel:** CRUD operations, caching

### Chat
- **ChatView:** Message list + input field
- WebSocket-driven real-time updates
- Markdown rendering for rich content

### Status
- **StatusView:** System health dashboard
- **AIUsageView:** Token usage & cost analytics
- **ActivityFeedView:** Recent work activity

### Team
- **AgentGridView:** Live agent status cards
- **WorkTrackerView:** Timeline of completed work sessions
- **AgentDetailSheet:** Deep dive into agent history

## Performance Considerations

- **Lazy loading:** Use `LazyVStack` for long lists
- **Caching:** CacheManager reduces redundant API calls
- **Debouncing:** Search inputs debounced to reduce API load
- **Pagination:** Large datasets fetched in chunks (when supported)

## Security

- **API token:** Stored in local config file (macOS keychain integration planned)
- **Tailscale:** Network traffic over encrypted Tailscale mesh
- **No secrets in code:** Server URL and token configured at runtime

---

**This architecture is designed for:**
- **Clarity:** Single source of truth (AppViewModel)
- **Maintainability:** Clear separation of concerns
- **Testability:** APIService and ViewModels are testable in isolation
- **Extensibility:** New features add views + update AppViewModel

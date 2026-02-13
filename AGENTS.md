# AGENTS.md — Lobs Mission Control

## What This Is
Rafe's second brain — a macOS SwiftUI app that serves as a command center for everything: tasks, memories, documents, chat, research, system status. Pure REST API client connecting to lobs-server.

## Quick Start
```bash
cd ~/lobs-mission-control
swift build
swift run
```

## Architecture
```
Lobs Mission Control (SwiftUI)
│
├── APIService.swift          — All REST API communication
├── AppViewModel.swift        — Main state management
├── ContentView.swift         — Root view, sidebar navigation
│
├── CommandCenterView.swift   — Home screen (at-a-glance everything)
├── BoardView.swift           — Kanban task management
├── Chat/                     — Real-time messaging
├── Memory/                   — Second brain (browse, search, capture)
├── Status/                   — System health dashboard
├── DocumentsView.swift       — Document browser
├── ResearchView.swift        — Research workspace
├── InboxView.swift           — Action items from agents
├── SettingsView.swift        — Server URL, API token, preferences
│
├── Config/                   — AppConfig, ConfigManager, UserSettings
├── Models.swift              — Data models (Task, Project, etc.)
└── Store.swift               — Legacy (dormant, kept as fallback)
```

## Sections
| Section | View | Icon | Purpose |
|---------|------|------|---------|
| Home | CommandCenterView | house | At-a-glance: "While You Were Away", active tasks, inbox, quick actions |
| Chat | Chat/ChatView | message | Real-time messaging with Lobs via WebSocket |
| Tasks | BoardView | checklist | Kanban boards, task CRUD per project |
| Memory | Memory/MemoryView | brain | Browse, search, edit memories; quick capture |
| Documents | DocumentsView | doc.text | Reports, research docs, deliverables |
| Research | ResearchView | magnifyingglass | Research workspaces with notes, sources, findings |
| Inbox | InboxView | tray | Proposals, suggestions, decisions from agents |
| Status | Status/StatusView | chart.bar | Server health, orchestrator, workers, activity, costs |
| Settings | SettingsView | gear | Server URL, API token, preferences |

## Key Files

### Core
- **APIService.swift** — REST client, all server communication, Bearer token auth
- **AppViewModel.swift** — Main ObservableObject, coordinates all data loading
- **ContentView.swift** — Root view with sidebar navigation
- **Models.swift** — Shared data models (Task, Project, DashboardTask, etc.)

### Chat System (Chat/)
- **ChatService.swift** — WebSocket client (URLSessionWebSocketTask), auto-reconnect, heartbeat
- **ChatViewModel.swift** — Chat state (messages, sessions, typing indicators)
- **ChatView.swift** — Main chat container with message list, input bar
- **ChatMessageView.swift** — Message bubbles (user right/blue, agent left/gray)
- **ChatInputView.swift** — Text input with send button
- **ChatSessionPicker.swift** — Session tabs with "+" for new session
- **ChatModels.swift** — Chat data structures

### Memory System (Memory/)
- **MemoryViewModel.swift** — Memory state, CRUD, search, capture
- **MemoryView.swift** — 3-column layout (list, viewer/editor, quick capture)
- **MemorySearchView.swift** — Search with snippets
- **MemoryTimelineView.swift** — Chronological timeline grouped by month
- **MemoryModels.swift** — MemoryItem, MemoryDetail, MemorySearchResult

### Status System (Status/)
- **StatusViewModel.swift** — System health state, auto-refresh 30s
- **StatusView.swift** — Health cards, activity feed, cost summary
- **StatusModels.swift** — SystemOverview, ActivityEvent, CostSummary

### Config (Config/)
- **AppConfig.swift** — Server URL, API token, preferences
- **ConfigManager.swift** — Read/write config to disk
- **UserSettings.swift** — User preferences

## Authentication
- API token stored in AppConfig (set in Settings)
- APIService sends `Authorization: Bearer <token>` on all requests
- WebSocket passes token as query param (`?token=...`)
- Health endpoint doesn't require auth (for connection testing)
- Token generated server-side: `python scripts/generate_token.py mission-control`

## Server Connection
- Connects to lobs-server over Tailscale (private network)
- Server URL configurable in Settings with connection test
- No local persistence — all state from API
- Graceful handling of disconnects (error banner, auto-retry)

## Common Edits
- **Add a section**: Create SwiftUI view, add to ContentView sidebar, add API methods to APIService
- **Add an API call**: Add method to APIService.swift, call from relevant ViewModel
- **Add a model**: Update Models.swift or create section-specific models
- **Change server behavior**: Edit lobs-server (separate repo)

## Testing
```bash
swift test                              # App tests
cd ~/lobs-server && python -m pytest    # Server tests
```

## Dependencies
- Pure SwiftUI + AppKit — no external packages
- Requires macOS 13+

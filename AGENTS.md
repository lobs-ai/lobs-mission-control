# Lobs Mission Control — Agent Guide

macOS SwiftUI app — Rafe's second brain and command center. Tasks, memories, documents, chat, research — everything in one place.

## Quick Start
```bash
swift build
swift run
```

## Architecture

### API-First Design
Mission Control is a **REST API client** — all state lives in lobs-server (FastAPI + SQLite). No local persistence or git-based state management.

```
Mission Control (SwiftUI) ←→ lobs-server (REST API over Tailscale) ←→ SQLite DB
                                       ↕
                              Orchestrator (built-in)
                                       ↕
                              OpenClaw (agent runtime)
```

### Key Files
```
Sources/LobsMissionControl/
├── Models.swift              # Data models
├── APIService.swift          # REST API client (all server communication)
├── AppViewModel.swift        # Main view model (state, CRUD via API)
├── ContentView.swift         # Root view (sidebar, navigation)
├── BoardView.swift           # Kanban board (task columns)
├── OverviewView.swift        # Dashboard home (stats, activity)
├── ResearchView.swift        # Research workspace
├── InboxView.swift           # Inbox for artifacts
├── DocumentsView.swift       # Document browser
├── SettingsView.swift        # Settings (server URL, connection test)
├── Chat/                     # Real-time chat system
│   ├── ChatModels.swift      # Chat data models
│   ├── ChatService.swift     # WebSocket client
│   ├── ChatViewModel.swift   # Chat state management
│   ├── ChatView.swift        # Main chat UI
│   ├── ChatMessageView.swift # Message bubbles
│   ├── ChatInputView.swift   # Text input
│   └── ChatSessionPicker.swift # Session tabs
└── ...
```

### Sections
- **Overview** — Stats, activity feed, project cards
- **Board** — Kanban task management per project
- **Research** — Research workspace with notes, sources, findings
- **Documents** — Reports, deliverables, research docs
- **Inbox** — Action items, proposals, suggestions from agents
- **Chat** — Real-time messaging with Lobs (WebSocket)
- **Memories** — (planned) Browse and search long-term memory
- **Settings** — Server URL, connection, preferences

## Server
- **lobs-server**: `~/lobs-server` — FastAPI + SQLite REST API
- All endpoints defined in APIService.swift
- Chat via WebSocket at `/api/chat/ws`

## Common Edits
- **Add a new section**: Create SwiftUI view, add to ContentView sidebar
- **Add an API call**: Add method to APIService.swift, call from AppViewModel
- **Add a model**: Update Models.swift (optional fields for backwards compat)

## Testing
```bash
swift test                              # Dashboard tests
cd ~/lobs-server && python -m pytest    # Server tests
```

## Dependencies
- Pure SwiftUI + AppKit — no external packages

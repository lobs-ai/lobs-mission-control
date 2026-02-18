# Lobs Mission Control

macOS command center for the Lobs multi-agent system. Manage tasks, chat with AI agents, browse memory & knowledge, monitor work, and track system health — all in one unified SwiftUI app.

## Features

### Core
- **Command Center** — Dashboard with "while you were away" summary, quick stats, and recent activity
- **Chat** — Real-time messaging with Lobs via WebSocket
- **Command Palette (⌘K)** — Fuzzy finder for tasks, projects, documents, and navigation
- **Quick Capture (⌘⇧Space)** — Global hotkey for instant task/memory capture

### Task Management
- **Tasks & Kanban** — Project-based boards with drag-and-drop, filtering, and agent assignment
- **Inbox** — Action items and proposals from AI agents requiring human decision
- **Projects** — Organize work by project with active/archive states

### Knowledge & Memory
- **Memory** — Browse, search, edit, and create personal memories (your second brain)
- **Knowledge/Topics** — Research workspaces with documents, notes, sources, and findings
- **Documents** — Browse and read reports and research deliverables

### Team & Monitoring
- **Team View** — Real-time agent status grid showing what each agent is working on
- **Work Tracker** — Timeline of completed work sessions with cost tracking
- **Calendar** — View upcoming events and schedule overview
- **Status Dashboard** — System health, activity feed, AI usage & cost analytics

## Tech Stack

- **Framework:** SwiftUI (macOS 14.0+)
- **Build:** Swift Package Manager
- **Architecture:** MVVM (AppViewModel as central state holder)
- **API:** REST + WebSocket to [lobs-server](https://github.com/RafeSymonds/lobs-server)
- **Network:** Connects via Tailscale for secure remote access
- **Storage:** Local cache + server-side persistence

## Building

### Prerequisites
- macOS 14.0 or later
- Xcode 15+ (for Swift compiler)
- Running instance of [lobs-server](https://github.com/RafeSymonds/lobs-server)

### Build & Run
```bash
git clone git@github.com:RafeSymonds/lobs-mission-control.git
cd lobs-mission-control
swift build
swift run
```

Or use the build script:
```bash
./bin/build
```

## Configuration

On first launch, the app guides you through onboarding:

1. **Server URL** — Your lobs-server address (e.g., `http://100.x.x.x:8000` for Tailscale)
2. **API Token** — Generate on server: `cd ~/lobs-server && python bin/generate_token.py mission-control`

Settings are stored in `~/Library/Application Support/LobsMissionControl/config.json`.

You can also configure via Settings (⌘,) after initial setup.

## Architecture

```
┌─────────────────────────────────────────────────┐
│          Lobs Mission Control (macOS)           │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │         AppViewModel (State)             │  │
│  └──────────────────────────────────────────┘  │
│                      │                          │
│  ┌──────────────────────────────────────────┐  │
│  │         APIService (Networking)          │  │
│  │  • REST API calls                        │  │
│  │  • WebSocket (chat, live updates)        │  │
│  │  • JSONDecoder (.convertFromSnakeCase)   │  │
│  └──────────────────────────────────────────┘  │
│                      │                          │
└──────────────────────┼──────────────────────────┘
                       │
                   (Tailscale)
                       │
┌──────────────────────┼──────────────────────────┐
│                      ▼                          │
│               lobs-server (FastAPI)             │
│  • Task orchestration                           │
│  • Agent coordination                           │
│  • Memory & knowledge storage                   │
│  • Calendar integration                         │
│  • WebSocket relay                              │
└─────────────────────────────────────────────────┘
```

**Key patterns:**
- Views use `@EnvironmentObject` to access `AppViewModel`
- API calls routed through `vm.apiService` (NOT direct APIService instantiation)
- Models decoded with `.convertFromSnakeCase` — no manual CodingKeys for snake→camel
- WebSocket updates pushed to AppViewModel, which updates `@Published` properties
- Local cache (CacheManager) for offline resilience

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — App structure, data flow, key components
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — Development guide, debugging, common pitfalls
- **[AGENTS.md](AGENTS.md)** — AI agent guidance and constraints
- **[docs/](docs/)** — Bug fixes, feature documentation, implementation notes
  - See [docs/README.md](docs/README.md) for full index

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

For AI agents working on this codebase, see [AGENTS.md](AGENTS.md).

## See Also

**Lobs Ecosystem Documentation** (in `~/self-improvement/docs/`):
- [LOBS_ECOSYSTEM.md](../self-improvement/docs/LOBS_ECOSYSTEM.md) — Cross-project architecture and feature matrix
- [GETTING_STARTED.md](../self-improvement/docs/GETTING_STARTED.md) — 20-30 min ecosystem onboarding
- [TECH_STACK_REFERENCE.md](../self-improvement/docs/TECH_STACK_REFERENCE.md) — Technology choices and patterns
- [Code Quality System](../self-improvement/README.md) — Handoffs, reviews, technical debt tracking

## License

Private

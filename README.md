# Lobs Mission Control

Your second brain — a macOS app for managing tasks, memories, documents, chat, research, and system health. Connects to [lobs-server](https://github.com/RafeSymonds/lobs-server) for all data.

## Features
- **Command Center** — At-a-glance dashboard with "While You Were Away" summary
- **Chat** — Real-time messaging with Lobs via WebSocket
- **Tasks** — Kanban board management per project
- **Memory** — Browse, search, edit, and capture memories (your second brain)
- **Documents** — Browse reports and research deliverables
- **Research** — Workspaces with notes, sources, and findings
- **Inbox** — Action items from AI agents
- **Status** — System health monitoring, activity feed, cost tracking

## Setup
```bash
git clone git@github.com:RafeSymonds/lobs-mission-control.git
cd lobs-mission-control
swift build
swift run
```

On first launch, configure in Settings:
1. **Server URL** — Your lobs-server address (e.g., `http://<tailscale-ip>:8000`)
2. **API Token** — Generated on the server: `python scripts/generate_token.py mission-control`

## Requirements
- macOS 13+
- [lobs-server](https://github.com/RafeSymonds/lobs-server) running and accessible

## License
Private

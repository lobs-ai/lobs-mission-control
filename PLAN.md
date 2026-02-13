# Lobs Mission Control — Build Plan

## Phase 1: Memory Section (🧠)
The core "second brain" feature.

### Server (lobs-server)
- [ ] Memory model: store memory files as records (path, content, updated_at)
- [ ] `GET /api/memories` — list all memory files (with metadata)
- [ ] `GET /api/memories/{path}` — read content of a memory file
- [ ] `PUT /api/memories/{path}` — update/create a memory file
- [ ] `POST /api/memories` — create new memory entry (auto-generates daily file)
- [ ] `GET /api/memories/search?q=` — full-text search across all memories
- [ ] Seed from existing MEMORY.md + memory/*.md files
- [ ] Tests for all endpoints

### Dashboard (mission-control)
- [ ] MemoryModels.swift — Memory, MemorySearchResult structs
- [ ] MemoryView.swift — main memory browser
  - Timeline view (daily entries, scrollable)
  - MEMORY.md viewer/editor (long-term memory)
  - Search bar with results
  - "Capture" button to add quick note to today's memory
- [ ] MemoryDetailView.swift — view/edit a single memory file
- [ ] MemorySearchView.swift — search results display
- [ ] APIService additions for memory endpoints
- [ ] Wire into sidebar navigation

## Phase 2: Status Section (📊)
System observability.

### Server
- [ ] `GET /api/status/overview` — combined health (server, orchestrator, agents, workers)
- [ ] `GET /api/status/activity` — recent activity timeline (tasks completed, workers spawned, errors)
- [ ] `GET /api/status/costs` — token usage tracking (if available)

### Dashboard
- [ ] StatusView.swift — system health dashboard
  - Server connection status (green/yellow/red)
  - Orchestrator state (running/paused/stopped)
  - Active workers with progress
  - Recent activity feed
  - Error log (last N errors)
- [ ] Agent cards with status, last activity, health
- [ ] Cost/usage charts (if data available)
- [ ] Wire into sidebar

## Phase 3: Command Center Home (⌘)
Redesigned home screen — at-a-glance everything.

### Dashboard
- [ ] Redesign OverviewView.swift → CommandCenterView.swift
  - "What happened" — activity since last visit
  - Active tasks summary (count + top 3)
  - Unread inbox count with preview
  - Recent memories snippet
  - Agent status badges
  - Quick actions: new task, capture thought, start research, open chat
- [ ] "While you were away" summary (queries activity endpoint)

## Phase 4: Navigation & Polish
Clean up and connect everything.

### Dashboard
- [ ] Redesign sidebar
  - Icons + labels for each section
  - Unread badges (inbox, activity)
  - Collapsible groups
- [ ] Command palette (⌘K) searches across ALL sections
  - Tasks, memories, documents, research, inbox
  - Quick actions (create task, capture memory, etc.)
- [ ] Keyboard shortcuts for section switching (⌘1-9)
- [ ] Menu bar widget update (show broader status)
- [ ] Global hotkey for quick capture (thought → today's memory)

## Phase 5: Cleanup
- [ ] Remove vestigial git/GitHub code from AppViewModel
- [ ] Remove Store.swift, Git.swift, GitError.swift, GitForceSync.swift, SyncConflictDetailsView.swift
- [ ] Remove old onboarding views (clone, repo setup, etc.)
- [ ] Final compile check + test pass

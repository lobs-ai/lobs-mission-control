# AGENTS.md — AI Agent Guide for Lobs Mission Control

This document is for AI agents working on the **Lobs Mission Control** codebase (macOS SwiftUI app). If you're looking for the OpenClaw workspace template, those files are in the root (`SOUL.md`, `USER.md`, etc.) — **do not modify them**.

## Project Structure

```
lobs-mission-control/
├── Sources/LobsMissionControl/
│   ├── LobsMissionControlApp.swift        # App entry point
│   ├── AppViewModel.swift                 # Central state holder (⚠️ CRITICAL)
│   ├── APIService.swift                   # Network layer (REST + WebSocket)
│   ├── Models.swift                       # Core data models
│   ├── MainView.swift                     # Root layout (NavigationSplitView)
│   ├── Calendar/                          # Calendar feature
│   ├── Chat/                              # Chat UI & WebSocket handling
│   ├── Memory/                            # Memory browser & editor
│   ├── Status/                            # System health & analytics
│   ├── Team/                              # Agent grid & work tracker
│   ├── Config/                            # Settings & onboarding
│   ├── Components/                        # Reusable UI components
│   ├── Analytics/                         # AI usage tracking
│   └── Resources/                         # Icons, assets
├── Package.swift                          # SPM manifest
├── bin/build                              # Build script
├── README.md                              # User-facing docs
├── CONTRIBUTING.md                        # Contribution guidelines
├── ARCHITECTURE.md                        # Architecture overview
└── [SOUL.md, USER.md, TOOLS.md, etc.]    # ⚠️ OpenClaw templates — DO NOT EDIT

**DO NOT CREATE:**
- `docs/` directory (was deleted — one-off worker artifacts)
- Fix summaries in root (e.g., `*_FIX.md`, `*_SUMMARY.md`)
- Review docs, before/after docs, planning docs in root

**Write persistent docs only in:**
- This file (AGENTS.md) — agent-specific development notes
- ARCHITECTURE.md — high-level design
- Inline code comments for complex logic
```

## Key Architecture Patterns

### 1. AppViewModel is the Source of Truth
- **Single instance** created in `LobsMissionControlApp` and injected via `@EnvironmentObject`
- Holds ALL app state: tasks, projects, agents, inbox, memory, chat messages, etc.
- Views **never** create their own APIService instances
- Pattern: `@EnvironmentObject var vm: AppViewModel` → use `vm.apiService` for API calls

**❌ WRONG:**
```swift
struct SomeView: View {
    let apiService = try! APIService() // NO! Creates duplicate, loses state
    ...
}
```

**✅ CORRECT:**
```swift
struct SomeView: View {
    @EnvironmentObject var vm: AppViewModel
    
    func loadData() async {
        do {
            let data = try await vm.apiService.fetchSomething()
            vm.someProperty = data
        } catch { ... }
    }
}
```

### 2. JSON Decoding with .convertFromSnakeCase
- **APIService** uses `JSONDecoder` with `.convertFromSnakeCase` key strategy
- This automatically converts `snake_case` API fields to `camelCase` Swift properties
- **NEVER add manual `CodingKeys`** for simple snake→camel conversions
- Past bugs: adding manual CodingKeys caused **double-conversion** and nil data

**❌ WRONG:**
```swift
struct Task: Codable {
    let taskId: Int
    let projectId: Int
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"      // ❌ Unnecessary! Decoder already converts
        case projectId = "project_id"
    }
}
```

**✅ CORRECT:**
```swift
struct Task: Codable {
    let taskId: Int      // ✅ Decoder converts task_id → taskId automatically
    let projectId: Int
    // No CodingKeys needed
}
```

**When to use CodingKeys:**
- Non-standard conversions (e.g., `id` in JSON → `taskId` in Swift)
- Excluding fields from encoding/decoding
- Renaming that doesn't follow snake_case pattern

### 3. NavigationSplitView Structure
- **MainView** uses `NavigationSplitView` with:
  - Sidebar: Navigation links (Command Center, Tasks, Chat, Memory, etc.)
  - Detail: Content view based on selected sidebar item
- Selected tab tracked in `vm.selectedTab` (persisted to UserDefaults)

### 4. WebSocket Real-Time Updates
- **Chat** uses WebSocket (`/ws/chat`) for real-time messaging
- **APIService** handles WebSocket lifecycle, delegates messages to AppViewModel
- AppViewModel updates `@Published` properties → SwiftUI auto-refreshes views

### 5. Models in Models.swift
- All core models (`Task`, `Project`, `Agent`, `Memory`, etc.) live in `Models.swift`
- Use `Codable` for JSON serialization
- Conform to `Identifiable` where needed (for SwiftUI lists)
- Add `Equatable`, `Hashable` when needed for comparison/sets

## Build & Test

### Building
```bash
cd ~/lobs-mission-control
swift build
```

Or with the script:
```bash
./bin/build
```

### Running
```bash
swift run
```

### Common Build Issues
1. **Missing server:** Ensure `lobs-server` is running on configured URL
2. **Module not found:** Run `swift package resolve` to update dependencies
3. **Resource errors:** Resources are accessed via `Bundle.module` (SPM convention)

## Common Pitfalls (Learn from Past Bugs)

### 🐛 Bug: Nil data after API changes
**Cause:** Added manual `CodingKeys` for snake_case fields when decoder already converts  
**Fix:** Remove unnecessary CodingKeys, rely on `.convertFromSnakeCase`

### 🐛 Bug: State not updating across views
**Cause:** Created new APIService instance instead of using `vm.apiService`  
**Fix:** Always get apiService from `@EnvironmentObject var vm: AppViewModel`

### 🐛 Bug: WebSocket messages not showing
**Cause:** Forgot to update `@Published` property in AppViewModel  
**Fix:** WebSocket handlers must update `vm.chatMessages.append(...)` on `@MainActor`

### 🐛 Bug: Navigation broken after view refactor
**Cause:** Changed `vm.selectedTab` without updating `MainView` switch cases  
**Fix:** Keep `SelectedTab` enum and MainView detail view in sync

### 🐛 Bug: Tap targets too small (especially in lists)
**Cause:** SwiftUI default hit areas too small for clickable elements  
**Fix:** Use `.frame(minHeight: 44)` or `.buttonStyle(.plain)` with explicit padding

### 🐛 Bug: Performance issues with large lists
**Cause:** Not using `LazyVStack` for long lists  
**Fix:** Use `LazyVStack` or `List` for 50+ items, leverage `Identifiable` for efficient diffing

## Development Workflow

1. **Pull latest:** `git pull --rebase`
2. **Create feature branch:** `git checkout -b feature/your-feature`
3. **Make changes** (follow patterns above)
4. **Build & test:** `swift build && swift run`
5. **Commit:** `git commit -m "feat: description"` (use conventional commits)
6. **Push:** `git push origin feature/your-feature`
7. **Don't create fix docs in root** — if you need to document, update this file

## Git Configuration

When committing as a worker agent:
```bash
git config user.email "thelobsbot@gmail.com"
git config user.name "Lobs (Worker)"
```

## Quick Reference

| Task | Command |
|------|---------|
| Build | `swift build` or `./bin/build` |
| Run | `swift run` |
| Clean | `swift package clean` |
| Resolve deps | `swift package resolve` |
| Update deps | `swift package update` |
| Generate Xcode project | `swift package generate-xcodeproj` (optional) |

## Resources

- **Server repo:** [lobs-server](https://github.com/RafeSymonds/lobs-server)
- **API docs:** Check `lobs-server/README.md` for endpoint reference
- **Architecture:** See `ARCHITECTURE.md` in this repo
- **Contributing:** See `CONTRIBUTING.md`

---

**Remember:** This is a clean, organized codebase. Keep it that way. No clutter, no fix docs in root, no docs/ directory. Write code, commit, move on.

## Shared Documentation

Query shared docs via memory search. Index at `/Users/lobs/lobs-server/docs/INDEX.md`.

Key docs: system-overview, memory-system, agent-lifecycle, coding-standards, git-workflow, model-routing, orchestrator.

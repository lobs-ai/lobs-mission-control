# Documentation — Lobs Mission Control

Technical documentation, bug fix reports, and implementation guides for the macOS dashboard app.

## Quick Links

| I want to... | Read this |
|--------------|-----------|
| Understand the architecture | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Contribute to the codebase | [CONTRIBUTING.md](../CONTRIBUTING.md) |
| Learn API integration patterns | [AGENTS.md](../AGENTS.md) |
| Debug common issues | [CONTRIBUTING.md](../CONTRIBUTING.md#debugging) |
| Run tests or write new tests | [TESTING.md](TESTING.md) |
| See known issues & tech debt | [KNOWN_ISSUES.md](KNOWN_ISSUES.md) |
| Learn Swift/SwiftUI best practices | [BEST_PRACTICES.md](BEST_PRACTICES.md) ✨ |

---

## Core Documentation

### [TESTING.md](TESTING.md) ✨ **NEW 2026-02-14**
**For:** Developers and AI agents  
**Purpose:** Testing guide for the macOS app

- Running tests (command line and Xcode)
- Writing tests (patterns and best practices)
- Testing async/await and MainActor code
- Mocking API services
- Troubleshooting test issues
- Current test status and known test build issues

**Last updated:** 2026-02-14

### [BEST_PRACTICES.md](BEST_PRACTICES.md) ✨ **NEW 2026-02-14**
**For:** Developers and AI agents  
**Purpose:** Swift/SwiftUI patterns, concurrency best practices, code quality guidelines

- Swift concurrency (async/await, MainActor, actor isolation)
- Modern SwiftUI patterns (onChange, NavigationStack, state management)
- AppViewModel pattern and dependency injection
- API integration and error handling
- Code quality (optional handling, type inference)
- Common pitfalls and solutions

**Last updated:** 2026-02-14

### [KNOWN_ISSUES.md](KNOWN_ISSUES.md)
**For:** Developers and AI agents  
**Purpose:** Known issues, deprecation warnings, technical debt

- SwiftUI onChange API deprecation (needs migration)
- Code quality issues (unused variables, unnecessary awaits)
- Recent bug fixes with commit references
- Technical debt tracking

**Last updated:** 2026-02-14

---

### [README.md](../README.md)
**For:** Everyone  
**Purpose:** Project overview, setup, features

- Feature list (Command Center, Tasks, Chat, Memory, Knowledge, Calendar, Team, Work Tracker)
- Tech stack (SwiftUI, macOS 14.0+)
- Build instructions
- Configuration guide
- Architecture diagram

---

### [ARCHITECTURE.md](../ARCHITECTURE.md)
**For:** Developers and AI agents  
**Purpose:** Deep dive into app structure

- App structure (AppViewModel, APIService, Views)
- Data flow diagrams
- Key components (AppViewModel, APIService, Models, CacheManager, OrchestratorManager)
- Navigation structure
- WebSocket real-time updates
- State management patterns
- View hierarchy

**Last reviewed:** 2026-02-14

---

### [CONTRIBUTING.md](../CONTRIBUTING.md)
**For:** Developers and AI agents  
**Purpose:** Development guidelines and debugging

**Contents:**
- Development setup
- Code patterns (settings management, new views, shortcuts)
- Testing strategies
- Debugging guide (common issues, verification steps)
- Common pitfalls (compilation verification, API changes, settings persistence)
- Appendix: Recent failure patterns

**Last updated:** 2026-02-12

---

### [AGENTS.md](../AGENTS.md)
**For:** AI agents  
**Purpose:** Constraints and project-specific guidance

- What this project is
- What to work on
- What NOT to do
- Architecture references
- Key conventions

---

## Bug Fixes & Patches

### fixes/TOPIC_DOCUMENT_NAVIGATION_FIX.md
**Issue:** Topic switching while viewing a document  
**Date:** 2026-02-13  
**Status:** ✅ Fixed

When viewing a document within a topic, clicking on a different topic in the sidebar did not exit the document view. User remained stuck in document view even though topic had changed.

**Solution:**
- Added explicit `onChange` handler to clear `selectedDocument` when topic changes
- Complements existing `.id(topic.id)` modifier for more robust state reset
- Files modified: `TopicBrowserView.swift`

**Related commits:**
- `ee457d5` — task(36D771B2): clicking on a topic while in a document should take you out of that document

---

## Recent Improvements (Last 7 Days)

### Calendar Enhancements
**Date:** 2026-02-13–2026-02-14

Multiple fixes to calendar functionality:
- ✅ Fixed calendar range API integration
- ✅ Week view: 30-minute grid, new event colors
- ✅ Event type filtering (hide autonomous tasks)
- ✅ Month view rendering fixes
- ✅ Integration with work tracker deadlines

**Related commits:**
- `220f791` — Fix calendar WeekView: 30-min grid, new event colors, filter fix
- `61dcd4c` — fix(calendar): Fix calendar range API, filter autonomous tasks, and improve UI
- `628cd9e` — task(CABB24FF): calendar says server error when trying to show week or month view

**Files:**
- `Sources/LobsMissionControl/Calendar/CalendarView.swift`
- `Sources/LobsMissionControl/Calendar/CalendarViewModel.swift`

---

### Knowledge/Topics System Improvements
**Date:** 2026-02-13

UI improvements for topic-based knowledge organization:
- ✅ Topic search now searches documents too (not just topic names)
- ✅ Document detail view with actions
- ✅ Research request + task creation UI
- ✅ Fixed document navigation bug (see [fixes/](#bug-fixes--patches))

**Related commits:**
- `bd579f8` — task(16563966): search topics should also search for specific documents
- `870aeb0` — task(E4629B50): Knowledge System: Document detail view with actions
- `b0aea14` — task(C436EFEF): Knowledge System: Research request + task creation UI

**Files:**
- `Sources/LobsMissionControl/TopicBrowserView.swift`

---

### Task Management UX
**Date:** 2026-02-14

Several UX improvements for task creation and management:
- ✅ Fixed task creation from project overview
- ✅ Fixed task creation from home page (agent selection)
- ✅ Removed "while you were away" from home screen
- ✅ Task creation no longer auto-opens detail view with edit cursor
- ✅ Fixed intermittent task creation failures

**Related commits:**
- `ff9857b` — task(5027A209): when creating a task it immediately shows the details
- `49fa13d` — task(AF37DCE8): create task from project overview doesn't let me create
- `10ecb41` — task(02009D14): creating task from home page should allow me to choose which agent
- `0299372` — task(49A9133C): can not create tasks sometimes when filling in the notes

---

## Architecture Patterns

### State Management
- **Single source of truth:** `AppViewModel` (@StateObject, injected via `.environmentObject()`)
- **Published properties:** All UI-bound state uses `@Published`
- **No direct APIService:** Views access via `vm.apiService`, never instantiate directly

### API Integration
- **Snake case conversion:** Automatic via `JSONDecoder.convertFromSnakeCase`
- **Auth:** Bearer token in headers for all `/api/*` endpoints (except `/api/health`)
- **WebSocket:** Chat and live updates via `URLSessionWebSocketTask`

### SwiftUI Conventions
- **MVVM pattern:** Views + ViewModels for complex screens
- **View composition:** Small, focused view components
- **@EnvironmentObject:** For AppViewModel access
- **@StateObject:** For view-owned ViewModels

---

## File Organization

```
lobs-mission-control/
├── Sources/
│   └── LobsMissionControl/
│       ├── Calendar/              # Calendar views and logic
│       ├── Chat/                  # Chat interface
│       ├── Models/                # Data models
│       ├── Services/              # APIService, CacheManager, etc.
│       ├── TopicBrowserView.swift # Knowledge/Topics UI
│       └── ...
├── Tests/                         # Unit tests
├── docs/                          # Documentation (you are here)
│   ├── README.md                  # This file
│   └── fixes/                     # Bug fix documentation
├── AGENTS.md                      # AI agent guidance
├── ARCHITECTURE.md                # System design
├── CONTRIBUTING.md                # Developer guide
└── README.md                      # Project overview
```

---

## Documentation Standards

When adding documentation:

1. **Bug fixes** → `docs/fixes/<descriptive-name>.md`
2. **Feature designs** → `docs/designs/<feature-name>.md` (create if needed)
3. **Update this index** → Add entry to relevant section
4. **Include metadata:**
   - Issue/task ID
   - Date
   - Status (✅ Fixed, 🚧 In Progress, 📝 Proposed)
   - Related commits
   - Modified files

---

## Testing

```bash
# Run tests
swift test

# Run with verbose output
swift test -v

# Run specific test
swift test --filter TestName
```

**Test locations:**
- Unit tests: `Tests/LobsMissionControlTests/`
- Integration tests: TBD

---

## Related Documentation

- **[lobs-server](../../lobs-server/README.md)** — Backend API reference
- **[lobs-server AGENTS.md](../../lobs-server/AGENTS.md)** — Complete API endpoint documentation
- **[lobs-server Topics Implementation](../../lobs-server/docs/TOPICS_IMPLEMENTATION.md)** — Backend Topics feature

---

*For project overview and setup, see [README.md](../README.md)*

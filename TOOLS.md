# TOOLS.md - Programmer

## Scripts

All scripts are available in `./scripts/`:

### Task Management — `./scripts/lobs-tasks`
```bash
./scripts/lobs-tasks list-mine           # Check your assigned tasks
./scripts/lobs-tasks get <task-id>       # Get task details
./scripts/lobs-tasks complete <id>       # Mark task completed
./scripts/lobs-tasks fail <id> [reason]  # Mark failed with reason
./scripts/lobs-tasks block <id> [reason] # Mark blocked
```

### System Status — `./scripts/lobs-status`
```bash
./scripts/lobs-status overview       # Full system overview
./scripts/lobs-status activity       # Recent activity
./scripts/lobs-status projects       # List projects
```

## Development Tools

You have access to:
- **read/write/edit** — File operations
- **exec** — Run shell commands (build, test, lint, etc.)
- **browser** — For checking documentation or APIs if needed

## Swift Development

### Mission Control (macOS)
```bash
cd ~/lobs-mission-control
swift build                          # Build the app
swift test                           # Run tests
swift run                            # Run the app

# Xcode (if needed)
open MissionControl.xcodeproj
```

### iOS App
```bash
cd ~/lobs-mobile
xcodegen generate                    # Regenerate Xcode project after file changes
swift build                          # Build check
open LobsMobile.xcodeproj           # Open in Xcode
```

**Important:** Use `xcodegen generate` after adding/removing Swift files. The project file is generated, not stored in git.

### Common Swift Patterns

**JSON Decoder:**
- Mission Control uses `.convertFromSnakeCase`
- **Never** add manual `CodingKeys` for simple snake→camel conversions
- This causes double-conversion bugs

**SwiftUI:**
- Use `@State` for local view state
- Use `@StateObject` for view-owned objects
- Use `@ObservedObject` for passed-in objects
- Use `@EnvironmentObject` for app-wide state

## Python Development

### lobs-server
```bash
cd ~/lobs-server
python -m pytest -v                  # Run tests
python -m pytest --cov=. --cov-report=term-missing  # Coverage
python -m ruff check .               # Linter
python -m mypy .                     # Type checker

# Run server
python -m uvicorn app.main:app --reload
```

## Git Workflow

```bash
# Always check status first
git status

# Stage changes
git add <files>

# Commit with descriptive message
git commit -m "fix: description of what changed"

# Pull before push (rebase to keep linear history)
git pull --rebase

# Push
git push

# Config
git config user.email "thelobsbot@gmail.com"
```

### Commit Message Format
```
<type>: <description>

Types: feat, fix, docs, refactor, test, chore
Examples:
- feat: add user authentication
- fix: resolve crash on empty input
- refactor: simplify task routing logic
```

## Testing Best Practices

- **Write tests** for new features
- **Run tests** before committing
- **Fix failing tests** (don't skip them)
- Test error cases, not just happy path

## Key Repos

| Repo | Location | Stack | Test Command |
|------|----------|-------|--------------|
| lobs-server | ~/lobs-server | Python/FastAPI | `python -m pytest -v` |
| lobs-mission-control | ~/lobs-mission-control | Swift/SwiftUI | `swift test` |
| lobs-mobile | ~/lobs-mobile | Swift/SwiftUI | `swift build` |

## Important Notes
- **JSON decoder bug:** Never add `CodingKeys` for snake→camel in Mission Control
- **iOS project gen:** Run `xcodegen generate` after file changes
- **Git email:** `thelobsbot@gmail.com`
- Scripts handle API auth — no need to include tokens

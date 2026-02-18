# Known Issues — lobs-mission-control

**Last Updated:** 2026-02-14

Known issues, deprecation warnings, and technical debt for the macOS app.

---

## Critical Issues

### 1. Actor Isolation Violations in PollingManager

**Status:** 🔴 Critical — Concurrency bug  
**Impact:** Potential race conditions and crashes  
**Affected Files:** `PollingManager.swift` (lines 47, 56)

**Problem:**
Calling `@MainActor`-isolated methods `pause()` and `resume()` from non-isolated notification observer context.

**Current Code:**
```swift
// Line 47
NotificationCenter.default.addObserver(...) { [weak self] _ in
  self?.pause()  // ❌ pause() is @MainActor but context is not
}

// Line 56
NotificationCenter.default.addObserver(...) { [weak self] _ in
  self?.resume()  // ❌ resume() is @MainActor but context is not
}
```

**Compiler Warning:**
```
warning: Call to main actor-isolated instance method 'pause()' 
in a synchronous nonisolated context
```

**Impact:** Race conditions, unpredictable behavior, potential crashes when app suspends/resumes.

**Fix Required:**
```swift
NotificationCenter.default.addObserver(...) { [weak self] _ in
  Task { @MainActor in
    self?.pause()
  }
}
```

**Recommended Action:**
Wrap calls in `Task { @MainActor in }` blocks. Programmer handoff created.

**Reference:** [Code Quality Review](~/self-improvement/review-notes.md), [handoff-actor-isolation.json](~/self-improvement/handoff-actor-isolation.json)

**Discovered:** 2026-02-14

---

## Deprecation Warnings

### 2. SwiftUI onChange API (Deprecated in macOS 14.0)

**Status:** 🟡 Important — Code quality issue  
**Impact:** Will break in future macOS versions  
**Affected Files:** ~20+ Swift files (see below)

**Problem:**
Using deprecated `onChange(of:perform:)` API throughout the codebase. This API was deprecated in macOS 14.0 and should be migrated to the new two-parameter or zero-parameter closure syntax.

**Deprecation Warning:**
```swift
warning: 'onChange(of:perform:)' was deprecated in macOS 14.0: 
Use `onChange` with a two or zero parameter action closure instead.
```

**Current Code:**
```swift
.onChange(of: searchText) { newValue in
    selectedIndex = 0
}
```

**Should Be:**
```swift
// Two-parameter version (when you need old value):
.onChange(of: searchText) { oldValue, newValue in
    selectedIndex = 0
}

// Zero-parameter version (when you don't need values):
.onChange(of: searchText) {
    selectedIndex = 0
}
```

**Affected Files:**
- `CommandPaletteView.swift` (2 instances)
- `DocumentsView.swift` (1 instance)
- `FirstTaskWalkthroughSheet.swift` (1 instance)
- `InboxView.swift` (2 instances)
- `MainView.swift` (1 instance)
- `OnboardingAgentSetupView.swift` (1 instance)
- Plus ~15 more files (see full list in code quality review)

**Recommended Action:**
Systematic migration of all `onChange` calls to new API. Programmer handoff created.

**Reference:** [Code Quality Review](~/self-improvement/review-notes.md) section 4

---

## Code Quality Issues

### 3. Unused Variables

**Status:** 🟡 Minor — Code quality  
**Impact:** Compiler warnings

**Instances Found:**

**DocumentsView.swift:870**
```swift
guard let repoURL = vm.repoURL else { return }
// `repoURL` is checked but never used
```

**Fix:**
```swift
guard vm.repoURL != nil else { return }
```

**APIService.swift:680**
```swift
let timestamp = ISO8601DateFormatter().string(from: Date())
// Variable created but never used
```

**Fix:** Either use the timestamp or remove the line.

---

### 4. Unnecessary Await Warnings

**Status:** 🟡 Minor — Code quality  
**Affected:** `DocumentsView.swift:1057, 1227`

**Problem:**
Using `await` on synchronous function `vm.loadAgentDocuments()`.

**Warning:**
```swift
warning: no 'async' operations occur within 'await' expression
```

**Recommended Fix:**
Either remove `await` or make the function properly async if it should be async.

---

## Design Considerations

### 5. Task Owner Optionality

**Status:** ℹ️ By Design  
**Recent Change:** Commit `b4b0dc0`

**Decision:** Made `task.owner` optional to handle null values from API.

**Rationale:**
- API can return tasks without owner assigned
- App needs to handle this gracefully
- Optional owner allows UI to show "Unassigned" state

**Code:**
```swift
struct Task: Codable {
    let owner: String?  // Changed from String to String?
}
```

---

## Recent Bug Fixes

### 6. Calendar View Errors (Fixed)

**Status:** ✅ Resolved  
**Fixed In:** Commits `628cd9e`, `a8f1c9c`, `3d5f2ce`

**Was:** Calendar views showed server errors and didn't display events correctly.

**Solution:**
- Fixed week view 30-minute grid
- Fixed event color handling
- Fixed event filter logic
- Improved error handling

---

### 7. Task Creation UX Issues (Fixed)

**Status:** ✅ Resolved  
**Fixed In:** Multiple commits `ff9857b`, `49fa13d`, `61a4b1d`

**Was:**
- Cursor immediately jumped to edit box after creating task
- Create task from home didn't allow agent selection
- Create task sometimes failed on first attempt

**Solution:**
- Changed task creation to show selected state without editing
- Added agent selection to home page task creation
- Fixed initialization race condition

---

### 8. Knowledge & Memory Issues (Fixed)

**Status:** ✅ Resolved  
**Fixed In:** `61a4b1d`, `66e82e7`, `49fa13d`

**Was:**
- Knowledge didn't show documents
- Memory search didn't search in memories
- Topic navigation while in document didn't exit document view

**Solution:**
- Fixed document loading
- Enhanced memory search to include memory content
- Fixed topic navigation routing

---

## Technical Debt

### Documentation
- ✅ CONTRIBUTING.md is comprehensive (18KB, updated 2026-02-12)
- ✅ ARCHITECTURE.md is current
- ✅ README.md is current
- ⚠️ No testing guide (manual testing only for now)

### Code Organization
- Good: Clean separation of concerns (ViewModels, Services, Views)
- Consider: More view composition (some views are getting large)

### Testing
- No automated UI tests (SwiftUI testing is challenging)
- Manual testing workflow only
- Consider: Unit tests for ViewModels and Services

---

## Tracking & Updates

**How to Update This Document:**
1. Add new issues as discovered during development
2. Move fixed issues to "Recent Bug Fixes" with commit reference
3. Update status markers (🔴 critical, 🟡 important, ℹ️ info, ✅ resolved)
4. Include dates and commit SHAs for traceability

**Related Documents:**
- [Code Quality Review](~/self-improvement/review-notes.md) — Latest automated review
- [docs/README.md](README.md) — Full documentation index
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Development guide

**Last Review:** 2026-02-14  
**Next Review:** After onChange migration is complete

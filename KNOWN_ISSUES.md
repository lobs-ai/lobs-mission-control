# Known Issues — lobs-mission-control

**Last Updated:** 2026-02-14  
**Source:** Code quality review and handoff inventory

This file tracks known bugs, technical debt, and quality issues identified during code reviews. Issues here should have corresponding handoffs for programmer agents to fix.

---

## 🔴 Critical Issues

### Swift Test Build System Error
**Discovered:** 2026-02-14  
**Impact:** Cannot run test suite, blocks QA  
**Status:** ⏸️ Pending fix  
**Handoff:** `handoff-mission-control-test-build.json`

**Problem:**  
Swift test compilation fails with:
```
error: couldn't build ... because of multiple producers: 
Compiling Swift Module 'LobsMissionControlTests' (103 sources)
```

**Root Cause:**  
The Swift Package Manager build system is detecting duplicate compilation targets for the test module.

**Possible Causes:**
1. Duplicate `testTarget` entries in `Package.swift`
2. Conflicting build settings
3. Xcode and SPM build caches out of sync

**Current Workaround:**  
Main app builds successfully with `swift build`. Only `swift test` fails.

**Recommended Investigation:**
1. Check `Package.swift` for duplicate testTarget entries
2. Clean build artifacts: `rm -rf .build && swift build`
3. Verify no circular dependencies in test targets
4. Check for duplicate test file references in Xcode project

---

## 🟡 Important Issues

### Actor Isolation Warnings — PollingManager
**Discovered:** 2026-02-14  
**Impact:** Concurrency safety warnings  
**Status:** ⏸️ Pending fix  
**Handoff:** `handoff-actor-isolation-polling-manager.json`

**Problem:**  
Actor isolation warnings in PollingManager and AppViewModel related to concurrent access.

**Affected Files:**
- `Sources/LobsMissionControl/PollingManager.swift`
- `Sources/LobsMissionControl/AppViewModel.swift`

**Warning Type:**
```
Sending 'self' risks causing data races
```

**Context:**  
Swift 6 strict concurrency mode requires explicit isolation for shared mutable state.

**Recommendation:**  
Use `@MainActor` isolation or proper Task isolation for async operations that touch UI state.

---

### SwiftUI Deprecated API Usage
**Discovered:** 2026-02-14  
**Impact:** Deprecation warnings, future compatibility risk  
**Status:** ⏸️ Pending fix  
**Handoff:** `handoff-swiftui-deprecated-api.json`

**Problem:**  
Using deprecated SwiftUI `onChange(of:perform:)` API instead of the new `onChange(of:initial:_:)` closure-based API.

**Affected Files:**
- `Sources/LobsMissionControl/BoardComponents.swift`
- `Sources/LobsMissionControl/Chat/ChatView.swift`

**Deprecation Warning:**
```
'onChange(of:perform:)' was deprecated in macOS 14.0
```

**Migration Pattern:**
```swift
// Old (deprecated)
.onChange(of: value) { newValue in
    doSomething(newValue)
}

// New (macOS 14+)
.onChange(of: value) { oldValue, newValue in
    doSomething(newValue)
}
```

---

### Dead Code and Unused Variables
**Discovered:** 2026-02-14  
**Impact:** Code quality, maintainability  
**Status:** ⏸️ Pending fix  
**Handoff:** `handoff-code-cleanup.json`

**Problem:**  
Various unused variables and dead code paths.

**Affected Files:**
- `Sources/LobsMissionControl/AppViewModel.swift`
- `Sources/LobsMissionControl/APIService.swift`

**Warnings:**
```
Variable 'x' was never used; consider replacing with '_'
```

**Recommendation:**  
Clean up unused code and variables to improve maintainability and reduce noise in build output.

---

## Issue Lifecycle

### States
- ⏸️ **Pending** — Issue identified, handoff created
- 🔨 **In Progress** — Programmer assigned
- ✅ **Fixed** — Fix implemented and merged
- 📦 **Deployed** — Fix in production
- ❌ **Won't Fix** — Decided not to fix (with reason)

### When to Update This File

**Add issue:**
- During code reviews
- After identifying bugs
- When creating handoffs

**Update status:**
- When programmer starts work (→ In Progress)
- When fix is merged (→ Fixed)
- When fix is deployed (→ Deployed)

**Remove issue:**
- After verification in production
- Move to COMPLETED.md with resolution date

---

## Statistics

**Total Issues:** 4  
**By Priority:**
- 🔴 Critical: 1
- 🟡 Important: 3

**By Status:**
- ⏸️ Pending: 4
- 🔨 In Progress: 0
- ✅ Fixed: 0

**Build Status:** ✅ Main app builds successfully, ❌ Test build fails

---

## Notes

### Build Health
- **Main App:** ✅ Builds successfully with `swift build`
- **Tests:** ❌ Test build broken (`swift test` fails)
- **Xcode:** Unknown (not tested in latest review)

### Deprecation Timeline
- SwiftUI `onChange` was deprecated in macOS 14.0
- Actor isolation warnings will become errors in Swift 6 strict mode

---

## Related Documentation

- [Handoffs Inventory](/Users/lobs/self-improvement/HANDOFFS_INVENTORY.md) — Full handoff details
- [Review Notes](/Users/lobs/self-improvement/review-notes.md) — Latest code quality review
- [CONTRIBUTING.md](CONTRIBUTING.md) — Development guidelines
- [ARCHITECTURE.md](ARCHITECTURE.md) — System architecture

---

**Next Review:** Weekly (every Friday)

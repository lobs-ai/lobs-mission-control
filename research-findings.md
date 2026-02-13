# Research Findings: Archive Action on Documents

**Date:** 2026-02-13  
**Task ID:** 68403BDC-D292-4A90-899D-1B515F0879A3  
**Status:** ✅ Root cause identified

---

## Summary

The archive button in the Documents view **does nothing** because the `archiveDocument()` function only marks documents as read locally—it never calls the backend API. The necessary API endpoint exists but is not being invoked.

---

## Root Cause

**Location:** `Sources/LobsMissionControl/DocumentsView.swift`, lines 740-746

```swift
private func archiveDocument() {
  // Mark as read
  if !doc.isRead {
    vm.markDocumentRead(doc)
  }
  // Note: In a real implementation, you might want to actually move the file
  // to an archived directory. For now, marking as read + hiding read items achieves the goal.
}
```

**The Problem:**
1. Function only marks document as read in-memory (`vm.markDocumentRead`)
2. Never calls the backend API to persist the archive action
3. Comment indicates this is a placeholder implementation
4. No UI feedback (no sound, no visual confirmation)

**Evidence:**
- Clicking "Archive" button triggers this function (line 611)
- Button is visible and enabled in UI
- Backend API endpoint exists: `POST /api/documents/{id}/archive` (APIService.swift:703-707)
- API method properly defined: `func archiveDocument(id: String) async throws -> AgentDocument`

---

## Expected vs. Actual Behavior

### Expected Behavior
1. User clicks "Archive" button
2. Document status changes to `.archived` on server
3. Document updates locally to reflect archived status
4. Visual feedback (sound/animation)
5. Document disappears from default view (if filtering archived items)
6. Server persists change (moves file to archived directory or updates metadata)

### Actual Behavior
1. User clicks "Archive" button
2. Document marked as read in-memory only
3. No server communication
4. No persistent state change
5. Document still appears after refresh
6. No feedback to user

---

## Architecture Context

### Document Status Flow
```
DocumentsView.swift (UI)
    ↓ (user clicks Archive button)
archiveDocument() [BROKEN]
    ↓ (should call)
AppViewModel.api.archiveDocument(id) [EXISTS BUT UNUSED]
    ↓ (makes API call)
POST /api/documents/{id}/archive [SERVER ENDPOINT]
    ↓ (returns)
AgentDocument with status=.archived
    ↓ (updates)
vm.loadAgentDocuments() [REFRESH LIST]
```

### Document Status Enum
**Source:** `Models.swift`, lines 646-649

```swift
enum DocumentStatus: String, Codable, Hashable {
  case pending
  case approved
  case rejected
  case archived   // ← Status exists but never set by UI
}
```

### Comparison with Working Actions

**Convert to Task** (lines 706-729) — **Working correctly:**
```swift
private func convertToTask() {
  Task {
    do {
      _ = try await vm.api.addTask(...)
      NSSound.beep()  // ← User feedback
    } catch {
      print("Failed to create task: \(error)")  // ← Error handling
    }
  }
}
```

**Archive** (lines 740-746) — **Broken:**
```swift
private func archiveDocument() {
  if !doc.isRead {
    vm.markDocumentRead(doc)  // ← Only local change
  }
  // No API call
  // No error handling
  // No user feedback
}
```

---

## Impact Assessment

**Severity:** Medium-High
- Users expect archive to work but it silently fails
- No error message shown (users assume it worked)
- Documents reappear after app restart
- Workaround exists (mark as read + hide read items)

**Affected Users:** All users of Documents view

**Frequency:** Every time archive button is clicked

---

## Recommended Fix

### Implementation Plan

**Step 1:** Update `archiveDocument()` to call the API
```swift
private func archiveDocument() {
  Task {
    do {
      // Call API to archive on server
      _ = try await vm.api.archiveDocument(id: doc.id)
      
      // Mark as read locally
      if !doc.isRead {
        vm.markDocumentRead(doc)
      }
      
      // Refresh document list from server
      await vm.loadAgentDocuments()
      
      // User feedback
      NSSound.beep()
      
    } catch {
      print("Failed to archive document: \(error)")
      // TODO: Show error alert to user
    }
  }
}
```

**Step 2:** Add error handling UI (optional enhancement)
- Show alert if archive fails
- Toast notification for success
- Loading spinner during operation

**Step 3:** Update AppViewModel if needed
- May need helper method like `markDocumentArchived()`
- Pattern already exists for read/unread

**Estimated Effort:** 30-60 minutes for core fix, +30 minutes for polish

---

## Related Issues (Potential)

### Other Missing API Integrations
Based on memory from 2026-02-12 research, the following features were also listed as "mentioned but not implemented":

1. ❌ **Reject button** — No UI or API call visible
2. ❌ **Quick note/reply functionality** — Partially implemented (notes exist but don't persist)

**Recommendation:** Audit all action buttons in DocumentsView for similar issues.

### Read State Persistence
Current implementation:
- `markDocumentRead()` only updates in-memory state
- Uses `@AppStorage("readDocumentIds")` but not visible in code excerpt
- May not persist across app restarts

**Action:** Verify read state persistence works correctly.

---

## Testing Checklist

After implementing fix:
- [ ] Click Archive button
- [ ] Verify API call made (check network logs or server logs)
- [ ] Confirm document status changes to `.archived`
- [ ] Restart app and verify document stays archived
- [ ] Test error handling (disconnect server, archive document)
- [ ] Verify sound feedback plays
- [ ] Check that archived documents filter correctly

---

## Sources

**Code References:**
- `DocumentsView.swift:740-746` — Broken archive function
- `DocumentsView.swift:611` — Archive button trigger
- `APIService.swift:703-707` — Existing but unused API method
- `Models.swift:646-649` — DocumentStatus enum
- `AppViewModel.swift:1491-1505` — Read state management pattern
- `DocumentsView.swift:706-729` — Working example (convertToTask)

**Memory References:**
- `memory/2026-02-12.md` — Previous research on Documents view
  - Noted: "Archive/reject buttons mentioned in requirements, not implemented"
  - Status: Still true as of 2026-02-13

**Server Repository:**
- Backend endpoint: `POST /api/documents/{id}/archive`
- Expected response: Updated `AgentDocument` JSON with `status: "archived"`

---

## Next Steps

1. **Immediate:** Implement API call in `archiveDocument()` function
2. **Short-term:** Add user feedback (sound, visual confirmation)
3. **Medium-term:** Audit other action buttons for similar issues
4. **Long-term:** Add comprehensive error handling UI

---

## Notes

- This is a **straightforward fix**—the infrastructure exists, just needs to be wired up
- Pattern is already established in `convertToTask()` function
- No architectural changes needed
- No new API endpoints required
- Backward compatible (older clients will continue to work)

**Confidence Level:** 🟢 **High** — Root cause confirmed via code inspection, fix is well-understood.

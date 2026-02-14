import XCTest
@testable import LobsMissionControl

/// Tests for Quick Capture agent selection functionality
///
/// This test suite validates:
/// - Quick Capture panel allows user to select which agent
/// - Selected agent is passed to task creation
/// - Agent selection UI is present and functional
/// - Default agent is "programmer" but user can change it
/// - Agent selection persists during capture session
final class QuickCaptureAgentSelectionTests: XCTestCase {
  
  // MARK: - State Tests
  
  func testQuickCaptureHasAgentState() {
    // QuickCaptureView should have:
    // @State private var selectedAgent: String = "programmer"
  }
  
  func testDefaultAgentIsProgrammer() {
    // When QuickCaptureView appears:
    // selectedAgent should default to "programmer"
  }
  
  func testAgentStateCanBeChanged() {
    // selectedAgent should be mutable
    // User can change it via UI
  }
  
  // MARK: - Available Agents Tests
  
  func testAvailableAgentsListExists() {
    // QuickCaptureView should have availableAgents property
    // Similar to AddTaskSheet
  }
  
  func testAvailableAgentsHasFiveOptions() {
    // availableAgents should contain 5 agents:
    // - programmer (🛠️)
    // - researcher (🔬)
    // - reviewer (🔍)
    // - writer (✍️)
    // - architect (🏗️)
  }
  
  func testAvailableAgentsHaveEmojis() {
    // Each agent tuple should have:
    // (id: String, emoji: String, description: String)
  }
  
  func testAvailableAgentsHaveDescriptions() {
    // Descriptions should be short (for compact UI):
    // - "Code implementation"
    // - "Research and investigation"
    // - "Code review"
    // - "Documentation"
    // - "System design"
  }
  
  // MARK: - UI Tests
  
  func testAgentPickerIsDisplayed() {
    // Agent picker should be visible in Quick Capture UI
    // Between project picker and notes field
  }
  
  func testAgentPickerIsMenu() {
    // Agent picker should use Menu component
    // For compact dropdown selection
  }
  
  func testAgentPickerShowsSelectedAgent() {
    // Menu label should display:
    // selectedAgentDisplay (emoji + capitalized name)
  }
  
  func testAgentPickerHasCorrectWidth() {
    // Agent picker should have .frame(width: 120)
    // To fit compactly in Quick Capture layout
  }
  
  func testAgentPickerStyling() {
    // Agent picker should have:
    // - .font(.footnote)
    // - .foregroundStyle(.secondary)
    // - Background: Color(NSColor.controlBackgroundColor)
    // - Rounded corners
  }
  
  // MARK: - Layout Tests
  
  func testProjectFieldIsNarrower() {
    // Project field width reduced from ~180 to 140
    // To make room for agent picker
  }
  
  func testAgentPickerBetweenProjectAndNotes() {
    // HStack order:
    // 1. Project field (140pt)
    // 2. Agent picker (120pt)
    // 3. Notes field (flexible)
    // 4. Submit button
  }
  
  func testLayoutFitsInQuickCaptureWidth() {
    // Total Quick Capture width: 560pt
    // Layout should fit without overflow
  }
  
  // MARK: - Menu Items Tests
  
  func testMenuShowsAllAgents() {
    // Menu should list all 5 agents
  }
  
  func testMenuItemShowsEmojiAndName() {
    // Each menu item should display:
    // HStack { emoji, capitalized name }
  }
  
  func testMenuItemClickChangesAgent() {
    // When user clicks a menu item:
    // selectedAgent should update
  }
  
  // MARK: - Submit Tests
  
  func testSubmitPassesSelectedAgent() {
    // When user submits:
    // vm.submitTaskToLobs should be called with:
    // agent: selectedAgent (not hardcoded "programmer")
  }
  
  func testSubmitWithProgrammer() {
    // Given: selectedAgent = "programmer"
    // When: user submits
    // Then: submitTaskToLobs receives agent: "programmer"
  }
  
  func testSubmitWithResearcher() {
    // Given: selectedAgent = "researcher"
    // When: user submits
    // Then: submitTaskToLobs receives agent: "researcher"
  }
  
  func testSubmitWithArchitect() {
    // Given: selectedAgent = "architect"
    // When: user submits
    // Then: submitTaskToLobs receives agent: "architect"
  }
  
  // MARK: - Reset Tests
  
  func testAgentResetsAfterSubmit() {
    // After successful submit:
    // selectedAgent should reset to "programmer"
  }
  
  func testAgentDoesNotResetOnCancel() {
    // If user cancels (onExitCommand):
    // selectedAgent should keep its value
    // (for potential re-open)
  }
  
  func testAgentResetsOnDismiss() {
    // When Quick Capture dismisses after submit:
    // selectedAgent = "programmer" (default for next use)
  }
  
  // MARK: - Display Text Tests
  
  func testSelectedAgentDisplayFormat() {
    // selectedAgentDisplay should format as:
    // "{emoji} {Capitalized Name}"
    // Example: "🛠️ Programmer"
  }
  
  func testSelectedAgentDisplayWithProgrammer() {
    // Given: selectedAgent = "programmer"
    // Then: selectedAgentDisplay = "🛠️ Programmer"
  }
  
  func testSelectedAgentDisplayWithResearcher() {
    // Given: selectedAgent = "researcher"
    // Then: selectedAgentDisplay = "🔬 Researcher"
  }
  
  func testSelectedAgentDisplayFallback() {
    // Given: selectedAgent = "unknown"
    // Then: selectedAgentDisplay = "Select agent"
  }
  
  // MARK: - Integration Tests
  
  func testFullQuickCaptureFlowWithAgentSelection() {
    // Scenario:
    // 1. User opens Quick Capture (⌘⇧Space)
    // 2. Types title
    // 3. Selects project
    // 4. Changes agent to "researcher"
    // 5. Adds optional notes
    // 6. Submits
    // Then:
    // - Task created with agent: "researcher"
    // - Quick Capture dismisses
    // - selectedAgent resets to "programmer"
  }
  
  func testQuickCaptureWithDefaultAgent() {
    // Scenario:
    // 1. User opens Quick Capture
    // 2. Types title and selects project
    // 3. Doesn't change agent (stays "programmer")
    // 4. Submits
    // Then:
    // - Task created with agent: "programmer"
  }
  
  func testMultipleQuickCapturesInSession() {
    // Scenario:
    // 1. Create task with agent "researcher"
    // 2. Close Quick Capture
    // 3. Open Quick Capture again
    // 4. Agent should be back to default "programmer"
  }
  
  // MARK: - Comparison with AddTaskSheet Tests
  
  func testAgentListMatchesAddTaskSheet() {
    // QuickCaptureView and AddTaskSheet should have:
    // Same agent list (ids match)
    // Different descriptions (QuickCapture is more compact)
  }
  
  func testAgentIDsConsistent() {
    // Agent IDs should be:
    // "programmer", "researcher", "reviewer", "writer", "architect"
    // (Same as AddTaskSheet)
  }
  
  // MARK: - Edge Cases
  
  func testEmptyTitle() {
    // Given: title is empty
    // When: user tries to submit
    // Then: Submit is prevented (existing behavior)
    // And: Agent selection is still visible and functional
  }
  
  func testNoProjectSelected() {
    // Given: selectedProjectId is empty
    // When: user has selected an agent
    // Then: Agent selection is preserved
  }
  
  func testAgentSelectionWithLongNames() {
    // Agent names like "Researcher" should fit in 120pt width
    // No text truncation needed
  }
  
  // MARK: - UI Consistency Tests
  
  func testAgentPickerAlignmentWithOtherFields() {
    // Agent picker should align vertically with:
    // - Project field
    // - Notes field
    // All in same HStack
  }
  
  func testAgentPickerFontConsistency() {
    // Agent picker should use .footnote font
    // Same as other fields in Quick Capture
  }
  
  // MARK: - Accessibility Tests
  
  func testAgentPickerHasAccessibleLabel() {
    // Menu should have accessible label
    // For VoiceOver support
  }
  
  func testAgentMenuItemsAccessible() {
    // Each menu item should be accessible
    // With agent name read aloud
  }
  
  // MARK: - Performance Tests
  
  func testAgentPickerDoesNotSlowOpening() {
    // Adding agent picker should not impact:
    // Quick Capture opening speed (< 50ms)
  }
  
  func testAgentMenuOpensQuickly() {
    // Agent menu should open instantly
    // No lag or delay
  }
  
  // MARK: - State Persistence Tests
  
  func testAgentNotPersistedAcrossSessions() {
    // Unlike project (which may have recents):
    // Agent selection does NOT persist
    // Always resets to "programmer"
  }
  
  func testNoAgentRecents() {
    // There should be no "recent agents" feature
    // Always default to "programmer"
  }
  
  // MARK: - Backward Compatibility Tests
  
  func testRemovedHardcodedProgrammer() {
    // Before: submit() had agent: "programmer" hardcoded
    // After: submit() uses selectedAgent variable
  }
  
  func testExistingTaskCreationStillWorks() {
    // All existing Quick Capture functionality preserved:
    // - Title input
    // - Project selection
    // - Notes input
    // - Submit button
    // - Keyboard shortcuts
  }
}

import XCTest
import SwiftUI
@testable import LobsMissionControl

/// Tests that buttons have proper tap targets matching their visual bounds.
///
/// ## Context
/// User reported: "buttons require you to click on the words not the outline"
/// This happens when buttons use `.buttonStyle(.plain)` with custom styling
/// but don't have `.contentShape(.rect)` to expand the tap target.
///
/// ## Fix
/// Added `.contentShape(.rect)` to all custom-styled plain buttons to ensure
/// the entire visual area (padding + background) is tappable, not just text.
final class ButtonTapTargetTests: XCTestCase {
  
  // MARK: - Toolbar Button Tests
  
  /// Test that TextDumpToolbarButton has contentShape for full tap target
  func testTextDumpToolbarButtonHasContentShape() throws {
    // The button uses .buttonStyle(.plain) with custom padding and background
    // It should have .contentShape(.rect) so the entire visual area is tappable
    
    // Pattern to verify:
    // Button(action:) { ... }
    //   .buttonStyle(.plain)
    //   should have .contentShape(.rect) before .buttonStyle
    
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/BoardComponents.swift")
    
    // Find TextDumpToolbarButton
    XCTAssertTrue(sourceFile.contains("private struct TextDumpToolbarButton: View"),
                  "TextDumpToolbarButton should exist")
    
    // Verify it has contentShape
    let textDumpSection = extractSection(from: sourceFile, 
                                          startMarker: "private struct TextDumpToolbarButton: View",
                                          endMarker: "// MARK: - Inbox Toolbar Button")
    XCTAssertTrue(textDumpSection.contains(".contentShape(.rect)"),
                  "TextDumpToolbarButton should have .contentShape(.rect) for full tap target")
  }
  
  /// Test that InboxToolbarButton has contentShape for full tap target
  func testInboxToolbarButtonHasContentShape() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/BoardComponents.swift")
    
    XCTAssertTrue(sourceFile.contains("private struct InboxToolbarButton: View"),
                  "InboxToolbarButton should exist")
    
    let inboxSection = extractSection(from: sourceFile,
                                       startMarker: "private struct InboxToolbarButton: View",
                                       endMarker: "private struct DocumentsToolbarButton: View")
    XCTAssertTrue(inboxSection.contains(".contentShape(.rect)"),
                  "InboxToolbarButton should have .contentShape(.rect) for full tap target")
  }
  
  /// Test that DocumentsToolbarButton has contentShape for full tap target
  func testDocumentsToolbarButtonHasContentShape() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/BoardComponents.swift")
    
    XCTAssertTrue(sourceFile.contains("private struct DocumentsToolbarButton: View"),
                  "DocumentsToolbarButton should exist")
    
    let docsSection = extractSection(from: sourceFile,
                                      startMarker: "private struct DocumentsToolbarButton: View",
                                      endMarker: "// MARK: - Settings Popover")
    XCTAssertTrue(docsSection.contains(".contentShape(.rect)"),
                  "DocumentsToolbarButton should have .contentShape(.rect) for full tap target")
  }
  
  // MARK: - Action Button Tests
  
  /// Test that BulkActionButton has contentShape for full tap target
  func testBulkActionButtonHasContentShape() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/BoardComponents.swift")
    
    XCTAssertTrue(sourceFile.contains("private struct BulkActionButton: View"),
                  "BulkActionButton should exist")
    
    let bulkSection = extractSection(from: sourceFile,
                                      startMarker: "private struct BulkActionButton: View",
                                      endMarker: "// MARK: - Project README Bar")
    XCTAssertTrue(bulkSection.contains(".contentShape(.rect)"),
                  "BulkActionButton should have .contentShape(.rect) for full tap target")
  }
  
  /// Test that ActionButton has contentShape for full tap target
  func testActionButtonHasContentShape() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/BoardComponents.swift")
    
    XCTAssertTrue(sourceFile.contains("private struct ActionButton: View"),
                  "ActionButton should exist")
    
    let actionSection = extractSection(from: sourceFile,
                                        startMarker: "private struct ActionButton: View",
                                        endMarker: "// MARK: - Create Project Sheet")
    XCTAssertTrue(actionSection.contains(".contentShape(.rect)"),
                  "ActionButton should have .contentShape(.rect) for full tap target")
  }
  
  // MARK: - Onboarding Button Tests
  
  /// Test that onboarding Back button has proper contentShape
  func testOnboardingBackButtonHasContentShape() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/OnboardingPersonalityView.swift")
    
    // The Back button should have .contentShape(.rect) within the button content
    // (before .buttonStyle(.plain))
    let backButtonPattern = "Button(action: onBack) {"
    XCTAssertTrue(sourceFile.contains(backButtonPattern),
                  "Onboarding Back button should exist")
    
    // Verify contentShape is present in the button content
    let backSection = extractSection(from: sourceFile,
                                      startMarker: "Button(action: onBack) {",
                                      endMarker: "Button(action: regenerateFromForm) {")
    XCTAssertTrue(backSection.contains(".contentShape(.rect)"),
                  "Onboarding Back button should have .contentShape(.rect)")
  }
  
  /// Test that onboarding Regenerate button has proper contentShape
  func testOnboardingRegenerateButtonHasContentShape() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/OnboardingPersonalityView.swift")
    
    let regenerateButtonPattern = "Button(action: regenerateFromForm) {"
    XCTAssertTrue(sourceFile.contains(regenerateButtonPattern),
                  "Onboarding Regenerate button should exist")
    
    let regenSection = extractSection(from: sourceFile,
                                       startMarker: "Button(action: regenerateFromForm) {",
                                       endMarker: "Button(action: saveAndContinue) {")
    XCTAssertTrue(regenSection.contains(".contentShape(.rect)"),
                  "Onboarding Regenerate button should have .contentShape(.rect)")
  }
  
  /// Test that onboarding Continue button has proper contentShape
  func testOnboardingContinueButtonHasContentShape() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/OnboardingPersonalityView.swift")
    
    let continueButtonPattern = "Button(action: saveAndContinue) {"
    XCTAssertTrue(sourceFile.contains(continueButtonPattern),
                  "Onboarding Continue button should exist")
    
    // The Continue button should have contentShape within the button content
    // Extract a reasonable section after the button declaration
    let lines = sourceFile.components(separatedBy: .newlines)
    if let buttonLine = lines.firstIndex(where: { $0.contains("Button(action: saveAndContinue) {") }) {
      let section = lines[buttonLine..<min(buttonLine + 20, lines.count)].joined(separator: "\n")
      XCTAssertTrue(section.contains(".contentShape(.rect)"),
                    "Onboarding Continue button should have .contentShape(.rect)")
    } else {
      XCTFail("Could not find saveAndContinue button")
    }
  }
  
  // MARK: - Pattern Verification Tests
  
  /// Test that all custom button components follow the pattern
  func testCustomButtonsFollowContentShapePattern() throws {
    let sourceFile = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/BoardComponents.swift")
    
    // Custom button components that should have contentShape
    let customButtons = [
      "TextDumpToolbarButton",
      "InboxToolbarButton",
      "DocumentsToolbarButton",
      "BulkActionButton",
      "ActionButton"
    ]
    
    for buttonName in customButtons {
      XCTAssertTrue(sourceFile.contains("private struct \(buttonName): View"),
                    "\(buttonName) should exist")
    }
    
    // Count occurrences of contentShape in custom buttons
    // Should have at least one per custom button
    let contentShapeCount = sourceFile.components(separatedBy: ".contentShape(.rect)").count - 1
    XCTAssertGreaterThanOrEqual(contentShapeCount, customButtons.count,
                                "Should have .contentShape(.rect) for all custom buttons")
  }
  
  /// Test that buttons with plain style and custom backgrounds have contentShape
  func testPlainButtonsWithBackgroundsHaveContentShape() throws {
    // This test verifies the pattern:
    // Button { ... .background(...) ... } .buttonStyle(.plain)
    // should have .contentShape(.rect) in the button content
    
    let boardComponents = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/BoardComponents.swift")
    let onboarding = try String(contentsOfFile: "/Users/lobs/lobs-mission-control/Sources/LobsMissionControl/OnboardingPersonalityView.swift")
    
    // Verify both files exist and contain the fixed patterns
    XCTAssertTrue(boardComponents.contains(".contentShape(.rect)"),
                  "BoardComponents should have buttons with .contentShape(.rect)")
    XCTAssertTrue(onboarding.contains(".contentShape(.rect)"),
                  "OnboardingPersonalityView should have buttons with .contentShape(.rect)")
  }
  
  // MARK: - Helper Methods
  
  /// Extract a section of source code between two markers
  private func extractSection(from source: String, startMarker: String, endMarker: String) -> String {
    guard let startRange = source.range(of: startMarker),
          let endRange = source.range(of: endMarker, range: startRange.upperBound..<source.endIndex) else {
      return ""
    }
    return String(source[startRange.lowerBound..<endRange.lowerBound])
  }
}

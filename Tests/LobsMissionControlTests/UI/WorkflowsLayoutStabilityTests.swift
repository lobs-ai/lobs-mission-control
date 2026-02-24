import XCTest
@testable import LobsMissionControl

final class WorkflowsLayoutStabilityTests: XCTestCase {
    func testWorkflowsViewUsesFixedTwoColumnLayout() throws {
        let source = try String(
            contentsOfFile: "Sources/LobsMissionControl/Workflows/WorkflowsView.swift",
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("HStack(spacing: 0)"), "Workflows layout should use non-resizable HStack columns")
        XCTAssertTrue(source.contains(".frame(width: sidebarWidth)"), "Workflow list column should use a fixed width")
        XCTAssertFalse(source.contains("HSplitView"), "Workflows view should not use resizable HSplitView")
    }
}

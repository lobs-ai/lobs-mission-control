import XCTest
@testable import LobsMissionControl

final class AddTaskSheetValidationLogicTests: XCTestCase {
  func testResolveTargetProjectId_UsesExplicitProjectWhenProvided() {
    let resolved = AddTaskSheetValidation.resolveTargetProjectId(
      explicitProjectId: "project-123",
      selectedProjectId: "other-project"
    )

    XCTAssertEqual(resolved, "project-123")
  }

  func testResolveTargetProjectId_UsesSelectedProjectWhenNoExplicitProject() {
    let resolved = AddTaskSheetValidation.resolveTargetProjectId(
      explicitProjectId: nil,
      selectedProjectId: "project-abc"
    )

    XCTAssertEqual(resolved, "project-abc")
  }

  func testResolveTargetProjectId_ReturnsNilForBlankSelection() {
    let resolved = AddTaskSheetValidation.resolveTargetProjectId(
      explicitProjectId: nil,
      selectedProjectId: "   "
    )

    XCTAssertNil(resolved)
  }

  func testMissingProject_TrueWhenNoExplicitProjectAndNoSelection() {
    XCTAssertTrue(
      AddTaskSheetValidation.missingProject(
        explicitProjectId: nil,
        selectedProjectId: ""
      )
    )
  }

  func testMissingProject_FalseWhenExplicitProjectProvided() {
    XCTAssertFalse(
      AddTaskSheetValidation.missingProject(
        explicitProjectId: "project-123",
        selectedProjectId: ""
      )
    )
  }
}

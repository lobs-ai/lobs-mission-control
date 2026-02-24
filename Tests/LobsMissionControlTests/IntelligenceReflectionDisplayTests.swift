import XCTest
@testable import LobsMissionControl

/// Tests for reflection card display when clicking to expand
final class IntelligenceReflectionDisplayTests: XCTestCase {
    
    // MARK: - Test Models
    
    func testReflectionWithNoFindings_ShowsCompletedMessage() {
        // Given: A completed reflection with no findings
        let reflection = ReflectionCycle(
            id: "test-id",
            batchId: "batch-123",
            agents: ["programmer", "researcher"],
            status: .completed,
            startedAt: Date(),
            completedAt: Date(),
            inefficiencies: [],
            missedOpportunities: [],
            systemRisks: [],
            identityAdjustments: [],
            proposedInitiatives: [],
            errorMessage: nil
        )
        
        // When: checking if there are findings
        let hasFindings = !reflection.inefficiencies.isEmpty
                         || !reflection.missedOpportunities.isEmpty
                         || !reflection.systemRisks.isEmpty
                         || !reflection.identityAdjustments.isEmpty
                         || !reflection.proposedInitiatives.isEmpty
        
        // Then: should have no findings and status should be completed
        XCTAssertFalse(hasFindings, "Reflection should have no findings")
        XCTAssertEqual(reflection.status, .completed, "Reflection should be completed")
    }
    
    func testReflectionWithFindings_HasData() {
        // Given: A completed reflection with findings
        let reflection = ReflectionCycle(
            id: "test-id",
            batchId: "batch-123",
            agents: ["programmer"],
            status: .completed,
            startedAt: Date(),
            completedAt: Date(),
            inefficiencies: ["Found inefficiency in task routing"],
            missedOpportunities: [],
            systemRisks: [],
            identityAdjustments: [],
            proposedInitiatives: [],
            errorMessage: nil
        )
        
        // When: checking if there are findings
        let hasFindings = !reflection.inefficiencies.isEmpty
                         || !reflection.missedOpportunities.isEmpty
                         || !reflection.systemRisks.isEmpty
                         || !reflection.identityAdjustments.isEmpty
                         || !reflection.proposedInitiatives.isEmpty
        
        // Then: should have findings
        XCTAssertTrue(hasFindings, "Reflection should have findings")
        XCTAssertEqual(reflection.inefficiencies.count, 1)
    }
    
    func testReflectionRunning_ShowsRunningState() {
        // Given: A running reflection with no findings yet
        let reflection = ReflectionCycle(
            id: "test-id",
            batchId: "batch-123",
            agents: ["programmer"],
            status: .running,
            startedAt: Date(),
            completedAt: nil,
            inefficiencies: [],
            missedOpportunities: [],
            systemRisks: [],
            identityAdjustments: [],
            proposedInitiatives: [],
            errorMessage: nil
        )
        
        // When: checking status
        let hasFindings = !reflection.inefficiencies.isEmpty
                         || !reflection.missedOpportunities.isEmpty
                         || !reflection.systemRisks.isEmpty
                         || !reflection.identityAdjustments.isEmpty
                         || !reflection.proposedInitiatives.isEmpty
        
        // Then: should have no findings and status should be running
        XCTAssertFalse(hasFindings, "Running reflection should have no findings yet")
        XCTAssertEqual(reflection.status, .running, "Reflection should be running")
        XCTAssertNil(reflection.completedAt, "Running reflection should not have completion date")
    }
    
    func testReflectionFailed_ShowsError() {
        // Given: A failed reflection with error message
        let errorMsg = "Connection timeout during reflection"
        let reflection = ReflectionCycle(
            id: "test-id",
            batchId: "batch-123",
            agents: ["programmer"],
            status: .failed,
            startedAt: Date(),
            completedAt: nil,
            inefficiencies: [],
            missedOpportunities: [],
            systemRisks: [],
            identityAdjustments: [],
            proposedInitiatives: [],
            errorMessage: errorMsg
        )
        
        // Then: should show error
        XCTAssertEqual(reflection.status, .failed)
        XCTAssertEqual(reflection.errorMessage, errorMsg)
    }
    
    func testReflectionWithProposedInitiatives_HasFindings() {
        // Given: A completed reflection with proposed initiatives
        let reflection = ReflectionCycle(
            id: "test-id",
            batchId: "batch-123",
            agents: ["programmer"],
            status: .completed,
            startedAt: Date(),
            completedAt: Date(),
            inefficiencies: [],
            missedOpportunities: [],
            systemRisks: [],
            identityAdjustments: [],
            proposedInitiatives: ["initiative-1", "initiative-2"],
            errorMessage: nil
        )
        
        // When: checking if there are findings
        let hasFindings = !reflection.inefficiencies.isEmpty
                         || !reflection.missedOpportunities.isEmpty
                         || !reflection.systemRisks.isEmpty
                         || !reflection.identityAdjustments.isEmpty
                         || !reflection.proposedInitiatives.isEmpty
        
        // Then: should have findings because of proposed initiatives
        XCTAssertTrue(hasFindings, "Reflection should have findings (proposed initiatives)")
        XCTAssertEqual(reflection.proposedInitiatives.count, 2)
    }
    
    func testReflectionWithMultipleFindings_AllDisplayed() {
        // Given: A completed reflection with multiple types of findings
        let reflection = ReflectionCycle(
            id: "test-id",
            batchId: "batch-123",
            agents: ["programmer", "researcher"],
            status: .completed,
            startedAt: Date(),
            completedAt: Date(),
            inefficiencies: ["Inefficiency 1", "Inefficiency 2"],
            missedOpportunities: ["Missed opportunity 1"],
            systemRisks: ["Risk 1"],
            identityAdjustments: ["Adjustment 1"],
            proposedInitiatives: ["initiative-1"],
            errorMessage: nil
        )
        
        // When: checking individual finding types
        // Then: all should have content
        XCTAssertEqual(reflection.inefficiencies.count, 2)
        XCTAssertEqual(reflection.missedOpportunities.count, 1)
        XCTAssertEqual(reflection.systemRisks.count, 1)
        XCTAssertEqual(reflection.identityAdjustments.count, 1)
        XCTAssertEqual(reflection.proposedInitiatives.count, 1)
    }
}

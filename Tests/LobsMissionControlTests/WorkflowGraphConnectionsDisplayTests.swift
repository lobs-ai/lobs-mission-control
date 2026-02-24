import XCTest
@testable import LobsMissionControl

final class WorkflowGraphConnectionsDisplayTests: XCTestCase {
    func testConnectionSummaryFiltersUnknownNodesAndDeduplicates() {
        let nodes = [
            WorkflowNode(id: "start", type: "tool_call", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil),
            WorkflowNode(id: "next", type: "notify", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil),
            WorkflowNode(id: "done", type: "cleanup", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil)
        ]

        let edges: [ResolvedEdge] = [
            .init(from: "start", to: "next", kind: .normal, label: nil),
            .init(from: "start", to: "next", kind: .success, label: "success"), // duplicate endpoint pair
            .init(from: "next", to: "done", kind: .normal, label: nil),
            .init(from: "ghost", to: "done", kind: .normal, label: nil) // unknown source should be ignored
        ]

        let summary = WorkflowConnectionSummary.build(nodes: nodes, edges: edges)

        XCTAssertEqual(summary["start"], WorkflowNodeConnections(incoming: [], outgoing: ["next"]))
        XCTAssertEqual(summary["next"], WorkflowNodeConnections(incoming: ["start"], outgoing: ["done"]))
        XCTAssertEqual(summary["done"], WorkflowNodeConnections(incoming: ["next"], outgoing: []))
    }

    func testShortNodeLabelUsesEllipsisForLongIds() {
        XCTAssertEqual(NodeChip.shortNodeLabel(for: "abcd1234efgh"), "abcd…fgh")
        XCTAssertEqual(NodeChip.shortNodeLabel(for: "short"), "short")
    }
}

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

    func testConnectionSummaryTextShowsIncomingAndOutgoingCounts() {
        XCTAssertEqual(NodeChip.connectionSummary(incoming: 0, outgoing: 0), "0 in · 0 out")
        XCTAssertEqual(NodeChip.connectionSummary(incoming: 2, outgoing: 5), "2 in · 5 out")
    }

    func testConnectionTokenPreviewLimitMatchesGraphDisplayExpectation() {
        XCTAssertEqual(NodeChip.connectionTokenPreviewLimit, 5)
    }

    func testConnectionPreviewTextShowsOverflowCount() {
        let ids = ["a", "b", "c", "d", "e", "f"]
        let labels = ["a": "alpha", "b": "beta"]

        let preview = NodeChip.connectionPreviewText(ids: ids, nodeLabelsById: labels, limit: 5)

        XCTAssertEqual(preview, "alpha, beta, c, d, e +1")
    }

    func testConnectionPreviewTextShowsNoneForEmptyConnections() {
        XCTAssertEqual(NodeChip.connectionPreviewText(ids: [], nodeLabelsById: [:], limit: 5), "none")
    }

    func testConnectionTokensPreferFriendlyLabelsAndFallBackToShortIds() {
        let ids = ["node-alpha", "node-beta", "abcdef123456"]
        let labels = ["node-alpha": "alpha"]

        let tokens = NodeChip.connectionTokens(ids: ids, nodeLabelsById: labels, limit: 3)

        XCTAssertEqual(tokens, ["alpha", "node-beta", "abcd…456"])
    }
}

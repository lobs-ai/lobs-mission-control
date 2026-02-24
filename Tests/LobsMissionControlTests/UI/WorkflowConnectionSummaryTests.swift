import XCTest
@testable import LobsMissionControl

final class WorkflowConnectionSummaryTests: XCTestCase {
    func testBuildAggregatesIncomingAndOutgoingConnections() {
        let nodes = [
            WorkflowNode(id: "start", type: "tool_call", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil),
            WorkflowNode(id: "branch", type: "branch", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil),
            WorkflowNode(id: "notify", type: "notify", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil)
        ]

        let edges = [
            ResolvedEdge(from: "start", to: "branch", kind: .normal, label: nil),
            ResolvedEdge(from: "branch", to: "notify", kind: .success, label: "success"),
            ResolvedEdge(from: "start", to: "branch", kind: .normal, label: "duplicate")
        ]

        let summary = WorkflowConnectionSummary.build(nodes: nodes, edges: edges)

        XCTAssertEqual(summary["start"], WorkflowNodeConnections(incoming: [], outgoing: ["branch"]))
        XCTAssertEqual(summary["branch"], WorkflowNodeConnections(incoming: ["start"], outgoing: ["notify"]))
        XCTAssertEqual(summary["notify"], WorkflowNodeConnections(incoming: ["branch"], outgoing: []))
    }

    func testBuildIgnoresEdgesToUnknownNodes() {
        let nodes = [
            WorkflowNode(id: "a", type: "tool_call", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil),
            WorkflowNode(id: "b", type: "tool_call", config: nil, onSuccess: nil, onFailure: nil, inputs: nil, timeoutSeconds: nil)
        ]

        let edges = [
            ResolvedEdge(from: "a", to: "b", kind: .normal, label: nil),
            ResolvedEdge(from: "ghost", to: "a", kind: .normal, label: nil),
            ResolvedEdge(from: "b", to: "missing", kind: .failure, label: "failure")
        ]

        let summary = WorkflowConnectionSummary.build(nodes: nodes, edges: edges)

        XCTAssertEqual(summary["a"], WorkflowNodeConnections(incoming: [], outgoing: ["b"]))
        XCTAssertEqual(summary["b"], WorkflowNodeConnections(incoming: ["a"], outgoing: []))
    }
}

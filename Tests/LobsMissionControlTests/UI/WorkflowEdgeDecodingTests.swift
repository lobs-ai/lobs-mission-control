import XCTest
@testable import LobsMissionControl

final class WorkflowEdgeDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesStandardFromToKeys() throws {
        let data = Data(#"{"from":"start","to":"notify","condition":"ok"}"#.utf8)

        let edge = try decoder.decode(WorkflowEdge.self, from: data)

        XCTAssertEqual(edge.from, "start")
        XCTAssertEqual(edge.to, "notify")
        XCTAssertEqual(edge.condition, "ok")
    }

    func testDecodesSourceTargetKeys() throws {
        let data = Data(#"{"source":"alpha","target":"beta"}"#.utf8)

        let edge = try decoder.decode(WorkflowEdge.self, from: data)

        XCTAssertEqual(edge.from, "alpha")
        XCTAssertEqual(edge.to, "beta")
        XCTAssertNil(edge.condition)
    }

    func testEncodingAlwaysUsesFromToKeys() throws {
        let edge = WorkflowEdge(from: "a", to: "b", condition: "success")

        let data = try JSONEncoder().encode(edge)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: String]

        XCTAssertEqual(object?["from"], "a")
        XCTAssertEqual(object?["to"], "b")
        XCTAssertEqual(object?["condition"], "success")
        XCTAssertNil(object?["source"])
        XCTAssertNil(object?["target"])
    }
}

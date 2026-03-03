import Foundation

// MARK: - Workflow Definition

struct WorkflowDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let version: Int
    let nodes: [WorkflowNode]
    let edges: [WorkflowEdge]
    let trigger: WorkflowTrigger?
    let metadata: WorkflowMetadata?
    let isActive: Bool
    let nodeCount: Int?
    let createdAt: String?
    let updatedAt: String?

    static func == (lhs: WorkflowDefinition, rhs: WorkflowDefinition) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct WorkflowNode: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let config: [String: AnyCodable]?
    let onSuccess: String?
    let onFailure: WorkflowFailurePolicy?
    let inputs: [String]?
    let timeoutSeconds: Int?

    // No manual CodingKeys — APIService uses .convertFromSnakeCase which automatically
    // converts on_success → onSuccess, on_failure → onFailure, timeout_seconds → timeoutSeconds.

    static func == (lhs: WorkflowNode, rhs: WorkflowNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct WorkflowFailurePolicy: Codable, Hashable {
    let retry: Int?
    let fallback: String?
    let escalateAfter: Int?
    let abortOn: [String]?
    // .convertFromSnakeCase handles escalate_after → escalateAfter, abort_on → abortOn
}

struct WorkflowEdge: Codable, Hashable {
    let from: String
    let to: String
    let condition: String?

    enum CodingKeys: String, CodingKey {
        case from, to, condition
        case source, target
    }

    init(from: String, to: String, condition: String? = nil) {
        self.from = from
        self.to = to
        self.condition = condition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedFrom = try container.decodeIfPresent(String.self, forKey: .from)
            ?? container.decodeIfPresent(String.self, forKey: .source)
        let decodedTo = try container.decodeIfPresent(String.self, forKey: .to)
            ?? container.decodeIfPresent(String.self, forKey: .target)

        guard let from = decodedFrom, let to = decodedTo else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath, debugDescription: "Workflow edge must include from/to or source/target")
            )
        }

        self.from = from
        self.to = to
        self.condition = try container.decodeIfPresent(String.self, forKey: .condition)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encodeIfPresent(condition, forKey: .condition)
    }
}

struct WorkflowTrigger: Codable, Hashable {
    let type: String?
    let cron: String?
    let timezone: String?
    let eventPattern: String?
    let agentTypes: [String]?
    // .convertFromSnakeCase handles event_pattern → eventPattern, agent_types → agentTypes
}

struct WorkflowMetadata: Codable, Hashable {
    let author: String?
    let category: String?
    let system: Bool?
}

// MARK: - Workflow Run

struct WorkflowRun: Codable, Identifiable, Hashable {
    let id: String
    let workflowId: String
    let workflowVersion: Int
    let taskId: String?
    let triggerType: String
    let status: String
    let currentNode: String?
    let nodeStates: [String: NodeState]?
    let error: String?
    let sessionKey: String?
    let startedAt: String?
    let finishedAt: String?
    let createdAt: String?

    static func == (lhs: WorkflowRun, rhs: WorkflowRun) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct NodeState: Codable, Hashable {
    let status: String?
    let attempts: Int?
    let error: String?
    let output: [String: AnyCodable]?
    let startedAt: String?
    let finishedAt: String?
    // .convertFromSnakeCase handles started_at → startedAt, finished_at → finishedAt
}

// MARK: - Run Trace

struct WorkflowRunTrace: Codable {
    let runId: String
    let workflow: String
    let status: String
    let startedAt: String?
    let finishedAt: String?
    let nodes: [TraceNode]
    // .convertFromSnakeCase handles run_id → runId, started_at → startedAt, finished_at → finishedAt
}

struct TraceNode: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let status: String
    let attempts: Int
    let error: String?
    let startedAt: String?
    let finishedAt: String?
    // .convertFromSnakeCase handles started_at → startedAt, finished_at → finishedAt
}

// MARK: - AnyCodable (lightweight JSON bridge)

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else if let i = try? container.decode(Int.self) {
            value = i
        } else if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let a = try? container.decode([AnyCodable].self) {
            value = a.map(\.value)
        } else if let d = try? container.decode([String: AnyCodable].self) {
            value = d.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let b as Bool:
            try container.encode(b)
        case let i as Int:
            try container.encode(i)
        case let d as Double:
            try container.encode(d)
        case let s as String:
            try container.encode(s)
        case let a as [Any]:
            try container.encode(a.map { AnyCodable($0) })
        case let d as [String: Any]:
            try container.encode(d.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }

    var stringValue: String {
        switch value {
        case let s as String: return s
        case let i as Int: return "\(i)"
        case let d as Double: return "\(d)"
        case let b as Bool: return b ? "true" : "false"
        case let a as [Any]: return "[\(a.count) items]"
        case let d as [String: Any]: return "{\(d.count) keys}"
        default: return "null"
        }
    }
}


// MARK: - Write Requests

struct WorkflowCreateRequest: Codable {
    let name: String
    let description: String?
    let nodes: [WorkflowNode]
    let edges: [WorkflowEdge]
    let trigger: WorkflowTrigger?
    let metadata: WorkflowMetadata?
    let isActive: Bool
    // APIService encoder uses .convertToSnakeCase: isActive → is_active automatically
}

struct WorkflowUpdateRequest: Codable {
    var name: String?
    var description: String?
    var nodes: [WorkflowNode]?
    var edges: [WorkflowEdge]?
    var trigger: WorkflowTrigger?
    var metadata: WorkflowMetadata?
    var isActive: Bool?
    // APIService encoder uses .convertToSnakeCase: isActive → is_active automatically
}

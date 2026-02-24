import Foundation

extension APIService {
    // MARK: - Workflow Definitions

    func fetchWorkflows(activeOnly: Bool = false) async throws -> [WorkflowDefinition] {
        try await request(
            method: "GET",
            path: "/api/workflows",
            queryItems: [URLQueryItem(name: "active_only", value: activeOnly ? "true" : "false")]
        )
    }

    func fetchWorkflow(id: String) async throws -> WorkflowDefinition {
        try await request(method: "GET", path: "/api/workflows/\(id)")
    }

    // MARK: - Workflow Runs

    func fetchWorkflowRuns(workflowId: String, limit: Int = 20, status: String? = nil) async throws -> [WorkflowRun] {
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return try await request(
            method: "GET",
            path: "/api/workflows/\(workflowId)/runs",
            queryItems: queryItems
        )
    }

    func fetchWorkflowRunTrace(runId: String) async throws -> WorkflowRunTrace {
        try await request(method: "GET", path: "/api/workflow-runs/\(runId)/trace")
    }

    func triggerWorkflow(workflowId: String) async throws -> WorkflowRun {
        try await request(
            method: "POST",
            path: "/api/workflows/\(workflowId)/runs",
            body: ["trigger_payload": [:] as [String: String]]
        )
    }
}

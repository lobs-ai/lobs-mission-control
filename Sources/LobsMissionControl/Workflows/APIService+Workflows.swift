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

    func createWorkflow(_ requestBody: WorkflowCreateRequest) async throws -> WorkflowDefinition {
        try await request(method: "POST", path: "/api/workflows", body: requestBody)
    }

    func updateWorkflow(id: String, updates: WorkflowUpdateRequest) async throws -> WorkflowDefinition {
        try await request(method: "PUT", path: "/api/workflows/\(id)", body: updates)
    }

    func deleteWorkflow(id: String) async throws {
        _ = try await request(method: "DELETE", path: "/api/workflows/\(id)") as APIResponse
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

private struct APIResponse: Codable {}

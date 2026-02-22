import Foundation

extension APIService {
  // MARK: - Usage Tracking

  func loadUsageDashboard(window: String = "month") async throws -> UsageDashboardResponse {
    try await request(method: "GET", path: "/api/usage/dashboard", queryItems: [
      URLQueryItem(name: "window", value: window)
    ])
  }

  func loadUsageSummary(window: String = "month") async throws -> UsageSummaryResponse {
    try await request(method: "GET", path: "/api/usage/summary", queryItems: [
      URLQueryItem(name: "window", value: window)
    ])
  }

  func loadUsageProviders(window: String = "month") async throws -> [UsageProviderSummary] {
    try await request(method: "GET", path: "/api/usage/providers", queryItems: [
      URLQueryItem(name: "window", value: window)
    ])
  }

  func loadUsageModels(window: String = "month") async throws -> [UsageModelSummary] {
    try await request(method: "GET", path: "/api/usage/models", queryItems: [
      URLQueryItem(name: "window", value: window)
    ])
  }

  func loadUsageProjection() async throws -> UsageProjectionResponse {
    try await request(method: "GET", path: "/api/usage/projection")
  }

  func loadUsageBudgets() async throws -> UsageBudgetLimits {
    try await request(method: "GET", path: "/api/usage/budgets")
  }

  func updateUsageBudgets(_ budgets: UsageBudgetLimits) async throws -> UsageBudgetLimits {
    try await request(method: "PATCH", path: "/api/usage/budgets", body: budgets)
  }

  func loadUsageRoutingPolicy() async throws -> UsageRoutingPolicy {
    try await request(method: "GET", path: "/api/routing/policy")
  }

  func updateUsageRoutingPolicy(_ policy: UsageRoutingPolicy) async throws -> UsageRoutingPolicy {
    try await request(method: "PATCH", path: "/api/routing/policy", body: policy)
  }
}

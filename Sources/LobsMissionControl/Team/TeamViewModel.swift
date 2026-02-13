import Foundation
import SwiftUI

@MainActor
class TeamViewModel: ObservableObject {
  @Published var agentStatuses: [String: AgentStatus] = [:]
  @Published var workerStatus: WorkerStatus?
  @Published var workerHistory: WorkerHistory?
  @Published var isLoading = false
  @Published var error: String?
  
  private let apiService: APIService
  private var refreshTask: Task<Void, Never>?
  
  init(apiService: APIService) {
    self.apiService = apiService
  }
  
  deinit {
    refreshTask?.cancel()
  }
  
  func startRefreshing() {
    refreshTask?.cancel()
    refreshTask = Task {
      while !Task.isCancelled {
        await refresh()
        try? await Task.sleep(for: .seconds(5))
      }
    }
  }
  
  func stopRefreshing() {
    refreshTask?.cancel()
    refreshTask = nil
  }
  
  func refresh() async {
    isLoading = true
    error = nil
    
    do {
      async let statuses = try apiService.loadAgentStatuses()
      async let worker = try apiService.loadWorkerStatus()
      async let history = try apiService.loadWorkerHistory()
      
      agentStatuses = try await statuses
      workerStatus = try await worker
      workerHistory = try await history
    } catch {
      self.error = error.localizedDescription
    }
    
    isLoading = false
  }
  
  var sortedAgents: [AgentStatus] {
    let order = ["programmer", "researcher", "writer", "reviewer", "architect"]
    return agentStatuses.values.sorted { a, b in
      let aIndex = order.firstIndex(of: a.agentType) ?? order.count
      let bIndex = order.firstIndex(of: b.agentType) ?? order.count
      return aIndex < bIndex
    }
  }
  
  var activeAgentsCount: Int {
    agentStatuses.values.filter { $0.status == "working" || $0.status == "thinking" }.count
  }
  
  var totalTasksCompletedToday: Int {
    let today = Calendar.current.startOfDay(for: Date())
    return agentStatuses.values.reduce(0) { total, agent in
      guard let lastCompleted = agent.lastCompletedAt,
            lastCompleted >= today else { return total }
      return total + 1
    }
  }
  
  var activeWorkersCount: Int {
    (workerStatus?.active == true) ? 1 : 0
  }
  
  var recentWorkerRuns: [WorkerHistoryRun] {
    Array((workerHistory?.runs ?? []).prefix(15))
  }
}

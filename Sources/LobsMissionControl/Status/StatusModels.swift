import Foundation

// MARK: - System Overview

struct SystemOverview: Codable {
  let server: ServerHealth
  let orchestrator: OrchestratorStatus
  let workers: WorkersStatus
  let agents: [AgentStatusSummary]
  let tasks: TasksSummary
  let memories: MemoriesSummary
  let inbox: InboxSummary
  
  struct ServerHealth: Codable {
    let status: String // "healthy", "degraded", "down"
    let uptime: TimeInterval?
    let version: String?
  }
  
  struct OrchestratorStatus: Codable {
    let state: String // "running", "paused", "stopped"
    let uptime: TimeInterval?
    let lastCheck: Date?
  }
  
  struct WorkersStatus: Codable {
    let activeCount: Int
    let completedCount: Int
    let failedCount: Int
    let activeWorkers: [ActiveWorker]
    
    struct ActiveWorker: Codable, Identifiable {
      let id: String
      let agentType: String
      let taskId: String?
      let taskTitle: String?
      let projectId: String?
      let startedAt: Date
      let status: String
    }
  }
  
  struct AgentStatusSummary: Codable, Identifiable {
    let agentType: String
    let status: String // "active", "idle", "error"
    let lastActive: Date?
    let health: String? // "healthy", "warning", "error"
    let activeTaskCount: Int?
    
    var id: String { agentType }
  }
  
  struct TasksSummary: Codable {
    let active: Int
    let inbox: Int
    let completed: Int
    let total: Int
  }
  
  struct MemoriesSummary: Codable {
    let total: Int
    let recentCount: Int
  }
  
  struct InboxSummary: Codable {
    let total: Int
    let unread: Int
  }
  
  enum CodingKeys: String, CodingKey {
    case server
    case orchestrator
    case workers
    case agents
    case tasks
    case memories
    case inbox
  }
}

// MARK: - Activity Event

struct ActivityEvent: Codable, Identifiable {
  let id: String
  let type: String // "task_completed", "worker_spawned", "error", "info", etc.
  let title: String
  let timestamp: Date
  let details: String?
  
  var displayType: EventType {
    EventType(rawValue: type) ?? .info
  }
  
  enum EventType: String {
    case taskCompleted = "task_completed"
    case taskCreated = "task_created"
    case workerSpawned = "worker_spawned"
    case workerCompleted = "worker_completed"
    case workerFailed = "worker_failed"
    case error
    case warning
    case info
    
    var icon: String {
      switch self {
      case .taskCompleted: return "checkmark.circle.fill"
      case .taskCreated: return "plus.circle.fill"
      case .workerSpawned: return "gearshape.circle.fill"
      case .workerCompleted: return "checkmark.circle.fill"
      case .workerFailed: return "xmark.circle.fill"
      case .error: return "exclamationmark.triangle.fill"
      case .warning: return "exclamationmark.circle.fill"
      case .info: return "info.circle.fill"
      }
    }
    
    var color: String {
      switch self {
      case .taskCompleted, .workerCompleted: return "green"
      case .taskCreated, .workerSpawned: return "blue"
      case .workerFailed, .error: return "red"
      case .warning: return "orange"
      case .info: return "gray"
      }
    }
  }
}

// MARK: - Cost Summary

struct CostSummary: Codable {
  let today: Period
  let week: Period
  let month: Period
  let byAgent: [String: AgentCost]
  
  struct Period: Codable {
    let tokensUsed: Int
    let estimatedCost: Double
  }
  
  struct AgentCost: Codable {
    let tokensUsed: Int
    let estimatedCost: Double
    let requestCount: Int
  }
  
  enum CodingKeys: String, CodingKey {
    case today
    case week
    case month
    case byAgent = "by_agent"
  }
}

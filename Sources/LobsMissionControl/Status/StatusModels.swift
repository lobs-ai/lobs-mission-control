import Foundation

// MARK: - Software Updates

struct RepoUpdateInfo: Codable, Identifiable {
  let name: String
  let path: String
  let localCommit: String
  let localMessage: String
  let localDate: String
  let remoteCommit: String?
  let remoteMessage: String?
  let remoteDate: String?
  let behind: Int
  let ahead: Int
  let hasUpdate: Bool
  let branch: String
  let error: String?
  
  var id: String { name }
}

struct UpdateCheckResponse: Codable {
  let repos: [RepoUpdateInfo]
  let hasUpdates: Bool
  let checkedAt: String
}

struct UpdatePullResponse: Codable {
  let repo: String
  let success: Bool
  let output: String
  let newCommit: String?
  let needsRestart: Bool
}

// MARK: - System Overview
// Note: APIService decoder uses .convertFromSnakeCase, so no manual CodingKeys needed
// for simple snake_case → camelCase conversions.

struct SystemOverview: Codable {
  let server: ServerHealth
  let orchestrator: OrchestratorStatus
  let workers: WorkersStatus
  let agents: [AgentStatusSummary]
  let tasks: TasksSummary
  let memories: MemoriesSummary
  let inbox: InboxSummary
  
  struct ServerHealth: Codable {
    let status: String
    let uptimeSeconds: Int
    let version: String
  }
  
  struct OrchestratorStatus: Codable {
    let running: Bool
    let paused: Bool
  }
  
  struct WorkersStatus: Codable {
    let active: Int
    let totalCompleted: Int
    let totalFailed: Int
  }
  
  struct AgentStatusSummary: Codable, Identifiable {
    let type: String
    let status: String
    let lastActive: String?  // Server sends ISO string or null, not Date
    
    var id: String { type }
  }
  
  struct TasksSummary: Codable {
    let active: Int
    let waiting: Int
    let blocked: Int
    let completedToday: Int
  }
  
  struct MemoriesSummary: Codable {
    let total: Int
    let todayEntries: Int
  }
  
  struct InboxSummary: Codable {
    let unread: Int
  }
}

// MARK: - Activity Event

struct ActivityEvent: Codable, Identifiable {
  let id: String
  let type: String
  let title: String
  let timestamp: Date
  let details: String?
  
  var displayType: EventType {
    EventType(rawValue: type) ?? .info
  }
  
  enum EventType: String {
    case taskCompleted = "task_completed"
    case taskCreated = "task_created"
    case taskUpdated = "task_updated"
    case workerSpawned = "worker_spawned"
    case workerCompleted = "worker_completed"
    case workerFailed = "worker_failed"
    case inboxReceived = "inbox_received"
    case memoryUpdated = "memory_updated"
    case error
    case warning
    case info
    
    var icon: String {
      switch self {
      case .taskCompleted, .workerCompleted: return "checkmark.circle.fill"
      case .taskCreated: return "plus.circle.fill"
      case .taskUpdated: return "arrow.triangle.2.circlepath"
      case .workerSpawned: return "gearshape.circle.fill"
      case .workerFailed, .error: return "exclamationmark.triangle.fill"
      case .inboxReceived: return "tray.fill"
      case .memoryUpdated: return "brain.head.profile"
      case .warning: return "exclamationmark.circle.fill"
      case .info: return "info.circle.fill"
      }
    }
    
    var color: String {
      switch self {
      case .taskCompleted, .workerCompleted: return "green"
      case .taskCreated, .workerSpawned: return "blue"
      case .taskUpdated: return "gray"
      case .workerFailed, .error: return "red"
      case .inboxReceived: return "orange"
      case .memoryUpdated: return "purple"
      case .warning: return "orange"
      case .info: return "gray"
      }
    }
  }
  
  // Server doesn't send id — generate client-side
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = UUID().uuidString
    self.type = try container.decode(String.self, forKey: .type)
    self.title = try container.decode(String.self, forKey: .title)
    self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    self.details = try container.decodeIfPresent(String.self, forKey: .details)
  }
  
  init(id: String = UUID().uuidString, type: String, title: String, timestamp: Date, details: String? = nil) {
    self.id = id
    self.type = type
    self.title = title
    self.timestamp = timestamp
    self.details = details
  }
  
  enum CodingKeys: String, CodingKey {
    case type, title, timestamp, details
  }
}

// MARK: - Cost Summary

struct CostSummary: Codable {
  let today: Period
  let week: Period
  let month: Period
  let byAgent: [AgentCost]
  
  struct Period: Codable {
    let tokensIn: Int
    let tokensOut: Int
    let estimatedCost: Double
    
    var tokensUsed: Int { tokensIn + tokensOut }
  }
  
  struct AgentCost: Codable, Identifiable {
    let type: String
    let tokensTotal: Int
    let runs: Int
    
    var id: String { type }
    var estimatedCost: Double { Double(tokensTotal) / 1000.0 * 0.01 }
  }
}

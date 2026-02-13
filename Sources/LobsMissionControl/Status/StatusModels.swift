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
    let uptimeSeconds: Int
    let version: String
    
    enum CodingKeys: String, CodingKey {
      case status
      case uptimeSeconds = "uptime_seconds"
      case version
    }
  }
  
  struct OrchestratorStatus: Codable {
    let running: Bool
    let paused: Bool
  }
  
  struct WorkersStatus: Codable {
    let active: Int
    let totalCompleted: Int
    let totalFailed: Int
    
    enum CodingKeys: String, CodingKey {
      case active
      case totalCompleted = "total_completed"
      case totalFailed = "total_failed"
    }
  }
  
  struct AgentStatusSummary: Codable, Identifiable {
    let type: String
    let status: String // "active", "idle", "error"
    let lastActive: Date?
    
    var id: String { type }
    
    enum CodingKeys: String, CodingKey {
      case type
      case status
      case lastActive = "last_active"
    }
  }
  
  struct TasksSummary: Codable {
    let active: Int
    let waiting: Int
    let blocked: Int
    let completedToday: Int
    
    enum CodingKeys: String, CodingKey {
      case active
      case waiting
      case blocked
      case completedToday = "completed_today"
    }
  }
  
  struct MemoriesSummary: Codable {
    let total: Int
    let todayEntries: Int
    
    enum CodingKeys: String, CodingKey {
      case total
      case todayEntries = "today_entries"
    }
  }
  
  struct InboxSummary: Codable {
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
  
  // Custom decoding to handle missing id field from server
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    // Server doesn't send id, so we generate a UUID
    self.id = UUID().uuidString
    self.type = try container.decode(String.self, forKey: .type)
    self.title = try container.decode(String.self, forKey: .title)
    self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    self.details = try container.decodeIfPresent(String.self, forKey: .details)
  }
  
  // Manual initializer for testing/creation
  init(id: String = UUID().uuidString, type: String, title: String, timestamp: Date, details: String? = nil) {
    self.id = id
    self.type = type
    self.title = title
    self.timestamp = timestamp
    self.details = details
  }
  
  enum CodingKeys: String, CodingKey {
    case type
    case title
    case timestamp
    case details
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
    
    // Computed property for total tokens
    var tokensUsed: Int {
      tokensIn + tokensOut
    }
    
    enum CodingKeys: String, CodingKey {
      case tokensIn = "tokens_in"
      case tokensOut = "tokens_out"
      case estimatedCost = "estimated_cost"
    }
  }
  
  struct AgentCost: Codable, Identifiable {
    let type: String
    let tokensTotal: Int
    let runs: Int
    
    var id: String { type }
    
    // Computed estimated cost (rough approximation if not provided by server)
    var estimatedCost: Double {
      // Rough estimate: $0.01 per 1K tokens
      return Double(tokensTotal) / 1000.0 * 0.01
    }
    
    enum CodingKeys: String, CodingKey {
      case type
      case tokensTotal = "tokens_total"
      case runs
    }
  }
  
  enum CodingKeys: String, CodingKey {
    case today
    case week
    case month
    case byAgent = "by_agent"
  }
}

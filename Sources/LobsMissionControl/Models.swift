import Foundation

enum TaskStatus: Hashable, Codable {
  case inbox
  case active
  case completed
  case rejected
  case waitingOn
  case other(String)

  var rawValue: String {
    switch self {
    case .inbox: return "inbox"
    case .active: return "active"
    case .completed: return "completed"
    case .rejected: return "rejected"
    case .waitingOn: return "waiting_on"
    case .other(let value): return value
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    switch value {
    case "inbox": self = .inbox
    case "active": self = .active
    case "completed": self = .completed
    case "rejected": self = .rejected
    case "waiting_on": self = .waitingOn
    default: self = .other(value)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

enum WorkState: Hashable, Codable {
  case notStarted
  case inProgress
  case blocked
  case other(String)

  var rawValue: String {
    switch self {
    case .notStarted: return "not_started"
    case .inProgress: return "in_progress"
    case .blocked: return "blocked"
    case .other(let value): return value
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    switch value {
    case "not_started": self = .notStarted
    case "in_progress": self = .inProgress
    case "blocked": self = .blocked
    default: self = .other(value)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

enum ReviewState: Hashable, Codable {
  case pending
  case approved
  case changesRequested
  case rejected
  case other(String)

  var rawValue: String {
    switch self {
    case .pending: return "pending"
    case .approved: return "approved"
    case .changesRequested: return "changes_requested"
    case .rejected: return "rejected"
    case .other(let value): return value
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    switch value {
    case "pending": self = .pending
    case "approved": self = .approved
    case "changes_requested": self = .changesRequested
    case "rejected": self = .rejected
    default: self = .other(value)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

enum TaskOwner: Hashable, Codable {
  case lobs
  case rafe
  case other(String)

  var rawValue: String {
    switch self {
    case .lobs: return "lobs"
    case .rafe: return "rafe"
    case .other(let value): return value
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    switch value {
    case "lobs": self = .lobs
    case "rafe": self = .rafe
    default: self = .other(value)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

/// Task shape/type classification for filtering by work mode.
enum TaskShape: String, Codable, Hashable, CaseIterable {
  case deep = "deep"           // Deep work — focused, uninterrupted effort
  case shallow = "shallow"     // Quick tasks, emails, admin
  case creative = "creative"   // Design, brainstorming, open-ended
  case waiting = "waiting"     // Blocked on someone/something external
  case admin = "admin"         // Organizational, process, logistics
}

struct DashboardTask: Codable, Identifiable, Hashable {
  var id: String
  var title: String

  /// Workflow status for the task itself (drives the Kanban columns: inbox/active/waiting_on/completed/etc).
  ///
  /// Important: `status=completed` means the task is done from a workflow perspective.
  /// It does *not* imply the artifact has been approved.
  var status: TaskStatus

  var owner: TaskOwner?
  var createdAt: Date
  var updatedAt: Date

  // No custom CodingKeys needed - let .convertFromSnakeCase handle snake_case conversion
  // This allows the decoder to automatically convert created_at → createdAt, work_state → workState, etc.

  // Memberwise initializer for creating tasks programmatically
  init(
    id: String,
    title: String,
    status: TaskStatus,
    owner: TaskOwner? = nil,
    createdAt: Date,
    updatedAt: Date,
    workState: WorkState? = nil,
    reviewState: ReviewState? = nil,
    projectId: String? = nil,
    artifactPath: String? = nil,
    notes: String? = nil,
    startedAt: Date? = nil,
    finishedAt: Date? = nil,
    sortOrder: Int? = nil,
    blockedBy: [String]? = nil,
    pinned: Bool? = nil,
    shape: TaskShape? = nil,
    agent: String? = nil
  ) {
    self.id = id
    self.title = title
    self.status = status
    self.owner = owner
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.workState = workState
    self.reviewState = reviewState
    self.projectId = projectId
    self.artifactPath = artifactPath
    self.notes = notes
    self.startedAt = startedAt
    self.finishedAt = finishedAt
    self.sortOrder = sortOrder
    self.blockedBy = blockedBy
    self.pinned = pinned
    self.shape = shape
    self.agent = agent
  }

  // Optional fields (schema evolves)

  /// Whether work has started / is in progress / is blocked.
  var workState: WorkState?

  /// Review state for the produced artifact (pending/approved/changes_requested/etc).
  /// This is intentionally separate from `status` so you can approve without completing (or vice versa).
  var reviewState: ReviewState?

  /// Project/workstream this task belongs to. Missing implies "default".
  var projectId: String?

  var artifactPath: String?
  var notes: String?

  /// Lightweight time tracking
  var startedAt: Date?
  var finishedAt: Date?

  /// Manual sort order within a column (lower = higher priority)
  var sortOrder: Int?

  /// Task IDs this task is blocked by. When all blockers complete, the task auto-unblocks.
  var blockedBy: [String]?

  /// Whether this task is pinned/starred (floats to top of its column).
  var pinned: Bool?

  /// Work shape/type for filtering (deep work, shallow, creative, admin, waiting).
  var shape: TaskShape?

  /// Agent type assignment (programmer, researcher, reviewer, writer, architect).
  var agent: String?

  /// Resolved owner (defaults to .lobs for backwards compatibility when server returns null).
  var resolvedOwner: TaskOwner { owner ?? .lobs }
}

enum ProjectType: String, Codable, CaseIterable, Hashable {
  case kanban
  case research
  case tracker
}

struct Project: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var createdAt: Date
  var updatedAt: Date
  var notes: String?
  var archived: Bool?
  var type: ProjectType?

  /// Manual sort order (lower = higher in list). Nil means unsorted (append to end).
  var sortOrder: Int?

  /// Resolved type (defaults to kanban for backwards compatibility).
  var resolvedType: ProjectType { type ?? .kanban }
  
  // No custom CodingKeys needed - let .convertFromSnakeCase handle snake_case conversion
  // This allows the decoder to automatically convert created_at → createdAt, sort_order → sortOrder, etc.
  
  init(id: String, title: String, createdAt: Date, updatedAt: Date, notes: String? = nil, archived: Bool? = nil, type: ProjectType? = nil, sortOrder: Int? = nil) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.notes = notes
    self.archived = archived
    self.type = type
    self.sortOrder = sortOrder
  }
}

// MARK: - Research Tile Types

enum ResearchTileType: String, Codable, CaseIterable, Hashable {
  case link
  case note
  case finding
  case comparison
}

enum ResearchTileStatus: String, Codable, Hashable {
  case active
  case archived
}

struct ResearchTile: Codable, Identifiable, Hashable {
  var id: String
  var projectId: String
  var type: ResearchTileType
  var title: String
  var tags: [String]?
  var status: ResearchTileStatus?
  var author: String?   // "rafe" or "lobs"
  var createdAt: Date
  var updatedAt: Date

  // Link tile fields
  var url: String?
  var summary: String?
  var snapshot: String?

  // Note tile fields
  var content: String?

  // Finding tile fields
  var claim: String?
  var confidence: Double?
  var evidence: [String]?
  var counterpoints: [String]?

  // Comparison tile fields
  var options: [ComparisonOption]?

  var resolvedStatus: ResearchTileStatus { status ?? .active }
}

struct ComparisonOption: Codable, Hashable {
  var name: String
  var pros: [String]?
  var cons: [String]?
  var cost: String?
  var risk: String?
  var notes: String?
}

// MARK: - Research Requests

enum ResearchRequestStatus: String, Codable, Hashable {
  case open
  case inProgress = "in_progress"
  case done
  case completed
  case blocked
}

/// Priority level for research requests.
enum ResearchPriority: String, Codable, Hashable, CaseIterable {
  case low
  case normal
  case high
  case urgent
}

/// A single expected deliverable artifact for a research request.
struct RequestDeliverable: Codable, Identifiable, Hashable {
  var id: String
  var kind: String       // e.g. "markdown", "bullet-summary", "links-list", "comparison-table"
  var label: String      // human description, e.g. "Main research document"
  var fulfilled: Bool    // whether the artifact has been produced

  static let commonKinds: [(String, String)] = [
    ("markdown", "Markdown document"),
    ("bullet-summary", "Bullet summary"),
    ("links-list", "Links / sources list"),
    ("comparison-table", "Comparison table"),
    ("implementation-plan", "Implementation plan"),
    ("custom", "Custom"),
  ]
}

/// A snapshot of a request prompt at a point in time (for edit versioning).
struct RequestEditVersion: Codable, Identifiable, Hashable {
  var id: String          // "v1", "v2", etc.
  var prompt: String
  var editedAt: Date
  var editedBy: String?   // "rafe" or "lobs"
}

struct ResearchRequest: Codable, Identifiable, Hashable {
  var id: String
  var projectId: String
  var topicId: String?      // Topic FK
  var tileId: String?       // If attached to a specific tile
  var prompt: String
  var status: ResearchRequestStatus
  var response: String?
  var author: String?       // who created the request
  var priority: ResearchPriority?  // nil defaults to .normal
  var deliverables: [RequestDeliverable]?  // expected output artifacts
  var editHistory: [RequestEditVersion]?   // version history of prompt edits
  var parentRequestId: String?   // if this was split from another request
  var assignedWorker: String?    // worker assignment (e.g. "lobs")
  var createdAt: Date
  var updatedAt: Date

  /// Resolved priority (defaults to .normal if nil)
  var resolvedPriority: ResearchPriority { priority ?? .normal }

  /// Whether all declared deliverables are fulfilled.
  var allDeliverablesFulfilled: Bool {
    guard let dels = deliverables, !dels.isEmpty else { return true }
    return dels.allSatisfy { $0.fulfilled }
  }

  /// Number of fulfilled deliverables vs total.
  var deliverableProgress: (fulfilled: Int, total: Int) {
    guard let dels = deliverables else { return (0, 0) }
    return (dels.filter { $0.fulfilled }.count, dels.count)
  }

  /// Current version number based on edit history.
  var currentVersion: Int {
    (editHistory?.count ?? 0) + 1
  }

  // No custom CodingKeys needed - let .convertFromSnakeCase handle snake_case conversion

  init(id: String, projectId: String, topicId: String? = nil, tileId: String? = nil, prompt: String, status: ResearchRequestStatus, response: String? = nil, author: String? = nil, priority: ResearchPriority? = nil, deliverables: [RequestDeliverable]? = nil, editHistory: [RequestEditVersion]? = nil, parentRequestId: String? = nil, assignedWorker: String? = nil, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.projectId = projectId
    self.topicId = topicId
    self.tileId = tileId
    self.prompt = prompt
    self.status = status
    self.response = response
    self.author = author
    self.priority = priority
    self.deliverables = deliverables
    self.editHistory = editHistory
    self.parentRequestId = parentRequestId
    self.assignedWorker = assignedWorker
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Research Document (doc-based storage)

struct ResearchSource: Codable, Identifiable, Hashable {
  var id: String
  var url: String
  var title: String
  var tags: [String]?
  var addedAt: Date
}

struct ResearchSourcesFile: Codable {
  var sources: [ResearchSource]
}

/// A research deliverable document from the `docs/` directory.
struct ResearchDeliverable: Identifiable, Hashable {
  var id: String           // filename
  var filename: String
  var title: String
  var requestIdPrefix: String?  // first 8 chars of request UUID if present
  var modifiedAt: Date
  var content: String
}

// MARK: - Inbox Item (Design Docs)

struct InboxItem: Identifiable, Hashable {
  var id: String          // e.g. "inbox/foo.md" or "artifacts/bar.md"
  var title: String       // derived from filename or first heading
  var filename: String
  var relativePath: String
  /// Content for the document. This may initially be a short preview for performance.
  var content: String
  /// True when `content` is only a preview/truncated snapshot and the full document
  /// should be loaded on-demand (e.g. when selected).
  var contentIsTruncated: Bool
  var modifiedAt: Date
  var isRead: Bool        // tracked locally
  var summary: String     // first ~200 chars or first paragraph
}

struct InboxResponse: Codable, Identifiable, Hashable {
  var id: String
  var docId: String
  var response: String
  var createdAt: Date
  var updatedAt: Date
}

// MARK: - Inbox Read State (repo-backed)

/// Repo-backed read/seen state for inbox items.
///
/// Stored in the control repo so it survives reinstall/reclone across machines.
struct InboxReadStateFile: Codable, Hashable {
  var schemaVersion: Int
  var generatedAt: Date
  var readItemIds: [String]
  var lastSeenThreadCounts: [String: Int]
}

// MARK: - Inbox Thread (threaded conversations per document)

enum InboxTriageStatus: String, Codable, Hashable, CaseIterable {
  case needsResponse = "needs_response"
  case pending = "pending"
  case resolved = "resolved"

  var displayName: String {
    switch self {
    case .needsResponse: return "Needs Response"
    case .pending: return "Pending"
    case .resolved: return "Resolved"
    }
  }

  var iconName: String {
    switch self {
    case .needsResponse: return "exclamationmark.bubble.fill"
    case .pending: return "clock.fill"
    case .resolved: return "checkmark.circle.fill"
    }
  }

  var color: String {
    switch self {
    case .needsResponse: return "orange"
    case .pending: return "blue"
    case .resolved: return "green"
    }
  }
}

struct InboxThreadMessage: Codable, Identifiable, Hashable {
  var id: String
  var author: String   // "rafe" or "lobs"
  var text: String
  var createdAt: Date
}

struct InboxThread: Codable, Identifiable, Hashable {
  var id: String       // same as docId
  var docId: String
  var messages: [InboxThreadMessage]
  var triageStatus: InboxTriageStatus = .needsResponse
  var createdAt: Date
  var updatedAt: Date

  // Custom decoder to provide default for triageStatus on legacy data
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    docId = try container.decode(String.self, forKey: .docId)
    messages = try container.decode([InboxThreadMessage].self, forKey: .messages)
    triageStatus = (try? container.decode(InboxTriageStatus.self, forKey: .triageStatus)) ?? .needsResponse
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  init(id: String, docId: String, messages: [InboxThreadMessage], triageStatus: InboxTriageStatus = .needsResponse, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.docId = docId
    self.messages = messages
    self.triageStatus = triageStatus
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Agent Documents (Reports & Research)

enum DocumentSource: String, Codable, Hashable {
  case writer
  case researcher
}

enum DocumentStatus: String, Codable, Hashable {
  case pending
  case approved
  case rejected
  case archived
}

// MARK: - Topic

struct Topic: Identifiable, Hashable, Codable {
  var id: String
  var title: String
  var description: String?
  var icon: String?
  var linkedProjectId: String?
  var autoCreated: Bool
  var createdAt: Date
  var updatedAt: Date
  
  init(id: String, title: String, description: String? = nil, icon: String? = nil, linkedProjectId: String? = nil, autoCreated: Bool = false, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.title = title
    self.description = description
    self.icon = icon
    self.linkedProjectId = linkedProjectId
    self.autoCreated = autoCreated
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

struct AgentDocument: Identifiable, Hashable, Codable {
  var id: String          // Full path: "reports/pending/foo.md" or "research/topic/bar.md"
  var title: String       // Extracted from filename or first heading
  var filename: String
  var relativePath: String // Relative to state/
  var content: String
  var contentIsTruncated: Bool
  var source: DocumentSource  // writer or researcher
  var status: DocumentStatus? // For reports only (pending/approved/rejected)
  var topic: String?      // For research: the subdirectory name (legacy)
  var topicId: String?    // Topic FK (new)
  var projectId: String?  // For reports: associated project
  var taskId: String?     // Task that generated this document
  var date: Date          // File modification date or extracted date
  var isRead: Bool        // Tracked locally
  var isStarred: Bool     // Tracked locally - user favorites
  var summary: String?    // High-level summary extracted from first paragraph
  
  init(id: String, title: String, filename: String, relativePath: String, content: String, contentIsTruncated: Bool, source: DocumentSource, status: DocumentStatus?, topic: String?, topicId: String? = nil, projectId: String?, taskId: String?, date: Date, isRead: Bool, isStarred: Bool = false, summary: String? = nil) {
    self.id = id
    self.title = title
    self.filename = filename
    self.relativePath = relativePath
    self.content = content
    self.contentIsTruncated = contentIsTruncated
    self.source = source
    self.status = status
    self.topic = topic
    self.topicId = topicId
    self.projectId = projectId
    self.taskId = taskId
    self.date = date
    self.isRead = isRead
    self.isStarred = isStarred
    self.summary = summary
  }
  
  // Custom decoding to handle missing isRead and isStarred from server
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    filename = try container.decode(String.self, forKey: .filename)
    relativePath = try container.decode(String.self, forKey: .relativePath)
    content = try container.decode(String.self, forKey: .content)
    contentIsTruncated = try container.decode(Bool.self, forKey: .contentIsTruncated)
    source = try container.decode(DocumentSource.self, forKey: .source)
    status = try container.decodeIfPresent(DocumentStatus.self, forKey: .status)
    topic = try container.decodeIfPresent(String.self, forKey: .topic)
    topicId = try container.decodeIfPresent(String.self, forKey: .topicId)
    projectId = try container.decodeIfPresent(String.self, forKey: .projectId)
    taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
    date = try container.decode(Date.self, forKey: .date)
    // isRead and isStarred are client-side only, default to false
    isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
    isStarred = try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false
    summary = try container.decodeIfPresent(String.self, forKey: .summary)
  }
  
  enum CodingKeys: String, CodingKey {
    case id, title, filename, relativePath, content, contentIsTruncated
    case source, status, topic, topicId, projectId, taskId, date
    case isRead, isStarred, summary
  }
}

extension DocumentSource: CaseIterable {
  var displayName: String {
    rawValue.capitalized
  }
  
  var icon: String {
    switch self {
    case .writer: return "doc.text.fill"
    case .researcher: return "magnifyingglass"
    }
  }
}

extension DocumentStatus: CaseIterable {
  var displayName: String {
    rawValue.capitalized
  }
}

// MARK: - Task Templates

struct TaskTemplateItem: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var notes: String?
}

struct TaskTemplate: Codable, Identifiable, Hashable {
  var id: String
  var name: String
  var description: String?
  var items: [TaskTemplateItem]
  var createdAt: Date
  var updatedAt: Date
}

// MARK: - Text Dump (bulk text → tasks)

enum TextDumpStatus: String, Codable, Hashable {
  case pending
  case processing
  case completed
}

struct TextDump: Codable, Identifiable, Hashable {
  var id: String
  var projectId: String
  var text: String
  var status: TextDumpStatus
  var taskIds: [String]?   // IDs of tasks created from this dump
  var createdAt: Date
  var updatedAt: Date
}

// MARK: - Worker Status

struct WorkerStatus: Codable {
  var active: Bool
  var workerId: String?
  var startedAt: Date?
  var currentTask: String?
  var tasksCompleted: Int?
  var lastHeartbeat: Date?
  var endedAt: Date?

  // Live run details (optional; written by worker-register)
  var currentProject: String?
  var taskLog: [WorkerTaskLogEntry]?

  // Optional live token counters (if workers start recording them)
  var inputTokens: Int?
  var outputTokens: Int?
}

// MARK: - Worker History

struct WorkerTaskLogEntry: Codable {
  var task: String?
  var project: String?
  var completedAt: Date?
}

struct WorkerHistoryRun: Codable, Identifiable {
  var workerId: String?
  var startedAt: Date?
  var endedAt: Date?
  var tasksCompleted: Int?
  var timeoutReason: String?
  var model: String?

  /// Optional token split (if recorded by the worker).
  var inputTokens: Int?
  var outputTokens: Int?

  /// Total tokens used in this worker run (optional).
  var totalTokens: Int?

  /// Total cost (USD) for this worker run (optional).
  var totalCostUSD: Double?

  /// Optional: lightweight list of tasks completed during the run.
  var taskLog: [WorkerTaskLogEntry]?

  /// Commit SHAs pushed during this run (for auditability).
  var commitSHAs: [String]?

  /// Files modified during this run (for auditability).
  var filesModified: [String]?
  
  /// Task ID this run was executing (optional).
  var taskId: String?
  
  /// Whether the run succeeded (optional).
  var succeeded: Bool?
  
  /// Source of the usage data (optional, e.g., "estimate", "actual").
  var source: String?

  var id: String { "\(workerId ?? "unknown")-\(startedAt?.timeIntervalSince1970 ?? 0)" }
  
  /// Extract agent type from workerId (e.g., "programmer-1234-ABC" → "programmer").
  var agentType: String {
    guard let workerId = workerId else { return "unknown" }
    let parts = workerId.split(separator: "-")
    return parts.first.map(String.init) ?? "unknown"
  }
  
  /// Extract first project from taskLog.
  var primaryProject: String? {
    taskLog?.first?.project
  }
}

struct WorkerHistory: Codable {
  var runs: [WorkerHistoryRun]
}

// MARK: - Orchestrator Status

struct OrchestratorStatus: Codable {
  var running: Bool
  var paused: Bool
  var worker: WorkerStatus?
  var agents: [String: AgentStatus]
  var pollInterval: Int?
}

// MARK: - Agent Status

struct AgentStats: Codable {
  var tasksCompleted: Int?
  var tasksFailed: Int?
  var avgDurationSeconds: Int?
  var lastWeekCompleted: Int?
}

struct AgentStatus: Codable, Identifiable {
  var agentType: String
  var status: String  // idle|working|thinking|finalizing
  var activity: String?
  var thinking: String?
  var currentTaskId: String?
  var currentProjectId: String?
  var lastActiveAt: Date?
  var lastCompletedTaskId: String?
  var lastCompletedAt: Date?
  var stats: AgentStats?

  var id: String { agentType }

  var displayName: String { agentType.capitalized }

  var emoji: String {
    switch agentType {
    case "programmer": return "\u{1F527}"
    case "architect": return "\u{1F3D7}"
    case "researcher": return "\u{1F52C}"
    case "reviewer": return "\u{1F50D}"
    case "writer": return "\u{270D}\u{FE0F}"
    default: return "\u{1F916}"
    }
  }

  var isActive: Bool { status != "idle" }
}

// MARK: - Main Session Usage

struct MainSessionSnapshot: Codable, Identifiable {
  var timestamp: Date?
  var inputTokens: Int?
  var outputTokens: Int?
  var totalTokens: Int?
  var model: String?
  var costUSD: Double?
  var deltaInputTokens: Int?
  var deltaOutputTokens: Int?
  var deltaCostUSD: Double?

  var id: String { "\(timestamp?.timeIntervalSince1970 ?? 0)" }
}

struct MainSessionDailySummary: Codable {
  var inputTokens: Int
  var outputTokens: Int
  var costUSD: Double
  var snapshotCount: Int
}

struct MainSessionUsage: Codable {
  var snapshots: [MainSessionSnapshot]
  var dailySummaries: [String: MainSessionDailySummary]
  
  /// Returns true if the main session usage data is recent (within last 7 days).
  /// Stale data should not be included in totals to avoid incorrect aggregation.
  var isFresh: Bool {
    guard let lastSnapshot = snapshots.max(by: { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }),
          let lastTimestamp = lastSnapshot.timestamp else {
      return false
    }
    let daysSinceUpdate = Date().timeIntervalSince(lastTimestamp) / 86400
    return daysSinceUpdate < 7
  }
  
  /// Returns the date of the most recent snapshot, if any.
  var lastUpdateDate: Date? {
    snapshots.compactMap(\.timestamp).max()
  }
}

struct ProjectsFile: Codable {
  var schemaVersion: Int
  var generatedAt: Date
  var projects: [Project]
}

struct TasksFile: Codable {
  var schemaVersion: Int
  var generatedAt: Date
  var tasks: [DashboardTask]
}

struct RemindersFile: Codable {
  var schemaVersion: Int
  var generatedAt: Date
  var reminders: [Reminder]
}

struct Reminder: Codable, Identifiable, Hashable {
  var id: String
  var title: String
  var dueAt: Date
}

// MARK: - Tracker Items

enum TrackerItemStatus: String, Codable, CaseIterable, Hashable {
  case notStarted = "not_started"
  case inProgress = "in_progress"
  case done
  case skipped
}

struct TrackerItem: Codable, Identifiable, Hashable {
  var id: String
  var projectId: String
  var title: String
  var status: TrackerItemStatus
  var difficulty: String?    // e.g. "Easy", "Medium", "Hard" or custom
  var tags: [String]?
  var notes: String?
  var links: [String]?
  var createdAt: Date
  var updatedAt: Date
}

// MARK: - Work Tracker (Personal Productivity)

struct TrackerEntry: Codable, Identifiable, Hashable {
  var id: String
  var type: TrackerEntryType  // work_session/deadline/note
  var rawText: String
  var duration: Int?  // minutes
  var category: String?
  var dueDate: Date?
  var estimatedMinutes: Int?
  var createdAt: Date
  var updatedAt: Date
}

enum TrackerEntryType: String, Codable, Hashable, CaseIterable {
  case workSession = "work_session"
  case deadline = "deadline"
  case note = "note"
  case analysis = "analysis"
  
  var displayName: String {
    switch self {
    case .workSession: return "Work Session"
    case .deadline: return "Deadline"
    case .note: return "Note"
    case .analysis: return "AI Analysis"
    }
  }
  
  var icon: String {
    switch self {
    case .workSession: return "clock.fill"
    case .deadline: return "calendar.badge.exclamationmark"
    case .note: return "note.text"
    case .analysis: return "brain.head.profile"
    }
  }
}

struct TrackerSummary: Codable, Hashable {
  var totalEntries: Int
  var workSessionsCount: Int
  var totalMinutesLogged: Int
  var deadlinesCount: Int
  var upcomingDeadlines: Int
  var notesCount: Int
  var categories: [String: Int]  // category -> count
  var last7DaysMinutes: Int
}

struct DeadlineEntry: Codable, Identifiable, Hashable {
  var id: String
  var rawText: String
  var category: String?
  var dueDate: Date
  var estimatedMinutes: Int?
  var createdAt: Date
}

// MARK: - Notifications

enum NotificationType: String, Codable {
  case reminder = "reminder"
  case blocker = "blocker"
  case error = "error"
  case success = "success"
  case info = "info"
  case warning = "warning"

  var displayName: String {
    switch self {
    case .reminder: return "Reminder"
    case .blocker: return "Blocker"
    case .error: return "Error"
    case .success: return "Success"
    case .info: return "Info"
    case .warning: return "Warning"
    }
  }

  var iconName: String {
    switch self {
    case .reminder: return "bell.fill"
    case .blocker: return "hand.raised.fill"
    case .error: return "xmark.circle.fill"
    case .success: return "checkmark.circle.fill"
    case .info: return "info.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    }
  }

  var priority: NotificationPriority {
    switch self {
    case .reminder, .blocker, .error:
      return .high
    case .warning:
      return .medium
    case .success, .info:
      return .low
    }
  }
}

enum NotificationPriority: Int, Codable {
  case low = 0
  case medium = 1
  case high = 2
}

struct DashboardNotification: Identifiable, Codable {
  var id: String
  var type: NotificationType
  var message: String
  var createdAt: Date
  var dismissed: Bool

  init(id: String = UUID().uuidString, type: NotificationType, message: String, createdAt: Date = Date(), dismissed: Bool = false) {
    self.id = id
    self.type = type
    self.message = message
    self.createdAt = createdAt
    self.dismissed = dismissed
  }
}

struct NotificationPreferences: Codable {
  var enabledTypes: Set<String> // Set of NotificationType.rawValue
  var batchLowPriority: Bool
  var batchIntervalSeconds: Int // How long to wait before showing batched notifications

  static var `default`: NotificationPreferences {
    NotificationPreferences(
      enabledTypes: Set(NotificationType.allCases.map { $0.rawValue }),
      batchLowPriority: true,
      batchIntervalSeconds: 30
    )
  }
}

extension NotificationType: CaseIterable {}

// MARK: - Calendar Events

struct ScheduledEvent: Codable, Identifiable {
  var id: String
  var title: String
  var description: String?
  var eventType: String? // e.g., "reminder", "task", "meeting"
  var scheduledAt: Date
  var endAt: Date?
  var allDay: Bool?
  var recurrenceRule: String?
  var recurrenceEnd: Date?
  var targetType: String? // e.g., "task", "project"
  var targetAgent: String?
  var taskProjectId: String?
  var taskNotes: String?
  var taskPriority: String?
  var status: String? // e.g., "pending", "completed", "cancelled"
  var lastFiredAt: Date?
  var nextFireAt: Date?
  var fireCount: Int?
  var createdAt: Date?
  var updatedAt: Date?
  
  var displayType: String {
    eventType?.capitalized ?? "Event"
  }
  
  var isUpcoming: Bool {
    scheduledAt > Date()
  }
  
  var isPast: Bool {
    scheduledAt < Date()
  }
  
  var timeUntil: String {
    let now = Date()
    let diff = scheduledAt.timeIntervalSince(now)
    
    if diff < 0 {
      return "Past"
    } else if diff < 60 {
      return "Now"
    } else if diff < 3600 {
      let mins = Int(diff / 60)
      return "in \(mins)m"
    } else if diff < 86400 {
      let hours = Int(diff / 3600)
      return "in \(hours)h"
    } else {
      let days = Int(diff / 86400)
      return "in \(days)d"
    }
  }
}

// MARK: - Calendar Range Response

struct CalendarDayEvents: Codable {
  var date: String  // YYYY-MM-DD format
  var events: [ScheduledEvent]
}

struct CalendarRangeResponse: Codable {
  var startDate: String  // YYYY-MM-DD format
  var endDate: String    // YYYY-MM-DD format
  var days: [CalendarDayEvents]
}

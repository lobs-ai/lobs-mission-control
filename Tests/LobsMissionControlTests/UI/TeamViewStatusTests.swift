import XCTest
@testable import LobsMissionControl

/// Tests for Team view correctly displaying active worker status
final class TeamViewStatusTests: XCTestCase {
  
  // MARK: - OrchestratorStatus Model
  
  func testOrchestratorStatusDecoding() throws {
    let json = """
    {
      "running": true,
      "paused": false,
      "worker": {
        "active": true,
        "workerId": "programmer-123-ABC",
        "currentTask": "Fix authentication bug",
        "currentProject": "backend-api"
      },
      "agents": {
        "programmer": {
          "agent_type": "programmer",
          "status": "working",
          "activity": "Implementing auth middleware",
          "thinking": null,
          "current_task_id": "task-456",
          "current_project_id": "proj-789",
          "last_active_at": "2024-01-15T10:30:00Z",
          "last_completed_task_id": "task-123",
          "last_completed_at": "2024-01-15T09:00:00Z",
          "stats": {
            "tasks_completed": 42,
            "tasks_failed": 3,
            "avg_duration_seconds": 1800
          }
        }
      },
      "poll_interval": 10
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let status = try decoder.decode(OrchestratorStatus.self, from: json)
    
    XCTAssertTrue(status.running)
    XCTAssertFalse(status.paused)
    XCTAssertEqual(status.pollInterval, 10)
    
    // Worker status
    XCTAssertNotNil(status.worker)
    XCTAssertEqual(status.worker?.active, true)
    XCTAssertEqual(status.worker?.workerId, "programmer-123-ABC")
    XCTAssertEqual(status.worker?.currentTask, "Fix authentication bug")
    XCTAssertEqual(status.worker?.currentProject, "backend-api")
    
    // Agent status
    XCTAssertEqual(status.agents.count, 1)
    XCTAssertNotNil(status.agents["programmer"])
    
    let programmer = status.agents["programmer"]!
    XCTAssertEqual(programmer.agentType, "programmer")
    XCTAssertEqual(programmer.status, "working")
    XCTAssertEqual(programmer.activity, "Implementing auth middleware")
    XCTAssertEqual(programmer.currentTaskId, "task-456")
    XCTAssertEqual(programmer.currentProjectId, "proj-789")
    XCTAssertNotNil(programmer.lastActiveAt)
    XCTAssertNotNil(programmer.lastCompletedAt)
    
    // Agent stats
    XCTAssertNotNil(programmer.stats)
    XCTAssertEqual(programmer.stats?.tasksCompleted, 42)
    XCTAssertEqual(programmer.stats?.tasksFailed, 3)
    XCTAssertEqual(programmer.stats?.avgDurationSeconds, 1800)
  }
  
  // MARK: - Agent Status Fields
  
  func testAgentStatusWithCurrentTask() throws {
    let json = """
    {
      "agent_type": "researcher",
      "status": "working",
      "activity": "Researching AI safety papers",
      "thinking": "Analyzing paper #3",
      "current_task_id": "research-task-789",
      "current_project_id": "ai-research-proj",
      "last_active_at": "2024-01-15T11:00:00Z",
      "last_completed_task_id": "research-task-456",
      "last_completed_at": "2024-01-15T10:00:00Z",
      "stats": {
        "tasks_completed": 12,
        "tasks_failed": 1,
        "avg_duration_seconds": 3600
      }
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let agent = try decoder.decode(AgentStatus.self, from: json)
    
    XCTAssertEqual(agent.agentType, "researcher")
    XCTAssertEqual(agent.status, "working")
    XCTAssertEqual(agent.activity, "Researching AI safety papers")
    XCTAssertEqual(agent.thinking, "Analyzing paper #3")
    XCTAssertEqual(agent.currentTaskId, "research-task-789")
    XCTAssertEqual(agent.currentProjectId, "ai-research-proj")
    XCTAssertTrue(agent.isActive)
  }
  
  func testAgentStatusIdle() throws {
    let json = """
    {
      "agent_type": "writer",
      "status": "idle",
      "activity": null,
      "thinking": null,
      "current_task_id": null,
      "current_project_id": null,
      "last_active_at": "2024-01-15T08:00:00Z",
      "last_completed_task_id": "write-task-123",
      "last_completed_at": "2024-01-15T08:00:00Z",
      "stats": {
        "tasks_completed": 5,
        "tasks_failed": 0,
        "avg_duration_seconds": 900
      }
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let agent = try decoder.decode(AgentStatus.self, from: json)
    
    XCTAssertEqual(agent.agentType, "writer")
    XCTAssertEqual(agent.status, "idle")
    XCTAssertNil(agent.activity)
    XCTAssertNil(agent.thinking)
    XCTAssertNil(agent.currentTaskId)
    XCTAssertNil(agent.currentProjectId)
    XCTAssertFalse(agent.isActive)
  }
  
  // MARK: - Worker Status Fields
  
  func testWorkerStatusActive() throws {
    let json = """
    {
      "active": true,
      "workerId": "architect-456-DEF",
      "currentTask": "Design database schema",
      "currentProject": "backend-rewrite",
      "startedAt": "2024-01-15T10:00:00Z",
      "tasksCompleted": 2,
      "lastHeartbeat": "2024-01-15T10:30:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let worker = try decoder.decode(WorkerStatus.self, from: json)
    
    XCTAssertTrue(worker.active)
    XCTAssertEqual(worker.workerId, "architect-456-DEF")
    XCTAssertEqual(worker.currentTask, "Design database schema")
    XCTAssertEqual(worker.currentProject, "backend-rewrite")
    XCTAssertNotNil(worker.startedAt)
    XCTAssertEqual(worker.tasksCompleted, 2)
    XCTAssertNotNil(worker.lastHeartbeat)
  }
  
  func testWorkerStatusInactive() throws {
    let json = """
    {
      "active": false,
      "workerId": null,
      "currentTask": null,
      "currentProject": null,
      "startedAt": null,
      "tasksCompleted": null,
      "lastHeartbeat": null
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let worker = try decoder.decode(WorkerStatus.self, from: json)
    
    XCTAssertFalse(worker.active)
    XCTAssertNil(worker.workerId)
    XCTAssertNil(worker.currentTask)
    XCTAssertNil(worker.currentProject)
  }
  
  // MARK: - Edge Cases
  
  func testOrchestratorStatusPaused() throws {
    let json = """
    {
      "running": true,
      "paused": true,
      "worker": null,
      "agents": {},
      "poll_interval": 10
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let status = try decoder.decode(OrchestratorStatus.self, from: json)
    
    XCTAssertTrue(status.running)
    XCTAssertTrue(status.paused)
    XCTAssertNil(status.worker)
    XCTAssertEqual(status.agents.count, 0)
  }
  
  func testMultipleAgents() throws {
    let json = """
    {
      "running": true,
      "paused": false,
      "worker": null,
      "agents": {
        "programmer": {
          "agent_type": "programmer",
          "status": "working",
          "activity": "Coding feature X",
          "current_task_id": "task-1",
          "stats": {}
        },
        "researcher": {
          "agent_type": "researcher",
          "status": "idle",
          "activity": null,
          "current_task_id": null,
          "stats": {}
        },
        "reviewer": {
          "agent_type": "reviewer",
          "status": "working",
          "activity": "Reviewing PR #42",
          "current_task_id": "task-3",
          "stats": {}
        }
      },
      "poll_interval": 10
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let status = try decoder.decode(OrchestratorStatus.self, from: json)
    
    XCTAssertEqual(status.agents.count, 3)
    
    // Programmer is working
    let programmer = status.agents["programmer"]!
    XCTAssertEqual(programmer.status, "working")
    XCTAssertEqual(programmer.activity, "Coding feature X")
    XCTAssertEqual(programmer.currentTaskId, "task-1")
    XCTAssertTrue(programmer.isActive)
    
    // Researcher is idle
    let researcher = status.agents["researcher"]!
    XCTAssertEqual(researcher.status, "idle")
    XCTAssertNil(researcher.activity)
    XCTAssertNil(researcher.currentTaskId)
    XCTAssertFalse(researcher.isActive)
    
    // Reviewer is working
    let reviewer = status.agents["reviewer"]!
    XCTAssertEqual(reviewer.status, "working")
    XCTAssertEqual(reviewer.activity, "Reviewing PR #42")
    XCTAssertEqual(reviewer.currentTaskId, "task-3")
    XCTAssertTrue(reviewer.isActive)
  }
}

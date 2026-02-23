import Foundation

// MARK: - Intelligence Summary

struct IntelligenceSummary: Codable {
    let pendingReviews: Int
    let recentApprovalRate: ApprovalRate?
    let lastReflection: LastReflection?
    let lastSweep: LastSweep?
    
    struct ApprovalRate: Codable {
        let approved: Int
        let total: Int
        let days: Int
        
        var percentage: Int {
            total > 0 ? (approved * 100) / total : 0
        }
    }
    
    struct LastReflection: Codable {
        let timestamp: Date
        let agentCount: Int
        let initiativesProposed: Int
    }
    
    struct LastSweep: Codable {
        let timestamp: Date
        let decisionsMade: Int
    }
}

// MARK: - Reflection Cycle

struct ReflectionCycle: Identifiable, Codable, Hashable {
    let id: String
    let batchId: String
    let agents: [String]
    let status: ReflectionStatus
    let startedAt: Date
    let completedAt: Date?
    let inefficiencies: [String]
    let missedOpportunities: [String]
    let systemRisks: [String]
    let identityAdjustments: [String]
    let proposedInitiatives: [String]  // Initiative IDs
    let errorMessage: String?
    
    enum ReflectionStatus: String, Codable, Hashable {
        case pending
        case running
        case completed
        case failed
    }
}

// MARK: - Reflection Details

struct ReflectionDetails: Codable {
    let cycle: ReflectionCycle
    let initiatives: [InitiativeReviewItem]
}

// MARK: - Reflections List Response

struct ReflectionsListResponse: Codable {
    let reflections: [ReflectionCycle]
    let total: Int
}

// MARK: - Sweep Models

struct SweepCycle: Identifiable, Codable, Hashable {
    let id: String
    let sweepType: String
    let status: String
    let summary: String?
    let totalProposed: Int
    let approvedCount: Int
    let rejectedCount: Int
    let deferredCount: Int
    let createdAt: Date
    let completedAt: Date?
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var statusColor: String {
        switch status.lowercased() {
        case "completed": return "green"
        case "pending", "in_progress": return "orange"
        case "failed": return "red"
        default: return "gray"
        }
    }
}

struct SweepDecision: Identifiable, Codable, Hashable {
    let id: String
    let initiativeId: String
    let sweepId: String
    let decision: String  // approved, rejected, deferred
    let decidedBy: String  // lobs, rafe
    let rationale: String?
    let taskId: String?  // if approved and created
    let decidedAt: Date
    
    // Embedded initiative data
    let initiativeTitle: String
    let initiativeDescription: String?
    let initiativeCategory: String
    let riskTier: String
    
    var decisionColor: String {
        switch decision.lowercased() {
        case "approved": return "green"
        case "rejected": return "red"
        case "deferred": return "blue"
        default: return "gray"
        }
    }
}

struct SweepDetails: Codable {
    let sweep: SweepCycle
    let decisions: [SweepDecision]
}

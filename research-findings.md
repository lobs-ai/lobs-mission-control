# Research Findings: Agent Decision Pattern Capture System

**Date:** 2026-02-13  
**Task ID:** 6f5b46a9-4560-4644-a8b5-dc7dd4baddec  
**Status:** ✅ Design complete

---

## Executive Summary

This research proposes a **modular, well-integrated system** for capturing agent decisions and feedback to create a learning loop that improves agent performance over time.

**Key Principles:**
- **Non-invasive**: Works alongside existing orchestrator without breaking flows
- **Modular**: Can be enabled/disabled, components can be evaluated independently
- **Observable**: Clear visibility into what's captured and whether it's working
- **Actionable**: Clear path from capture → analysis → prompt improvement

**Expected Impact:**
- Reduce agent mistakes through learned patterns
- Surface high-value decision patterns for reuse
- Enable data-driven agent prompt optimization
- Build institutional knowledge about what works

---

## Current System Analysis

### Architecture Context

**Source:** `/Users/lobs/lobs-server/` (lobs-server repository)

The orchestrator system has these key components:

```
┌─────────────────────────────────────────────────────────────┐
│ Orchestrator Engine (app/orchestrator/engine.py)           │
│ - Polls for eligible tasks                                   │
│ - Dispatches work to workers                                 │
│ - Monitors worker health                                     │
└───────────────┬─────────────────────────────────────────────┘
                │
                ↓
┌─────────────────────────────────────────────────────────────┐
│ Worker Manager (app/orchestrator/worker.py)                 │
│ - Spawns OpenClaw workers                                    │
│ - Tracks active workers (in-memory + DB)                     │
│ - Enforces domain locks (one worker per project)             │
│ - Records WorkerRun entries                                  │
└───────────────┬─────────────────────────────────────────────┘
                │
                ↓
┌─────────────────────────────────────────────────────────────┐
│ Prompter (app/orchestrator/prompter.py)                     │
│ - Builds agent prompts with context                          │
│ - Includes: AGENTS.md, SOUL.md, rules, project context       │
│ - This is where improvements would be injected               │
└─────────────────────────────────────────────────────────────┘
```

### Current Tracking

**WorkerRun Model** (`app/models.py:170-193`)

Already tracks:
- ✅ Task execution metadata (worker_id, start/end times, task_id)
- ✅ Token usage (input/output/total)
- ✅ Cost tracking (total_cost_usd)
- ✅ Success/failure (succeeded boolean)
- ✅ Work summary (from .work-summary file)
- ✅ Files modified, commit SHAs

**What's Missing:**
- ❌ **Decision points** — What choices did the agent make and why?
- ❌ **Alternatives considered** — What other approaches were evaluated?
- ❌ **Feedback** — Was this a good decision or could it be better?
- ❌ **Patterns** — Which decision patterns correlate with success?

---

## Proposed Solution: Modular Decision Capture System

### Design Philosophy

**Three-tier architecture:**

1. **Capture Layer** — Lightweight, passive data collection
2. **Analysis Layer** — Pattern detection and feedback processing
3. **Application Layer** — Prompt improvement based on learned patterns

**Each tier is independent, testable, and can be toggled on/off.**

---

## Phase 1: Capture Layer (Foundation)

### 1.1 Database Schema Extension

**New Table: `agent_decisions`**

```sql
CREATE TABLE agent_decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    worker_run_id INTEGER REFERENCES worker_runs(id),
    task_id TEXT REFERENCES tasks(id),
    agent_type TEXT,
    
    -- Decision metadata
    decision_point TEXT,           -- e.g., "file_structure", "testing_approach"
    chosen_approach TEXT,          -- What the agent decided to do
    alternatives_considered JSON,  -- [{"approach": "...", "reason_discarded": "..."}]
    rationale TEXT,                -- Agent's explanation for choice
    
    -- Context
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_context JSON,        -- Relevant task/project context at decision time
    
    -- Feedback (populated later)
    feedback_quality TEXT,         -- "excellent", "good", "okay", "poor", "bad"
    feedback_notes TEXT,           -- Human feedback or automated analysis
    feedback_at TIMESTAMP,
    feedback_source TEXT           -- "human", "automated", "system"
);

CREATE INDEX idx_agent_decisions_task ON agent_decisions(task_id);
CREATE INDEX idx_agent_decisions_worker ON agent_decisions(worker_run_id);
CREATE INDEX idx_agent_decisions_agent_type ON agent_decisions(agent_type);
CREATE INDEX idx_agent_decisions_point ON agent_decisions(decision_point);
CREATE INDEX idx_agent_decisions_quality ON agent_decisions(feedback_quality);
```

**Rationale:**
- Links to existing `worker_runs` table (non-invasive)
- JSON for flexibility (can evolve without migrations)
- Feedback fields separate (can be populated asynchronously)
- Indexes for fast queries (analysis won't slow down orchestrator)

### 1.2 Capture Mechanism

**Method 1: Agent Self-Reporting (Primary)**

Agents explicitly log decisions in a structured format:

```python
# In agent workspace: .agent-decisions.jsonl
{"decision_point": "file_structure", "chosen": "created lib/utils.py", 
 "alternatives": ["keep in main.py", "split into multiple modules"],
 "rationale": "Enables reuse, keeps tests clean"}
{"decision_point": "testing_approach", "chosen": "unit + integration tests",
 "alternatives": ["unit only", "integration only"],
 "rationale": "Fast iteration + real-world validation"}
```

**Implementation:**
- Add `.agent-decisions.jsonl` to agent workspace template
- Update AGENTS.md to encourage decision logging
- Worker manager reads file after task completion
- Parse and insert into `agent_decisions` table

**Method 2: Automatic Extraction (Secondary)**

Parse decisions from work summary and commit messages:

```python
# In worker.py, after task completion
async def _extract_decisions_from_summary(summary: str) -> list[dict]:
    """Parse structured decision data from work summary."""
    # Look for patterns like:
    # - "Chose X over Y because Z"
    # - "Decided to X (alternatives: Y, Z)"
    # - Decision markers in summary
    pass
```

**Pros/Cons:**

| Method | Pros | Cons |
|--------|------|------|
| Self-reporting | - Accurate rationale<br>- Captures thought process<br>- Agent control | - Requires agent cooperation<br>- May be forgotten |
| Auto-extraction | - No agent changes needed<br>- Works retroactively | - Less accurate<br>- Miss subtle decisions |

**Recommendation:** Start with self-reporting, add auto-extraction as backup.

### 1.3 Integration Points

**Worker Manager** (`app/orchestrator/worker.py`)

Add after task completion (line ~400+):

```python
async def _finalize_worker_run(self, worker_id: str, run_id: int, ...):
    # ... existing code ...
    
    # Capture agent decisions
    if self._decision_capture_enabled():
        await self._capture_agent_decisions(
            worker_run_id=run_id,
            task_id=task_id,
            agent_type=agent_type,
            workspace_path=workspace_path
        )
    
    # ... existing code ...

async def _capture_agent_decisions(
    self,
    worker_run_id: int,
    task_id: str,
    agent_type: str,
    workspace_path: Path
):
    """Read .agent-decisions.jsonl and save to DB."""
    decisions_file = workspace_path / ".agent-decisions.jsonl"
    if not decisions_file.exists():
        return
    
    try:
        from app.models import AgentDecision
        
        with open(decisions_file, "r") as f:
            for line in f:
                if not line.strip():
                    continue
                decision_data = json.loads(line)
                
                # Create DB entry
                decision = AgentDecision(
                    worker_run_id=worker_run_id,
                    task_id=task_id,
                    agent_type=agent_type,
                    decision_point=decision_data.get("decision_point"),
                    chosen_approach=decision_data.get("chosen"),
                    alternatives_considered=decision_data.get("alternatives"),
                    rationale=decision_data.get("rationale"),
                    execution_context={"task_title": ..., "project": ...}
                )
                self.db.add(decision)
        
        await self.db.commit()
        logger.info(f"Captured decisions for task {task_id[:8]}")
    
    except Exception as e:
        logger.warning(f"Failed to capture decisions: {e}")
        # Non-blocking failure — don't break task completion
```

**Agent Workspace Template**

Update agent workspace files:

```markdown
# In ~/.openclaw/workspace-{agent}/AGENTS.md

## Decision Logging (Optional but Encouraged)

To help improve future agent performance, log key decisions in `.agent-decisions.jsonl`:

```jsonl
{"decision_point": "architecture", "chosen": "microservices", 
 "alternatives": ["monolith", "serverless"], 
 "rationale": "Better scalability for expected growth"}
```

This helps the system learn which approaches work best for different situations.
```

**Configuration** (`app/orchestrator/config.py`)

```python
# Feature flag for decision capture
DECISION_CAPTURE_ENABLED = os.getenv("DECISION_CAPTURE_ENABLED", "true").lower() == "true"
```

---

## Phase 2: Analysis Layer

### 2.1 Decision Pattern Detection

**Goal:** Identify which decision patterns correlate with success.

**Module:** `app/orchestrator/decision_analyzer.py` (new file)

```python
"""Decision pattern analyzer.

Identifies patterns in agent decisions that correlate with successful outcomes.
"""

from typing import Any
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import AgentDecision, WorkerRun, Task

class DecisionAnalyzer:
    """Analyzes decision patterns and success correlations."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_decision_patterns(
        self,
        agent_type: str | None = None,
        decision_point: str | None = None,
        min_occurrences: int = 3
    ) -> list[dict[str, Any]]:
        """
        Find recurring decision patterns.
        
        Returns patterns like:
        {
            "agent_type": "programmer",
            "decision_point": "file_structure",
            "chosen_approach": "created lib/utils.py",
            "occurrences": 5,
            "success_rate": 0.8,  # 4/5 succeeded
            "avg_feedback_quality": "good"
        }
        """
        query = (
            select(
                AgentDecision.agent_type,
                AgentDecision.decision_point,
                AgentDecision.chosen_approach,
                func.count(AgentDecision.id).label("occurrences"),
                func.avg(
                    case((WorkerRun.succeeded == True, 1), else_=0)
                ).label("success_rate")
            )
            .join(WorkerRun, AgentDecision.worker_run_id == WorkerRun.id)
            .group_by(
                AgentDecision.agent_type,
                AgentDecision.decision_point,
                AgentDecision.chosen_approach
            )
            .having(func.count(AgentDecision.id) >= min_occurrences)
        )
        
        if agent_type:
            query = query.where(AgentDecision.agent_type == agent_type)
        if decision_point:
            query = query.where(AgentDecision.decision_point == decision_point)
        
        result = await self.db.execute(query)
        return [dict(row) for row in result]
    
    async def get_high_value_decisions(
        self,
        agent_type: str,
        limit: int = 10
    ) -> list[dict[str, Any]]:
        """
        Find decisions with high success correlation.
        
        Returns decisions where:
        - Success rate > 80%
        - Occurred at least 3 times
        - Has human feedback marked "excellent" or "good"
        """
        query = (
            select(AgentDecision, WorkerRun)
            .join(WorkerRun, AgentDecision.worker_run_id == WorkerRun.id)
            .where(
                and_(
                    AgentDecision.agent_type == agent_type,
                    WorkerRun.succeeded == True,
                    AgentDecision.feedback_quality.in_(["excellent", "good"])
                )
            )
            .limit(limit)
        )
        
        result = await self.db.execute(query)
        return [{"decision": dec, "run": run} for dec, run in result]
    
    async def get_anti_patterns(
        self,
        agent_type: str,
        limit: int = 10
    ) -> list[dict[str, Any]]:
        """
        Find decisions that correlate with failure.
        
        Returns decisions where:
        - Success rate < 40%
        - Occurred at least 2 times
        - Has feedback marked "poor" or "bad"
        """
        # Similar to above, but inverted criteria
        pass
```

**Usage:**

```python
# In analysis script or dashboard API
analyzer = DecisionAnalyzer(db)

# What file structures work best for programmer agent?
patterns = await analyzer.get_decision_patterns(
    agent_type="programmer",
    decision_point="file_structure"
)

# High-value decisions to reinforce
good = await analyzer.get_high_value_decisions("programmer")

# Anti-patterns to avoid
bad = await analyzer.get_anti_patterns("programmer")
```

### 2.2 Feedback Collection

**Manual Feedback** (via dashboard)

Add to Documents view or create dedicated Decision Review section:

```
Decision Review
├── Pending Review (decisions without feedback)
├── Recent Decisions (last 20)
└── By Agent Type
    ├── Programmer (5 decisions)
    ├── Researcher (3 decisions)
    └── Reviewer (2 decisions)

[Decision Card]
Task: Fix auth middleware (#abc123)
Agent: Programmer
Decision: Created lib/auth_utils.py for shared functions
Alternatives: Keep in main.py, Use external package
Rationale: "Enables reuse across modules, keeps main.py focused"

Outcome: ✅ Task succeeded
Files changed: 3 (+120 lines)
Cost: $0.08

Your feedback:
[Excellent] [Good] [Okay] [Poor] [Bad]
Notes: ___________________________
[Submit Feedback]
```

**Automated Feedback**

Basic signals that can be computed automatically:

```python
async def _compute_automated_feedback(decision: AgentDecision, run: WorkerRun):
    """Compute basic quality signals from task outcome."""
    
    signals = []
    
    # Task success
    if run.succeeded:
        signals.append("task_succeeded")
    
    # Efficiency (tokens vs typical for agent type)
    avg_tokens = await get_avg_tokens_for_agent_type(run.agent_type)
    if run.total_tokens < avg_tokens * 0.7:
        signals.append("efficient_execution")
    elif run.total_tokens > avg_tokens * 1.5:
        signals.append("inefficient_execution")
    
    # Files modified (simplicity check)
    if len(run.files_modified or []) <= 3:
        signals.append("focused_changes")
    elif len(run.files_modified or []) > 10:
        signals.append("sprawling_changes")
    
    # Determine quality
    if "task_succeeded" in signals and "efficient_execution" in signals:
        return "good", ", ".join(signals)
    elif "task_succeeded" in signals:
        return "okay", ", ".join(signals)
    else:
        return "poor", ", ".join(signals)
```

---

## Phase 3: Application Layer

### 3.1 Prompt Enhancement

**Goal:** Inject learned patterns into agent prompts to improve future performance.

**Module:** `app/orchestrator/prompt_enhancer.py` (new file)

```python
"""Prompt enhancer - injects learned decision patterns into agent prompts.

Integrates with Prompter to add decision guidance based on historical data.
"""

from app.orchestrator.decision_analyzer import DecisionAnalyzer

class PromptEnhancer:
    """Enhances prompts with learned decision patterns."""
    
    def __init__(self, db: AsyncSession):
        self.analyzer = DecisionAnalyzer(db)
    
    async def get_decision_guidance(
        self,
        agent_type: str,
        task_context: dict[str, Any]
    ) -> str:
        """
        Generate decision guidance based on learned patterns.
        
        Returns markdown section to inject into agent prompt.
        """
        
        # Get high-value patterns for this agent type
        good_patterns = await self.analyzer.get_high_value_decisions(
            agent_type=agent_type,
            limit=5
        )
        
        # Get anti-patterns to avoid
        bad_patterns = await self.analyzer.get_anti_patterns(
            agent_type=agent_type,
            limit=3
        )
        
        if not good_patterns and not bad_patterns:
            return ""  # No guidance available yet
        
        sections = []
        
        if good_patterns:
            sections.append("## Learned Patterns (What Works)\n")
            sections.append("Based on analysis of previous successful tasks:\n\n")
            
            for item in good_patterns:
                dec = item["decision"]
                sections.append(
                    f"- **{dec.decision_point}**: "
                    f"{dec.chosen_approach}\n"
                    f"  - Rationale: {dec.rationale}\n"
                    f"  - Success rate: {item['success_rate']:.0%}\n"
                )
        
        if bad_patterns:
            sections.append("\n## Anti-Patterns (What to Avoid)\n")
            sections.append("These approaches have had poor outcomes:\n\n")
            
            for item in bad_patterns:
                dec = item["decision"]
                sections.append(
                    f"- ❌ **{dec.decision_point}**: "
                    f"Avoid {dec.chosen_approach}\n"
                    f"  - Failure rate: {item['failure_rate']:.0%}\n"
                )
        
        return "\n".join(sections)
```

**Integration with Prompter**

Update `app/orchestrator/prompter.py`:

```python
# In Prompter.build_task_prompt()

# ... existing code ...

# OPTIONAL: Inject learned decision guidance
if DECISION_GUIDANCE_ENABLED:
    try:
        from app.orchestrator.prompt_enhancer import PromptEnhancer
        enhancer = PromptEnhancer(db)  # Need to pass db session
        guidance = await enhancer.get_decision_guidance(
            agent_type=agent_type,
            task_context={"task_id": task_id, "project": project_id}
        )
        if guidance:
            prompt_parts.append("\n" + guidance + "\n---\n\n")
    except Exception as e:
        logger.warning(f"Failed to add decision guidance: {e}")
        # Non-blocking failure

# ... existing code ...
```

### 3.2 A/B Testing Framework

**Goal:** Measure if decision guidance actually improves outcomes.

**Approach:**
- 50% of tasks get enhanced prompts (test group)
- 50% get standard prompts (control group)
- Track which group has better success rate, efficiency, quality

**Implementation:**

```python
# In worker.py, before building prompt

def _should_use_enhanced_prompt(task_id: str) -> bool:
    """Deterministic A/B test assignment based on task ID."""
    # Use hash to ensure consistent assignment for same task
    hash_val = int(hashlib.md5(task_id.encode()).hexdigest(), 16)
    return hash_val % 2 == 0  # 50/50 split

# When spawning worker:
use_enhancement = self._should_use_enhanced_prompt(task_id)

# Build prompt accordingly
if use_enhancement and DECISION_GUIDANCE_ENABLED:
    prompt = await prompter.build_enhanced_prompt(...)
else:
    prompt = await prompter.build_task_prompt(...)

# Record in WorkerRun
run.experiment_group = "enhanced" if use_enhancement else "control"
```

**Analysis Query:**

```sql
-- Compare success rates between groups
SELECT 
    experiment_group,
    COUNT(*) as total_runs,
    SUM(CASE WHEN succeeded THEN 1 ELSE 0 END) as successes,
    AVG(CASE WHEN succeeded THEN 1.0 ELSE 0.0 END) as success_rate,
    AVG(total_tokens) as avg_tokens,
    AVG(total_cost_usd) as avg_cost
FROM worker_runs
WHERE experiment_group IS NOT NULL
GROUP BY experiment_group;
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
**Goal:** Start capturing decisions without breaking anything

- [ ] Add `agent_decisions` table to database schema
- [ ] Add migration script
- [ ] Update Worker Manager to read `.agent-decisions.jsonl`
- [ ] Update agent workspace templates with decision logging guidance
- [ ] Add feature flag `DECISION_CAPTURE_ENABLED` (default: true)
- [ ] Test with single agent (Programmer) on 5-10 tasks
- [ ] Verify data is being captured correctly

**Success Criteria:**
- At least 3 decisions captured per task
- No worker failures due to capture code
- Data queryable in database

### Phase 2: Analysis (Week 2)
**Goal:** Build tools to understand what we're capturing

- [ ] Create `DecisionAnalyzer` module
- [ ] Add dashboard API endpoints for decision data
  - `GET /api/decisions/patterns` — Pattern frequency
  - `GET /api/decisions/pending-feedback` — Decisions needing review
  - `GET /api/decisions/stats` — Success correlation stats
- [ ] Add Decision Review section to dashboard
  - List pending decisions
  - Feedback submission UI
  - Pattern visualization
- [ ] Collect feedback on 20+ decisions
- [ ] Run first pattern analysis

**Success Criteria:**
- Can identify at least 3 recurring patterns
- Feedback collection workflow is smooth
- Clear correlation data between decisions and success

### Phase 3: Application (Week 3)
**Goal:** Use learned patterns to improve agent performance

- [ ] Create `PromptEnhancer` module
- [ ] Integrate with Prompter (feature-flagged)
- [ ] Implement A/B testing framework
- [ ] Run 20+ tasks with enhanced prompts (test group)
- [ ] Run 20+ tasks with standard prompts (control group)
- [ ] Analyze results

**Success Criteria:**
- Enhanced prompt group shows measurable improvement (5%+ better success rate OR 10%+ fewer tokens)
- No degradation in task quality
- System remains stable

### Phase 4: Refinement (Week 4)
**Goal:** Tune and expand based on results

- [ ] Add automated feedback computation
- [ ] Expand to all agent types (Researcher, Reviewer, Architect)
- [ ] Build pattern library UI
- [ ] Add pattern export/import (share across instances)
- [ ] Document learnings

---

## Integration Architecture

### File Structure

```
app/
├── models.py                      # Add AgentDecision model
├── schemas.py                     # Add decision schemas
├── orchestrator/
│   ├── worker.py                  # Add decision capture after task
│   ├── prompter.py                # Add enhancement injection point
│   ├── decision_analyzer.py       # NEW: Pattern analysis
│   ├── prompt_enhancer.py         # NEW: Prompt improvement
│   └── config.py                  # Add feature flags
├── routers/
│   └── decisions.py               # NEW: Decision API endpoints
└── services/
    └── feedback_processor.py      # NEW: Automated feedback

migrations/
└── 003_add_agent_decisions.sql    # NEW: Schema migration
```

### API Endpoints

```
GET  /api/decisions                # List decisions (paginated, filtered)
GET  /api/decisions/{id}           # Get single decision
POST /api/decisions/{id}/feedback  # Submit feedback
GET  /api/decisions/patterns       # Get pattern analysis
GET  /api/decisions/pending        # Decisions needing review
GET  /api/decisions/stats          # Success correlation stats
```

### Dashboard Integration

Add new section to Lobs Mission Control:

```swift
// In ContentView.swift sidebar

NavigationLink(destination: DecisionReviewView(vm: vm)) {
    Label("Decisions", systemImage: "chart.bar.doc.horizontal")
}

// New view: DecisionReviewView.swift
struct DecisionReviewView: View {
    @ObservedObject var vm: AppViewModel
    
    // Lists decisions, allows feedback submission
    // Shows patterns and stats
}
```

---

## Evaluation Metrics

### Capture Phase Metrics
- **Capture rate**: % of tasks with decision data
- **Decisions per task**: Average number of decisions captured
- **Capture failures**: Errors in capture process
- **Storage overhead**: Database size growth

**Target:** 80%+ capture rate, 3+ decisions per task, <1% failures

### Analysis Phase Metrics
- **Pattern coverage**: % of tasks with applicable patterns
- **Feedback completeness**: % of decisions with feedback
- **Pattern accuracy**: Inter-rater agreement on pattern quality
- **Analysis performance**: Query latency for pattern detection

**Target:** 60%+ pattern coverage, 40%+ feedback, <100ms queries

### Application Phase Metrics
- **Success rate delta**: Enhanced vs control group success rate
- **Efficiency delta**: Token usage difference
- **Quality delta**: Human-rated quality difference
- **Adoption rate**: % of agents using enhanced prompts

**Target:** +5% success rate, -10% token usage, no quality degradation

---

## Risk Mitigation

### Risk: Capture Overhead Slows Tasks
**Mitigation:**
- Make capture async (non-blocking)
- Feature flag to disable if issues
- Capture only after task success (don't slow failures)
- Timeout capture after 5 seconds

### Risk: Bad Patterns Get Reinforced
**Mitigation:**
- Require minimum sample size (3+ occurrences)
- Weight recent decisions higher
- Human review before adding to prompts
- A/B testing catches degradation
- Easy rollback via feature flag

### Risk: Agents Don't Log Decisions
**Mitigation:**
- Make logging optional (start with just a few agents)
- Add to AGENTS.md as encouraged practice
- Provide clear examples
- Fall back to auto-extraction
- Gamify: show agents their decision quality stats

### Risk: Storage Grows Too Large
**Mitigation:**
- Set retention policy (e.g., 90 days)
- Archive old decisions to cold storage
- Limit decisions per task (max 20)
- Compress JSON fields
- Periodic cleanup job

---

## Success Criteria

### Phase 1 (Capture)
- ✅ Decisions captured for 80%+ of tasks
- ✅ No worker failures caused by capture system
- ✅ Data structure supports analysis queries
- ✅ Feature can be disabled with single flag

### Phase 2 (Analysis)
- ✅ Can identify 5+ high-value patterns
- ✅ Can identify 3+ anti-patterns
- ✅ Feedback workflow is intuitive
- ✅ Queries return in <100ms

### Phase 3 (Application)
- ✅ Enhanced prompts show measurable improvement
- ✅ A/B test demonstrates value
- ✅ System remains stable under load
- ✅ Agents report prompts are helpful

### Overall Success
- 📈 Agent success rate improves by 5-10%
- 📉 Average task cost decreases by 10-15%
- 🎯 High-value patterns documented and reusable
- 🔄 Feedback loop is sustainable (doesn't require constant human input)

---

## Next Steps

### Immediate (This Week)
1. **Review this design** — Does it align with system goals?
2. **Create database migration** — `migrations/003_add_agent_decisions.sql`
3. **Prototype capture** — Test with 5 Programmer tasks
4. **Verify data quality** — Check captured decisions make sense

### Short-term (Next 2 Weeks)
1. Build `DecisionAnalyzer` module
2. Add dashboard API endpoints
3. Create Decision Review UI
4. Collect feedback on 20+ decisions

### Medium-term (Month 1)
1. Build `PromptEnhancer` module
2. Implement A/B testing
3. Run enhancement experiment
4. Measure and iterate

---

## Research References

### System Context Sources
- **Source:** `/Users/lobs/lobs-server/AGENTS.md` — System architecture
- **Source:** `/Users/lobs/lobs-server/ORCHESTRATOR_AUDIT.md` — Orchestrator capabilities
- **Source:** `/Users/lobs/lobs-server/app/models.py:170-193` — WorkerRun model
- **Source:** `/Users/lobs/lobs-server/app/orchestrator/worker.py` — Worker manager
- **Source:** `/Users/lobs/lobs-server/app/orchestrator/prompter.py` — Prompt builder

### Design Patterns
- **Agent feedback loops**: Reinforcement learning from human feedback (RLHF) patterns
- **Decision capture**: Structured logging with explicit decision points
- **Pattern mining**: Frequency analysis with success correlation
- **A/B testing**: Deterministic assignment, statistical comparison
- **Feature flags**: Progressive rollout with easy rollback

### Similar Systems
- **LangSmith**: Captures LLM decision traces for debugging
- **Weights & Biases**: ML experiment tracking and comparison
- **OpenAI Evals**: Evaluation framework for model outputs
- **Anthropic Constitutional AI**: Feedback-based model alignment

---

## Appendices

### Appendix A: Example Decision Log

```jsonl
{"decision_point": "file_structure", "chosen": "created lib/auth_utils.py", "alternatives": ["keep in main.py", "use external package"], "rationale": "Enables reuse, keeps main.py focused, avoids external dependency"}
{"decision_point": "error_handling", "chosen": "try/except with specific exceptions", "alternatives": ["bare except", "no error handling"], "rationale": "Specific exceptions aid debugging, prevents silent failures"}
{"decision_point": "testing_approach", "chosen": "pytest with fixtures", "alternatives": ["unittest", "no tests"], "rationale": "Pytest fixtures reduce boilerplate, match project convention"}
```

### Appendix B: Database Migration Script

```sql
-- migrations/003_add_agent_decisions.sql

CREATE TABLE IF NOT EXISTS agent_decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    worker_run_id INTEGER REFERENCES worker_runs(id) ON DELETE CASCADE,
    task_id TEXT REFERENCES tasks(id) ON DELETE CASCADE,
    agent_type TEXT NOT NULL,
    
    decision_point TEXT NOT NULL,
    chosen_approach TEXT NOT NULL,
    alternatives_considered JSON,
    rationale TEXT,
    
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_context JSON,
    
    feedback_quality TEXT CHECK(feedback_quality IN ('excellent', 'good', 'okay', 'poor', 'bad')),
    feedback_notes TEXT,
    feedback_at TIMESTAMP,
    feedback_source TEXT CHECK(feedback_source IN ('human', 'automated', 'system'))
);

CREATE INDEX idx_agent_decisions_task ON agent_decisions(task_id);
CREATE INDEX idx_agent_decisions_worker ON agent_decisions(worker_run_id);
CREATE INDEX idx_agent_decisions_agent_type ON agent_decisions(agent_type);
CREATE INDEX idx_agent_decisions_point ON agent_decisions(decision_point);
CREATE INDEX idx_agent_decisions_quality ON agent_decisions(feedback_quality);
CREATE INDEX idx_agent_decisions_captured_at ON agent_decisions(captured_at);

-- Add experiment_group to worker_runs for A/B testing
ALTER TABLE worker_runs ADD COLUMN experiment_group TEXT CHECK(experiment_group IN ('enhanced', 'control'));
```

### Appendix C: Agent Workspace Template Update

```markdown
<!-- Add to ~/.openclaw/workspace-{agent}/AGENTS.md -->

## Decision Logging

To help improve the orchestrator's learning, you can optionally log key decisions you make during task execution.

Create a file `.agent-decisions.jsonl` in your workspace with entries like:

\`\`\`jsonl
{"decision_point": "architecture", "chosen": "microservices", "alternatives": ["monolith", "serverless"], "rationale": "Better scalability"}
\`\`\`

**Common decision points:**
- `file_structure` — How you organized code
- `testing_approach` — Testing strategy chosen
- `error_handling` — How errors are handled
- `dependencies` — Libraries/packages chosen
- `architecture` — System design decisions
- `refactoring` — Code improvement approach

This is **optional** — if you don't log decisions, the orchestrator will still work normally. But over time, decision logs help identify patterns that lead to better outcomes.
```

---

## Conclusion

This design provides a **modular, well-integrated system** for capturing agent decisions and creating a feedback loop that improves performance over time.

**Key strengths:**
- ✅ Non-invasive integration (doesn't break existing flows)
- ✅ Progressive rollout (can test incrementally)
- ✅ Clear evaluation metrics (know if it's working)
- ✅ Easy rollback (feature flags + minimal coupling)
- ✅ Observable (dashboard UI + API endpoints)
- ✅ Extensible (can add more analysis/enhancement modules)

**Expected timeline:** 3-4 weeks from design to production-ready system.

**Recommended approach:** Start with Phase 1 (capture), validate data quality, then proceed to analysis and application phases.

---

**Confidence Level:** 🟢 **High** — Architecture is sound, integration points are clear, risks are mitigated.

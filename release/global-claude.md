# Project Instructions

## CAM Protocol

**Reference**: `~/.claude/CLAUDE.md`

CAM (Continuous Architectural Memory) protocol specification, hooks, and annotation schemas are defined globally.

## Project Documentation

**Hub**: `.ai/README.md`
**CAM**: Semantically query/search the CAM database, execute scripts in the `@~/.claude/hooks` directory.

All project-specific documentation is organized in the `.ai/` directory, as well as the CAM interface database. These are the **two sources of truth** for all documentation.

### Quick Routes

| Topic | Location |
|-------|----------|
| Architecture | `.ai/core/application-architecture.md` |
| Tech Stack | `.ai/core/technology-stack.md` |
| Development | `.ai/development/development-workflow.md` |
| Testing | `.ai/development/testing-patterns.md` |
| Patterns | `.ai/patterns/` |
| Security | `.ai/patterns/security-patterns.md` |

## CAM Integration

### Automatic (Hooks)

CAM hooks fire automatically during Claude Code sessions:

- **SessionStart**: Validates CAM, loads recent context
- **UserPromptSubmit**: Queries CAM before processing your message (proactive context injection)
- **PreToolUse**: Queries CAM before tool execution
- **PostToolUse**: Annotates operations after completion
- **SessionEnd**: Summarizes session and refines knowledge graph

### Manual Commands

CAM commands are available in any initialized project via `./.claude/cam/cam.sh`:

**Core Commands:**
- **Query**: `./.claude/cam/cam.sh query "intent"`
- **Add note**: `./.claude/cam/cam.sh note "Title" "Content"`
- **Stats**: `./.claude/cam/cam.sh stats`

**Ingestion Commands (v1.5.0):**
- **Ingest file/directory**: `./.claude/cam/cam.sh ingest <path> [type]`
  - Supports: code, docs, config (auto-detected if omitted)
  - `--force` re-ingests unchanged files
  - `--dry-run` shows what would be ingested
- **Scan directory**: `./.claude/cam/cam.sh scan <directory>`
- **Check file status**: `./.claude/cam/cam.sh check-file <path>`
- **File index stats**: `./.claude/cam/cam.sh file-stats`

**Examples:**
```bash
# Ingest entire codebase
./.claude/cam/cam.sh ingest . --dry-run  # Preview first
./.claude/cam/cam.sh ingest .            # Then ingest

# Ingest specific directory with type
./.claude/cam/cam.sh ingest .ai/ docs
./.claude/cam/cam.sh ingest src/ code

# Check what needs updating
./.claude/cam/cam.sh scan .
```

### Smart CAM Triggering (Automatic)

Claude automatically consults CAM at decision points through hooks:

**SessionStart Hook (Once Per Session)**
- Validates CAM database
- Loads recent context from past work
- Queries for session patterns (what was worked on recently?)
- Cost: 1-2 seconds (one-time at session start)
- Context: ~20 tokens added to session memory

**PreToolUse Hook (Intelligent Filtering)**
- Queries CAM only at high-value decision points
- **Edit/Write operations**: Always query (code changes benefit from patterns)
- **Bash operations**: Query only if architectural (contains keywords: migrate, refactor, deploy, etc.)
- **Read/Glob/Grep**: Skip (information gathering, not decision-making)
- Results cached for 30 minutes to avoid redundant queries
- Cost per decision: ~500ms (first time), ~0ms (cached)
- Context: ~10-15 tokens per decision point

**Caching Layer**
- CAM query results cached locally for 30 minutes
- Same patterns queried multiple times return instantly from cache
- Prevents latency accumulation across session
- Old cache automatically cleaned up

**Performance Expectations**
- Session start: +1-2 seconds (one-time)
- Per code change: +500ms (first query), then cached
- Total context bloat: ~15-20 tokens per session
- Multiple edits: First triggers CAM, subsequent uses cache (instant)

**PostToolUse Auto-Ingest (v1.5.0)**
- When you Edit/Write a file, CAM automatically ingests the new content
- Smart change detection: Only re-ingests if file content actually changed
- Supports code, docs, and config files (auto-detected by extension)
- Skips large files (>100KB), lock files, and node_modules
- Keeps CAM's semantic index synchronized with codebase changes

### Advanced Features (v2.0+)

Query DSL and CMR are power-user features NOT automated in hooks. Use them proactively:

**Query DSL (When complex search is needed):**
```bash
# Structured TOML query with constraints
./.claude/cam/cam.sh query-dsl '[query]
text = "authentication"
min_tier = "high"
[constraints]
type = "code"'

# Query with graph expansion
./.claude/cam/cam.sh query-graph "error handling" 5 2

# Multi-hop reasoning
./.claude/cam/cam.sh multi-hop "what caused bug" "how was it fixed" --strategy chain
```

**CMR - Contextual Memory Reweaving (When context is large or after compaction):**
```bash
# Detect important inflection points
./.claude/cam/cam.sh inflection-points

# Generate reconstruction context after /compact
./.claude/cam/cam.sh reconstruction-context "current task" 2000

# Context-aware retrieval
./.claude/cam/cam.sh adaptive-retrieve "debugging auth" debugging

# Full CMR pipeline (combines all above)
./.claude/cam/cam.sh reweave "implementing feature X"
```

**When to Use:**
- `query-dsl`: Complex searches needing filters, constraints, or graph traversal
- `query-graph`: When related context matters (follow relationships)
- `multi-hop`: Multi-step questions ("what caused X then how was Y fixed")
- `reweave`: After compaction or when context seems disconnected
- `adaptive-retrieve`: Debugging (prioritizes recent/causal) vs architecture (prioritizes decisions)

### Proactive CAM Usage (Manual Consultation)

In addition to automatic hooks, Claude can proactively consult CAM during reasoning:

**When Making Decisions:**
- Query CAM before architectural decisions:
  ```bash
  ./.claude/cam/cam.sh query "similar architectural patterns"
  ```
- Reference historical solutions before bug fixes:
  ```bash
  ./.claude/cam/cam.sh query "similar bug fixes"
  ```
- Search for patterns before implementing features:
  ```bash
  ./.claude/cam/cam.sh query "feature implementation patterns"
  ```

**During Reasoning:**
- Explicitly cite CAM findings: "Based on CAM context, this pattern was used before..."
- Note where approach differs from CAM: "Diverging from CAM pattern because..."
- Use confidence scores: "This approach scored 0.87 in CAM retrieval"

**When Uncertain:**
- Query CAM first before deciding
- Use top results to inform implementation choices
- Document decisions that contradict CAM patterns

**Integration Points:**
- Use CAM context when refactoring existing code
- Consult CAM when modifying infrastructure (hooks, scripts, core)
- Reference CAM when adding new features to existing systems

### Cache Management

Clear CAM cache manually:
```bash
# Remove cache entries older than 30 minutes
~/.claude/hooks/cam-cache-clean.sh

# Force clear all cache
~/.claude/hooks/cam-cache-clean.sh clean-all
```

Cache is stored in: `~/.claude/.cam-cache/`
Session context cache: `~/.claude/.session-cam-context`

## Project Policies

### Changelog

Before modifying CAM infrastructure, append changes to project root `CHANGELOG.md`:
- `~/.claude/CLAUDE.md` (protocol)
- `~/.claude/hooks/*.sh` (hooks)
- `~/.claude/cam-template/cam_core.py` / `~/.claude/cam-template/cam.sh` (core)
- `~/.claude/cam-template/settings-hooks.json` (hooks settings)

**Location**: `/CHANGELOG.md` (project root, not cam-template)

### Version Management (v2.0+)

**Simple Rule: Any code change = patch increment.**

```
2.0.0 → 2.0.1 → 2.0.2 → 2.0.3 → ...
```

**When modifying any CAM code** (hooks, cam_core.py, cam.sh):

1. Increment patch version (e.g., 2.0.0 → 2.0.1)

2. Update ALL of these files:
   - `~/.claude/cam-template/VERSION.txt`
   - `/release/cam-template/VERSION.txt`
   - `cam_core.py` line 26: `CAM_VERSION = "x.y.z"`
   - Modified hook(s): `# Version: x.y.z` header

3. Deploy changes:
   ```bash
   ~/.claude/hooks/cam-sync-template.sh
   ```

**Does NOT require version bump**: README.md, CHANGELOG.md, documentation-only changes.

See [VERSIONING.md](~/.claude/cam-template/VERSIONING.md) for full policy.

### Documentation

- **Source of truth**: `.ai/` directory
- **Single location**: Each fact in ONE place
- **Cross-reference**: Never duplicate

---

## Completion Protocol

When work is complete, **always** finish with:

1. **Commit** changes with descriptive message (conventional commits)
2. **Push** to remote branch
3. **Create PR** with summary and test plan
4. **Report** PR URL to user

**Do NOT wait for permission**—PRs are the expected output of completed work in this project. Skipping the PR step is a protocol violation.

```bash
# Expected flow
git add <files>
git commit -m "feat/fix/chore: description"
git push origin <branch>
gh pr create --title "..." --body "..."
```

---

## Agent Orchestration

### Orchestrator Agent

For complex, multi-step tasks, invoke the **orchestrator** agent to coordinate work across specialized agents:

```bash
# The orchestrator analyzes your request and delegates to:
# - Explore agents (fast codebase discovery)
# - Plan agents (implementation strategy)
# - general-purpose agents (implementation work)
```

**When to Use Orchestrator**:
- Tasks requiring research → planning → implementation flow
- Multi-file changes that benefit from parallel exploration
- Complex debugging requiring systematic investigation
- Architectural decisions needing comprehensive analysis

**Invocation**:
```
Task(subagent_type="orchestrator", prompt="Your complex task")
```

The orchestrator inherits CAM awareness through this environment—no explicit CAM configuration needed in delegation prompts.

### Available Agent Types

| Agent | Speed | Use For |
|-------|-------|---------|
| `Explore` | Fast | File search, codebase discovery, pattern matching |
| `Plan` | Medium | Implementation strategy, architectural planning |
| `general-purpose` | Medium | Multi-step implementation, complex coding |
| `orchestrator` | Varies | Coordinating multiple agents for complex tasks |

---

*Claude reads `.ai/` for context. CAM indexes `.ai/` for semantic queries.*

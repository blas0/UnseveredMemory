# CAM Changelog

All notable changes to CAM (Continuous Architectural Memory) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2025-12-09

### Major Release - Memory, Query, Architectural, Decision, Weight Improvements

This release consolidates the CAM Evolution Framework into a unified v2.0 release.

#### Core Capabilities
- Semantic embedding storage with Gemini
- Knowledge graph with temporal, semantic, and causal relationships
- Claude Code hook integration (automatic context injection)

#### Intelligence Layer
- **Importance Tiers** - Weighted retrieval (critical/high/normal/reference)
- **Decision Store** - Structured architectural decision records
- **Invariant Management** - Enforced architectural constraints
- **Causal Tracking** - Bug → root cause → fix chains

#### Query DSL
- **TOML Queries** - Structured search with constraints
- **Graph Expansion** - Automatic relationship traversal
- **Multi-Hop Reasoning** - Chained/parallel query strategies

#### Memory Management (CMR)
- **Inflection Detection** - Find pivotal moments
- **Smart Compression** - Preserve-aware memory management
- **Reconstruction** - Post-compaction context recovery
- **Adaptive Retrieval** - Task-aware search strategies

#### Hook System Enhancements
- **UserPromptSubmit** - Importance-weighted queries + invariant injection
- **PostToolUse** - Auto decision capture + causal link tracking
- **PreCompact** - Critical decision preservation + invariant snapshot
- **SessionEnd** - Decision aggregation + causal chain cleanup

#### PR Workflow (v2.0.1)
- **session-end-with-pr.sh** - Creates PRs instead of auto-commits
- Automatic session branch creation (`session/<id>-<timestamp>`)
- Conventional Commits message generation
- Removed `Co-Authored-By: Claude` footer

#### Auto-Migration
- **Backward Compatible** - Existing CAM databases automatically upgrade on first v2.0 run
- Schema changes applied via `_ensure_tables()` in cam_core.py:
  - Adds `importance_tier` column to `embeddings` table if missing
  - Creates `decisions` table if missing
  - Creates `invariants` table if missing
- No manual migration required — just run `./cam.sh upgrade --force` or any CAM command
- Existing data preserved with default values (`importance_tier='normal'`)

### New CLI Commands

**Data Model:**
```bash
# Importance Tiers
set-importance <id> <tier>           # Set importance (critical|high|normal|reference)
list-important <tier> [limit]        # List by tier
query-important "<query>" [tier] [k] # Importance-weighted search

# Decisions
store-decision "<title>" "<rationale>" [--tier T] [--type T]
get-decision <id>
list-decisions [--tier T] [--limit N]

# Invariants
store-invariant <category> "<statement>" [--enforcement E]
list-invariants [--category C]

# Causal Links
link-causal <source> <target> [reason]
trace-causality <id> [depth]
get-related <id>
```

**Query DSL:**
```bash
query-dsl '<toml>'                    # TOML-based structured query
query-graph '<text>' [top_k] [depth]  # Query with graph expansion
multi-hop '<q1>' '<q2>' [--strategy]  # Chained/parallel queries
get-embedding <id>                    # Retrieve by ID
```

**CMR:**
```bash
inflection-points                     # Detect significant moments
compress-memory [max_embeddings]      # Preserve-aware compression
reconstruction-context [task] [tokens] # Post-compaction summary
adaptive-retrieve '<query>' [type]    # Context-aware retrieval
reweave '<current_task>'              # Full CMR pipeline
```

### Migration

To upgrade from v1.x:
```bash
./cam.sh upgrade --force
```

To enable PR workflow:
1. Edit `~/.claude/settings.json`
2. Change SessionEnd hook command to `session-end-with-pr.sh`
3. Ensure `gh` CLI is authenticated (`gh auth login`)

---

## [1.7.x] - 2025-12-08

### Automatic Context Crystallization
- PreCompact hook for session preservation before compaction
- Stop hook for proactive `/compact` suggestions
- Session state system for cross-hook communication
- Primer system for post-compact recovery

### Ralph Wiggum Integration (v1.6.0)
- Ralph data types and CAM storage
- Pattern matching for similar tasks
- Cross-loop learning

### Session Memory System (v1.5.2)
- Session retrieval commands
- Metadata type filtering
- Structured session summaries

### Smart Auto-Ingest (v1.5.0)
- File index database with change detection
- Directory ingestion support
- PostToolUse auto-ingest

### Automatic Relationships (v1.4.0)
- Graph building at session end
- Cross-reference detection in markdown
- Modifies relationships for .ai/ edits

---

## [1.0.0 - 1.3.0] - 2025-11-18 to 2025-12-04

### Core Infrastructure
- CAM class with embedding, query, annotate methods
- Vector, metadata, and graph databases
- CLI wrapper with version management
- Hook system integration

### Evaluation Framework (v1.2.0)
- STS correlation, precision/recall, graph coherence
- DMR and LoCoMo benchmarks

### Graph Building (v1.1.0)
- Hierarchical clustering
- Temporal, semantic, causal relationships

---

## Upgrade Instructions

```bash
# Check current version
./cam.sh version

# Upgrade to latest
./cam.sh upgrade

# Force reinstall
./cam.sh upgrade --force
```

---

**Maintained by**: Claude Code + Human collaboration
**Template location**: `~/.claude/cam-template/`

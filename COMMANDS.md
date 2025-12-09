# CAM Commands

Complete command reference for CAM (Continuous Architectural Memory).

---

## Core Commands

```bash
# Show CAM version
./cam.sh version
```

```bash
# Show CAM statistics (embedding count, database sizes, graph metrics)
./cam.sh stats
```

```bash
# Upgrade CAM from global template (~/.claude/cam-template/)
./cam.sh upgrade

# Force upgrade even if versions match
./cam.sh upgrade --force
```

---

## Semantic Search

```bash
# Query CAM with semantic search
# Returns top 5 results by default, ranked by cosine similarity
./cam.sh query "<search_text>"

# Parameters:
#   <search_text>  - Natural language query describing your intent
#   [top_k]        - Optional: Number of results to return (default: 5)

# Examples:
./cam.sh query "authentication patterns"
./cam.sh query "how does the API handle errors" 10
./cam.sh query "database schema" --type docs
```

```bash
# Retrieve full embedding content by ID
# Use after query to get complete content of a result
./cam.sh get <embedding_id>

# Parameters:
#   <embedding_id>  - 16-character hex ID from query results

# Example:
./cam.sh get 572ff1840d0f0a99
```

---

## Notes & Annotations

```bash
# Add an ephemeral note to CAM
# Notes are embedded and searchable like any other content
./cam.sh note "<title>" "<content>" [tags]

# Parameters:
#   <title>    - Short descriptive title
#   <content>  - Note content (can be multi-line)
#   [tags]     - Optional: Comma-separated tags for categorization

# Examples:
./cam.sh note "Bug Fix" "Fixed authentication timeout issue"
./cam.sh note "Architecture Decision" "Chose PostgreSQL over MongoDB" "decision,database"
./cam.sh note "TODO" "Refactor user service" "todo,refactor,user"
```

```bash
# Add manual annotation to an existing embedding
./cam.sh annotate "<content>"

# Parameters:
#   <content>  - Annotation text to add
```

---

## File Ingestion

```bash
# Ingest file or directory into CAM
# Automatically detects file type and creates embeddings
./cam.sh ingest <path> [type] [flags]

# Parameters:
#   <path>      - File or directory path to ingest
#   [type]      - Optional: Force type (code, docs, config)
#   [--force]   - Re-ingest even if file unchanged
#   [--dry-run] - Preview what would be ingested without doing it

# Examples:
./cam.sh ingest src/                     # Ingest source directory (auto-detect)
./cam.sh ingest .ai/ docs                # Ingest as documentation
./cam.sh ingest config.yaml config       # Ingest as config
./cam.sh ingest . --dry-run              # Preview full project ingestion
./cam.sh ingest src/ --force             # Force re-ingest all files
```

```bash
# Scan directory for new or modified files
# Reports status without ingesting
./cam.sh scan <directory>

# Parameters:
#   <directory>  - Directory path to scan

# Example:
./cam.sh scan .
./cam.sh scan src/
```

```bash
# Check single file status in CAM index
# Shows if file is new, modified, or unchanged
./cam.sh check-file <path>

# Parameters:
#   <path>  - File path to check

# Example:
./cam.sh check-file src/main.py
```

```bash
# Show file index statistics
# Displays counts by type, total size, last ingestion times
./cam.sh file-stats
```

---

## Knowledge Graph

```bash
# Build knowledge graph from embeddings
# Discovers temporal, semantic, and causal relationships
./cam.sh graph build

# Rebuild graph from scratch (clears existing)
./cam.sh graph build --rebuild
```

```bash
# Show graph statistics
# Displays node count, edge count, relationship types
./cam.sh graph stats
```

```bash
# Create manual relationship between embeddings
./cam.sh relate <source_id> <target_id> <type> [weight]

# Parameters:
#   <source_id>   - Source embedding ID
#   <target_id>   - Target embedding ID
#   <type>        - Relationship type (temporal, semantic, causal, modifies, references)
#   [weight]      - Optional: Relationship strength 0.0-1.0 (default: 1.0)

# Example:
./cam.sh relate abc123 def456 references 0.8
```

```bash
# Find embedding ID by source file path
# Useful for creating relationships to documents
./cam.sh find-doc <file_path>

# Parameters:
#   <file_path>  - Path to source file

# Example:
./cam.sh find-doc ".ai/patterns/api-routing.md"
```

---

## Importance Tiers (v1.8.0+)

```bash
# Set importance tier for an embedding
# Controls preservation priority during compaction
./cam.sh set-importance <embedding_id> <tier>

# Parameters:
#   <embedding_id>  - ID of the embedding to modify
#   <tier>          - critical | high | normal | reference

# Tier weights (applied to query scores):
#   critical:  4.0x multiplier (never compacted)
#   high:      2.0x multiplier (preserved during compaction)
#   normal:    1.0x multiplier (default, may be compacted)
#   reference: 0.5x multiplier (de-prioritized, first to compact)

# Example:
./cam.sh set-importance abc123def456 critical
```

```bash
# List embeddings by importance tier
./cam.sh list-important <tier> [limit]

# Parameters:
#   <tier>   - critical | high | normal | reference
#   [limit]  - Optional: Max results (default: 10)

# Example:
./cam.sh list-important critical 20
```

```bash
# Query with importance-weighted scoring
# Results boosted by their importance tier
./cam.sh query-important "<search_text>" [min_tier] [top_k]

# Parameters:
#   <search_text>  - Natural language query
#   [min_tier]     - Optional: Minimum tier filter (default: normal)
#   [top_k]        - Optional: Number of results (default: 5)

# Example:
./cam.sh query-important "authentication patterns" high 10
```

---

## Decision Store (v1.8.0+)

```bash
# Store architectural decision with context
# Preserves rationale, alternatives, and constraints
./cam.sh store-decision "<title>" "<rationale>" [flags]

# Parameters:
#   <title>      - Decision title (e.g., "Why we chose PostgreSQL")
#   <rationale>  - Multi-paragraph explanation

# Flags:
#   --tier <T>   - Importance: critical | high | normal | reference
#   --type <T>   - Category: architecture | technical | process

# Example:
./cam.sh store-decision "Database Selection" "Chose PostgreSQL for ACID compliance and JSON support" --tier critical --type architecture
```

```bash
# Retrieve decision by ID
./cam.sh get-decision <decision_id>

# Parameters:
#   <decision_id>  - 16-character decision ID

# Example:
./cam.sh get-decision 8bb59f33a55efd3c
```

```bash
# List decisions by tier or recent
./cam.sh list-decisions [flags]

# Flags:
#   --tier <T>   - Filter by importance tier
#   --limit <N>  - Max results (default: 10)

# Examples:
./cam.sh list-decisions                    # Recent decisions
./cam.sh list-decisions --tier critical    # Critical decisions only
./cam.sh list-decisions --limit 20         # More results
```

---

## Invariants (v1.8.0+)

```bash
# Store architectural invariant (constraint)
# Defines rules that must be maintained across the codebase
./cam.sh store-invariant <category> "<statement>" [flags]

# Parameters:
#   <category>   - security | performance | architecture | business
#   <statement>  - The constraint (e.g., "All APIs must validate input")

# Flags:
#   --enforcement <E>  - required | preferred | guideline (default: required)
#   --rationale <R>    - Why this invariant exists

# Example:
./cam.sh store-invariant security "All user input must be sanitized" --enforcement required
./cam.sh store-invariant performance "API response time < 200ms" --enforcement preferred
```

```bash
# List invariants by category or all required
./cam.sh list-invariants [flags]

# Flags:
#   --category <C>  - Filter by category

# Examples:
./cam.sh list-invariants                        # All required invariants
./cam.sh list-invariants --category security    # Security invariants only
```

---

## Causal Relationships (v1.8.0+)

```bash
# Create causal link between embeddings
# Tracks bug → root cause → fix → rationale chains
./cam.sh link-causal <source_id> <target_id> [reason]

# Parameters:
#   <source_id>   - Source embedding ID
#   <target_id>   - Target embedding ID (caused by source)
#   [reason]      - Optional: Explanation of causal link

# Example:
./cam.sh link-causal abc123 def456 "Bug caused by missing null check"
```

```bash
# Trace causal chain from embedding
# Walks the causal graph to discover related context
./cam.sh trace-causality <embedding_id> [max_depth]

# Parameters:
#   <embedding_id>  - Starting embedding ID
#   [max_depth]     - Optional: Max traversal depth (default: 5)

# Example:
./cam.sh trace-causality abc123 3
```

```bash
# Get all causally related embeddings
# Returns embeddings with causal, temporal, or semantic relationships
./cam.sh get-related <embedding_id>

# Parameters:
#   <embedding_id>  - Embedding to find relations for

# Example:
./cam.sh get-related abc123
```

---

## Query DSL (v2.0.0+)

```bash
# Execute TOML-based structured query
# Supports text search, constraints, and graph traversal
./cam.sh query-dsl '<toml_query>'

# TOML Format:
# [query]
# text = "search text"
# min_tier = "high"          # Filter by importance
# top_k = 10
#
# [constraints]
# type = "code"              # code | docs | operation
# category = "security"
# tags = ["auth", "api"]
# after = "2025-01-01"
#
# [graph]
# traverse = true
# max_depth = 3
# relationship_types = ["causal", "semantic"]

# Example:
./cam.sh query-dsl '[query]
text = "authentication patterns"
min_tier = "high"
[constraints]
type = "code"'
```

```bash
# Query with automatic graph expansion
# Traverses knowledge graph to find related context
./cam.sh query-graph "<search_text>" [top_k] [max_depth]

# Parameters:
#   <search_text>  - Natural language query
#   [top_k]        - Number of initial results (default: 5)
#   [max_depth]    - Graph traversal depth (default: 2)

# Example:
./cam.sh query-graph "error handling" 5 3
```

```bash
# Multi-hop reasoning across multiple queries
# Chain: each query informed by previous results
# Parallel: independent queries merged at end
./cam.sh multi-hop "<q1>" "<q2>" [--strategy chain|parallel]

# Parameters:
#   <q1>, <q2>...  - Questions to chain or run in parallel
#   [--strategy]   - chain (default) or parallel

# Examples:
./cam.sh multi-hop "what caused the auth bug" "how was it fixed" --strategy chain
./cam.sh multi-hop "auth patterns" "error handling" "logging" --strategy parallel
```

```bash
# Retrieve single embedding by ID
./cam.sh get-embedding <embedding_id>

# Parameters:
#   <embedding_id>  - 16-character hex ID

# Example:
./cam.sh get-embedding abc123def456789
```

---

## CMR - Contextual Memory Reweaving (v2.0.0+)

```bash
# Detect significant inflection points in session history
# Identifies critical decisions, causal chain starts, high-importance embeddings
./cam.sh inflection-points

# Output: JSON array of inflection points with scores and reasons
```

```bash
# Compress memory while preserving critical information
# Soft-delete strategy: downgrades to reference tier instead of deleting
./cam.sh compress-memory [max_embeddings]

# Parameters:
#   [max_embeddings]  - Target maximum count (default: 1000)

# Preserves:
#   - Critical tier embeddings
#   - High tier embeddings
#   - Active causal chain participants
#   - Recent embeddings (last 7 days)

# Example:
./cam.sh compress-memory 500
```

```bash
# Generate post-compaction reconstruction context
# Creates prose summary suitable for context injection
./cam.sh reconstruction-context [task_hint] [max_tokens]

# Parameters:
#   [task_hint]    - Current task for relevance filtering
#   [max_tokens]   - Max output size (default: 2000)

# Example:
./cam.sh reconstruction-context "implementing user auth" 1500
```

```bash
# Context-aware adaptive retrieval
# Different strategies for different task types
./cam.sh adaptive-retrieve "<query>" [context_type]

# Parameters:
#   <query>         - Search query
#   [context_type]  - general | debugging | architecture | implementation

# Context type behaviors:
#   general:        Balanced retrieval
#   debugging:      Prioritizes recent, causal chains, error-related
#   architecture:   Prioritizes decisions, invariants, high-tier
#   implementation: Prioritizes code patterns, recent changes

# Example:
./cam.sh adaptive-retrieve "null pointer exception" debugging
./cam.sh adaptive-retrieve "API design patterns" architecture
```

```bash
# Full CMR pipeline - combines all above
# Detect, compress if needed, reconstruct, retrieve
./cam.sh reweave "<current_task>"

# Parameters:
#   <current_task>  - Description of what you're working on

# Returns:
#   - memory_stats: Current state
#   - inflection_points: Significant moments
#   - reconstruction_context: Prose summary
#   - relevant_context: Task-relevant results

# Example:
./cam.sh reweave "debugging authentication timeout issue"
```

---

## Session Management

```bash
# Show active session primers
# Displays primers cached for post-compact recovery
./cam.sh primer-status
```

```bash
# List recent sessions with metadata
./cam.sh sessions [--limit N]

# Parameters:
#   [--limit N]  - Optional: Number of sessions to show (default: 10)
```

```bash
# Get most recent session summary
./cam.sh last-session
```

```bash
# Get specific session details by ID
./cam.sh session <session_id>

# Parameters:
#   <session_id>  - Full or partial session ID
```

---

## Ralph Wiggum Integration

```bash
# List recent Ralph loops
./cam.sh ralph-loops [flags]

# Flags:
#   [--limit N]       - Number of loops to show (default: 10)
#   [--successful]    - Only show successful loops
#   [--outcome TYPE]  - Filter by outcome (success, max_iterations, cancelled)

# Examples:
./cam.sh ralph-loops
./cam.sh ralph-loops --successful
./cam.sh ralph-loops --limit 5 --outcome max_iterations
```

```bash
# View iteration history for a specific loop
./cam.sh ralph-history <loop_id>

# Parameters:
#   <loop_id>  - Ralph loop ID from ralph-loops output
```

```bash
# Find patterns from similar past tasks
# Searches CAM for loops with similar prompts
./cam.sh ralph-patterns "<task_description>"

# Parameters:
#   <task_description>  - Description of current task

# Example:
./cam.sh ralph-patterns "Build REST API for user management"
```

---

## Evaluation & Benchmarks

```bash
# Run evaluation suite
./cam.sh eval <type>

# Types:
#   embeddings  - STS correlation test (Pearson/Spearman)
#   retrieval   - Precision/Recall/nDCG metrics
#   graph       - Edge coherence, temporal consistency
#   extrinsic   - Operational utility analysis
#   all         - Run all intrinsic evaluations

# Example:
./cam.sh eval all
```

```bash
# Run benchmarks
./cam.sh benchmark <type>

# Types:
#   dmr    - Deep Memory Retrieval benchmark
#   locomo - Long-Context Memory benchmark
#   all    - Run all benchmarks
```

---

## Troubleshooting

```bash
# Verify hooks are registered in settings
cat ~/.claude/settings.json | jq '.hooks | keys'
```

```bash
# Check specific hook configuration
cat ~/.claude/settings.json | jq '.hooks.SessionStart'
```

```bash
# Verify Gemini API key is configured
cat ~/.claude/hooks/.env | grep GEMINI_API_KEY
```

```bash
# Test Gemini API connection
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$(grep GEMINI_API_KEY ~/.claude/hooks/.env | cut -d= -f2)"
```

```bash
# Initialize CAM in current project
~/.claude/hooks/init-cam.sh
```

```bash
# Verify CAM installation
ls -la .claude/cam/
```

```bash
# Check CAM version matches template
./cam.sh version
cat ~/.claude/cam-template/VERSION.txt
```

---

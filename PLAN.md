# UnseveredMemory Improvement Plan

> Research-backed improvements for UnseveredMemory that stay native to Claude Code's architecture

## Research Summary

This plan synthesizes findings from:
- [Anthropic's Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude's Memory Tool Documentation](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)
- [A-Mem: Agentic Memory for LLM Agents](https://arxiv.org/abs/2502.12110) (NeurIPS 2025)
- [Anthropic's Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Claude Context Management](https://claude.com/blog/context-management)

### Key Insight

Anthropic's research shows:
- **Memory + Context Editing = 39% performance improvement**
- **Multi-agent with Opus orchestrator + Sonnet workers = 90% improvement over single-agent**
- **"Context is a precious, finite resource"** - smaller, high-signal tokens outperform large context dumps

---

## Improvement Categories

### Category A: Hook System Enhancements
*Leverage underutilized Claude Code hooks*

### Category B: Memory Architecture
*Apply academic research (A-Mem, Zettelkasten) using native markdown*

### Category C: Context Engineering
*Implement Anthropic's best practices for token efficiency*

### Category D: Multi-Agent Integration
*Enhance orchestrator with memory-aware coordination*

---

## Category A: Hook System Enhancements

### A1. PreCompact Hook Integration

**Problem**: Context compaction summarizes conversations, losing critical details. Currently no intervention before this happens.

**Solution**: Add `PreCompact` hook to capture context state before compaction.

**Implementation**:
```bash
# hooks/memory-precompact.sh
#!/bin/bash
# Extract and preserve critical context before compaction

PROJECT_ROOT="$(pwd)"
MEMORY_DIR="$PROJECT_ROOT/.claude/memory"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")

# Create compaction checkpoint
cat >> "$MEMORY_DIR/checkpoints/${TIMESTAMP}.md" << EOF
# Compaction Checkpoint
Time: $(date)
Trigger: ${COMPACTION_TYPE:-auto}

## Active Task
$(grep -A5 "## Current Task" "$MEMORY_DIR/context.md" 2>/dev/null)

## Recent Decisions
$(tail -20 "$MEMORY_DIR/scratchpad.md" 2>/dev/null)

## Files Modified This Session
$(git diff --name-only HEAD 2>/dev/null | head -10)
EOF

echo "[Memory] Checkpoint saved before compaction"
```

**hooks.json addition**:
```json
{
  "PreCompact": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "bash ~/.claude/hooks/memory-precompact.sh"
    }]
  }]
}
```

**Complexity**: Low
**Impact**: High - Prevents context loss during long sessions

---

### A2. PostToolUse Hook for Memory Updates

**Problem**: Significant operations (file writes, git commits) should trigger memory updates but currently rely on Claude remembering.

**Solution**: Add `PostToolUse` hook that logs significant tool operations to scratchpad.

**Implementation**:
```bash
# hooks/memory-post-tool.sh
#!/bin/bash
# Auto-log significant tool operations

TOOL_NAME="$1"
TOOL_INPUT="$2"
SCRATCHPAD=".claude/memory/scratchpad.md"

case "$TOOL_NAME" in
  Write|Edit)
    echo "- [$(date +%H:%M)] Modified: $(echo $TOOL_INPUT | jq -r '.file_path' 2>/dev/null)" >> "$SCRATCHPAD"
    ;;
  Bash)
    CMD=$(echo $TOOL_INPUT | jq -r '.command' 2>/dev/null | head -c 50)
    echo "- [$(date +%H:%M)] Ran: $CMD..." >> "$SCRATCHPAD"
    ;;
esac
```

**Complexity**: Medium
**Impact**: Medium - Reduces manual logging burden

---

### A3. SubagentStop Hook for Memory Synthesis

**Problem**: Subagent results are lost after context compaction. No mechanism to preserve subagent findings.

**Solution**: Add `SubagentStop` hook to extract and store subagent conclusions.

**Implementation**:
```bash
# hooks/memory-subagent.sh
#!/bin/bash
# Capture subagent results for cross-session persistence

SUBAGENT_TYPE="$1"
SUBAGENT_RESULT="$2"
MEMORY_DIR=".claude/memory"

# Append to subagent findings log
cat >> "$MEMORY_DIR/subagent-findings.md" << EOF

---
## $(date +"%Y-%m-%d %H:%M") - $SUBAGENT_TYPE
$SUBAGENT_RESULT
EOF
```

**Complexity**: Low
**Impact**: High - Preserves multi-agent coordination state

---

## Category B: Memory Architecture

### B1. Zettelkasten-Inspired Memory Linking

**Research Basis**: A-Mem (NeurIPS 2025) shows 26% improvement with interconnected memory networks over flat storage.

**Problem**: Current memories are isolated files with no cross-referencing.

**Solution**: Implement bidirectional linking between related memories using markdown conventions.

**Implementation**:

1. **Memory Note Format**:
```markdown
# memory-2025-01-02-auth-refactor.md

## Keywords
authentication, JWT, security, login

## Links
- [[decisions#2025-12-15-jwt-choice]] - Why we chose JWT
- [[context#auth-system]] - Current auth state
- [[patterns/error-handling]] - Related pattern

## Content
Refactored authentication to use refresh tokens...

## Backlinks
(auto-generated by indexer)
```

2. **Link Indexer Script**:
```bash
# scripts/memory-index.sh
#!/bin/bash
# Build backlink index from memory files

MEMORY_DIR=".claude/memory"
INDEX_FILE="$MEMORY_DIR/.index.json"

# Extract all [[links]] and build reverse index
find "$MEMORY_DIR" -name "*.md" -exec grep -l '\[\[' {} \; | while read file; do
  grep -oP '\[\[([^\]]+)\]\]' "$file" | while read link; do
    # Add to index
    echo "{\"from\": \"$file\", \"to\": \"$link\"}"
  done
done | jq -s 'group_by(.to) | map({key: .[0].to, backlinks: [.[].from]}) | from_entries' > "$INDEX_FILE"
```

3. **SessionStart Enhancement**:
```bash
# In memory-load.sh, add:
if [ -f "$MEMORY_DIR/.index.json" ]; then
  RELATED=$(jq -r '.["'"$CURRENT_TASK"'"] // empty' "$MEMORY_DIR/.index.json")
  [ -n "$RELATED" ] && echo "Related memories: $RELATED"
fi
```

**Complexity**: Medium
**Impact**: High - Creates knowledge network instead of isolated notes

---

### B2. Hierarchical Memory Compression

**Research Basis**: Anthropic recommends "iterative curation - refining data each turn to maximize signal."

**Problem**: Daily sessions accumulate. Over time, `sessions/` becomes a graveyard of unconnected logs.

**Solution**: Implement 3-tier memory hierarchy with automatic summarization.

**Architecture**:
```
.claude/memory/
├── context.md          # Tier 1: Current (updated each session)
├── scratchpad.md       # Working memory
├── weekly/
│   └── 2025-W01.md     # Tier 2: Weekly summaries (auto-generated)
├── monthly/
│   └── 2025-01.md      # Tier 3: Monthly digests (auto-generated)
└── sessions/
    └── 2025-01-02.md   # Raw daily logs
```

**Weekly Summary Generation** (SessionEnd hook addition):
```bash
# Check if end of week
if [ "$(date +%u)" = "7" ]; then
  WEEK=$(date +%Y-W%V)
  WEEK_FILE="$MEMORY_DIR/weekly/$WEEK.md"

  # Compile this week's sessions
  echo "# Week $WEEK Summary" > "$WEEK_FILE"
  echo "" >> "$WEEK_FILE"
  echo "## Key Accomplishments" >> "$WEEK_FILE"

  # Extract key points from daily sessions
  for day in "$MEMORY_DIR/sessions/$(date -v-6d +%Y-%m-%d)"*.md; do
    [ -f "$day" ] && grep -E "^##|^- " "$day" >> "$WEEK_FILE"
  done
fi
```

**Complexity**: Medium
**Impact**: High - Prevents memory bloat while preserving important history

---

### B3. Semantic Tagging System

**Problem**: Finding relevant memories requires knowing exact file names or content.

**Solution**: Auto-extract and maintain a tag index for semantic retrieval.

**Implementation**:

1. **Tag Extraction** (UserPromptSubmit hook addition):
```bash
# Extract tags from recent scratchpad entries
TAGS=$(grep -oP '#\w+' "$MEMORY_DIR/scratchpad.md" | sort -u | tr '\n' ' ')
[ -n "$TAGS" ] && echo "Active tags: $TAGS"
```

2. **Tag Index** (`.claude/memory/.tags.json`):
```json
{
  "authentication": ["sessions/2025-01-02.md", "decisions.md#jwt"],
  "performance": ["sessions/2025-01-01.md", "patterns/caching.md"],
  "refactor": ["weekly/2025-W01.md"]
}
```

3. **SessionStart Tag Display**:
```bash
# Show tags relevant to current task
TASK_KEYWORDS=$(echo "$CURRENT_TASK" | tr ' ' '\n' | grep -v '^$')
for kw in $TASK_KEYWORDS; do
  MATCHES=$(jq -r ".\"$kw\" // empty" "$MEMORY_DIR/.tags.json" 2>/dev/null)
  [ -n "$MATCHES" ] && echo "Related to '$kw': $MATCHES"
done
```

**Complexity**: Low
**Impact**: Medium - Improves memory discoverability

---

## Category C: Context Engineering

### C1. Token-Efficient Memory Injection

**Research Basis**: Anthropic's context engineering emphasizes "the smallest set of high-signal tokens."

**Problem**: Current SessionStart loads full `context.md` which may contain stale information.

**Solution**: Implement tiered loading based on relevance scoring.

**Implementation**:

1. **Relevance Scoring**:
```bash
# hooks/memory-load.sh enhancement
# Only inject sections relevant to detected task type

detect_task_type() {
  # Simple keyword detection from recent prompt
  if echo "$RECENT_PROMPT" | grep -qiE 'bug|fix|error'; then
    echo "debugging"
  elif echo "$RECENT_PROMPT" | grep -qiE 'add|create|implement|feature'; then
    echo "implementation"
  elif echo "$RECENT_PROMPT" | grep -qiE 'refactor|clean|improve'; then
    echo "refactoring"
  else
    echo "general"
  fi
}

TASK_TYPE=$(detect_task_type)

case "$TASK_TYPE" in
  debugging)
    # Load recent errors, related files
    inject_section "## Recent Issues"
    inject_section "## Test Results"
    ;;
  implementation)
    # Load architecture, patterns
    inject_section "## Architecture"
    inject_section "## Patterns"
    ;;
  *)
    # Load general context
    inject_section "## Current State"
    ;;
esac
```

**Complexity**: Medium
**Impact**: High - Reduces token waste, improves relevance

---

### C2. Just-In-Time Context Retrieval

**Research Basis**: Anthropic recommends "maintain lightweight identifiers and dynamically load data at runtime."

**Problem**: Loading all memory upfront wastes context window on potentially irrelevant information.

**Solution**: Inject memory pointers instead of full content; Claude loads as needed.

**Implementation**:

1. **Memory Manifest** (generated by SessionEnd):
```markdown
# .claude/memory/MANIFEST.md

## Available Memory Files

| File | Keywords | Last Updated | Size |
|------|----------|--------------|------|
| context.md | state, task, next | 2025-01-02 | 1.2KB |
| decisions.md | jwt, auth, api | 2025-01-01 | 3.4KB |
| patterns/error-handling.md | errors, try-catch | 2024-12-28 | 0.8KB |

## Quick Access
- Current task: `context.md#current-task`
- Recent decisions: `decisions.md` (last 5)
- Unfinished work: `scratchpad.md`
```

2. **SessionStart Loads Manifest Only**:
```bash
# Instead of full context.md, show manifest
echo "=== Memory Manifest ==="
cat "$MEMORY_DIR/MANIFEST.md"
echo ""
echo "Use Read tool to access specific memories as needed."
```

**Complexity**: Low
**Impact**: High - Dramatically reduces initial token load

---

### C3. Structured Memory Format (XML)

**Research Basis**: Anthropic's memory tool uses structured formats for reliable parsing.

**Problem**: Markdown memories are human-readable but harder for Claude to parse reliably.

**Solution**: Offer optional XML format for critical memories.

**Implementation**:
```xml
<!-- .claude/memory/context.xml -->
<memory version="1.0">
  <state updated="2025-01-02T14:30:00Z">
    <current_task>Implement authentication refresh tokens</current_task>
    <progress percent="60">
      <completed>Token generation</completed>
      <completed>Storage mechanism</completed>
      <pending>Refresh endpoint</pending>
      <pending>Expiry handling</pending>
    </progress>
  </state>

  <recent_decisions>
    <decision date="2025-01-01" topic="token-storage">
      <choice>Redis over database</choice>
      <rationale>Better TTL support, faster access</rationale>
    </decision>
  </recent_decisions>

  <active_files>
    <file path="src/auth/tokens.ts" status="modified"/>
    <file path="src/api/refresh.ts" status="new"/>
  </active_files>
</memory>
```

**Complexity**: Low
**Impact**: Medium - More reliable parsing for automated processing

---

## Category D: Multi-Agent Integration

### D1. Memory-Aware Orchestrator

**Research Basis**: Anthropic's multi-agent system achieved 90% improvement with proper orchestrator coordination.

**Problem**: `/orchestrate` command doesn't leverage memory system for task delegation.

**Solution**: Enhance orchestrator to consult memory before decomposition.

**Implementation** (orchestrate.md enhancement):

```markdown
## Memory-Aware Orchestration Protocol

### Before Decomposition
1. Read `context.md` for current state
2. Check `scratchpad.md` for related work in progress
3. Search `decisions.md` for relevant prior decisions
4. Scan `.ai/patterns/` for applicable patterns

### During Delegation
- Include relevant memory excerpts in subagent prompts
- Specify which memory files subagents should update
- Define output format for memory persistence

### After Synthesis
- Compile subagent findings to `scratchpad.md`
- Update `context.md` with new state
- Append significant decisions to `decisions.md`
- Create backlinks between related memories
```

**Complexity**: Low (documentation change)
**Impact**: High - Better coordination preserves context

---

### D2. Subagent Memory Isolation

**Research Basis**: "Each subagent operates independently, with their own 200K token context windows."

**Problem**: Subagents have no access to project memory, start from scratch each time.

**Solution**: Create lightweight memory bundles for subagents.

**Implementation**:
```bash
# scripts/create-subagent-bundle.sh
#!/bin/bash
# Create minimal memory bundle for subagent

TASK_TYPE="$1"
BUNDLE_DIR="/tmp/subagent-memory-$$"

mkdir -p "$BUNDLE_DIR"

# Copy only relevant memories
case "$TASK_TYPE" in
  explore)
    cp ".ai/core/architecture.md" "$BUNDLE_DIR/" 2>/dev/null
    cp ".ai/core/technology-stack.md" "$BUNDLE_DIR/" 2>/dev/null
    ;;
  implement)
    cp ".ai/patterns/"*.md "$BUNDLE_DIR/" 2>/dev/null
    cp ".claude/memory/decisions.md" "$BUNDLE_DIR/" 2>/dev/null
    ;;
  review)
    tail -50 ".claude/memory/scratchpad.md" > "$BUNDLE_DIR/recent-work.md"
    ;;
esac

echo "$BUNDLE_DIR"
```

**Complexity**: Medium
**Impact**: Medium - Subagents work with project context

---

### D3. Memory Diff Tracking

**Problem**: Hard to see what changed across sessions or agent executions.

**Solution**: Track memory changes like git tracks code.

**Implementation**:
```bash
# scripts/memory-diff.sh
#!/bin/bash
# Show memory changes since last session

MEMORY_DIR=".claude/memory"
LAST_SESSION=$(ls -t "$MEMORY_DIR/sessions/" | head -1)

echo "=== Memory Changes Since Last Session ==="

for file in context.md decisions.md; do
  if [ -f "$MEMORY_DIR/$file" ]; then
    echo ""
    echo "--- $file ---"
    diff "$MEMORY_DIR/sessions/$LAST_SESSION" "$MEMORY_DIR/$file" 2>/dev/null | head -20
  fi
done
```

**Complexity**: Low
**Impact**: Low - Debugging aid

---

## Implementation Roadmap

### Phase 1: Quick Wins
*Estimated: 1-2 sessions*

| Improvement | Complexity | Impact |
|-------------|------------|--------|
| A1. PreCompact Hook | Low | High |
| B3. Semantic Tagging | Low | Medium |
| C2. Just-In-Time Retrieval | Low | High |
| D1. Memory-Aware Orchestrator | Low | High |

### Phase 2: Core Enhancements
*Estimated: 3-4 sessions*

| Improvement | Complexity | Impact |
|-------------|------------|--------|
| A2. PostToolUse Hook | Medium | Medium |
| B1. Zettelkasten Linking | Medium | High |
| C1. Token-Efficient Loading | Medium | High |

### Phase 3: Advanced Features
*Estimated: 4-5 sessions*

| Improvement | Complexity | Impact |
|-------------|------------|--------|
| A3. SubagentStop Hook | Low | High |
| B2. Hierarchical Compression | Medium | High |
| D2. Subagent Memory Isolation | Medium | Medium |

---

## Design Principles

### 1. Stay Native
All improvements use Claude Code's built-in features:
- Hooks (SessionStart, UserPromptSubmit, SessionEnd, PreCompact, PostToolUse, SubagentStop)
- Skills and Commands
- Native tools (Read, Write, Edit, Grep, Glob)
- No external databases, APIs, or services

### 2. Keep It Simple
- Bash scripts for hooks (portable, debuggable)
- Markdown for human-readable memories
- Optional XML for structured parsing
- No complex dependencies

### 3. Respect Token Budget
- Load manifests, not full content
- Tier information by relevance
- Compress historical data
- Just-in-time retrieval

### 4. Enable Evolution
- Memories link to each other
- Old memories update when context changes
- Tags emerge from usage
- Patterns graduate to `.ai/`

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Context loss after compaction | ~40% | <10% |
| Memory retrieval relevance | Manual | Auto-suggested |
| Cross-session continuity | ~75% | ~95% |
| Token efficiency | Full load | Selective load |
| Subagent context inheritance | None | Bundled |

---

## References

1. Anthropic. (2025). *Effective Context Engineering for AI Agents*. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

2. Anthropic. (2025). *Memory Tool Documentation*. https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool

3. Anthropic. (2025). *How We Built Our Multi-Agent Research System*. https://www.anthropic.com/engineering/multi-agent-research-system

4. Anthropic. (2025). *Managing Context on the Claude Developer Platform*. https://claude.com/blog/context-management

5. Liu et al. (2025). *A-Mem: Agentic Memory for LLM Agents*. arXiv:2502.12110 (NeurIPS 2025)

6. Mem0 Team. (2025). *Building Production-Ready AI Agents with Scalable Long-Term Memory*. arXiv:2504.19413

7. Survey Authors. (2025). *From Human Memory to AI Memory: A Survey on Memory Mechanisms in the Era of LLMs*. arXiv:2504.15965

---

*Plan created: 2025-01-02*
*Research sources: Anthropic engineering blog, Claude documentation, NeurIPS 2025, arXiv*

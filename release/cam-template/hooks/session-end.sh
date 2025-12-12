#!/bin/bash
# Global SessionEnd Hook: Intelligent Session Summary Generation
# Version: 2.0.3

set -e

# Read hook input
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd')
PROJECT_NAME=$(basename "$CWD")

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 0: UNCOMMITTED CHANGES CHECK (v2.0.3)
# Warn if there are uncommitted changes that should have been PR'd
# ═══════════════════════════════════════════════════════════════════════════

UNCOMMITTED_WARNING=""
if [ -d "$CWD/.git" ]; then
  cd "$CWD"
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | head -20)
  if [ -n "$UNCOMMITTED" ]; then
    UNCOMMITTED_COUNT=$(echo "$UNCOMMITTED" | wc -l | tr -d ' ')
    UNCOMMITTED_WARNING="⚠️  UNCOMMITTED CHANGES DETECTED ($UNCOMMITTED_COUNT files) - Consider committing and creating PR before ending session"
  fi
  cd - > /dev/null
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6: SESSION STATE CLEANUP
# ═══════════════════════════════════════════════════════════════════════════

SESSION_STATE_DIR="$HOME/.claude/.session-state"
SESSION_STATE_FILE="$SESSION_STATE_DIR/${SESSION_ID}.json"

# Remove this session's state file
if [ -f "$SESSION_STATE_FILE" ]; then
  rm -f "$SESSION_STATE_FILE"
fi

# Skip if CAM not available in this project
if [ ! -d "$CWD/.claude/cam" ]; then
  jq -n '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "SessionEnd"
    }
  }'
  exit 0
fi

cd "$CWD"

# =========================================================================
# PHASE 6: Intelligent Session Summary (v1.5.2)
# Aggregate operations and create structured summary
# =========================================================================

# Query for all operations from this session using tags
SESSION_PREFIX="${SESSION_ID:0:8}"

# Get operation counts by type from the database
EDIT_COUNT=$(sqlite3 "./.claude/cam/metadata.db" \
  "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${SESSION_PREFIX}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Edit%';" 2>/dev/null || echo "0")

WRITE_COUNT=$(sqlite3 "./.claude/cam/metadata.db" \
  "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${SESSION_PREFIX}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Write%';" 2>/dev/null || echo "0")

READ_COUNT=$(sqlite3 "./.claude/cam/metadata.db" \
  "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${SESSION_PREFIX}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Read%';" 2>/dev/null || echo "0")

BASH_COUNT=$(sqlite3 "./.claude/cam/metadata.db" \
  "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${SESSION_PREFIX}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Bash%';" 2>/dev/null || echo "0")

TOTAL_OPS=$((EDIT_COUNT + WRITE_COUNT + READ_COUNT + BASH_COUNT))

# Get list of modified files (from Edit/Write operations)
FILES_MODIFIED=$(sqlite3 "./.claude/cam/metadata.db" \
  "SELECT DISTINCT json_extract(metadata, '\$.title') FROM annotations
   WHERE tags LIKE '%session-${SESSION_PREFIX}%'
   AND (json_extract(metadata, '\$.title') LIKE 'Op: Edit%' OR json_extract(metadata, '\$.title') LIKE 'Op: Write%')
   LIMIT 50;" 2>/dev/null | \
  sed 's/Op: Edit //g; s/Op: Write //g' | \
  sort -u | \
  head -20 || echo "")

# Convert files to JSON array
FILES_JSON="[]"
if [ -n "$FILES_MODIFIED" ]; then
  FILES_JSON=$(echo "$FILES_MODIFIED" | jq -R -s 'split("\n") | map(select(length > 0))')
fi

# Get timestamp
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Only create summary if there were operations
SUMMARY_STATUS="[~] No operations recorded this session"
if [ "$TOTAL_OPS" -gt 0 ]; then
  # Build JSON data for store-session command
  SESSION_DATA=$(jq -n \
    --arg project "$PROJECT_NAME" \
    --arg end_time "$END_TIME" \
    --argjson edit "$EDIT_COUNT" \
    --argjson write "$WRITE_COUNT" \
    --argjson read "$READ_COUNT" \
    --argjson bash "$BASH_COUNT" \
    --argjson files "$FILES_JSON" \
    '{
      project: $project,
      end_time: $end_time,
      operations: {
        Edit: $edit,
        Write: $write,
        Read: $read,
        Bash: $bash
      },
      files_modified: $files,
      key_activities: []
    }')

  # Store the session summary using the new store-session command
  STORE_OUTPUT=$(./.claude/cam/cam.sh store-session "$SESSION_ID" "$SESSION_DATA" 2>&1 || echo "")

  if echo "$STORE_OUTPUT" | grep -q "\[v\]"; then
    SUMMARY_STATUS="$STORE_OUTPUT"
  else
    SUMMARY_STATUS="[v] Session summary stored"
  fi
fi

# =========================================================================
# PHASE 2: Automatic Graph Building (v1.4.0)
# Build knowledge graph relationships if operations were recorded
# =========================================================================
GRAPH_STATS=""
if [ "$TOTAL_OPS" -gt 0 ]; then
  # Check minimum embedding threshold (need at least 10 for meaningful clustering)
  EMBEDDING_COUNT=$(./.claude/cam/cam.sh stats 2>/dev/null | jq -r '.total_embeddings // 0' 2>/dev/null || echo "0")

  if [ "$EMBEDDING_COUNT" -ge 10 ]; then
    # Build graph incrementally (without --rebuild to preserve existing relationships)
    # Run with timeout to prevent blocking session end
    GRAPH_OUTPUT=$(timeout 60 ./.claude/cam/cam.sh graph build 2>&1 || echo "Graph build skipped or timed out")

    # Extract edge counts from output
    TEMPORAL_EDGES=$(echo "$GRAPH_OUTPUT" | grep -o '"temporal": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")
    SEMANTIC_EDGES=$(echo "$GRAPH_OUTPUT" | grep -o '"semantic": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")
    CAUSAL_EDGES=$(echo "$GRAPH_OUTPUT" | grep -o '"causal": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")
    TOTAL_EDGES=$(echo "$GRAPH_OUTPUT" | grep -o '"total": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")

    if [ "$TOTAL_EDGES" -gt 0 ]; then
      GRAPH_STATS="Graph: ${TOTAL_EDGES} relationships (${TEMPORAL_EDGES} temporal, ${SEMANTIC_EDGES} semantic, ${CAUSAL_EDGES} causal)"
    fi
  fi
fi

# Return session summary - schema compliant format
jq -n \
  --arg session_id "$SESSION_ID" \
  --arg total_ops "$TOTAL_OPS" \
  --arg edit "$EDIT_COUNT" \
  --arg write "$WRITE_COUNT" \
  --arg read "$READ_COUNT" \
  --arg bash "$BASH_COUNT" \
  --arg project "$PROJECT_NAME" \
  --arg summary_status "$SUMMARY_STATUS" \
  --arg graph_stats "$GRAPH_STATS" \
  --arg uncommitted_warning "$UNCOMMITTED_WARNING" \
  '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "SessionEnd",
      additionalContext: ((if $uncommitted_warning != "" then $uncommitted_warning + "\n\n" else "" end) + "Session Summary\n\nProject: " + $project + "\nSession: " + $session_id + "\nOperations: " + $total_ops + " (Edit: " + $edit + ", Write: " + $write + ", Read: " + $read + ", Bash: " + $bash + ")\n\nStatus:\n  " + $summary_status + "\n  " + (if $graph_stats != "" then $graph_stats else "[~] Graph building skipped" end))
    }
  }'

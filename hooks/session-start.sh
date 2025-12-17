#!/bin/bash
# Simplified Memory - Session Start Hook
# Version: 1.0.0
#
# Reads context.md and injects it as session primer.
# Zero latency. No API calls. No Python.
#
# Expected input (stdin):
#   {"cwd": "/path/to/project", ...}
#
# Output (stdout):
#   {"continue": true, "additionalContext": "..."}

set -e

# Read JSON input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Fallback if cwd not provided
if [[ -z "$CWD" ]]; then
    echo '{"continue": true}'
    exit 0
fi

MEMORY_DIR="$CWD/.claude/memory"
CONTEXT_FILE="$MEMORY_DIR/context.md"

# Check if simplified memory is initialized
if [[ ! -d "$MEMORY_DIR" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Build context from memory files
CONTEXT=""

# Read current context (primary)
if [[ -f "$CONTEXT_FILE" ]]; then
    CONTEXT="## Session Memory

$(cat "$CONTEXT_FILE")

---
"
fi

# Check for recent session notes (last 3 days)
SESSIONS_DIR="$MEMORY_DIR/sessions"
if [[ -d "$SESSIONS_DIR" ]]; then
    RECENT_SESSIONS=""
    for i in {0..2}; do
        DATE=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "-$i days" +%Y-%m-%d 2>/dev/null || echo "")
        SESSION_FILE="$SESSIONS_DIR/$DATE.md"
        if [[ -f "$SESSION_FILE" ]]; then
            RECENT_SESSIONS="$RECENT_SESSIONS
### Session: $DATE
$(head -50 "$SESSION_FILE")
"
        fi
    done

    if [[ -n "$RECENT_SESSIONS" ]]; then
        CONTEXT="$CONTEXT
## Recent Sessions
$RECENT_SESSIONS
---
"
    fi
fi

# Output result
if [[ -n "$CONTEXT" ]]; then
    jq -n \
        --arg context "$CONTEXT" \
        '{
            continue: true,
            additionalContext: $context
        }'
else
    echo '{"continue": true}'
fi

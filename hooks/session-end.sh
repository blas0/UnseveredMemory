#!/bin/bash
# Simplified Memory - Session End Hook
# Version: 1.0.0
#
# Reminds Claude to update context.md before session ends.
# Non-blocking - just a gentle reminder.
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

# Check if simplified memory is initialized
if [[ ! -d "$MEMORY_DIR" ]]; then
    echo '{"continue": true}'
    exit 0
fi

DATE=$(date +%Y-%m-%d)
CONTEXT_FILE="$MEMORY_DIR/context.md"
SESSION_FILE="$MEMORY_DIR/sessions/$DATE.md"

# Build reminder
REMINDER="**📝 Session Memory Reminder**

Before ending, consider updating:

1. **\`.claude/memory/context.md\`** - Current state
   - What task is in progress?
   - What files were modified?
   - What's pending/blocked?
   - Context for next session?

2. **\`.claude/memory/decisions.md\`** - Append any architectural decisions made

3. **\`.claude/memory/sessions/$DATE.md\`** (optional) - Daily session notes

This helps maintain continuity across sessions."

jq -n \
    --arg reminder "$REMINDER" \
    '{
        continue: true,
        additionalContext: $reminder
    }'

#!/bin/bash
# UserPromptSubmit Hook - Injects memory state reminder on every prompt
# Part of Unsevered Memory: https://github.com/blas0/UnseveredMemory
#
# This is the ENFORCEMENT hook. It survives context compaction by
# being injected fresh on every user message.

MEMORY_DIR=".claude/memory"

# Exit silently if no memory directory
if [ ! -d "$MEMORY_DIR" ]; then
    exit 0
fi

# Extract current task from context.md (first non-empty, non-header line after "Current Task" or "## Task")
TASK="none"
if [ -f "$MEMORY_DIR/context.md" ]; then
    TASK=$(grep -A1 -i "current task\|## task" "$MEMORY_DIR/context.md" 2>/dev/null | grep -v "^#\|^--\|^$" | head -1 | sed 's/^[[:space:]]*//' | cut -c1-50)
    if [ -z "$TASK" ]; then
        TASK="none"
    fi
fi

# Count scratchpad lines
SCRATCH_LINES=0
if [ -f "$MEMORY_DIR/scratchpad.md" ]; then
    SCRATCH_LINES=$(wc -l < "$MEMORY_DIR/scratchpad.md" | tr -d ' ')
fi

# Get last .ai/ modification date
AI_UPDATED="never"
if [ -d ".ai" ]; then
    LATEST=$(find .ai -type f -name "*.md" -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f1)
    if [ -n "$LATEST" ]; then
        AI_UPDATED=$(date -r "$LATEST" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
    fi
fi

# Output single-line state reminder
echo ""
echo "[Memory] Task: $TASK | Scratchpad: ${SCRATCH_LINES} lines | .ai/ updated: $AI_UPDATED"
echo ""

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

# Extract active tags from scratchpad (hashtags)
TAGS=""
if [ -f "$MEMORY_DIR/scratchpad.md" ]; then
    TAGS=$(grep -oE '#[a-zA-Z0-9_-]+' "$MEMORY_DIR/scratchpad.md" 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//')
fi

# Check for checkpoints (context was compacted)
CHECKPOINT_COUNT=0
if [ -d "$MEMORY_DIR/checkpoints" ]; then
    CHECKPOINT_COUNT=$(find "$MEMORY_DIR/checkpoints" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

# Build output line
OUTPUT="[Memory] Task: $TASK | Scratchpad: ${SCRATCH_LINES} lines | .ai/ updated: $AI_UPDATED"

# Add tags if present
if [ -n "$TAGS" ]; then
    OUTPUT="$OUTPUT | Tags: $TAGS"
fi

# Warn if checkpoints exist (context was compacted)
if [ "$CHECKPOINT_COUNT" -gt 0 ]; then
    OUTPUT="$OUTPUT | Checkpoints: $CHECKPOINT_COUNT"
fi

# Output state reminder
echo ""
echo "$OUTPUT"
echo ""

#!/bin/bash
# PreCompact Hook - Saves critical context before context compaction
# Part of Unsevered Memory: https://github.com/blas0/UnseveredMemory
#
# This hook fires BEFORE Claude compacts the conversation context.
# It preserves critical information that would otherwise be lost.

MEMORY_DIR=".claude/memory"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Exit silently if no memory directory
if [ ! -d "$MEMORY_DIR" ]; then
    exit 0
fi

# Create checkpoints directory if needed
mkdir -p "$MEMORY_DIR/checkpoints"

echo ""
echo "[Memory] Creating checkpoint before compaction..."

# Build checkpoint content
CHECKPOINT_FILE="$MEMORY_DIR/checkpoints/${TIMESTAMP}.md"

{
    echo "# Compaction Checkpoint"
    echo ""
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Extract current task from context.md
    echo "## Active Task"
    echo ""
    if [ -f "$MEMORY_DIR/context.md" ]; then
        grep -A5 -i "## current task\|## task" "$MEMORY_DIR/context.md" 2>/dev/null | head -10 || echo "[No task found]"
    else
        echo "[No context.md]"
    fi
    echo ""

    # Get recent scratchpad entries
    echo "## Recent Progress"
    echo ""
    if [ -f "$MEMORY_DIR/scratchpad.md" ]; then
        tail -30 "$MEMORY_DIR/scratchpad.md"
    else
        echo "[No scratchpad]"
    fi
    echo ""

    # Get files modified in this session
    echo "## Files Modified This Session"
    echo ""
    if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
        git diff --name-only HEAD 2>/dev/null | head -15 || echo "[No uncommitted changes]"
    else
        echo "[Not a git repository]"
    fi
    echo ""

    # Get active tags if any
    if [ -f "$MEMORY_DIR/scratchpad.md" ]; then
        TAGS=$(grep -oE '#[a-zA-Z0-9_-]+' "$MEMORY_DIR/scratchpad.md" 2>/dev/null | sort -u | tr '\n' ' ')
        if [ -n "$TAGS" ]; then
            echo "## Active Tags"
            echo ""
            echo "$TAGS"
            echo ""
        fi
    fi

} > "$CHECKPOINT_FILE"

echo "[Memory] Checkpoint saved: checkpoints/${TIMESTAMP}.md"
echo ""

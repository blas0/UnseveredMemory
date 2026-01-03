#!/bin/bash
# SessionStart Hook - Loads memory context at session start
# Part of Unsevered Memory: https://github.com/blas0/UnseveredMemory

MEMORY_DIR=".claude/memory"

# Exit silently if no memory directory
if [ ! -d "$MEMORY_DIR" ]; then
    exit 0
fi

echo ""
echo "==========================================="
echo "  MEMORY LOADED"
echo "==========================================="
echo ""

# Load context.md (primary state)
if [ -f "$MEMORY_DIR/context.md" ]; then
    echo "--- Context (cross-session state) ---"
    echo ""
    cat "$MEMORY_DIR/context.md"
    echo ""
    echo "-------------------------------------------"
fi

# Check scratchpad for incomplete work from last session
if [ -f "$MEMORY_DIR/scratchpad.md" ]; then
    LINES=$(wc -l < "$MEMORY_DIR/scratchpad.md" | tr -d ' ')
    if [ "$LINES" -gt 5 ]; then
        echo ""
        echo "--- Previous Scratchpad ($LINES lines) ---"
        echo ""
        cat "$MEMORY_DIR/scratchpad.md"
        echo ""
        echo "-------------------------------------------"
    fi
fi

# Check for compaction checkpoints (indicates context was lost)
if [ -d "$MEMORY_DIR/checkpoints" ]; then
    CHECKPOINT_COUNT=$(find "$MEMORY_DIR/checkpoints" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CHECKPOINT_COUNT" -gt 0 ]; then
        echo ""
        echo "--- Compaction Checkpoints ($CHECKPOINT_COUNT) ---"
        echo ""
        echo "Context was compacted in previous session(s)."
        echo "Checkpoints preserve critical context. Latest:"
        echo ""
        LATEST_CHECKPOINT=$(ls -t "$MEMORY_DIR/checkpoints/"*.md 2>/dev/null | head -1)
        if [ -n "$LATEST_CHECKPOINT" ]; then
            echo "  $(basename "$LATEST_CHECKPOINT")"
            echo ""
            # Show task from checkpoint
            grep -A3 "## Active Task" "$LATEST_CHECKPOINT" 2>/dev/null | head -5
        fi
        echo ""
        echo "Use Read tool to view full checkpoints if needed."
        echo "-------------------------------------------"
    fi
fi

# Show MANIFEST summary if available
if [ -f "$MEMORY_DIR/MANIFEST.md" ]; then
    echo ""
    echo "[Memory MANIFEST available - use Read tool for just-in-time access]"
fi

# Hint about .ai/ documentation if it exists
if [ -d ".ai" ]; then
    echo ""
    echo "[.ai/ documentation available - check patterns and architecture]"
fi

echo ""

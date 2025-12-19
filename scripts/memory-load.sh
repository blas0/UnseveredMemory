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

# Hint about .ai/ documentation if it exists
if [ -d ".ai" ]; then
    echo ""
    echo "[.ai/ documentation available - check patterns and architecture]"
fi

echo ""

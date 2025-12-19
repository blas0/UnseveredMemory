#!/bin/bash
# SessionEnd Hook - Archives scratchpad and reminds to update context
# Part of Unsevered Memory: https://github.com/blas0/UnseveredMemory

MEMORY_DIR=".claude/memory"
TODAY=$(date +%Y-%m-%d)

# Exit silently if no memory directory
if [ ! -d "$MEMORY_DIR" ]; then
    exit 0
fi

echo ""
echo "==========================================="
echo "  SESSION END - MEMORY SAVE"
echo "==========================================="
echo ""

# Archive scratchpad if it has content
if [ -f "$MEMORY_DIR/scratchpad.md" ] && [ -s "$MEMORY_DIR/scratchpad.md" ]; then
    mkdir -p "$MEMORY_DIR/sessions"

    # Append to today's archive (multiple sessions per day)
    if [ -f "$MEMORY_DIR/sessions/$TODAY.md" ]; then
        echo "" >> "$MEMORY_DIR/sessions/$TODAY.md"
        echo "---" >> "$MEMORY_DIR/sessions/$TODAY.md"
        echo "" >> "$MEMORY_DIR/sessions/$TODAY.md"
    fi

    cat "$MEMORY_DIR/scratchpad.md" >> "$MEMORY_DIR/sessions/$TODAY.md"

    echo "[+] Archived scratchpad to sessions/$TODAY.md"

    # Clear scratchpad for next session
    echo "# Scratchpad" > "$MEMORY_DIR/scratchpad.md"
    echo "" >> "$MEMORY_DIR/scratchpad.md"
    echo "Session: $(date '+%Y-%m-%d %H:%M')" >> "$MEMORY_DIR/scratchpad.md"
    echo "" >> "$MEMORY_DIR/scratchpad.md"
fi

echo ""
echo "REMINDER: Update context.md with:"
echo "  - Current state of work"
echo "  - What was accomplished"
echo "  - Next steps for future sessions"
echo ""

# Check if decisions were made
if [ -f "$MEMORY_DIR/scratchpad.md" ]; then
    if grep -qi "decision\|chose\|decided\|architecture" "$MEMORY_DIR/sessions/$TODAY.md" 2>/dev/null; then
        echo "NOTE: Architectural decisions detected."
        echo "      Consider appending to decisions.md"
        echo ""
    fi
fi

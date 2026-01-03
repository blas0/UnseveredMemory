#!/bin/bash
# Memory Manifest Generator - Creates an index of memory files
# Part of Unsevered Memory: https://github.com/blas0/UnseveredMemory
#
# Generates MANIFEST.md with lightweight pointers to memory files,
# enabling just-in-time context retrieval.

MEMORY_DIR=".claude/memory"
MANIFEST="$MEMORY_DIR/MANIFEST.md"

# Exit if no memory directory
if [ ! -d "$MEMORY_DIR" ]; then
    exit 0
fi

# Get file size in human-readable format
get_size() {
    if [ -f "$1" ]; then
        SIZE=$(wc -c < "$1" | tr -d ' ')
        if [ "$SIZE" -lt 1024 ]; then
            echo "${SIZE}B"
        else
            KB=$((SIZE / 1024))
            echo "${KB}KB"
        fi
    else
        echo "0B"
    fi
}

# Extract keywords from a file (headers, first few words)
get_keywords() {
    if [ -f "$1" ]; then
        # Get headers and first meaningful words
        grep -E '^#+\s|^[A-Z]' "$1" 2>/dev/null | head -5 | tr '\n' ' ' | cut -c1-50 | sed 's/[#]//g' | tr -s ' '
    fi
}

# Get last modification date
get_modified() {
    if [ -f "$1" ]; then
        stat -f "%Sm" -t "%Y-%m-%d" "$1" 2>/dev/null || stat --format="%y" "$1" 2>/dev/null | cut -d' ' -f1
    fi
}

# Generate manifest
{
    echo "# Memory Manifest"
    echo ""
    echo "> Lightweight index for just-in-time context retrieval."
    echo "> Use Read tool to load specific files as needed."
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M')"
    echo ""

    echo "## Core Memory Files"
    echo ""
    echo "| File | Size | Modified | Preview |"
    echo "|------|------|----------|---------|"

    for file in context.md scratchpad.md decisions.md; do
        filepath="$MEMORY_DIR/$file"
        if [ -f "$filepath" ]; then
            size=$(get_size "$filepath")
            modified=$(get_modified "$filepath")
            keywords=$(get_keywords "$filepath" | cut -c1-40)
            echo "| \`$file\` | $size | $modified | $keywords |"
        fi
    done
    echo ""

    # Sessions
    if [ -d "$MEMORY_DIR/sessions" ]; then
        SESSION_COUNT=$(find "$MEMORY_DIR/sessions" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$SESSION_COUNT" -gt 0 ]; then
            echo "## Session Archives ($SESSION_COUNT files)"
            echo ""
            echo "| File | Size | Modified |"
            echo "|------|------|----------|"
            find "$MEMORY_DIR/sessions" -name "*.md" -exec stat -f "%Sm|%N" -t "%Y-%m-%d" {} \; 2>/dev/null | \
                sort -r | head -5 | while IFS='|' read -r date filepath; do
                    filename=$(basename "$filepath")
                    size=$(get_size "$filepath")
                    echo "| \`sessions/$filename\` | $size | $date |"
                done
            echo ""
            if [ "$SESSION_COUNT" -gt 5 ]; then
                echo "*... and $((SESSION_COUNT - 5)) more session files*"
                echo ""
            fi
        fi
    fi

    # Checkpoints
    if [ -d "$MEMORY_DIR/checkpoints" ]; then
        CHECKPOINT_COUNT=$(find "$MEMORY_DIR/checkpoints" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$CHECKPOINT_COUNT" -gt 0 ]; then
            echo "## Compaction Checkpoints ($CHECKPOINT_COUNT files)"
            echo ""
            echo "| File | Size | Created |"
            echo "|------|------|---------|"
            find "$MEMORY_DIR/checkpoints" -name "*.md" -exec stat -f "%Sm|%N" -t "%Y-%m-%d %H:%M" {} \; 2>/dev/null | \
                sort -r | head -3 | while IFS='|' read -r date filepath; do
                    filename=$(basename "$filepath")
                    size=$(get_size "$filepath")
                    echo "| \`checkpoints/$filename\` | $size | $date |"
                done
            echo ""
        fi
    fi

    # .ai/ documentation
    if [ -d ".ai" ]; then
        echo "## Documentation (.ai/)"
        echo ""
        echo "| File | Size | Modified |"
        echo "|------|------|----------|"
        find .ai -name "*.md" -type f 2>/dev/null | head -10 | while read -r filepath; do
            relpath="${filepath#./}"
            size=$(get_size "$filepath")
            modified=$(get_modified "$filepath")
            echo "| \`$relpath\` | $size | $modified |"
        done
        echo ""
    fi

    # Quick access section
    echo "## Quick Access"
    echo ""
    echo "- **Current task**: Read \`context.md\` section '## Current Task'"
    echo "- **Recent work**: Read last 30 lines of \`scratchpad.md\`"
    echo "- **Past decisions**: Read \`decisions.md\`"
    echo "- **After compaction**: Check \`checkpoints/\` for preserved context"
    echo ""

    # Active tags if any
    if [ -f "$MEMORY_DIR/scratchpad.md" ]; then
        TAGS=$(grep -oE '#[a-zA-Z0-9_-]+' "$MEMORY_DIR/scratchpad.md" 2>/dev/null | sort -u | tr '\n' ' ')
        if [ -n "$TAGS" ]; then
            echo "## Active Tags"
            echo ""
            echo "$TAGS"
            echo ""
        fi
    fi

} > "$MANIFEST"

echo "[Memory] Manifest updated: MANIFEST.md"

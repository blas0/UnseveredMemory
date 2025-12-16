#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# insight-extract.sh - Extract session insights to staging area
# Version: 2.1.0
#
# PURPOSE: Capture valuable session knowledge without polluting curated .ai/ docs
# TRIGGER: SessionEnd (automatic) or manual invocation
#
# ARCHITECTURE:
#   Context Window → Extract → Filter (novelty) → Stage (.ai/.insights/)
#   Never auto-writes to curated .ai/ files - only to .insights/ staging area
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

INSIGHT_VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Safeguards
MAX_INSIGHTS_PER_SESSION=5
MAX_INSIGHT_SIZE=2000
NOVELTY_THRESHOLD=0.85
INSIGHT_TTL_DAYS=30

# Blocked patterns (transient content)
BLOCKED_PATTERNS=("TODO" "FIXME" "XXX" "HACK" "temporary" "test only" "debug")

# Categories
CATEGORIES=("decisions" "patterns" "gotchas")

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

_log() {
    if [[ "${INSIGHT_DEBUG:-false}" == "true" ]]; then
        echo "[Insight] $*" >&2
    fi
}

_generate_id() {
    # Generate short unique ID
    echo -n "$(date +%s)-$$" | md5sum 2>/dev/null | cut -c1-8 || \
    echo -n "$(date +%s)-$$" | md5 2>/dev/null | cut -c1-8 || \
    echo "$(date +%s)" | cut -c-8
}

_is_blocked_content() {
    local content="$1"
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        if echo "$content" | grep -qi "$pattern"; then
            return 0  # true, is blocked
        fi
    done
    return 1  # false, not blocked
}

_truncate() {
    local text="$1"
    local max="$2"
    if [[ ${#text} -gt $max ]]; then
        echo "${text:0:$max}..."
    else
        echo "$text"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# NOVELTY CHECK
# ═══════════════════════════════════════════════════════════════════════════════

_is_novel() {
    local insight_text="$1"
    local cwd="$2"

    # Skip novelty check if CAM not available
    if [[ ! -d "$cwd/.claude/cam" ]]; then
        return 0  # Assume novel if can't check
    fi

    cd "$cwd"

    # Query CAM for similar content
    local similar_results
    similar_results=$(./.claude/cam/cam.sh query "$insight_text" 3 2>/dev/null || echo "")

    # Check if any result has high similarity score
    # CAM returns format: "1. [Score: 0.XX] ..."
    local max_score
    max_score=$(echo "$similar_results" | grep -oE 'Score: [0-9.]+' | head -1 | grep -oE '[0-9.]+' || echo "0")

    # Compare to threshold (using bc for float comparison, fallback to awk)
    local is_similar
    is_similar=$(echo "$max_score $NOVELTY_THRESHOLD" | awk '{if ($1 >= $2) print "yes"; else print "no"}')

    if [[ "$is_similar" == "yes" ]]; then
        _log "Insight too similar to existing content (score: $max_score)"
        return 1  # Not novel
    fi

    return 0  # Novel
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSIGHT CLASSIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

_classify_insight() {
    local text="$1"

    # Decision patterns
    if echo "$text" | grep -qiE "(because|chose|decided|instead of|trade-?off|opted for|went with|prefer)"; then
        echo "decisions"
        return
    fi

    # Gotcha/warning patterns
    if echo "$text" | grep -qiE "(remember|don't forget|watch out|careful|gotcha|pitfall|caveat|important:|note:|warning:)"; then
        echo "gotchas"
        return
    fi

    # Pattern patterns (meta!)
    if echo "$text" | grep -qiE "(always|never|convention|pattern|structure|approach|standard|best practice)"; then
        echo "patterns"
        return
    fi

    # Default to patterns
    echo "patterns"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSIGHT EXTRACTION
# ═══════════════════════════════════════════════════════════════════════════════

_extract_from_transcript() {
    local transcript_path="$1"
    local insights=()

    if [[ ! -f "$transcript_path" ]]; then
        return
    fi

    # Sample last 500 lines
    local sample
    sample=$(tail -500 "$transcript_path" 2>/dev/null || cat "$transcript_path")

    # Extract decision statements
    local decisions
    decisions=$(echo "$sample" | grep -iE "(because|chose|decided|instead of)" | head -5 || echo "")

    # Extract gotchas/warnings
    local gotchas
    gotchas=$(echo "$sample" | grep -iE "(remember|don't forget|watch out|important:)" | head -5 || echo "")

    # Extract pattern observations
    local patterns
    patterns=$(echo "$sample" | grep -iE "(always|never|pattern|convention|structure)" | head -5 || echo "")

    # Output as simple format (one per line)
    [[ -n "$decisions" ]] && echo "$decisions"
    [[ -n "$gotchas" ]] && echo "$gotchas"
    [[ -n "$patterns" ]] && echo "$patterns"
}

_extract_from_session_state() {
    local session_id="$1"
    local state_file="$HOME/.claude/.session-state/${session_id}.json"

    if [[ ! -f "$state_file" ]]; then
        return
    fi

    # Extract narrative events that might contain insights
    jq -r '.working_memory.session_narrative[]?.summary // empty' "$state_file" 2>/dev/null | head -10
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSIGHT STORAGE
# ═══════════════════════════════════════════════════════════════════════════════

_ensure_insights_dir() {
    local cwd="$1"
    local insights_dir="$cwd/.ai/.insights"

    mkdir -p "$insights_dir/decisions" 2>/dev/null || true
    mkdir -p "$insights_dir/patterns" 2>/dev/null || true
    mkdir -p "$insights_dir/gotchas" 2>/dev/null || true
    mkdir -p "$insights_dir/.archive" 2>/dev/null || true

    # Create index if not exists
    if [[ ! -f "$insights_dir/_index.json" ]]; then
        echo '{"version": "1.0", "insights": [], "last_cleanup": null}' > "$insights_dir/_index.json"
    fi

    # Create .gitignore for insights (optional - user can remove if they want to track)
    if [[ ! -f "$insights_dir/.gitignore" ]]; then
        cat > "$insights_dir/.gitignore" << 'EOF'
# Auto-generated insights - review before committing
# Remove this file if you want to track insights in git
*
!.gitignore
!_index.json
!README.md
EOF
    fi

    # Create README explaining the directory
    if [[ ! -f "$insights_dir/README.md" ]]; then
        cat > "$insights_dir/README.md" << 'EOF'
# AI-Generated Insights (Staging Area)

This directory contains **auto-extracted insights** from AI work sessions.

## Purpose

These are NOT curated documentation. They are a staging area for potential knowledge worth preserving.

## Review Process

Run `./cam.sh promote-insights` to:
- Review each insight
- Accept (add to curated .ai/ docs)
- Edit (modify then add)
- Skip (keep for later)
- Reject (delete)

## Directory Structure

```
.insights/
├── decisions/    # Why X instead of Y
├── patterns/     # Observed conventions
├── gotchas/      # Warnings and pitfalls
├── .archive/     # Old/rejected insights
└── _index.json   # Metadata tracking
```

## Note

By default, this directory is gitignored. Remove `.gitignore` if you want to track insights in version control.
EOF
    fi

    echo "$insights_dir"
}

_store_insight() {
    local cwd="$1"
    local session_id="$2"
    local category="$3"
    local content="$4"
    local confidence="${5:-0.7}"

    local insights_dir
    insights_dir=$(_ensure_insights_dir "$cwd")

    local insight_id
    insight_id=$(_generate_id)

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local date_prefix
    date_prefix=$(date +%Y-%m-%d)

    local file_path="$insights_dir/$category/${date_prefix}-${insight_id}.md"

    # Write insight file
    cat > "$file_path" << EOF
---
id: ${insight_id}
session: ${session_id:0:8}
timestamp: ${timestamp}
category: ${category}
confidence: ${confidence}
source: session_extraction
promoted: false
---

${content}
EOF

    # Update index
    local index_file="$insights_dir/_index.json"
    local updated_index
    updated_index=$(jq \
        --arg id "$insight_id" \
        --arg cat "$category" \
        --arg ts "$timestamp" \
        --arg file "$file_path" \
        --argjson conf "$confidence" \
        '.insights += [{
            id: $id,
            category: $cat,
            timestamp: $ts,
            file: $file,
            confidence: $conf,
            promoted: false,
            reviewed: false
        }]' "$index_file" 2>/dev/null || echo '{"insights":[]}')

    echo "$updated_index" > "$index_file"

    # Also tag in CAM for cross-referencing
    if [[ -d "$cwd/.claude/cam" ]]; then
        cd "$cwd"
        ./.claude/cam/cam.sh note \
            "Staged Insight: $category" \
            "$content" \
            "staged-insight,$category,${session_id:0:8}" \
            >/dev/null 2>&1 || true
    fi

    echo "$file_path"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXTRACTION LOGIC
# ═══════════════════════════════════════════════════════════════════════════════

extract_insights() {
    local input="$1"

    local session_id cwd transcript_path
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
    cwd=$(echo "$input" | jq -r '.cwd // ""')
    transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

    # Validate cwd
    if [[ -z "$cwd" || "$cwd" == "null" || ! -d "$cwd" ]]; then
        # Try to get from session state
        local state_file="$HOME/.claude/.session-state/${session_id}.json"
        if [[ -f "$state_file" ]]; then
            cwd=$(jq -r '.cwd // ""' "$state_file" 2>/dev/null || echo "")
        fi
    fi

    if [[ -z "$cwd" || ! -d "$cwd" ]]; then
        _log "No valid working directory found"
        echo '{"continue": true}'
        return 0
    fi

    # Check if .ai/ exists (insights require .ai/ directory)
    if [[ ! -d "$cwd/.ai" ]]; then
        _log ".ai/ directory not found, skipping insight extraction"
        echo '{"continue": true}'
        return 0
    fi

    _log "Extracting insights for session $session_id in $cwd"

    # Count existing insights for this session (rate limiting)
    local insights_dir="$cwd/.ai/.insights"
    local session_insight_count=0
    if [[ -d "$insights_dir" ]]; then
        session_insight_count=$(find "$insights_dir" -name "*.md" -newer "$HOME/.claude/.session-state/${session_id}.json" 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [[ "$session_insight_count" -ge "$MAX_INSIGHTS_PER_SESSION" ]]; then
        _log "Insight limit reached for session ($session_insight_count >= $MAX_INSIGHTS_PER_SESSION)"
        echo '{"continue": true, "hookSpecificOutput": {"insight_status": "limit_reached"}}'
        return 0
    fi

    # Extract potential insights
    local raw_insights=""

    # From transcript
    if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
        raw_insights+=$(_extract_from_transcript "$transcript_path")
        raw_insights+=$'\n'
    fi

    # From session state
    raw_insights+=$(_extract_from_session_state "$session_id")

    # Process each potential insight
    local stored_count=0
    local stored_files=""

    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Skip very short lines
        [[ ${#line} -lt 20 ]] && continue

        # Check blocked content
        if _is_blocked_content "$line"; then
            _log "Skipping blocked content: ${line:0:50}..."
            continue
        fi

        # Truncate if too long
        line=$(_truncate "$line" "$MAX_INSIGHT_SIZE")

        # Check novelty
        if ! _is_novel "$line" "$cwd"; then
            _log "Skipping non-novel content"
            continue
        fi

        # Classify
        local category
        category=$(_classify_insight "$line")

        # Store
        local stored_file
        stored_file=$(_store_insight "$cwd" "$session_id" "$category" "$line" "0.7")

        if [[ -n "$stored_file" ]]; then
            stored_count=$((stored_count + 1))
            stored_files+="$stored_file"$'\n'
            _log "Stored insight: $stored_file"
        fi

        # Check limit
        if [[ "$stored_count" -ge "$MAX_INSIGHTS_PER_SESSION" ]]; then
            break
        fi

    done <<< "$raw_insights"

    # Output result
    if [[ "$stored_count" -gt 0 ]]; then
        jq -n \
            --arg count "$stored_count" \
            --arg dir "$cwd/.ai/.insights" \
            '{
                continue: true,
                hookSpecificOutput: {
                    hookEventName: "InsightExtraction",
                    additionalContext: ("[+] Extracted " + $count + " insights to " + $dir + "\n    Run: ./cam.sh promote-insights to review")
                }
            }'
    else
        echo '{"continue": true}'
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP FUNCTION
# ═══════════════════════════════════════════════════════════════════════════════

cleanup_insights() {
    local cwd="$1"
    local max_age_days="${2:-$INSIGHT_TTL_DAYS}"

    local insights_dir="$cwd/.ai/.insights"

    if [[ ! -d "$insights_dir" ]]; then
        echo "No insights directory found"
        return 0
    fi

    local archived=0
    local deleted=0

    # Archive old unreviewed insights
    find "$insights_dir" -name "*.md" -mtime "+$max_age_days" -not -path "*/.archive/*" 2>/dev/null | while read -r file; do
        local filename
        filename=$(basename "$file")
        mv "$file" "$insights_dir/.archive/$filename" 2>/dev/null && archived=$((archived + 1))
    done

    # Delete very old archived insights (2x TTL)
    find "$insights_dir/.archive" -name "*.md" -mtime "+$((max_age_days * 2))" -delete 2>/dev/null

    # Update index - remove entries for deleted files
    local index_file="$insights_dir/_index.json"
    if [[ -f "$index_file" ]]; then
        local updated_index
        updated_index=$(jq '[.insights[] | select(.file as $f | ([$f] | map(test(".*") and (. | ltrimstr("") | test("^/"))) | any) or (input_filename | . != null))]' "$index_file" 2>/dev/null || cat "$index_file")
        # Simpler: just update last_cleanup timestamp
        updated_index=$(jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.last_cleanup = $ts' "$index_file")
        echo "$updated_index" > "$index_file"
    fi

    echo "Cleanup complete: archived old insights, deleted expired archives"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI INTERFACE
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local command="${1:-extract}"
    shift 2>/dev/null || true

    case "$command" in
        extract)
            # Read from stdin (hook mode)
            extract_insights "$(cat)"
            ;;
        cleanup)
            local cwd="${1:-$(pwd)}"
            local days="${2:-$INSIGHT_TTL_DAYS}"
            cleanup_insights "$cwd" "$days"
            ;;
        init)
            # Initialize insights directory
            local cwd="${1:-$(pwd)}"
            _ensure_insights_dir "$cwd"
            echo "[v] Insights directory initialized at $cwd/.ai/.insights/"
            ;;
        version)
            echo "Insight Extraction System v${INSIGHT_VERSION}"
            ;;
        help|--help|-h)
            cat << 'EOF'
Insight Extraction System - Capture session knowledge

Usage:
  echo '<json>' | ./insight-extract.sh extract    # Hook mode
  ./insight-extract.sh init [cwd]                 # Initialize .insights/
  ./insight-extract.sh cleanup [cwd] [days]       # Clean old insights
  ./insight-extract.sh version                    # Show version
  ./insight-extract.sh help                       # Show this help

Environment:
  INSIGHT_DEBUG=true    Enable debug logging
EOF
            ;;
        *)
            echo "Unknown command: $command" >&2
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# insight-promote.sh - Human-gated promotion of staged insights
# Version: 2.0.3
#
# PURPOSE: Review auto-extracted insights and promote worthy ones to curated .ai/
# USAGE: ./insight-promote.sh [--interactive] [--list] [--auto-accept THRESHOLD]
#
# NEVER auto-modifies curated .ai/ files without human approval
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

PROMOTE_VERSION="2.0.3"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Default target files for each category
declare -A CATEGORY_TARGETS=(
    ["decisions"]=".ai/meta/decisions.md"
    ["patterns"]=".ai/patterns/observed-patterns.md"
    ["gotchas"]=".ai/development/gotchas.md"
)

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

_print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}INSIGHT PROMOTION REVIEW${NC}                                     ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

_print_insight_box() {
    local category="$1"
    local confidence="$2"
    local session="$3"
    local timestamp="$4"
    local content="$5"
    local index="$6"
    local total="$7"

    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}[$index/$total]${NC} ${YELLOW}$category${NC} | Confidence: ${GREEN}$confidence${NC} | Session: $session"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${BOLD}CONTENT:${NC}"
    echo -e "┌──────────────────────────────────────────────────────────────────┐"
    # Wrap content nicely
    echo "$content" | fold -w 66 -s | while IFS= read -r line; do
        printf "│ %-66s │\n" "$line"
    done
    echo -e "└──────────────────────────────────────────────────────────────────┘"
    echo ""
}

_get_target_file() {
    local category="$1"
    local cwd="$2"

    local target="${CATEGORY_TARGETS[$category]}"

    # If target doesn't exist, create it
    if [[ ! -f "$cwd/$target" ]]; then
        local dir
        dir=$(dirname "$cwd/$target")
        mkdir -p "$dir"

        case "$category" in
            decisions)
                cat > "$cwd/$target" << 'EOF'
# Architecture Decisions

This document captures key decisions made during development.

## Promoted Insights

<!-- Insights promoted from .ai/.insights/ will be appended below -->

EOF
                ;;
            patterns)
                cat > "$cwd/$target" << 'EOF'
# Observed Patterns

Patterns discovered and validated during development.

## Promoted Insights

<!-- Insights promoted from .ai/.insights/ will be appended below -->

EOF
                ;;
            gotchas)
                cat > "$cwd/$target" << 'EOF'
# Gotchas and Pitfalls

Important warnings and lessons learned.

## Promoted Insights

<!-- Insights promoted from .ai/.insights/ will be appended below -->

EOF
                ;;
        esac
    fi

    echo "$cwd/$target"
}

# ═══════════════════════════════════════════════════════════════════════════════
# LIST INSIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

list_insights() {
    local cwd="${1:-$(pwd)}"
    local insights_dir="$cwd/.ai/.insights"

    if [[ ! -d "$insights_dir" ]]; then
        echo -e "${YELLOW}No insights directory found at $insights_dir${NC}"
        return 1
    fi

    local total=0
    local by_category=""

    for category in decisions patterns gotchas; do
        local count
        count=$(find "$insights_dir/$category" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        total=$((total + count))
        by_category+="  $category: $count\n"
    done

    echo -e "${BOLD}Staged Insights Summary${NC}"
    echo -e "Location: $insights_dir"
    echo -e "Total: $total insights"
    echo ""
    echo -e "${by_category}"

    if [[ "$total" -eq 0 ]]; then
        echo -e "${GREEN}No insights pending review.${NC}"
        return 0
    fi

    echo -e "${BOLD}Recent Insights:${NC}"
    find "$insights_dir" -name "*.md" -not -path "*/.archive/*" -not -name "README.md" 2>/dev/null | \
        head -10 | while read -r file; do
            local cat
            cat=$(basename "$(dirname "$file")")
            local name
            name=$(basename "$file")
            local preview
            preview=$(grep -v "^---" "$file" | grep -v "^$" | head -1 | cut -c1-60)
            echo -e "  ${YELLOW}[$cat]${NC} $name"
            echo -e "         ${preview}..."
        done

    echo ""
    echo -e "Run ${CYAN}./cam.sh promote-insights --interactive${NC} to review"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTIVE PROMOTION
# ═══════════════════════════════════════════════════════════════════════════════

promote_interactive() {
    local cwd="${1:-$(pwd)}"
    local insights_dir="$cwd/.ai/.insights"

    if [[ ! -d "$insights_dir" ]]; then
        echo -e "${YELLOW}No insights directory found.${NC}"
        return 1
    fi

    # Collect all insight files
    local insight_files=()
    while IFS= read -r -d '' file; do
        insight_files+=("$file")
    done < <(find "$insights_dir" -name "*.md" -not -path "*/.archive/*" -not -name "README.md" -print0 2>/dev/null)

    local total=${#insight_files[@]}

    if [[ "$total" -eq 0 ]]; then
        echo -e "${GREEN}No insights pending review.${NC}"
        return 0
    fi

    _print_header
    echo -e "Found ${BOLD}$total${NC} insights to review"
    echo ""

    local accepted=0
    local skipped=0
    local rejected=0
    local index=0

    for file in "${insight_files[@]}"; do
        index=$((index + 1))

        # Parse frontmatter
        local category confidence session timestamp
        category=$(grep "^category:" "$file" | cut -d: -f2 | tr -d ' ')
        confidence=$(grep "^confidence:" "$file" | cut -d: -f2 | tr -d ' ')
        session=$(grep "^session:" "$file" | cut -d: -f2 | tr -d ' ')
        timestamp=$(grep "^timestamp:" "$file" | cut -d: -f2- | tr -d ' ')

        # Get content (after frontmatter)
        local content
        content=$(awk '/^---$/{p=!p;next}p==0' "$file" | tail -n +2)

        _print_insight_box "$category" "$confidence" "$session" "$timestamp" "$content" "$index" "$total"

        # Get target suggestion
        local target
        target=$(_get_target_file "$category" "$cwd")
        echo -e "Suggested target: ${CYAN}$target${NC}"
        echo ""

        # Prompt for action
        echo -e "${BOLD}[A]${NC}ccept  ${BOLD}[E]${NC}dit  ${BOLD}[S]${NC}kip  ${BOLD}[R]${NC}eject  ${BOLD}[T]${NC}arget  ${BOLD}[Q]${NC}uit"
        echo -n "> "
        read -r action

        case "${action,,}" in
            a|accept)
                # Append to target file
                echo "" >> "$target"
                echo "### $(date +%Y-%m-%d) - Session $session" >> "$target"
                echo "" >> "$target"
                echo "$content" >> "$target"
                echo "" >> "$target"

                # Mark as promoted in index
                _mark_promoted "$insights_dir" "$file"

                # Move to archive
                mv "$file" "$insights_dir/.archive/" 2>/dev/null || rm "$file"

                accepted=$((accepted + 1))
                echo -e "${GREEN}[v] Promoted to $target${NC}"
                ;;

            e|edit)
                # Open in editor
                local temp_file
                temp_file=$(mktemp)
                echo "$content" > "$temp_file"

                ${EDITOR:-vim} "$temp_file"

                local edited_content
                edited_content=$(cat "$temp_file")
                rm "$temp_file"

                # Append edited content
                echo "" >> "$target"
                echo "### $(date +%Y-%m-%d) - Session $session (edited)" >> "$target"
                echo "" >> "$target"
                echo "$edited_content" >> "$target"
                echo "" >> "$target"

                _mark_promoted "$insights_dir" "$file"
                mv "$file" "$insights_dir/.archive/" 2>/dev/null || rm "$file"

                accepted=$((accepted + 1))
                echo -e "${GREEN}[v] Edited and promoted to $target${NC}"
                ;;

            s|skip)
                skipped=$((skipped + 1))
                echo -e "${YELLOW}[~] Skipped (will review later)${NC}"
                ;;

            r|reject)
                mv "$file" "$insights_dir/.archive/" 2>/dev/null || rm "$file"
                rejected=$((rejected + 1))
                echo -e "${RED}[x] Rejected and archived${NC}"
                ;;

            t|target)
                echo -e "Enter custom target path (relative to project root):"
                echo -n "> "
                read -r custom_target

                if [[ -n "$custom_target" ]]; then
                    target="$cwd/$custom_target"
                    mkdir -p "$(dirname "$target")"

                    echo "" >> "$target"
                    echo "### $(date +%Y-%m-%d) - Session $session" >> "$target"
                    echo "" >> "$target"
                    echo "$content" >> "$target"
                    echo "" >> "$target"

                    _mark_promoted "$insights_dir" "$file"
                    mv "$file" "$insights_dir/.archive/" 2>/dev/null || rm "$file"

                    accepted=$((accepted + 1))
                    echo -e "${GREEN}[v] Promoted to $target${NC}"
                fi
                ;;

            q|quit)
                echo ""
                echo -e "${YELLOW}Exiting review.${NC}"
                break
                ;;

            *)
                echo -e "${YELLOW}Unknown action, skipping${NC}"
                skipped=$((skipped + 1))
                ;;
        esac

        echo ""
    done

    # Summary
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Review Complete${NC}"
    echo -e "  ${GREEN}Accepted:${NC} $accepted"
    echo -e "  ${YELLOW}Skipped:${NC} $skipped"
    echo -e "  ${RED}Rejected:${NC} $rejected"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

_mark_promoted() {
    local insights_dir="$1"
    local file="$2"
    local index_file="$insights_dir/_index.json"

    if [[ -f "$index_file" ]]; then
        local filename
        filename=$(basename "$file")
        jq --arg f "$filename" '
            .insights = [.insights[] | if .file | endswith($f) then .promoted = true else . end]
        ' "$index_file" > "${index_file}.tmp" && mv "${index_file}.tmp" "$index_file"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-ACCEPT (for CI/scripting)
# ═══════════════════════════════════════════════════════════════════════════════

promote_auto() {
    local cwd="${1:-$(pwd)}"
    local threshold="${2:-0.9}"
    local insights_dir="$cwd/.ai/.insights"

    if [[ ! -d "$insights_dir" ]]; then
        echo "No insights directory found."
        return 1
    fi

    echo "Auto-accepting insights with confidence >= $threshold"

    local accepted=0

    find "$insights_dir" -name "*.md" -not -path "*/.archive/*" -not -name "README.md" 2>/dev/null | while read -r file; do
        local confidence
        confidence=$(grep "^confidence:" "$file" | cut -d: -f2 | tr -d ' ')

        # Compare confidence to threshold
        local above_threshold
        above_threshold=$(echo "$confidence $threshold" | awk '{if ($1 >= $2) print "yes"; else print "no"}')

        if [[ "$above_threshold" == "yes" ]]; then
            local category
            category=$(grep "^category:" "$file" | cut -d: -f2 | tr -d ' ')

            local target
            target=$(_get_target_file "$category" "$cwd")

            local content
            content=$(awk '/^---$/{p=!p;next}p==0' "$file" | tail -n +2)

            local session
            session=$(grep "^session:" "$file" | cut -d: -f2 | tr -d ' ')

            echo "" >> "$target"
            echo "### $(date +%Y-%m-%d) - Session $session (auto-promoted)" >> "$target"
            echo "" >> "$target"
            echo "$content" >> "$target"
            echo "" >> "$target"

            mv "$file" "$insights_dir/.archive/"
            accepted=$((accepted + 1))
            echo "[v] Auto-promoted: $(basename "$file") -> $target"
        fi
    done

    echo "Auto-accepted $accepted insights"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI INTERFACE
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local cwd="$(pwd)"
    local mode="interactive"
    local threshold="0.9"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list|-l)
                mode="list"
                shift
                ;;
            --interactive|-i)
                mode="interactive"
                shift
                ;;
            --auto-accept)
                mode="auto"
                threshold="${2:-0.9}"
                shift 2
                ;;
            --cwd|-c)
                cwd="$2"
                shift 2
                ;;
            --help|-h)
                cat << 'EOF'
Insight Promotion System - Review and promote staged insights

Usage:
  ./insight-promote.sh [options]

Options:
  --list, -l              List pending insights
  --interactive, -i       Interactive review (default)
  --auto-accept THRESHOLD Auto-accept insights above threshold
  --cwd, -c PATH          Set working directory
  --help, -h              Show this help

Interactive Actions:
  [A]ccept  - Add insight to curated .ai/ documentation
  [E]dit    - Edit insight before adding
  [S]kip    - Leave for later review
  [R]eject  - Delete insight
  [T]arget  - Specify custom target file
  [Q]uit    - Exit review

Examples:
  ./insight-promote.sh --list
  ./insight-promote.sh --interactive
  ./insight-promote.sh --auto-accept 0.95
EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    case "$mode" in
        list)
            list_insights "$cwd"
            ;;
        interactive)
            promote_interactive "$cwd"
            ;;
        auto)
            promote_auto "$cwd" "$threshold"
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# migrate-insights.sh - Upgrade existing CAM installations to v2.1.0+
# Version: 2.1.0
#
# PURPOSE: Seamlessly upgrade existing CAM installations with new features:
#   - Insights Pipeline (.ai/.insights/ system)
#   - Auto-update system
#   - New hooks integration
#
# USAGE:
#   ~/.claude/hooks/migrate-insights.sh [project-dir]
#   ~/.claude/hooks/migrate-insights.sh --global
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

MIGRATE_VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

_log() {
    echo -e "${BLUE}[migrate]${NC} $*"
}

_success() {
    echo -e "${GREEN}[v]${NC} $*"
}

_warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

_error() {
    echo -e "${RED}[x]${NC} $*"
}

_print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  CAM Migration to v${MIGRATE_VERSION}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL MIGRATION (hooks, template, config)
# ═══════════════════════════════════════════════════════════════════════════════

migrate_global() {
    _print_header
    _log "Migrating global CAM installation..."

    local template_dir="$HOME/.claude/cam-template"
    local hooks_dir="$HOME/.claude/hooks"

    # Check if CAM is installed globally
    if [[ ! -d "$template_dir" ]]; then
        _error "CAM template not found at $template_dir"
        echo "  Run the setup script first: ./release/setup.sh"
        return 1
    fi

    # Get current version
    local current_version="0.0.0"
    if [[ -f "$template_dir/VERSION.txt" ]]; then
        current_version=$(cat "$template_dir/VERSION.txt" | tr -d '[:space:]')
    fi

    _log "Current version: $current_version"
    _log "Target version:  $MIGRATE_VERSION"

    # ─────────────────────────────────────────────────────────────────────────
    # Step 1: Backup current installation
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 1/5: Creating backup..."

    local backup_dir="$HOME/.claude/.cam-backup-pre-${MIGRATE_VERSION}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    cp -r "$template_dir" "$backup_dir/cam-template" 2>/dev/null || true
    cp -r "$hooks_dir" "$backup_dir/hooks" 2>/dev/null || true
    [[ -f "$HOME/.claude/CLAUDE.md" ]] && cp "$HOME/.claude/CLAUDE.md" "$backup_dir/" 2>/dev/null || true

    _success "Backup created at $backup_dir"

    # ─────────────────────────────────────────────────────────────────────────
    # Step 2: Install new hooks
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 2/5: Installing new hooks..."

    local new_hooks=(
        "insight-extract.sh"
        "insight-promote.sh"
        "cam-update-check.sh"
        "migrate-insights.sh"
    )

    for hook in "${new_hooks[@]}"; do
        if [[ -f "$SCRIPT_DIR/$hook" ]]; then
            cp "$SCRIPT_DIR/$hook" "$hooks_dir/$hook"
            chmod +x "$hooks_dir/$hook"
            _success "Installed $hook"
        else
            _warn "Hook not found: $hook (may need manual copy)"
        fi
    done

    # ─────────────────────────────────────────────────────────────────────────
    # Step 3: Update settings-hooks.json
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 3/5: Updating hooks configuration..."

    local settings_file="$HOME/.claude/settings.json"

    if [[ -f "$settings_file" ]]; then
        # Check if hooks section exists
        if jq -e '.hooks' "$settings_file" >/dev/null 2>&1; then
            # Add new hooks if not present

            # Check for insight extraction hook
            local has_insight_hook
            has_insight_hook=$(jq '.hooks.SessionEnd // [] | map(select(.command | contains("insight-extract"))) | length' "$settings_file" 2>/dev/null || echo "0")

            if [[ "$has_insight_hook" == "0" ]]; then
                _log "Adding insight extraction to SessionEnd hooks..."
                # This is complex JSON manipulation - create a temp file
                local temp_settings
                temp_settings=$(mktemp)

                jq '.hooks.SessionEnd = (.hooks.SessionEnd // []) + [{
                    "command": "~/.claude/hooks/insight-extract.sh extract",
                    "description": "Extract session insights to staging area"
                }]' "$settings_file" > "$temp_settings"

                mv "$temp_settings" "$settings_file"
                _success "Added insight extraction hook"
            else
                _success "Insight extraction hook already configured"
            fi

            # Check for update check hook
            local has_update_hook
            has_update_hook=$(jq '.hooks.SessionStart // [] | map(select(.command | contains("cam-update-check"))) | length' "$settings_file" 2>/dev/null || echo "0")

            if [[ "$has_update_hook" == "0" ]]; then
                _log "Adding update check to SessionStart hooks..."
                local temp_settings
                temp_settings=$(mktemp)

                jq '.hooks.SessionStart = (.hooks.SessionStart // []) + [{
                    "command": "~/.claude/hooks/cam-update-check.sh hook",
                    "description": "Check for CAM updates (daily)"
                }]' "$settings_file" > "$temp_settings"

                mv "$temp_settings" "$settings_file"
                _success "Added update check hook"
            else
                _success "Update check hook already configured"
            fi
        else
            _warn "No hooks section in settings.json - may need manual configuration"
        fi
    else
        _warn "settings.json not found - hooks will need manual configuration"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Step 4: Initialize update config
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 4/5: Initializing update system..."

    local update_config="$HOME/.claude/cam-update-config.json"

    if [[ ! -f "$update_config" ]]; then
        cat > "$update_config" << 'EOF'
{
    "version": "1.0",
    "enabled": true,
    "auto_check": true,
    "auto_update": false,
    "check_interval_hours": 24,
    "upstream": {
        "repo": "",
        "branch": "main",
        "raw_url_base": ""
    },
    "notifications": {
        "show_changelog": true,
        "notify_minor": true,
        "notify_patch": true
    },
    "last_check": null,
    "last_update": null,
    "skipped_versions": []
}
EOF
        _success "Created update configuration"
        echo ""
        _warn "Configure your upstream repository:"
        echo "    ~/.claude/hooks/cam-update-check.sh --configure https://github.com/your-org/cam-system.git"
    else
        _success "Update configuration already exists"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Step 5: Update version
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 5/5: Updating version..."

    echo "$MIGRATE_VERSION" > "$template_dir/VERSION.txt"
    _success "Version updated to $MIGRATE_VERSION"

    # ─────────────────────────────────────────────────────────────────────────
    # Done
    # ─────────────────────────────────────────────────────────────────────────
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Global Migration Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "New features available:"
    echo "  • Insights Pipeline: Auto-extract session knowledge"
    echo "  • Update Checker: Daily checks for CAM updates"
    echo ""
    echo "Next steps:"
    echo "  1. Configure upstream repo for updates:"
    echo "     ${CYAN}~/.claude/hooks/cam-update-check.sh --configure <repo-url>${NC}"
    echo ""
    echo "  2. Migrate individual projects:"
    echo "     ${CYAN}~/.claude/hooks/migrate-insights.sh /path/to/project${NC}"
    echo ""
    echo "Backup location: $backup_dir"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PROJECT MIGRATION (add .insights/ to existing projects)
# ═══════════════════════════════════════════════════════════════════════════════

migrate_project() {
    local project_dir="$1"

    if [[ -z "$project_dir" ]]; then
        project_dir="$(pwd)"
    fi

    # Resolve to absolute path
    project_dir=$(cd "$project_dir" && pwd)

    _print_header
    _log "Migrating project: $project_dir"

    # Check if .ai/ exists
    if [[ ! -d "$project_dir/.ai" ]]; then
        _warn "No .ai/ directory found in project"
        echo "  This project may not be set up for AI documentation."
        echo "  Run init-cam.sh to initialize: ~/.claude/hooks/init-cam.sh $project_dir"
        return 1
    fi

    # Check if CAM is initialized
    if [[ ! -d "$project_dir/.claude/cam" ]]; then
        _warn "CAM not initialized in this project"
        echo "  Run init-cam.sh to initialize: ~/.claude/hooks/init-cam.sh $project_dir"
        return 1
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Step 1: Create .insights/ directory
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 1/3: Creating insights directory..."

    local insights_dir="$project_dir/.ai/.insights"

    if [[ -d "$insights_dir" ]]; then
        _success "Insights directory already exists"
    else
        mkdir -p "$insights_dir/decisions"
        mkdir -p "$insights_dir/patterns"
        mkdir -p "$insights_dir/gotchas"
        mkdir -p "$insights_dir/.archive"

        # Create index
        echo '{"version": "1.0", "insights": [], "last_cleanup": null}' > "$insights_dir/_index.json"

        # Create .gitignore
        cat > "$insights_dir/.gitignore" << 'EOF'
# Auto-generated insights - review before committing
# Remove this file if you want to track insights in git
*
!.gitignore
!_index.json
!README.md
EOF

        # Create README
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

        _success "Created insights directory structure"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Step 2: Create target files for promotion
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 2/3: Creating promotion target files..."

    # Decisions file
    if [[ ! -f "$project_dir/.ai/meta/decisions.md" ]]; then
        mkdir -p "$project_dir/.ai/meta"
        cat > "$project_dir/.ai/meta/decisions.md" << 'EOF'
# Architecture Decisions

This document captures key decisions made during development.

## Promoted Insights

<!-- Insights promoted from .ai/.insights/ will be appended below -->

EOF
        _success "Created .ai/meta/decisions.md"
    fi

    # Observed patterns file
    if [[ ! -f "$project_dir/.ai/patterns/observed-patterns.md" ]]; then
        mkdir -p "$project_dir/.ai/patterns"
        cat > "$project_dir/.ai/patterns/observed-patterns.md" << 'EOF'
# Observed Patterns

Patterns discovered and validated during development.

## Promoted Insights

<!-- Insights promoted from .ai/.insights/ will be appended below -->

EOF
        _success "Created .ai/patterns/observed-patterns.md"
    fi

    # Gotchas file
    if [[ ! -f "$project_dir/.ai/development/gotchas.md" ]]; then
        mkdir -p "$project_dir/.ai/development"
        cat > "$project_dir/.ai/development/gotchas.md" << 'EOF'
# Gotchas and Pitfalls

Important warnings and lessons learned.

## Promoted Insights

<!-- Insights promoted from .ai/.insights/ will be appended below -->

EOF
        _success "Created .ai/development/gotchas.md"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Step 3: Update project's cam.sh if needed
    # ─────────────────────────────────────────────────────────────────────────
    _log "Step 3/3: Checking project CAM installation..."

    local project_cam="$project_dir/.claude/cam/cam.sh"
    local template_cam="$HOME/.claude/cam-template/cam.sh"

    if [[ -f "$project_cam" && -f "$template_cam" ]]; then
        local project_version template_version
        project_version=$(grep "^CAM_VERSION=" "$project_cam" 2>/dev/null | cut -d'"' -f2 || echo "0.0.0")
        template_version=$(grep "^CAM_VERSION=" "$template_cam" 2>/dev/null | cut -d'"' -f2 || echo "0.0.0")

        if [[ "$project_version" != "$template_version" ]]; then
            _warn "Project CAM version ($project_version) differs from template ($template_version)"
            echo "  To upgrade project: cd $project_dir && ./.claude/cam/cam.sh upgrade"
        else
            _success "Project CAM is up to date"
        fi
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Done
    # ─────────────────────────────────────────────────────────────────────────
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Project Migration Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "New features available in this project:"
    echo "  • .ai/.insights/ - Auto-extracted insights staging"
    echo "  • .ai/meta/decisions.md - Promoted decisions"
    echo "  • .ai/patterns/observed-patterns.md - Promoted patterns"
    echo "  • .ai/development/gotchas.md - Promoted gotchas"
    echo ""
    echo "Usage:"
    echo "  • Insights are auto-extracted at session end"
    echo -e "  • Review with: ${CYAN}./cam.sh promote-insights${NC}"
    echo -e "  • List pending: ${CYAN}./cam.sh promote-insights --list${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH MIGRATION
# ═══════════════════════════════════════════════════════════════════════════════

migrate_all_projects() {
    _print_header
    _log "Finding all CAM-initialized projects..."

    # Find all projects with .claude/cam
    local projects=()
    while IFS= read -r -d '' cam_dir; do
        local project_dir
        project_dir=$(dirname "$(dirname "$cam_dir")")
        projects+=("$project_dir")
    done < <(find "$HOME" -maxdepth 5 -type d -name "cam" -path "*/.claude/cam" -print0 2>/dev/null)

    if [[ ${#projects[@]} -eq 0 ]]; then
        _warn "No CAM-initialized projects found"
        return 0
    fi

    echo "Found ${#projects[@]} CAM-initialized projects:"
    for p in "${projects[@]}"; do
        echo "  • $p"
    done
    echo ""

    read -p "Migrate all projects? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Migration cancelled."
        return 0
    fi

    for project in "${projects[@]}"; do
        echo ""
        echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
        migrate_project "$project"
    done

    echo ""
    _success "All projects migrated!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI INTERFACE
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local command="${1:-help}"

    case "$command" in
        --global|-g)
            migrate_global
            ;;
        --all|-a)
            migrate_all_projects
            ;;
        --help|-h|help)
            cat << 'EOF'
CAM Migration Script - Upgrade to v2.2.0+

Usage:
  ./migrate-insights.sh [command]

Commands:
  --global, -g          Migrate global CAM installation (~/.claude/)
  --all, -a             Migrate all CAM-initialized projects
  /path/to/project      Migrate specific project
  --help, -h            Show this help

Migration adds:
  • Insights Pipeline (.ai/.insights/ system)
  • Auto-update system (daily version checks)
  • New hooks for insight extraction

Recommended order:
  1. Run --global first to update hooks
  2. Run on individual projects or --all

Examples:
  ./migrate-insights.sh --global
  ./migrate-insights.sh /path/to/my/project
  ./migrate-insights.sh --all
EOF
            ;;
        *)
            # Assume it's a project path
            if [[ -d "$command" ]]; then
                migrate_project "$command"
            else
                _error "Unknown command or invalid path: $command"
                echo "Run './migrate-insights.sh --help' for usage"
                exit 1
            fi
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

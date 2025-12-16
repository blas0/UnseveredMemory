#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# cam-update-check.sh - Automatic CAM update checker
# Version: 2.1.0
#
# PURPOSE: Check for CAM updates from upstream repository
# TRIGGER: SessionStart (rate-limited to once per day) or manual
#
# FEATURES:
#   - Daily update checks (rate-limited)
#   - Compares local VERSION.txt to remote
#   - Shows changelog for new versions
#   - Optional auto-update with confirmation
#   - Preserves local customizations
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

UPDATE_VERSION="2.1.0"
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
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Update check configuration file
UPDATE_CONFIG="$HOME/.claude/cam-update-config.json"

# State file for rate limiting
UPDATE_STATE="$HOME/.claude/.cam-update-state"

# Default upstream repository
DEFAULT_REPO="https://github.com/your-org/cam-system.git"
DEFAULT_BRANCH="main"

# Rate limiting: check at most once per day (in seconds)
CHECK_INTERVAL=$((24 * 60 * 60))

# Paths
TEMPLATE_DIR="$HOME/.claude/cam-template"
HOOKS_DIR="$HOME/.claude/hooks"

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

_init_config() {
    if [[ ! -f "$UPDATE_CONFIG" ]]; then
        cat > "$UPDATE_CONFIG" << EOF
{
    "version": "1.0",
    "enabled": true,
    "auto_check": true,
    "auto_update": false,
    "check_interval_hours": 24,
    "upstream": {
        "repo": "$DEFAULT_REPO",
        "branch": "$DEFAULT_BRANCH",
        "raw_url_base": "https://raw.githubusercontent.com/your-org/cam-system/main"
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
        echo "[v] Created update configuration at $UPDATE_CONFIG"
    fi
}

_get_config() {
    local key="$1"
    local default="$2"

    if [[ -f "$UPDATE_CONFIG" ]]; then
        local value
        value=$(jq -r "$key // empty" "$UPDATE_CONFIG" 2>/dev/null)
        if [[ -n "$value" && "$value" != "null" ]]; then
            echo "$value"
            return
        fi
    fi
    echo "$default"
}

_set_config() {
    local key="$1"
    local value="$2"

    if [[ -f "$UPDATE_CONFIG" ]]; then
        local updated
        updated=$(jq "$key = $value" "$UPDATE_CONFIG")
        echo "$updated" > "$UPDATE_CONFIG"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# RATE LIMITING
# ═══════════════════════════════════════════════════════════════════════════════

_should_check() {
    # Check if auto-check is enabled
    local enabled
    enabled=$(_get_config ".auto_check" "true")
    if [[ "$enabled" != "true" ]]; then
        return 1
    fi

    # Check rate limit
    if [[ ! -f "$UPDATE_STATE" ]]; then
        return 0  # Never checked, should check
    fi

    local last_check
    last_check=$(cat "$UPDATE_STATE" 2>/dev/null || echo "0")

    local now
    now=$(date +%s)

    local interval_hours
    interval_hours=$(_get_config ".check_interval_hours" "24")
    local interval_seconds=$((interval_hours * 60 * 60))

    if [[ $((now - last_check)) -ge $interval_seconds ]]; then
        return 0  # Enough time has passed
    fi

    return 1  # Too soon
}

_record_check() {
    date +%s > "$UPDATE_STATE"
    _set_config ".last_check" "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERSION COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════

_get_local_version() {
    if [[ -f "$TEMPLATE_DIR/VERSION.txt" ]]; then
        cat "$TEMPLATE_DIR/VERSION.txt" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}

_fetch_remote_version() {
    local raw_url_base
    raw_url_base=$(_get_config ".upstream.raw_url_base" "")

    if [[ -z "$raw_url_base" ]]; then
        # Try to fetch from git repo directly
        local repo branch
        repo=$(_get_config ".upstream.repo" "$DEFAULT_REPO")
        branch=$(_get_config ".upstream.branch" "$DEFAULT_BRANCH")

        # Use git ls-remote to check if repo is accessible
        if ! git ls-remote "$repo" HEAD >/dev/null 2>&1; then
            echo ""
            return 1
        fi

        # Clone minimal info to temp dir
        local temp_dir
        temp_dir=$(mktemp -d)
        if git clone --depth 1 --branch "$branch" "$repo" "$temp_dir" >/dev/null 2>&1; then
            if [[ -f "$temp_dir/release/cam-template/VERSION.txt" ]]; then
                cat "$temp_dir/release/cam-template/VERSION.txt" | tr -d '[:space:]'
            elif [[ -f "$temp_dir/cam-template/VERSION.txt" ]]; then
                cat "$temp_dir/cam-template/VERSION.txt" | tr -d '[:space:]'
            fi
            rm -rf "$temp_dir"
        else
            rm -rf "$temp_dir"
            echo ""
            return 1
        fi
    else
        # Fetch VERSION.txt via HTTP
        local version_url="$raw_url_base/release/cam-template/VERSION.txt"
        curl -s --connect-timeout 5 "$version_url" 2>/dev/null | tr -d '[:space:]' || echo ""
    fi
}

_compare_versions() {
    local v1="$1"
    local v2="$2"

    # Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
    if [[ "$v1" == "$v2" ]]; then
        echo "0"
        return
    fi

    # Parse version components
    local v1_major v1_minor v1_patch
    local v2_major v2_minor v2_patch

    IFS='.' read -r v1_major v1_minor v1_patch <<< "$v1"
    IFS='.' read -r v2_major v2_minor v2_patch <<< "$v2"

    # Default to 0 if empty
    v1_major=${v1_major:-0}
    v1_minor=${v1_minor:-0}
    v1_patch=${v1_patch:-0}
    v2_major=${v2_major:-0}
    v2_minor=${v2_minor:-0}
    v2_patch=${v2_patch:-0}

    if [[ "$v1_major" -lt "$v2_major" ]]; then
        echo "-1"
    elif [[ "$v1_major" -gt "$v2_major" ]]; then
        echo "1"
    elif [[ "$v1_minor" -lt "$v2_minor" ]]; then
        echo "-1"
    elif [[ "$v1_minor" -gt "$v2_minor" ]]; then
        echo "1"
    elif [[ "$v1_patch" -lt "$v2_patch" ]]; then
        echo "-1"
    elif [[ "$v1_patch" -gt "$v2_patch" ]]; then
        echo "1"
    else
        echo "0"
    fi
}

_is_version_skipped() {
    local version="$1"

    if [[ -f "$UPDATE_CONFIG" ]]; then
        local skipped
        skipped=$(jq -r ".skipped_versions | index(\"$version\") // -1" "$UPDATE_CONFIG" 2>/dev/null)
        if [[ "$skipped" != "-1" && "$skipped" != "null" ]]; then
            return 0  # Is skipped
        fi
    fi
    return 1  # Not skipped
}

# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE OPERATIONS
# ═══════════════════════════════════════════════════════════════════════════════

_fetch_changelog() {
    local raw_url_base
    raw_url_base=$(_get_config ".upstream.raw_url_base" "")

    if [[ -n "$raw_url_base" ]]; then
        local changelog_url="$raw_url_base/CHANGELOG.md"
        curl -s --connect-timeout 5 "$changelog_url" 2>/dev/null | head -100 || echo "Changelog not available"
    else
        echo "Changelog not available (configure upstream.raw_url_base)"
    fi
}

_backup_current() {
    local backup_dir="$HOME/.claude/.cam-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    # Backup template
    if [[ -d "$TEMPLATE_DIR" ]]; then
        cp -r "$TEMPLATE_DIR" "$backup_dir/cam-template"
    fi

    # Backup hooks
    if [[ -d "$HOOKS_DIR" ]]; then
        cp -r "$HOOKS_DIR" "$backup_dir/hooks"
    fi

    echo "$backup_dir"
}

_perform_update() {
    local repo branch
    repo=$(_get_config ".upstream.repo" "$DEFAULT_REPO")
    branch=$(_get_config ".upstream.branch" "$DEFAULT_BRANCH")

    echo -e "${BLUE}[1/4] Creating backup...${NC}"
    local backup_dir
    backup_dir=$(_backup_current)
    echo -e "      Backup created at: $backup_dir"

    echo -e "${BLUE}[2/4] Fetching latest version...${NC}"
    local temp_dir
    temp_dir=$(mktemp -d)

    if ! git clone --depth 1 --branch "$branch" "$repo" "$temp_dir" 2>/dev/null; then
        echo -e "${RED}[x] Failed to clone repository${NC}"
        rm -rf "$temp_dir"
        return 1
    fi

    echo -e "${BLUE}[3/4] Installing updates...${NC}"

    # Determine source path (handle different repo structures)
    local source_path=""
    if [[ -d "$temp_dir/release/cam-template" ]]; then
        source_path="$temp_dir/release"
    elif [[ -d "$temp_dir/cam-template" ]]; then
        source_path="$temp_dir"
    else
        echo -e "${RED}[x] Could not find cam-template in repository${NC}"
        rm -rf "$temp_dir"
        return 1
    fi

    # Update template
    if [[ -d "$source_path/cam-template" ]]; then
        rm -rf "$TEMPLATE_DIR"
        cp -r "$source_path/cam-template" "$TEMPLATE_DIR"
        echo -e "      [v] Updated cam-template"
    fi

    # Update hooks (preserving local customizations)
    if [[ -d "$source_path/cam-template/hooks" ]]; then
        for hook in "$source_path/cam-template/hooks"/*.sh; do
            local hook_name
            hook_name=$(basename "$hook")
            local dest="$HOOKS_DIR/$hook_name"

            # Check if local hook has customizations
            if [[ -f "$dest" ]]; then
                local local_hash remote_hash
                local_hash=$(md5sum "$dest" 2>/dev/null | cut -d' ' -f1 || md5 "$dest" | cut -d' ' -f4)
                remote_hash=$(md5sum "$hook" 2>/dev/null | cut -d' ' -f1 || md5 "$hook" | cut -d' ' -f4)

                if [[ "$local_hash" != "$remote_hash" ]]; then
                    # Keep backup of customized hook
                    cp "$dest" "$dest.local-backup"
                fi
            fi

            cp "$hook" "$dest"
            chmod +x "$dest"
        done
        echo -e "      [v] Updated hooks"
    fi

    # Update global-claude.md if present
    if [[ -f "$source_path/global-claude.md" ]]; then
        cp "$source_path/global-claude.md" "$HOME/.claude/CLAUDE.md"
        echo -e "      [v] Updated global CLAUDE.md"
    fi

    rm -rf "$temp_dir"

    echo -e "${BLUE}[4/4] Verifying installation...${NC}"
    local new_version
    new_version=$(_get_local_version)
    echo -e "      [v] Now running CAM v$new_version"

    # Record update
    _set_config ".last_update" "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Update complete! CAM is now at version $new_version${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Backup location: $backup_dir"
    echo -e "To rollback: ${CYAN}cp -r $backup_dir/* ~/.claude/${NC}"

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK COMMAND
# ═══════════════════════════════════════════════════════════════════════════════

check_for_updates() {
    local force="${1:-false}"
    local silent="${2:-false}"

    # Initialize config if needed
    _init_config

    # Check rate limit (unless forced)
    if [[ "$force" != "true" ]] && ! _should_check; then
        [[ "$silent" != "true" ]] && echo "Update check skipped (rate limited). Use --force to override."
        return 0
    fi

    # Record this check
    _record_check

    [[ "$silent" != "true" ]] && echo -e "${BLUE}Checking for CAM updates...${NC}"

    local local_version remote_version
    local_version=$(_get_local_version)
    remote_version=$(_fetch_remote_version)

    if [[ -z "$remote_version" ]]; then
        [[ "$silent" != "true" ]] && echo -e "${YELLOW}Could not fetch remote version. Check network or configure upstream.${NC}"
        return 1
    fi

    local comparison
    comparison=$(_compare_versions "$local_version" "$remote_version")

    if [[ "$comparison" == "-1" ]]; then
        # Update available
        if _is_version_skipped "$remote_version"; then
            [[ "$silent" != "true" ]] && echo -e "${YELLOW}Update to v$remote_version available but skipped.${NC}"
            return 0
        fi

        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}  ${BOLD}CAM Update Available!${NC}                                        ${GREEN}║${NC}"
        echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║${NC}  Current: ${YELLOW}v$local_version${NC}                                             ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  Latest:  ${CYAN}v$remote_version${NC}                                             ${GREEN}║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Show changelog preview
        local show_changelog
        show_changelog=$(_get_config ".notifications.show_changelog" "true")
        if [[ "$show_changelog" == "true" ]]; then
            echo -e "${BOLD}Recent Changes:${NC}"
            _fetch_changelog | head -30
            echo ""
        fi

        echo -e "To update: ${CYAN}~/.claude/hooks/cam-update-check.sh --update${NC}"
        echo -e "To skip:   ${CYAN}~/.claude/hooks/cam-update-check.sh --skip $remote_version${NC}"
        echo ""

        # Return special exit code for "update available"
        return 2

    elif [[ "$comparison" == "0" ]]; then
        [[ "$silent" != "true" ]] && echo -e "${GREEN}[v] CAM is up to date (v$local_version)${NC}"
        return 0

    else
        [[ "$silent" != "true" ]] && echo -e "${CYAN}[i] Local version (v$local_version) is ahead of remote (v$remote_version)${NC}"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# HOOK MODE (for SessionStart integration)
# ═══════════════════════════════════════════════════════════════════════════════

hook_mode() {
    # Read hook input (not used, but consume stdin)
    cat >/dev/null

    # Initialize config
    _init_config

    # Check if enabled
    local enabled
    enabled=$(_get_config ".enabled" "true")
    if [[ "$enabled" != "true" ]]; then
        echo '{"continue": true}'
        return 0
    fi

    # Rate-limited check
    if ! _should_check; then
        echo '{"continue": true}'
        return 0
    fi

    # Silent check
    local local_version remote_version
    local_version=$(_get_local_version)
    remote_version=$(_fetch_remote_version 2>/dev/null)

    _record_check

    if [[ -n "$remote_version" ]]; then
        local comparison
        comparison=$(_compare_versions "$local_version" "$remote_version")

        if [[ "$comparison" == "-1" ]] && ! _is_version_skipped "$remote_version"; then
            # Update available - notify via hook output
            jq -n \
                --arg local "$local_version" \
                --arg remote "$remote_version" \
                '{
                    continue: true,
                    hookSpecificOutput: {
                        hookEventName: "UpdateCheck",
                        additionalContext: ("⬆️  CAM Update Available: v" + $local + " → v" + $remote + "\n   Run: ~/.claude/hooks/cam-update-check.sh --update")
                    }
                }'
            return 0
        fi
    fi

    echo '{"continue": true}'
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI INTERFACE
# ═══════════════════════════════════════════════════════════════════════════════

show_status() {
    _init_config

    local local_version
    local_version=$(_get_local_version)

    local last_check last_update
    last_check=$(_get_config ".last_check" "never")
    last_update=$(_get_config ".last_update" "never")

    local enabled auto_check auto_update
    enabled=$(_get_config ".enabled" "true")
    auto_check=$(_get_config ".auto_check" "true")
    auto_update=$(_get_config ".auto_update" "false")

    local repo branch
    repo=$(_get_config ".upstream.repo" "$DEFAULT_REPO")
    branch=$(_get_config ".upstream.branch" "$DEFAULT_BRANCH")

    echo -e "${BOLD}CAM Update System Status${NC}"
    echo ""
    echo -e "Local Version:  ${CYAN}v$local_version${NC}"
    echo -e "Last Check:     $last_check"
    echo -e "Last Update:    $last_update"
    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo -e "  Enabled:      $enabled"
    echo -e "  Auto-Check:   $auto_check"
    echo -e "  Auto-Update:  $auto_update"
    echo ""
    echo -e "${BOLD}Upstream:${NC}"
    echo -e "  Repository:   $repo"
    echo -e "  Branch:       $branch"
}

configure_upstream() {
    local repo="$1"
    local branch="${2:-main}"

    _init_config

    _set_config ".upstream.repo" "\"$repo\""
    _set_config ".upstream.branch" "\"$branch\""

    # Try to derive raw URL base for GitHub
    if [[ "$repo" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        local owner="${BASH_REMATCH[1]}"
        local reponame="${BASH_REMATCH[2]%.git}"
        local raw_base="https://raw.githubusercontent.com/$owner/$reponame/$branch"
        _set_config ".upstream.raw_url_base" "\"$raw_base\""
        echo "[v] Configured upstream: $repo ($branch)"
        echo "[v] Raw URL base: $raw_base"
    else
        echo "[v] Configured upstream: $repo ($branch)"
        echo "[!] Could not auto-detect raw URL base. Set manually with --set-raw-url"
    fi
}

main() {
    local command="${1:-check}"
    shift 2>/dev/null || true

    case "$command" in
        check)
            check_for_updates "false" "false"
            ;;
        --check|-c)
            check_for_updates "false" "false"
            ;;
        --force|-f)
            check_for_updates "true" "false"
            ;;
        --silent|-s)
            check_for_updates "false" "true"
            ;;
        --update|-u)
            echo -e "${YELLOW}This will update CAM to the latest version.${NC}"
            echo -e "A backup will be created before updating."
            echo ""
            read -p "Continue? (y/N): " confirm
            if [[ "${confirm,,}" == "y" ]]; then
                _perform_update
            else
                echo "Update cancelled."
            fi
            ;;
        --skip)
            local version="$1"
            if [[ -z "$version" ]]; then
                echo "Usage: --skip <version>"
                exit 1
            fi
            _init_config
            local current_skipped
            current_skipped=$(jq '.skipped_versions' "$UPDATE_CONFIG")
            jq --arg v "$version" '.skipped_versions += [$v] | .skipped_versions |= unique' "$UPDATE_CONFIG" > "${UPDATE_CONFIG}.tmp"
            mv "${UPDATE_CONFIG}.tmp" "$UPDATE_CONFIG"
            echo "[v] Version $version will be skipped"
            ;;
        --status)
            show_status
            ;;
        --configure)
            local repo="$1"
            local branch="${2:-main}"
            if [[ -z "$repo" ]]; then
                echo "Usage: --configure <repo-url> [branch]"
                exit 1
            fi
            configure_upstream "$repo" "$branch"
            ;;
        --enable)
            _init_config
            _set_config ".enabled" "true"
            _set_config ".auto_check" "true"
            echo "[v] Update checking enabled"
            ;;
        --disable)
            _init_config
            _set_config ".enabled" "false"
            _set_config ".auto_check" "false"
            echo "[v] Update checking disabled"
            ;;
        hook)
            hook_mode
            ;;
        version)
            echo "CAM Update System v$UPDATE_VERSION"
            ;;
        help|--help|-h)
            cat << 'EOF'
CAM Update Check System - Keep CAM up to date

Usage:
  ./cam-update-check.sh [command] [options]

Commands:
  check, --check, -c      Check for updates (default, rate-limited)
  --force, -f             Force check (ignore rate limit)
  --silent, -s            Silent check (no output unless update available)
  --update, -u            Download and install latest version
  --skip <version>        Skip a specific version
  --status                Show update system status
  --configure <repo>      Configure upstream repository
  --enable                Enable auto-update checking
  --disable               Disable auto-update checking
  hook                    Hook mode (for SessionStart integration)
  version                 Show version
  help                    Show this help

Configuration:
  Config file: ~/.claude/cam-update-config.json

  To configure upstream repository:
    ./cam-update-check.sh --configure https://github.com/org/repo.git main

Examples:
  ./cam-update-check.sh                    # Check for updates
  ./cam-update-check.sh --force            # Force check now
  ./cam-update-check.sh --update           # Install updates
  ./cam-update-check.sh --skip 2.3.0       # Skip version 2.3.0
EOF
            ;;
        *)
            echo "Unknown command: $command"
            echo "Run './cam-update-check.sh help' for usage"
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

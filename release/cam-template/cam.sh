#!/bin/bash
# CAM CLI Wrapper Script with Version Management

CAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$CAM_DIR/venv/bin/python"
CAM_CORE="$CAM_DIR/cam_core.py"
VERSION_FILE="$CAM_DIR/VERSION.txt"
TEMPLATE_DIR="$HOME/.claude/cam-template"
BACKUP_DIR="$CAM_DIR/.backup"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE" | tr -d '\n'
    else
        # Fallback to Python
        "$VENV_PYTHON" "$CAM_CORE" version 2>/dev/null || echo "unknown"
    fi
}

# Get template version
get_template_version() {
    if [ -f "$TEMPLATE_DIR/VERSION.txt" ]; then
        cat "$TEMPLATE_DIR/VERSION.txt" | tr -d '\n'
    else
        echo "unknown"
    fi
}

# Compare versions (returns 0 if v1 < v2, 1 if v1 >= v2)
version_lt() {
    # Simple semantic version comparison
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ] && [ "$1" != "$2" ]
}

# Check if venv exists
check_venv() {
    if [ ! -f "$VENV_PYTHON" ]; then
        echo -e "${RED}Error: Virtual environment not found at $CAM_DIR/venv${NC}"
        echo "Run: cd $CAM_DIR && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
        exit 1
    fi
}

# Check and install Python dependencies if needed
check_dependencies() {
    # Only check if requirements.txt exists
    if [ ! -f "$CAM_DIR/requirements.txt" ]; then
        return 0
    fi

    # Check if google-generativeai is importable (key dependency)
    if ! "$VENV_PYTHON" -c "import google.generativeai" 2>/dev/null; then
        echo -e "${YELLOW}[!] Missing Python dependencies detected${NC}"
        echo -e "${BLUE}[+] Installing dependencies...${NC}"

        # Install from requirements.txt
        "$VENV_PYTHON" -m pip install -q -r "$CAM_DIR/requirements.txt" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[v] Dependencies installed successfully${NC}"
        else
            echo -e "${RED}[x] Failed to install dependencies${NC}"
            echo "Try manually: cd $CAM_DIR && source venv/bin/activate && pip install -r requirements.txt"
            exit 1
        fi
    fi
}

# Version check and warning (runs on most commands)
version_check_warning() {
    local current=$(get_current_version)
    local template=$(get_template_version)

    if [ "$current" != "unknown" ] && [ "$template" != "unknown" ] && version_lt "$current" "$template"; then
        echo -e "${YELLOW}[!] CAM v${current} installed, v${template} available${NC}"
        echo -e "${YELLOW}Run: $0 upgrade${NC}"
        echo ""
    fi
}

# Handle commands
case "$1" in
    version)
        # Show version info
        current=$(get_current_version)
        template=$(get_template_version)

        echo "CAM Version: $current"
        if [ "$template" != "unknown" ]; then
            echo "Template Version: $template"
            if version_lt "$current" "$template"; then
                echo -e "${YELLOW}Status: Update available${NC}"
            else
                echo -e "${GREEN}Status: Up to date${NC}"
            fi
        fi
        ;;

    upgrade)
        # Check for --force flag
        FORCE_UPGRADE=false
        if [ "$2" = "--force" ] || [ "$2" = "-f" ]; then
            FORCE_UPGRADE=true
        fi

        echo -e "${BLUE}[~] CAM Upgrade${NC}"
        if [ "$FORCE_UPGRADE" = true ]; then
            echo -e "${YELLOW}(Force mode enabled)${NC}"
        fi
        echo ""

        # Check if template exists
        if [ ! -d "$TEMPLATE_DIR" ]; then
            echo -e "${RED}Error: Template not found at $TEMPLATE_DIR${NC}"
            echo "Cannot upgrade without template source."
            exit 1
        fi

        current=$(get_current_version)
        template=$(get_template_version)

        echo "Current version: $current"
        echo "Template version: $template"
        echo ""

        # Check if already up to date (skip if force mode)
        if [ "$FORCE_UPGRADE" = false ] && [ "$current" = "$template" ]; then
            echo -e "${GREEN}[v] Already up to date!${NC}"
            echo -e "${BLUE}Tip: Use --force to reinstall anyway${NC}"
            exit 0
        fi

        # Confirm upgrade
        echo -e "${YELLOW}This will replace cam_core.py, cam.sh, and potentially requirements.txt${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Upgrade cancelled."
            exit 0
        fi

        # Create backup
        echo -e "${BLUE}[+] Creating backup...${NC}"
        rm -rf "$BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        cp "$CAM_CORE" "$BACKUP_DIR/" 2>/dev/null || true
        cp "$0" "$BACKUP_DIR/cam.sh" 2>/dev/null || true
        cp "$CAM_DIR/requirements.txt" "$BACKUP_DIR/" 2>/dev/null || true
        cp "$VERSION_FILE" "$BACKUP_DIR/" 2>/dev/null || true
        echo -e "${GREEN}[v] Backup created at $BACKUP_DIR${NC}"

        # Copy new files
        echo -e "${BLUE}[+] Copying new files...${NC}"
        cp "$TEMPLATE_DIR/cam_core.py" "$CAM_DIR/" || {
            echo -e "${RED}[x] Failed to copy cam_core.py${NC}"
            exit 1
        }
        cp "$TEMPLATE_DIR/cam.sh" "$CAM_DIR/" || {
            echo -e "${RED}[x] Failed to copy cam.sh${NC}"
            exit 1
        }
        cp "$TEMPLATE_DIR/VERSION.txt" "$CAM_DIR/" || {
            echo -e "${RED}[x] Failed to copy VERSION.txt${NC}"
            exit 1
        }
        chmod +x "$CAM_DIR/cam.sh"
        echo -e "${GREEN}[v] Files copied${NC}"

        # Check if requirements changed
        echo -e "${BLUE}>>> Checking dependencies...${NC}"
        if [ -f "$BACKUP_DIR/requirements.txt" ] && ! diff -q "$TEMPLATE_DIR/requirements.txt" "$BACKUP_DIR/requirements.txt" >/dev/null 2>&1; then
            echo -e "${YELLOW}Requirements changed, reinstalling dependencies...${NC}"
            cp "$TEMPLATE_DIR/requirements.txt" "$CAM_DIR/"
            "$VENV_PYTHON" -m pip install -q -r "$CAM_DIR/requirements.txt" || {
                echo -e "${RED}[x] Failed to install dependencies${NC}"
                echo -e "${YELLOW}Rolling back...${NC}"
                cp "$BACKUP_DIR/cam_core.py" "$CAM_DIR/"
                cp "$BACKUP_DIR/cam.sh" "$CAM_DIR/"
                cp "$BACKUP_DIR/requirements.txt" "$CAM_DIR/"
                cp "$BACKUP_DIR/VERSION.txt" "$CAM_DIR/"
                exit 1
            }
            echo -e "${GREEN}[v] Dependencies updated${NC}"
        else
            echo -e "${GREEN}[v] No dependency changes${NC}"
        fi

        # Test installation
        echo -e "${BLUE}>>> Testing installation...${NC}"
        TEST_OUTPUT=$("$VENV_PYTHON" "$CAM_CORE" version 2>&1)
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[v] Installation test passed${NC}"

            # Clean up backup directory after successful upgrade
            # IMPORTANT: .backup existence blocks cam-note.sh (PostToolUse annotations)
            echo -e "${BLUE}[--] Cleaning up backup...${NC}"
            rm -rf "$BACKUP_DIR"
            echo -e "${GREEN}[v] Backup cleaned up${NC}"

            echo ""
            echo -e "${GREEN}==========================================${NC}"
            echo -e "${GREEN}[v] Upgrade complete: $current --> $template${NC}"
            echo -e "${GREEN}==========================================${NC}"
            echo ""
            echo -e "${BLUE}Note: To rollback, run 'upgrade --force' with old template${NC}"
        else
            echo -e "${RED}[x] Installation test failed${NC}"
            echo -e "${YELLOW}Rolling back...${NC}"
            cp "$BACKUP_DIR/cam_core.py" "$CAM_DIR/"
            cp "$BACKUP_DIR/cam.sh" "$CAM_DIR/"
            cp "$BACKUP_DIR/VERSION.txt" "$CAM_DIR/"
            if [ -f "$BACKUP_DIR/requirements.txt" ]; then
                cp "$BACKUP_DIR/requirements.txt" "$CAM_DIR/"
            fi
            echo -e "${RED}Upgrade failed, rolled back to $current${NC}"
            exit 1
        fi
        ;;

    note)
        # Add ephemeral note to CAM
        # Wrapper for cam-note.sh hook script
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 note \"Title\" \"Content\" [tags]"
            echo ""
            echo "Arguments:"
            echo "  Title    - Short title for the note"
            echo "  Content  - Full content/description"
            echo "  tags     - Optional comma-separated tags (default: ephemeral,session-note)"
            echo ""
            echo "Example:"
            echo "  $0 note \"Bug Fix\" \"Fixed auth token expiration issue\" \"bugfix,auth\""
            exit 1
        fi

        TITLE="$2"
        CONTENT="$3"
        TAGS="${4:-ephemeral,session-note}"

        # Check if cam-note.sh exists in hooks
        CAM_NOTE_SCRIPT="$HOME/.claude/hooks/cam-note.sh"
        if [ -f "$CAM_NOTE_SCRIPT" ]; then
            # Use the hooks script
            "$CAM_NOTE_SCRIPT" "$TITLE" "$CONTENT" "$TAGS"
        else
            # Fallback: use annotate directly
            check_venv
            TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            NOTE_ID=$(echo -n "${TITLE}-$(date +%s)" | md5 2>/dev/null || echo -n "${TITLE}-$(date +%s)" | md5sum | cut -d' ' -f1)
            METADATA="{\"type\":\"ephemeral_note\",\"title\":\"$TITLE\",\"created\":\"$TIMESTAMP\"}"
            "$VENV_PYTHON" "$CAM_CORE" annotate "$CONTENT" --metadata "$METADATA" --tags "$TAGS"
            echo "[v] Stored note: $TITLE"
        fi
        ;;

    get)
        # Get full content by embedding ID
        check_venv
        check_dependencies

        if [ -z "$2" ]; then
            echo "Usage: $0 get <embedding_id>"
            echo ""
            echo "Retrieves the full content of an embedding by its ID."
            echo "Use 'query' first to find embedding IDs, then 'get' to see full content."
            exit 1
        fi

        "$VENV_PYTHON" "$CAM_CORE" get "$2"
        ;;

    stats|query|ingest|annotate|eval|benchmark|graph|rebuild|relate|find-doc|\
    set-importance|list-important|query-important|\
    store-decision|get-decision|list-decisions|\
    store-invariant|list-invariants|\
    link-causal|trace-causality|get-related|\
    query-dsl|query-graph|multi-hop|get-embedding|\
    inflection-points|compress-memory|reconstruction-context|adaptive-retrieve|reweave)
        # Check venv for Python commands
        check_venv
        check_dependencies

        # Show version warning before executing
        if [ "$1" = "stats" ]; then
            version_check_warning
        fi

        # Execute CAM command
        "$VENV_PYTHON" "$CAM_CORE" "$@"
        ;;

    promote-insights|insights)
        # Insight promotion system - review and promote staged insights
        INSIGHTS_SCRIPT="$HOME/.claude/hooks/insight-promote.sh"
        if [ -f "$INSIGHTS_SCRIPT" ]; then
            shift  # Remove 'promote-insights' or 'insights'
            "$INSIGHTS_SCRIPT" "$@"
        else
            echo -e "${RED}Error: insight-promote.sh not found${NC}"
            echo "Run migration: ~/.claude/hooks/migrate-insights.sh --global"
            exit 1
        fi
        ;;

    insights-init)
        # Initialize insights directory in current project
        EXTRACT_SCRIPT="$HOME/.claude/hooks/insight-extract.sh"
        if [ -f "$EXTRACT_SCRIPT" ]; then
            "$EXTRACT_SCRIPT" init "$(pwd)"
        else
            echo -e "${RED}Error: insight-extract.sh not found${NC}"
            echo "Run migration: ~/.claude/hooks/migrate-insights.sh --global"
            exit 1
        fi
        ;;

    insights-cleanup)
        # Clean up old insights
        EXTRACT_SCRIPT="$HOME/.claude/hooks/insight-extract.sh"
        if [ -f "$EXTRACT_SCRIPT" ]; then
            "$EXTRACT_SCRIPT" cleanup "$(pwd)" "${2:-30}"
        else
            echo -e "${RED}Error: insight-extract.sh not found${NC}"
            exit 1
        fi
        ;;

    update-check)
        # Check for CAM updates
        UPDATE_SCRIPT="$HOME/.claude/hooks/cam-update-check.sh"
        if [ -f "$UPDATE_SCRIPT" ]; then
            shift  # Remove 'update-check'
            "$UPDATE_SCRIPT" "$@"
        else
            echo -e "${RED}Error: cam-update-check.sh not found${NC}"
            echo "Run migration: ~/.claude/hooks/migrate-insights.sh --global"
            exit 1
        fi
        ;;

    update)
        # Alias for update-check --update
        UPDATE_SCRIPT="$HOME/.claude/hooks/cam-update-check.sh"
        if [ -f "$UPDATE_SCRIPT" ]; then
            "$UPDATE_SCRIPT" --update
        else
            echo -e "${RED}Error: cam-update-check.sh not found${NC}"
            exit 1
        fi
        ;;

    migrate)
        # Run migration script
        MIGRATE_SCRIPT="$HOME/.claude/hooks/migrate-insights.sh"
        if [ -f "$MIGRATE_SCRIPT" ]; then
            shift  # Remove 'migrate'
            "$MIGRATE_SCRIPT" "$@"
        else
            echo -e "${RED}Error: migrate-insights.sh not found${NC}"
            exit 1
        fi
        ;;

    release)
        # Release management: bump version and scaffold changelog
        NEW_VERSION="$2"
        CHANGELOG_MSG="$3"

        if [ -z "$NEW_VERSION" ]; then
            current=$(get_current_version)
            echo -e "${BLUE}[+] CAM Release Management${NC}"
            echo ""
            echo "Current version: $current"
            echo ""
            echo "Usage:"
            echo "  $0 release <version> [changelog-summary]"
            echo ""
            echo "Examples:"
            echo "  $0 release 1.2.6"
            echo "  $0 release 1.2.6 \"Added release command for version management\""
            echo ""
            echo "This command will:"
            echo "  1. Update VERSION.txt"
            echo "  2. Update CAM_VERSION in cam_core.py"
            echo "  3. Append changelog entry template to CHANGELOG.md"
            echo "  4. Show reminder of files that may need manual changelog details"
            exit 0
        fi

        # Validate version format (x.y.z)
        if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo -e "${RED}Error: Invalid version format. Use semantic versioning (e.g., 1.2.6)${NC}"
            exit 1
        fi

        current=$(get_current_version)
        echo -e "${BLUE}[+] CAM Release: $current --> $NEW_VERSION${NC}"
        echo ""

        # Step 1: Update VERSION.txt in template
        echo -e "${GREEN}1. Updating VERSION.txt...${NC}"
        echo "$NEW_VERSION" > "$TEMPLATE_DIR/VERSION.txt"
        echo "   [v] $TEMPLATE_DIR/VERSION.txt"

        # Step 2: Update CAM_VERSION in cam_core.py
        echo -e "${GREEN}2. Updating cam_core.py CAM_VERSION...${NC}"
        if [ -f "$TEMPLATE_DIR/cam_core.py" ]; then
            # Update the CAM_VERSION line (portable sed for Mac/Linux)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^CAM_VERSION = \".*\"/CAM_VERSION = \"$NEW_VERSION\"/" "$TEMPLATE_DIR/cam_core.py"
            else
                sed -i "s/^CAM_VERSION = \".*\"/CAM_VERSION = \"$NEW_VERSION\"/" "$TEMPLATE_DIR/cam_core.py"
            fi
            echo "   [v] $TEMPLATE_DIR/cam_core.py"
        else
            echo -e "${YELLOW}   [!] cam_core.py not found in template${NC}"
        fi

        # Step 3: Append changelog entry
        echo -e "${GREEN}3. Appending CHANGELOG.md entry...${NC}"
        CHANGELOG_FILE="$TEMPLATE_DIR/CHANGELOG.md"
        TODAY=$(date +%Y-%m-%d)

        # Create changelog entry
        CHANGELOG_ENTRY="
## [$NEW_VERSION] - $TODAY

### Added
- <!-- Describe new features -->

### Changed
- <!-- Describe changes to existing functionality -->

### Fixed
- <!-- Describe bug fixes -->

---
"
        # Insert after the "---" line following the header (line 14)
        if [ -f "$CHANGELOG_FILE" ]; then
            # Find line number of first "---" after line 10 and insert after it
            HEADER_END=$(awk 'NR>10 && /^---$/ {print NR; exit}' "$CHANGELOG_FILE")
            if [ -n "$HEADER_END" ]; then
                head -n "$HEADER_END" "$CHANGELOG_FILE" > "$CHANGELOG_FILE.tmp"
                echo "$CHANGELOG_ENTRY" >> "$CHANGELOG_FILE.tmp"
                tail -n +$((HEADER_END + 1)) "$CHANGELOG_FILE" >> "$CHANGELOG_FILE.tmp"
                mv "$CHANGELOG_FILE.tmp" "$CHANGELOG_FILE"
                echo "   [v] $CHANGELOG_FILE"
            else
                echo -e "${YELLOW}   [!] Could not find insertion point in CHANGELOG.md${NC}"
            fi
        else
            echo -e "${YELLOW}   [!] CHANGELOG.md not found${NC}"
        fi

        # Step 4: Show summary
        echo ""
        echo -e "${GREEN}==========================================${NC}"
        echo -e "${GREEN}[v] Release $NEW_VERSION scaffolded${NC}"
        echo -e "${GREEN}==========================================${NC}"
        echo ""
        echo -e "${YELLOW}[*] Next steps:${NC}"
        echo "  1. Edit CHANGELOG.md to fill in actual changes"
        echo "  2. Run: ./cam.sh upgrade --force  (to sync to project)"
        echo "  3. Commit changes"
        echo ""
        echo -e "${BLUE}Files modified:${NC}"
        echo "  - ~/.claude/cam-template/VERSION.txt"
        echo "  - ~/.claude/cam-template/cam_core.py"
        echo "  - ~/.claude/cam-template/CHANGELOG.md"
        ;;

    *)
        # Check venv
        check_venv

        # Pass through to Python
        "$VENV_PYTHON" "$CAM_CORE" "$@"
        ;;
esac

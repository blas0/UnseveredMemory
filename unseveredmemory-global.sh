#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# unseveredmemory-global.sh - Global Unsevered Memory Setup
# Version: 1.0.0
# ═══════════════════════════════════════════════════════════════════════════
#
# PURPOSE: Set up global Claude Code configuration with memory hooks
#
# USAGE:
#   ./unseveredmemory-global.sh           # Install to ~/.claude/
#   ./unseveredmemory-global.sh --uninstall  # Remove hooks
#
# CREATES:
#   ~/.claude/
#   ├── CLAUDE.md                    # Global instructions with memory protocol
#   ├── settings.json                # Hook configurations
#   ├── unseveredmemory-project.sh   # Project scaffolding script
#   └── hooks/
#       ├── session-start.sh         # Memory primer hook
#       └── session-end.sh           # Memory reminder hook
#
# ═══════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
    echo "Unsevered Memory - Global Setup"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help        Show this help message"
    echo "  --uninstall   Remove Unsevered Memory hooks"
    echo ""
    echo "This script sets up:"
    echo "  • ~/.claude/CLAUDE.md                   - Global instructions"
    echo "  • ~/.claude/settings.json               - Hook configurations"
    echo "  • ~/.claude/unseveredmemory-project.sh  - Project scaffolding"
    echo "  • ~/.claude/hooks/                      - Session hooks"
    echo ""
    echo "After setup, scaffold new projects with:"
    echo "  ~/.claude/unseveredmemory-project.sh [project-dir]"
}

# ─────────────────────────────────────────────────────────────────────────────
# Uninstall
# ─────────────────────────────────────────────────────────────────────────────

uninstall() {
    echo -e "${YELLOW}Uninstalling Unsevered Memory...${NC}"

    # Remove hooks
    rm -f "$HOOKS_DIR/session-start.sh"
    rm -f "$HOOKS_DIR/session-end.sh"

    # Remove project script
    rm -f "$CLAUDE_DIR/unseveredmemory-project.sh"

    # Remove hook entries from settings.json if it exists
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        # Create backup
        cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.backup"

        # Remove hook entries (keep other settings)
        jq 'del(.hooks)' "$CLAUDE_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp" && \
            mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"

        echo -e "${GREEN}[✓] Removed hooks from settings.json${NC}"
    fi

    echo -e "${GREEN}[✓] Uninstall complete${NC}"
    echo ""
    echo "Note: CLAUDE.md was preserved. Delete manually if desired:"
    echo "  rm ~/.claude/CLAUDE.md"
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────────────────────────

case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --uninstall)
        uninstall
        ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# Main Installation
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Unsevered Memory - Global Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Create directories
mkdir -p "$CLAUDE_DIR" "$HOOKS_DIR"
echo -e "${GREEN}[✓] Created ~/.claude/ directory${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Install CLAUDE.md
# ─────────────────────────────────────────────────────────────────────────────

if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    echo -e "${YELLOW}[!] ~/.claude/CLAUDE.md already exists${NC}"
    read -p "    Overwrite? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo -e "    Keeping existing CLAUDE.md"
    else
        cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
        echo -e "    Backed up to CLAUDE.md.backup"
        INSTALL_CLAUDE_MD=true
    fi
else
    INSTALL_CLAUDE_MD=true
fi

if [ "${INSTALL_CLAUDE_MD:-}" = "true" ]; then
    cat > "$CLAUDE_DIR/CLAUDE.md" << 'GLOBALCLAUDEMD'
# Global Claude Instructions

## Coding Preferences

- Use conventional commits (feat, fix, docs, chore, refactor, test)
- Always create PRs for completed work
- Prefer functional programming patterns where appropriate
- Write clear, self-documenting code

## Memory Protocol

For projects with `.claude/memory/`:

### Session Start
- Read `context.md` to understand current state
- Reference relevant `.ai/` docs as needed

### During Work
- Consult `.ai/patterns/` before implementing
- Check `decisions.md` before architectural changes

### Session End
- Update `context.md` with current state
- Append significant decisions to `decisions.md`
- Log daily summary in `sessions/YYYY-MM-DD.md` (optional)

## Documentation Protocol

For projects with `.ai/`:

### Two Sources of Truth
1. **`.ai/`** - Static documentation (architecture, patterns, workflows)
2. **`.claude/memory/`** - Dynamic memory (context, decisions, sessions)

### Documentation Rules
- Each fact exists in ONE location
- Cross-reference, never duplicate
- Version numbers ONLY in `.ai/core/technology-stack.md`

## Quick Reference

| Topic | Location |
|-------|----------|
| Memory State | `.claude/memory/context.md` |
| Decisions | `.claude/memory/decisions.md` |
| Patterns | `.ai/patterns/` |
| Documentation | `.ai/` |
| Tech Stack | `.ai/core/technology-stack.md` |

## Completion Protocol

When work is complete, **always** finish with:

1. **Commit** changes with descriptive message
2. **Push** to remote branch
3. **Create PR** with summary and test plan
4. **Report** PR URL to user
GLOBALCLAUDEMD
    echo -e "${GREEN}[✓] Installed ~/.claude/CLAUDE.md${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Install Hooks
# ─────────────────────────────────────────────────────────────────────────────

# Copy session-start.sh
if [ -f "$SCRIPT_DIR/hooks/session-start.sh" ]; then
    cp "$SCRIPT_DIR/hooks/session-start.sh" "$HOOKS_DIR/session-start.sh"
    chmod +x "$HOOKS_DIR/session-start.sh"
    echo -e "${GREEN}[✓] Installed session-start.sh hook${NC}"
else
    # Create inline if template not found
    cat > "$HOOKS_DIR/session-start.sh" << 'SESSIONSTART'
#!/bin/bash
# Unsevered Memory - Session Start Hook
# Version: 1.0.0
set -e

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [[ -z "$CWD" ]]; then
    echo '{"continue": true}'
    exit 0
fi

MEMORY_DIR="$CWD/.claude/memory"
CONTEXT_FILE="$MEMORY_DIR/context.md"

if [[ ! -d "$MEMORY_DIR" ]]; then
    echo '{"continue": true}'
    exit 0
fi

CONTEXT=""

if [[ -f "$CONTEXT_FILE" ]]; then
    CONTEXT="## Session Memory

$(cat "$CONTEXT_FILE")

---
"
fi

SESSIONS_DIR="$MEMORY_DIR/sessions"
if [[ -d "$SESSIONS_DIR" ]]; then
    RECENT_SESSIONS=""
    for i in {0..2}; do
        DATE=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || date -d "-$i days" +%Y-%m-%d 2>/dev/null || echo "")
        SESSION_FILE="$SESSIONS_DIR/$DATE.md"
        if [[ -f "$SESSION_FILE" ]]; then
            RECENT_SESSIONS="$RECENT_SESSIONS
### Session: $DATE
$(head -50 "$SESSION_FILE")
"
        fi
    done

    if [[ -n "$RECENT_SESSIONS" ]]; then
        CONTEXT="$CONTEXT
## Recent Sessions
$RECENT_SESSIONS
---
"
    fi
fi

if [[ -n "$CONTEXT" ]]; then
    jq -n --arg context "$CONTEXT" '{continue: true, additionalContext: $context}'
else
    echo '{"continue": true}'
fi
SESSIONSTART
    chmod +x "$HOOKS_DIR/session-start.sh"
    echo -e "${GREEN}[✓] Created session-start.sh hook${NC}"
fi

# Copy session-end.sh
if [ -f "$SCRIPT_DIR/hooks/session-end.sh" ]; then
    cp "$SCRIPT_DIR/hooks/session-end.sh" "$HOOKS_DIR/session-end.sh"
    chmod +x "$HOOKS_DIR/session-end.sh"
    echo -e "${GREEN}[✓] Installed session-end.sh hook${NC}"
else
    # Create inline if template not found
    cat > "$HOOKS_DIR/session-end.sh" << 'SESSIONEND'
#!/bin/bash
# Unsevered Memory - Session End Hook
# Version: 1.0.0
set -e

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [[ -z "$CWD" ]]; then
    echo '{"continue": true}'
    exit 0
fi

MEMORY_DIR="$CWD/.claude/memory"

if [[ ! -d "$MEMORY_DIR" ]]; then
    echo '{"continue": true}'
    exit 0
fi

DATE=$(date +%Y-%m-%d)

REMINDER="**Session Memory Reminder**

Before ending, consider updating:

1. **\`.claude/memory/context.md\`** - Current state
   - What task is in progress?
   - What files were modified?
   - What's pending/blocked?

2. **\`.claude/memory/decisions.md\`** - Append any architectural decisions made

3. **\`.claude/memory/sessions/$DATE.md\`** (optional) - Daily session notes"

jq -n --arg reminder "$REMINDER" '{continue: true, additionalContext: $reminder}'
SESSIONEND
    chmod +x "$HOOKS_DIR/session-end.sh"
    echo -e "${GREEN}[✓] Created session-end.sh hook${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Install Project Script
# ─────────────────────────────────────────────────────────────────────────────

if [ -f "$SCRIPT_DIR/unseveredmemory-project.sh" ]; then
    cp "$SCRIPT_DIR/unseveredmemory-project.sh" "$CLAUDE_DIR/unseveredmemory-project.sh"
    chmod +x "$CLAUDE_DIR/unseveredmemory-project.sh"
    echo -e "${GREEN}[✓] Installed ~/.claude/unseveredmemory-project.sh${NC}"
else
    echo -e "${YELLOW}[!] unseveredmemory-project.sh not found in $SCRIPT_DIR${NC}"
    echo -e "${YELLOW}    Project scaffolding will need to be run from source location${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Configure settings.json
# ─────────────────────────────────────────────────────────────────────────────

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Define the hooks configuration
HOOKS_CONFIG='{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-start.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-end.sh"
          }
        ]
      }
    ]
  }
}'

if [ -f "$SETTINGS_FILE" ]; then
    # Backup existing
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

    # Merge hooks into existing settings
    EXISTING=$(cat "$SETTINGS_FILE")
    echo "$EXISTING" | jq --argjson hooks "$(echo "$HOOKS_CONFIG" | jq '.hooks')" '. + {hooks: $hooks}' > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo -e "${GREEN}[✓] Updated settings.json with hooks${NC}"
else
    # Create new settings.json
    echo "$HOOKS_CONFIG" | jq '.' > "$SETTINGS_FILE"
    echo -e "${GREEN}[✓] Created settings.json with hooks${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Complete
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Global Setup Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Installed:"
echo "  ~/.claude/CLAUDE.md                   - Global instructions"
echo "  ~/.claude/settings.json               - Hook configurations"
echo "  ~/.claude/unseveredmemory-project.sh  - Project scaffolding"
echo "  ~/.claude/hooks/session-start.sh"
echo "  ~/.claude/hooks/session-end.sh"
echo ""
echo "To scaffold a new project:"
echo "  ~/.claude/unseveredmemory-project.sh [project-dir]"
echo ""
echo "To uninstall:"
echo "  $0 --uninstall"

#!/bin/bash
# migrate-to-cognitive.sh - Migrate CAM hooks from v2.0.x to v2.1.0 Cognitive Architecture
# Version: 2.1.0
#
# This script safely migrates existing CAM installations to the new Cognitive Hook Architecture.
# It backs up existing hooks, deploys new cognitive system, and preserves user customizations.

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

HOOKS_DIR="$HOME/.claude/hooks"
BACKUP_DIR="$HOME/.claude/hooks-backup-$(date +%Y%m%d-%H%M%S)"
TEMPLATE_DIR="$HOME/.claude/cam-template"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CAM Cognitive Architecture Migration (v2.0.x → v2.1.0)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}[1/5] Checking prerequisites...${NC}"

if [ ! -d "$HOOKS_DIR" ]; then
    echo -e "  ${YELLOW}[!] No existing hooks directory found${NC}"
    echo -e "  ${GREEN}[v] Fresh installation - no migration needed${NC}"
    echo -e "  Run: ~/.claude/hooks/cam-sync-template.sh"
    exit 0
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo -e "  ${RED}[x] Template directory not found: $TEMPLATE_DIR${NC}"
    echo -e "  Please ensure CAM template is installed first"
    exit 1
fi

# Check current version
CURRENT_VERSION="unknown"
if [ -f "$HOOKS_DIR/../cam-template/VERSION.txt" ]; then
    CURRENT_VERSION=$(cat "$HOOKS_DIR/../cam-template/VERSION.txt" 2>/dev/null || echo "unknown")
fi
echo -e "  Current version: ${YELLOW}$CURRENT_VERSION${NC}"
echo -e "  Target version:  ${GREEN}2.1.0${NC}"

# Check if already migrated
if [ -f "$HOOKS_DIR/cam-cognitive.sh" ]; then
    echo -e "  ${GREEN}[v] Cognitive system already installed${NC}"
    read -p "  Re-run migration anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "  ${BLUE}Migration cancelled${NC}"
        exit 0
    fi
fi

echo -e "  ${GREEN}[v] Prerequisites OK${NC}"
echo ""

# Create backup
echo -e "${BLUE}[2/5] Creating backup...${NC}"
mkdir -p "$BACKUP_DIR"

# Backup existing hooks
HOOKS_TO_BACKUP=(
    "session-start.sh"
    "session-end.sh"
    "prompt-cam.sh"
    "query-cam.sh"
    "update-cam.sh"
    "crystallize.sh"
    "suggest-compact.sh"
)

for hook in "${HOOKS_TO_BACKUP[@]}"; do
    if [ -f "$HOOKS_DIR/$hook" ]; then
        cp "$HOOKS_DIR/$hook" "$BACKUP_DIR/"
        echo -e "  ${GREEN}[v]${NC} Backed up: $hook"
    fi
done

# Backup settings.json
if [ -f "$HOME/.claude/settings.json" ]; then
    cp "$HOME/.claude/settings.json" "$BACKUP_DIR/"
    echo -e "  ${GREEN}[v]${NC} Backed up: settings.json"
fi

echo -e "  ${GREEN}[v] Backup created: $BACKUP_DIR${NC}"
echo ""

# Check for user customizations
echo -e "${BLUE}[3/5] Checking for customizations...${NC}"
CUSTOMIZATIONS_FOUND=false

for hook in "${HOOKS_TO_BACKUP[@]}"; do
    if [ -f "$BACKUP_DIR/$hook" ]; then
        # Check if hook was modified from template
        if [ -f "$TEMPLATE_DIR/hooks/$hook" ]; then
            if ! diff -q "$BACKUP_DIR/$hook" "$TEMPLATE_DIR/hooks/$hook" >/dev/null 2>&1; then
                echo -e "  ${YELLOW}[!] Customized: $hook${NC}"
                CUSTOMIZATIONS_FOUND=true
            fi
        fi
    fi
done

if [ "$CUSTOMIZATIONS_FOUND" = true ]; then
    echo -e "  ${YELLOW}[!] Custom modifications detected${NC}"
    echo -e "  ${YELLOW}    These will be preserved in: $BACKUP_DIR${NC}"
    echo -e "  ${YELLOW}    Review after migration to re-apply customizations${NC}"
else
    echo -e "  ${GREEN}[v] No customizations detected${NC}"
fi
echo ""

# Deploy new cognitive system
echo -e "${BLUE}[4/5] Deploying Cognitive Hook Architecture...${NC}"

# Run the sync template script
if [ -x "$TEMPLATE_DIR/hooks/cam-sync-template.sh" ]; then
    "$TEMPLATE_DIR/hooks/cam-sync-template.sh" --all
else
    echo -e "  ${RED}[x] cam-sync-template.sh not found or not executable${NC}"
    exit 1
fi
echo ""

# Verify deployment
echo -e "${BLUE}[5/5] Verifying deployment...${NC}"

REQUIRED_FILES=(
    "memory_bus_core.sh"
    "cam-cognitive.sh"
    "session-start.sh"
    "session-end.sh"
    "prompt-cam.sh"
    "query-cam.sh"
    "update-cam.sh"
    "pre-compact.sh"
    "stop.sh"
    "permission-request.sh"
    "subagent-stop.sh"
)

ALL_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$HOOKS_DIR/$file" ] && [ -x "$HOOKS_DIR/$file" ]; then
        echo -e "  ${GREEN}[v]${NC} $file"
    else
        echo -e "  ${RED}[x]${NC} Missing or not executable: $file"
        ALL_OK=false
    fi
done

echo ""

if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Migration Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}New Cognitive Functions:${NC}"
    echo -e "  ORIENT    (SessionStart)      - Establish context, load memories"
    echo -e "  PERCEIVE  (UserPromptSubmit)  - Understand intent, proactive retrieval"
    echo -e "  ATTEND    (PreToolUse)        - Focus attention, pattern retrieval"
    echo -e "  ENCODE    (PostToolUse)       - Store operations, create relationships"
    echo -e "  DECIDE    (PermissionRequest) - Evaluate permissions, record decisions"
    echo -e "  INTEGRATE (SubagentStop)      - Consolidate subagent results"
    echo -e "  HOLD      (PreCompact)        - Preserve critical context"
    echo -e "  REFLECT   (SessionEnd/Stop)   - Summarize session, consolidate knowledge"
    echo ""
    echo -e "${BLUE}Memory Bus:${NC}"
    echo -e "  Session state stored in: ~/.claude/.session-state/"
    echo -e "  Enables cross-hook communication and cognitive load tracking"
    echo ""
    echo -e "${BLUE}Backup location:${NC}"
    echo -e "  $BACKUP_DIR"
    echo ""
    if [ "$CUSTOMIZATIONS_FOUND" = true ]; then
        echo -e "${YELLOW}[!] Remember to review your customizations in the backup${NC}"
    fi
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  Migration encountered issues${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}To restore from backup:${NC}"
    echo -e "  cp $BACKUP_DIR/*.sh $HOOKS_DIR/"
    echo -e "  cp $BACKUP_DIR/settings.json ~/.claude/"
fi

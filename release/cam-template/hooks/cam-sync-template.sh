#!/bin/bash
# cam-sync-template.sh - Deploy CAM template to live locations
# Version: 2.1.0
# Usage: cam-sync-template.sh [--hooks-only | --settings-only | --all]
#
# DIRECTION: ~/.claude/cam-template/ → ~/.claude/hooks/ & settings.json

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

TEMPLATE_DIR="$HOME/.claude/cam-template"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}==> CAM Template Deploy${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Source: ${GREEN}$TEMPLATE_DIR${NC}"
echo -e "  Target: ${GREEN}$HOOKS_DIR${NC}"
echo ""

MODE="${1:---all}"

# Verify template exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo -e "${RED}[x] Template directory not found: $TEMPLATE_DIR${NC}"
    exit 1
fi

# Verify template hooks exist
if [ ! -d "$TEMPLATE_DIR/hooks" ]; then
    echo -e "${RED}[x] Template hooks directory not found: $TEMPLATE_DIR/hooks${NC}"
    exit 1
fi

deploy_hooks() {
    echo -e "${GREEN}--> Deploying hooks...${NC}"
    echo -e "  ${BLUE}FROM:${NC} $TEMPLATE_DIR/hooks/"
    echo -e "  ${BLUE}TO:${NC}   $HOOKS_DIR/"
    echo ""

    # Ensure target directory exists
    mkdir -p "$HOOKS_DIR"

    # Core cognitive system
    HOOKS=(
        "memory_bus_core.sh"
        "cam-cognitive.sh"
    )

    # Hook wrappers (delegate to cam-cognitive.sh)
    HOOK_WRAPPERS=(
        "session-start.sh"
        "prompt-cam.sh"
        "query-cam.sh"
        "update-cam.sh"
        "session-end.sh"
        "pre-compact.sh"
        "stop.sh"
        "permission-request.sh"
        "subagent-stop.sh"
    )

    # Utility scripts
    UTILITIES=(
        "cam-note.sh"
        "init-cam.sh"
        "cam-sync-template.sh"
        "scaffold-ai.sh"
    )

    # Deploy core cognitive system first
    echo -e "  ${BLUE}[Core Cognitive System]${NC}"
    for hook in "${HOOKS[@]}"; do
        if [ -f "$TEMPLATE_DIR/hooks/$hook" ]; then
            cp "$TEMPLATE_DIR/hooks/$hook" "$HOOKS_DIR/"
            chmod +x "$HOOKS_DIR/$hook"
            echo -e "  ${GREEN}[v]${NC} $hook"
        else
            echo -e "  ${YELLOW}[!]  Not in template: $hook${NC}"
        fi
    done

    echo ""
    echo -e "  ${BLUE}[Hook Wrappers]${NC}"
    for hook in "${HOOK_WRAPPERS[@]}"; do
        if [ -f "$TEMPLATE_DIR/hooks/$hook" ]; then
            cp "$TEMPLATE_DIR/hooks/$hook" "$HOOKS_DIR/"
            chmod +x "$HOOKS_DIR/$hook"
            echo -e "  ${GREEN}[v]${NC} $hook"
        else
            echo -e "  ${YELLOW}[!]  Not in template: $hook${NC}"
        fi
    done

    echo ""
    echo -e "  ${BLUE}[Utilities]${NC}"
    for hook in "${UTILITIES[@]}"; do
        if [ -f "$TEMPLATE_DIR/hooks/$hook" ]; then
            cp "$TEMPLATE_DIR/hooks/$hook" "$HOOKS_DIR/"
            chmod +x "$HOOKS_DIR/$hook"
            echo -e "  ${GREEN}[v]${NC} $hook"
        else
            echo -e "  ${YELLOW}[!]  Not in template: $hook${NC}"
        fi
    done
}

deploy_settings() {
    echo -e "${GREEN}==>  Deploying settings...${NC}"
    echo -e "  ${BLUE}FROM:${NC} $TEMPLATE_DIR/settings-hooks.json"
    echo -e "  ${BLUE}TO:${NC}   $SETTINGS_FILE (merge)"
    echo ""

    if [ ! -f "$TEMPLATE_DIR/settings-hooks.json" ]; then
        echo -e "  ${YELLOW}[!]  No settings-hooks.json in template, skipping${NC}"
        return
    fi

    if [ ! -f "$SETTINGS_FILE" ]; then
        # No existing settings, just copy the hooks settings
        cp "$TEMPLATE_DIR/settings-hooks.json" "$SETTINGS_FILE"
        # Substitute __HOME__ placeholder with actual home path
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|__HOME__|$HOME|g" "$SETTINGS_FILE"
        else
            sed -i "s|__HOME__|$HOME|g" "$SETTINGS_FILE"
        fi
        echo -e "  ${GREEN}[v]${NC} Created settings.json from template"
    else
        # Merge: template hooks settings INTO existing settings
        # This preserves any non-hook settings the user has
        TEMP_FILE=$(mktemp)

        # Use jq to merge: existing settings + template hooks (template wins for hooks key)
        jq -s '.[0] * .[1]' "$SETTINGS_FILE" "$TEMPLATE_DIR/settings-hooks.json" > "$TEMP_FILE" 2>/dev/null

        if [ $? -eq 0 ] && [ -s "$TEMP_FILE" ]; then
            mv "$TEMP_FILE" "$SETTINGS_FILE"
            # Substitute __HOME__ placeholder with actual home path
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|__HOME__|$HOME|g" "$SETTINGS_FILE"
            else
                sed -i "s|__HOME__|$HOME|g" "$SETTINGS_FILE"
            fi
            echo -e "  ${GREEN}[v]${NC} Merged hooks into settings.json"
        else
            rm -f "$TEMP_FILE"
            echo -e "  ${RED}[x]${NC} Failed to merge settings (jq error)"
            echo -e "  ${YELLOW}Tip: Manually copy hooks section from settings-hooks.json${NC}"
        fi
    fi
}

show_status() {
    echo ""
    echo -e "${BLUE}[#] Deployment Status${NC}"
    echo -e "  Template version: $(cat $TEMPLATE_DIR/VERSION.txt 2>/dev/null || echo 'unknown')"
    echo ""

    echo -e "${BLUE}--> Live hooks (deployed):${NC}"
    ls -la "$HOOKS_DIR"/*.sh 2>/dev/null | while read line; do
        echo "  $line"
    done

    echo ""
    echo -e "${BLUE}==>  Settings hooks section:${NC}"
    if [ -f "$SETTINGS_FILE" ]; then
        jq '.hooks | keys' "$SETTINGS_FILE" 2>/dev/null | head -20 || echo "  (unable to parse)"
    else
        echo "  (no settings.json)"
    fi
}

case "$MODE" in
    --hooks-only)
        deploy_hooks
        ;;
    --settings-only)
        deploy_settings
        ;;
    --all|*)
        deploy_hooks
        echo ""
        deploy_settings
        ;;
esac

show_status

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[v] Deployment Complete${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}[*] Remember:${NC}"
echo -e "  • Edit files in ${GREEN}~/.claude/cam-template/${NC} (source of truth)"
echo -e "  • Run this script to deploy changes to live locations"
echo -e "  • Projects upgrade via: ${GREEN}./cam.sh upgrade${NC}"
echo ""

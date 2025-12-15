#!/bin/bash
# ===============================================================================
# CAM Setup Script - Automated Installation
# ===============================================================================
#
# This script handles complete CAM installation:
#   1. Checks prerequisites (Python 3.9+, jq)
#   2. Deploys cam-template to ~/.claude/
#   3. Installs hooks to ~/.claude/hooks/
#   4. Generates settings.json with correct paths
#   5. Configures Gemini API key
#
# Usage: ./setup.sh
#
# ===============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TEMPLATE_DIR="$CLAUDE_DIR/cam-template"
HOOKS_DIR="$CLAUDE_DIR/hooks"

echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}    CAM - Continuous Architectural Memory${NC}"
echo -e "${BLUE}    Installation Script v2.0.3${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""

# -------------------------------------------------------------------------------
# Prerequisites Check
# -------------------------------------------------------------------------------

echo -e "${GREEN}[1/8] Checking prerequisites...${NC}"

# Detect package manager
PKG_MANAGER=""
if command -v brew &> /dev/null; then
    PKG_MANAGER="brew"
elif command -v apt &> /dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
fi

# Track missing packages
MISSING_PKGS=()

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 9 ]; then
        echo -e "  [v] Python $PYTHON_VERSION"
    else
        echo -e "  ${RED}[x] Python 3.9+ required (found $PYTHON_VERSION)${NC}"
        echo -e "  Please upgrade Python manually: https://www.python.org/downloads/"
        exit 1
    fi
else
    echo -e "  ${RED}[x] Python 3 not found${NC}"
    echo -e "  Please install Python 3.9+: https://www.python.org/downloads/"
    exit 1
fi

# Check jq
if command -v jq &> /dev/null; then
    echo -e "  [v] jq $(jq --version)"
else
    echo -e "  ${YELLOW}[!] jq not found${NC}"
    MISSING_PKGS+=("jq")
fi

# Check sqlite3
if command -v sqlite3 &> /dev/null; then
    echo -e "  [v] sqlite3 $(sqlite3 --version | cut -d' ' -f1)"
else
    echo -e "  ${YELLOW}[!] sqlite3 not found${NC}"
    case "$PKG_MANAGER" in
        dnf|yum) MISSING_PKGS+=("sqlite") ;;
        *) MISSING_PKGS+=("sqlite3") ;;
    esac
fi

# Auto-install missing packages
if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}Missing packages: ${MISSING_PKGS[*]}${NC}"

    if [ -n "$PKG_MANAGER" ]; then
        echo -e "  Detected package manager: ${BLUE}$PKG_MANAGER${NC}"
        read -p "  Install missing packages automatically? (Y/n): " AUTO_INSTALL
        AUTO_INSTALL=${AUTO_INSTALL:-Y}

        if [[ $AUTO_INSTALL =~ ^[Yy]$ ]]; then
            echo -e "  ${BLUE}Installing ${MISSING_PKGS[*]}...${NC}"

            case "$PKG_MANAGER" in
                brew)
                    brew install "${MISSING_PKGS[@]}"
                    ;;
                apt)
                    sudo apt update && sudo apt install -y "${MISSING_PKGS[@]}"
                    ;;
                dnf)
                    sudo dnf install -y "${MISSING_PKGS[@]}"
                    ;;
                yum)
                    sudo yum install -y "${MISSING_PKGS[@]}"
                    ;;
            esac

            # Verify installation
            INSTALL_FAILED=0
            if ! command -v jq &> /dev/null && [[ " ${MISSING_PKGS[*]} " =~ " jq " ]]; then
                echo -e "  ${RED}[x] jq installation failed${NC}"
                INSTALL_FAILED=1
            fi
            if ! command -v sqlite3 &> /dev/null; then
                echo -e "  ${RED}[x] sqlite3 installation failed${NC}"
                INSTALL_FAILED=1
            fi

            if [ $INSTALL_FAILED -eq 1 ]; then
                echo -e "  ${RED}Some packages failed to install. Please install manually.${NC}"
                exit 1
            fi

            echo -e "  ${GREEN}[v] Packages installed successfully${NC}"
        else
            echo -e "  ${RED}Please install missing packages manually:${NC}"
            case "$PKG_MANAGER" in
                brew) echo -e "    brew install ${MISSING_PKGS[*]}" ;;
                apt) echo -e "    sudo apt install ${MISSING_PKGS[*]}" ;;
                dnf) echo -e "    sudo dnf install ${MISSING_PKGS[*]}" ;;
                yum) echo -e "    sudo yum install ${MISSING_PKGS[*]}" ;;
            esac
            exit 1
        fi
    else
        echo -e "  ${RED}No supported package manager found (brew/apt/dnf/yum)${NC}"
        echo -e "  Please install manually: ${MISSING_PKGS[*]}"
        exit 1
    fi
fi

# Check if running from correct directory
if [ ! -f "$SCRIPT_DIR/cam-template/cam_core.py" ]; then
    echo -e "  ${RED}[x] cam-template not found in current directory${NC}"
    echo -e "  Please run this script from the CAM release directory"
    exit 1
fi

echo -e "  [v] All prerequisites met"
echo ""

# -------------------------------------------------------------------------------
# Create Directory Structure
# -------------------------------------------------------------------------------

echo -e "${GREEN}[2/8] Creating directory structure...${NC}"

mkdir -p "$CLAUDE_DIR"
mkdir -p "$HOOKS_DIR"
mkdir -p "$CLAUDE_DIR/agents"

echo -e "  [v] Created $CLAUDE_DIR"
echo -e "  [v] Created $HOOKS_DIR"
echo -e "  [v] Created $CLAUDE_DIR/agents"
echo ""

# -------------------------------------------------------------------------------
# Deploy Template
# -------------------------------------------------------------------------------

echo -e "${GREEN}[3/8] Deploying CAM template...${NC}"

if [ -d "$TEMPLATE_DIR" ]; then
    echo -e "  ${YELLOW}[!] Existing template found at $TEMPLATE_DIR${NC}"
    read -p "  Overwrite? (y/N): " OVERWRITE_TEMPLATE
    if [[ $OVERWRITE_TEMPLATE =~ ^[Yy]$ ]]; then
        rm -rf "$TEMPLATE_DIR"
        cp -r "$SCRIPT_DIR/cam-template" "$TEMPLATE_DIR"
        echo -e "  [v] Template updated"
    else
        echo -e "  [>] Skipped. To manually update, run:"
        echo -e "      ${BLUE}rm -rf $TEMPLATE_DIR && cp -r $SCRIPT_DIR/cam-template $TEMPLATE_DIR${NC}"
    fi
else
    cp -r "$SCRIPT_DIR/cam-template" "$TEMPLATE_DIR"
    echo -e "  [v] Template installed to $TEMPLATE_DIR"
fi
echo ""

# -------------------------------------------------------------------------------
# Deploy Hooks
# -------------------------------------------------------------------------------

echo -e "${GREEN}[4/8] Installing hooks...${NC}"

# Check if hooks already exist
EXISTING_HOOKS=0
for hook in "$SCRIPT_DIR/cam-template/hooks/"*.sh; do
    HOOK_NAME=$(basename "$hook")
    if [ -f "$HOOKS_DIR/$HOOK_NAME" ]; then
        EXISTING_HOOKS=1
        break
    fi
done

if [ $EXISTING_HOOKS -eq 1 ]; then
    echo -e "  ${YELLOW}[!] Existing hooks found in $HOOKS_DIR${NC}"
    read -p "  Overwrite all hooks? (y/N): " OVERWRITE_HOOKS
    if [[ $OVERWRITE_HOOKS =~ ^[Yy]$ ]]; then
        for hook in "$SCRIPT_DIR/cam-template/hooks/"*.sh; do
            if [ -f "$hook" ]; then
                HOOK_NAME=$(basename "$hook")
                cp "$hook" "$HOOKS_DIR/"
                chmod +x "$HOOKS_DIR/$HOOK_NAME"
                echo -e "  [v] $HOOK_NAME"
            fi
        done
    else
        echo -e "  [>] Skipped. To manually update hooks, run:"
        echo -e "      ${BLUE}cp $SCRIPT_DIR/cam-template/hooks/*.sh $HOOKS_DIR/${NC}"
        echo -e "      ${BLUE}chmod +x $HOOKS_DIR/*.sh${NC}"
    fi
else
    for hook in "$SCRIPT_DIR/cam-template/hooks/"*.sh; do
        if [ -f "$hook" ]; then
            HOOK_NAME=$(basename "$hook")
            cp "$hook" "$HOOKS_DIR/"
            chmod +x "$HOOKS_DIR/$HOOK_NAME"
            echo -e "  [v] $HOOK_NAME"
        fi
    done
fi
echo ""

# -------------------------------------------------------------------------------
# Deploy Agents
# -------------------------------------------------------------------------------

echo -e "${GREEN}[5/8] Installing agents...${NC}"

AGENTS_DIR="$CLAUDE_DIR/agents"

# Check if agents already exist
if [ -d "$SCRIPT_DIR/agents" ]; then
    EXISTING_AGENTS=0
    for agent in "$SCRIPT_DIR/agents/"*.md; do
        AGENT_NAME=$(basename "$agent")
        if [ -f "$AGENTS_DIR/$AGENT_NAME" ]; then
            EXISTING_AGENTS=1
            break
        fi
    done

    if [ $EXISTING_AGENTS -eq 1 ]; then
        echo -e "  ${YELLOW}[!] Existing agents found in $AGENTS_DIR${NC}"
        read -p "  Overwrite all agents? (y/N): " OVERWRITE_AGENTS
        if [[ $OVERWRITE_AGENTS =~ ^[Yy]$ ]]; then
            for agent in "$SCRIPT_DIR/agents/"*.md; do
                if [ -f "$agent" ]; then
                    AGENT_NAME=$(basename "$agent")
                    cp "$agent" "$AGENTS_DIR/"
                    echo -e "  [v] $AGENT_NAME"
                fi
            done
        else
            echo -e "  [>] Skipped. To manually update agents, run:"
            echo -e "      ${BLUE}cp $SCRIPT_DIR/agents/*.md $AGENTS_DIR/${NC}"
        fi
    else
        for agent in "$SCRIPT_DIR/agents/"*.md; do
            if [ -f "$agent" ]; then
                AGENT_NAME=$(basename "$agent")
                cp "$agent" "$AGENTS_DIR/"
                echo -e "  [v] $AGENT_NAME"
            fi
        done
    fi
else
    echo -e "  ${YELLOW}[!] No agents directory found in release${NC}"
fi
echo ""

# -------------------------------------------------------------------------------
# Configure Settings
# -------------------------------------------------------------------------------

echo -e "${GREEN}[6/8] Configuring Claude Code settings...${NC}"

# Generate settings.json with correct paths for THIS user
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Create hooks configuration with user's actual home path
HOOKS_CONFIG=$(cat << EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-start.sh",
            "timeout": 60
          },
          {
            "type": "command",
            "command": "$HOOKS_DIR/cam-update-check.sh hook",
            "timeout": 15
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/prompt-cam.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|Read|Edit|Write|Glob|Grep|Task",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/query-cam.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|Read|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/update-cam.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/session-end.sh",
            "timeout": 60
          },
          {
            "type": "command",
            "command": "$HOOKS_DIR/insight-extract.sh extract",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
EOF
)

if [ -f "$SETTINGS_FILE" ]; then
    echo -e "  ${YELLOW}[!] Existing settings.json found${NC}"

    # Check if hooks are already configured
    if grep -q "SessionStart" "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "  ${YELLOW}[!] Hooks already configured in settings.json${NC}"
        read -p "  Replace hooks configuration? (y/N): " REPLACE_HOOKS
        if [[ $REPLACE_HOOKS =~ ^[Yy]$ ]]; then
            # Merge: keep existing settings, replace hooks
            TEMP_FILE=$(mktemp)
            echo "$HOOKS_CONFIG" > "$TEMP_FILE"
            jq -s '.[0] * .[1]' "$SETTINGS_FILE" "$TEMP_FILE" > "${SETTINGS_FILE}.new"
            mv "${SETTINGS_FILE}.new" "$SETTINGS_FILE"
            rm "$TEMP_FILE"
            echo -e "  [v] Hooks configuration updated"
        else
            echo -e "  [>] Skipped. To manually update, merge hooks from:"
            echo -e "      ${BLUE}$SCRIPT_DIR/cam-template/settings-hooks.json${NC}"
            echo -e "      Replace __HOME__ with your home path: ${BLUE}$HOME${NC}"
        fi
    else
        # No hooks yet - ask before adding
        read -p "  Add hooks to existing settings.json? (y/N): " ADD_HOOKS
        if [[ $ADD_HOOKS =~ ^[Yy]$ ]]; then
            TEMP_FILE=$(mktemp)
            echo "$HOOKS_CONFIG" > "$TEMP_FILE"
            jq -s '.[0] * .[1]' "$SETTINGS_FILE" "$TEMP_FILE" > "${SETTINGS_FILE}.new"
            mv "${SETTINGS_FILE}.new" "$SETTINGS_FILE"
            rm "$TEMP_FILE"
            echo -e "  [v] Hooks added to existing settings"
        else
            echo -e "  [>] Skipped. To manually add hooks, run:"
            echo -e "      ${BLUE}jq -s '.[0] * .[1]' $SETTINGS_FILE $SCRIPT_DIR/cam-template/settings-hooks.json > settings.tmp && mv settings.tmp $SETTINGS_FILE${NC}"
            echo -e "      Then replace __HOME__ with: ${BLUE}$HOME${NC}"
        fi
    fi
else
    # Create new settings file
    echo "$HOOKS_CONFIG" > "$SETTINGS_FILE"
    echo -e "  [v] Created $SETTINGS_FILE"
fi
echo ""

# -------------------------------------------------------------------------------
# Configure API Key
# -------------------------------------------------------------------------------

echo -e "${GREEN}[7/8] Configuring Gemini API key...${NC}"

ENV_FILE="$HOOKS_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo -e "  ${YELLOW}[!] Existing .env found${NC}"
    if grep -q "GEMINI_API_KEY" "$ENV_FILE" 2>/dev/null; then
        CURRENT_KEY=$(grep "GEMINI_API_KEY" "$ENV_FILE" | cut -d'=' -f2)
        if [ -n "$CURRENT_KEY" ] && [ "$CURRENT_KEY" != "your-api-key-here" ]; then
            echo -e "  [v] API key already configured"
        else
            read -p "  Replace placeholder with real API key? (y/N): " REPLACE_KEY
            if [[ $REPLACE_KEY =~ ^[Yy]$ ]]; then
                read -p "  Enter your Gemini API key: " API_KEY
                if [ -n "$API_KEY" ]; then
                    echo "GEMINI_API_KEY=$API_KEY" > "$ENV_FILE"
                    echo -e "  [v] API key saved"
                else
                    echo -e "  [>] Skipped. To manually set, edit:"
                    echo -e "      ${BLUE}$ENV_FILE${NC}"
                fi
            else
                echo -e "  [>] Skipped. To manually set, edit:"
                echo -e "      ${BLUE}$ENV_FILE${NC}"
            fi
        fi
    fi
else
    echo -e "  CAM uses Google's Gemini API for embeddings."
    echo -e "  Get your API key at: ${BLUE}https://aistudio.google.com/apikey${NC}"
    echo ""
    read -p "  Enter your Gemini API key (or press Enter to skip): " API_KEY

    if [ -n "$API_KEY" ]; then
        echo "GEMINI_API_KEY=$API_KEY" > "$ENV_FILE"
        echo -e "  [v] API key saved to $ENV_FILE"
    else
        echo "GEMINI_API_KEY=your-api-key-here" > "$ENV_FILE"
        echo -e "  [>] Placeholder created. To set later, edit:"
        echo -e "      ${BLUE}$ENV_FILE${NC}"
    fi
fi
echo ""

# -------------------------------------------------------------------------------
# Install Global CLAUDE.md
# -------------------------------------------------------------------------------

echo -e "${GREEN}[8/8] Installing global CLAUDE.md...${NC}"

GLOBAL_CLAUDE="$CLAUDE_DIR/CLAUDE.md"

if [ -f "$GLOBAL_CLAUDE" ]; then
    echo -e "  ${YELLOW}[!] Existing ~/.claude/CLAUDE.md found${NC}"
    read -p "  Overwrite? (y/N): " OVERWRITE_CLAUDE
    if [[ $OVERWRITE_CLAUDE =~ ^[Yy]$ ]]; then
        if [ -f "$SCRIPT_DIR/global-claude.md" ]; then
            cp "$SCRIPT_DIR/global-claude.md" "$GLOBAL_CLAUDE"
            echo -e "  [v] CLAUDE.md updated"
        fi
    else
        echo -e "  [>] Skipped. To manually update, run:"
        echo -e "      ${BLUE}cp $SCRIPT_DIR/global-claude.md $GLOBAL_CLAUDE${NC}"
        echo -e "      Or append: ${BLUE}cat $SCRIPT_DIR/global-claude.md >> $GLOBAL_CLAUDE${NC}"
    fi
else
    if [ -f "$SCRIPT_DIR/global-claude.md" ]; then
        cp "$SCRIPT_DIR/global-claude.md" "$GLOBAL_CLAUDE"
        echo -e "  [v] Created ~/.claude/CLAUDE.md"
    fi
fi
echo ""

# -------------------------------------------------------------------------------
# Complete
# -------------------------------------------------------------------------------

echo -e "${GREEN}===============================================================================${NC}"
echo -e "${GREEN}    Installation Complete!${NC}"
echo -e "${GREEN}===============================================================================${NC}"
echo ""
echo -e "${BLUE}Installed components:${NC}"
echo -e "  [*] CAM template:  $TEMPLATE_DIR"
echo -e "  [*] Hooks:         $HOOKS_DIR"
echo -e "  [*] Agents:        $CLAUDE_DIR/agents"
echo -e "  [*] Settings:      $SETTINGS_FILE"
echo -e "  [*] API config:    $ENV_FILE"
echo ""
echo -e "${BLUE}New in v2.0.3:${NC}"
echo -e "  [+] Insights Pipeline: Auto-extract session knowledge to .ai/.insights/"
echo -e "  [+] Update Checker: Daily checks for CAM updates"
echo -e "  [+] Migration Tool: Easy upgrades for existing installations"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Navigate to any project directory"
echo -e "  2. Run: ${GREEN}~/.claude/hooks/init-cam.sh${NC}"
echo -e "  3. Start Claude Code: ${GREEN}claude${NC}"
echo ""
echo -e "${BLUE}Configure update checking (optional):${NC}"
echo -e "  ${GREEN}~/.claude/hooks/cam-update-check.sh --configure https://github.com/your-org/cam-system.git${NC}"
echo ""
echo -e "${BLUE}Verify installation:${NC}"
echo -e "  ${GREEN}cat ~/.claude/settings.json | jq '.hooks | keys'${NC}"
echo ""

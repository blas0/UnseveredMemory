#!/bin/bash
# init-cam.sh - CAM + .ai/ Documentation System Initialization
# Unified entry point for initializing CAM interface and .ai/ doc management
# Version: 2.0.3

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get current directory or use provided argument
PROJECT_DIR="${1:-$(pwd)}"
CAM_DIR="$PROJECT_DIR/.claude/cam"
AI_DIR="$PROJECT_DIR/.ai"
TEMPLATE_DIR="$HOME/.claude/cam-template"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Version comparison (returns 0 if v1 < v2)
version_lt() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ] && [ "$1" != "$2" ]
}

get_template_version() {
    if [ -f "$TEMPLATE_DIR/VERSION.txt" ]; then
        cat "$TEMPLATE_DIR/VERSION.txt" | tr -d '\n'
    else
        echo "unknown"
    fi
}

get_project_version() {
    if [ -f "$CAM_DIR/VERSION.txt" ]; then
        cat "$CAM_DIR/VERSION.txt" | tr -d '\n'
    else
        echo "0.0.0"
    fi
}

# =============================================================================
# PREREQUISITES CHECK
# =============================================================================

check_prerequisites() {
    local missing=0

    # Check Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}[x] Python 3 not found${NC}"
        echo -e "    Install: https://www.python.org/downloads/"
        missing=1
    fi

    # Check sqlite3
    if ! command -v sqlite3 &> /dev/null; then
        echo -e "${RED}[x] sqlite3 not found${NC}"
        echo -e "    Install: brew install sqlite3 (macOS) or apt install sqlite3 (Debian/Ubuntu) or dnf install sqlite (Fedora)"
        missing=1
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}[x] jq not found${NC}"
        echo -e "    Install: brew install jq (macOS) or apt install jq (Debian/Ubuntu) or dnf install jq (Fedora)"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${RED}Please install missing prerequisites and try again.${NC}"
        exit 1
    fi
}

# =============================================================================
# DISPLAY FUNCTIONS
# =============================================================================

show_banner() {
    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}    * INTERFACE INITIALIZATION *${NC}"
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "  * Initialize CAM + .ai codebase doc management system"
    echo -e "  Project: ${BLUE}$PROJECT_DIR${NC}"
    echo ""
    read -n 1 -s -r -p "Press any key to initialize..."
    echo ""
    echo ""
}

show_upgrade_prompt() {
    local system_name="$1"
    local project_ver="$2"
    local template_ver="$3"

    echo ""
    echo -e "${YELLOW}=================================================================${NC}"
    echo -e "${YELLOW}    ${system_name} Upgrade available:${NC}"
    echo -e "${YELLOW}=================================================================${NC}"
    echo -e "  Project Version: ${RED}${project_ver}${NC}"
    echo -e "  Current Version: ${GREEN}${template_ver}${NC}"
    echo ""
    echo -e "  Run: ${GREEN}./cam.sh upgrade --force${NC}"
    echo -e "  From: ${GREEN}.claude/cam/${NC} directory"
    echo ""
    read -n 1 -s -r -p "Press any key to exit..."
    echo ""
}

show_no_changes() {
    local system_name="$1"

    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}    ${system_name} Initialization:${NC}"
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "  No changes are necessary."
    echo ""
    read -n 1 -s -r -p "Press any key to exit..."
    echo ""
}

show_next_steps() {
    echo ""
    echo -e "${BLUE}* NEXT STEPS *${NC}"
    echo -e "  1. Prompt your agent to populate the .ai/ doc management system files proactively."
    echo -e "  2. After the agent populates the .ai/ doc management system files, prompt your agent"
    echo -e "     to consolidate/append any existing .md documents (excluding CLAUDE.md, GEMINI.md,"
    echo -e "     cursor-rules.md, and any other docs you don't want consolidated) into the .ai/"
    echo -e "     doc management system. After completed - delete and remove the orphaned/appended docs."
    echo -e "  3. Prompt your agent to thoroughly sync your entire codebase + .ai/ document files"
    echo -e "     into the CAM database."
    echo ""
}

show_codebase_analysis() {
    echo -e "${BLUE}=================================================================${NC}"
    echo -e "${BLUE}* CODEBASE ANALYSIS *${NC}"
    echo -e "${BLUE}=================================================================${NC}"
    echo ""
    echo -e "Copy this prompt to bootstrap your AI agent's understanding of the codebase:"
    echo ""
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
    cat << 'BOOTSTRAP_PROMPT'
Act as a Principal Software Architect to perform a holistic static analysis of this codebase, documentation, and configuration files to construct a comprehensive mental model of the system.

1. **Technology Stack**: Identify languages, frameworks, and infrastructure dependencies
2. **Architecture Map**: Delineate frontend components, backend services, and database entities
3. **Feature Catalog**: Document each module's business purpose, I/O contracts, and dependencies
4. **Data Flow**: Trace interactions from UI through controllers to persistence layers
5. **Technical Spec**: Define function purposes, entity relationships (Mermaid.js), and system workflows

Systematically organize and proactively append all discovered data, architectural insights, and generated documentation into the .ai/ documentation directory.
BOOTSTRAP_PROMPT
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
    echo ""
}

show_codebase_analysis_pt2() {
    echo -e "${BLUE}=================================================================${NC}"
    echo -e "${BLUE}* CODEBASE ANALYSIS PT. 2 *${NC}"
    echo -e "${BLUE}=================================================================${NC}"
    echo ""
    echo -e "Copy this prompt to sync your CAM database with your codebase + .ai/ doc system:"
    echo ""
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
    cat << 'CAM_SYNC_PROMPT'
Systematically organize and proactively append all discovered data, architectural insights, and generated documentation in the .ai/ directory along with any other insights of this project and its purpose to the CAM database. Ensure to vectorize/embed/annotate/and graph all data very thoroughly.
CAM_SYNC_PROMPT
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"
    echo ""
}

# =============================================================================
# CAM INITIALIZATION
# =============================================================================

initialize_cam() {
    echo -e "==> Initializing CAM infrastructure..."

    # Create .claude directory if needed
    mkdir -p "$PROJECT_DIR/.claude"

    # Create CAM directory
    mkdir -p "$CAM_DIR"
    echo -e "  [v] Created .claude/cam/ directory"

    # Copy core files from template
    echo -e "--> Installing CAM core library..."
    if [ -f "$TEMPLATE_DIR/cam_core.py" ]; then
        cp "$TEMPLATE_DIR/cam_core.py" "$CAM_DIR/"
        cp "$TEMPLATE_DIR/cam.sh" "$CAM_DIR/"
        cp "$TEMPLATE_DIR/requirements.txt" "$CAM_DIR/"
        cp "$TEMPLATE_DIR/VERSION.txt" "$CAM_DIR/" 2>/dev/null || echo "1.0.0" > "$CAM_DIR/VERSION.txt"
        chmod +x "$CAM_DIR/cam.sh"
        echo -e "  [v] Core files installed"
    else
        echo -e "  [x] Template not found at $TEMPLATE_DIR"
        echo -e "  [!] Please ensure cam-template is installed at ~/.claude/cam-template/"
        exit 1
    fi

    # Create Python virtual environment
    echo -e "[py] Creating Python virtual environment..."
    cd "$CAM_DIR"
    python3 -m venv venv
    echo -e "  [v] Virtual environment created"

    # Install dependencies
    echo -e "[+] Installing dependencies..."
    ./venv/bin/pip install -q -r requirements.txt
    echo -e "  [v] Dependencies installed"

    # Initialize SQLite databases
    echo -e "[db] Initializing databases..."

    # vectors.db
    echo "CREATE TABLE IF NOT EXISTS embeddings (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    embedding BLOB,
    source_type TEXT CHECK(source_type IN ('code', 'docs', 'operation', 'external', 'conversation')),
    source_file TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_source_type ON embeddings(source_type);
CREATE INDEX IF NOT EXISTS idx_created_at ON embeddings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_source_file ON embeddings(source_file);" | sqlite3 vectors.db

    # metadata.db
    echo "CREATE TABLE IF NOT EXISTS annotations (
    id TEXT PRIMARY KEY,
    embedding_id TEXT NOT NULL,
    metadata TEXT NOT NULL,
    tags TEXT,
    confidence REAL DEFAULT 1.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_embedding_id ON annotations(embedding_id);
CREATE INDEX IF NOT EXISTS idx_confidence ON annotations(confidence DESC);
CREATE INDEX IF NOT EXISTS idx_created_at ON annotations(created_at DESC);" | sqlite3 metadata.db

    # graph.db
    echo "CREATE TABLE IF NOT EXISTS relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    weight REAL DEFAULT 1.0,
    metadata TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(source_id, target_id, relationship_type)
);
CREATE INDEX IF NOT EXISTS idx_source_id ON relationships(source_id);
CREATE INDEX IF NOT EXISTS idx_target_id ON relationships(target_id);
CREATE INDEX IF NOT EXISTS idx_relationship_type ON relationships(relationship_type);
CREATE INDEX IF NOT EXISTS idx_weight ON relationships(weight DESC);

CREATE TABLE IF NOT EXISTS nodes (
    id TEXT PRIMARY KEY,
    node_type TEXT NOT NULL,
    properties TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_node_type ON nodes(node_type);" | sqlite3 graph.db

    echo -e "  [v] Databases initialized"

    # Create operations log
    echo "# CAM Operations Log" > operations.log
    echo "# Initialized: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> operations.log
    echo "" >> operations.log
    echo -e "  [v] Operations log created"

    # Update .gitignore
    echo -e "[--] Updating .gitignore..."
    cd "$PROJECT_DIR"

    GITIGNORE_ENTRIES="
# CAM (Continuous Architectural Memory)
.claude/cam/vectors.db
.claude/cam/metadata.db
.claude/cam/graph.db
.claude/cam/operations.log
.claude/cam/venv/
.claude/cam/*.pyc
.claude/cam/__pycache__/
.claude/cam/.backup/
"

    if [ -f .gitignore ]; then
        if ! grep -q ".claude/cam/vectors.db" .gitignore; then
            echo "$GITIGNORE_ENTRIES" >> .gitignore
            echo -e "  [v] Added CAM to .gitignore"
        else
            echo -e "  [#] CAM entries already in .gitignore"
        fi
    else
        echo "$GITIGNORE_ENTRIES" > .gitignore
        echo -e "  [v] Created .gitignore with CAM entries"
    fi

    # Test installation
    echo -e ">>> Testing CAM installation..."
    cd "$PROJECT_DIR"
    STATS=$(./.claude/cam/cam.sh stats 2>&1 || echo "ERROR")

    if echo "$STATS" | grep -q "total_embeddings"; then
        echo -e "  [v] CAM installation verified"
    else
        echo -e "  [!] CAM initialized but test failed. Check manually."
    fi

    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}  [v] CAM Initialization Complete${NC}"
    echo -e "${GREEN}=================================================================${NC}"
    echo ""
}

# =============================================================================
# .AI/ SCAFFOLDING (Inline from scaffold-ai.sh logic)
# =============================================================================

scaffold_ai_docs() {
    echo -e "==> Scaffolding .ai/ documentation system..."

    # Source scaffold-ai.sh if available, otherwise inline the logic
    if [ -f "$TEMPLATE_DIR/hooks/scaffold-ai.sh" ]; then
        # Call scaffold-ai.sh with project directory
        bash "$TEMPLATE_DIR/hooks/scaffold-ai.sh" "$PROJECT_DIR"
    else
        echo -e "  [!] scaffold-ai.sh not found at $TEMPLATE_DIR/hooks/"
        echo -e "  [#] Creating minimal .ai/ structure..."

        # Create basic structure
        mkdir -p "$AI_DIR/core"
        mkdir -p "$AI_DIR/development"
        mkdir -p "$AI_DIR/patterns"
        mkdir -p "$AI_DIR/meta"

        # Create README.md
        cat > "$AI_DIR/README.md" << 'EOF'
# Project Documentation Hub

This is the central documentation hub for the project.

## Two Sources of Truth

1. **Hub**: This `.ai/` directory - Documentation structure
2. **CAM**: Semantic query/search database - Cross-session memory

## Structure

- `core/` - Architecture, tech stack, deployment
- `development/` - Workflows, testing patterns
- `patterns/` - Database, frontend, API, security patterns
- `meta/` - Documentation maintenance guides
EOF

        echo -e "  [v] Created minimal .ai/ structure"
        echo -e "  [*] Run scaffold-ai.sh separately for full scaffolding"
    fi

    # Always scaffold .insights/ directory (v2.2.0+)
    scaffold_insights_dir
}

# =============================================================================
# .AI/.INSIGHTS/ SCAFFOLDING (v2.2.0+)
# =============================================================================

scaffold_insights_dir() {
    local insights_dir="$AI_DIR/.insights"

    if [ -d "$insights_dir" ]; then
        echo -e "  [v] .ai/.insights/ already exists"
        return 0
    fi

    echo -e "  [+] Creating .ai/.insights/ staging directory..."

    # Create directory structure
    mkdir -p "$insights_dir/decisions"
    mkdir -p "$insights_dir/patterns"
    mkdir -p "$insights_dir/gotchas"
    mkdir -p "$insights_dir/.archive"

    # Create index file
    echo '{"version": "1.0", "insights": [], "last_cleanup": null}' > "$insights_dir/_index.json"

    # Create .gitignore (insights are staging, not committed by default)
    cat > "$insights_dir/.gitignore" << 'GITIGNORE'
# Auto-generated insights - review before committing
# Remove this file if you want to track insights in git
*
!.gitignore
!_index.json
!README.md
GITIGNORE

    # Create README
    cat > "$insights_dir/README.md" << 'INSIGHTSREADME'
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
INSIGHTSREADME

    echo -e "  [v] Created .ai/.insights/ staging directory"
}

# =============================================================================
# MAIN LOGIC
# =============================================================================

main() {
    # Check prerequisites first
    check_prerequisites

    # Show banner and wait for user
    show_banner

    # Get versions
    TEMPLATE_VERSION=$(get_template_version)
    PROJECT_VERSION=$(get_project_version)

    # Track what was initialized
    CAM_INITIALIZED=false
    AI_INITIALIZED=false

    # -------------------------------------------------------------------------
    # CHECK .claude/ FOLDER
    # -------------------------------------------------------------------------
    if [ -d "$PROJECT_DIR/.claude" ]; then
        echo -e "[#] .claude/ directory found"
    else
        echo -e "--> Creating .claude/ directory..."
        mkdir -p "$PROJECT_DIR/.claude"
        echo -e "  [v] Created .claude/"
    fi

    # -------------------------------------------------------------------------
    # CHECK .claude/cam/ FOLDER
    # -------------------------------------------------------------------------
    if [ -d "$CAM_DIR" ]; then
        echo -e "[#] CAM installation found"
        PROJECT_VERSION=$(get_project_version)

        if [ "$TEMPLATE_VERSION" != "unknown" ] && version_lt "$PROJECT_VERSION" "$TEMPLATE_VERSION"; then
            show_upgrade_prompt "CAM" "$PROJECT_VERSION" "$TEMPLATE_VERSION"
            exit 0
        else
            echo -e "  [v] CAM is up to date (v${PROJECT_VERSION})"
            CAM_INITIALIZED=true
        fi
    else
        echo -e "[#] CAM not found - initializing..."
        initialize_cam
        CAM_INITIALIZED=true
    fi

    # -------------------------------------------------------------------------
    # CHECK .ai/ FOLDER
    # -------------------------------------------------------------------------
    echo ""
    if [ -d "$AI_DIR" ]; then
        echo -e "[#] .ai/ documentation found"

        # If CAM is initialized and up to date, nothing to do
        if [ "$CAM_INITIALIZED" = true ]; then
            show_no_changes "CAM + .ai/"
            show_next_steps
            exit 0
        fi
    else
        echo -e "[#] .ai/ not found - scaffolding..."
        scaffold_ai_docs
        AI_INITIALIZED=true
    fi

    # -------------------------------------------------------------------------
    # COMPLETION OUTPUT
    # -------------------------------------------------------------------------
    echo ""
    echo -e "${GREEN}=================================================================${NC}"
    echo -e "${GREEN}  [v] Initialization Complete${NC}"
    echo -e "${GREEN}=================================================================${NC}"

    # Show what was done
    echo ""
    echo -e "[#] Summary:"
    if [ "$CAM_INITIALIZED" = true ]; then
        echo -e "  [v] CAM interface initialized"
    fi
    if [ "$AI_INITIALIZED" = true ]; then
        echo -e "  [v] .ai/ documentation scaffolded"
    fi
    echo ""

    # Show next steps and analysis prompts
    show_next_steps
    show_codebase_analysis
    show_codebase_analysis_pt2

    echo -e "${GREEN}=================================================================${NC}"
    echo -e "  Ready to use. Start your AI agent and paste the prompts above."
    echo -e "${GREEN}=================================================================${NC}"
    echo ""
}

# Run main
main

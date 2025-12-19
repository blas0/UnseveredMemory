#!/bin/bash
# Unsevered Memory - Global Setup
# Installs memory system to ~/.claude/
# https://github.com/blas0/UnseveredMemory

set -e

# Colors (no emojis)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

print_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Unsevered Memory - Global Setup${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_header

# 1. Create ~/.claude/ directory structure
print_step "Creating ~/.claude/ directory structure..."
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/skills/orchestrate"
mkdir -p "$CLAUDE_DIR/commands"
print_success "Directory structure created"

# 2. Install hooks
print_step "Installing hooks..."
cp "$SCRIPT_DIR/hooks/memory-load.sh" "$CLAUDE_DIR/hooks/"
cp "$SCRIPT_DIR/hooks/memory-remind.sh" "$CLAUDE_DIR/hooks/"
cp "$SCRIPT_DIR/hooks/memory-save.sh" "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh
print_success "Hooks installed (memory-load, memory-remind, memory-save)"

# 3. Install skill
print_step "Installing harness skill..."
cp "$SCRIPT_DIR/skills/orchestrate/SKILL.md" "$CLAUDE_DIR/skills/orchestrate/"
print_success "Skill installed"

# 4. Install command
print_step "Installing /orchestrate command..."
cp "$SCRIPT_DIR/commands/orchestrate.md" "$CLAUDE_DIR/commands/"
print_success "Command installed"

# 5. Configure settings.json (MERGE, don't overwrite)
print_step "Configuring hooks in settings.json..."

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    print_step "Backed up existing settings.json"

    # Check if jq is available for merging
    if command -v jq &> /dev/null; then
        # Merge hooks into existing settings using matcher format (empty string = match all)
        TEMP_FILE=$(mktemp)
        jq '.hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-load.sh"}]}] |
            .hooks.UserPromptSubmit = [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-remind.sh"}]}] |
            .hooks.SessionEnd = [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-save.sh"}]}]' \
            "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"
        print_success "Merged hooks into existing settings.json"
    else
        print_error "jq not found - cannot merge settings.json safely"
        print_step "Please manually add hooks to settings.json"
        print_step "See ~/.claude/settings.json.backup for original"

        # Create a separate hooks file for reference
        cat > "$CLAUDE_DIR/hooks-config.json" << 'HOOKS'
{
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-load.sh"}]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-remind.sh"}]}],
    "SessionEnd": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-save.sh"}]}]
  }
}
HOOKS
        print_step "Hook configuration saved to ~/.claude/hooks-config.json"
    fi
else
    # No existing settings, create new
    cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-load.sh"}]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-remind.sh"}]}],
    "SessionEnd": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/memory-save.sh"}]}]
  }
}
SETTINGS
    print_success "Created settings.json with hooks"
fi

# 6. Install or update CLAUDE.md
print_step "Installing global CLAUDE.md..."

if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    # Check if our marker exists
    if grep -q "Unsevered Memory" "$CLAUDE_DIR/CLAUDE.md"; then
        print_step "Updating existing CLAUDE.md..."
    else
        # Backup and append
        cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
        print_step "Backed up existing CLAUDE.md"
    fi
fi

cp "$SCRIPT_DIR/templates/CLAUDE.md.template" "$CLAUDE_DIR/CLAUDE.md"
print_success "Global CLAUDE.md installed"

# 7. Create project setup script
print_step "Creating project setup script..."

cat > "$CLAUDE_DIR/setup-project.sh" << 'PROJECT_SETUP'
#!/bin/bash
# Unsevered Memory - Project Setup
# Run this in any project directory to add memory support

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Unsevered Memory - Project Setup${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_header

# Resolve project directory
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
echo "Project: $PROJECT_DIR"
echo ""

# 1. Create .claude/memory/ structure
print_step "Creating .claude/memory/ structure..."
mkdir -p "$PROJECT_DIR/.claude/memory/sessions"

# Create memory files from templates or defaults
if [ ! -f "$PROJECT_DIR/.claude/memory/context.md" ]; then
    cat > "$PROJECT_DIR/.claude/memory/context.md" << 'CONTEXT'
# Project Context

## Current State

[Project initialized with Unsevered Memory]

## Current Task

[No active task]

## Last Session

- Date: N/A
- Accomplished: Initial setup
- Stopped at: N/A

## Next Steps

1. Define project goals
2. Set up development environment
3. Begin implementation

## Notes

[Add project-specific notes here]
CONTEXT
    print_success "Created context.md"
fi

if [ ! -f "$PROJECT_DIR/.claude/memory/scratchpad.md" ]; then
    CURRENT_DATE=$(date '+%Y-%m-%d %H:%M')
    cat > "$PROJECT_DIR/.claude/memory/scratchpad.md" << SCRATCHPAD
# Scratchpad

Session: $CURRENT_DATE

## Operations

- Project initialized with Unsevered Memory

## Findings

- N/A

## Decisions

- N/A

## Blockers

- None

## Next Steps

- Begin work
SCRATCHPAD
    print_success "Created scratchpad.md"
fi

if [ ! -f "$PROJECT_DIR/.claude/memory/decisions.md" ]; then
    cat > "$PROJECT_DIR/.claude/memory/decisions.md" << 'DECISIONS'
# Decision Log

Architectural and significant decisions for this project.

---

## Template

```markdown
## YYYY-MM-DD: [Decision Title]

**Context**: Why was this decision needed?

**Options Considered**:
1. Option A - pros/cons
2. Option B - pros/cons

**Decision**: What was chosen

**Rationale**: Why this option was selected

**Consequences**: What this means going forward
```

---

## Decisions

[Decisions will be appended below]
DECISIONS
    print_success "Created decisions.md"
fi

# 2. Create .ai/ documentation structure
print_step "Creating .ai/ documentation structure..."
mkdir -p "$PROJECT_DIR/.ai/core"
mkdir -p "$PROJECT_DIR/.ai/patterns"
mkdir -p "$PROJECT_DIR/.ai/workflows"

if [ ! -f "$PROJECT_DIR/.ai/README.md" ]; then
    cat > "$PROJECT_DIR/.ai/README.md" << 'AI_README'
# Project Documentation

Static documentation for this project.

## Structure

```
.ai/
├── core/           # Technology stack, architecture
├── patterns/       # Reusable implementation patterns
└── workflows/      # Development workflows
```

## Two Sources of Truth

| Location | Type | Updates |
|----------|------|---------|
| `.ai/` | Static docs | When architecture/patterns change |
| `.claude/memory/` | Dynamic state | Every session |

## Guidelines

- Each fact exists in ONE location
- Cross-reference, never duplicate
- Version numbers ONLY in `core/technology-stack.md`
- Update patterns after 3+ uses of same solution
AI_README
    print_success "Created .ai/README.md"
fi

if [ ! -f "$PROJECT_DIR/.ai/core/technology-stack.md" ]; then
    cat > "$PROJECT_DIR/.ai/core/technology-stack.md" << 'TECH'
# Technology Stack

> Single source of truth for all versions.

## Runtime

- Language: [e.g., TypeScript 5.x]
- Runtime: [e.g., Node.js 20.x]

## Frameworks

- Backend: [e.g., Express 4.x]
- Frontend: [e.g., React 18.x]

## Database

- Primary: [e.g., PostgreSQL 16]
- Cache: [e.g., Redis 7.x]

## Infrastructure

- Hosting: [e.g., AWS, Vercel]
- CI/CD: [e.g., GitHub Actions]

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [name] | [x.x.x] | [purpose] |
TECH
    print_success "Created .ai/core/technology-stack.md"
fi

if [ ! -f "$PROJECT_DIR/.ai/core/architecture.md" ]; then
    cat > "$PROJECT_DIR/.ai/core/architecture.md" << 'ARCH'
# Architecture

## Overview

[High-level description of system architecture]

## Layers

### Presentation
[UI components, API endpoints]

### Business Logic
[Services, domain logic]

### Data
[Database access, repositories]

## Components

[Add component descriptions as they are built]

## Data Flow

[How data moves through the system]
ARCH
    print_success "Created .ai/core/architecture.md"
fi

if [ ! -f "$PROJECT_DIR/.ai/patterns/README.md" ]; then
    cat > "$PROJECT_DIR/.ai/patterns/README.md" << 'PATTERNS'
# Patterns

Reusable implementation patterns for this project.

## Adding Patterns

After using the same solution 3+ times, add it here.

## Pattern Template

```markdown
## [Pattern Name]

**Use Case**: When to use this pattern

**Implementation**:
```[language]
// Code example
```

**Rationale**: Why we use this pattern
```

## Patterns

[Add patterns below as they emerge]
PATTERNS
    print_success "Created .ai/patterns/README.md"
fi

if [ ! -f "$PROJECT_DIR/.ai/workflows/README.md" ]; then
    cat > "$PROJECT_DIR/.ai/workflows/README.md" << 'WORKFLOWS'
# Workflows

Development workflows for this project.

## Workflow Template

```markdown
## [Workflow Name]

**Purpose**: What this workflow accomplishes

**Steps**:
1. Step one
2. Step two

**Verification**: How to confirm success
```

## Workflows

[Add workflows below as they are established]
WORKFLOWS
    print_success "Created .ai/workflows/README.md"
fi

# 3. Create project CLAUDE.md if missing
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
    print_step "Creating project CLAUDE.md..."
    cat > "$PROJECT_DIR/CLAUDE.md" << 'PROJECT_CLAUDE'
# Project Instructions

## Overview

[Brief description of this project]

## Tech Stack

See `.ai/core/technology-stack.md` for versions.

## Architecture

See `.ai/core/architecture.md` for system design.

## Development

### Setup
```bash
[setup commands]
```

### Run
```bash
[run commands]
```

### Test
```bash
[test commands]
```

## Conventions

- [Convention 1]
- [Convention 2]

## Memory

This project uses Unsevered Memory. See:
- `.claude/memory/` for session state
- `.ai/` for patterns and architecture
PROJECT_CLAUDE
    print_success "Created project CLAUDE.md"
fi

# 4. Update .gitignore
print_step "Updating .gitignore..."
GITIGNORE="$PROJECT_DIR/.gitignore"

if [ ! -f "$GITIGNORE" ]; then
    touch "$GITIGNORE"
fi

if ! grep -q "# Unsevered Memory" "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Unsevered Memory" >> "$GITIGNORE"
    echo ".claude/memory/scratchpad.md" >> "$GITIGNORE"
    print_success "Updated .gitignore"
else
    print_step ".gitignore already configured"
fi

# Done
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Project Setup Complete${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Structure created:"
echo "  .claude/memory/"
echo "    - context.md      (cross-session state)"
echo "    - scratchpad.md   (live session log)"
echo "    - decisions.md    (architectural decisions)"
echo "    - sessions/       (daily archives)"
echo ""
echo "  .ai/"
echo "    - core/           (tech stack, architecture)"
echo "    - patterns/       (reusable solutions)"
echo "    - workflows/      (dev processes)"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md with project details"
echo "  2. Fill in .ai/core/ with project info"
echo "  3. Run 'claude' to start working"
echo ""
echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Bootstrap Prompt${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo "To initialize this project with comprehensive documentation:"
echo ""
cat << 'BOOTSTRAP_PROMPT'
Conduct a comprehensive documentation audit and integration project for this codebase by systematically analyzing, organizing, and consolidating all text-based materials into the existing @.ai/ folder documentation framework. Begin by thoroughly examining the current @.ai/ folder structure to understand the existing documentation system, including what files are present, how information is organized, and where specific types of content should be appended or integrated. Next, perform an in-depth analysis of the project's actual codebase, treating the working code as the authoritative source of truth about functionality, architecture, and purpose, then use these insights to enhance and complete the @.ai/ documentation system with accurate technical specifications and operational context. Following the code analysis, systematically search throughout the entire project directory to locate and catalog all documentation-related files and folders, including .txt, .md, .pdf documents, research materials, diagnostic reports, project plans, notes, and any other relevant documentation (excluding claude.md). Once all documentation materials have been identified, carefully review their contents and strategically append the relevant information to the appropriate corresponding files within the established @.ai/ folder system, ensuring that data is integrated logically without creating new files or folders. After completing the integration process, create a new folder named "olddoccontext" in the project root directory and relocate all the original documentation files and folders that were processed during the audit, effectively centralizing these materials while maintaining the enhanced @.ai/ documentation system as the primary source of project information. Throughout this entire process, utilize the @agent-orchestrator tool to maximize efficiency and ensure systematic completion of each phase, ultimately delivering a comprehensive, well-organized documentation framework that accurately captures all technical specifications, operational contexts, and project details within the existing @.ai/ folder structure.
BOOTSTRAP_PROMPT
echo ""
echo "Run this in your project with: /orchestrate"
echo ""
PROJECT_SETUP

chmod +x "$CLAUDE_DIR/setup-project.sh"
print_success "Project setup script created"

# Done
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Global Setup Complete${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Installed to ~/.claude/:"
echo "  - CLAUDE.md          (global instructions)"
echo "  - settings.json      (hook configuration)"
echo "  - hooks/"
echo "      - memory-load.sh     (SessionStart)"
echo "      - memory-remind.sh   (UserPromptSubmit)"
echo "      - memory-save.sh     (SessionEnd)"
echo "  - skills/orchestrate/"
echo "      - SKILL.md           (workflow instructions)"
echo "  - commands/"
echo "      - orchestrate.md     (/orchestrate command)"
echo "  - setup-project.sh   (per-project setup)"
echo ""
echo "To add memory to a project:"
echo "  cd /path/to/project"
echo "  ~/.claude/setup-project.sh"
echo ""
echo "To use orchestrator mode:"
echo "  /orchestrate [task description]"
echo ""

#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# unseveredmemory-project.sh - Project Scaffolding for Unsevered Memory
# Version: 1.0.0
# ═══════════════════════════════════════════════════════════════════════════
#
# PURPOSE: Scaffold a project with .ai/ documentation and .claude/memory/
#
# USAGE:
#   ./unseveredmemory-project.sh              # Current directory
#   ./unseveredmemory-project.sh /path/to/project
#
# CREATES:
#   .ai/                         # Documentation hub (always created)
#   .claude/memory/              # Session memory
#   CLAUDE.md                    # Claude Code entry point
#
# ═══════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Unsevered Memory - Project Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "Project: $PROJECT_DIR"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Detect project type
# ─────────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}>>> Detecting project type...${NC}"

PROJECT_TYPE="generic"
FRAMEWORK=""
LANGUAGE=""

# PHP/Laravel detection
if [ -f "$PROJECT_DIR/artisan" ]; then
    PROJECT_TYPE="laravel"
    FRAMEWORK="Laravel"
    LANGUAGE="PHP"
    echo -e "  Detected: ${GREEN}Laravel${NC}"
fi

# Node.js detection
if [ -f "$PROJECT_DIR/package.json" ]; then
    if [ "$PROJECT_TYPE" == "generic" ]; then
        PROJECT_TYPE="node"
        LANGUAGE="JavaScript/TypeScript"
    fi
    if grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FRAMEWORK="Next.js"
        echo -e "  Detected: ${GREEN}Next.js${NC}"
    elif grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FRAMEWORK="React"
        echo -e "  Detected: ${GREEN}React${NC}"
    elif grep -q '"vue"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FRAMEWORK="Vue"
        echo -e "  Detected: ${GREEN}Vue${NC}"
    elif grep -q '"svelte"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        FRAMEWORK="Svelte"
        echo -e "  Detected: ${GREEN}Svelte${NC}"
    fi
fi

# Python detection
if [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    if [ "$PROJECT_TYPE" == "generic" ]; then
        PROJECT_TYPE="python"
        LANGUAGE="Python"
        echo -e "  Detected: ${GREEN}Python${NC}"
    fi
fi

# Go detection
if [ -f "$PROJECT_DIR/go.mod" ]; then
    PROJECT_TYPE="go"
    LANGUAGE="Go"
    echo -e "  Detected: ${GREEN}Go${NC}"
fi

# Rust detection
if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    PROJECT_TYPE="rust"
    LANGUAGE="Rust"
    echo -e "  Detected: ${GREEN}Rust${NC}"
fi

if [ "$PROJECT_TYPE" == "generic" ]; then
    echo -e "  Detected: ${YELLOW}Generic project${NC}"
    LANGUAGE="TBD"
fi

PROJECT_NAME=$(basename "$PROJECT_DIR")
DATE=$(date +%Y-%m-%d)
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# ─────────────────────────────────────────────────────────────────────────────
# Check existing .ai/ directory
# ─────────────────────────────────────────────────────────────────────────────

AI_DIR="$PROJECT_DIR/.ai"

if [ -d "$AI_DIR" ]; then
    echo ""
    echo -e "${YELLOW}[!] .ai/ directory already exists${NC}"
    read -p "    Overwrite? (y/N): " overwrite_ai
    if [[ "$overwrite_ai" =~ ^[Yy]$ ]]; then
        echo -e "    Backing up to .ai.backup/"
        rm -rf "$PROJECT_DIR/.ai.backup"
        mv "$AI_DIR" "$PROJECT_DIR/.ai.backup"
    else
        echo -e "    Keeping existing .ai/"
        SKIP_AI=true
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Create .ai/ directory structure
# ─────────────────────────────────────────────────────────────────────────────

if [ "${SKIP_AI:-}" != "true" ]; then
    echo ""
    echo -e "${GREEN}>>> Creating .ai/ documentation structure...${NC}"

    mkdir -p "$AI_DIR"/{core,development,patterns,meta}

    # ─────────────────────────────────────────────────────────────────────────
    # .ai/README.md
    # ─────────────────────────────────────────────────────────────────────────

    cat > "$AI_DIR/README.md" << 'EOF'
# Project Documentation

This directory contains all AI-related documentation for the project.

## Two Sources of Truth

1. **`.ai/`** - Static documentation (architecture, patterns, workflows)
2. **`.claude/memory/`** - Dynamic memory (context, decisions, sessions)

## Quick Start

### For Claude Code

Start with [CLAUDE.md](../CLAUDE.md) in the project root. Claude Code's hooks automatically load context from `.claude/memory/` at session start, then reference this `.ai/` directory for detailed documentation.

## Documentation Structure

```
.ai/
├── README.md                    # This file - Navigation hub
├── core/                        # Core project information
│   ├── technology-stack.md      # Version numbers (SINGLE SOURCE)
│   ├── project-overview.md      # What this project is
│   ├── application-architecture.md
│   └── deployment-architecture.md
├── development/                 # Development practices
│   ├── development-workflow.md
│   └── testing-patterns.md
├── patterns/                    # Code patterns
│   ├── database-patterns.md
│   ├── frontend-patterns.md
│   ├── security-patterns.md
│   └── api-and-routing.md
└── meta/                        # Documentation guides
    ├── maintaining-docs.md
    └── sync-guide.md
```

## Navigation

### Core Documentation
- [Technology Stack](core/technology-stack.md) - All versions and dependencies
- [Project Overview](core/project-overview.md) - Project description
- [Application Architecture](core/application-architecture.md) - System design
- [Deployment Architecture](core/deployment-architecture.md) - Deployment details

### Development
- [Development Workflow](development/development-workflow.md) - Setup and workflows
- [Testing Patterns](development/testing-patterns.md) - Testing strategies

### Patterns
- [Database Patterns](patterns/database-patterns.md) - Database implementation
- [Frontend Patterns](patterns/frontend-patterns.md) - Frontend development
- [Security Patterns](patterns/security-patterns.md) - Security guidelines
- [API & Routing](patterns/api-and-routing.md) - API design

### Meta
- [Maintaining Docs](meta/maintaining-docs.md) - Documentation maintenance
- [Sync Guide](meta/sync-guide.md) - Synchronization guidelines

---

**Remember**: Each piece of information exists in ONE location. Use cross-references, never duplicate.
EOF
    echo -e "  [✓] Created .ai/README.md"

    # ─────────────────────────────────────────────────────────────────────────
    # .ai/core/
    # ─────────────────────────────────────────────────────────────────────────

    cat > "$AI_DIR/core/technology-stack.md" << EOF
# Technology Stack

**SINGLE SOURCE OF TRUTH** for all version numbers and dependencies.

## Overview

| Category | Technology | Version |
|----------|------------|---------|
| Language | ${LANGUAGE:-"TBD"} | TBD |
| Framework | ${FRAMEWORK:-"TBD"} | TBD |
| Database | TBD | TBD |
| Cache | TBD | TBD |

## Backend

<!-- Update with actual versions -->

## Frontend

<!-- Update with actual versions -->

## Development Tools

<!-- Update with actual versions -->

## Infrastructure

<!-- Update with actual versions -->

---

**Note**: All version references across documentation should link back to this file.
EOF
    echo -e "  [✓] Created .ai/core/technology-stack.md"

    cat > "$AI_DIR/core/project-overview.md" << 'EOF'
# Project Overview

## What This Project Is

<!-- Describe what the project does -->

## Core Mission

<!-- One sentence mission statement -->

## Key Features

<!-- List main features -->

## Target Users

<!-- Who uses this -->

## Architecture Philosophy

<!-- High-level approach -->

---

See [application-architecture.md](application-architecture.md) for technical details.
EOF
    echo -e "  [✓] Created .ai/core/project-overview.md"

    cat > "$AI_DIR/core/application-architecture.md" << 'EOF'
# Application Architecture

## System Overview

<!-- High-level architecture diagram or description -->

## Directory Structure

```
<!-- Project structure here -->
```

## Core Components

<!-- List and describe main components -->

## Data Models

<!-- Key models and relationships -->

## Service Layer

<!-- Business logic organization -->

---

See [technology-stack.md](technology-stack.md) for version details.
EOF
    echo -e "  [✓] Created .ai/core/application-architecture.md"

    cat > "$AI_DIR/core/deployment-architecture.md" << 'EOF'
# Deployment Architecture

## Environments

| Environment | URL | Purpose |
|-------------|-----|---------|
| Development | localhost | Local development |
| Staging | TBD | Pre-production testing |
| Production | TBD | Live application |

## Infrastructure

<!-- Describe hosting, containers, etc. -->

## CI/CD Pipeline

<!-- Describe deployment process -->

## Configuration

<!-- Environment variables, secrets management -->

---

See [development-workflow.md](../development/development-workflow.md) for local setup.
EOF
    echo -e "  [✓] Created .ai/core/deployment-architecture.md"

    # ─────────────────────────────────────────────────────────────────────────
    # .ai/development/
    # ─────────────────────────────────────────────────────────────────────────

    cat > "$AI_DIR/development/development-workflow.md" << 'EOF'
# Development Workflow

## Prerequisites

<!-- List required software -->

## Quick Start

```bash
# Clone repository
git clone <repo-url>
cd <project>

# Install dependencies
# <commands here>

# Start development server
# <commands here>
```

## Development Commands

| Command | Description |
|---------|-------------|
| TBD | TBD |

## Code Style

<!-- Formatting, linting rules -->

## Git Workflow

<!-- Branch naming, commit conventions -->

---

See [testing-patterns.md](testing-patterns.md) for testing instructions.
EOF
    echo -e "  [✓] Created .ai/development/development-workflow.md"

    cat > "$AI_DIR/development/testing-patterns.md" << 'EOF'
# Testing Patterns

## Testing Strategy

<!-- Overview of testing approach -->

## Test Types

### Unit Tests

<!-- Unit testing patterns -->

### Integration Tests

<!-- Integration testing patterns -->

### E2E Tests

<!-- End-to-end testing patterns -->

## Running Tests

```bash
# Run all tests
# <command>

# Run specific tests
# <command>
```

## Test Coverage

<!-- Coverage requirements -->

---

See [development-workflow.md](development-workflow.md) for setup.
EOF
    echo -e "  [✓] Created .ai/development/testing-patterns.md"

    # ─────────────────────────────────────────────────────────────────────────
    # .ai/patterns/
    # ─────────────────────────────────────────────────────────────────────────

    cat > "$AI_DIR/patterns/database-patterns.md" << 'EOF'
# Database Patterns

## Overview

<!-- Database technology and approach -->

## Models

<!-- Key models and their purpose -->

## Relationships

<!-- Model relationships -->

## Migrations

<!-- Migration patterns -->

## Query Patterns

<!-- Common query patterns -->

---

See [application-architecture.md](../core/application-architecture.md) for data model overview.
EOF
    echo -e "  [✓] Created .ai/patterns/database-patterns.md"

    cat > "$AI_DIR/patterns/frontend-patterns.md" << 'EOF'
# Frontend Patterns

## Overview

<!-- Frontend technology and approach -->

## Component Structure

<!-- How components are organized -->

## State Management

<!-- State management approach -->

## Styling

<!-- CSS/styling approach -->

## Best Practices

<!-- Frontend best practices -->

---

See [technology-stack.md](../core/technology-stack.md) for versions.
EOF
    echo -e "  [✓] Created .ai/patterns/frontend-patterns.md"

    cat > "$AI_DIR/patterns/security-patterns.md" << 'EOF'
# Security Patterns

## Authentication

<!-- How authentication works -->

## Authorization

<!-- Permission and access control -->

## Data Protection

<!-- Encryption, sanitization -->

## Security Headers

<!-- HTTP security headers -->

## Best Practices

<!-- Security best practices -->

---

See [api-and-routing.md](api-and-routing.md) for API security.
EOF
    echo -e "  [✓] Created .ai/patterns/security-patterns.md"

    cat > "$AI_DIR/patterns/api-and-routing.md" << 'EOF'
# API and Routing Patterns

## Route Structure

<!-- How routes are organized -->

## API Design

<!-- RESTful conventions, versioning -->

## Request Handling

<!-- Validation, middleware -->

## Response Format

<!-- Standard response structure -->

## Error Handling

<!-- Error response patterns -->

---

See [security-patterns.md](security-patterns.md) for API security.
EOF
    echo -e "  [✓] Created .ai/patterns/api-and-routing.md"

    # ─────────────────────────────────────────────────────────────────────────
    # .ai/meta/
    # ─────────────────────────────────────────────────────────────────────────

    cat > "$AI_DIR/meta/maintaining-docs.md" << 'EOF'
# Maintaining Documentation

Guidelines for creating and maintaining AI documentation.

## Documentation Structure

All AI documentation lives in the `.ai/` directory:

```
.ai/
├── README.md                    # Navigation hub
├── core/                        # Core project information
├── development/                 # Development practices
├── patterns/                    # Code patterns and best practices
└── meta/                        # Documentation maintenance guides
```

## Content Guidelines

### DO:
- Start with high-level overview
- Include specific, actionable requirements
- Show examples of correct implementation
- Reference existing code when possible
- Keep documentation DRY by cross-referencing
- Use bullet points for clarity

### DON'T:
- Create theoretical examples when real code exists
- Duplicate content across multiple files
- Make assumptions about versions - specify exact versions
- Create documentation for obvious functionality

## When to Update Documentation

### Add New Documentation When:
- A new technology/pattern is used in 3+ files
- Common bugs could be prevented by documentation
- Code reviews repeatedly mention the same feedback

### Modify Existing Documentation When:
- Better examples exist in the codebase
- Additional edge cases are discovered
- Implementation details have changed

## Single Source of Truth

- Each piece of information should exist in exactly ONE location
- Other files should reference the source, not duplicate it
- Version numbers live ONLY in `core/technology-stack.md`

## How Claude Code Uses This

Claude Code reads `CLAUDE.md` at session start, which routes to `.ai/` for documentation. The hooks system automatically loads `.claude/memory/context.md` to restore session state.

---

See [sync-guide.md](sync-guide.md) for synchronization rules.
EOF
    echo -e "  [✓] Created .ai/meta/maintaining-docs.md"

    cat > "$AI_DIR/meta/sync-guide.md" << 'EOF'
# Documentation Sync Guide

How documentation is organized for Claude Code.

## Overview

This project maintains documentation with **two sources of truth**:

1. **`.ai/`** - Static documentation (architecture, patterns, workflows)
2. **`.claude/memory/`** - Dynamic memory (context, decisions, sessions)

Claude Code reads `CLAUDE.md` which routes to these sources. Hooks automatically load memory context at session start.

## Where to Make Changes

**For version numbers** (frameworks, languages, packages):
1. Update `.ai/core/technology-stack.md` (single source of truth)
2. Never duplicate version numbers elsewhere

**For workflow changes** (commands, setup):
1. Update `.ai/development/development-workflow.md`
2. Verify all cross-references work

**For architectural patterns** (how code should be structured):
1. Update appropriate file in `.ai/core/`
2. Add cross-references from related docs

**For code patterns** (how to write code):
1. Update appropriate file in `.ai/patterns/`
2. Add examples from real codebase

## Update Checklist

When making significant changes:

- [ ] Update primary location in `.ai/` directory
- [ ] Verify CLAUDE.md references are still accurate
- [ ] Update cross-references in related `.ai/` files
- [ ] Test links in markdown files

## File Organization

```
/
├── CLAUDE.md                          # Claude Code entry point
├── .ai/                               # Static documentation
│   ├── README.md
│   ├── core/
│   ├── development/
│   ├── patterns/
│   └── meta/
└── .claude/memory/                    # Dynamic memory
    ├── context.md
    ├── decisions.md
    └── sessions/
```

---

**Golden Rule**: Each piece of information exists in ONE location in `.ai/`. Entry points route to `.ai/`.
EOF
    echo -e "  [✓] Created .ai/meta/sync-guide.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Create .claude/memory/ structure
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}>>> Creating .claude/memory/ structure...${NC}"

MEMORY_DIR="$PROJECT_DIR/.claude/memory"
SESSIONS_DIR="$MEMORY_DIR/sessions"

mkdir -p "$MEMORY_DIR" "$SESSIONS_DIR"

# context.md
if [ ! -f "$MEMORY_DIR/context.md" ]; then
    cat > "$MEMORY_DIR/context.md" << EOF
# Current Context

> **Last Updated**: $DATE
> **Branch**: $BRANCH

## Active Work

**Current Task**: [What you're currently working on]

**Status**: [In progress / Blocked / Ready for review]

**Files Modified**:
- [List key files being modified]

## Recently Completed

- [$DATE] [Recent completed item]

## Pending / Blocked

- **Pending**: [Tasks waiting to be done]
- **Blocked**: [Tasks blocked on something - note what]

## Context for Next Session

[Important context the next session needs to know:
- Where you left off
- Any half-finished work
- Key decisions made
- Gotchas discovered]

## Related Patterns

- See \`.ai/patterns/\` for established patterns
- Reference \`decisions.md\` for architectural context

---

*Keep this file under 200 lines. Move old context to \`sessions/YYYY-MM-DD.md\` if needed.*
EOF
    echo -e "  [✓] Created .claude/memory/context.md"
else
    echo -e "  [!] context.md already exists, skipping"
fi

# decisions.md
if [ ! -f "$MEMORY_DIR/decisions.md" ]; then
    cat > "$MEMORY_DIR/decisions.md" << 'EOF'
# Architectural Decisions

> **Append new decisions at the bottom. Don't modify old entries.**

This log tracks significant architectural and design decisions for this project.

---

<!-- Template for new entries:

## [YYYY-MM-DD] Decision Title

**Context**: Why this decision was needed

**Decision**: What was decided

**Reasoning**:
- Key point 1
- Key point 2

**Alternatives Considered**:
1. **[Alternative A]** - [Why rejected]
2. **[Alternative B]** - [Why rejected]

**Consequences**:
- [Impact of this decision]

**References**: [Links to relevant docs or patterns]

---

-->
EOF
    echo -e "  [✓] Created .claude/memory/decisions.md"
else
    echo -e "  [!] decisions.md already exists, skipping"
fi

echo -e "  [✓] Created .claude/memory/sessions/"

# ─────────────────────────────────────────────────────────────────────────────
# Create CLAUDE.md entry point
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}>>> Creating CLAUDE.md entry point...${NC}"

# CLAUDE.md
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
    echo -e "${YELLOW}  [!] CLAUDE.md exists${NC}"
    read -p "      Overwrite? (y/N): " overwrite_claude
    if [[ "$overwrite_claude" =~ ^[Yy]$ ]]; then
        cp "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md.backup"
        WRITE_CLAUDE=true
    fi
else
    WRITE_CLAUDE=true
fi

if [ "${WRITE_CLAUDE:-}" = "true" ]; then
    cat > "$PROJECT_DIR/CLAUDE.md" << EOF
# $PROJECT_NAME - Claude Instructions

> **Maintaining Instructions**: See [.ai/meta/sync-guide.md](.ai/meta/sync-guide.md) for guidelines.

## Documentation Hub

**Entry Point**: \`.ai/README.md\`

| Topic | Location |
|-------|----------|
| Overview | \`.ai/README.md\` |
| Architecture | \`.ai/core/application-architecture.md\` |
| Tech Stack | \`.ai/core/technology-stack.md\` |
| Workflow | \`.ai/development/development-workflow.md\` |
| Testing | \`.ai/development/testing-patterns.md\` |
| Patterns | \`.ai/patterns/\` |

## Memory System

- **Current State**: \`.claude/memory/context.md\` (read at start, update at end)
- **Decision Log**: \`.claude/memory/decisions.md\` (append-only)
- **Session History**: \`.claude/memory/sessions/\` (optional daily notes)

## Project Policies

### Documentation
- **Sources of truth**: \`.ai/\` (static) + \`.claude/memory/\` (dynamic)
- **Single location**: Each fact in ONE place
- **Cross-reference**: Never duplicate
- **Version numbers**: ONLY in \`.ai/core/technology-stack.md\`

## Completion Protocol

When work is complete, **always** finish with:

1. **Commit** changes with descriptive message (conventional commits)
2. **Push** to remote branch
3. **Create PR** with summary and test plan
4. **Report** PR URL to user

## Project-Specific Notes

<!-- Add project-specific commands, conventions, gotchas below -->

**Commands:**
- Run tests: \`[command]\`
- Build: \`[command]\`
- Lint: \`[command]\`

---

*Claude reads \`.ai/\` for documentation. Memory hooks provide session continuity.*
EOF
    echo -e "  [✓] Created CLAUDE.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Update .gitignore
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}>>> Checking .gitignore...${NC}"

if [ -f "$PROJECT_DIR/.gitignore" ]; then
    # Add .ai temp files if not present
    if ! grep -q "\.ai/\*\.tmp" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo "" >> "$PROJECT_DIR/.gitignore"
        echo "# AI documentation temp files" >> "$PROJECT_DIR/.gitignore"
        echo ".ai/*.tmp" >> "$PROJECT_DIR/.gitignore"
        echo -e "  [✓] Added .ai/*.tmp to .gitignore"
    fi

    # Add .ai.backup if not present
    if ! grep -q "\.ai\.backup" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo ".ai.backup/" >> "$PROJECT_DIR/.gitignore"
        echo -e "  [✓] Added .ai.backup/ to .gitignore"
    fi
else
    echo -e "  [!] No .gitignore found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check for legacy documentation
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}>>> Documentation audit...${NC}"

for legacy_dir in docs DOCS documentation wiki notes; do
    if [ -d "$PROJECT_DIR/$legacy_dir" ]; then
        echo -e "${YELLOW}  [!] Found legacy docs folder: $legacy_dir/${NC}"
        echo -e "      Consider migrating to .ai/"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Complete
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Project Setup Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Created:"
echo "  .ai/                    - Documentation hub"
echo "  .claude/memory/         - Session memory"
echo "  CLAUDE.md               - Claude Code entry point"
echo ""
echo "Next steps:"
echo "  1. Start a Claude Code session in this project"
echo "  2. Copy and paste the prompt below to populate .ai/ documentation"
echo ""
echo "Ensure global hooks are installed:"
echo "  ~/.claude/unseveredmemory-global.sh"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    COPY AND PASTE TO CLAUDE:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
cat << 'PROMPT'
Conduct a comprehensive documentation audit and integration project for this codebase by systematically analyzing, organizing, and consolidating all text-based materials into the existing @.ai/ folder documentation framework. Begin by thoroughly examining the current @.ai/ folder structure to understand the existing documentation system, including what files are present, how information is organized, and where specific types of content should be appended or integrated. Next, perform an in-depth analysis of the project's actual codebase, treating the working code as the authoritative source of truth about functionality, architecture, and purpose, then use these insights to enhance and complete the @.ai/ documentation system with accurate technical specifications and operational context. Following the code analysis, systematically search throughout the entire project directory to locate and catalog all documentation-related files and folders, including .txt, .md, .pdf documents, research materials, diagnostic reports, project plans, notes, and any other relevant documentation (excluding claude.md). Once all documentation materials have been identified, carefully review their contents and strategically append the relevant information to the appropriate corresponding files within the established @.ai/ folder system, ensuring that data is integrated logically without creating new files or folders. After completing the integration process, create a new folder named "olddoccontext" in the project root directory and relocate all the original documentation files and folders that were processed during the audit, effectively centralizing these materials while maintaining the enhanced @.ai/ documentation system as the primary source of project information. Throughout this entire process, utilize the @agent-orchestrator tool to maximize efficiency and ensure systematic completion of each phase, ultimately delivering a comprehensive, well-organized documentation framework that accurately captures all technical specifications, operational contexts, and project details within the existing @.ai/ folder structure.
PROMPT
echo ""

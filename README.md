<div align="center">

<img src="Unsevered.jpeg" alt="Unsevered Memory" width="200">

# Unsevered Memory

![Claude Code](https://img.shields.io/badge/Claude_Code-Hooks-d97757?logo=anthropic) ![Bash](https://img.shields.io/badge/Bash-Scripts-4EAA25?logo=gnubash&logoColor=white) ![Markdown](https://img.shields.io/badge/Markdown-Docs-000000?logo=markdown) ![jq](https://img.shields.io/badge/jq-JSON-CB171E)

A markdown-based memory system for Claude Code. Zero dependencies. Zero latency. Works offline.

</div>

## Overview

Unsevered Memory provides cross-session continuity for Claude Code by leveraging its built-in hooks system:

1. **`.ai/`** - Static documentation (architecture, patterns, workflows)
2. **`.claude/memory/`** - Dynamic memory (context, decisions, sessions)

This is Claude Code using its native features organically. No external APIs, no databases, just markdown files and shell hooks.

## Installation

### Step 1: Global Setup (Once)

```bash
./unseveredmemory-global.sh
```

This installs to `~/.claude/`:
- `CLAUDE.md` - Global instructions with memory protocol
- `settings.json` - Hook configurations
- `unseveredmemory-project.sh` - Project scaffolding script
- `hooks/session-start.sh` - Memory primer
- `hooks/session-end.sh` - Memory reminder

### Step 2: Project Setup (Per Project)

```bash
~/.claude/unseveredmemory-project.sh /path/to/your/project
```

Or from within the project directory:
```bash
cd /path/to/your/project
~/.claude/unseveredmemory-project.sh
```

This creates:
```
your-project/
├── CLAUDE.md                    # Claude Code entry point
├── .ai/                         # Documentation hub
│   ├── README.md
│   ├── core/
│   │   ├── technology-stack.md
│   │   ├── project-overview.md
│   │   ├── application-architecture.md
│   │   └── deployment-architecture.md
│   ├── development/
│   │   ├── development-workflow.md
│   │   └── testing-patterns.md
│   ├── patterns/
│   │   ├── database-patterns.md
│   │   ├── frontend-patterns.md
│   │   ├── security-patterns.md
│   │   └── api-and-routing.md
│   └── meta/
│       ├── maintaining-docs.md
│       └── sync-guide.md
└── .claude/
    └── memory/
        ├── context.md           # Current state
        ├── decisions.md         # Decision log
        └── sessions/            # Daily notes
```

## How It Works

Unsevered Memory uses Claude Code's native hooks feature to maintain session continuity:

### Session Start
The `session-start.sh` hook automatically reads `.claude/memory/context.md` and injects it as context, so Claude knows where you left off.

### During Work
Claude references `.ai/` for architectural documentation and established patterns.

### Session End
The `session-end.sh` hook reminds Claude to update `.claude/memory/context.md` with current state before the session ends.

## Two Sources of Truth

| Source | Purpose | Updates |
|--------|---------|---------|
| `.ai/` | Static documentation | When architecture changes |
| `.claude/memory/` | Dynamic context | Every session |

### `.ai/` Structure

- **core/** - Technology stack, architecture, project overview
- **development/** - Workflows, testing patterns
- **patterns/** - Code patterns, security, API design
- **meta/** - Documentation maintenance guides

### `.claude/memory/` Structure

- **context.md** - Current work state, modified files, pending tasks
- **decisions.md** - Architectural decision log (append-only)
- **sessions/** - Daily session notes (optional)

## Uninstall

To remove global hooks:
```bash
./unseveredmemory-global.sh --uninstall
```

## Repository Structure

```
unsevered-memory/
├── README.md
├── unseveredmemory-global.sh    # Global setup script
├── unseveredmemory-project.sh   # Project setup script
├── hooks/
│   ├── session-start.sh         # Memory primer hook
│   └── session-end.sh           # Memory reminder hook
└── templates/
    ├── global-claude.md.template
    ├── project-claude.md.template
    ├── context.md.template
    ├── decisions.md.template
    └── session.md.template
```

## Philosophy

- **Zero dependencies** - Pure bash + jq (usually pre-installed)
- **Zero latency** - No API calls, no databases
- **Works offline** - Everything is local markdown
- **Organically Claude** - Uses Claude Code's built-in hooks, nothing external
- **Simple** - ~1,500 lines total, two scripts, done

<div align="center">

<img src="Unsevered.jpeg" alt="Unsevered Memory" width="200">

# Unsevered Memory

![Claude Code](https://img.shields.io/badge/Claude_Code-Hooks-d97757?logo=anthropic) ![Bash](https://img.shields.io/badge/Bash-Scripts-4EAA25?logo=gnubash&logoColor=white) ![Markdown](https://img.shields.io/badge/Markdown-Docs-000000?logo=markdown)

A markdown-based memory system for Claude Code with enforced persistence.

Zero dependencies. Zero latency. Works offline.

</div>

## What Makes This Different

Most memory systems inject context at session start and hope Claude remembers. This doesn't work because:

1. Context compaction loses early instructions
2. Claude has no obligation to follow suggestions
3. Long sessions forget the protocol

**Unsevered Memory solves this with enforcement:**

| Hook | When | Purpose |
|------|------|---------|
| `SessionStart` | Session begins | Load full context |
| `UserPromptSubmit` | Every prompt | Inject state reminder |
| `SessionEnd` | Session ends | Archive + remind |

The `UserPromptSubmit` hook survives context compaction by being injected fresh on every message.

## Architecture

```
Enforcement Layer
├── SessionStart ──────> Load context.md + scratchpad
├── UserPromptSubmit ──> [Memory] Task: X | Scratchpad: Y lines
└── SessionEnd ────────> Archive scratchpad, remind to update

File Structure
├── .claude/memory/     # Dynamic (every session)
│   ├── context.md      # Current state, next steps
│   ├── scratchpad.md   # Live session operations
│   ├── decisions.md    # Architectural choices
│   └── sessions/       # Daily archives
│
└── .ai/                # Static (when patterns emerge)
    ├── core/           # Tech stack, architecture
    ├── patterns/       # Reusable solutions (after 3+ uses)
    └── workflows/      # Dev processes
```

## Installation

### Step 1: Global Setup (Once)

```bash
git clone https://github.com/blas0/UnseveredMemory.git
cd UnseveredMemory
./setup-global.sh
```

Installs to `~/.claude/`:
- `CLAUDE.md` - Global memory protocol
- `settings.json` - Hook configuration (3 hooks)
- `hooks/` - memory-load, memory-remind, memory-save
- `skills/harness/` - Workflow instructions
- `commands/harness.md` - Orchestrator command
- `setup-project.sh` - Project scaffolding

### Step 2: Project Setup (Per Project)

```bash
cd /path/to/your/project
~/.claude/setup-project.sh
```

Creates:
```
project/
├── CLAUDE.md               # Project instructions
├── .ai/                    # Static documentation
│   ├── core/
│   │   ├── technology-stack.md
│   │   └── architecture.md
│   ├── patterns/
│   └── workflows/
└── .claude/
    └── memory/
        ├── context.md      # Cross-session state
        ├── scratchpad.md   # Live session log
        ├── decisions.md    # Decision log
        └── sessions/       # Daily archives
```

### Step 3: Use Claude Code

```bash
claude
# Memory loads automatically. Reminder appears on every prompt.
```

## Workflow

### Session Start
1. Hook loads `context.md` and `scratchpad.md`
2. Claude sees current state and any unfinished work
3. Hook hints about `.ai/` documentation

### During Session
Every prompt shows:
```
[Memory] Task: Fix auth bug | Scratchpad: 24 lines | .ai/ updated: 2024-01-15
```

Claude writes to `scratchpad.md` as it works:
```markdown
## Session: 2024-01-15 14:30

### Operations
- [14:35] Found issue in validateToken() at src/auth.ts:142
- [14:40] Fixed: was comparing wrong field

### Decisions
- Keep backward compatibility by checking both fields
```

Claude updates `.ai/` when patterns emerge (3+ uses).

### Session End
1. Hook archives scratchpad to `sessions/YYYY-MM-DD.md`
2. Hook reminds to update `context.md`
3. Claude updates context with current state

## Orchestrator Mode

For complex multi-step tasks:

```
/harness Implement user authentication with JWT
```

The orchestrator:
1. Reads all memory files
2. Breaks task into subtasks
3. Delegates to specialized agents
4. Updates memory after each step
5. Never loses context

## File Purposes

| File | Content | Update Frequency |
|------|---------|------------------|
| `context.md` | Current state, next steps | End of session |
| `scratchpad.md` | Operations, findings | During session |
| `decisions.md` | Architectural choices | When decisions made |
| `.ai/core/` | Tech stack, architecture | When they change |
| `.ai/patterns/` | Reusable solutions | After 3+ uses |

## Repository Structure

```
UnseveredMemory/
├── README.md
├── setup-global.sh           # Global installer
├── hooks/
│   ├── memory-load.sh        # SessionStart
│   ├── memory-remind.sh      # UserPromptSubmit (enforcer)
│   └── memory-save.sh        # SessionEnd
├── skills/
│   └── harness/
│       └── SKILL.md          # Workflow instructions
├── commands/
│   └── harness.md            # /harness orchestrator
└── templates/
    ├── CLAUDE.md.template
    ├── PROJECT-CLAUDE.md.template
    ├── context.md.template
    ├── decisions.md.template
    ├── scratchpad.md.template
    └── .ai/                  # Documentation templates
```

## Philosophy

- **Enforced** - UserPromptSubmit hook survives context compaction
- **Simple** - Bash + markdown, no databases, no APIs
- **Offline** - Everything is local files
- **Native** - Uses Claude Code's built-in hooks system
- **Proactive** - Claude updates .ai/ during work, not after

## Enforcement Levels

| Approach | Reliability | This System |
|----------|-------------|-------------|
| CLAUDE.md only | ~30% | Base |
| + SessionStart | ~50% | Included |
| + UserPromptSubmit | ~75% | Included |
| + /harness orchestrator | ~95% | Available |

## Uninstall

```bash
# Remove global installation
rm -rf ~/.claude/hooks/memory-*.sh
rm -rf ~/.claude/skills/harness
rm -rf ~/.claude/commands/harness.md
rm ~/.claude/setup-project.sh
# Restore settings.json manually

# Remove from project
rm -rf .claude/memory
rm -rf .ai
```

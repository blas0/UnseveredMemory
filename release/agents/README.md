# Claude Code Agents

Custom agents for Claude Code that extend its capabilities through specialized orchestration patterns.

## Installation

Agents are automatically deployed to `~/.claude/agents/` during CAM setup:

```bash
./setup.sh
```

Or manually copy:

```bash
cp -r agents/ ~/.claude/agents/
```

## Available Agents

### orchestrator

**Purpose**: Meta-agent that decomposes complex tasks and delegates to specialized Claude Code agents.

**When to Use**:
- Multi-step tasks requiring coordination
- Tasks that benefit from parallel execution
- Complex projects needing research → planning → implementation flow

**Invocation**:
```
# Via slash command (if configured)
/orchestrator

# Via Task tool
Task(subagent_type="orchestrator", prompt="Your complex task here")
```

**Capabilities**:
- Spawns `Explore`, `Plan`, `general-purpose`, and `claude-code-guide` agents
- Maximizes parallel execution for independent subtasks
- Tracks progress via TodoWrite
- Synthesizes results from multiple agents

## Agent Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Request                         │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR                         │
│  • Analyzes intent                                      │
│  • Decomposes into subtasks                             │
│  • Identifies parallelization opportunities             │
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
     ┌──────────┐    ┌──────────┐    ┌──────────┐
     │ Explore  │    │   Plan   │    │ general- │
     │ (haiku)  │    │ (sonnet) │    │ purpose  │
     │          │    │          │    │ (sonnet) │
     │ Discovery│    │ Strategy │    │ Implement│
     └──────────┘    └──────────┘    └──────────┘
            │               │               │
            └───────────────┼───────────────┘
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR                         │
│  • Synthesizes results                                  │
│  • Reports to user                                      │
└─────────────────────────────────────────────────────────┘
```

## Environment Integration

Agents inherit environment configuration automatically:

| Component | Inheritance |
|-----------|-------------|
| `~/.claude/CLAUDE.md` | Global instructions flow to all agents |
| CAM hooks | Fire for agent operations (if CAM is configured) |
| Working directory | Agents operate in same project context |
| Tool permissions | Defined in agent frontmatter |

**No manual CAM configuration needed**—agents operate in the CAM-enabled environment naturally.

## Creating Custom Agents

Agents are Markdown files with YAML frontmatter:

```markdown
---
name: my-agent
description: Brief description shown in agent list
tools: Task, Read, Write, Edit, Bash, Glob, Grep
---

# Agent Instructions

Your agent's system prompt goes here...
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Agent identifier (used in Task tool) |
| `description` | Yes | Shown when listing agents |
| `tools` | No | Comma-separated tool allowlist |

### Storage Locations

- **Global**: `~/.claude/agents/` (available in all projects)
- **Project**: `.claude/agents/` (project-specific)

Project agents override global agents with the same name.

## Best Practices

### 1. Keep Agents Focused

Each agent should have a clear, singular purpose. The orchestrator coordinates—specialists execute.

### 2. Write Complete Prompts

When spawning agents, include all context they need. Agents don't share memory.

```markdown
# Good
Task(subagent_type="Explore", prompt="""
Find authentication middleware in this Express.js codebase.
Look for:
- Files in src/middleware/
- JWT or session handling
- Auth-related route guards
""")

# Bad
Task(subagent_type="Explore", prompt="Find auth stuff")
```

### 3. Parallelize When Possible

Independent tasks should spawn simultaneously:

```markdown
# Parallel (good for independent tasks)
Task(subagent_type="Explore", prompt="Find all API routes...")
Task(subagent_type="Explore", prompt="Find all tests...")
Task(subagent_type="Explore", prompt="Find all configs...")
```

### 4. Use Appropriate Models

- `haiku`: Fast searches, simple lookups
- `sonnet`: Standard implementation work
- `opus`: Complex reasoning, architecture decisions

```markdown
Task(subagent_type="general-purpose", model="opus", prompt="Analyze architecture...")
```

## Troubleshooting

### Agent Not Found

Ensure the agent file is in `~/.claude/agents/` with correct frontmatter:

```bash
ls ~/.claude/agents/
cat ~/.claude/agents/orchestrator.md | head -10
```

### Agent Not Inheriting CAM

CAM hooks fire based on `~/.claude/settings.json`. Verify hooks are configured:

```bash
cat ~/.claude/settings.json | jq '.hooks'
```

### Agent Spawning Fails

Check that spawned `subagent_type` values are valid:
- `Explore`
- `Plan`
- `general-purpose`
- `claude-code-guide`
- Custom agent names from `~/.claude/agents/`

## Version History

| Version | Changes |
|---------|---------|
| 1.0.0 | Initial orchestrator agent |

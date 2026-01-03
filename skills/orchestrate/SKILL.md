# Unsevered Memory - Workflow Skill

You are operating with persistent memory. This skill defines how to maintain context across sessions.

## Memory Architecture

### Two Sources of Truth

| Location | Type | Purpose | Update Frequency |
|----------|------|---------|------------------|
| `.claude/memory/` | Dynamic | Session state, decisions | Every session |
| `.ai/` | Static | Architecture, patterns | When patterns emerge |

### File Purposes

| File | Content | When to Update |
|------|---------|----------------|
| `context.md` | Current state, next steps | End of session |
| `scratchpad.md` | Live session operations | During session |
| `decisions.md` | Architectural choices | When decisions made |
| `.ai/core/` | Tech stack, architecture | When they change |
| `.ai/patterns/` | Reusable solutions | After 3+ uses |

---

## Session Workflow

### On Session Start

1. Memory hook automatically loads `context.md`
2. Review the current state and task
3. Check `scratchpad.md` for unfinished work
4. Reference `.ai/` for patterns and architecture

### During Session

**Write to scratchpad.md as you work:**

```markdown
## Session: 2024-01-15 14:30

### Operations
- [14:31] Read context.md - last session worked on auth
- [14:32] User asked to fix login bug
- [14:35] Found issue in validateToken() at src/auth.ts:142
- [14:40] Fixed: was comparing wrong field

### Findings
- Token validation was checking user.id instead of user.uid
- Only affects users created after migration

### Decisions
- Keep backward compatibility by checking both fields

### Blockers
(none)

### Next Steps
- Add regression test for token validation
```

**Update .ai/ when patterns emerge:**

After implementing the same solution 3+ times, add it to `.ai/patterns/`.

### On Session End

1. Hook archives scratchpad to `sessions/YYYY-MM-DD.md`
2. Update `context.md` with:
   - What was accomplished
   - Current state
   - Next steps
3. Append architectural decisions to `decisions.md`

---

## Live Documentation Updates

### When to Update .ai/

During your session, proactively update `.ai/` when you encounter:

| Trigger | Location | Example |
|---------|----------|---------|
| Pattern used 3+ times | `.ai/patterns/` | Error handling, API structure |
| Architecture change | `.ai/core/architecture.md` | New service layer |
| Stack change | `.ai/core/technology-stack.md` | New dependency |
| Workflow improvement | `.ai/workflows/` | Better test process |

### How to Update

Do not wait for session end. Update as you go:

1. Notice a pattern emerging
2. Add/update relevant `.ai/` file immediately
3. Log the update in scratchpad
4. Continue working

Example scratchpad entry:
```markdown
### Operations
- [14:35] Implemented error handling in 3 endpoints
- [14:40] Pattern detected - created .ai/patterns/error-handling.md
- [14:45] Applied pattern to remaining endpoints
```

---

## Decision Tree: Where Does This Go?

```
Is this information:

[Specific to today's work?]
    YES --> scratchpad.md

[An architectural decision?]
    YES --> decisions.md (also update .ai/ if changes architecture)

[A reusable pattern?]
    YES --> .ai/patterns/

[About the tech stack?]
    YES --> .ai/core/technology-stack.md

[Current project state?]
    YES --> context.md
```

---

## File Templates

### context.md

```markdown
# Project Context

## Current State
[What is the current state of the project/feature?]

## Current Task
[What are we working on right now?]

## Last Session
- Date: YYYY-MM-DD
- Accomplished: [summary]
- Stopped at: [where we left off]

## Next Steps
1. [First thing to do]
2. [Second thing to do]

## Active Branches
- feature/xxx - [purpose]

## Notes
[Any context the next session needs]
```

### scratchpad.md

```markdown
# Scratchpad

Session: YYYY-MM-DD HH:MM

## Operations
- [HH:MM] Action taken

## Findings
- What was discovered

## Decisions
- Choices made and rationale

## Blockers
- Issues encountered

## Next Steps
- What to do if session ends
```

### decisions.md

```markdown
# Decision Log

## YYYY-MM-DD: [Decision Title]

**Context**: [Why was this decision needed?]

**Options Considered**:
1. Option A - pros/cons
2. Option B - pros/cons

**Decision**: [What was chosen]

**Rationale**: [Why this option]

**Consequences**: [What this means going forward]
```

---

## Enforcement

The `UserPromptSubmit` hook displays memory state on every prompt:

```
[Memory] Task: Fix auth bug | Scratchpad: 24 lines | .ai/ updated: 2024-01-15
```

This reminder survives context compaction. Use it to stay oriented.

---

## Commands

### /orchestrate

Activates orchestrator mode for complex tasks. The orchestrator:
1. Reads all memory files
2. Breaks task into subtasks
3. Delegates to specialized agents
4. Updates memory after each step
5. Never loses context

Use for multi-step tasks requiring persistent state management.

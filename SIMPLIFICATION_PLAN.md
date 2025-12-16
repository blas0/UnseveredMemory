# CAM Simplification Plan

## Executive Summary

This document proposes simplifying CAM from a 11,000+ line vector-embedding system to a ~50 line markdown-based memory system. The goal is to eliminate startup latency, remove external dependencies, and leverage Claude's native ability to read and understand text.

---

## Problem Statement

### Current Issues

1. **Startup Latency**: 1.5-4 seconds overhead from 3 Python invocations + Gemini API calls
2. **Dependency Burden**: Requires Python 3.9+, numpy, scipy, google-generativeai, jq, sqlite3, Gemini API key
3. **Complexity**: 14 hooks, 4 SQLite databases, 11,135 lines of code
4. **Offline Failure**: Requires network access to Gemini API
5. **Per-Project Setup**: Each project needs `init-cam.sh`, Python venv, database initialization

### Root Cause

Vector embeddings solve a problem Claude doesn't have. Claude can read markdown and understand semantics natively—it doesn't need a 768-dimensional vector to know that "login flow" relates to "auth patterns."

---

## Proposed Solution

Replace the entire CAM infrastructure with plain markdown files that Claude reads naturally.

### Design Principles

1. **Zero dependencies** — Just markdown files
2. **Zero latency** — No API calls, no Python startup
3. **Works offline** — No network required
4. **Human readable** — Debug by opening a text file
5. **Leverages existing behavior** — Claude already reads CLAUDE.md

---

## Architecture

### File Structure

```
~/.claude/
└── CLAUDE.md                      # Global preferences (optional)

your-project/
├── CLAUDE.md                      # Project entry point
├── .ai/                           # Documentation hub
│   ├── README.md                  # Project overview
│   ├── core/
│   │   ├── architecture.md        # System architecture
│   │   └── stack.md               # Technology stack
│   ├── development/
│   │   ├── workflow.md            # Dev workflow
│   │   └── testing.md             # Testing strategy
│   └── patterns/
│       └── [pattern].md           # Code patterns
└── .claude/
    └── memory/
        ├── context.md             # Current working state
        ├── decisions.md           # Architectural decisions (append-only)
        └── sessions/              # Optional session history
            └── [YYYY-MM-DD].md
```

### How It Works

1. **Session Start**: Claude reads `CLAUDE.md`, which points to `.ai/` and `.claude/memory/`
2. **During Work**: Claude references docs as needed, appends decisions to `decisions.md`
3. **Session End**: Claude updates `context.md` with current state
4. **Next Session**: Claude reads `context.md` to understand where we left off

No hooks required. No databases. No API calls.

---

## File Specifications

### Global: `~/.claude/CLAUDE.md`

```markdown
# Global Instructions

## Coding Preferences
- [Your coding style preferences]
- [Commit conventions]

## Memory Protocol

For projects with `.claude/memory/`:
1. Read `context.md` at session start
2. Append significant decisions to `decisions.md`
3. Update `context.md` before ending work
```

### Project: `./CLAUDE.md`

```markdown
# Project Instructions

## Documentation
| Topic | Location |
|-------|----------|
| Overview | `.ai/README.md` |
| Architecture | `.ai/core/architecture.md` |
| Stack | `.ai/core/stack.md` |
| Patterns | `.ai/patterns/` |

## Memory
- `.claude/memory/context.md` — Current state (read at start, update at end)
- `.claude/memory/decisions.md` — Decision log (append-only)

## Quick Reference
[Project-specific commands, conventions, or notes]
```

### `.claude/memory/context.md`

```markdown
# Current Context

## Active Work
[What's currently being worked on]

## Recently Completed
- [Recent items]

## Pending / Blocked
- [Waiting items]

## Notes
[Context for next session]

---
*Last updated: YYYY-MM-DD*
```

### `.claude/memory/decisions.md`

```markdown
# Architectural Decisions

Append new decisions at the bottom. Don't modify old entries.

---

## [YYYY-MM-DD] Decision Title

**Context**: Why this decision was needed

**Decision**: What was decided

**Reasoning**: Why this choice

**Alternatives Considered**: What else was evaluated

---
```

---

## Implementation Plan

### Phase 1: Create Simplified System

**Files to Create:**
- [ ] `simple/CLAUDE.md.template` — Project template
- [ ] `simple/global-claude.md.template` — Global template
- [ ] `simple/init.sh` — Simple initialization script (~30 lines)
- [ ] `simple/README.md` — Usage documentation

**Estimated Size**: ~200 lines total

### Phase 2: Migration Guide

**Documentation:**
- [ ] How to migrate from CAM to simple memory
- [ ] What to preserve (decisions, patterns)
- [ ] What to discard (databases, hooks)

### Phase 3: Optional Enhancements

**If desired, add minimal hooks:**
- [ ] Session-end hook that reminds to update context.md
- [ ] Pre-compact hook that auto-updates context.md

These are optional—the system works without them.

---

## Comparison

| Metric | Current CAM | Proposed |
|--------|-------------|----------|
| Lines of code | 11,135 | ~200 |
| Hooks | 14 | 0-1 |
| Databases | 4 SQLite | 0 |
| External APIs | Gemini | None |
| Python required | Yes + venv | No |
| Startup latency | 1.5-4s | 0ms |
| Works offline | No | Yes |
| Per-project setup | Complex init | `mkdir -p` |
| Debuggable | Query DBs | Open markdown |

---

## What We Preserve

1. **`.ai/` structure** — Excellent documentation organization
2. **Decision tracking** — Now in `decisions.md`
3. **Session continuity** — Now in `context.md`
4. **Cross-session memory** — Just files Claude reads

## What We Remove

1. Vector embeddings (Claude understands text natively)
2. Gemini API dependency
3. Python/numpy/scipy infrastructure
4. 4 SQLite databases
5. 14 shell hook scripts
6. Complex caching layer
7. Graph relationships (Claude understands context)

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Loss of semantic search | Claude can grep + understand context from markdown |
| No automatic ingestion | Claude reads files on demand; no ingestion needed |
| Manual context updates | Simple habit; can add optional reminder hook |
| Loss of session history | `sessions/` directory preserves if wanted |

---

## Success Criteria

1. **Zero startup latency** from memory system
2. **No external dependencies** required
3. **Works offline** completely
4. **Human-readable** memory files
5. **Same cross-session continuity** as CAM promised

---

## Open Questions

1. Should we keep CAM as an optional "power user" mode for very large codebases?
2. Should sessions/ auto-populate or be manual?
3. What's the migration path for existing CAM users?

---

## Next Steps

1. Review and approve this plan
2. Implement Phase 1 (create simplified system)
3. Test on a real project
4. Document migration path
5. Deprecate or archive complex CAM

---

*This plan prioritizes simplicity over sophistication. Claude's strength is understanding text—we should leverage that instead of working around it.*

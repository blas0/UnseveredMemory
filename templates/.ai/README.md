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

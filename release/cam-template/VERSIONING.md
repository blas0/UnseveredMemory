# CAM Versioning Scheme

**Authority**: This versioning scheme is the source of truth for all CAM updates.

---

## Version Format

```
MAJOR.MINOR.PATCH
  2    .   0   .   1
```

---

## Simple Rule: Any Code Change = Patch Increment

**Every code change increments the patch version by 1.**

```
2.0.0 → 2.0.1 → 2.0.2 → 2.0.3 → 2.1.0 → ...
```

### What Counts as "Code Change"
- Hook script modifications (*.sh)
- cam_core.py changes
- cam.sh changes
- Any functional code in cam-template/

### What Does NOT Increment Version
- README.md updates
- CHANGELOG.md updates (version already bumped)
- Documentation-only changes (.md files)
- Comments-only changes

---

## Files That Must Be Updated Together

**ALL of these must show the same version:**

| File | Location | Update Method |
|------|----------|---------------|
| `VERSION.txt` | `~/.claude/cam-template/VERSION.txt` | Plain text |
| `VERSION.txt` | `/release/cam-template/VERSION.txt` | Plain text |
| `cam_core.py` | Both locations, line 26 | `CAM_VERSION = "x.y.z"` |
| All hooks | `# Version: x.y.z` header | Comment on line 3-5 |

---

## Update Procedure

### When you modify any code file:

1. **Increment patch version**:
   ```
   Current: 2.0.0
   New:     2.0.1
   ```

2. **Update these files**:
   ```bash
   # VERSION.txt (both locations)
   echo "2.0.1" > ~/.claude/cam-template/VERSION.txt
   echo "2.0.1" > /release/cam-template/VERSION.txt

   # cam_core.py CAM_VERSION (both locations)
   # Line 26: CAM_VERSION = "2.0.1"

   # Modified hook(s) version header
   # Line 3-5: # Version: 2.0.1
   ```

3. **Add CHANGELOG entry** (if significant change)

4. **Sync to all locations**:
   ```bash
   ~/.claude/hooks/cam-sync-template.sh
   ```

---

## Hook Version Header Format

All hooks should have a version header in lines 1-5:

```bash
#!/bin/bash
# ~/.claude/hooks/example-hook.sh
# Description of hook purpose
# Version: 2.0.0
```

---

## Current Version

**v2.0.0** - Consolidated release with:
- Phase 1: Extended Data Model (importance, decisions, invariants, causal)
- Phase 2: Hook System Enhancements
- Phase 3: Query DSL (TOML, graph, multi-hop)
- Phase 4: CMR (inflection, compression, reconstruction, adaptive)
- PR Workflow hook

---

## Verification

Before committing:
- [ ] VERSION.txt updated in `~/.claude/cam-template/`
- [ ] VERSION.txt updated in `/release/cam-template/`
- [ ] cam_core.py CAM_VERSION updated (both locations)
- [ ] Modified hooks have version header updated
- [ ] `./cam.sh version` shows correct version

---

## Rationale

**Why always increment patch?**
- Simple, predictable versioning
- No ambiguity about "is this a minor or patch change"
- Clear audit trail of changes
- Easy to track what version introduced what

**When to increment minor/major?**
- Minor (2.1.0): Reserved for new feature phases
- Major (3.0.0): Reserved for breaking changes or redesigns
- Both are rare; patch increments are the norm

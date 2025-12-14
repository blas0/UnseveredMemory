#!/bin/bash
# ~/.claude/hooks/session-end-with-pr.sh
# Enhanced SessionEnd Hook with PR Workflow (Optional)
# Version: 2.0.0
# Purpose: Crystallize session to CAM + create PR for review (not auto-commit)

set -e

SESSION_ID="${1}"
SESSION_END_TIME=$(date -u +%s)
CWD_OVERRIDE="${2:-}"

# Get session state
SESSION_STATE_DIR="$HOME/.claude/.session-state"
SESSION_STATE_FILE="$SESSION_STATE_DIR/${SESSION_ID}.json"

if [ ! -f "$SESSION_STATE_FILE" ]; then
  echo '{"continue": true}'
  exit 0
fi

CWD=$(jq -r '.cwd // ""' "$SESSION_STATE_FILE")
CWD="${CWD_OVERRIDE:-$CWD}"

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo '{"continue": true}'
  exit 0
fi

cd "$CWD" || exit 1

# Skip if CAM not initialized
if [ ! -d "./.claude/cam" ]; then
  echo '{"continue": true}'
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 1: GATHER SESSION INTELLIGENCE
# ═══════════════════════════════════════════════════════════════════════════

# Get operations log
OPS_LOG="./.claude/cam/operations.log"
SESSION_OPS=$(grep "$SESSION_ID" "$OPS_LOG" 2>/dev/null | tail -50 || echo "")

# Count operation types
EDIT_COUNT=$(echo "$SESSION_OPS" | grep -c "Edit" || echo "0")
WRITE_COUNT=$(echo "$SESSION_OPS" | grep -c "Write" || echo "0")
BASH_COUNT=$(echo "$SESSION_OPS" | grep -c "Bash" || echo "0")
READ_COUNT=$(echo "$SESSION_OPS" | grep -c "Read" || echo "0")

# Get git information
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_STATUS=$(git status --short 2>/dev/null | wc -l || echo "0")
  FILES_MODIFIED=$(git status --short 2>/dev/null | cut -d' ' -f3 | sort -u)
  PRIMARY_FILE=$(echo "$FILES_MODIFIED" | head -1)
else
  GIT_STATUS="0"
  FILES_MODIFIED=""
  PRIMARY_FILE=""
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 2: DETERMINE COMMIT TYPE
# ═══════════════════════════════════════════════════════════════════════════

# Type inference based on operation counts
COMMIT_TYPE="chore"  # default

if [ "$EDIT_COUNT" -gt 0 ] || [ "$WRITE_COUNT" -gt 0 ]; then
  # Determine if feature or fix
  if grep -q "feat\|feature\|add\|new" <(echo "$SESSION_OPS"); then
    COMMIT_TYPE="feat"
  elif grep -q "fix\|bug\|error\|resolve\|correct" <(echo "$SESSION_OPS"); then
    COMMIT_TYPE="fix"
  elif grep -q "refactor\|reorganize\|restructure" <(echo "$SESSION_OPS"); then
    COMMIT_TYPE="refactor"
  elif grep -q "test" <(echo "$SESSION_OPS"); then
    COMMIT_TYPE="test"
  elif grep -q "perf\|performance\|optim" <(echo "$SESSION_OPS"); then
    COMMIT_TYPE="perf"
  elif grep -q "style\|format" <(echo "$SESSION_OPS"); then
    COMMIT_TYPE="style"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 3: DETERMINE SCOPE
# ═══════════════════════════════════════════════════════════════════════════

SCOPE=""

# Infer scope from primary file
if [ -n "$PRIMARY_FILE" ]; then
  case "$PRIMARY_FILE" in
    cam_core.py|*cam*.py)
      SCOPE="cam"
      ;;
    *hook*|session*.sh|prompt*.sh|*compact*.sh)
      SCOPE="hooks"
      ;;
    cam.sh|commands.md|COMMANDS.md)
      SCOPE="cli"
      ;;
    *model*.md|*.sql)
      SCOPE="data-model"
      ;;
    *query*|*dsl*)
      SCOPE="query-dsl"
      ;;
    *cmr*|*compress*)
      SCOPE="cmr"
      ;;
    *.md|README*)
      SCOPE="docs"
      ;;
    *)
      SCOPE=""
      ;;
  esac
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 4: EXTRACT DESCRIPTION FROM SESSION
# ═══════════════════════════════════════════════════════════════════════════

# Try to get primary decision from CAM
PRIMARY_DECISION=$(./.claude/cam/cam.sh recent-decisions 1 2>/dev/null | \
  jq -r '.[0].title // ""' 2>/dev/null || echo "")

# Fallback: use primary file name
if [ -z "$PRIMARY_DECISION" ]; then
  PRIMARY_FILE_SHORT=$(basename "$PRIMARY_FILE" 2>/dev/null || echo "project")
  PRIMARY_DECISION="update $PRIMARY_FILE_SHORT"
fi

# Format description (imperative, lowercase, no period, max 50 chars)
DESCRIPTION=$(echo "$PRIMARY_DECISION" | \
  sed 's/^./\L&/' | \
  sed 's/\.$//' | \
  cut -c1-50)

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 5: BUILD COMMIT MESSAGE
# ═══════════════════════════════════════════════════════════════════════════

# Subject line
if [ -n "$SCOPE" ]; then
  COMMIT_SUBJECT="${COMMIT_TYPE}(${SCOPE}): ${DESCRIPTION}"
else
  COMMIT_SUBJECT="${COMMIT_TYPE}: ${DESCRIPTION}"
fi

# Body: session statistics and decisions
COMMIT_BODY=$(cat <<EOF
Session Statistics:
• Operations: $(($EDIT_COUNT + $WRITE_COUNT + $BASH_COUNT + $READ_COUNT))
  - Edits: $EDIT_COUNT
  - Writes: $WRITE_COUNT
  - Bash: $BASH_COUNT
  - Reads: $READ_COUNT
• Files Modified: $GIT_STATUS
EOF
)

# Add decision rationale if available
if [ -n "$PRIMARY_DECISION" ]; then
  COMMIT_BODY=$(cat <<EOF
$COMMIT_BODY

Decision Context:
• Primary Decision: $PRIMARY_DECISION
EOF
)
fi

# Footers (removed Co-Authored-By per user preference)
SESSION_DATE=$(date -u +%Y-%m-%d)
COMMIT_FOOTERS=$(cat <<EOF

Session-ID: ${SESSION_ID:0:16}
Session-Date: $SESSION_DATE
EOF
)

# Full commit message
FULL_COMMIT_MSG="${COMMIT_SUBJECT}

${COMMIT_BODY}
${COMMIT_FOOTERS}"

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 6: VALIDATE COMMIT MESSAGE
# ═══════════════════════════════════════════════════════════════════════════

# Check subject line length
SUBJECT_LEN=${#COMMIT_SUBJECT}
if [ "$SUBJECT_LEN" -gt 72 ]; then
  # Truncate if too long
  COMMIT_SUBJECT="${COMMIT_TYPE}(${SCOPE}): ${DESCRIPTION:0:$((50 - ${#SCOPE} - 3))}"
fi

# Validate conventional commit format
if ! echo "$COMMIT_SUBJECT" | grep -qE '^(feat|fix|docs|test|refactor|perf|chore|style|ci)(\([a-z\-]+\))?: '; then
  # Fallback to generic if format invalid
  COMMIT_SUBJECT="chore: session work"
fi

# Rebuild if truncated
if [ "$SUBJECT_LEN" -gt 72 ]; then
  FULL_COMMIT_MSG="${COMMIT_SUBJECT}

${COMMIT_BODY}
${COMMIT_FOOTERS}"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 7: CREATE PR FOR REVIEW (if changes exist)
# ═══════════════════════════════════════════════════════════════════════════

PR_URL=""
PR_CREATED=false

if [ -n "$(git status --short 2>/dev/null)" ]; then
  # Check if gh CLI is available
  if ! command -v gh &> /dev/null; then
    echo "Warning: gh CLI not found. Staging changes only (no PR created)." >&2
    git add -A 2>/dev/null || true
  else
    # Get current branch (will be PR base)
    ORIGINAL_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

    # Create session-specific branch name
    SESSION_BRANCH="session/${SESSION_ID:0:8}-$(date +%Y%m%d-%H%M%S)"

    # Stash current changes
    git stash push -m "Session ${SESSION_ID:0:8} changes" 2>/dev/null || true

    # Create and switch to session branch
    git checkout -b "$SESSION_BRANCH" 2>/dev/null || {
      # If branch creation fails, try to recover
      git stash pop 2>/dev/null || true
      echo "Warning: Could not create session branch. Changes staged but no PR created." >&2
      git add -A 2>/dev/null || true
    }

    # If we're on the session branch, proceed with PR workflow
    if [ "$(git branch --show-current)" = "$SESSION_BRANCH" ]; then
      # Pop stashed changes
      git stash pop 2>/dev/null || true

      # Stage all changes
      git add -A 2>/dev/null || true

      # Create commit with conventional message
      git commit -m "$FULL_COMMIT_MSG" 2>/dev/null || {
        git commit -m "chore: session work" 2>/dev/null || true
      }

      # Push branch to origin
      git push -u origin "$SESSION_BRANCH" 2>/dev/null || {
        echo "Warning: Could not push to origin. Commit created locally." >&2
      }

      # Create PR using gh CLI
      PR_BODY=$(cat <<PREOF
## Session Summary

$COMMIT_BODY

---

**Review Checklist:**
- [ ] Code changes reviewed
- [ ] Tests pass (if applicable)
- [ ] Documentation updated (if needed)

PREOF
)

      PR_OUTPUT=$(gh pr create \
        --title "$COMMIT_SUBJECT" \
        --body "$PR_BODY" \
        --base "$ORIGINAL_BRANCH" \
        --head "$SESSION_BRANCH" 2>&1) && {
        PR_URL="$PR_OUTPUT"
        PR_CREATED=true
      } || {
        echo "Warning: PR creation failed. Branch pushed but no PR created." >&2
        echo "You can create it manually: gh pr create --base $ORIGINAL_BRANCH" >&2
      }

      # Return to original branch
      git checkout "$ORIGINAL_BRANCH" 2>/dev/null || true
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 8: BUILD KNOWLEDGE GRAPH
# ═══════════════════════════════════════════════════════════════════════════

./.claude/cam/cam.sh graph build --session "$SESSION_ID" >/dev/null 2>&1 || true

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 9: STORE SESSION SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

SESSION_SUMMARY=$(cat <<EOF
Session Summary - ${SESSION_ID:0:8}}
Created: $SESSION_DATE
Type: $COMMIT_TYPE
Scope: ${SCOPE:-general}
Operations: $(($EDIT_COUNT + $WRITE_COUNT + $BASH_COUNT + $READ_COUNT))
Files: $GIT_STATUS
Commit: $COMMIT_SUBJECT
EOF
)

# Store to CAM (optional - for cross-session memory)
./.claude/cam/cam.sh note "Session $(date +%Y-%m-%d_%H:%M)" "$SESSION_SUMMARY" \
  "session,$(date +%Y-%m-%d),${COMMIT_TYPE},${SCOPE}" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 10: CLEANUP
# ═══════════════════════════════════════════════════════════════════════════

# Remove session state
rm -f "$SESSION_STATE_FILE" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# PHASE 11: RETURN STATUS
# ═══════════════════════════════════════════════════════════════════════════

jq -n \
  --arg subject "$COMMIT_SUBJECT" \
  --arg type "$COMMIT_TYPE" \
  --arg scope "$SCOPE" \
  --arg pr_url "$PR_URL" \
  --argjson pr_created "$PR_CREATED" \
  '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "SessionEnd",
      additionalContext: (if $pr_created then "PR Created: \($pr_url)" else "Session: \($type)(\($scope)) - changes staged" end)
    }
  }' 2>/dev/null || echo '{"continue": true}'

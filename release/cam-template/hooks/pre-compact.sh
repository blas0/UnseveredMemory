#!/bin/bash
# Global PreCompact Hook: HOLD cognitive function
# Version: 2.1.0
#
# This hook delegates to the unified CAM Cognitive system.
# Cognitive Function: HOLD - Preserve critical context before compaction

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read input and add hook event marker
INPUT=$(cat)
INPUT_WITH_EVENT=$(echo "$INPUT" | jq '. + {hook_event: "PreCompact"}')

# Delegate to cognitive system
if [[ -x "$SCRIPT_DIR/cam-cognitive.sh" ]]; then
    echo "$INPUT_WITH_EVENT" | "$SCRIPT_DIR/cam-cognitive.sh" dispatch
elif [[ -x "$HOME/.claude/hooks/cam-cognitive.sh" ]]; then
    echo "$INPUT_WITH_EVENT" | "$HOME/.claude/hooks/cam-cognitive.sh" dispatch
else
    # Fallback: continue
    jq -n '{
        continue: true,
        hookSpecificOutput: {
            hookEventName: "PreCompact"
        }
    }'
fi

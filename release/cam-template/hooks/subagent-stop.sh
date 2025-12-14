#!/bin/bash
# Global SubagentStop Hook: INTEGRATE cognitive function
# Version: 2.1.0
#
# This hook delegates to the unified CAM Cognitive system.
# Cognitive Function: INTEGRATE - Consolidate subagent results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read input and add hook event marker
INPUT=$(cat)
INPUT_WITH_EVENT=$(echo "$INPUT" | jq '. + {hook_event: "SubagentStop"}')

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
            hookEventName: "SubagentStop"
        }
    }'
fi

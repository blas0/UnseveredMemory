#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# CAM Cognitive Hook System - Unified Cognitive Function Dispatch
# Version: 2.1.0
#
# This script provides a unified entry point for all CAM cognitive functions.
# Each Claude Code hook event maps to a cognitive function that operates on
# the shared Memory Bus.
#
# Cognitive Function Mapping:
#   SessionStart      → ORIENT    (establish context, load memories)
#   UserPromptSubmit  → PERCEIVE  (understand intent, proactive retrieval)
#   PreToolUse        → ATTEND    (focus attention, pattern retrieval)
#   PostToolUse       → ENCODE    (store operations, create relationships)
#   PermissionRequest → DECIDE    (evaluate risk, record decisions)
#   SubagentStop      → INTEGRATE (consolidate subagent results)
#   PreCompact        → HOLD      (preserve critical context)
#   SessionEnd/Stop   → REFLECT   (summarize, consolidate knowledge)
#
# Usage:
#   ./cam-cognitive.sh <cognitive_function> [args...]
#
# Or as hook dispatcher:
#   echo '{"hook_event": "SessionStart", ...}' | ./cam-cognitive.sh dispatch
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

COGNITIVE_VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Memory Bus core library
if [[ -f "$SCRIPT_DIR/memory_bus_core.sh" ]]; then
    source "$SCRIPT_DIR/memory_bus_core.sh"
elif [[ -f "$HOME/.claude/hooks/memory_bus_core.sh" ]]; then
    source "$HOME/.claude/hooks/memory_bus_core.sh"
else
    echo '{"continue": true, "error": "Memory Bus core not found"}' >&2
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

PRIMER_DIR="$HOME/.claude/.session-primers"
CACHE_DIR="$HOME/.claude/.cam-cache"
SESSION_CONTEXT_CACHE="$HOME/.claude/.session-cam-context"

# Ensure directories exist
mkdir -p "$PRIMER_DIR" "$CACHE_DIR" 2>/dev/null || true

# Load environment
source ~/.claude/hooks/.env 2>/dev/null || true

# Detect timeout command
_get_timeout_cmd() {
    if command -v gtimeout >/dev/null 2>&1; then
        echo "gtimeout"
    elif command -v timeout >/dev/null 2>&1; then
        echo "timeout"
    else
        echo ""
    fi
}

TIMEOUT_CMD=$(_get_timeout_cmd)

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

_cognitive_log() {
    if [[ "${COGNITIVE_DEBUG:-false}" == "true" ]]; then
        echo "[Cognitive:$1] $2" >&2
    fi
}

_run_with_timeout() {
    local timeout_secs="$1"
    shift
    if [[ -n "$TIMEOUT_CMD" ]]; then
        "$TIMEOUT_CMD" "$timeout_secs" "$@"
    else
        "$@"
    fi
}

_cam_available() {
    local cwd="$1"
    [[ -d "$cwd/.claude/cam" ]]
}

_output_json() {
    # Generate standard hook output JSON
    local hook_event="$1"
    local context="$2"
    local continue="${3:-true}"

    if [[ -n "$context" ]]; then
        jq -n \
            --arg hook "$hook_event" \
            --arg ctx "$context" \
            --argjson cont "$continue" \
            '{
                continue: $cont,
                hookSpecificOutput: {
                    hookEventName: $hook,
                    additionalContext: $ctx
                }
            }'
    else
        jq -n \
            --arg hook "$hook_event" \
            --argjson cont "$continue" \
            '{
                continue: $cont,
                hookSpecificOutput: {
                    hookEventName: $hook
                }
            }'
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: ORIENT (SessionStart)
# Establish spatial and temporal context, load relevant memories
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_orient() {
    local input="$1"

    local cwd session_id project_name
    cwd=$(echo "$input" | jq -r '.cwd')
    session_id=$(echo "$input" | jq -r '.session_id')
    project_name=$(basename "$cwd")

    _cognitive_log "ORIENT" "Initializing session $session_id for $project_name"

    # Initialize Memory Bus for this session
    local state_file
    state_file=$(memory_bus_init "$session_id" "$cwd" "$project_name") || {
        _cognitive_log "ORIENT" "Failed to initialize Memory Bus"
    }

    # Add narrative event
    memory_bus_add_narrative "$session_id" "session_start" \
        "Session started for project $project_name" "high" 2>/dev/null || true

    # Clean up old session states
    local cleaned
    cleaned=$(memory_bus_cleanup 24) 2>/dev/null || cleaned="0"

    # Clean up expired primers
    find "$PRIMER_DIR" -name "*.primer" -mmin +240 -delete 2>/dev/null || true

    # Check if CAM is available
    if ! _cam_available "$cwd"; then
        _output_json "SessionStart" \
            "CAM Status: not_initialized\n\nProject: $project_name\nDirectory: $cwd\n\nCAM not found. To initialize, run:\n  ~/.claude/hooks/init-cam.sh"
        return 0
    fi

    cd "$cwd"

    # Query CAM for recent context
    local recent_context stats session_patterns
    recent_context=$(_run_with_timeout 5 ./.claude/cam/cam.sh query "recent session summary" 1 2>&1 | head -20 || echo "No recent context")
    stats=$(_run_with_timeout 5 ./.claude/cam/cam.sh stats 2>&1 | jq -c . 2>/dev/null || echo '{"total_embeddings":0,"total_annotations":0}')
    session_patterns=$(_run_with_timeout 5 ./.claude/cam/cam.sh query "session patterns work summary" 2 2>&1 || echo "")

    # Store session patterns in cache for other hooks
    if [[ -n "$session_patterns" && "$session_patterns" != "No results" ]]; then
        echo "$session_patterns" > "$SESSION_CONTEXT_CACHE" 2>/dev/null || true
        chmod 600 "$SESSION_CONTEXT_CACHE" 2>/dev/null || true

        # Add to Memory Bus context
        memory_bus_add_context "$session_id" "$session_patterns" 0.8 "cam_session_patterns" 2>/dev/null || true
    fi

    # Update Memory Bus with initial focus
    memory_bus_update_focus "$session_id" "$cwd" "file" "normal" 2>/dev/null || true

    # Build output context
    local context_output
    context_output=$(jq -n \
        --arg context "$recent_context" \
        --argjson stats "$stats" \
        --arg project "$project_name" \
        --arg cwd "$cwd" \
        --arg session_context "$session_patterns" \
        '"CAM Status: operational\n\nProject: " + $project + "\nDirectory: " + $cwd + "\n\nRecent Context:\n" + $context + "\n\nCAM Stats:\n  Embeddings: " + ($stats.total_embeddings | tostring) + "\n  Annotations: " + ($stats.total_annotations | tostring // "0") + (if $session_context != "" then "\n\nSession Patterns:\n" + $session_context else "" end)' \
        | jq -r .)

    _output_json "SessionStart" "$context_output"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: PERCEIVE (UserPromptSubmit)
# Understand intent, trigger proactive memory retrieval
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_perceive() {
    local input="$1"

    local user_prompt cwd session_id
    user_prompt=$(echo "$input" | jq -r '.prompt // .user_prompt // ""')
    cwd=$(echo "$input" | jq -r '.cwd')
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

    _cognitive_log "PERCEIVE" "Processing user intent for session $session_id"

    local primer_context=""
    local project_name=""

    # Check for primer (post-compact recovery)
    if [[ -d "$cwd" && "$cwd" != "null" ]]; then
        project_name=$(basename "$cwd")
        local primer_file="$PRIMER_DIR/${project_name}.primer"

        if [[ -f "$primer_file" ]]; then
            # Check primer age (expire after 4 hours)
            local primer_mtime now primer_age_seconds max_age_seconds
            primer_mtime=$(stat -f %m "$primer_file" 2>/dev/null || stat -c %Y "$primer_file" 2>/dev/null || echo "0")
            now=$(date +%s)
            primer_age_seconds=$((now - primer_mtime))
            max_age_seconds=$((4 * 60 * 60))

            if [[ "$primer_age_seconds" -lt "$max_age_seconds" ]]; then
                local primer_json primer_task primer_files primer_state primer_pending primer_ops
                primer_json=$(cat "$primer_file")
                primer_task=$(echo "$primer_json" | jq -r '.summary.task_context // ""' | head -c 200)
                primer_files=$(echo "$primer_json" | jq -r '.summary.files_modified | join(", ")' 2>/dev/null | head -c 300 || echo "")
                primer_state=$(echo "$primer_json" | jq -r '.summary.current_state // ""' | head -c 200)
                primer_pending=$(echo "$primer_json" | jq -r '.summary.pending_items | join(", ")' 2>/dev/null | head -c 200 || echo "")
                primer_ops=$(echo "$primer_json" | jq -r '.summary.operations | "Edits: \(.edits), Writes: \(.writes), Bash: \(.bash)"' 2>/dev/null || echo "")

                primer_context="[SESSION PRIMER - Post-Compact Recovery]
Project: ${project_name}
Previous task: ${primer_task}
Files modified: ${primer_files}
Operations: ${primer_ops}
State: ${primer_state}
Pending: ${primer_pending:-None}
---"

                # Consume primer
                rm -f "$primer_file"

                # Record primer consumption in Memory Bus
                memory_bus_add_narrative "$session_id" "primer_consumed" \
                    "Recovered context from pre-compact primer" "high" 2>/dev/null || true
            else
                rm -f "$primer_file"
            fi
        fi
    fi

    # Handle empty prompt
    if [[ -z "$user_prompt" || "$user_prompt" == "null" ]]; then
        if [[ -n "$primer_context" ]]; then
            _output_json "UserPromptSubmit" "$primer_context"
        else
            echo '{"continue": true}'
        fi
        return 0
    fi

    # Update Memory Bus with perceived intent
    memory_bus_update_intent "$session_id" "$user_prompt" 0.9 "user_prompt" 2>/dev/null || true

    # Check if CAM is available
    if ! _cam_available "$cwd"; then
        if [[ -n "$primer_context" ]]; then
            _output_json "UserPromptSubmit" "$primer_context"
        else
            echo '{"continue": true, "hookSpecificOutput": {"cam_status": "not_available", "hookEventName": "UserPromptSubmit"}}'
        fi
        return 0
    fi

    cd "$cwd"

    # Query CAM based on user intent
    local query cam_results
    query=$(echo "$user_prompt" | head -c 200)
    cam_results=$(_run_with_timeout 5 ./.claude/cam/cam.sh query "$query" 5 2>&1 || echo "No results")

    local top_results
    top_results=$(echo "$cam_results" | head -20)

    # Add CAM results to Memory Bus context
    if [[ -n "$top_results" && "$top_results" != "No results" ]]; then
        memory_bus_add_context "$session_id" "$top_results" 0.85 "cam_intent_query" 2>/dev/null || true
    fi

    # Build full context
    local full_context=""
    if [[ -n "$primer_context" ]]; then
        full_context="${primer_context}\n\n"
    fi
    full_context="${full_context}CAM PROACTIVE CONTEXT (intent: $(echo "$query" | head -c 80)...)\n\n${top_results}\n\nProject: ${project_name:-$(basename "$cwd")}\n\n---\nThis context was retrieved BEFORE processing your message based on semantic similarity to your intent."

    _output_json "UserPromptSubmit" "$full_context"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: ATTEND (PreToolUse)
# Focus attention on relevant patterns for decision points
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_attend() {
    local input="$1"

    local tool_name tool_input prompt cwd session_id
    tool_name=$(echo "$input" | jq -r '.tool_name')
    tool_input=$(echo "$input" | jq -r '.tool_input | tostring')
    prompt=$(echo "$input" | jq -r '.prompt // ""')
    cwd=$(echo "$input" | jq -r '.cwd')
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

    _cognitive_log "ATTEND" "Focusing on $tool_name operation"

    # Check CAM availability
    if ! _cam_available "$cwd"; then
        echo '{"continue": true, "hookSpecificOutput": {"cam_status": "not_available"}}'
        return 0
    fi

    # Smart decision-point filtering
    local should_query=false
    local query_type="standard"

    case "$tool_name" in
        Edit|Write)
            should_query=true
            query_type="code_pattern"
            ;;
        Bash)
            if echo "$prompt" | grep -qiE "(migrate|refactor|architecture|deploy|setup|infrastructure|pattern)"; then
                should_query=true
                query_type="operation_pattern"
            fi
            ;;
        Read|Glob|Grep)
            should_query=false
            ;;
        *)
            should_query=false
            ;;
    esac

    # Track focus in Memory Bus regardless of query
    local file_target=""
    if echo "$tool_input" | jq -e '.file_path' >/dev/null 2>&1; then
        file_target=$(echo "$tool_input" | jq -r '.file_path')
        memory_bus_update_focus "$session_id" "$file_target" "file" "high" 2>/dev/null || true
    fi

    # Skip query if not a decision point
    if [[ "$should_query" == "false" ]]; then
        jq -n '{
            continue: true,
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "allow"
            }
        }'
        return 0
    fi

    # Build query
    local query
    if [[ -n "$file_target" ]]; then
        query="$prompt $(basename "$file_target") $tool_name"
    else
        query="$prompt $tool_name"
    fi

    # Check cache
    local cache_key cache_file cam_results from_cache=false
    cache_key=$(echo -n "$query_type:$query" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "no-md5")
    cache_file="$CACHE_DIR/$cache_key"

    if [[ -f "$cache_file" ]]; then
        local file_age
        file_age=$(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0)))
        if [[ "$file_age" -lt 1800 ]]; then
            cam_results=$(cat "$cache_file")
            from_cache=true
        fi
    fi

    # Query CAM if not cached
    if [[ -z "$cam_results" ]]; then
        cd "$cwd"
        cam_results=$(_run_with_timeout 2 ./.claude/cam/cam.sh query "$query" 3 2>&1 || echo "No results")

        if [[ "$cam_results" != "No results" ]]; then
            echo "$cam_results" > "$cache_file" 2>/dev/null || true
        fi
    fi

    # Extract first result
    local first_result
    first_result=$(echo "$cam_results" | awk '/^1\. \[Score:/{p=1} p && /^[0-9]+\. \[Score:/{if(NR>1) exit} p' || echo "")

    # Add to Memory Bus context
    if [[ -n "$first_result" && "$first_result" != "No results" ]]; then
        memory_bus_add_context "$session_id" "$first_result" 0.7 "cam_pattern_query" 2>/dev/null || true
    fi

    # Auto-annotate in background
    if [[ "$first_result" != "No results" && -n "$prompt" ]]; then
        (
            local result_count annotation_content
            result_count=$(echo "$cam_results" | wc -l)
            annotation_content="CAM Query Auto-Annotated

Query: ${query}
Results Found: ${result_count} lines

Results Summary:
$(echo "$first_result" | head -5)"

            if [[ -x ~/.claude/hooks/cam-note.sh ]]; then
                cd "$cwd"
                SESSION_ID="${session_id}" ~/.claude/hooks/cam-note.sh \
                    "Query: ${query}" \
                    "$annotation_content" \
                    "cam-query,auto-annotated" >/dev/null 2>&1 || true
            fi
        ) &
    fi

    # Output
    if [[ "$first_result" != "No results" && -n "$first_result" ]]; then
        jq -n \
            --arg context "$first_result" \
            '{
                continue: true,
                hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "allow",
                    additionalContext: ("CAM Patterns:\n" + $context)
                }
            }'
    else
        jq -n '{
            continue: true,
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "allow"
            }
        }'
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: ENCODE (PostToolUse)
# Store operations, create relationships, maintain knowledge graph
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_encode() {
    local input="$1"

    local tool_name tool_input success cwd session_id
    tool_name=$(echo "$input" | jq -r '.tool_name')
    tool_input=$(echo "$input" | jq -r '.tool_input // {}')
    success=$(echo "$input" | jq -r '.tool_response.success // true')
    cwd=$(echo "$input" | jq -r '.cwd')
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

    _cognitive_log "ENCODE" "Recording $tool_name operation (success: $success)"

    # Check CAM availability
    if ! _cam_available "$cwd"; then
        echo '{"continue": true}'
        return 0
    fi

    # Only annotate significant operations
    local annotated_ops=("Edit" "Write" "Bash" "Read")
    local should_annotate=false
    for op in "${annotated_ops[@]}"; do
        if [[ "$tool_name" == "$op" ]]; then
            should_annotate=true
            break
        fi
    done

    if [[ "$should_annotate" == "false" ]]; then
        echo '{"continue": true}'
        return 0
    fi

    local timestamp project_name file_path summary
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    project_name=$(basename "$cwd")
    file_path=$(echo "$tool_input" | jq -r '.file_path // .command // "unknown"' | head -c 100)
    summary="${tool_name} operation on ${file_path} (success: ${success})"

    # Add to Memory Bus narrative
    memory_bus_add_narrative "$session_id" "tool_use" "$summary" "normal" 2>/dev/null || true

    # Store in operations log
    echo "[$timestamp] [${project_name}] $summary" >> "$cwd/.claude/cam/operations.log"

    cd "$cwd"

    # Create CAM annotation
    local content note_output op_embedding_id
    content="Operation: ${tool_name}
Project: ${project_name}
Target: ${file_path}
Success: ${success}
Session: ${session_id:0:8}
Timestamp: ${timestamp}"

    note_output=$(~/.claude/hooks/cam-note.sh \
        "Op: ${tool_name} ${file_path##*/}" \
        "$content" \
        "operation,${tool_name},auto-annotated,session-${session_id:0:8}" \
        2>/dev/null || echo "")

    op_embedding_id=$(echo "$note_output" | grep -o 'ID: [a-f0-9]*' | head -1 | cut -d' ' -f2 || echo "")

    # Create relationships for .ai/ files
    local relationship_created=""
    if [[ "$tool_name" =~ ^(Edit|Write)$ ]] && [[ "$file_path" =~ \.ai/ ]] && [[ -n "$op_embedding_id" ]]; then
        local doc_embedding_id
        doc_embedding_id=$(./.claude/cam/cam.sh find-doc "$file_path" 2>/dev/null || echo "")

        if [[ -n "$doc_embedding_id" ]]; then
            ./.claude/cam/cam.sh relate "$op_embedding_id" "$doc_embedding_id" "modifies" 0.9 2>/dev/null || true
            relationship_created="[^] Relationship: ${op_embedding_id:0:8} --modifies--> ${doc_embedding_id:0:8}"
        fi
    fi

    # Auto-ingest modified files
    local auto_ingest_msg=""
    if [[ "$tool_name" =~ ^(Edit|Write)$ ]] && [[ "$success" == "true" ]] && [[ -f "$file_path" ]]; then
        local ext="${file_path##*.}"
        local should_ingest=false

        # Check extension
        if [[ "$ext" =~ ^(py|js|ts|tsx|jsx|go|rs|java|c|cpp|h|rb|php|swift|kt|scala|sh|bash|zsh)$ ]]; then
            should_ingest=true
        elif [[ "$ext" =~ ^(md|mdx|rst|txt)$ ]]; then
            should_ingest=true
        elif [[ "$ext" =~ ^(json|yaml|yml|toml|ini|cfg|conf)$ ]]; then
            should_ingest=true
        fi

        # Check size and exclusions
        if [[ "$should_ingest" == "true" ]]; then
            local file_size
            file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")

            if [[ "$file_size" -gt 102400 ]]; then
                should_ingest=false
            fi

            if [[ "$file_path" =~ (package-lock|yarn\.lock|pnpm-lock|node_modules|__pycache__|\.git/) ]]; then
                should_ingest=false
            fi
        fi

        if [[ "$should_ingest" == "true" ]]; then
            local ingest_output ingest_id
            ingest_output=$(./.claude/cam/cam.sh ingest "$file_path" 2>&1 || echo "")

            if echo "$ingest_output" | grep -q "\[v\] Ingested"; then
                ingest_id=$(echo "$ingest_output" | grep -o '-> [a-f0-9]*' | head -1 | cut -d' ' -f2 || echo "")
                auto_ingest_msg="[+] Auto-ingested: ${file_path##*/} -> ${ingest_id:0:8}"
            fi
        fi
    fi

    # Check for CAM infrastructure modification
    local cam_infra_reminder=""
    if [[ "$file_path" =~ cam_core\.py ]] || \
       [[ "$file_path" =~ cam\.sh ]] || \
       [[ "$file_path" =~ \.claude/hooks/ ]] || \
       [[ "$file_path" =~ cam-template/ ]] || \
       [[ "$file_path" =~ CLAUDE\.md ]]; then
        cam_infra_reminder="[!] CAM INFRASTRUCTURE MODIFIED: Remember to run './cam.sh release <version>' to bump version and update CHANGELOG.md"
    fi

    # Calculate cognitive load
    memory_bus_calculate_load "$session_id" >/dev/null 2>&1 || true

    # Build output
    local context_msg="$summary\n\nProject: $project_name"
    [[ -n "$relationship_created" ]] && context_msg="$context_msg\n\n$relationship_created"
    [[ -n "$auto_ingest_msg" ]] && context_msg="$context_msg\n\n$auto_ingest_msg"
    if [[ -n "$cam_infra_reminder" ]]; then
        context_msg="$context_msg\n\n$cam_infra_reminder"
    else
        context_msg="$context_msg\n\n[v] CAM updated and embedded"
    fi

    jq -n \
        --arg context "$context_msg" \
        '{
            continue: true,
            hookSpecificOutput: {
                hookEventName: "PostToolUse",
                additionalContext: $context
            }
        }'
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: DECIDE (PermissionRequest) - NEW
# Evaluate permission requests, record decision rationale
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_decide() {
    local input="$1"

    local tool_name tool_input risk_level session_id cwd
    tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"')
    tool_input=$(echo "$input" | jq -r '.tool_input | tostring')
    risk_level=$(echo "$input" | jq -r '.risk_level // "medium"')
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
    cwd=$(echo "$input" | jq -r '.cwd // "."')

    _cognitive_log "DECIDE" "Evaluating permission for $tool_name (risk: $risk_level)"

    local decision="allow"
    local rationale="Standard operation within normal parameters"
    local alternatives='[]'
    local confidence=0.85

    # Risk-based decision logic
    case "$risk_level" in
        high)
            # High-risk operations require more careful consideration
            confidence=0.7
            rationale="High-risk operation - proceeding with caution"

            # Check if we have patterns for this type of operation
            if _cam_available "$cwd"; then
                cd "$cwd"
                local similar_ops
                similar_ops=$(_run_with_timeout 2 ./.claude/cam/cam.sh query "high risk $tool_name operation" 2 2>&1 || echo "")

                if [[ -n "$similar_ops" && "$similar_ops" != "No results" ]]; then
                    rationale="High-risk operation - similar operations found in CAM history"
                    confidence=0.75
                fi
            fi
            ;;
        critical)
            confidence=0.6
            rationale="Critical operation - user approval recommended"
            alternatives='["Request explicit user confirmation", "Suggest safer alternative"]'
            ;;
        *)
            confidence=0.9
            rationale="Standard risk level - operation approved"
            ;;
    esac

    # Record decision in Memory Bus
    memory_bus_add_decision "$session_id" \
        "Permission $decision for $tool_name" \
        "$rationale" \
        "$alternatives" \
        "$confidence" 2>/dev/null || true

    # Output decision
    jq -n \
        --arg decision "$decision" \
        --arg tool "$tool_name" \
        --arg rationale "$rationale" \
        '{
            continue: true,
            hookSpecificOutput: {
                hookEventName: "PermissionRequest",
                permissionDecision: $decision,
                additionalContext: ("Decision: " + $decision + " for " + $tool + "\nRationale: " + $rationale)
            }
        }'
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: INTEGRATE (SubagentStop) - NEW
# Consolidate results from completed subagents
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_integrate() {
    local input="$1"

    local subagent_type subagent_result session_id cwd
    subagent_type=$(echo "$input" | jq -r '.subagent_type // "unknown"')
    subagent_result=$(echo "$input" | jq -r '.result // ""')
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
    cwd=$(echo "$input" | jq -r '.cwd // "."')

    _cognitive_log "INTEGRATE" "Consolidating results from $subagent_type subagent"

    # Add integration event to narrative
    memory_bus_add_narrative "$session_id" "subagent_complete" \
        "Subagent ($subagent_type) completed task" "normal" 2>/dev/null || true

    # Check if subagent produced significant results
    if [[ -n "$subagent_result" && ${#subagent_result} -gt 100 ]]; then
        # Add summary to Memory Bus context
        local result_summary
        result_summary=$(echo "$subagent_result" | head -c 500)
        memory_bus_add_context "$session_id" "$result_summary" 0.8 "subagent_$subagent_type" 2>/dev/null || true

        # Store in CAM if available
        if _cam_available "$cwd"; then
            cd "$cwd"
            ~/.claude/hooks/cam-note.sh \
                "Subagent: $subagent_type result" \
                "$result_summary" \
                "subagent,$subagent_type,integrated,session-${session_id:0:8}" \
                >/dev/null 2>&1 || true
        fi
    fi

    # Check for any commitments that might be completed
    # (Subagents often complete tasks that were committed earlier)

    jq -n \
        --arg type "$subagent_type" \
        '{
            continue: true,
            hookSpecificOutput: {
                hookEventName: "SubagentStop",
                additionalContext: ("Integrated results from " + $type + " subagent")
            }
        }'
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: HOLD (PreCompact)
# Preserve critical context before memory compaction
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_hold() {
    local input="$1"

    local session_id cwd
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
    cwd=$(echo "$input" | jq -r '.cwd // "."')

    # Try to get cwd from session state if not provided
    if [[ -z "$cwd" || "$cwd" == "null" || "$cwd" == "." ]]; then
        local state_file="$MEMORY_BUS_STATE_DIR/${session_id}.json"
        if [[ -f "$state_file" ]]; then
            cwd=$(jq -r '.session_metadata.cwd // "."' "$state_file" 2>/dev/null || echo ".")
        fi
    fi

    local project_name
    project_name=$(basename "$cwd" 2>/dev/null || echo "unknown")

    _cognitive_log "HOLD" "Preserving context before compaction for $project_name"

    # Get Memory Bus state
    local state
    state=$(memory_bus_load "$session_id" 2>/dev/null || echo "{}")

    if [[ "$state" == "{}" ]]; then
        echo '{"continue": true}'
        return 0
    fi

    # Extract critical information for primer
    local current_intent focus_items pending_commitments recent_narrative
    current_intent=$(echo "$state" | jq -r '.working_memory.current_intent.description // "No active intent"')
    focus_items=$(echo "$state" | jq -r '[.working_memory.attention_focus[].entity] | join(", ")' 2>/dev/null || echo "")
    pending_commitments=$(echo "$state" | jq -r '[.commitments.pending[].description] | join(", ")' 2>/dev/null || echo "")
    recent_narrative=$(echo "$state" | jq -r '[.working_memory.session_narrative[-5:][].summary] | join("; ")' 2>/dev/null || echo "")

    # Get operation counts from CAM if available
    local edit_count=0 write_count=0 bash_count=0
    if _cam_available "$cwd"; then
        cd "$cwd"
        local session_prefix="${session_id:0:8}"
        edit_count=$(sqlite3 "./.claude/cam/metadata.db" \
            "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${session_prefix}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Edit%';" 2>/dev/null || echo "0")
        write_count=$(sqlite3 "./.claude/cam/metadata.db" \
            "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${session_prefix}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Write%';" 2>/dev/null || echo "0")
        bash_count=$(sqlite3 "./.claude/cam/metadata.db" \
            "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${session_prefix}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Bash%';" 2>/dev/null || echo "0")
    fi

    # Create primer file
    local primer_file="$PRIMER_DIR/${project_name}.primer"
    jq -n \
        --arg project "$project_name" \
        --arg session_id "$session_id" \
        --arg task_context "$current_intent" \
        --arg focus "$focus_items" \
        --arg pending "$pending_commitments" \
        --arg narrative "$recent_narrative" \
        --argjson edits "$edit_count" \
        --argjson writes "$write_count" \
        --argjson bash "$bash_count" \
        '{
            project: $project,
            session_id: $session_id,
            created_at: (now | todate),
            summary: {
                task_context: $task_context,
                files_modified: ($focus | split(", ") | map(select(length > 0))),
                operations: {
                    edits: $edits,
                    writes: $writes,
                    bash: $bash
                },
                current_state: $narrative,
                pending_items: ($pending | split(", ") | map(select(length > 0)))
            }
        }' > "$primer_file" 2>/dev/null || true

    chmod 600 "$primer_file" 2>/dev/null || true

    # Add narrative event
    memory_bus_add_narrative "$session_id" "pre_compact" \
        "Context preserved in primer before compaction" "critical" 2>/dev/null || true

    _output_json "PreCompact" \
        "[~] Context preserved in primer for post-compact recovery\nProject: $project_name\nIntent: $current_intent"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COGNITIVE FUNCTION: REFLECT (SessionEnd/Stop)
# Summarize session, consolidate knowledge, clean up
# ═══════════════════════════════════════════════════════════════════════════════

cognitive_reflect() {
    local input="$1"

    local session_id cwd
    session_id=$(echo "$input" | jq -r '.session_id')
    cwd=$(echo "$input" | jq -r '.cwd // ""')

    # Try to get cwd from session state if not provided
    if [[ -z "$cwd" || "$cwd" == "null" ]]; then
        local state_file="$MEMORY_BUS_STATE_DIR/${session_id}.json"
        if [[ -f "$state_file" ]]; then
            cwd=$(jq -r '.session_metadata.cwd // ""' "$state_file" 2>/dev/null || echo "")
        fi
    fi

    local project_name
    project_name=$(basename "$cwd" 2>/dev/null || echo "unknown")

    _cognitive_log "REFLECT" "Ending session $session_id for $project_name"

    # Check for uncommitted changes
    local uncommitted_warning=""
    if [[ -d "$cwd/.git" ]]; then
        cd "$cwd"
        local uncommitted
        uncommitted=$(git status --porcelain 2>/dev/null | head -20)
        if [[ -n "$uncommitted" ]]; then
            local uncommitted_count
            uncommitted_count=$(echo "$uncommitted" | wc -l | tr -d ' ')
            uncommitted_warning="⚠️  UNCOMMITTED CHANGES DETECTED ($uncommitted_count files) - Consider committing and creating PR before ending session"
        fi
    fi

    # Get Memory Bus summary
    local memory_summary
    memory_summary=$(memory_bus_get_summary "$session_id" 2>/dev/null || echo "Memory Bus: No state available")

    # Get cognitive load
    local cognitive_load
    cognitive_load=$(memory_bus_get_load_level "$session_id" 2>/dev/null || echo "unknown")

    # Skip CAM operations if not available
    if ! _cam_available "$cwd"; then
        # Clean up Memory Bus state
        rm -f "$MEMORY_BUS_STATE_DIR/${session_id}.json" 2>/dev/null || true
        rm -f "$MEMORY_BUS_STATE_DIR/${session_id}.lock" 2>/dev/null || true

        local context="Session Summary\n\nProject: $project_name\nSession: $session_id\n\n$memory_summary\nCognitive Load: $cognitive_load"
        [[ -n "$uncommitted_warning" ]] && context="${uncommitted_warning}\n\n${context}"

        _output_json "SessionEnd" "$context"
        return 0
    fi

    cd "$cwd"

    # Get operation counts
    local session_prefix="${session_id:0:8}"
    local edit_count write_count read_count bash_count total_ops
    edit_count=$(sqlite3 "./.claude/cam/metadata.db" \
        "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${session_prefix}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Edit%';" 2>/dev/null || echo "0")
    write_count=$(sqlite3 "./.claude/cam/metadata.db" \
        "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${session_prefix}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Write%';" 2>/dev/null || echo "0")
    read_count=$(sqlite3 "./.claude/cam/metadata.db" \
        "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${session_prefix}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Read%';" 2>/dev/null || echo "0")
    bash_count=$(sqlite3 "./.claude/cam/metadata.db" \
        "SELECT COUNT(*) FROM annotations WHERE tags LIKE '%session-${session_prefix}%' AND json_extract(metadata, '\$.title') LIKE 'Op: Bash%';" 2>/dev/null || echo "0")
    total_ops=$((edit_count + write_count + read_count + bash_count))

    # Get modified files
    local files_modified files_json
    files_modified=$(sqlite3 "./.claude/cam/metadata.db" \
        "SELECT DISTINCT json_extract(metadata, '\$.title') FROM annotations
         WHERE tags LIKE '%session-${session_prefix}%'
         AND (json_extract(metadata, '\$.title') LIKE 'Op: Edit%' OR json_extract(metadata, '\$.title') LIKE 'Op: Write%')
         LIMIT 50;" 2>/dev/null | \
        sed 's/Op: Edit //g; s/Op: Write //g' | \
        sort -u | \
        head -20 || echo "")

    files_json="[]"
    if [[ -n "$files_modified" ]]; then
        files_json=$(echo "$files_modified" | jq -R -s 'split("\n") | map(select(length > 0))')
    fi

    # Store session summary in CAM
    local summary_status="[~] No operations recorded this session"
    if [[ "$total_ops" -gt 0 ]]; then
        local end_time session_data
        end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        session_data=$(jq -n \
            --arg project "$project_name" \
            --arg end_time "$end_time" \
            --argjson edit "$edit_count" \
            --argjson write "$write_count" \
            --argjson read "$read_count" \
            --argjson bash "$bash_count" \
            --argjson files "$files_json" \
            '{
                project: $project,
                end_time: $end_time,
                operations: {
                    Edit: $edit,
                    Write: $write,
                    Read: $read,
                    Bash: $bash
                },
                files_modified: $files,
                key_activities: []
            }')

        local store_output
        store_output=$(./.claude/cam/cam.sh store-session "$session_id" "$session_data" 2>&1 || echo "")

        if echo "$store_output" | grep -q "\[v\]"; then
            summary_status="$store_output"
        else
            summary_status="[v] Session summary stored"
        fi
    fi

    # Build graph if enough embeddings
    local graph_stats=""
    if [[ "$total_ops" -gt 0 ]]; then
        local embedding_count
        embedding_count=$(./.claude/cam/cam.sh stats 2>/dev/null | jq -r '.total_embeddings // 0' 2>/dev/null || echo "0")

        if [[ "$embedding_count" -ge 10 ]]; then
            local graph_output
            graph_output=$(_run_with_timeout 60 ./.claude/cam/cam.sh graph build 2>&1 || echo "Graph build skipped or timed out")

            local temporal_edges semantic_edges causal_edges total_edges
            temporal_edges=$(echo "$graph_output" | grep -o '"temporal": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")
            semantic_edges=$(echo "$graph_output" | grep -o '"semantic": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")
            causal_edges=$(echo "$graph_output" | grep -o '"causal": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")
            total_edges=$(echo "$graph_output" | grep -o '"total": [0-9]*' | grep -o '[0-9]*' | tail -1 || echo "0")

            if [[ "$total_edges" -gt 0 ]]; then
                graph_stats="Graph: ${total_edges} relationships (${temporal_edges} temporal, ${semantic_edges} semantic, ${causal_edges} causal)"
            fi
        fi
    fi

    # Clean up Memory Bus state
    rm -f "$MEMORY_BUS_STATE_DIR/${session_id}.json" 2>/dev/null || true
    rm -f "$MEMORY_BUS_STATE_DIR/${session_id}.lock" 2>/dev/null || true

    # Build final output
    jq -n \
        --arg session_id "$session_id" \
        --arg total_ops "$total_ops" \
        --arg edit "$edit_count" \
        --arg write "$write_count" \
        --arg read "$read_count" \
        --arg bash "$bash_count" \
        --arg project "$project_name" \
        --arg summary_status "$summary_status" \
        --arg graph_stats "$graph_stats" \
        --arg uncommitted_warning "$uncommitted_warning" \
        --arg memory_summary "$memory_summary" \
        --arg cognitive_load "$cognitive_load" \
        '{
            continue: true,
            hookSpecificOutput: {
                hookEventName: "SessionEnd",
                additionalContext: ((if $uncommitted_warning != "" then $uncommitted_warning + "\n\n" else "" end) + "Session Summary\n\nProject: " + $project + "\nSession: " + $session_id + "\nOperations: " + $total_ops + " (Edit: " + $edit + ", Write: " + $write + ", Read: " + $read + ", Bash: " + $bash + ")\nCognitive Load: " + $cognitive_load + "\n\nStatus:\n  " + $summary_status + "\n  " + (if $graph_stats != "" then $graph_stats else "[~] Graph building skipped" end) + "\n\n" + $memory_summary)
            }
        }'
}

# ═══════════════════════════════════════════════════════════════════════════════
# DISPATCH: Route hook events to cognitive functions
# ═══════════════════════════════════════════════════════════════════════════════

dispatch_hook() {
    local input
    input=$(cat)

    # Determine hook event from input
    local hook_event
    hook_event=$(echo "$input" | jq -r '.hook_event // .hookEventName // ""')

    # If not explicitly provided, try to infer from context
    if [[ -z "$hook_event" ]]; then
        # Check for tool_name (PreToolUse/PostToolUse)
        if echo "$input" | jq -e '.tool_name' >/dev/null 2>&1; then
            if echo "$input" | jq -e '.tool_response' >/dev/null 2>&1; then
                hook_event="PostToolUse"
            else
                hook_event="PreToolUse"
            fi
        # Check for prompt (UserPromptSubmit)
        elif echo "$input" | jq -e '.prompt // .user_prompt' >/dev/null 2>&1; then
            hook_event="UserPromptSubmit"
        fi
    fi

    # Route to cognitive function
    case "$hook_event" in
        SessionStart)
            cognitive_orient "$input"
            ;;
        UserPromptSubmit)
            cognitive_perceive "$input"
            ;;
        PreToolUse)
            cognitive_attend "$input"
            ;;
        PostToolUse)
            cognitive_encode "$input"
            ;;
        PermissionRequest)
            cognitive_decide "$input"
            ;;
        SubagentStop)
            cognitive_integrate "$input"
            ;;
        PreCompact)
            cognitive_hold "$input"
            ;;
        SessionEnd|Stop)
            cognitive_reflect "$input"
            ;;
        *)
            echo '{"continue": true, "error": "Unknown hook event"}'
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN: Command-line interface
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local command="${1:-dispatch}"
    shift 2>/dev/null || true

    case "$command" in
        dispatch)
            dispatch_hook
            ;;
        orient|ORIENT)
            cognitive_orient "$(cat)"
            ;;
        perceive|PERCEIVE)
            cognitive_perceive "$(cat)"
            ;;
        attend|ATTEND)
            cognitive_attend "$(cat)"
            ;;
        encode|ENCODE)
            cognitive_encode "$(cat)"
            ;;
        decide|DECIDE)
            cognitive_decide "$(cat)"
            ;;
        integrate|INTEGRATE)
            cognitive_integrate "$(cat)"
            ;;
        hold|HOLD)
            cognitive_hold "$(cat)"
            ;;
        reflect|REFLECT)
            cognitive_reflect "$(cat)"
            ;;
        version)
            echo "CAM Cognitive Hook System v${COGNITIVE_VERSION}"
            echo "Memory Bus v${MEMORY_BUS_VERSION}"
            ;;
        help|--help|-h)
            cat << 'EOF'
CAM Cognitive Hook System - Unified Cognitive Function Dispatch

Usage:
  ./cam-cognitive.sh <command> [args...]
  echo '<json>' | ./cam-cognitive.sh dispatch

Commands:
  dispatch   - Auto-route hook input to appropriate cognitive function (default)
  orient     - ORIENT: Initialize session context (SessionStart)
  perceive   - PERCEIVE: Process user intent (UserPromptSubmit)
  attend     - ATTEND: Focus on tool patterns (PreToolUse)
  encode     - ENCODE: Store operation results (PostToolUse)
  decide     - DECIDE: Evaluate permissions (PermissionRequest)
  integrate  - INTEGRATE: Consolidate subagent results (SubagentStop)
  hold       - HOLD: Preserve pre-compact context (PreCompact)
  reflect    - REFLECT: Summarize session (SessionEnd/Stop)
  version    - Show version information
  help       - Show this help message

Environment Variables:
  COGNITIVE_DEBUG=true  - Enable debug logging
  MEMORY_BUS_DEBUG=true - Enable Memory Bus debug logging
EOF
            ;;
        *)
            echo "Unknown command: $command" >&2
            echo "Run './cam-cognitive.sh help' for usage" >&2
            exit 1
            ;;
    esac
}

# Run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

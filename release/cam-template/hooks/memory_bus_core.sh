#!/bin/bash
# Memory Bus Core - Shared Working Memory for CAM Cognitive Hooks
# Version: 2.1.0
#
# This library provides a unified working memory interface for cognitive functions.
# All hooks source this file to read/write shared session state.
#
# Usage: source ~/.claude/hooks/memory_bus_core.sh

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

MEMORY_BUS_VERSION="2.1.0"
MEMORY_BUS_STATE_DIR="${HOME}/.claude/.session-state"
MEMORY_BUS_SCHEMA_VERSION="2.1.0"

# Ensure state directory exists
mkdir -p "$MEMORY_BUS_STATE_DIR" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

_memory_bus_log() {
    # Silent logging - only in debug mode
    if [[ "${MEMORY_BUS_DEBUG:-false}" == "true" ]]; then
        echo "[MemoryBus] $*" >&2
    fi
}

_memory_bus_now() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_memory_bus_state_file() {
    local session_id="$1"
    echo "${MEMORY_BUS_STATE_DIR}/${session_id}.json"
}

_memory_bus_lock_file() {
    local session_id="$1"
    echo "${MEMORY_BUS_STATE_DIR}/${session_id}.lock"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CORE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

memory_bus_init() {
    # Create new session state file with initial schema
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - cwd (required)
    #   $3 - project_name (optional, derived from cwd if omitted)
    #
    # Returns: 0 on success, 1 on error
    # Output: Path to created state file on stdout

    local session_id="${1:?Session ID required}"
    local cwd="${2:?CWD required}"
    local project="${3:-$(basename "$cwd")}"

    local state_file
    state_file=$(_memory_bus_state_file "$session_id")

    local now
    now=$(_memory_bus_now)

    # Generate initial state
    jq -n \
        --arg schema_version "$MEMORY_BUS_SCHEMA_VERSION" \
        --arg session_id "$session_id" \
        --arg project "$project" \
        --arg cwd "$cwd" \
        --arg now "$now" \
        '{
            schema_version: $schema_version,
            session_metadata: {
                session_id: $session_id,
                project: $project,
                cwd: $cwd,
                start_time: $now,
                last_updated: $now
            },
            working_memory: {
                current_intent: null,
                attention_focus: [],
                active_context: {
                    max_items: 10,
                    items: []
                },
                session_narrative: []
            },
            cognitive_load: {
                total_score: 0.0,
                components: {
                    context_items: 0,
                    focus_entities: 0,
                    pending_commitments: 0,
                    narrative_length: 0
                },
                calculated_at: $now,
                thresholds: {
                    low: 0.3,
                    medium: 0.6,
                    high: 0.8
                }
            },
            decisions: [],
            commitments: {
                pending: [],
                completed: []
            }
        }' > "${state_file}.tmp" 2>/dev/null || {
        _memory_bus_log "Failed to generate initial state"
        return 1
    }

    # Atomic move
    mv "${state_file}.tmp" "$state_file" 2>/dev/null || {
        _memory_bus_log "Failed to move state file"
        rm -f "${state_file}.tmp"
        return 1
    }

    chmod 600 "$state_file" 2>/dev/null || true

    echo "$state_file"
    return 0
}

memory_bus_load() {
    # Load existing session state from file
    #
    # Arguments:
    #   $1 - session_id (required)
    #
    # Returns: 0 on success, 1 if file not found, 2 on parse error
    # Output: JSON state object on stdout

    local session_id="${1:?Session ID required}"
    local state_file
    state_file=$(_memory_bus_state_file "$session_id")

    # Check if file exists
    if [[ ! -f "$state_file" ]]; then
        _memory_bus_log "State file not found: $state_file"
        return 1
    fi

    # Validate JSON and output
    if ! jq . "$state_file" 2>/dev/null; then
        _memory_bus_log "Invalid JSON in state file: $state_file"
        return 2
    fi

    return 0
}

memory_bus_save() {
    # Persist state to file atomically with locking
    #
    # Arguments:
    #   $1 - session_id (required)
    #   stdin - JSON state object
    #
    # Returns: 0 on success, 1 on error

    local session_id="${1:?Session ID required}"
    local state_file
    state_file=$(_memory_bus_state_file "$session_id")
    local lock_file
    lock_file=$(_memory_bus_lock_file "$session_id")

    # Read stdin to variable
    local new_state
    new_state=$(cat) || return 1

    # Validate JSON before writing
    if ! echo "$new_state" | jq . >/dev/null 2>&1; then
        _memory_bus_log "Invalid JSON provided to memory_bus_save"
        return 1
    fi

    # Acquire lock (wait up to 5 seconds)
    local lock_fd
    exec {lock_fd}>"$lock_file" 2>/dev/null || {
        _memory_bus_log "Failed to open lock file"
        return 1
    }

    if ! flock -w 5 "$lock_fd" 2>/dev/null; then
        _memory_bus_log "Failed to acquire lock on $lock_file"
        exec {lock_fd}>&- 2>/dev/null
        return 1
    fi

    # Update last_updated timestamp
    local now
    now=$(_memory_bus_now)
    local updated_state
    updated_state=$(echo "$new_state" | jq \
        --arg now "$now" \
        '.session_metadata.last_updated = $now') || {
        flock -u "$lock_fd" 2>/dev/null
        exec {lock_fd}>&- 2>/dev/null
        return 1
    }

    # Write to temp file
    echo "$updated_state" > "${state_file}.tmp" || {
        flock -u "$lock_fd" 2>/dev/null
        exec {lock_fd}>&- 2>/dev/null
        return 1
    }

    # Atomic move
    mv "${state_file}.tmp" "$state_file" || {
        rm -f "${state_file}.tmp"
        flock -u "$lock_fd" 2>/dev/null
        exec {lock_fd}>&- 2>/dev/null
        return 1
    }

    chmod 600 "$state_file" 2>/dev/null || true

    # Release lock
    flock -u "$lock_fd" 2>/dev/null
    exec {lock_fd}>&- 2>/dev/null

    return 0
}

memory_bus_exists() {
    # Check if Memory Bus state exists for session
    #
    # Arguments:
    #   $1 - session_id (required)
    #
    # Returns: 0 if exists, 1 if not

    local session_id="${1:?Session ID required}"
    local state_file
    state_file=$(_memory_bus_state_file "$session_id")

    [[ -f "$state_file" ]]
}

memory_bus_update_intent() {
    # Update current intent in working memory
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - intent_description (required)
    #   $3 - confidence (optional, default: 0.8)
    #   $4 - source (optional, default: "user_prompt")
    #
    # Returns: 0 on success, non-zero on error

    local session_id="${1:?Session ID required}"
    local description="${2:?Intent description required}"
    local confidence="${3:-0.8}"
    local source="${4:-user_prompt}"

    local now
    now=$(_memory_bus_now)

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Update intent
    local updated_state
    updated_state=$(echo "$state" | jq \
        --arg desc "$description" \
        --argjson conf "$confidence" \
        --arg source "$source" \
        --arg now "$now" \
        '.working_memory.current_intent = {
            description: $desc,
            confidence: $conf,
            set_at: $now,
            source: $source
        }') || return 1

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id"
}

memory_bus_update_focus() {
    # Add entity to attention focus (maintains max 7 items)
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - entity (required) - file path, component, or concept
    #   $3 - type (required) - file|file_pattern|component|concept
    #   $4 - priority (optional, default: "normal") - critical|high|normal|low
    #
    # Returns: 0 on success, non-zero on error

    local session_id="${1:?Session ID required}"
    local entity="${2:?Entity required}"
    local type="${3:?Type required}"
    local priority="${4:-normal}"

    local now
    now=$(_memory_bus_now)

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Add focus item (limit to 7, remove oldest)
    local updated_state
    updated_state=$(echo "$state" | jq \
        --arg entity "$entity" \
        --arg type "$type" \
        --arg priority "$priority" \
        --arg now "$now" \
        '.working_memory.attention_focus += [{
            entity: $entity,
            type: $type,
            priority: $priority,
            added_at: $now
        }] | .working_memory.attention_focus |= .[-7:]') || return 1

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id"
}

memory_bus_add_context() {
    # Add item to active context (auto-prunes to max_items)
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - content (required)
    #   $3 - relevance (optional, default: 0.75)
    #   $4 - source (optional, default: "unknown")
    #
    # Returns: 0 on success, non-zero on error

    local session_id="${1:?Session ID required}"
    local content="${2:?Content required}"
    local relevance="${3:-0.75}"
    local source="${4:-unknown}"

    local now
    now=$(_memory_bus_now)

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Get max_items limit
    local max_items
    max_items=$(echo "$state" | jq -r '.working_memory.active_context.max_items // 10')

    # Validate max_items is numeric
    [[ "$max_items" =~ ^[0-9]+$ ]] || max_items=10

    # Add context item and prune to max_items
    local updated_state
    updated_state=$(echo "$state" | jq \
        --arg content "$content" \
        --argjson relevance "$relevance" \
        --arg source "$source" \
        --arg now "$now" \
        --argjson max_items "$max_items" \
        '.working_memory.active_context.items += [{
            content: $content,
            relevance: $relevance,
            added_at: $now,
            source: $source
        }] | .working_memory.active_context.items |= .[(-$max_items):]') || return 1

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id"
}

memory_bus_add_narrative() {
    # Append event to session narrative
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - event_type (required)
    #   $3 - summary (required)
    #   $4 - importance (optional, default: "normal") - critical|high|normal|low
    #
    # Returns: 0 on success, non-zero on error

    local session_id="${1:?Session ID required}"
    local event_type="${2:?Event type required}"
    local summary="${3:?Summary required}"
    local importance="${4:-normal}"

    local now
    now=$(_memory_bus_now)

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Append narrative event
    local updated_state
    updated_state=$(echo "$state" | jq \
        --arg event "$event_type" \
        --arg summary "$summary" \
        --arg importance "$importance" \
        --arg now "$now" \
        '.working_memory.session_narrative += [{
            timestamp: $now,
            event: $event,
            summary: $summary,
            importance: $importance
        }]') || return 1

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id"
}

memory_bus_add_decision() {
    # Record a decision with rationale and alternatives
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - decision (required)
    #   $3 - rationale (required)
    #   $4 - alternatives (optional) - JSON array string
    #   $5 - confidence (optional, default: 0.8)
    #
    # Returns: 0 on success, non-zero on error

    local session_id="${1:?Session ID required}"
    local decision="${2:?Decision required}"
    local rationale="${3:?Rationale required}"
    local alternatives="${4:-[]}"
    local confidence="${5:-0.8}"

    local now
    now=$(_memory_bus_now)
    local dec_id="dec_$(date +%s)"

    # Validate alternatives is valid JSON array
    if ! echo "$alternatives" | jq -e 'type == "array"' >/dev/null 2>&1; then
        alternatives='[]'
    fi

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Add decision
    local updated_state
    updated_state=$(echo "$state" | jq \
        --arg id "$dec_id" \
        --arg decision "$decision" \
        --arg rationale "$rationale" \
        --argjson alternatives "$alternatives" \
        --argjson confidence "$confidence" \
        --arg now "$now" \
        '.decisions += [{
            id: $id,
            decision: $decision,
            rationale: $rationale,
            alternatives: $alternatives,
            timestamp: $now,
            confidence: $confidence
        }]') || return 1

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id"
}

memory_bus_add_commitment() {
    # Create pending commitment
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - description (required)
    #   $3 - priority (optional, default: "normal") - critical|high|normal|low
    #   $4 - depends_on (optional) - JSON array of commitment IDs
    #
    # Returns: 0 on success, non-zero on error
    # Output: Commitment ID on stdout

    local session_id="${1:?Session ID required}"
    local description="${2:?Description required}"
    local priority="${3:-normal}"
    local depends_on="${4:-[]}"

    local now
    now=$(_memory_bus_now)
    local cmt_id="cmt_$(date +%s)"

    # Validate depends_on is valid JSON array
    if ! echo "$depends_on" | jq -e 'type == "array"' >/dev/null 2>&1; then
        depends_on='[]'
    fi

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Add pending commitment
    local updated_state
    updated_state=$(echo "$state" | jq \
        --arg id "$cmt_id" \
        --arg desc "$description" \
        --arg priority "$priority" \
        --argjson depends_on "$depends_on" \
        --arg now "$now" \
        '.commitments.pending += [{
            id: $id,
            description: $desc,
            created_at: $now,
            priority: $priority,
            depends_on: $depends_on
        }]') || return 1

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id" || return 1

    # Output commitment ID
    echo "$cmt_id"
    return 0
}

memory_bus_complete_commitment() {
    # Mark commitment as completed and move to completed array
    #
    # Arguments:
    #   $1 - session_id (required)
    #   $2 - commitment_id (required)
    #   $3 - outcome (required)
    #
    # Returns: 0 on success, 1 if commitment not found, 2 on error

    local session_id="${1:?Session ID required}"
    local cmt_id="${2:?Commitment ID required}"
    local outcome="${3:?Outcome required}"

    local now
    now=$(_memory_bus_now)

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Find commitment in pending array
    local commitment
    commitment=$(echo "$state" | jq --arg id "$cmt_id" \
        '.commitments.pending[] | select(.id == $id)' 2>/dev/null)

    if [[ -z "$commitment" ]]; then
        _memory_bus_log "Commitment not found: $cmt_id"
        return 1
    fi

    # Move to completed with outcome
    local updated_state
    updated_state=$(echo "$state" | jq \
        --arg id "$cmt_id" \
        --arg outcome "$outcome" \
        --arg now "$now" \
        '(.commitments.pending[] | select(.id == $id)) as $cmt |
        .commitments.pending |= map(select(.id != $id)) |
        .commitments.completed += [($cmt + {
            completed_at: $now,
            outcome: $outcome
        })]') || return 2

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id"
}

memory_bus_calculate_load() {
    # Calculate and update cognitive load score
    #
    # Arguments:
    #   $1 - session_id (required)
    #
    # Returns: 0 on success, non-zero on error
    # Output: Load score (0.0-1.0) on stdout
    #
    # Algorithm:
    #   - context_items: weight 0.3 (max 10)
    #   - focus_entities: weight 0.2 (max 7)
    #   - pending_commitments: weight 0.3 (max 10)
    #   - narrative_length: weight 0.2 (max 50)

    local session_id="${1:?Session ID required}"

    local now
    now=$(_memory_bus_now)

    # Load current state
    local state
    state=$(memory_bus_load "$session_id") || return 1

    # Calculate load using jq
    local load_data
    load_data=$(echo "$state" | jq \
        --arg now "$now" \
        '{
            components: {
                context_items: (.working_memory.active_context.items | length),
                focus_entities: (.working_memory.attention_focus | length),
                pending_commitments: (.commitments.pending | length),
                narrative_length: (.working_memory.session_narrative | length)
            }
        } | {
            components: .components,
            total_score: (
                (((.components.context_items / 10.0) * 0.3) +
                 ((.components.focus_entities / 7.0) * 0.2) +
                 ((.components.pending_commitments / 10.0) * 0.3) +
                 ((.components.narrative_length / 50.0) * 0.2)) |
                if . > 1.0 then 1.0 else . end
            ),
            calculated_at: $now
        }') || return 1

    # Update state with new load data
    local updated_state
    updated_state=$(echo "$state" | jq \
        --argjson load "$load_data" \
        '.cognitive_load = ($load + {
            thresholds: .cognitive_load.thresholds
        })') || return 1

    # Save atomically
    echo "$updated_state" | memory_bus_save "$session_id" || return 1

    # Output load score
    echo "$load_data" | jq -r '.total_score'
    return 0
}

memory_bus_get_load_level() {
    # Get load level as string (low/medium/high/critical)
    #
    # Arguments:
    #   $1 - session_id (required)
    #
    # Returns: 0 on success
    # Output: Load level string

    local session_id="${1:?Session ID required}"

    local state
    state=$(memory_bus_load "$session_id") || return 1

    echo "$state" | jq -r '
        .cognitive_load as $load |
        if $load.total_score >= 0.8 then "critical"
        elif $load.total_score >= 0.6 then "high"
        elif $load.total_score >= 0.3 then "medium"
        else "low"
        end
    '
}

memory_bus_cleanup() {
    # Remove session state files older than specified hours
    #
    # Arguments:
    #   $1 - max_age_hours (optional, default: 24)
    #
    # Returns: 0 on success
    # Output: Count of deleted files on stdout

    local max_age_hours="${1:-24}"
    local max_age_minutes=$((max_age_hours * 60))

    # Ensure directory exists
    if [[ ! -d "$MEMORY_BUS_STATE_DIR" ]]; then
        echo "0"
        return 0
    fi

    # Find and count old files
    local count=0
    while IFS= read -r -d '' file; do
        rm -f "$file"
        ((count++))
    done < <(find "$MEMORY_BUS_STATE_DIR" -name "*.json" -mmin "+$max_age_minutes" -print0 2>/dev/null)

    # Also clean up lock files
    find "$MEMORY_BUS_STATE_DIR" -name "*.lock" -mmin "+$max_age_minutes" -delete 2>/dev/null || true

    echo "$count"
    return 0
}

memory_bus_get_summary() {
    # Get a concise summary of current Memory Bus state
    #
    # Arguments:
    #   $1 - session_id (required)
    #
    # Returns: 0 on success
    # Output: Human-readable summary

    local session_id="${1:?Session ID required}"

    local state
    state=$(memory_bus_load "$session_id") || return 1

    echo "$state" | jq -r '
        "Memory Bus Summary:" +
        "\n  Intent: " + (.working_memory.current_intent.description // "None") +
        "\n  Focus Items: " + (.working_memory.attention_focus | length | tostring) +
        "\n  Context Items: " + (.working_memory.active_context.items | length | tostring) +
        "\n  Narrative Events: " + (.working_memory.session_narrative | length | tostring) +
        "\n  Decisions: " + (.decisions | length | tostring) +
        "\n  Pending Commitments: " + (.commitments.pending | length | tostring) +
        "\n  Cognitive Load: " + (.cognitive_load.total_score | tostring | .[0:4])
    '
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT
# ═══════════════════════════════════════════════════════════════════════════════

# Export all functions for subshell usage
export -f memory_bus_init
export -f memory_bus_load
export -f memory_bus_save
export -f memory_bus_exists
export -f memory_bus_update_intent
export -f memory_bus_update_focus
export -f memory_bus_add_context
export -f memory_bus_add_narrative
export -f memory_bus_add_decision
export -f memory_bus_add_commitment
export -f memory_bus_complete_commitment
export -f memory_bus_calculate_load
export -f memory_bus_get_load_level
export -f memory_bus_cleanup
export -f memory_bus_get_summary
export -f _memory_bus_log
export -f _memory_bus_now
export -f _memory_bus_state_file
export -f _memory_bus_lock_file

export MEMORY_BUS_VERSION
export MEMORY_BUS_STATE_DIR
export MEMORY_BUS_SCHEMA_VERSION

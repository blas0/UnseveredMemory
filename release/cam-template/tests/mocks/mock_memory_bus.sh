#!/bin/bash
# Mock Memory Bus Implementation for Testing
# Version: 2.1.0
# This is a standalone implementation for testing the Memory Bus cognitive architecture

# Memory Bus state file location
MEMORY_BUS_DIR="${MEMORY_BUS_DIR:-$HOME/.claude/.memory-bus}"
MEMORY_BUS_STATE="${MEMORY_BUS_STATE:-$MEMORY_BUS_DIR/state.json}"

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

memory_bus_init() {
  local session_id="$1"
  local cwd="$2"
  local project_name="${3:-$(basename "$cwd")}"

  # Create directory if it doesn't exist
  mkdir -p "$MEMORY_BUS_DIR"

  # Create initial state
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local state=$(jq -n \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    --arg project "$project_name" \
    --arg timestamp "$timestamp" \
    '{
      session_id: $session_id,
      cwd: $cwd,
      project: $project,
      start_time: $timestamp,
      last_update: $timestamp,
      cognitive_load: 0.0,
      focus: {
        current_intent: null,
        active_files: [],
        recent_operations: []
      },
      narrative: [],
      metrics: {
        operations: {
          Edit: 0,
          Write: 0,
          Read: 0,
          Bash: 0
        },
        queries: 0,
        decisions: 0
      }
    }')

  # Write atomically (write to temp, then move)
  local temp_file="${MEMORY_BUS_STATE}.tmp"
  echo "$state" > "$temp_file"
  mv "$temp_file" "$MEMORY_BUS_STATE"
  chmod 600 "$MEMORY_BUS_STATE"

  echo "$state"
}

memory_bus_load() {
  if [ ! -f "$MEMORY_BUS_STATE" ]; then
    echo "Error: No active memory bus" >&2
    return 1
  fi

  cat "$MEMORY_BUS_STATE"
  return 0
}

memory_bus_save() {
  local state="$1"

  # Validate JSON
  if ! echo "$state" | jq . >/dev/null 2>&1; then
    echo "Error: Invalid JSON state" >&2
    return 1
  fi

  # Update last_update timestamp
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  state=$(echo "$state" | jq --arg ts "$timestamp" '.last_update = $ts')

  # Atomic write
  local temp_file="${MEMORY_BUS_STATE}.tmp"
  echo "$state" > "$temp_file"
  mv "$temp_file" "$MEMORY_BUS_STATE"
  chmod 600 "$MEMORY_BUS_STATE"

  return 0
}

memory_bus_update_intent() {
  local intent="$1"

  local state=$(memory_bus_load)
  if [ $? -ne 0 ]; then
    echo "Error: No active memory bus" >&2
    return 1
  fi

  state=$(echo "$state" | jq --arg intent "$intent" '.focus.current_intent = $intent')
  memory_bus_save "$state"
}

memory_bus_add_narrative() {
  local event_type="$1"
  local description="$2"
  local metadata="${3:-{}}"

  local state=$(memory_bus_load)
  if [ $? -ne 0 ]; then
    echo "Error: No active memory bus" >&2
    return 1
  fi

  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Validate metadata is valid JSON, default to {} if not
  if ! echo "$metadata" | jq . >/dev/null 2>&1; then
    metadata="{}"
  fi

  local event=$(jq -n \
    --arg type "$event_type" \
    --arg desc "$description" \
    --arg ts "$timestamp" \
    --argjson meta "$metadata" \
    '{
      type: $type,
      description: $desc,
      timestamp: $ts,
      metadata: $meta
    }')

  state=$(echo "$state" | jq --argjson event "$event" '.narrative += [$event]')
  memory_bus_save "$state"
}

memory_bus_record_operation() {
  local op_type="$1"
  local file_path="$2"
  local success="${3:-true}"

  local state=$(memory_bus_load)
  if [ $? -ne 0 ]; then
    echo "Error: No active memory bus" >&2
    return 1
  fi

  # Increment operation counter using proper jq syntax
  case "$op_type" in
    Edit)
      state=$(echo "$state" | jq '.metrics.operations.Edit += 1')
      ;;
    Write)
      state=$(echo "$state" | jq '.metrics.operations.Write += 1')
      ;;
    Read)
      state=$(echo "$state" | jq '.metrics.operations.Read += 1')
      ;;
    Bash)
      state=$(echo "$state" | jq '.metrics.operations.Bash += 1')
      ;;
  esac

  # Add to recent operations
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local op_entry=$(jq -n \
    --arg op "$op_type" \
    --arg file "$file_path" \
    --arg ts "$timestamp" \
    --arg success "$success" \
    '{
      type: $op,
      file: $file,
      timestamp: $ts,
      success: ($success == "true")
    }')

  state=$(echo "$state" | jq --argjson op "$op_entry" '.focus.recent_operations += [$op] | .focus.recent_operations |= .[-10:]')

  # Add to active files if Edit/Write
  if [[ "$op_type" =~ ^(Edit|Write)$ ]]; then
    state=$(echo "$state" | jq --arg file "$file_path" '.focus.active_files += [$file] | .focus.active_files = (.focus.active_files | unique) | .focus.active_files |= .[-20:]')
  fi

  memory_bus_save "$state"
}

memory_bus_calculate_load() {
  local state=$(memory_bus_load)
  if [ $? -ne 0 ]; then
    echo "0.0"
    return 1
  fi

  # Extract metrics
  local narrative_count=$(echo "$state" | jq '.narrative | length')
  local recent_ops=$(echo "$state" | jq '.focus.recent_operations | length')
  local active_files=$(echo "$state" | jq '.focus.active_files | length')

  # Simple load formula: (narrative_events + recent_ops*2 + active_files*3) / 100
  # This gives higher weight to active files and operations
  local load=$(echo "scale=2; ($narrative_count + $recent_ops * 2 + $active_files * 3) / 100" | bc)

  # Cap at 1.0
  load=$(echo "$load" | awk '{if ($1 > 1.0) print 1.0; else print $1}')

  # Update state
  state=$(echo "$state" | jq --argjson load "$load" '.cognitive_load = $load')
  memory_bus_save "$state"

  echo "$load"
}

memory_bus_cleanup() {
  local max_age_hours="${1:-24}"

  if [ ! -f "$MEMORY_BUS_STATE" ]; then
    return 0
  fi

  # Check file age
  local current_time=$(date +%s)
  local file_mtime

  # macOS vs Linux stat
  if [[ "$OSTYPE" == "darwin"* ]]; then
    file_mtime=$(stat -f %m "$MEMORY_BUS_STATE" 2>/dev/null || echo "0")
  else
    file_mtime=$(stat -c %Y "$MEMORY_BUS_STATE" 2>/dev/null || echo "0")
  fi

  local age_hours=$(( ($current_time - $file_mtime) / 3600 ))

  if [ "$age_hours" -ge "$max_age_hours" ]; then
    rm -f "$MEMORY_BUS_STATE"
    echo "Cleaned up stale memory bus state (age: ${age_hours}h)"
  fi
}

memory_bus_get_summary() {
  local state=$(memory_bus_load)
  if [ $? -ne 0 ]; then
    echo "No active memory bus"
    return 1
  fi

  echo "$state" | jq '{
    session_id,
    project,
    start_time,
    cognitive_load,
    current_intent: .focus.current_intent,
    active_files: (.focus.active_files | length),
    narrative_events: (.narrative | length),
    operations: .metrics.operations
  }'
}

memory_bus_clear() {
  rm -f "$MEMORY_BUS_STATE"
  echo "Memory bus cleared"
}

# =============================================================================
# CLI INTERFACE (for testing)
# =============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  # Script is being executed directly
  COMMAND="${1:-}"

  case "$COMMAND" in
    init)
      memory_bus_init "$2" "$3" "$4"
      ;;
    load)
      memory_bus_load
      ;;
    update-intent)
      memory_bus_update_intent "$2"
      ;;
    add-narrative)
      memory_bus_add_narrative "$2" "$3" "${4:-{}}"
      ;;
    record-op)
      memory_bus_record_operation "$2" "$3" "${4:-true}"
      ;;
    calculate-load)
      memory_bus_calculate_load
      ;;
    cleanup)
      memory_bus_cleanup "${2:-24}"
      ;;
    summary)
      memory_bus_get_summary
      ;;
    clear)
      memory_bus_clear
      ;;
    *)
      echo "Usage: $0 {init|load|update-intent|add-narrative|record-op|calculate-load|cleanup|summary|clear}"
      exit 1
      ;;
  esac
fi

# Export functions for sourcing
export -f memory_bus_init
export -f memory_bus_load
export -f memory_bus_save
export -f memory_bus_update_intent
export -f memory_bus_add_narrative
export -f memory_bus_record_operation
export -f memory_bus_calculate_load
export -f memory_bus_cleanup
export -f memory_bus_get_summary
export -f memory_bus_clear

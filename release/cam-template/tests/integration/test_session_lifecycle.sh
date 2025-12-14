#!/bin/bash
# Integration Tests: Session Lifecycle
# Version: 2.1.0
# Tests the complete session lifecycle with Memory Bus integration

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# Load test helpers
source "$TEST_ROOT/test_helpers.sh"
source "$TEST_ROOT/mocks/mock_memory_bus.sh"
source "$TEST_ROOT/mocks/mock_claude_input.sh"

# =============================================================================
# SESSION LIFECYCLE TESTS
# =============================================================================

test_full_session_flow() {
  begin_test "complete session lifecycle initializes and cleans up correctly"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  local session_id="session-$(generate_uuid)"
  local cwd="$TEST_TMP_DIR/project"

  # 1. SessionStart - ORIENT
  memory_bus_init "$session_id" "$cwd" "test-project" >/dev/null
  memory_bus_add_narrative "ORIENT" "Session started"

  # Verify initialization
  local state=$(memory_bus_load)
  assert_json_field_equals "$state" ".session_id" "$session_id" || return 1

  # 2. UserPromptSubmit - PERCEIVE
  memory_bus_update_intent "implement authentication feature"
  memory_bus_add_narrative "PERCEIVE" "User requested auth feature"

  # Verify intent set
  state=$(memory_bus_load)
  assert_json_field_equals "$state" ".focus.current_intent" "implement authentication feature" || return 1

  # 3. PreToolUse - ATTEND (simulate checking context before Edit)
  memory_bus_add_narrative "ATTEND" "Preparing to edit auth.py"

  # 4. PostToolUse - ENCODE (simulate Edit operation)
  memory_bus_record_operation "Edit" "$cwd/auth.py" "true"
  memory_bus_add_narrative "ENCODE" "Modified auth.py"

  # Verify operation recorded
  state=$(memory_bus_load)
  local edit_count=$(echo "$state" | jq '.metrics.operations.Edit')
  assert_equals "1" "$edit_count" "Edit operation should be recorded" || return 1

  # 5. SessionEnd - REFLECT
  memory_bus_add_narrative "REFLECT" "Session completed successfully"
  local summary=$(memory_bus_get_summary)

  # Verify summary contains expected data
  assert_json_valid "$summary" "Summary should be valid JSON" || return 1

  # 6. Cleanup
  memory_bus_clear >/dev/null

  pass_test
}

test_memory_bus_persistence() {
  begin_test "memory bus persists state across function calls"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  local session_id="session-$(generate_uuid)"

  # Initialize
  memory_bus_init "$session_id" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Add data
  memory_bus_update_intent "test intent"
  memory_bus_add_narrative "TEST" "Event 1"
  memory_bus_record_operation "Edit" "/file.py" "true"

  # Clear memory and reload from file
  unset MEMORY_BUS_CACHE
  local reloaded_state=$(memory_bus_load)

  # Verify data persisted
  assert_json_field_equals "$reloaded_state" ".focus.current_intent" "test intent" || return 1

  local narrative_count=$(echo "$reloaded_state" | jq '.narrative | length')
  assert_greater_than "$narrative_count" "0" "Narrative should be persisted" || return 1

  memory_bus_clear >/dev/null
  pass_test
}

test_cross_hook_communication() {
  begin_test "hooks can communicate via shared memory bus state"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  local session_id="session-$(generate_uuid)"

  # Hook 1: SessionStart sets initial context
  memory_bus_init "$session_id" "$TEST_TMP_DIR" "test-project" >/dev/null
  memory_bus_add_narrative "ORIENT" "Session initialized"

  # Hook 2: UserPromptSubmit reads and updates
  local state=$(memory_bus_load)
  local narrative_count=$(echo "$state" | jq '.narrative | length')
  assert_greater_than "$narrative_count" "0" "Hook 2 can read Hook 1's narrative" || return 1

  memory_bus_update_intent "shared intent"
  memory_bus_add_narrative "PERCEIVE" "Intent updated"

  # Hook 3: PostToolUse reads previous context
  state=$(memory_bus_load)
  local current_intent=$(echo "$state" | jq -r '.focus.current_intent')
  assert_equals "shared intent" "$current_intent" "Hook 3 can read Hook 2's intent" || return 1

  memory_bus_record_operation "Edit" "/file.py" "true"

  # Hook 4: SessionEnd reads accumulated state
  state=$(memory_bus_load)
  narrative_count=$(echo "$state" | jq '.narrative | length')
  assert_greater_than "$narrative_count" "1" "Hook 4 sees all narrative events" || return 1

  memory_bus_clear >/dev/null
  pass_test
}

test_cognitive_load_tracking() {
  begin_test "cognitive load increases with activity and can be calculated"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize with no load
  memory_bus_init "session-$(generate_uuid)" "$TEST_TMP_DIR" "test-project" >/dev/null
  local initial_load=$(memory_bus_calculate_load)

  # Add some activity
  memory_bus_update_intent "implement feature"
  memory_bus_add_narrative "PERCEIVE" "User request"
  memory_bus_record_operation "Edit" "/file1.py" "true"
  memory_bus_record_operation "Edit" "/file2.py" "true"
  memory_bus_record_operation "Write" "/file3.py" "true"

  # Calculate new load
  local active_load=$(memory_bus_calculate_load)

  # Load should have increased
  # Convert to integer by removing decimal point and truncating
  local initial_int=$(echo "$initial_load" | awk '{printf "%.0f", $1*100}')
  local active_int=$(echo "$active_load" | awk '{printf "%.0f", $1*100}')

  if [ "$active_int" -le "$initial_int" ]; then
    fail_test "Load should increase with activity (initial: $initial_load, active: $active_load)"
    return 1
  fi

  memory_bus_clear >/dev/null
  pass_test
}

test_narrative_timeline() {
  begin_test "narrative events maintain chronological timeline"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  memory_bus_init "session-$(generate_uuid)" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Add events in sequence
  memory_bus_add_narrative "ORIENT" "Event 1"
  sleep 0.1
  memory_bus_add_narrative "PERCEIVE" "Event 2"
  sleep 0.1
  memory_bus_add_narrative "ATTEND" "Event 3"
  sleep 0.1
  memory_bus_add_narrative "ENCODE" "Event 4"

  # Load state and verify timeline
  local state=$(memory_bus_load)

  # Verify all events present
  local event_count=$(echo "$state" | jq '.narrative | length')
  assert_equals "4" "$event_count" "Should have 4 narrative events" || return 1

  # Verify chronological order (timestamps should be increasing)
  local ts1=$(echo "$state" | jq -r '.narrative[0].timestamp')
  local ts2=$(echo "$state" | jq -r '.narrative[1].timestamp')
  local ts3=$(echo "$state" | jq -r '.narrative[2].timestamp')
  local ts4=$(echo "$state" | jq -r '.narrative[3].timestamp')

  # Simple string comparison works for ISO timestamps
  if [[ "$ts1" > "$ts2" ]] || [[ "$ts2" > "$ts3" ]] || [[ "$ts3" > "$ts4" ]]; then
    fail_test "Timestamps should be in chronological order"
    return 1
  fi

  memory_bus_clear >/dev/null
  pass_test
}

# =============================================================================
# RUN TESTS
# =============================================================================

main() {
  setup_test_env "Session Lifecycle Integration Tests"

  test_full_session_flow
  test_memory_bus_persistence
  test_cross_hook_communication
  test_cognitive_load_tracking
  test_narrative_timeline

  teardown_test_env
  print_test_summary
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi

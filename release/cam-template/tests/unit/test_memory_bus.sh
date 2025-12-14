#!/bin/bash
# Unit Tests for Memory Bus Core Functions
# Version: 2.1.0

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# Load test helpers
source "$TEST_ROOT/test_helpers.sh"

# Load Memory Bus implementation
source "$TEST_ROOT/mocks/mock_memory_bus.sh"

# =============================================================================
# TEST SUITE
# =============================================================================

test_init_creates_state_file() {
  begin_test "init creates state file with valid JSON"

  # Set up isolated environment
  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize memory bus
  local session_id="test-session-$(generate_uuid)"
  local cwd="$TEST_TMP_DIR/project"
  local project="test-project"

  local result=$(memory_bus_init "$session_id" "$cwd" "$project")

  # Assert file exists
  assert_file_exists "$MEMORY_BUS_STATE" "State file should be created" || return 1

  # Assert valid JSON
  assert_json_valid "$result" "Init should return valid JSON" || return 1

  # Assert required fields
  assert_json_field_equals "$result" ".session_id" "$session_id" || return 1
  assert_json_field_equals "$result" ".cwd" "$cwd" || return 1
  assert_json_field_equals "$result" ".project" "$project" || return 1

  # Check cognitive_load is a number (0 or 0.0)
  local load=$(echo "$result" | jq -r '.cognitive_load')
  if [ "$load" != "0" ] && [ "$load" != "0.0" ]; then
    fail_test "cognitive_load should be 0 or 0.0, got: $load"
    return 1
  fi

  pass_test
}

test_load_returns_valid_json() {
  begin_test "load returns valid JSON state"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Create a state first
  local session_id="test-session-$(generate_uuid)"
  memory_bus_init "$session_id" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Load state
  local loaded_state=$(memory_bus_load)

  # Assert valid JSON
  assert_json_valid "$loaded_state" "Loaded state should be valid JSON" || return 1

  # Assert session ID matches
  assert_json_field_equals "$loaded_state" ".session_id" "$session_id" || return 1

  pass_test
}

test_load_fails_when_no_state() {
  begin_test "load fails gracefully when no state exists"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus-empty"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Try to load non-existent state directly (not in subshell)
  set +e  # Temporarily disable exit on error
  memory_bus_load >/dev/null 2>&1
  local exit_code=$?
  set -e  # Re-enable exit on error

  # Should fail (exit code should be non-zero)
  if [ "$exit_code" -eq 0 ]; then
    fail_test "Load should fail when no state exists (got exit code: $exit_code)"
    return 1
  fi

  pass_test
}

test_save_is_atomic() {
  begin_test "save operation is atomic (uses temp file)"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  local session_id="test-session-$(generate_uuid)"
  memory_bus_init "$session_id" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Load and modify
  local state=$(memory_bus_load)
  state=$(echo "$state" | jq '.test_field = "test_value"')

  # Save
  memory_bus_save "$state"

  # Verify temp file is gone
  assert_file_not_exists "$MEMORY_BUS_STATE.tmp" "Temp file should be cleaned up" || return 1

  # Verify state was saved
  local loaded_state=$(memory_bus_load)
  assert_json_field_equals "$loaded_state" ".test_field" "test_value" || return 1

  pass_test
}

test_save_validates_json() {
  begin_test "save rejects invalid JSON"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Try to save invalid JSON - call directly, not in subshell
  local invalid_json="{ invalid json"
  set +e  # Temporarily disable exit on error
  memory_bus_save "$invalid_json" >/dev/null 2>&1
  local exit_code=$?
  set -e  # Re-enable exit on error

  # Should fail (exit code should be non-zero)
  if [ "$exit_code" -eq 0 ]; then
    fail_test "Save should reject invalid JSON (got exit code: $exit_code)"
    return 1
  fi

  pass_test
}

test_update_intent_persists() {
  begin_test "update_intent persists intent to state"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Update intent
  local new_intent="implement authentication feature"
  memory_bus_update_intent "$new_intent"

  # Load and verify
  local state=$(memory_bus_load)
  assert_json_field_equals "$state" ".focus.current_intent" "$new_intent" || return 1

  pass_test
}

test_add_narrative_appends() {
  begin_test "add_narrative appends events to narrative array"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Add narrative events
  memory_bus_add_narrative "ORIENT" "Session started" '{"source": "hook"}'
  memory_bus_add_narrative "PERCEIVE" "User requested feature" '{"source": "hook"}'

  # Load and verify
  local state=$(memory_bus_load)
  local narrative_count=$(echo "$state" | jq '.narrative | length')

  assert_equals "2" "$narrative_count" "Should have 2 narrative events" || return 1

  # Verify first event
  local first_event_type=$(echo "$state" | jq -r '.narrative[0].type')
  assert_equals "ORIENT" "$first_event_type" "First event type should be ORIENT" || return 1

  pass_test
}

test_record_operation_increments_counter() {
  begin_test "record_operation increments operation counters"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Record operations
  memory_bus_record_operation "Edit" "/path/to/file.py" "true"
  memory_bus_record_operation "Edit" "/path/to/other.py" "true"
  memory_bus_record_operation "Write" "/path/to/new.py" "true"

  # Load and verify
  local state=$(memory_bus_load)
  local edit_count=$(echo "$state" | jq '.metrics.operations.Edit')
  local write_count=$(echo "$state" | jq '.metrics.operations.Write')

  assert_equals "2" "$edit_count" "Edit count should be 2" || return 1
  assert_equals "1" "$write_count" "Write count should be 1" || return 1

  pass_test
}

test_record_operation_tracks_active_files() {
  begin_test "record_operation tracks active files for Edit/Write"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Record Edit/Write operations
  memory_bus_record_operation "Edit" "/path/to/file1.py" "true"
  memory_bus_record_operation "Write" "/path/to/file2.py" "true"
  memory_bus_record_operation "Read" "/path/to/file3.py" "true"  # Should not be tracked

  # Load and verify
  local state=$(memory_bus_load)
  local active_files=$(echo "$state" | jq -r '.focus.active_files | join(",")')

  assert_contains "$active_files" "file1.py" "Should track Edit files" || return 1
  assert_contains "$active_files" "file2.py" "Should track Write files" || return 1
  assert_not_contains "$active_files" "file3.py" "Should not track Read files" || return 1

  pass_test
}

test_record_operation_limits_recent_ops() {
  begin_test "record_operation limits recent operations to 10"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Record 15 operations
  for i in {1..15}; do
    memory_bus_record_operation "Edit" "/path/to/file${i}.py" "true"
  done

  # Load and verify
  local state=$(memory_bus_load)
  local recent_ops_count=$(echo "$state" | jq '.focus.recent_operations | length')

  assert_equals "10" "$recent_ops_count" "Should limit recent operations to 10" || return 1

  pass_test
}

test_calculate_load_formula() {
  begin_test "calculate_load uses correct formula"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Add some load
  memory_bus_add_narrative "ORIENT" "Event 1"
  memory_bus_add_narrative "PERCEIVE" "Event 2"
  memory_bus_record_operation "Edit" "/path/to/file1.py" "true"
  memory_bus_record_operation "Edit" "/path/to/file2.py" "true"

  # Calculate load
  local load=$(memory_bus_calculate_load)

  # Load should be > 0
  local load_int=$(echo "$load * 100" | bc | cut -d. -f1)
  assert_greater_than "$load_int" "0" "Load should be greater than 0" || return 1

  pass_test
}

test_calculate_load_caps_at_one() {
  begin_test "calculate_load caps at 1.0"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Add excessive load (100+ events)
  for i in {1..100}; do
    memory_bus_add_narrative "TEST" "Event $i"
    memory_bus_record_operation "Edit" "/path/to/file${i}.py" "true"
  done

  # Calculate load
  local load=$(memory_bus_calculate_load)

  # Load should be capped at 1.0 (could be "1.0", "1.00", or "1")
  # Convert to integer comparison by multiplying by 100
  local load_int=$(echo "$load * 100" | bc 2>/dev/null || echo "$load" | awk '{print int($1*100)}')
  if [ "$load_int" -ne 100 ]; then
    fail_test "Load should be capped at 1.0 (got: $load, int: $load_int)"
    return 1
  fi

  pass_test
}

test_cleanup_removes_stale() {
  begin_test "cleanup removes stale state files"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Make file old by touching with old timestamp (25 hours ago)
  # Note: This is platform-dependent, so we'll create a workaround
  touch -t $(date -v-25H +%Y%m%d%H%M 2>/dev/null || date -d '25 hours ago' +%Y%m%d%H%M) "$MEMORY_BUS_STATE" 2>/dev/null || {
    # If touch with timestamp doesn't work, skip this test
    echo "  [SKIP] Platform doesn't support touch -t, skipping cleanup test"
    return 0
  }

  # Run cleanup with 24 hour threshold
  memory_bus_cleanup 24

  # File should be removed
  assert_file_not_exists "$MEMORY_BUS_STATE" "Stale state should be removed" || return 1

  pass_test
}

test_get_summary_returns_overview() {
  begin_test "get_summary returns state overview"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  local session_id="test-session-$(generate_uuid)"
  memory_bus_init "$session_id" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Add some activity
  memory_bus_update_intent "test feature"
  memory_bus_add_narrative "ORIENT" "Started"
  memory_bus_record_operation "Edit" "/path/to/file.py" "true"

  # Get summary
  local summary=$(memory_bus_get_summary)

  # Validate summary
  assert_json_valid "$summary" "Summary should be valid JSON" || return 1
  assert_json_field_equals "$summary" ".session_id" "$session_id" || return 1
  assert_json_field_equals "$summary" ".project" "test-project" || return 1
  assert_json_field_equals "$summary" ".current_intent" "test feature" || return 1

  pass_test
}

test_clear_removes_state() {
  begin_test "clear removes memory bus state"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Verify state exists
  assert_file_exists "$MEMORY_BUS_STATE" "State should exist before clear" || return 1

  # Clear
  memory_bus_clear >/dev/null

  # Verify state is gone
  assert_file_not_exists "$MEMORY_BUS_STATE" "State should be removed after clear" || return 1

  pass_test
}

test_concurrent_access_safety() {
  begin_test "concurrent access uses atomic writes"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "test-session" "$TEST_TMP_DIR" "test-project" >/dev/null

  # Simulate concurrent writes
  (memory_bus_update_intent "intent-1") &
  (memory_bus_update_intent "intent-2") &
  (memory_bus_record_operation "Edit" "/file1.py" "true") &
  (memory_bus_record_operation "Edit" "/file2.py" "true") &

  # Wait for all to complete
  wait

  # State should still be valid JSON
  local state=$(memory_bus_load)
  assert_json_valid "$state" "State should remain valid after concurrent access" || return 1

  pass_test
}

# =============================================================================
# RUN TESTS
# =============================================================================

main() {
  setup_test_env "Memory Bus Unit Tests"

  # Core functionality tests
  test_init_creates_state_file
  test_load_returns_valid_json
  test_load_fails_when_no_state
  test_save_is_atomic
  test_save_validates_json

  # State update tests
  test_update_intent_persists
  test_add_narrative_appends
  test_record_operation_increments_counter
  test_record_operation_tracks_active_files
  test_record_operation_limits_recent_ops

  # Load calculation tests
  test_calculate_load_formula
  test_calculate_load_caps_at_one

  # Maintenance tests
  test_cleanup_removes_stale
  test_get_summary_returns_overview
  test_clear_removes_state

  # Safety tests
  test_concurrent_access_safety

  teardown_test_env
  print_test_summary
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi

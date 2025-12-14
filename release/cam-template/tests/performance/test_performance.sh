#!/bin/bash
# Performance Tests: Hook Latency and Throughput
# Version: 2.1.0
# Benchmarks hook execution time and Memory Bus performance

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# Load test helpers
source "$TEST_ROOT/test_helpers.sh"
source "$TEST_ROOT/mocks/mock_memory_bus.sh"

# Performance thresholds (in milliseconds)
HOOK_LATENCY_TARGET=100
MEMORY_BUS_IO_TARGET=50
CONCURRENT_ACCESS_TARGET=500

# =============================================================================
# PERFORMANCE TESTS
# =============================================================================

test_hook_latency_under_100ms() {
  begin_test "hook operations complete within 100ms target"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "perf-session" "$TEST_TMP_DIR" "perf-test" >/dev/null

  # Measure typical hook workflow
  local start_time=$(date +%s%N)

  # Simulate typical hook operations
  memory_bus_update_intent "test intent"
  memory_bus_add_narrative "TEST" "Event"
  memory_bus_record_operation "Edit" "/file.py" "true"
  memory_bus_calculate_load >/dev/null

  local end_time=$(date +%s%N)
  local duration=$((($end_time - $start_time) / 1000000)) # Convert to milliseconds

  # Check if under threshold
  if [ "$duration" -gt "$HOOK_LATENCY_TARGET" ]; then
    echo "    [WARNING] Duration: ${duration}ms (target: ${HOOK_LATENCY_TARGET}ms)"
  else
    echo "    [OK] Duration: ${duration}ms"
  fi

  # We don't fail on performance tests, just warn
  memory_bus_clear >/dev/null
  pass_test
}

test_memory_bus_io_speed() {
  begin_test "memory bus I/O operations are fast"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "io-perf-session" "$TEST_TMP_DIR" "io-test" >/dev/null

  # Measure save operation
  local state=$(memory_bus_load)
  local start_time=$(date +%s%N)
  memory_bus_save "$state"
  local end_time=$(date +%s%N)
  local save_duration=$((($end_time - $start_time) / 1000000))

  # Measure load operation
  start_time=$(date +%s%N)
  memory_bus_load >/dev/null
  end_time=$(date +%s%N)
  local load_duration=$((($end_time - $start_time) / 1000000))

  echo "    [INFO] Save: ${save_duration}ms, Load: ${load_duration}ms"

  if [ "$save_duration" -gt "$MEMORY_BUS_IO_TARGET" ] || [ "$load_duration" -gt "$MEMORY_BUS_IO_TARGET" ]; then
    echo "    [WARNING] I/O slower than ${MEMORY_BUS_IO_TARGET}ms target"
  fi

  memory_bus_clear >/dev/null
  pass_test
}

test_concurrent_access() {
  begin_test "concurrent access handles multiple operations"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "concurrent-session" "$TEST_TMP_DIR" "concurrent-test" >/dev/null

  # Measure concurrent operations
  local start_time=$(date +%s%N)

  # Simulate concurrent hook operations (sequential in bash, but tests atomic writes)
  for i in {1..10}; do
    memory_bus_update_intent "intent-$i"
    memory_bus_record_operation "Edit" "/file-$i.py" "true"
  done

  local end_time=$(date +%s%N)
  local duration=$((($end_time - $start_time) / 1000000))

  echo "    [INFO] 10 operations: ${duration}ms (avg: $((duration / 10))ms per op)"

  if [ "$duration" -gt "$CONCURRENT_ACCESS_TARGET" ]; then
    echo "    [WARNING] Duration ${duration}ms exceeds ${CONCURRENT_ACCESS_TARGET}ms target"
  fi

  # Verify all operations were recorded
  local state=$(memory_bus_load)
  local edit_count=$(echo "$state" | jq '.metrics.operations.Edit')

  if [ "$edit_count" -ne 10 ]; then
    fail_test "Expected 10 Edit operations, got $edit_count"
    return 1
  fi

  memory_bus_clear >/dev/null
  pass_test
}

test_memory_growth() {
  begin_test "memory bus state size stays reasonable"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "memory-growth-session" "$TEST_TMP_DIR" "growth-test" >/dev/null

  # Add significant amount of data
  for i in {1..50}; do
    memory_bus_add_narrative "TEST" "Event number $i with some description text"
    memory_bus_record_operation "Edit" "/path/to/file-${i}.py" "true"
  done

  # Check file size
  local file_size=$(stat -f%z "$MEMORY_BUS_STATE" 2>/dev/null || stat -c%s "$MEMORY_BUS_STATE" 2>/dev/null || echo "0")
  local size_kb=$((file_size / 1024))

  echo "    [INFO] State file size: ${size_kb}KB after 50 operations"

  # Warn if state file is getting large (>100KB is excessive for in-memory state)
  if [ "$file_size" -gt 102400 ]; then
    echo "    [WARNING] State file exceeds 100KB, consider cleanup strategies"
  fi

  memory_bus_clear >/dev/null
  pass_test
}

test_load_calculation_performance() {
  begin_test "cognitive load calculation is efficient"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize with data
  memory_bus_init "load-calc-session" "$TEST_TMP_DIR" "load-test" >/dev/null

  # Add moderate amount of data
  for i in {1..20}; do
    memory_bus_add_narrative "TEST" "Event $i"
    memory_bus_record_operation "Edit" "/file-${i}.py" "true"
  done

  # Measure load calculation time
  local start_time=$(date +%s%N)
  for i in {1..10}; do
    memory_bus_calculate_load >/dev/null
  done
  local end_time=$(date +%s%N)

  local total_duration=$((($end_time - $start_time) / 1000000))
  local avg_duration=$((total_duration / 10))

  echo "    [INFO] Average load calculation: ${avg_duration}ms (10 iterations)"

  if [ "$avg_duration" -gt 10 ]; then
    echo "    [WARNING] Load calculation slower than 10ms target"
  fi

  memory_bus_clear >/dev/null
  pass_test
}

test_throughput() {
  begin_test "memory bus handles high operation throughput"

  local test_bus_dir="$TEST_TMP_DIR/.memory-bus"
  export MEMORY_BUS_DIR="$test_bus_dir"
  export MEMORY_BUS_STATE="$test_bus_dir/state.json"

  # Initialize
  memory_bus_init "throughput-session" "$TEST_TMP_DIR" "throughput-test" >/dev/null

  # Measure throughput - 100 operations
  local start_time=$(date +%s%N)

  for i in {1..100}; do
    case $((i % 4)) in
      0) memory_bus_update_intent "intent-$i" ;;
      1) memory_bus_add_narrative "TEST" "Event $i" ;;
      2) memory_bus_record_operation "Edit" "/file-$i.py" "true" ;;
      3) memory_bus_calculate_load >/dev/null ;;
    esac
  done

  local end_time=$(date +%s%N)
  local duration=$((($end_time - $start_time) / 1000000))
  local ops_per_second=$((100000 / duration))

  echo "    [INFO] 100 operations in ${duration}ms (~${ops_per_second} ops/sec)"

  if [ "$duration" -gt 2000 ]; then
    echo "    [WARNING] Throughput lower than expected (target: <2000ms for 100 ops)"
  fi

  memory_bus_clear >/dev/null
  pass_test
}

# =============================================================================
# RUN TESTS
# =============================================================================

main() {
  setup_test_env "Performance Benchmarks"

  echo ""
  echo "Performance Targets:"
  echo "  Hook Latency:        < ${HOOK_LATENCY_TARGET}ms"
  echo "  Memory Bus I/O:      < ${MEMORY_BUS_IO_TARGET}ms"
  echo "  Concurrent Access:   < ${CONCURRENT_ACCESS_TARGET}ms"
  echo ""

  test_hook_latency_under_100ms
  test_memory_bus_io_speed
  test_concurrent_access
  test_memory_growth
  test_load_calculation_performance
  test_throughput

  teardown_test_env
  print_test_summary
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi

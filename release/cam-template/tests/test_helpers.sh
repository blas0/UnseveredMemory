#!/bin/bash
# CAM Test Helpers - Common assertion and utility functions
# Version: 2.1.0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Current test context
CURRENT_TEST=""
CURRENT_SUITE=""

# Temp directory for test isolation
TEST_TMP_DIR=""

# =============================================================================
# TEST LIFECYCLE
# =============================================================================

setup_test_env() {
  local suite_name="$1"
  CURRENT_SUITE="$suite_name"

  # Create isolated temp directory
  TEST_TMP_DIR=$(mktemp -d -t cam-test.XXXXXX)
  export TEST_TMP_DIR

  # Create mock CAM directory structure
  mkdir -p "$TEST_TMP_DIR/.claude/cam"
  mkdir -p "$TEST_TMP_DIR/.claude/.session-state"
  mkdir -p "$TEST_TMP_DIR/.claude/.session-primers"

  echo -e "${YELLOW}[SUITE] ${suite_name}${NC}"
}

teardown_test_env() {
  # Clean up temp directory
  if [ -n "$TEST_TMP_DIR" ] && [ -d "$TEST_TMP_DIR" ]; then
    rm -rf "$TEST_TMP_DIR"
  fi
}

begin_test() {
  local test_name="$1"
  CURRENT_TEST="$test_name"
  TESTS_RUN=$((TESTS_RUN + 1))
}

pass_test() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "  ${GREEN}✓${NC} ${CURRENT_TEST}"
}

fail_test() {
  local reason="$1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "  ${RED}✗${NC} ${CURRENT_TEST}"
  echo -e "    ${RED}Reason: ${reason}${NC}"
}

# =============================================================================
# ASSERTIONS
# =============================================================================

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values not equal}"

  if [ "$expected" = "$actual" ]; then
    return 0
  else
    fail_test "$message (expected: '$expected', got: '$actual')"
    return 1
  fi
}

assert_not_equals() {
  local not_expected="$1"
  local actual="$2"
  local message="${3:-Values should not be equal}"

  if [ "$not_expected" != "$actual" ]; then
    return 0
  else
    fail_test "$message (both values: '$actual')"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String not found}"

  if echo "$haystack" | grep -q "$needle"; then
    return 0
  else
    fail_test "$message (expected to find: '$needle')"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should not be found}"

  if ! echo "$haystack" | grep -q "$needle"; then
    return 0
  else
    fail_test "$message (unexpectedly found: '$needle')"
    return 1
  fi
}

assert_file_exists() {
  local file_path="$1"
  local message="${2:-File does not exist}"

  if [ -f "$file_path" ]; then
    return 0
  else
    fail_test "$message (file: '$file_path')"
    return 1
  fi
}

assert_file_not_exists() {
  local file_path="$1"
  local message="${2:-File should not exist}"

  if [ ! -f "$file_path" ]; then
    return 0
  else
    fail_test "$message (file: '$file_path')"
    return 1
  fi
}

assert_dir_exists() {
  local dir_path="$1"
  local message="${2:-Directory does not exist}"

  if [ -d "$dir_path" ]; then
    return 0
  else
    fail_test "$message (directory: '$dir_path')"
    return 1
  fi
}

assert_json_valid() {
  local json_string="$1"
  local message="${2:-Invalid JSON}"

  if echo "$json_string" | jq . >/dev/null 2>&1; then
    return 0
  else
    fail_test "$message"
    return 1
  fi
}

assert_json_field_equals() {
  local json_string="$1"
  local field_path="$2"
  local expected_value="$3"
  local message="${4:-JSON field value mismatch}"

  local actual_value=$(echo "$json_string" | jq -r "$field_path" 2>/dev/null)

  if [ "$actual_value" = "$expected_value" ]; then
    return 0
  else
    fail_test "$message (field: $field_path, expected: '$expected_value', got: '$actual_value')"
    return 1
  fi
}

assert_exit_code() {
  local expected_code="$1"
  local actual_code="$2"
  local message="${3:-Exit code mismatch}"

  if [ "$expected_code" -eq "$actual_code" ]; then
    return 0
  else
    fail_test "$message (expected: $expected_code, got: $actual_code)"
    return 1
  fi
}

assert_greater_than() {
  local value="$1"
  local threshold="$2"
  local message="${3:-Value not greater than threshold}"

  if [ "$value" -gt "$threshold" ]; then
    return 0
  else
    fail_test "$message (value: $value, threshold: $threshold)"
    return 1
  fi
}

assert_less_than() {
  local value="$1"
  local threshold="$2"
  local message="${3:-Value not less than threshold}"

  if [ "$value" -lt "$threshold" ]; then
    return 0
  else
    fail_test "$message (value: $value, threshold: $threshold)"
    return 1
  fi
}

# =============================================================================
# UTILITIES
# =============================================================================

create_mock_json() {
  local file_path="$1"
  local json_content="$2"

  echo "$json_content" | jq . > "$file_path" 2>/dev/null
}

create_mock_file() {
  local file_path="$1"
  local content="$2"

  mkdir -p "$(dirname "$file_path")"
  echo "$content" > "$file_path"
}

generate_uuid() {
  # Generate a simple UUID-like string
  cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | fold -w 8 | head -n 1
}

generate_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

measure_time() {
  local start_time=$(date +%s%N)
  eval "$@"
  local end_time=$(date +%s%N)
  local duration=$((($end_time - $start_time) / 1000000)) # Convert to milliseconds
  echo "$duration"
}

# =============================================================================
# REPORTING
# =============================================================================

print_test_summary() {
  echo ""
  echo "=================================="
  echo "TEST SUMMARY"
  echo "=================================="
  echo "Total Tests:  $TESTS_RUN"
  echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
  echo "=================================="

  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    return 0
  else
    echo -e "${RED}SOME TESTS FAILED${NC}"
    return 1
  fi
}

# Export functions for use in test scripts
export -f setup_test_env
export -f teardown_test_env
export -f begin_test
export -f pass_test
export -f fail_test
export -f assert_equals
export -f assert_not_equals
export -f assert_contains
export -f assert_not_contains
export -f assert_file_exists
export -f assert_file_not_exists
export -f assert_dir_exists
export -f assert_json_valid
export -f assert_json_field_equals
export -f assert_exit_code
export -f assert_greater_than
export -f assert_less_than
export -f create_mock_json
export -f create_mock_file
export -f generate_uuid
export -f generate_timestamp
export -f measure_time
export -f print_test_summary

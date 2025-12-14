# CAM Cognitive Hook Architecture - Test Suite v2.1.0

Comprehensive test framework for the CAM (Continuous Architectural Memory) Cognitive Hook Architecture.

## Overview

This test suite validates the Memory Bus implementation and cognitive functions that power CAM's hook-based architecture. The framework includes unit tests, integration tests, end-to-end tests, and performance benchmarks.

## Directory Structure

```
tests/
├── README.md                 # This file
├── run_tests.sh             # Main test runner
├── test_helpers.sh          # Common assertion and utility functions
├── unit/                    # Unit tests for individual components
│   └── test_memory_bus.sh   # Memory Bus core function tests
├── integration/             # Integration tests for hook interactions
├── e2e/                     # End-to-end workflow tests
├── performance/             # Performance and latency tests
├── mocks/                   # Mock implementations for testing
│   ├── mock_memory_bus.sh   # Memory Bus mock implementation
│   ├── mock_claude_input.sh # Hook input generators
│   └── mock_cam.sh          # CAM CLI mock
└── fixtures/                # Test data and fixtures
```

## Quick Start

### Run All Tests

```bash
cd /path/to/cam-template/tests
./run_tests.sh
```

### Run Specific Test Suite

```bash
# Run only unit tests
./run_tests.sh unit

# Run only integration tests
./run_tests.sh integration

# Run specific test file
./run_tests.sh unit/test_memory_bus.sh
```

## Test Categories

### 1. Unit Tests (`unit/`)

Test individual components in isolation.

**Memory Bus Tests** (`test_memory_bus.sh`)
- ✓ init creates state file with valid JSON
- ✓ load returns valid JSON state
- ✓ load fails gracefully when no state exists
- ✓ save operation is atomic (uses temp file)
- ✓ save rejects invalid JSON
- ✓ update_intent persists intent to state
- ✓ add_narrative appends events to narrative array
- ✓ record_operation increments operation counters
- ✓ record_operation tracks active files for Edit/Write
- ✓ record_operation limits recent operations to 10
- ✓ calculate_load uses correct formula
- ✓ calculate_load caps at 1.0
- ✓ cleanup removes stale state files
- ✓ get_summary returns state overview
- ✓ clear removes memory bus state
- ✓ concurrent access uses atomic writes

### 2. Integration Tests (`integration/`)

Test interactions between hooks and the Memory Bus.

**Planned Tests:**
- Session lifecycle (SessionStart → UserPromptSubmit → PostToolUse → SessionEnd)
- Cross-hook communication via Memory Bus
- CAM database integration
- Backward compatibility with existing hook implementations

### 3. End-to-End Tests (`e2e/`)

Simulate complete Claude Code sessions.

**Planned Tests:**
- Full cognitive cycle simulation
- Multi-hook workflow scenarios
- Real-world usage patterns

### 4. Performance Tests (`performance/`)

Benchmark hook latency and throughput.

**Planned Tests:**
- Hook execution time (target: <100ms)
- Memory Bus I/O performance
- Concurrent access stress tests
- Cache efficiency

## Test Helpers

### Assertions

```bash
assert_equals "expected" "actual" "message"
assert_not_equals "not_expected" "actual" "message"
assert_contains "haystack" "needle" "message"
assert_file_exists "/path/to/file" "message"
assert_json_valid "$json_string" "message"
assert_json_field_equals "$json" ".field" "expected_value"
assert_exit_code 0 $? "message"
assert_greater_than 10 5 "message"
assert_less_than 5 10 "message"
```

### Utilities

```bash
setup_test_env "Suite Name"          # Initialize test environment
teardown_test_env                     # Clean up after tests
begin_test "test description"         # Start a test
pass_test                             # Mark test as passed
fail_test "reason"                    # Mark test as failed
create_mock_json "/path" "$json"      # Create mock JSON file
generate_uuid                         # Generate test UUID
generate_timestamp                    # Generate ISO timestamp
```

## Mock Utilities

### Mock Memory Bus

Standalone implementation for testing Memory Bus functionality:

```bash
source tests/mocks/mock_memory_bus.sh

# Initialize
memory_bus_init "session-id" "/path/to/cwd" "project-name"

# Update state
memory_bus_update_intent "implement feature"
memory_bus_add_narrative "ORIENT" "Started session"
memory_bus_record_operation "Edit" "/path/to/file.py" "true"

# Query state
memory_bus_load
memory_bus_get_summary
memory_bus_calculate_load

# Cleanup
memory_bus_clear
```

### Mock Claude Input

Generate sample hook inputs:

```bash
source tests/mocks/mock_claude_input.sh

# Generate hook inputs
generate_session_start_input "session-id" "/path/to/cwd"
generate_user_prompt_input "prompt text" "session-id" "/cwd"
generate_post_tool_use_input "Edit" '{"file_path":"/file.py"}' "true" "session-id" "/cwd"
```

### Mock CAM CLI

Lightweight CAM mock for testing:

```bash
source tests/mocks/mock_cam.sh

# Initialize mock CAM
mock_cam_init

# Use mock operations
mock_cam_query "search query" 5
mock_cam_annotate "title" "content" "tags"
mock_cam_stats
```

## Writing Tests

### Test Structure

```bash
#!/bin/bash
# Test Suite Name
# Version: 2.1.0

set -e

# Get script directory and load helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"
source "$TEST_ROOT/test_helpers.sh"

# Load mocks if needed
source "$TEST_ROOT/mocks/mock_memory_bus.sh"

# Test function
test_my_feature() {
  begin_test "my feature works correctly"

  # Setup
  local test_dir="$TEST_TMP_DIR/my-test"
  mkdir -p "$test_dir"

  # Execute
  # ... test logic ...

  # Assert
  assert_equals "expected" "$result" "Feature should work" || return 1

  pass_test
}

# Main function
main() {
  setup_test_env "My Test Suite"

  test_my_feature
  # ... more tests ...

  teardown_test_env
  print_test_summary
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
```

### Best Practices

1. **Isolation**: Each test should be independent and not affect others
2. **Cleanup**: Always clean up test artifacts in `teardown_test_env`
3. **Descriptive Names**: Use clear, descriptive test function names
4. **Single Purpose**: Each test should verify one specific behavior
5. **Fast Execution**: Keep tests fast (<1s per test when possible)
6. **Error Messages**: Provide clear failure messages for debugging

## Requirements

### System Dependencies

- **bash** 4.0+
- **jq** (JSON processing)
- **bc** (floating point calculations, optional)

### macOS-specific

- **coreutils** (for `gtimeout`): `brew install coreutils`

### Linux-specific

- **timeout** command (usually pre-installed)

## Test Output

### Success

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   CAM COGNITIVE HOOK ARCHITECTURE - TEST SUITE v2.1.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

════════════════════════════════════════════════════════════════
  Running: test_memory_bus
════════════════════════════════════════════════════════════════

[SUITE] Memory Bus Unit Tests
  ✓ init creates state file with valid JSON
  ✓ load returns valid JSON state
  ...
  ✓ concurrent access uses atomic writes

==================================
TEST SUMMARY
==================================
Total Tests:  16
Passed:       16
Failed:       0
==================================
ALL TESTS PASSED

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          FINAL TEST SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total Suites:  1
  Passed:        1
  Failed:        0

  ✓ ALL TEST SUITES PASSED

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Failure

```
  ✗ save rejects invalid JSON
    Reason: Save should reject invalid JSON (got exit code: 0)
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: CAM Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: sudo apt-get install -y jq bc
      - name: Run tests
        run: cd release/cam-template/tests && ./run_tests.sh
```

## Troubleshooting

### Tests fail with "jq: command not found"

Install jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

### Tests fail with "bc: command not found"

Install bc (optional, only needed for some load calculation tests):
```bash
# macOS
brew install bc

# Ubuntu/Debian
sudo apt-get install bc
```

### Timeout command not found (macOS)

Install coreutils:
```bash
brew install coreutils
```

### Tests are slow

Run specific test suites instead of all tests:
```bash
./run_tests.sh unit  # Only unit tests
```

## Future Enhancements

- [ ] Add integration tests for all cognitive functions
- [ ] Add e2e workflow simulation tests
- [ ] Add performance benchmarking suite
- [ ] Add test coverage reporting
- [ ] Add CI/CD integration examples
- [ ] Add mutation testing
- [ ] Add property-based testing

## Contributing

When adding new tests:

1. Follow the existing test structure
2. Add tests to the appropriate directory (unit/integration/e2e/performance)
3. Update this README with new test descriptions
4. Ensure all tests pass before committing
5. Keep tests fast and focused

## Version History

- **v2.1.0** (2024-12-13): Initial test framework with Memory Bus unit tests
  - 16 unit tests for Memory Bus core functions
  - Test helpers and assertion library
  - Mock implementations for isolated testing
  - Main test runner with suite filtering

## License

Part of the CAM (Continuous Architectural Memory) project.

#!/bin/bash
# CAM Cognitive Hook Test Runner
# Version: 2.1.0

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SUITE_FILTER="${1:-all}"
VERBOSE="${VERBOSE:-0}"

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${BLUE}   CAM COGNITIVE HOOK ARCHITECTURE - TEST SUITE v2.1.0${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

print_suite_header() {
  local suite_name="$1"
  echo ""
  echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Running: ${suite_name}${NC}"
  echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
  echo ""
}

run_test_suite() {
  local test_file="$1"
  local suite_name="$(basename "$test_file" .sh)"

  TOTAL_SUITES=$((TOTAL_SUITES + 1))

  print_suite_header "$suite_name"

  # Run test and capture exit code
  if bash "$test_file"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    echo -e "${GREEN}✓ Suite passed: $suite_name${NC}"
    return 0
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    echo -e "${RED}✗ Suite failed: $suite_name${NC}"
    return 1
  fi
}

print_final_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "                          FINAL TEST SUMMARY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Total Suites:  $TOTAL_SUITES"
  echo -e "  ${GREEN}Passed:        $PASSED_SUITES${NC}"
  echo -e "  ${RED}Failed:        $FAILED_SUITES${NC}"
  echo ""

  if [ "$FAILED_SUITES" -eq 0 ]; then
    echo -e "${GREEN}  ✓ ALL TEST SUITES PASSED${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 0
  else
    echo -e "${RED}  ✗ SOME TEST SUITES FAILED${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 1
  fi
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
  print_header

  # Check dependencies
  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    exit 1
  fi

  if ! command -v bc >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: bc not installed, some load calculation tests may fail${NC}"
  fi

  # Determine which tests to run
  case "$SUITE_FILTER" in
    all)
      echo "Running all test suites..."
      ;;
    unit)
      echo "Running unit tests only..."
      ;;
    integration)
      echo "Running integration tests only..."
      ;;
    e2e)
      echo "Running e2e tests only..."
      ;;
    performance)
      echo "Running performance tests only..."
      ;;
    *)
      echo -e "${YELLOW}Running specific suite: $SUITE_FILTER${NC}"
      ;;
  esac

  # Run unit tests
  if [[ "$SUITE_FILTER" == "all" ]] || [[ "$SUITE_FILTER" == "unit" ]]; then
    for test_file in "$SCRIPT_DIR"/unit/test_*.sh; do
      if [ -f "$test_file" ]; then
        run_test_suite "$test_file" || true
      fi
    done
  fi

  # Run integration tests
  if [[ "$SUITE_FILTER" == "all" ]] || [[ "$SUITE_FILTER" == "integration" ]]; then
    for test_file in "$SCRIPT_DIR"/integration/test_*.sh; do
      if [ -f "$test_file" ]; then
        run_test_suite "$test_file" || true
      fi
    done
  fi

  # Run e2e tests
  if [[ "$SUITE_FILTER" == "all" ]] || [[ "$SUITE_FILTER" == "e2e" ]]; then
    for test_file in "$SCRIPT_DIR"/e2e/test_*.sh; do
      if [ -f "$test_file" ]; then
        run_test_suite "$test_file" || true
      fi
    done
  fi

  # Run performance tests
  if [[ "$SUITE_FILTER" == "all" ]] || [[ "$SUITE_FILTER" == "performance" ]]; then
    for test_file in "$SCRIPT_DIR"/performance/test_*.sh; do
      if [ -f "$test_file" ]; then
        run_test_suite "$test_file" || true
      fi
    done
  fi

  # Run specific suite if provided
  if [[ "$SUITE_FILTER" != "all" ]] && [[ "$SUITE_FILTER" != "unit" ]] && \
     [[ "$SUITE_FILTER" != "integration" ]] && [[ "$SUITE_FILTER" != "e2e" ]] && \
     [[ "$SUITE_FILTER" != "performance" ]]; then
    # Treat as specific test file
    if [ -f "$SUITE_FILTER" ]; then
      run_test_suite "$SUITE_FILTER" || true
    else
      echo -e "${RED}Error: Test file not found: $SUITE_FILTER${NC}"
      exit 1
    fi
  fi

  # Print final summary
  print_final_summary
}

# Show usage
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  echo "Usage: $0 [suite]"
  echo ""
  echo "Suites:"
  echo "  all           - Run all test suites (default)"
  echo "  unit          - Run unit tests only"
  echo "  integration   - Run integration tests only"
  echo "  e2e           - Run end-to-end tests only"
  echo "  performance   - Run performance tests only"
  echo "  <file>        - Run specific test file"
  echo ""
  echo "Examples:"
  echo "  $0                          # Run all tests"
  echo "  $0 unit                     # Run unit tests"
  echo "  $0 unit/test_memory_bus.sh  # Run specific test"
  echo ""
  exit 0
fi

# Run main
main
exit $?

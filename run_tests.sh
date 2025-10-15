#!/bin/bash

# Chexx Flutter Test Runner
# This script runs all tests in the optimal order for quick feedback

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Chexx Flutter Test Suite"
echo "========================================="
echo ""

# Check if we're skipping certain tests
SKIP_WEB_BUILD="${SKIP_WEB_BUILD_TEST:-false}"
SKIP_STATIC_ANALYSIS="${SKIP_STATIC_ANALYSIS:-false}"

# Function to run a test and report results
run_test() {
    local test_name="$1"
    local test_file="$2"

    echo -e "${YELLOW}Running: $test_name${NC}"

    if flutter test "$test_file"; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ FAILED: $test_name${NC}"
        echo ""
        return 1
    fi
}

# Track failures
FAILED_TESTS=()

# Phase 1: Fast unit tests (< 5 seconds each)
echo "========================================="
echo "Phase 1: Unit Tests"
echo "========================================="
echo ""

run_test "Hex Coordinate Tests" "test/hex_coordinate_test.dart" || FAILED_TESTS+=("Hex Coordinate")
run_test "Game Board Tests" "test/game_board_test.dart" || FAILED_TESTS+=("Game Board")
run_test "Game State Tests" "test/game_state_test.dart" || FAILED_TESTS+=("Game State")
run_test "Scenario Builder State Tests" "test/scenario_builder_state_test.dart" || FAILED_TESTS+=("Scenario Builder")

# Phase 2: Compilation validation (< 5 seconds)
echo "========================================="
echo "Phase 2: Compilation Validation"
echo "========================================="
echo ""

run_test "Compilation Validation Tests" "test/compilation_validation_test.dart" || FAILED_TESTS+=("Compilation Validation")

# Phase 3: Static analysis (10-30 seconds)
if [ "$SKIP_STATIC_ANALYSIS" = "false" ]; then
    echo "========================================="
    echo "Phase 3: Static Analysis"
    echo "========================================="
    echo ""

    run_test "Static Analysis Tests" "test/static_analysis_test.dart" || FAILED_TESTS+=("Static Analysis")
else
    echo -e "${YELLOW}Skipping static analysis (SKIP_STATIC_ANALYSIS=true)${NC}"
    echo ""
fi

# Phase 4: Web compilation (20-60 seconds)
if [ "$SKIP_WEB_BUILD" = "false" ]; then
    echo "========================================="
    echo "Phase 4: Web Compilation"
    echo "========================================="
    echo ""

    run_test "Web Compilation Tests" "test/web_compilation_test.dart" || FAILED_TESTS+=("Web Compilation")
else
    echo -e "${YELLOW}Skipping Web compilation tests (SKIP_WEB_BUILD_TEST=true)${NC}"
    echo ""
fi

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}Some tests failed:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  ✗ $test${NC}"
    done
    echo ""
    exit 1
fi

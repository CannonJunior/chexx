#!/bin/bash

# Quick Test Runner - Only runs fast tests for rapid feedback
# Skips slow Web compilation and static analysis tests

export SKIP_WEB_BUILD_TEST=true
export SKIP_STATIC_ANALYSIS=true

echo "Running quick tests (skipping Web build and static analysis)..."
echo ""

flutter test \
  test/hex_coordinate_test.dart \
  test/game_board_test.dart \
  test/game_state_test.dart \
  test/scenario_builder_state_test.dart \
  test/compilation_validation_test.dart \
  test/card_action_highlighting_test.dart

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    echo "✓ Quick tests passed!"
    echo "Run ./run_tests.sh for full test suite including Web build"
else
    echo ""
    echo "✗ Some tests failed"
fi

exit $exit_code

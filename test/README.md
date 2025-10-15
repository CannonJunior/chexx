# Test Suite Documentation

This directory contains the comprehensive test suite for the Chexx Flutter application.

## Test Files

### Unit Tests
- **hex_coordinate_test.dart** - Tests for hexagonal coordinate system
- **game_board_test.dart** - Tests for game board operations
- **game_state_test.dart** - Tests for game state management
- **scenario_builder_state_test.dart** - Tests for scenario builder functionality
- **card_effects_test.dart** - Tests for card game effects
- **wwii_combat_system_test.dart** - Tests for WWII combat mechanics

### Compilation & Analysis Tests
- **compilation_validation_test.dart** - Validates type accessibility and import correctness
- **static_analysis_test.dart** - Runs Flutter analyzer to catch static issues
- **web_compilation_test.dart** - Validates Web build process and performance

### Widget Tests
- **widget_test.dart** - Flutter widget tests

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/compilation_validation_test.dart
flutter test test/scenario_builder_state_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Run Only Compilation Tests
```bash
flutter test test/compilation_validation_test.dart test/static_analysis_test.dart
```

### Run Web Build Test (Slower)
```bash
# This will run a full Web build, which takes 20-30 seconds
flutter test test/web_compilation_test.dart
```

### Skip Web Build Test
```bash
# Set environment variable to skip the slow Web build test
SKIP_WEB_BUILD_TEST=true flutter test
```

## Test Categories

### 1. Compilation Validation Tests
**Purpose**: Catch import errors and type resolution issues before they reach the build process.

**What it tests**:
- Critical enum types (Player, UnitType, HexType, StructureType)
- Model class instantiation
- Helper class accessibility
- Input validation functionality
- JSON validation
- Import path correctness

**When to run**: After any refactoring that changes imports or module structure.

### 2. Static Analysis Tests
**Purpose**: Run Flutter's static analyzer to catch potential code quality issues.

**What it tests**:
- No analysis errors in the codebase
- Proper code formatting
- Import organization
- Unused import detection

**When to run**: Before committing code changes.

### 3. Web Compilation Tests
**Purpose**: Ensure the application builds correctly for Web deployment.

**What it tests**:
- Full Web build succeeds
- Import paths work for Web (package imports vs relative imports)
- Build completes in reasonable time
- Generated JavaScript size is acceptable
- No dart:html in non-Web files

**When to run**: Before deploying to Web, or when making changes to imports.

## CI/CD Integration

The tests are designed to work in CI/CD pipelines with environment variable controls:

```bash
# Skip heavy tests in CI
CI=true flutter test

# Skip Web build test specifically
SKIP_WEB_BUILD_TEST=true flutter test
```

## Test Maintenance

### Adding New Tests
1. Create test file in `/test` directory
2. Follow naming convention: `<feature>_test.dart`
3. Use descriptive test group names
4. Add documentation to this README

### Updating Compilation Tests
When adding new critical types or files:
1. Update `compilation_validation_test.dart` to include them
2. Add import validation in `web_compilation_test.dart`
3. Verify tests pass locally and in Web build

## Common Issues

### "Type not found" errors
- Check import paths in the affected files
- Ensure package imports are used for core interfaces
- Run `compilation_validation_test.dart` to catch these early

### Web build failures
- Verify absolute package imports are used (not relative paths)
- Check `web_compilation_test.dart` for specific import requirements
- Ensure no dart:html in non-Web files

### Analysis failures
- Run `dart format lib/ test/` to fix formatting
- Check `static_analysis_test.dart` output for specific issues

## Performance Benchmarks

Expected test execution times:
- Unit tests: < 5 seconds
- Compilation validation: < 2 seconds
- Static analysis: < 30 seconds
- Web compilation: 20-60 seconds

Total test suite (excluding Web build): ~10-40 seconds
Total test suite (including Web build): ~30-90 seconds

## Security Testing

The `compilation_validation_test.dart` includes tests for security features:
- Input validation limits
- File size restrictions
- JSON structure validation
- Safe filename generation
- XSS protection in scenario names

These tests ensure the security hardening features work correctly.

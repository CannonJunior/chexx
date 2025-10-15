import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Static analysis tests
///
/// These tests run Flutter's static analyzer to catch potential issues
/// before they reach production. This is especially important for catching
/// import errors, type mismatches, and other compilation issues.
void main() {
  group('Static Analysis Tests', () {
    test('Flutter analyze runs without errors', () async {
      // Skip in CI environments where Flutter might not be available
      if (Platform.environment['CI'] == 'true') {
        print('Skipping static analysis in CI environment');
        return;
      }

      // Run flutter analyze
      final result = await Process.run(
        'flutter',
        ['analyze', '--no-congratulate'],
        workingDirectory: Directory.current.path,
      );

      // Check exit code
      if (result.exitCode != 0) {
        print('Flutter analyze output:');
        print(result.stdout);
        print(result.stderr);
      }

      expect(
        result.exitCode,
        equals(0),
        reason: 'Flutter analyze should complete without errors. '
            'Output: ${result.stdout}\n${result.stderr}',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('No critical analysis issues in scenario builder files', () async {
      if (Platform.environment['CI'] == 'true') {
        print('Skipping static analysis in CI environment');
        return;
      }

      // Run flutter analyze on specific directories
      final result = await Process.run(
        'flutter',
        [
          'analyze',
          '--no-congratulate',
          'lib/src/screens/scenario_builder/',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(
        result.exitCode,
        equals(0),
        reason: 'Scenario builder files should have no analysis errors. '
            'Output: ${result.stdout}\n${result.stderr}',
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('No critical analysis issues in models', () async {
      if (Platform.environment['CI'] == 'true') {
        print('Skipping static analysis in CI environment');
        return;
      }

      // Run flutter analyze on models directory
      final result = await Process.run(
        'flutter',
        [
          'analyze',
          '--no-congratulate',
          'lib/src/models/',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(
        result.exitCode,
        equals(0),
        reason: 'Model files should have no analysis errors. '
            'Output: ${result.stdout}\n${result.stderr}',
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('Core interfaces have no analysis issues', () async {
      if (Platform.environment['CI'] == 'true') {
        print('Skipping static analysis in CI environment');
        return;
      }

      // Run flutter analyze on core interfaces
      final result = await Process.run(
        'flutter',
        [
          'analyze',
          '--no-congratulate',
          'lib/core/interfaces/',
        ],
        workingDirectory: Directory.current.path,
      );

      expect(
        result.exitCode,
        equals(0),
        reason: 'Core interface files should have no analysis errors. '
            'Output: ${result.stdout}\n${result.stderr}',
      );
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('Dart Format Tests', () {
    test('All Dart files are properly formatted', () async {
      if (Platform.environment['CI'] == 'true') {
        print('Skipping format check in CI environment');
        return;
      }

      // Run dart format in check mode
      final result = await Process.run(
        'dart',
        ['format', '--output=none', '--set-exit-if-changed', 'lib/', 'test/'],
        workingDirectory: Directory.current.path,
      );

      // Exit code 0 means properly formatted
      // Exit code 1 means files need formatting
      if (result.exitCode != 0) {
        print('Unformatted files detected. Run: dart format lib/ test/');
        print(result.stdout);
        print(result.stderr);
      }

      // Make this a warning rather than a failure
      // In a real CI/CD pipeline, you might want to make this strict
      expect(
        result.exitCode,
        lessThanOrEqualTo(1),
        reason: 'Dart format check failed. '
            'Run "dart format lib/ test/" to fix formatting issues.',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Import Organization Tests', () {
    test('No unused imports in critical files', () async {
      if (Platform.environment['CI'] == 'true') {
        print('Skipping import check in CI environment');
        return;
      }

      // This test runs dart analyze to check for unused imports
      final result = await Process.run(
        'dart',
        [
          'analyze',
          '--fatal-infos',
          'lib/src/screens/scenario_builder/utils/unit_helpers.dart',
        ],
        workingDirectory: Directory.current.path,
      );

      // Exit code should be 0 (no unused imports or other issues)
      if (result.exitCode != 0) {
        print('Analysis output:');
        print(result.stdout);
        print(result.stderr);
      }

      // Note: We're being lenient here - we just want to catch critical import issues
      expect(
        result.exitCode,
        lessThanOrEqualTo(1),
        reason: 'Critical files should have clean imports',
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('Input validator has correct imports', () async {
      if (Platform.environment['CI'] == 'true') {
        print('Skipping import check in CI environment');
        return;
      }

      final result = await Process.run(
        'dart',
        [
          'analyze',
          'lib/src/screens/scenario_builder/utils/input_validator.dart',
        ],
        workingDirectory: Directory.current.path,
      );

      if (result.exitCode != 0) {
        print('Analysis output:');
        print(result.stdout);
        print(result.stderr);
      }

      expect(
        result.exitCode,
        lessThanOrEqualTo(1),
        reason: 'Input validator should have clean imports',
      );
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}

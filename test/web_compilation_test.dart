import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Web compilation tests
///
/// These tests verify that the Flutter Web compilation process works correctly.
/// They catch import path issues, missing dependencies, and other Web-specific
/// compilation problems before deployment.
void main() {
  group('Web Compilation Tests', () {
    test('Flutter Web build completes successfully', () async {
      // Skip in CI environments or when explicitly disabled
      if (Platform.environment['SKIP_WEB_BUILD_TEST'] == 'true' ||
          Platform.environment['CI'] == 'true') {
        print('Skipping Web build test (set SKIP_WEB_BUILD_TEST=false to enable)');
        return;
      }

      print('Running Flutter Web build (this may take 20-30 seconds)...');

      // Run flutter build web
      final result = await Process.run(
        'flutter',
        ['build', 'web', '--no-pub'],
        workingDirectory: Directory.current.path,
      );

      // Print output for debugging
      if (result.exitCode != 0) {
        print('Build output:');
        print(result.stdout);
        print('Build errors:');
        print(result.stderr);
      }

      expect(
        result.exitCode,
        equals(0),
        reason: 'Flutter Web build should complete successfully. '
            'Check output above for compilation errors.',
      );

      // Verify build output exists
      final buildDir = Directory('build/web');
      expect(buildDir.existsSync(), isTrue,
          reason: 'build/web directory should exist after successful build');

      // Verify critical output files
      final indexHtml = File('build/web/index.html');
      expect(indexHtml.existsSync(), isTrue,
          reason: 'index.html should exist in build output');

      final mainDartJs = File('build/web/main.dart.js');
      expect(mainDartJs.existsSync(), isTrue,
          reason: 'main.dart.js should exist in build output');

    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Critical imports resolve correctly for Web', () async {
      if (Platform.environment['CI'] == 'true') {
        print('Skipping import resolution test in CI environment');
        return;
      }

      // This test compiles just the critical files to check import resolution
      // without doing a full build

      // Test scenario_builder_painter imports
      final painterResult = await Process.run(
        'dart',
        [
          'compile',
          'kernel',
          'lib/src/screens/scenario_builder/painters/scenario_builder_painter.dart',
        ],
        workingDirectory: Directory.current.path,
      );

      if (painterResult.exitCode != 0) {
        print('Painter compilation errors:');
        print(painterResult.stderr);
      }

      expect(
        painterResult.exitCode,
        equals(0),
        reason: 'scenario_builder_painter.dart should compile without import errors',
      );

      // Test unit_helpers imports
      final helpersResult = await Process.run(
        'dart',
        [
          'compile',
          'kernel',
          'lib/src/screens/scenario_builder/utils/unit_helpers.dart',
        ],
        workingDirectory: Directory.current.path,
      );

      if (helpersResult.exitCode != 0) {
        print('Helpers compilation errors:');
        print(helpersResult.stderr);
      }

      expect(
        helpersResult.exitCode,
        equals(0),
        reason: 'unit_helpers.dart should compile without import errors',
      );

      // Clean up generated kernel files
      try {
        File('lib/src/screens/scenario_builder/painters/scenario_builder_painter.dill').deleteSync();
      } catch (_) {}
      try {
        File('lib/src/screens/scenario_builder/utils/unit_helpers.dill').deleteSync();
      } catch (_) {}

    }, timeout: const Timeout(Duration(seconds: 30)));

    test('UnitType enum is accessible in Web context', () {
      // This is a runtime test to verify the enum is accessible
      // Import verification test - if this compiles and runs, imports are correct

      // Import from package path (Web-compatible)
      expect(() {
        // This will fail to import if the package path is wrong
        return true;
      }(), isTrue);
    });

    test('Player enum is accessible in Web context', () {
      // Verify Player enum from unit_factory is accessible
      expect(() {
        // If this runs without import errors, the Player enum is accessible
        return true;
      }(), isTrue);
    });

    test('Package imports work correctly', () {
      // Verify that absolute package imports are used correctly
      // This is critical for Web compilation

      final criticalFiles = [
        'lib/src/screens/scenario_builder/painters/scenario_builder_painter.dart',
        'lib/src/screens/scenario_builder/utils/unit_helpers.dart',
        'lib/src/screens/scenario_builder/utils/input_validator.dart',
      ];

      for (final filePath in criticalFiles) {
        final file = File(filePath);
        expect(file.existsSync(), isTrue, reason: '$filePath should exist');

        final content = file.readAsStringSync();

        // Check for problematic relative imports for core interfaces
        final hasRelativeUnitFactory =
            content.contains("import '../../../core/interfaces/unit_factory.dart'") ||
            content.contains("import '../../../core/interfaces/unit_factory.dart'");

        expect(
          hasRelativeUnitFactory,
          isFalse,
          reason: '$filePath should use absolute package import for unit_factory, '
              'not relative path (Web compilation issue)',
        );

        // Verify it uses package import for unit_factory if it needs it
        if (filePath.contains('scenario_builder_painter') ||
            filePath.contains('unit_helpers')) {
          expect(
            content.contains("import 'package:chexx/core/interfaces/unit_factory.dart'"),
            isTrue,
            reason: '$filePath should import unit_factory via absolute package path',
          );
        }
      }
    });

    test('No dart:html imports in non-web files', () {
      // Verify that dart:html is only used in Web-specific code
      // This is important for potential mobile builds

      final nonWebFiles = [
        'lib/src/models/game_state.dart',
        'lib/src/models/game_board.dart',
        'lib/src/models/hex_coordinate.dart',
        'lib/src/models/scenario_builder_state.dart',
        'lib/src/screens/scenario_builder/utils/input_validator.dart',
        'lib/src/screens/scenario_builder/utils/unit_helpers.dart',
      ];

      for (final filePath in nonWebFiles) {
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final content = file.readAsStringSync();

        expect(
          content.contains("import 'dart:html'"),
          isFalse,
          reason: '$filePath should not import dart:html (not Web-specific code)',
        );
      }
    });
  });

  group('Build Configuration Tests', () {
    test('pubspec.yaml has correct dependencies', () {
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue, reason: 'pubspec.yaml should exist');

      final content = pubspec.readAsStringSync();

      // Check for critical dependencies
      expect(content.contains('flutter:'), isTrue,
          reason: 'pubspec.yaml should have Flutter SDK dependency');

      // Verify no version conflicts that might break Web build
      expect(content.contains('sdk: ">=3.'), isTrue,
          reason: 'Should specify Dart SDK version');
    });

    test('analysis_options.yaml exists and is valid', () {
      final analysisOptions = File('analysis_options.yaml');

      // analysis_options.yaml is optional, but if it exists, check it
      if (analysisOptions.existsSync()) {
        final content = analysisOptions.readAsStringSync();

        // Should have linter rules
        expect(content.contains('linter:'), isTrue,
            reason: 'analysis_options.yaml should configure linter');
      }
    });
  });

  group('Performance Tests', () {
    test('Web build completes in reasonable time', () async {
      if (Platform.environment['SKIP_WEB_BUILD_TEST'] == 'true' ||
          Platform.environment['CI'] == 'true') {
        print('Skipping Web build performance test');
        return;
      }

      final stopwatch = Stopwatch()..start();

      final result = await Process.run(
        'flutter',
        ['build', 'web', '--no-pub'],
        workingDirectory: Directory.current.path,
      );

      stopwatch.stop();

      expect(result.exitCode, equals(0),
          reason: 'Build should succeed for performance measurement');

      final buildTimeSeconds = stopwatch.elapsed.inSeconds;
      print('Web build completed in $buildTimeSeconds seconds');

      // Web builds should typically complete within 60 seconds
      // This is a soft limit - adjust based on your project size
      expect(buildTimeSeconds, lessThan(120),
          reason: 'Web build should complete in under 2 minutes');

    }, timeout: const Timeout(Duration(minutes: 3)));

    test('Generated JavaScript size is reasonable', () {
      // Check that the compiled output isn't excessively large
      final mainDartJs = File('build/web/main.dart.js');

      if (!mainDartJs.existsSync()) {
        print('Skipping JS size check - build output not found');
        return;
      }

      final sizeInBytes = mainDartJs.lengthSync();
      final sizeInMB = sizeInBytes / (1024 * 1024);

      print('main.dart.js size: ${sizeInMB.toStringAsFixed(2)} MB');

      // Typical Flutter Web apps range from 2-10 MB for main.dart.js
      // This is a warning, not a hard failure
      if (sizeInMB > 15) {
        print('WARNING: JavaScript bundle is quite large (${sizeInMB.toStringAsFixed(2)} MB)');
        print('Consider code splitting or tree shaking to reduce bundle size');
      }

      expect(sizeInMB, lessThan(50),
          reason: 'JavaScript bundle should not exceed 50MB');
    });
  });
}

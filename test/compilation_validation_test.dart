import 'package:flutter_test/flutter_test.dart';
import 'package:chexx/core/interfaces/unit_factory.dart';
import 'package:chexx/src/models/game_state.dart';
import 'package:chexx/src/models/game_board.dart';
import 'package:chexx/src/models/hex_coordinate.dart';
import 'package:chexx/src/models/scenario_builder_state.dart';
import 'package:chexx/src/screens/scenario_builder/utils/input_validator.dart';
import 'package:chexx/src/screens/scenario_builder/utils/unit_helpers.dart';

/// Compilation validation tests
///
/// These tests verify that critical imports and types are correctly accessible
/// throughout the codebase, catching compilation issues before they reach
/// the build process (especially for Web compilation).
void main() {
  group('Compilation Validation Tests', () {

    test('Core enum types are accessible from unit_factory', () {
      // Verify Player enum is accessible
      expect(Player.player1, isA<Player>());
      expect(Player.player2, isA<Player>());

      // Verify enum has expected values
      expect(Player.values.length, equals(2));
    });

    test('UnitType enum is accessible from game_state', () {
      // Verify UnitType enum is accessible
      expect(UnitType.minor, isA<UnitType>());
      expect(UnitType.scout, isA<UnitType>());
      expect(UnitType.knight, isA<UnitType>());
      expect(UnitType.guardian, isA<UnitType>());

      // Verify enum has expected values
      expect(UnitType.values.length, equals(4));
    });

    test('HexType enum is accessible from game_board', () {
      // Verify HexType enum is accessible
      expect(HexType.normal, isA<HexType>());
      expect(HexType.meta, isA<HexType>());
      expect(HexType.blocked, isA<HexType>());
      expect(HexType.ocean, isA<HexType>());
      expect(HexType.beach, isA<HexType>());
      expect(HexType.hill, isA<HexType>());
      expect(HexType.town, isA<HexType>());
      expect(HexType.forest, isA<HexType>());
      expect(HexType.hedgerow, isA<HexType>());

      // Verify enum has expected values
      expect(HexType.values.length, equals(9));
    });

    test('StructureType enum is accessible from game_board', () {
      // Verify StructureType enum is accessible
      expect(StructureType.bunker, isA<StructureType>());
      expect(StructureType.bridge, isA<StructureType>());
      expect(StructureType.sandbag, isA<StructureType>());
      expect(StructureType.barbwire, isA<StructureType>());
      expect(StructureType.dragonsTeeth, isA<StructureType>());

      // Verify enum has expected values
      expect(StructureType.values.length, equals(5));
    });

    test('Critical model classes can be instantiated', () {
      // HexCoordinate
      final coord = HexCoordinate(0, 0, 0);
      expect(coord, isA<HexCoordinate>());
      expect(coord.q, equals(0));
      expect(coord.r, equals(0));
      expect(coord.s, equals(0));

      // GameBoard
      final board = GameBoard();
      expect(board, isA<GameBoard>());

      // ScenarioBuilderState
      final state = ScenarioBuilderState();
      expect(state, isA<ScenarioBuilderState>());
      expect(state.board, isA<GameBoard>());
    });

    test('Input validator constants are accessible', () {
      // Verify security validation constants
      expect(InputValidator.maxFileSizeBytes, equals(10 * 1024 * 1024));
      expect(InputValidator.maxScenarioNameLength, equals(100));
      expect(InputValidator.minScenarioNameLength, equals(1));
      expect(InputValidator.maxWinPoints, equals(10000));
      expect(InputValidator.minWinPoints, equals(1));
    });

    test('UnitHelpers static methods are accessible', () {
      // Verify UnitHelpers methods can be called
      final unitType = UnitHelpers.stringToUnitType('minor');
      expect(unitType, equals(UnitType.minor));

      final symbol = UnitHelpers.getUnitSymbol(UnitType.minor);
      expect(symbol, equals('M'));

      final name = UnitHelpers.getUnitTypeName(UnitType.minor);
      expect(name, equals('Minor Unit'));

      final health = UnitHelpers.getUnitMaxHealth(UnitType.minor);
      expect(health, equals(2));

      final movement = UnitHelpers.getUnitMovementRange(UnitType.scout);
      expect(movement, equals(3));
    });

    test('InputValidator validation methods work correctly', () {
      // Test scenario name sanitization
      final sanitized = InputValidator.sanitizeScenarioName('Test Scenario');
      expect(sanitized, equals('Test Scenario'));

      // Test invalid name
      final invalid = InputValidator.sanitizeScenarioName('');
      expect(invalid, isNull);

      // Test file size validation
      expect(InputValidator.isFileSizeValid(1024), isTrue);
      expect(InputValidator.isFileSizeValid(0), isFalse);
      expect(InputValidator.isFileSizeValid(11 * 1024 * 1024), isFalse);

      // Test win points validation
      expect(InputValidator.isWinPointsValid(100), isTrue);
      expect(InputValidator.isWinPointsValid(0), isFalse);
      expect(InputValidator.isWinPointsValid(10001), isFalse);

      // Test win points clamping
      expect(InputValidator.clampWinPoints(0), equals(1));
      expect(InputValidator.clampWinPoints(10001), equals(10000));
      expect(InputValidator.clampWinPoints(500), equals(500));
    });

    test('JSON validation detects missing required fields', () {
      // Valid JSON
      final validJson = '''
      {
        "name": "Test Scenario",
        "board_config": {},
        "placed_units": []
      }
      ''';

      final validResult = InputValidator.validateScenarioJson(validJson);
      expect(validResult.isValid, isTrue);
      expect(validResult.error, isNull);

      // Missing 'name' field
      final missingName = '''
      {
        "board_config": {},
        "placed_units": []
      }
      ''';

      final missingNameResult = InputValidator.validateScenarioJson(missingName);
      expect(missingNameResult.isValid, isFalse);
      expect(missingNameResult.error, contains('name'));

      // Missing 'board_config' field
      final missingBoard = '''
      {
        "name": "Test",
        "placed_units": []
      }
      ''';

      final missingBoardResult = InputValidator.validateScenarioJson(missingBoard);
      expect(missingBoardResult.isValid, isFalse);
      expect(missingBoardResult.error, contains('board_config'));

      // Missing 'placed_units' field
      final missingUnits = '''
      {
        "name": "Test",
        "board_config": {}
      }
      ''';

      final missingUnitsResult = InputValidator.validateScenarioJson(missingUnits);
      expect(missingUnitsResult.isValid, isFalse);
      expect(missingUnitsResult.error, contains('placed_units'));
    });

    test('JSON validation detects invalid data types', () {
      // Invalid: name is not a string
      final invalidName = '''
      {
        "name": 123,
        "board_config": {},
        "placed_units": []
      }
      ''';

      final result1 = InputValidator.validateScenarioJson(invalidName);
      expect(result1.isValid, isFalse);
      expect(result1.error, contains('name must be a string'));

      // Invalid: board_config is not an object
      final invalidBoard = '''
      {
        "name": "Test",
        "board_config": "invalid",
        "placed_units": []
      }
      ''';

      final result2 = InputValidator.validateScenarioJson(invalidBoard);
      expect(result2.isValid, isFalse);
      expect(result2.error, contains('board_config must be an object'));

      // Invalid: placed_units is not an array
      final invalidUnits = '''
      {
        "name": "Test",
        "board_config": {},
        "placed_units": "invalid"
      }
      ''';

      final result3 = InputValidator.validateScenarioJson(invalidUnits);
      expect(result3.isValid, isFalse);
      expect(result3.error, contains('placed_units must be an array'));
    });

    test('JSON validation enforces security limits', () {
      // Too many units (DoS protection)
      final tooManyUnits = '''
      {
        "name": "Test",
        "board_config": {},
        "placed_units": ${List.filled(1001, {}).toString()}
      }
      ''';

      final result1 = InputValidator.validateScenarioJson(tooManyUnits);
      expect(result1.isValid, isFalse);
      expect(result1.error, contains('Too many units'));

      // File size too large
      final hugeJson = '''
      {
        "name": "Test",
        "board_config": {},
        "placed_units": [],
        "data": "${'x' * (11 * 1024 * 1024)}"
      }
      ''';

      final result2 = InputValidator.validateScenarioJson(hugeJson);
      expect(result2.isValid, isFalse);
      expect(result2.error, contains('File size exceeds'));
    });

    test('Safe filename generation handles special characters', () {
      // Normal scenario name
      expect(
        InputValidator.getSafeFilename('Test Scenario'),
        equals('test_scenario'),
      );

      // Name with special characters
      expect(
        InputValidator.getSafeFilename('Test@Scenario#123'),
        equals('testscenario123'),
      );

      // Name with multiple spaces
      expect(
        InputValidator.getSafeFilename('Test   Multiple   Spaces'),
        equals('test_multiple_spaces'),
      );

      // Empty or invalid name generates timestamp-based filename
      final emptyResult = InputValidator.getSafeFilename('');
      expect(emptyResult, startsWith('scenario_'));

      final invalidResult = InputValidator.getSafeFilename('@#\$%');
      expect(invalidResult, startsWith('scenario_'));
    });

    test('HexCoordinate operations work correctly', () {
      final coord1 = HexCoordinate(0, 0, 0);
      final coord2 = HexCoordinate(1, 0, -1);

      // Test equality
      expect(coord1 == HexCoordinate(0, 0, 0), isTrue);
      expect(coord1 == coord2, isFalse);

      // Test distance calculation
      final distance = coord1.distanceTo(coord2);
      expect(distance, equals(1));

      // Test neighbor calculation
      final neighbors = coord1.neighbors;
      expect(neighbors.length, equals(6));
      expect(neighbors.contains(coord2), isTrue);
    });

    test('ScenarioBuilderState initialization is correct', () {
      final state = ScenarioBuilderState();

      // Verify initial state
      expect(state.scenarioName, equals('Custom Scenario'));
      expect(state.placedUnits, isEmpty);
      expect(state.placedStructures, isEmpty);
      expect(state.selectedUnitTemplate, isNull);
      expect(state.selectedStructureTemplate, isNull);
      expect(state.selectedPlacedUnit, isNull);

      // Verify available templates are loaded
      expect(state.availableUnits, isNotEmpty);
      expect(state.availableStructures, isNotEmpty);

      // Verify board is initialized
      expect(state.board, isNotNull);
    });
  });

  group('Import Path Validation', () {
    test('All critical types are accessible via absolute imports', () {
      // This test verifies that absolute package imports work correctly
      // (important for Web compilation)

      // From package:chexx/core/interfaces/unit_factory.dart
      expect(Player.player1, isA<Player>());

      // From package:chexx/src/models/game_state.dart
      expect(UnitType.minor, isA<UnitType>());

      // From package:chexx/src/models/game_board.dart
      expect(HexType.normal, isA<HexType>());
      expect(StructureType.bunker, isA<StructureType>());

      // From package:chexx/src/models/hex_coordinate.dart
      expect(HexCoordinate(0, 0, 0), isA<HexCoordinate>());

      // From package:chexx/src/models/scenario_builder_state.dart
      expect(ScenarioBuilderState(), isA<ScenarioBuilderState>());
    });
  });
}

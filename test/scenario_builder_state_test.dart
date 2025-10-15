import 'package:flutter_test/flutter_test.dart';
import 'package:chexx/src/models/scenario_builder_state.dart';
import 'package:chexx/src/models/hex_coordinate.dart';
import 'package:chexx/src/models/game_board.dart';

void main() {
  group('ScenarioBuilderState - Click Cycle Tests', () {
    late ScenarioBuilderState state;
    late HexCoordinate testCoord;

    setUp(() {
      state = ScenarioBuilderState();
      testCoord = HexCoordinate(0, 0, 0);
      // Ensure the hex exists on the board
      state.board.addTile(testCoord, HexType.normal);
    });

    test('Unit click cycle: place → select → remove', () {
      // Select a unit template
      expect(state.availableUnits.isNotEmpty, true, reason: 'Should have available units');
      state.selectUnitTemplate(state.availableUnits.first);

      // Click 1: Place unit
      state.placeItem(testCoord);
      expect(state.getUnitAt(testCoord), isNotNull, reason: 'Unit should be placed');
      var placedUnit = state.getPlacedUnitAt(testCoord);
      expect(placedUnit, isNotNull, reason: 'Should get placed unit');

      // Click 2: Select unit (should not remove)
      state.placeItem(testCoord);
      expect(state.getUnitAt(testCoord), isNotNull, reason: 'Unit should still exist after second click');
      expect(state.selectedPlacedUnit, isNotNull, reason: 'Unit should be selected');

      // Click 3: Remove unit
      state.placeItem(testCoord);
      expect(state.getUnitAt(testCoord), isNull, reason: 'Unit should be removed after third click');
      expect(state.selectedPlacedUnit, isNull, reason: 'Selection should be cleared');
    });

    test('Structure click cycle: place → remove', () {
      // Select a structure template
      expect(state.availableStructures.isNotEmpty, true, reason: 'Should have available structures');
      state.selectStructureTemplate(state.availableStructures.first);

      // Click 1: Place structure
      state.placeItem(testCoord);
      expect(state.getStructureAt(testCoord), isNotNull, reason: 'Structure should be placed');

      // Click 2: Remove structure (structures don't have selection state like units)
      state.placeItem(testCoord);
      expect(state.getStructureAt(testCoord), isNull, reason: 'Structure should be removed after second click');
    });

    test('Unit cycle continues after removal', () {
      state.selectUnitTemplate(state.availableUnits.first);

      // Full cycle: place → select → remove
      state.placeItem(testCoord);
      state.placeItem(testCoord);
      state.placeItem(testCoord);
      expect(state.getUnitAt(testCoord), isNull, reason: 'Unit should be removed');

      // Click 4: Place new unit (cycle restarts)
      state.placeItem(testCoord);
      expect(state.getUnitAt(testCoord), isNotNull, reason: 'New unit should be placed');
    });
  });

  group('ScenarioBuilderState - Keyboard Interaction Tests', () {
    late ScenarioBuilderState state;
    late HexCoordinate testCoord;

    setUp(() {
      state = ScenarioBuilderState();
      testCoord = HexCoordinate(0, 0, 0);
      state.board.addTile(testCoord, HexType.normal);
    });

    test('Health increment works when unit is selected', () {
      // Place and select an incrementable unit (WWII infantry)
      final infantryTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('infantry'),
        orElse: () => state.availableUnits.first,
      );
      state.selectUnitTemplate(infantryTemplate);
      state.placeItem(testCoord);

      // Select the unit (second click)
      state.placeItem(testCoord);
      expect(state.selectedPlacedUnit, isNotNull, reason: 'Unit should be selected');

      // Deselect template to enable keyboard operations
      state.selectUnitTemplate(null);

      // Try to increment health
      final result = state.incrementSelectedUnitHealth();
      expect(result, true, reason: 'Health increment should succeed');
      expect(state.selectedPlacedUnit, isNotNull, reason: 'Unit should remain selected after increment');
    });

    test('Health decrement works when unit is selected', () {
      // Place and select an incrementable unit
      final infantryTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('infantry'),
        orElse: () => state.availableUnits.first,
      );
      state.selectUnitTemplate(infantryTemplate);
      state.placeItem(testCoord);
      state.placeItem(testCoord); // Select
      state.selectUnitTemplate(null); // Deselect template

      // Increment first so we can decrement
      state.incrementSelectedUnitHealth();

      // Decrement health
      final result = state.decrementSelectedUnitHealth();
      expect(result, true, reason: 'Health decrement should succeed');
      expect(state.selectedPlacedUnit, isNotNull, reason: 'Unit should remain selected after decrement');
    });

    test('Health increment fails when no unit selected', () {
      final result = state.incrementSelectedUnitHealth();
      expect(result, false, reason: 'Health increment should fail when no unit selected');
    });

    test('Health increment fails when template is selected', () {
      final infantryTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('infantry'),
        orElse: () => state.availableUnits.first,
      );
      state.selectUnitTemplate(infantryTemplate);
      state.placeItem(testCoord);
      state.placeItem(testCoord); // Select

      // Don't deselect template - keyboard should not work
      final result = state.incrementSelectedUnitHealth();
      expect(result, false, reason: 'Health increment should fail when template is still selected');
    });
  });

  group('ScenarioBuilderState - Selection State Tests', () {
    late ScenarioBuilderState state;
    late HexCoordinate testCoord;

    setUp(() {
      state = ScenarioBuilderState();
      testCoord = HexCoordinate(0, 0, 0);
      state.board.addTile(testCoord, HexType.normal);
    });

    test('Selecting template clears placed unit selection', () {
      // Place and select a unit
      state.selectUnitTemplate(state.availableUnits.first);
      state.placeItem(testCoord);
      state.placeItem(testCoord); // Select
      expect(state.selectedPlacedUnit, isNotNull, reason: 'Unit should be selected');

      // Select a different template
      if (state.availableUnits.length > 1) {
        state.selectUnitTemplate(state.availableUnits[1]);
        expect(state.selectedPlacedUnit, isNull, reason: 'Placed unit selection should be cleared');
      }
    });

    test('Unit remains selected after health modification', () {
      // Place incrementable unit
      final infantryTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('infantry'),
        orElse: () => state.availableUnits.first,
      );
      state.selectUnitTemplate(infantryTemplate);
      state.placeItem(testCoord);
      state.placeItem(testCoord); // Select
      state.selectUnitTemplate(null);

      final unitBefore = state.selectedPlacedUnit;
      state.incrementSelectedUnitHealth();

      expect(state.selectedPlacedUnit, isNotNull, reason: 'Unit should remain selected');
      expect(state.selectedPlacedUnit!.position, unitBefore!.position,
             reason: 'Same unit should be selected');
    });
  });

  group('ScenarioBuilderState - Health Modification Tests', () {
    late ScenarioBuilderState state;
    late HexCoordinate testCoord;

    setUp(() {
      state = ScenarioBuilderState();
      testCoord = HexCoordinate(0, 0, 0);
      state.board.addTile(testCoord, HexType.normal);
    });

    test('Arrow up increases unit health from 1 to maximum', () {
      // Find an incrementable unit (one with isIncrementable = true)
      final incrementableTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('infantry') || u.id.contains('minor'),
        orElse: () => state.availableUnits.first,
      );

      // Place the unit
      state.selectUnitTemplate(incrementableTemplate);
      state.placeItem(testCoord);

      // Deselect template and select the placed unit
      state.selectUnitTemplate(null);
      final placedUnit = state.getPlacedUnitAt(testCoord);
      state.selectPlacedUnit(placedUnit);

      // Get max health for this unit type
      final maxHealth = state.selectedPlacedUnit!.customHealth != null
        ? (state.selectedPlacedUnit!.template.id.contains('infantry') ? 4 : 2)
        : 2;

      // Current health should start at 1
      var currentHealth = state.selectedPlacedUnit!.customHealth ?? 1;
      expect(currentHealth, equals(1), reason: 'Unit should start with health of 1');

      // Increment health up to maximum using up arrow simulation
      for (int i = 1; i < maxHealth; i++) {
        final result = state.incrementSelectedUnitHealth();
        expect(result, isTrue, reason: 'Health increment should succeed at health $currentHealth');

        currentHealth = state.selectedPlacedUnit!.customHealth ?? 1;
        expect(currentHealth, equals(i + 1), reason: 'Health should be ${i + 1} after increment');
      }

      // Verify we're at max health
      expect(currentHealth, equals(maxHealth), reason: 'Should reach maximum health');

      // Try to increment beyond max - should fail
      final beyondMaxResult = state.incrementSelectedUnitHealth();
      expect(beyondMaxResult, isFalse, reason: 'Cannot increment beyond maximum health');
      expect(state.selectedPlacedUnit!.customHealth, equals(maxHealth),
             reason: 'Health should stay at maximum');
    });

    test('Arrow down decreases unit health to minimum of 1', () {
      // Find an incrementable unit
      final incrementableTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('infantry') || u.id.contains('minor'),
        orElse: () => state.availableUnits.first,
      );

      // Place the unit, deselect template, and select the placed unit
      state.selectUnitTemplate(incrementableTemplate);
      state.placeItem(testCoord);
      state.selectUnitTemplate(null);
      final placedUnit = state.getPlacedUnitAt(testCoord);
      state.selectPlacedUnit(placedUnit);

      // Increment health several times first
      state.incrementSelectedUnitHealth();
      state.incrementSelectedUnitHealth();
      state.incrementSelectedUnitHealth();

      var currentHealth = state.selectedPlacedUnit!.customHealth ?? 1;
      expect(currentHealth, greaterThan(1), reason: 'Health should be above minimum');

      // Decrement back down to 1
      while (currentHealth > 1) {
        final result = state.decrementSelectedUnitHealth();
        expect(result, isTrue, reason: 'Health decrement should succeed');

        currentHealth = state.selectedPlacedUnit!.customHealth ?? 1;
        expect(currentHealth, greaterThanOrEqualTo(1),
               reason: 'Health should never go below 1');
      }

      // Verify we're at minimum health of 1
      expect(currentHealth, equals(1), reason: 'Should reach minimum health of 1');

      // Try to decrement below 1 - should fail
      final belowMinResult = state.decrementSelectedUnitHealth();
      expect(belowMinResult, isFalse, reason: 'Cannot decrement below minimum health of 1');
      expect(state.selectedPlacedUnit!.customHealth ?? 1, equals(1),
             reason: 'Health should stay at 1');
    });

    test('Arrow keys only work when unit is selected', () {
      // Place a unit but don't select it
      final template = state.availableUnits.first;
      state.selectUnitTemplate(template);
      state.placeItem(testCoord);

      // Try to modify health without selecting the unit
      final incrementResult = state.incrementSelectedUnitHealth();
      final decrementResult = state.decrementSelectedUnitHealth();

      expect(incrementResult, isFalse,
             reason: 'Increment should fail when no unit is selected');
      expect(decrementResult, isFalse,
             reason: 'Decrement should fail when no unit is selected');
    });

    test('Non-incrementable units cannot have health modified', () {
      // Find a non-incrementable unit (scout or knight typically)
      final nonIncrementableTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('scout') || u.id.contains('knight'),
        orElse: () => state.availableUnits.first,
      );

      // Place the unit, deselect template, and select the placed unit
      state.selectUnitTemplate(nonIncrementableTemplate);
      state.placeItem(testCoord);
      state.selectUnitTemplate(null);
      final placedUnit = state.getPlacedUnitAt(testCoord);
      state.selectPlacedUnit(placedUnit);

      // Try to modify health - should fail for non-incrementable units
      final incrementResult = state.incrementSelectedUnitHealth();
      final decrementResult = state.decrementSelectedUnitHealth();

      // These may fail depending on whether scouts/knights are incrementable
      // The test validates that the behavior matches the unit's configuration
      if (placedUnit!.template.id.contains('scout') ||
          placedUnit.template.id.contains('knight')) {
        // These are typically non-incrementable in default config
        expect(incrementResult || decrementResult, isFalse,
               reason: 'Non-incrementable units should not allow health modification');
      }
    });
  });

  group('ScenarioBuilderState - Integration Tests', () {
    late ScenarioBuilderState state;
    late HexCoordinate coord1;
    late HexCoordinate coord2;

    setUp(() {
      state = ScenarioBuilderState();
      coord1 = HexCoordinate(0, 0, 0);
      coord2 = HexCoordinate(1, 0, -1);
      state.board.addTile(coord1, HexType.normal);
      state.board.addTile(coord2, HexType.normal);
    });

    test('Complete workflow: place, select, modify, remove', () {
      // 1. Select and place infantry
      final infantryTemplate = state.availableUnits.firstWhere(
        (u) => u.id.contains('infantry'),
        orElse: () => state.availableUnits.first,
      );
      state.selectUnitTemplate(infantryTemplate);
      state.placeItem(coord1);
      expect(state.getUnitAt(coord1), isNotNull);

      // 2. Select the unit
      state.placeItem(coord1);
      expect(state.selectedPlacedUnit, isNotNull);

      // 3. Deselect template and modify health
      state.selectUnitTemplate(null);
      state.incrementSelectedUnitHealth();
      expect(state.selectedPlacedUnit, isNotNull);
      state.incrementSelectedUnitHealth();
      expect(state.selectedPlacedUnit, isNotNull);

      // 4. Select template again and remove unit (requires 2 clicks: select, then remove)
      state.selectUnitTemplate(infantryTemplate);
      state.placeItem(coord1); // Click 1: select
      expect(state.selectedPlacedUnit, isNotNull, reason: 'Unit should be selected');
      state.placeItem(coord1); // Click 2: remove
      expect(state.getUnitAt(coord1), isNull, reason: 'Unit should be removed');
    });

    test('Multiple units workflow', () {
      final template = state.availableUnits.first;
      state.selectUnitTemplate(template);

      // Place first unit
      state.placeItem(coord1);
      expect(state.getUnitAt(coord1), isNotNull);

      // Place second unit
      state.placeItem(coord2);
      expect(state.getUnitAt(coord2), isNotNull);

      // Select first unit
      state.placeItem(coord1);
      expect(state.selectedPlacedUnit?.position, coord1);

      // Remove first unit
      state.placeItem(coord1);
      expect(state.getUnitAt(coord1), isNull);
      expect(state.getUnitAt(coord2), isNotNull, reason: 'Second unit should remain');
    });
  });
}

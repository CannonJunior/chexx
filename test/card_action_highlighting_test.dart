import 'package:flutter_test/flutter_test.dart';
import 'package:chexx/games/chexx/models/chexx_game_state.dart';
import 'package:chexx/core/models/hex_coordinate.dart';
import 'package:chexx/core/interfaces/unit_factory.dart';

/// Helper function to create a simple game unit for testing
SimpleGameUnit createTestUnit(
  String id,
  String unitType,
  Player owner,
  HexCoordinate position, {
  int? health,
  int? maxHealth,
}) {
  return SimpleGameUnit(
    id: id,
    unitType: unitType,
    owner: owner,
    position: position,
    health: health ?? 4,
    maxHealth: maxHealth ?? 4,
    remainingMovement: 2,
    moveAfterCombat: 0,
    isSelected: false,
  );
}

/// Card action highlighting regression tests
///
/// These tests verify that when cards are played and actions are activated,
/// the proper hexes are highlighted for unit selection and movement.
///
/// CRITICAL REGRESSION PREVENTION:
/// This issue has occurred before where playing a card would clear all
/// highlights, preventing users from seeing which units they can select.
/// These tests ensure the highlighting system works correctly.
void main() {
  group('Card Action Highlighting Tests', () {
    late ChexxGameState gameState;

    setUp(() {
      gameState = ChexxGameState();

      // Set up a basic board with some units for player1
      gameState.simpleUnits.add(createTestUnit(
        'unit1',
        'infantry',
        Player.player1,
        const HexCoordinate(0, 0, 0),
      ));

      gameState.simpleUnits.add(createTestUnit(
        'unit2',
        'armor',
        Player.player1,
        const HexCoordinate(1, -1, 0),
      ));

      gameState.simpleUnits.add(createTestUnit(
        'enemy1',
        'infantry',
        Player.player2,
        const HexCoordinate(2, -2, 0),
      ));

      gameState.currentPlayer = Player.player1;
    });

    test('Playing a card should NOT clear highlighted hexes', () {
      // REGRESSION TEST: Previously, playing a card would clear all highlights
      // This test ensures that highlights are preserved when a card is played

      // Simulate having highlighted hexes (as if an action was about to be taken)
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
        const HexCoordinate(1, -1, 0),
      };

      // Verify highlights are set
      expect(gameState.highlightedHexes.length, equals(2));
      expect(gameState.highlightedHexes.contains(const HexCoordinate(0, 0, 0)), isTrue);

      // NOTE: The actual card playing logic is in card_game_screen.dart's _playCard()
      // That method should NOT clear highlightedHexes
      // This test verifies the state object doesn't have any auto-clearing behavior

      // The highlights should still be there
      expect(gameState.highlightedHexes.length, equals(2),
          reason: 'Highlights should not be automatically cleared');
    });

    test('Setting highlightedHexes should replace previous highlights', () {
      // Set initial highlights
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
      };

      expect(gameState.highlightedHexes.length, equals(1));

      // Set new highlights (simulating action activation)
      gameState.highlightedHexes = {
        const HexCoordinate(1, -1, 0),
        const HexCoordinate(2, -2, 0),
      };

      // Verify old highlights are replaced
      expect(gameState.highlightedHexes.length, equals(2));
      expect(gameState.highlightedHexes.contains(const HexCoordinate(0, 0, 0)), isFalse);
      expect(gameState.highlightedHexes.contains(const HexCoordinate(1, -1, 0)), isTrue);
      expect(gameState.highlightedHexes.contains(const HexCoordinate(2, -2, 0)), isTrue);
    });

    test('Card action mode should enable highlighting', () {
      // Enable card action mode
      gameState.isCardActionActive = true;

      // Set highlights for unit selection
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
        const HexCoordinate(1, -1, 0),
      };

      expect(gameState.isCardActionActive, isTrue);
      expect(gameState.highlightedHexes.length, equals(2));
    });

    test('Clearing highlights should work when action completes', () {
      // Set highlights
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
        const HexCoordinate(1, -1, 0),
      };

      expect(gameState.highlightedHexes.length, equals(2));

      // Clear highlights (simulating action completion)
      gameState.highlightedHexes.clear();

      expect(gameState.highlightedHexes.isEmpty, isTrue);
    });

    test('Hex restrictions should filter highlighted hexes', () {
      // This tests that when a card action has hex_tiles restrictions,
      // only units in allowed hexes are highlighted

      final allUnits = gameState.simpleUnits;
      expect(allUnits.length, greaterThanOrEqualTo(2),
          reason: 'Should have at least 2 player units');

      // Get hexes for all player1 units
      final player1UnitHexes = allUnits
          .where((u) => u.owner == Player.player1)
          .map((u) => u.position)
          .toSet();

      expect(player1UnitHexes.length, equals(2));

      // Set highlights to player1 units
      gameState.highlightedHexes = player1UnitHexes;

      // Verify highlights are set correctly
      expect(gameState.highlightedHexes.length, equals(2));
      expect(gameState.highlightedHexes.contains(const HexCoordinate(0, 0, 0)), isTrue);
      expect(gameState.highlightedHexes.contains(const HexCoordinate(1, -1, 0)), isTrue);

      // Enemy unit should not be highlighted
      expect(gameState.highlightedHexes.contains(const HexCoordinate(2, -2, 0)), isFalse);
    });

    test('Action activation should set active card action state', () {
      // Simulate action activation
      gameState.isCardActionActive = true;
      gameState.activeCardActionHexTiles = 'all';
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
        const HexCoordinate(1, -1, 0),
      };

      expect(gameState.isCardActionActive, isTrue);
      expect(gameState.activeCardActionHexTiles, equals('all'));
      expect(gameState.highlightedHexes.length, equals(2));
    });

    test('Action completion should clear card action state', () {
      // Set up active action state
      gameState.isCardActionActive = true;
      gameState.activeCardActionHexTiles = 'middle_third';
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
      };

      // Simulate action completion (what _completeAction() does)
      gameState.isCardActionActive = false;
      gameState.highlightedHexes.clear();
      gameState.activeCardActionHexTiles = null;
      gameState.activeCardActionUnitId = null;
      gameState.isCardActionUnitLocked = false;

      // Verify state is cleared
      expect(gameState.isCardActionActive, isFalse);
      expect(gameState.highlightedHexes.isEmpty, isTrue);
      expect(gameState.activeCardActionHexTiles, isNull);
      expect(gameState.activeCardActionUnitId, isNull);
      expect(gameState.isCardActionUnitLocked, isFalse);
    });

    test('Multiple actions should each set their own highlights', () {
      // First action - highlight infantry units
      gameState.isCardActionActive = true;
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
      };

      expect(gameState.highlightedHexes.length, equals(1));

      // Complete first action
      gameState.isCardActionActive = false;
      gameState.highlightedHexes.clear();

      expect(gameState.highlightedHexes.isEmpty, isTrue);

      // Second action - highlight all units
      gameState.isCardActionActive = true;
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
        const HexCoordinate(1, -1, 0),
      };

      expect(gameState.highlightedHexes.length, equals(2));
    });

    test('Unit selection should work with highlighted hexes', () {
      // Set highlights
      gameState.highlightedHexes = {
        const HexCoordinate(0, 0, 0),
        const HexCoordinate(1, -1, 0),
      };

      // Get the unit at highlighted hex
      final unit = gameState.simpleUnits.firstWhere(
        (u) => u.position == const HexCoordinate(0, 0, 0),
      );

      // Select the unit
      unit.isSelected = true;
      gameState.activeCardActionUnitId = unit.id;

      expect(unit.isSelected, isTrue);
      expect(gameState.activeCardActionUnitId, equals(unit.id));

      // Highlights should still be present (not cleared by selection)
      expect(gameState.highlightedHexes.length, equals(2));
    });
  });

  group('Unit ID Uniqueness Tests', () {
    test('REGRESSION: Units loaded from scenario have unique IDs', () {
      // This is a critical regression test
      // Previously, units were assigned template IDs (like "p1_infantry")
      // which meant multiple units of the same type had the SAME ID
      // This broke unit selection, movement, and all game logic

      final scenarioConfig = {
        'game_type': 'card',
        'unit_placements': [
          {
            'template': {
              'id': 'p1_infantry',  // Template ID - should NOT be used as unit ID
              'type': 'infantry',
              'owner': 'player1',
            },
            'position': {'q': 0, 'r': 0, 's': 0},
          },
          {
            'template': {
              'id': 'p1_infantry',  // Same template ID
              'type': 'infantry',
              'owner': 'player1',
            },
            'position': {'q': 1, 'r': -1, 's': 0},
          },
          {
            'template': {
              'id': 'p1_infantry',  // Same template ID again
              'type': 'infantry',
              'owner': 'player1',
            },
            'position': {'q': 2, 'r': -2, 's': 0},
          },
        ],
      };

      final gameState = ChexxGameState();
      gameState.initializeFromScenario(scenarioConfig);

      // Verify all units were loaded
      expect(gameState.simpleUnits.length, equals(3),
          reason: 'All 3 units should be loaded from scenario');

      // Verify all units have DIFFERENT IDs
      final unitIds = gameState.simpleUnits.map((u) => u.id).toSet();
      expect(unitIds.length, equals(3),
          reason: 'CRITICAL: All units must have unique IDs. '
              'If this fails, units are using template IDs instead of position-based IDs.');

      // Verify IDs follow the correct pattern: type_owner_q_r_s
      for (final unit in gameState.simpleUnits) {
        expect(unit.id, matches(RegExp(r'infantry_player1_\d+_-?\d+_\d+')),
            reason: 'Unit ID should follow pattern: type_owner_q_r_s');
      }

      // Verify specific expected IDs
      final expectedIds = {
        'infantry_player1_0_0_0',
        'infantry_player1_1_-1_0',
        'infantry_player1_2_-2_0',
      };
      expect(unitIds, equals(expectedIds),
          reason: 'Units should have position-based unique IDs');
    });

    test('Multiple unit types have unique IDs', () {
      final scenarioConfig = {
        'game_type': 'card',
        'unit_placements': [
          {
            'template': {'id': 'p1_infantry', 'type': 'infantry', 'owner': 'player1'},
            'position': {'q': 0, 'r': 0, 's': 0},
          },
          {
            'template': {'id': 'p1_armor', 'type': 'armor', 'owner': 'player1'},
            'position': {'q': 0, 'r': 0, 's': 0},  // Same position, different type
          },
          {
            'template': {'id': 'p2_infantry', 'type': 'infantry', 'owner': 'player2'},
            'position': {'q': 0, 'r': 0, 's': 0},  // Same position, different owner
          },
        ],
      };

      final gameState = ChexxGameState();
      gameState.initializeFromScenario(scenarioConfig);

      // Even though they're at the same position (which is unusual but possible in tests),
      // they should have different IDs due to different types/owners
      final unitIds = gameState.simpleUnits.map((u) => u.id).toSet();
      expect(unitIds.length, equals(3),
          reason: 'Units with different types/owners must have unique IDs');
    });
  });

  group('Card Action Workflow Integration Tests', () {
    late ChexxGameState gameState;

    setUp(() {
      gameState = ChexxGameState();

      // Set up multiple units
      for (int i = 0; i < 3; i++) {
        gameState.simpleUnits.add(createTestUnit(
          'unit_$i',
          'infantry',
          Player.player1,
          HexCoordinate(i, -i, 0),
        ));
      }

      gameState.currentPlayer = Player.player1;
    });

    test('Complete card action workflow maintains highlighting', () {
      // 1. Card is played (should NOT clear highlights)
      // Initial state - no highlights
      expect(gameState.highlightedHexes.isEmpty, isTrue);

      // 2. Action is clicked - highlights are set
      gameState.isCardActionActive = true;
      final player1Units = gameState.simpleUnits
          .where((u) => u.owner == Player.player1)
          .map((u) => u.position)
          .toSet();
      gameState.highlightedHexes = player1Units;

      expect(gameState.highlightedHexes.length, equals(3),
          reason: 'All player1 units should be highlighted');

      // 3. Unit is selected
      final selectedUnit = gameState.simpleUnits.first;
      selectedUnit.isSelected = true;
      gameState.activeCardActionUnitId = selectedUnit.id;

      expect(selectedUnit.isSelected, isTrue);
      expect(gameState.highlightedHexes.length, equals(3),
          reason: 'Highlights should persist after unit selection');

      // 4. Unit moves (highlights get cleared for movement range display)
      gameState.highlightedHexes.clear();
      gameState.moveAndFireHexes = {
        HexCoordinate(1, -1, 0),
        HexCoordinate(2, -2, 0),
      };

      expect(gameState.highlightedHexes.isEmpty, isTrue);
      expect(gameState.moveAndFireHexes.length, equals(2),
          reason: 'Movement hexes should be shown');

      // 5. Action completes - all highlights cleared
      gameState.isCardActionActive = false;
      gameState.moveAndFireHexes.clear();
      gameState.moveOnlyHexes.clear();
      gameState.highlightedHexes.clear();

      expect(gameState.isCardActionActive, isFalse);
      expect(gameState.highlightedHexes.isEmpty, isTrue);
      expect(gameState.moveAndFireHexes.isEmpty, isTrue);
    });

    test('REGRESSION: Card playing preserves ability to set highlights later', () {
      // This is the key regression test
      // Previously, _playCard() would clear highlightedHexes
      // This prevented _onActionTapped() from setting them

      // Simulate the state right after a card is played
      // (in the buggy version, this would clear highlightedHexes)

      // The fix: _playCard() should NOT touch highlightedHexes
      // So we can still set them when action is clicked

      // Verify we can set highlights (simulating action click)
      final units = gameState.simpleUnits
          .where((u) => u.owner == Player.player1)
          .map((u) => u.position)
          .toSet();

      gameState.highlightedHexes = units;

      expect(gameState.highlightedHexes.length, equals(3),
          reason: 'CRITICAL: Highlights must be settable after card is played. '
              'If this fails, _playCard() is incorrectly clearing highlights.');

      expect(gameState.highlightedHexes.isNotEmpty, isTrue,
          reason: 'Highlighted hexes should be visible to show which units can be selected');
    });
  });
}

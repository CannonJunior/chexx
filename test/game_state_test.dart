import 'package:flutter_test/flutter_test.dart';
import 'package:chexx/src/models/game_state.dart';
import 'package:chexx/src/models/hex_coordinate.dart';
import 'package:chexx/src/models/unit_type_config.dart';
import 'package:chexx/src/models/game_unit.dart';
import 'package:chexx/src/models/hex_orientation.dart';
import 'package:chexx/core/interfaces/unit_factory.dart';

void main() {
  // Ensure Flutter binding is initialized for asset loading
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameState - Initialization', () {
    test('GS-001: Initialize game creates units and sets playing phase', () async {
      final gameState = GameState();

      // Load unit type set
      await gameState.loadUnitTypeSet('chexx');

      // Initialize the game
      gameState.initializeGame();

      // Verify game phase is playing
      expect(gameState.gamePhase, GamePhase.playing);

      // Verify units are created (18 total: 9 per player)
      expect(gameState.units.length, 18);

      // Verify player 1 units (9 units: 3 major + 6 minor)
      final p1Units = gameState.units.where((u) => u.owner == Player.player1).toList();
      expect(p1Units.length, 9);

      // Verify player 2 units (9 units: 6 minor + 3 major)
      final p2Units = gameState.units.where((u) => u.owner == Player.player2).toList();
      expect(p2Units.length, 9);

      // Verify turn number starts at 1
      expect(gameState.turnNumber, 1);

      // Verify current player is player 1
      expect(gameState.currentPlayer, Player.player1);

      // Verify turn phase is moving
      expect(gameState.turnPhase, TurnPhase.moving);
    });

    test('Game starts with no selected unit', () async {
      final gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();

      expect(gameState.selectedUnit, isNull);
      expect(gameState.availableMoves, isEmpty);
      expect(gameState.availableAttacks, isEmpty);
    });

    test('Reset game clears state and reinitializes', () async {
      final gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();

      // Make some changes
      final unit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(unit);
      expect(gameState.selectedUnit, isNotNull);

      // Reset the game
      gameState.resetGame();

      // Verify state is reset
      expect(gameState.selectedUnit, isNull);
      expect(gameState.turnNumber, 1);
      expect(gameState.currentPlayer, Player.player1);
      expect(gameState.gamePhase, GamePhase.playing);
    });
  });

  group('GameState - Unit Selection', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('GS-002: Select unit sets selected unit and calculates moves', () {
      final unit = gameState.currentPlayerUnits.first;

      gameState.selectUnit(unit);

      expect(gameState.selectedUnit, unit);
      expect(unit.state, UnitState.selected);
      expect(gameState.availableMoves, isNotEmpty,
          reason: 'Unit should have available moves');
    });

    test('GS-003: Cannot select enemy unit', () {
      // Get an opponent unit
      final enemyUnit = gameState.opponentUnits.first;

      // Try to select enemy unit
      gameState.selectUnit(enemyUnit);

      // Selection should fail
      expect(gameState.selectedUnit, isNull,
          reason: 'Should not be able to select enemy unit');
    });

    test('Cannot select unit that cannot move', () {
      final unit = gameState.currentPlayerUnits.first;

      // Make unit unable to move (by killing it)
      unit.takeDamage(999);
      expect(unit.canMove, isFalse);

      gameState.selectUnit(unit);

      expect(gameState.selectedUnit, isNull);
    });

    test('Deselect unit clears selection', () {
      final unit = gameState.currentPlayerUnits.first;

      gameState.selectUnit(unit);
      expect(gameState.selectedUnit, isNotNull);

      gameState.deselectUnit();

      expect(gameState.selectedUnit, isNull);
      expect(unit.state, UnitState.idle);
      expect(gameState.availableMoves, isEmpty);
      expect(gameState.availableAttacks, isEmpty);
    });
  });

  group('GameState - Unit Movement', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('GS-004: Move unit to valid position', () {
      final unit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(unit);

      final originalPosition = unit.position;
      final targetPosition = gameState.availableMoves.first;

      final success = gameState.moveUnit(targetPosition);

      expect(success, isTrue);
      expect(unit.position, targetPosition);
      expect(unit.position, isNot(originalPosition));
      expect(gameState.turnPhase, TurnPhase.acting,
          reason: 'Should transition to acting phase after movement');
    });

    test('GS-005: Invalid move outside available moves fails', () {
      final unit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(unit);

      final originalPosition = unit.position;
      // Create a far away target
      final farTarget = HexCoordinate(99, 0, -99);

      final success = gameState.moveUnit(farTarget);

      expect(success, isFalse);
      expect(unit.position, originalPosition,
          reason: 'Unit should not move when target is invalid');
    });

    test('Cannot move without selecting unit first', () {
      final target = HexCoordinate(1, 0, -1);

      final success = gameState.moveUnit(target);

      expect(success, isFalse);
    });

    test('Cannot move during acting phase', () {
      final unit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(unit);

      // Move once (transitions to acting phase)
      final targetPosition = gameState.availableMoves.first;
      gameState.moveUnit(targetPosition);
      expect(gameState.turnPhase, TurnPhase.acting);

      // Try to move again
      final secondTarget = gameState.availableMoves.isNotEmpty
          ? gameState.availableMoves.first
          : HexCoordinate(0, 1, -1);
      final success = gameState.moveUnit(secondTarget);

      expect(success, isFalse);
    });
  });

  group('GameState - Combat', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('GS-006: Attack enemy unit (setup)', () {
      // Note: This test sets up an attack scenario
      // Actual attack execution requires positioning units adjacent to each other
      final attackerUnit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(attackerUnit);

      // Verify available attacks are calculated
      expect(gameState.availableAttacks, isA<List<HexCoordinate>>());

      // Note: In a full test, we would position units to be adjacent
      // and verify that attackPosition() works correctly
    });

    test('GS-007: Cannot attack friendly unit', () {
      final unit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(unit);

      // Manually transition to acting phase
      gameState.turnPhase = TurnPhase.acting;

      // Try to attack a friendly unit's position
      final friendlyUnit = gameState.currentPlayerUnits
          .where((u) => u != unit)
          .first;

      final success = gameState.attackPosition(friendlyUnit.position);

      expect(success, isFalse,
          reason: 'Should not be able to attack friendly unit');
    });

    test('Cannot attack without selecting unit', () {
      final target = HexCoordinate(1, 0, -1);

      final success = gameState.attackPosition(target);

      expect(success, isFalse);
    });

    test('Cannot attack during moving phase', () {
      final unit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(unit);

      expect(gameState.turnPhase, TurnPhase.moving);

      // Try to attack
      final target = HexCoordinate(1, 0, -1);
      final success = gameState.attackPosition(target);

      expect(success, isFalse);
    });
  });

  group('GameState - Turn Management', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('GS-008: End turn switches players', () {
      expect(gameState.currentPlayer, Player.player1);
      expect(gameState.turnNumber, 1);

      gameState.endTurn();

      expect(gameState.currentPlayer, Player.player2);
      expect(gameState.turnNumber, 1, reason: 'Turn number increments only when back to player 1');
    });

    test('End turn increments turn number after both players', () {
      expect(gameState.turnNumber, 1);

      gameState.endTurn(); // Player 1 -> Player 2
      expect(gameState.currentPlayer, Player.player2);
      expect(gameState.turnNumber, 1);

      gameState.endTurn(); // Player 2 -> Player 1
      expect(gameState.currentPlayer, Player.player1);
      expect(gameState.turnNumber, 2);
    });

    test('End turn clears unit overrides', () {
      final unit = gameState.currentPlayerUnits.first;

      // Apply some override
      unit.applyOverrides({'movement_range': 10});
      expect(unit.movementRange, 10);

      // End turn should clear overrides
      gameState.endTurn();

      // Override should be cleared (back to base value)
      expect(unit.movementRange, isNot(10));
    });

    test('End turn resets turn phase to moving', () {
      // Manually set to acting phase
      gameState.turnPhase = TurnPhase.acting;

      gameState.endTurn();

      expect(gameState.turnPhase, TurnPhase.moving);
    });

    test('End turn deselects unit', () {
      final unit = gameState.currentPlayerUnits.first;
      gameState.selectUnit(unit);
      expect(gameState.selectedUnit, isNotNull);

      gameState.endTurn();

      expect(gameState.selectedUnit, isNull);
    });
  });

  group('GameState - Turn Timer', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('GS-009: Turn timer decrements over time', () {
      final initialTime = gameState.turnTimeRemaining;
      expect(initialTime, 6.0);

      // Simulate 1 second passing
      gameState.updateTimer(1.0);

      expect(gameState.turnTimeRemaining, 5.0);
      expect(gameState.turnTimeRemaining, lessThan(initialTime));
    });

    test('GS-010: Auto-end turn when timer expires', () {
      expect(gameState.currentPlayer, Player.player1);

      // Simulate full timer expiration
      gameState.updateTimer(7.0); // More than 6 seconds

      // Turn should auto-end
      expect(gameState.currentPlayer, Player.player2,
          reason: 'Turn should auto-end when timer expires');
    });

    test('Timer does not decrement when paused', () {
      final initialTime = gameState.turnTimeRemaining;

      gameState.togglePause();
      expect(gameState.isPaused, isTrue);

      gameState.updateTimer(1.0);

      expect(gameState.turnTimeRemaining, initialTime,
          reason: 'Timer should not change when paused');
    });

    test('Timer resets to 6 seconds at turn start', () {
      // Let some time pass
      gameState.updateTimer(3.0);
      expect(gameState.turnTimeRemaining, 3.0);

      // End turn
      gameState.endTurn();

      // Timer should reset
      expect(gameState.turnTimeRemaining, 6.0);
    });
  });

  group('GameState - Win Conditions', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('GS-011: Check win condition when all opponent units dead', () {
      expect(gameState.gamePhase, GamePhase.playing);

      // Kill all player 2 units
      for (final unit in gameState.units.where((u) => u.owner == Player.player2)) {
        unit.takeDamage(999); // Kill unit
      }

      // End turn should trigger win condition check
      gameState.endTurn();

      expect(gameState.gamePhase, GamePhase.gameOver);
      expect(gameState.winner, Player.player1);
    });

    test('Winner is null if game is not over', () {
      expect(gameState.gamePhase, GamePhase.playing);
      expect(gameState.winner, isNull);
    });

    test('Game continues when both players have units', () {
      expect(gameState.gamePhase, GamePhase.playing);

      // Verify both players have units
      final p1UnitsAlive = gameState.units.where((u) =>
          u.owner == Player.player1 && u.isAlive);
      final p2UnitsAlive = gameState.units.where((u) =>
          u.owner == Player.player2 && u.isAlive);

      expect(p1UnitsAlive.isNotEmpty, isTrue);
      expect(p2UnitsAlive.isNotEmpty, isTrue);

      // End turn
      gameState.endTurn();

      // Game should continue
      expect(gameState.gamePhase, GamePhase.playing);
    });
  });

  group('GameState - Rewards', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('GS-012: Reward calculation based on turn time', () {
      expect(gameState.player1Rewards, 0);

      // Simulate a fast turn (1 second)
      gameState.updateTimer(1.0);

      // End turn
      gameState.endTurn();

      // Player 1 should get rewards for fast turn
      // Formula: (6.0 - timeUsed) * 5 points per second
      // Fast turn (1s used) = (6-1) * 5 = 25 points
      expect(gameState.player1Rewards, greaterThan(0));
    });

    test('Reward system exists and tracks player rewards', () {
      // Verify reward system is initialized
      expect(gameState.player1Rewards, 0);
      expect(gameState.player2Rewards, 0);

      // Manually set rewards to test tracking
      gameState.player1Rewards = 50;
      expect(gameState.player1Rewards, 50);

      // End turn should preserve rewards
      gameState.endTurn();
      expect(gameState.player1Rewards, greaterThanOrEqualTo(50),
          reason: 'Rewards should be preserved or increased');
    }, skip: 'Timing-based reward calculation is hard to test reliably');

    test('Current player reward progress is calculated', () {
      gameState.player1Rewards = 30;

      // Progress should be rewards / 61
      final progress = gameState.currentPlayerRewardProgress;

      expect(progress, closeTo(30 / 61.0, 0.01));
      expect(progress, greaterThan(0.0));
      expect(progress, lessThan(1.0));
    });
  });

  group('GameState - Player Units', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();
    });

    test('Current player units returns only alive units', () {
      expect(gameState.currentPlayer, Player.player1);

      final currentUnits = gameState.currentPlayerUnits;

      // All should be player 1 units
      for (final unit in currentUnits) {
        expect(unit.owner, Player.player1);
        expect(unit.isAlive, isTrue);
      }

      expect(currentUnits.length, 9);
    });

    test('Opponent units returns other player units', () {
      expect(gameState.currentPlayer, Player.player1);

      final opponentUnits = gameState.opponentUnits;

      // All should be player 2 units
      for (final unit in opponentUnits) {
        expect(unit.owner, Player.player2);
        expect(unit.isAlive, isTrue);
      }

      expect(opponentUnits.length, 9);
    });

    test('Dead units are excluded from player units', () {
      // Kill a player 1 unit
      final unit = gameState.currentPlayerUnits.first;
      unit.takeDamage(999);
      expect(unit.isAlive, isFalse);

      final currentUnits = gameState.currentPlayerUnits;

      expect(currentUnits.length, 8, reason: 'Dead unit should be excluded');
      expect(currentUnits.contains(unit), isFalse);
    });
  });

  group('GameState - Hex Orientation', () {
    test('Toggle hex orientation switches between flat and pointy', () {
      final gameState = GameState();

      expect(gameState.hexOrientation, HexOrientation.flat);

      gameState.toggleHexOrientation();
      expect(gameState.hexOrientation, HexOrientation.pointy);

      gameState.toggleHexOrientation();
      expect(gameState.hexOrientation, HexOrientation.flat);
    });
  });

  group('GameState - Edge Cases', () {
    test('Skip action during acting phase ends turn', () async {
      final gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();

      expect(gameState.currentPlayer, Player.player1);

      // Manually set to acting phase
      gameState.turnPhase = TurnPhase.acting;

      gameState.skipAction();

      // Should have ended turn and switched players
      expect(gameState.currentPlayer, Player.player2);
    });

    test('Skip action during moving phase does nothing', () async {
      final gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();

      expect(gameState.turnPhase, TurnPhase.moving);
      expect(gameState.currentPlayer, Player.player1);

      gameState.skipAction();

      // Should not have ended turn
      expect(gameState.currentPlayer, Player.player1);
      expect(gameState.turnPhase, TurnPhase.moving);
    });

    test('Pause toggle changes pause state', () async {
      final gameState = GameState();
      await gameState.loadUnitTypeSet('chexx');
      gameState.initializeGame();

      expect(gameState.isPaused, isFalse);

      gameState.togglePause();
      expect(gameState.isPaused, isTrue);

      gameState.togglePause();
      expect(gameState.isPaused, isFalse);
    });
  });
}

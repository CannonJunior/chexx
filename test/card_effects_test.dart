import 'package:flutter_test/flutter_test.dart';
import 'package:chexx/src/models/game_unit.dart';
import 'package:chexx/src/models/hex_coordinate.dart';
import 'package:chexx/src/models/unit_type_config.dart';
import 'package:chexx/core/interfaces/unit_factory.dart';

void main() {
  group('Card Effects - Unit Overrides', () {
    late GameUnit infantryUnit;
    late GameUnit scoutUnit;

    setUp(() {
      // Create test unit configs
      final infantryConfig = UnitTypeConfig(
        id: 'p1_infantry',
        name: 'Infantry',
        description: 'Standard infantry unit',
        health: 4,
        maxHealth: 4,
        movementRange: 1,
        attackRange: 2,
        attackDamage: [3, 2, 1],
        movementType: 'adjacent',
        isIncrementable: true,
        symbol: 'I',
        gameType: 'wwii',
        special: {
          'move_and_fire': 0,
          'move_after_combat': 0,
        },
      );

      final scoutConfig = UnitTypeConfig(
        id: 'p1_scout',
        name: 'Scout',
        description: 'Fast reconnaissance unit',
        health: 2,
        maxHealth: 2,
        movementRange: 3,
        attackRange: 4,
        attackDamage: [2, 1],
        movementType: 'straight_line',
        isIncrementable: false,
        symbol: 'S',
        gameType: 'wwii',
      );

      infantryUnit = GameUnit(
        id: 'test_infantry',
        unitTypeId: 'p1_infantry',
        config: infantryConfig,
        owner: Player.player1,
        position: HexCoordinate(0, 0, 0),
      );

      scoutUnit = GameUnit(
        id: 'test_scout',
        unitTypeId: 'p1_scout',
        config: scoutConfig,
        owner: Player.player1,
        position: HexCoordinate(1, 0, -1),
      );
    });

    test('Unit restriction filtering - infantry matches', () {
      expect(infantryUnit.matchesUnitRestriction('infantry'), isTrue);
      expect(infantryUnit.matchesUnitRestriction('scout'), isFalse);
      expect(infantryUnit.matchesUnitRestriction('all'), isTrue);
      expect(infantryUnit.matchesUnitRestriction(null), isTrue);
    });

    test('Unit restriction filtering - scout matches', () {
      expect(scoutUnit.matchesUnitRestriction('scout'), isTrue);
      expect(scoutUnit.matchesUnitRestriction('infantry'), isFalse);
      expect(scoutUnit.matchesUnitRestriction('all'), isTrue);
    });

    test('Apply overrides to unit - basic attributes', () {
      final overrides = {
        'movement_range': 5,
        'attack_range': 4,
        'attack_damage': [4, 3, 2, 1],
      };

      // Check original values
      expect(infantryUnit.movementRange, equals(1));
      expect(infantryUnit.attackRange, equals(2));

      // Apply overrides
      infantryUnit.applyOverrides(overrides);

      // Check new values
      expect(infantryUnit.movementRange, equals(5));
      expect(infantryUnit.attackRange, equals(4));
      expect(infantryUnit.attackDamage, equals(10)); // Sum of [4,3,2,1]
      expect(infantryUnit.hasOverrides, isTrue);
    });

    test('Behind Enemy Lines card overrides', () {
      final behindEnemyLinesOverrides = {
        'movement_range': 3,
        'move_and_fire': 3,
        'move_only': 3,
        'move_after_combat': 3,
        'attack_range': 3,
        'attack_damage': [4, 3, 2],
      };

      // Check original values
      expect(infantryUnit.movementRange, equals(1));
      expect(infantryUnit.moveAndFire, equals(0));
      expect(infantryUnit.moveAfterCombat, equals(0));

      // Apply Behind Enemy Lines overrides
      infantryUnit.applyOverrides(behindEnemyLinesOverrides);

      // Check enhanced values
      expect(infantryUnit.movementRange, equals(3));
      expect(infantryUnit.moveAndFire, equals(3));
      expect(infantryUnit.moveAfterCombat, equals(3));
      expect(infantryUnit.attackRange, equals(3));
      expect(infantryUnit.attackDamage, equals(9)); // Sum of [4,3,2]
    });

    test('Clear overrides restores original values', () {
      final overrides = {
        'movement_range': 5,
        'attack_damage': [5, 4, 3],
      };

      infantryUnit.applyOverrides(overrides);
      expect(infantryUnit.movementRange, equals(5));
      expect(infantryUnit.hasOverrides, isTrue);

      // Clear overrides
      infantryUnit.clearOverrides();

      // Should restore to original config values
      expect(infantryUnit.movementRange, equals(1));
      expect(infantryUnit.attackDamage, equals(6)); // Sum of [3,2,1]
      expect(infantryUnit.hasOverrides, isFalse);
    });

    test('Multiple overrides can be applied sequentially', () {
      infantryUnit.applyOverrides({'movement_range': 3});
      expect(infantryUnit.movementRange, equals(3));

      infantryUnit.applyOverrides({'attack_range': 5});
      expect(infantryUnit.movementRange, equals(3)); // Still overridden
      expect(infantryUnit.attackRange, equals(5)); // Now also overridden
    });

    test('Overrides are unit-specific', () {
      infantryUnit.applyOverrides({'movement_range': 10});

      expect(infantryUnit.movementRange, equals(10));
      expect(scoutUnit.movementRange, equals(3)); // Unchanged
    });

    test('Get move_and_fire and move_after_combat values', () {
      // Default values from config
      expect(infantryUnit.moveAndFire, equals(0));
      expect(infantryUnit.moveAfterCombat, equals(0));

      // Apply overrides
      infantryUnit.applyOverrides({
        'move_and_fire': 2,
        'move_after_combat': 2,
      });

      expect(infantryUnit.moveAndFire, equals(2));
      expect(infantryUnit.moveAfterCombat, equals(2));
    });
  });

  group('Card Effects - Integration with GameState', () {
    test('applyCardEffectsToUnit checks unit restrictions', () {
      final infantryConfig = UnitTypeConfig(
        id: 'p1_infantry',
        name: 'Infantry',
        description: 'Standard infantry unit',
        health: 4,
        maxHealth: 4,
        movementRange: 1,
        attackRange: 2,
        attackDamage: [3, 2, 1],
        movementType: 'adjacent',
        isIncrementable: true,
        symbol: 'I',
        gameType: 'wwii',
      );

      final infantryUnit = GameUnit(
        id: 'test_infantry',
        unitTypeId: 'p1_infantry',
        config: infantryConfig,
        owner: Player.player1,
        position: HexCoordinate(0, 0, 0),
      );

      // Simulate Behind Enemy Lines card action
      final cardAction = {
        'action_type': 'order',
        'unit_restrictions': 'infantry',
        'overrides': {
          'movement_range': 3,
          'move_and_fire': 3,
          'move_after_combat': 3,
          'attack_damage': [4, 3, 2],
        },
      };

      // Infantry unit should match restriction
      expect(infantryUnit.matchesUnitRestriction('infantry'), isTrue);

      // Apply overrides
      infantryUnit.applyOverrides(cardAction['overrides'] as Map<String, dynamic>);

      // Verify effects applied
      expect(infantryUnit.movementRange, equals(3));
      expect(infantryUnit.moveAndFire, equals(3));
      expect(infantryUnit.moveAfterCombat, equals(3));
    });
  });
}

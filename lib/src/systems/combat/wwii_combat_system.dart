import 'dart:math';
import '../../../models/game_unit.dart';
import '../../../models/unit_type_config.dart';
import 'die_faces_config.dart';

/// Result of a single die roll in combat
class DieRollResult {
  final DieFace face;
  final bool isHit;
  final int effectivenessModifier;

  const DieRollResult({
    required this.face,
    required this.isHit,
    required this.effectivenessModifier,
  });

  @override
  String toString() => 'Roll: ${face.symbol} (${isHit ? "Hit" : "Miss"}) modifier: $effectivenessModifier';
}

/// Complete result of a combat attack
class CombatResult {
  final GameUnit attacker;
  final GameUnit defender;
  final List<DieRollResult> dieRolls;
  final int totalDamage;
  final bool defenderDestroyed;

  const CombatResult({
    required this.attacker,
    required this.defender,
    required this.dieRolls,
    required this.totalDamage,
    required this.defenderDestroyed,
  });

  int get hitCount => dieRolls.where((roll) => roll.isHit).length;
  int get missCount => dieRolls.where((roll) => !roll.isHit).length;

  @override
  String toString() {
    return 'Combat: ${attacker.unitTypeId} vs ${defender.unitTypeId} - '
           '${hitCount} hits, ${missCount} misses, ${totalDamage} damage, '
           '${defenderDestroyed ? "destroyed" : "survived"}';
  }
}

/// WWII-style die-based combat system
class WWIICombatSystem {
  final DieFacesConfig _dieFacesConfig;
  final Random _random;

  WWIICombatSystem({
    required DieFacesConfig dieFacesConfig,
    Random? random,
  }) : _dieFacesConfig = dieFacesConfig,
       _random = random ?? Random();

  /// Execute a combat attack between attacker and defender
  Future<CombatResult> executeAttack(
    GameUnit attacker,
    GameUnit defender,
    UnitTypeConfig attackerConfig,
    UnitTypeConfig defenderConfig,
    String defenderTileType,
  ) async {
    // Ensure we're using WWII-style units
    if (!attackerConfig.usesWWIIAttackSystem) {
      throw ArgumentError('Attacker must use WWII attack system');
    }

    // Get the attack damage array for die rolls
    final attackDamageArray = attackerConfig.attackDamageAsList;
    final dieRollCount = attackDamageArray.length;

    // Roll dice for each potential attack damage
    final dieRolls = <DieRollResult>[];
    int totalDamage = 0;

    for (int i = 0; i < dieRollCount; i++) {
      final rolledFace = _dieFacesConfig.rollDie(_random);

      // Check if this roll hits the target
      final isHit = _evaluateHit(
        rolledFace,
        attackerConfig,
        defenderConfig,
      );

      // Get effectiveness modifier based on die face vs tile type
      final effectivenessModifier = _dieFacesConfig.getCombatEffectiveness(
        rolledFace.unitType,
        defenderTileType,
      );

      final rollResult = DieRollResult(
        face: rolledFace,
        isHit: isHit,
        effectivenessModifier: effectivenessModifier,
      );

      dieRolls.add(rollResult);

      // Calculate damage for this roll
      if (isHit && effectivenessModifier >= 0) {
        final baseDamage = attackDamageArray[i];
        // Add effectiveness modifier as additional damage
        final finalDamage = baseDamage + effectivenessModifier;
        totalDamage += finalDamage.clamp(0, 999); // Ensure non-negative damage
      }
    }

    // Apply damage to defender
    final newDefenderHealth = (defender.health - totalDamage).clamp(0, defenderConfig.maxHealth);
    final defenderDestroyed = newDefenderHealth <= 0;

    // Update defender health
    final updatedDefender = GameUnit(
      id: defender.id,
      unitTypeId: defender.unitTypeId,
      playerId: defender.playerId,
      position: defender.position,
      health: newDefenderHealth,
    );

    return CombatResult(
      attacker: attacker,
      defender: updatedDefender,
      dieRolls: dieRolls,
      totalDamage: totalDamage,
      defenderDestroyed: defenderDestroyed,
    );
  }

  /// Evaluate if a die roll results in a hit
  bool _evaluateHit(
    DieFace rolledFace,
    UnitTypeConfig attackerConfig,
    UnitTypeConfig defenderConfig,
  ) {
    // Miss faces always miss
    if (rolledFace.unitType == 'miss') {
      return false;
    }

    // Basic hit evaluation: unit types on die faces hit their corresponding targets
    // This can be expanded with more complex logic

    // Infantry is effective against artillery and other infantry
    if (rolledFace.unitType == 'infantry') {
      return defenderConfig.id == 'artillery' || defenderConfig.id == 'infantry';
    }

    // Armor is effective against infantry and other armor
    if (rolledFace.unitType == 'armor') {
      return defenderConfig.id == 'infantry' || defenderConfig.id == 'armor';
    }

    // Artillery is effective against armor and other artillery
    if (rolledFace.unitType == 'artillery') {
      return defenderConfig.id == 'armor' || defenderConfig.id == 'artillery';
    }

    // Default: no hit
    return false;
  }

  /// Check if an attack is possible between two units
  bool canAttack(
    GameUnit attacker,
    GameUnit defender,
    UnitTypeConfig attackerConfig,
  ) {
    // Must be WWII-style unit to use this combat system
    if (!attackerConfig.usesWWIIAttackSystem) {
      return false;
    }

    // Units can't attack themselves
    if (attacker.id == defender.id) {
      return false;
    }

    // Units can't attack friendly units (same player)
    if (attacker.playerId == defender.playerId) {
      return false;
    }

    // Attacker must be alive
    if (attacker.health <= 0) {
      return false;
    }

    // Defender must be alive
    if (defender.health <= 0) {
      return false;
    }

    return true;
  }

  /// Simulate a combat attack without applying changes (for AI/preview)
  Future<CombatResult> simulateAttack(
    GameUnit attacker,
    GameUnit defender,
    UnitTypeConfig attackerConfig,
    UnitTypeConfig defenderConfig,
    String defenderTileType, {
    int? seed,
  }) async {
    // Use a seeded random for deterministic simulation if provided
    final simulationRandom = seed != null ? Random(seed) : Random();

    final tempCombatSystem = WWIICombatSystem(
      dieFacesConfig: _dieFacesConfig,
      random: simulationRandom,
    );

    return tempCombatSystem.executeAttack(
      attacker,
      defender,
      attackerConfig,
      defenderConfig,
      defenderTileType,
    );
  }

  /// Get combat statistics for display
  Map<String, dynamic> getCombatStats(
    UnitTypeConfig attackerConfig,
    String defenderTileType,
  ) {
    final attackDamageArray = attackerConfig.attackDamageAsList;

    // Calculate max possible damage considering all die faces
    int maxPossibleDamage = 0;
    final dieFaceEffectiveness = <String, int>{};

    for (final dieFaceType in _dieFacesConfig.combatModifiers.getAvailableDieFaceTypes()) {
      final effectiveness = _dieFacesConfig.getCombatEffectiveness(
        dieFaceType,
        defenderTileType,
      );
      dieFaceEffectiveness[dieFaceType] = effectiveness;

      // Calculate max damage if all rolls were this die face type
      if (effectiveness >= 0) {
        final maxDamageForThisFace = attackDamageArray.fold<int>(
          0,
          (sum, damage) => sum + damage + effectiveness,
        );

        if (maxDamageForThisFace > maxPossibleDamage) {
          maxPossibleDamage = maxDamageForThisFace;
        }
      }
    }

    return {
      'attacker_type': attackerConfig.id,
      'defender_tile_type': defenderTileType,
      'die_face_effectiveness': dieFaceEffectiveness,
      'die_rolls_count': attackDamageArray.length,
      'max_possible_damage': maxPossibleDamage,
      'attack_damage_array': attackDamageArray,
    };
  }

  /// Get the die faces configuration
  DieFacesConfig get dieFacesConfig => _dieFacesConfig;
}

/// Factory for creating WWII combat systems
class WWIICombatSystemFactory {
  static Future<WWIICombatSystem> create({Random? random}) async {
    final dieFacesConfig = await DieFacesConfigLoader.loadDieFacesConfig();
    return WWIICombatSystem(
      dieFacesConfig: dieFacesConfig,
      random: random,
    );
  }
}
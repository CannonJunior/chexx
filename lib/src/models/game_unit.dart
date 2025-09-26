import 'hex_coordinate.dart';

/// Level bonuses for units
class LevelBonuses {
  final int healthBonus;
  final int attackBonus;
  final int movementBonus;

  const LevelBonuses({
    this.healthBonus = 0,
    this.attackBonus = 0,
    this.movementBonus = 0,
  });

  /// Get level bonuses for a specific level
  factory LevelBonuses.fromLevel(int level) {
    if (level <= 1) return const LevelBonuses();

    // Every 2 levels: +1 health
    // Every 3 levels: +1 attack
    // Every 4 levels: +1 movement
    return LevelBonuses(
      healthBonus: ((level - 1) ~/ 2),
      attackBonus: ((level - 1) ~/ 3),
      movementBonus: ((level - 1) ~/ 4),
    );
  }
}

enum UnitType { minor, scout, knight, guardian }

enum Player { player1, player2 }

enum UnitState { idle, selected, moving, attacking, dead }

/// Represents a game unit with position, stats, and abilities
class GameUnit {
  final String id;
  final UnitType type;
  final Player owner;
  HexCoordinate position;
  UnitState state;

  int currentHealth;
  int maxHealth;
  int level;
  int experience;

  // Ability cooldowns
  Map<String, int> abilityCooldowns;

  // Status effects
  Map<String, int> statusEffects;

  GameUnit({
    required this.id,
    required this.type,
    required this.owner,
    required this.position,
    this.state = UnitState.idle,
    required this.maxHealth,
    this.level = 1,
    this.experience = 0,
  }) : currentHealth = maxHealth,
       abilityCooldowns = {},
       statusEffects = {};

  /// Check if unit is alive
  bool get isAlive => currentHealth > 0;

  /// Check if unit can move
  bool get canMove => isAlive && state != UnitState.dead;

  /// Check if unit can attack
  bool get canAttack => isAlive && state != UnitState.dead;

  /// Get movement range based on unit type
  int get movementRange {
    switch (type) {
      case UnitType.minor:
        return 1;
      case UnitType.scout:
        return 3;
      case UnitType.knight:
        return 2;
      case UnitType.guardian:
        return 1;
    }
  }

  /// Get attack range based on unit type
  int get attackRange {
    switch (type) {
      case UnitType.minor:
        return 1;
      case UnitType.scout:
        return 3;
      case UnitType.knight:
        return 2;
      case UnitType.guardian:
        return 1;
    }
  }

  /// Get attack damage based on unit type
  int get attackDamage {
    switch (type) {
      case UnitType.minor:
        return 1;
      case UnitType.scout:
        return 1;
      case UnitType.knight:
        return 2;
      case UnitType.guardian:
        return 1;
    }
  }

  /// Check if unit can move to target position
  bool canMoveTo(HexCoordinate target, List<GameUnit> allUnits) {
    if (!canMove) return false;

    // Check if target is within movement range (with level bonuses)
    final distance = position.distanceTo(target);
    if (distance > effectiveMovementRange) return false;

    // Check if target position is occupied
    final occupiedBy = allUnits.where((unit) =>
        unit.isAlive && unit.position == target).firstOrNull;
    if (occupiedBy != null) return false;

    // Check movement type constraints
    return _isValidMovementPath(target);
  }

  /// Check if unit can attack target position
  bool canAttackPosition(HexCoordinate target, List<GameUnit> allUnits) {
    if (!canAttack) return false;

    final distance = position.distanceTo(target);
    if (distance > attackRange) return false;

    // For basic implementation, all units can attack in range
    // Scout has line-of-sight, others are direct
    return true;
  }

  /// Get valid movement positions
  List<HexCoordinate> getValidMoves(List<GameUnit> allUnits) {
    final validMoves = <HexCoordinate>[];
    final possibleMoves = HexCoordinate.hexesInRange(position, effectiveMovementRange);

    for (final target in possibleMoves) {
      if (target != position && canMoveTo(target, allUnits)) {
        validMoves.add(target);
      }
    }

    return validMoves;
  }

  /// Get valid attack positions
  List<HexCoordinate> getValidAttacks(List<GameUnit> allUnits) {
    final validAttacks = <HexCoordinate>[];
    final possibleAttacks = HexCoordinate.hexesInRange(position, attackRange);

    for (final target in possibleAttacks) {
      if (target != position && canAttackPosition(target, allUnits)) {
        // Check if there's an enemy unit at target
        final targetUnit = allUnits.where((unit) =>
            unit.isAlive && unit.position == target && unit.owner != owner)
            .firstOrNull;
        if (targetUnit != null) {
          validAttacks.add(target);
        }
      }
    }

    return validAttacks;
  }

  /// Move unit to new position
  void moveTo(HexCoordinate newPosition) {
    if (canMove) {
      position = newPosition;
      state = UnitState.idle;
    }
  }

  /// Take damage
  bool takeDamage(int damage) {
    currentHealth = (currentHealth - damage).clamp(0, maxHealth);
    if (currentHealth <= 0) {
      state = UnitState.dead;
      return true; // Unit died
    }
    return false; // Unit survived
  }

  /// Take damage with shield check (requires GameState for shield validation)
  bool takeDamageWithShield(int damage, bool hasShield) {
    int actualDamage = hasShield ? (damage - 1).clamp(0, 999) : damage;
    return takeDamage(actualDamage);
  }

  /// Heal unit
  void heal(int amount) {
    currentHealth = (currentHealth + amount).clamp(0, maxHealth);
  }

  /// Get experience required for next level
  int get experienceToNextLevel => level * 2;

  /// Get experience progress to next level (0.0 to 1.0)
  double get experienceProgress => experience / experienceToNextLevel;

  /// Get level bonuses applied to this unit
  LevelBonuses get levelBonuses => LevelBonuses.fromLevel(level);

  /// Gain experience and potentially level up
  bool gainExperience(int exp) {
    experience += exp;
    final expRequired = experienceToNextLevel;

    if (experience >= expRequired) {
      final oldLevel = level;
      level++;

      // Apply level up bonuses
      final bonuses = levelBonuses;
      maxHealth += bonuses.healthBonus;
      currentHealth += bonuses.healthBonus; // Heal on level up
      experience -= expRequired;

      // Clear ability cooldowns on level up
      abilityCooldowns.clear();

      return true; // Leveled up
    }
    return false; // No level up
  }

  /// Get effective attack damage with level bonuses
  int get effectiveAttackDamage => attackDamage + levelBonuses.attackBonus;

  /// Get effective movement range with level bonuses
  int get effectiveMovementRange => movementRange + levelBonuses.movementBonus;

  /// Check if ability is on cooldown
  bool isAbilityOnCooldown(String abilityName) {
    return (abilityCooldowns[abilityName] ?? 0) > 0;
  }

  /// Use ability and set cooldown
  void useAbility(String abilityName, int cooldown) {
    abilityCooldowns[abilityName] = cooldown;
  }

  /// Update cooldowns (called each turn)
  void updateCooldowns() {
    final keys = abilityCooldowns.keys.toList();
    for (final key in keys) {
      abilityCooldowns[key] = (abilityCooldowns[key]! - 1).clamp(0, 999);
      if (abilityCooldowns[key]! <= 0) {
        abilityCooldowns.remove(key);
      }
    }
  }

  /// Validate movement path based on unit type
  bool _isValidMovementPath(HexCoordinate target) {
    switch (type) {
      case UnitType.minor:
      case UnitType.guardian:
        return true; // Can move to any hex in range

      case UnitType.scout:
        // Scout moves in straight lines only
        final diff = target - position;
        return diff.q == 0 || diff.r == 0 || diff.s == 0;

      case UnitType.knight:
        // Knight moves in L-shape pattern
        final distance = position.distanceTo(target);
        if (distance > 2) return false;

        // L-shape: must be exactly 2 distance and not in straight line
        final diff = target - position;
        final isStraightLine = diff.q == 0 || diff.r == 0 || diff.s == 0;
        return distance == 2 && !isStraightLine;
    }
  }

  /// Check if unit has special abilities available
  bool canUseSpecialAbility(String abilityName) {
    switch (type) {
      case UnitType.guardian:
        return abilityName == 'swap' && !isAbilityOnCooldown('swap');
      case UnitType.scout:
        return abilityName == 'long_range_scan' && !isAbilityOnCooldown('long_range_scan');
      default:
        return false;
    }
  }

  /// Use special ability
  bool useSpecialAbility(String abilityName, HexCoordinate? target, List<GameUnit> allUnits) {
    if (!canUseSpecialAbility(abilityName)) return false;

    switch (type) {
      case UnitType.guardian:
        if (abilityName == 'swap' && target != null) {
          return _performSwapAbility(target, allUnits);
        }
        break;
      case UnitType.scout:
        if (abilityName == 'long_range_scan') {
          return _performLongRangeScan(allUnits);
        }
        break;
      default:
        break;
    }
    return false;
  }

  /// Guardian swap ability - exchange positions with friendly unit
  bool _performSwapAbility(HexCoordinate target, List<GameUnit> allUnits) {
    final targetUnit = allUnits.where((u) => u.position == target && u.isAlive).firstOrNull;
    if (targetUnit == null || targetUnit.owner != owner) return false;

    final distance = position.distanceTo(target);
    if (distance > effectiveMovementRange) return false;

    // Perform swap
    final tempPosition = position;
    position = targetUnit.position;
    targetUnit.position = tempPosition;

    // Set cooldown
    useAbility('swap', 3);
    return true;
  }

  /// Scout long range scan - reveals enemy positions and weaknesses
  bool _performLongRangeScan(List<GameUnit> allUnits) {
    // Grant temporary vision boost and mark nearby enemies
    final nearbyEnemies = allUnits.where((u) =>
        u.isAlive &&
        u.owner != owner &&
        position.distanceTo(u.position) <= 4);

    for (final enemy in nearbyEnemies) {
      enemy.statusEffects['revealed'] = 2; // Revealed for 2 turns
    }

    useAbility('long_range_scan', 4);
    return true;
  }

  /// Create unit from type
  static GameUnit create({
    required String id,
    required UnitType type,
    required Player owner,
    required HexCoordinate position,
  }) {
    final health = switch (type) {
      UnitType.minor => 1,
      UnitType.scout => 2,
      UnitType.knight => 3,
      UnitType.guardian => 3,
    };

    return GameUnit(
      id: id,
      type: type,
      owner: owner,
      position: position,
      maxHealth: health,
    );
  }

  @override
  String toString() => 'GameUnit($id, $type, $owner, $position, HP:$currentHealth/$maxHealth)';
}
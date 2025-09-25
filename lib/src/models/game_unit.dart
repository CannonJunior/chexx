import 'hex_coordinate.dart';

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

    // Check if target is within movement range
    final distance = position.distanceTo(target);
    if (distance > movementRange) return false;

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
    final possibleMoves = HexCoordinate.hexesInRange(position, movementRange);

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

  /// Heal unit
  void heal(int amount) {
    currentHealth = (currentHealth + amount).clamp(0, maxHealth);
  }

  /// Gain experience and potentially level up
  bool gainExperience(int exp) {
    experience += exp;
    final expRequired = level * 2; // Simple progression: level 1 needs 2 exp, level 2 needs 4 exp, etc.

    if (experience >= expRequired) {
      level++;
      maxHealth++;
      currentHealth++;
      experience -= expRequired;

      // Clear ability cooldowns on level up
      abilityCooldowns.clear();

      return true; // Leveled up
    }
    return false; // No level up
  }

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
        // Scout moves in straight lines
        final diff = target - position;
        return diff.q == 0 || diff.r == 0 || diff.s == 0;

      case UnitType.knight:
        // Knight moves in L-shape (simplified for now)
        final distance = position.distanceTo(target);
        return distance <= 2;
    }
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
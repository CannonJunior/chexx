import 'hex_coordinate.dart';
import 'unit_type_config.dart';
import '../../core/interfaces/unit_factory.dart';

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

enum UnitState { idle, selected, moving, attacking, dead }

/// Represents a game unit with position, stats, and abilities
class GameUnit {
  final String id;
  final String unitTypeId;
  final UnitTypeConfig config;
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

  // Temporary attribute overrides (from cards, abilities, etc.)
  // These are cleared at the end of each turn
  Map<String, dynamic> _tempOverrides;

  GameUnit({
    required this.id,
    required this.unitTypeId,
    required this.config,
    required this.owner,
    required this.position,
    this.state = UnitState.idle,
    int? customHealth,
    this.level = 1,
    this.experience = 0,
  }) : maxHealth = customHealth ?? config.health,
       currentHealth = customHealth ?? config.health,
       abilityCooldowns = {},
       statusEffects = {},
       _tempOverrides = {};

  /// Check if unit is alive
  bool get isAlive => currentHealth > 0;

  /// Check if unit can move
  bool get canMove => isAlive && state != UnitState.dead;

  /// Check if unit can attack
  bool get canAttack => isAlive && state != UnitState.dead;

  /// Get movement range based on unit configuration (with overrides)
  int get movementRange => _tempOverrides['movement_range'] as int? ?? config.movementRange;

  /// Get attack range based on unit configuration (with overrides)
  int get attackRange => _tempOverrides['attack_range'] as int? ?? config.attackRange;

  /// Get attack damage based on unit configuration (with overrides)
  int get attackDamage {
    // Check for override first
    final overrideDamage = _tempOverrides['attack_damage'];
    if (overrideDamage != null) {
      if (overrideDamage is List) {
        // For WWII units with array attack damage
        final List<int> damageArray = (overrideDamage as List).cast<int>();
        return damageArray.fold(0, (sum, damage) => sum + damage);
      } else {
        return overrideDamage as int;
      }
    }

    // Use config value
    if (config.attackDamage is List<int>) {
      // For WWII units with array attack damage, return the sum as equivalent damage
      final List<int> damageArray = config.attackDamage as List<int>;
      return damageArray.fold(0, (sum, damage) => sum + damage);
    } else {
      return config.attackDamage as int;
    }
  }

  /// Get move_and_fire value (with overrides) - movement after attack
  int get moveAndFire => _tempOverrides['move_and_fire'] as int? ?? (config.special?['move_and_fire'] as int? ?? 0);

  /// Get move_after_combat value (with overrides) - movement after combat
  int get moveAfterCombat => _tempOverrides['move_after_combat'] as int? ?? (config.special?['move_after_combat'] as int? ?? 0);

  /// Get move_only value (with overrides)
  int get moveOnly => _tempOverrides['move_only'] as int? ?? (config.special?['move_only'] as int? ?? movementRange);

  /// Check if unit can move to target position
  bool canMoveTo(HexCoordinate target, List<GameUnit> allUnits) {
    if (!canMove) return false;

    // Check if target is within movement range (with level bonuses)
    final distance = position.distanceTo(target);
    if (distance > effectiveMovementRange) return false;

    // Check if target position is occupied
    final occupiedUnits = allUnits.where((unit) =>
        unit.isAlive && unit.position == target).toList();
    final occupiedBy = occupiedUnits.isNotEmpty ? occupiedUnits.first : null;
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
        final targetUnits = allUnits.where((unit) =>
            unit.isAlive && unit.position == target && unit.owner != owner).toList();
        final targetUnit = targetUnits.isNotEmpty ? targetUnits.first : null;
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
    switch (config.movementType) {
      case 'adjacent':
        return true; // Can move to any hex in range

      case 'straight_line':
        // Moves in straight lines only
        final diff = target - position;
        return diff.q == 0 || diff.r == 0 || diff.s == 0;

      case 'l_shaped':
        // L-shape pattern movement
        final distance = position.distanceTo(target);
        if (distance > 2) return false;

        // L-shape: must be exactly 2 distance and not in straight line
        final diff = target - position;
        final isStraightLine = diff.q == 0 || diff.r == 0 || diff.s == 0;
        return distance == 2 && !isStraightLine;

      default:
        return true; // Default to adjacent movement
    }
  }

  /// Check if unit has special abilities available
  bool canUseSpecialAbility(String abilityName) {
    if (config.special == null) return false;

    // Check if the special ability matches what this unit has
    final specialAbility = config.special!['special'] as String?;
    if (specialAbility == null) return false;

    switch (specialAbility) {
      case 'can_swap_with_friendly':
        return abilityName == 'swap' && !isAbilityOnCooldown('swap');
      case 'indirect_fire':
        return abilityName == 'indirect_fire' && !isAbilityOnCooldown('indirect_fire');
      default:
        return false;
    }
  }

  /// Use special ability
  bool useSpecialAbility(String abilityName, HexCoordinate? target, List<GameUnit> allUnits) {
    if (!canUseSpecialAbility(abilityName)) return false;

    if (config.special == null) return false;
    final specialAbility = config.special!['special'] as String?;
    if (specialAbility == null) return false;

    switch (specialAbility) {
      case 'can_swap_with_friendly':
        if (abilityName == 'swap' && target != null) {
          return _performSwapAbility(target, allUnits);
        }
        break;
      case 'indirect_fire':
        if (abilityName == 'indirect_fire') {
          return _performIndirectFire(target, allUnits);
        }
        break;
      default:
        break;
    }
    return false;
  }

  /// Guardian swap ability - exchange positions with friendly unit
  bool _performSwapAbility(HexCoordinate target, List<GameUnit> allUnits) {
    final targetUnits = allUnits.where((u) => u.position == target && u.isAlive).toList();
    final targetUnit = targetUnits.isNotEmpty ? targetUnits.first : null;
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

  /// Artillery indirect fire - can attack over obstacles
  bool _performIndirectFire(HexCoordinate? target, List<GameUnit> allUnits) {
    if (target == null) return false;

    final distance = position.distanceTo(target);
    if (distance > attackRange) return false;

    // Find target unit at position
    final targetUnits = allUnits.where((u) =>
        u.isAlive && u.position == target && u.owner != owner).toList();
    final targetUnit = targetUnits.isNotEmpty ? targetUnits.first : null;

    if (targetUnit != null) {
      // Deal damage to target
      targetUnit.takeDamage(effectiveAttackDamage);

      // Set cooldown for indirect fire
      useAbility('indirect_fire', 2);
      return true;
    }

    return false;
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

  /// Apply temporary attribute overrides from card action
  /// These last for the duration of the current turn
  void applyOverrides(Map<String, dynamic> overrides) {
    print('DEBUG: Applying overrides to unit $id: $overrides');
    _tempOverrides.addAll(overrides);
    print('DEBUG: Unit $id now has overrides: $_tempOverrides');
  }

  /// Clear all temporary overrides (called at end of turn)
  void clearOverrides() {
    if (_tempOverrides.isNotEmpty) {
      print('DEBUG: Clearing overrides from unit $id: $_tempOverrides');
      _tempOverrides.clear();
    }
  }

  /// Check if this unit matches a unit restriction filter
  /// Restriction can be:
  /// - "infantry" - matches infantry unit type
  /// - "armor" - matches armor unit type
  /// - "scout" - matches scout unit type
  /// - "minor" - matches minor unit type
  /// - "artillery" - matches artillery unit type
  /// - "all" - matches all units
  bool matchesUnitRestriction(String? restriction) {
    if (restriction == null || restriction.isEmpty || restriction.toLowerCase() == 'all') {
      return true; // No restriction or "all" means any unit can be selected
    }

    final restrictionLower = restriction.toLowerCase();
    final unitTypeLower = unitTypeId.toLowerCase();

    // Check if unit type contains the restriction string
    // This handles cases like:
    // - "infantry" matches "p1_infantry", "p2_infantry"
    // - "scout" matches "p1_scout", "p2_scout"
    // - "armor" matches "p1_armor", "p2_armor"
    return unitTypeLower.contains(restrictionLower);
  }

  /// Get current overrides (for debugging)
  Map<String, dynamic> get currentOverrides => Map.unmodifiable(_tempOverrides);

  /// Check if unit has any active overrides
  bool get hasOverrides => _tempOverrides.isNotEmpty;

  @override
  String toString() => 'GameUnit($id, $unitTypeId, $owner, $position, HP:$currentHealth/$maxHealth)';
}
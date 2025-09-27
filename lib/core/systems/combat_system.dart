import 'package:oxygen/oxygen.dart';
import '../components/position_component.dart';
import '../components/combat_component.dart';
import '../components/health_component.dart';
import '../components/owner_component.dart';
import '../models/hex_coordinate.dart';
import '../interfaces/unit_factory.dart';

/// System for handling combat between entities
class CombatSystem extends System {
  late Query _positionQuery;
  late Query _combatQuery;

  @override
  void init() {
    _positionQuery = createQuery([
      Has<PositionComponent>(),
      Has<CombatComponent>(),
      Has<HealthComponent>(),
    ]);
    _combatQuery = createQuery([Has<CombatComponent>()]);
  }

  /// Check if entity can attack target position
  bool canAttack({
    required Entity attacker,
    required HexCoordinate target,
  }) {
    final combat = attacker.get<CombatComponent>();
    final position = attacker.get<PositionComponent>();
    final health = attacker.get<HealthComponent>();

    if (combat == null || position == null || health == null) return false;
    if (!combat.canAttack || !health.isAlive) return false;

    final distance = position.coordinate.distanceTo(target);
    if (distance > combat.attackRange) return false;

    // Check if there's a valid target at the position
    final targetEntity = getEntityAt(target);
    if (targetEntity == null) return false;

    // Can't attack entities of the same owner
    final attackerOwner = attacker.get<OwnerComponent>();
    final targetOwner = targetEntity.get<OwnerComponent>();
    if (attackerOwner != null && targetOwner != null) {
      if (attackerOwner.owner == targetOwner.owner) return false;
    }

    return true;
  }

  /// Perform attack from attacker to target position
  bool attack({
    required Entity attacker,
    required HexCoordinate target,
  }) {
    if (!canAttack(attacker: attacker, target: target)) return false;

    final targetEntity = getEntityAt(target);
    if (targetEntity == null) return false;

    final attackerCombat = attacker.get<CombatComponent>()!;
    final targetHealth = targetEntity.get<HealthComponent>();

    if (targetHealth == null) return false;

    // Calculate damage (can be overridden by game-specific rules)
    final damage = calculateDamage(attacker: attacker, target: targetEntity);

    // Apply damage
    final died = targetHealth.takeDamage(damage);

    // Mark attacker as having attacked
    attackerCombat.markAttacked();

    // Handle death
    if (died) {
      handleEntityDeath(targetEntity);
    }

    return true;
  }

  /// Calculate damage from attacker to target (can be overridden)
  int calculateDamage({
    required Entity attacker,
    required Entity target,
  }) {
    final combat = attacker.get<CombatComponent>();
    return combat?.attackDamage ?? 1;
  }

  /// Handle entity death
  void handleEntityDeath(Entity entity) {
    // Mark entity as dead (can be handled by game-specific logic)
    final health = entity.get<HealthComponent>();
    if (health != null) {
      health.currentHealth = 0;
    }
  }

  /// Get all valid attack positions for an entity
  List<HexCoordinate> getValidAttacks(Entity entity) {
    final combat = entity.get<CombatComponent>();
    final position = entity.get<PositionComponent>();

    if (combat == null || position == null) return [];

    final validAttacks = <HexCoordinate>[];
    final range = combat.attackRange;
    final possibleTargets = HexCoordinate.hexesInRange(position.coordinate, range);

    for (final target in possibleTargets) {
      if (target != position.coordinate && canAttack(attacker: entity, target: target)) {
        validAttacks.add(target);
      }
    }

    return validAttacks;
  }

  /// Reset attack flags for all entities belonging to a player
  void resetAttacksForPlayer(Player player) {
    for (final entity in _combatQuery.entities) {
      final owner = entity.get<OwnerComponent>();
      final combat = entity.get<CombatComponent>();

      if (owner != null && combat != null && owner.owner == player) {
        combat.resetAttack();
      }
    }
  }

  /// Get entity at specific position
  Entity? getEntityAt(HexCoordinate coordinate) {
    for (final entity in _positionQuery.entities) {
      final position = entity.get<PositionComponent>()!;
      if (position.coordinate == coordinate) {
        return entity;
      }
    }
    return null;
  }

  /// Get all entities belonging to a player
  List<Entity> getPlayerEntities(Player player) {
    final entities = <Entity>[];
    for (final entity in _positionQuery.entities) {
      final owner = entity.get<OwnerComponent>();
      if (owner != null && owner.owner == player) {
        entities.add(entity);
      }
    }
    return entities;
  }

  /// Check if player has any living entities
  bool hasLivingEntities(Player player) {
    for (final entity in _positionQuery.entities) {
      final owner = entity.get<OwnerComponent>();
      final health = entity.get<HealthComponent>();

      if (owner != null && health != null &&
          owner.owner == player && health.isAlive) {
        return true;
      }
    }
    return false;
  }

  @override
  void execute(double delta) {
    // Combat system is primarily reactive - called by game logic
  }
}
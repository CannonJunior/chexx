import 'package:oxygen/oxygen.dart';
import '../components/position_component.dart';
import '../components/movement_component.dart';
import '../components/owner_component.dart';
import '../models/hex_coordinate.dart';
import '../interfaces/unit_factory.dart';
import '../models/game_config.dart';

/// System for handling entity movement
class MovementSystem extends System {
  late Query _positionQuery;
  late Query _movementQuery;
  late Query _ownerQuery;

  @override
  void init() {
    _positionQuery = createQuery([
      Has<PositionComponent>(),
      Has<MovementComponent>(),
    ]);
    _movementQuery = createQuery([Has<MovementComponent>()]);
    _ownerQuery = createQuery([Has<OwnerComponent>()]);
  }

  /// Check if entity can move to target position
  bool canMoveTo({
    required Entity entity,
    required HexCoordinate target,
  }) {
    final movement = entity.get<MovementComponent>();
    final position = entity.get<PositionComponent>();

    if (movement == null || position == null) return false;
    if (!movement.canMove) return false;

    final distance = position.coordinate.distanceTo(target);
    if (distance > movement.remainingMovement) return false;

    // Check if target position is occupied
    if (isPositionOccupied(target)) return false;

    // Check movement type constraints
    return isValidMovementPath(entity, target);
  }

  /// Move entity to target position
  bool moveEntity({
    required Entity entity,
    required HexCoordinate target,
  }) {
    if (!canMoveTo(entity: entity, target: target)) return false;

    final movement = entity.get<MovementComponent>()!;
    final position = entity.get<PositionComponent>()!;

    final distance = position.coordinate.distanceTo(target);
    if (movement.useMovement(distance)) {
      position.coordinate = target;
      return true;
    }

    return false;
  }

  /// Check if position is occupied by any entity
  bool isPositionOccupied(HexCoordinate coordinate) {
    for (final entity in _positionQuery.entities) {
      final position = entity.get<PositionComponent>()!;
      if (position.coordinate == coordinate) {
        return true;
      }
    }
    return false;
  }

  /// Get all valid move positions for an entity
  List<HexCoordinate> getValidMoves(Entity entity) {
    final movement = entity.get<MovementComponent>();
    final position = entity.get<PositionComponent>();

    if (movement == null || position == null) return [];

    final validMoves = <HexCoordinate>[];
    final range = movement.remainingMovement;
    final possibleMoves = HexCoordinate.hexesInRange(position.coordinate, range);

    for (final target in possibleMoves) {
      if (target != position.coordinate && canMoveTo(entity: entity, target: target)) {
        validMoves.add(target);
      }
    }

    return validMoves;
  }

  /// Validate movement path based on movement type
  bool isValidMovementPath(Entity entity, HexCoordinate target) {
    final movement = entity.get<MovementComponent>();
    final position = entity.get<PositionComponent>();

    if (movement == null || position == null) return false;

    final current = position.coordinate;

    switch (movement.movementType) {
      case MovementType.adjacent:
        return true; // Can move to any hex in range

      case MovementType.straight:
        // Can only move in straight lines
        final diff = target - current;
        return diff.q == 0 || diff.r == 0 || diff.s == 0;

      case MovementType.knight:
        // L-shaped movement pattern
        final distance = current.distanceTo(target);
        if (distance > 2) return false;

        final diff = target - current;
        final isStraightLine = diff.q == 0 || diff.r == 0 || diff.s == 0;
        return distance == 2 && !isStraightLine;

      case MovementType.custom:
        // Custom movement rules handled by game-specific logic
        return true;
    }
  }

  /// Reset movement for all entities (call at start of turn)
  void resetMovementForPlayer(Player player) {
    for (final entity in _movementQuery.entities) {
      final owner = entity.get<OwnerComponent>();
      final movement = entity.get<MovementComponent>();

      if (owner != null && movement != null && owner.owner == player) {
        movement.resetMovement();
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

  @override
  void execute(double delta) {
    // Movement system is primarily reactive - called by game logic
  }
}
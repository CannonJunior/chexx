import 'package:oxygen/oxygen.dart';
import '../models/hex_coordinate.dart';
import 'unit_factory.dart';

/// Interface for game rules and logic validation
abstract class RulesEngine {
  /// Check if a unit can move to the target position
  bool canUnitMoveTo({
    required Entity unit,
    required HexCoordinate target,
    required World world,
  });

  /// Check if a unit can attack the target position
  bool canUnitAttack({
    required Entity unit,
    required HexCoordinate target,
    required World world,
  });

  /// Get valid movement positions for a unit
  List<HexCoordinate> getValidMoves({
    required Entity unit,
    required World world,
  });

  /// Get valid attack positions for a unit
  List<HexCoordinate> getValidAttacks({
    required Entity unit,
    required World world,
  });

  /// Check victory conditions
  Player? checkVictoryCondition(World world);

  /// Validate if an action is legal in the current game state
  bool isActionValid({
    required String action,
    required Map<String, dynamic> params,
    required World world,
  });

  /// Get movement cost for a unit to move to a target
  int getMovementCost({
    required Entity unit,
    required HexCoordinate target,
    required World world,
  });

  /// Apply damage calculations with game-specific rules
  int calculateDamage({
    required Entity attacker,
    required Entity target,
    required World world,
  });
}
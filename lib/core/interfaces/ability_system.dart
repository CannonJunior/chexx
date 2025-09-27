import 'package:oxygen/oxygen.dart';
import '../models/hex_coordinate.dart';

/// Interface for special abilities and powers in the game
abstract class AbilitySystem {
  /// Get all available abilities
  List<String> getAvailableAbilities();

  /// Check if an ability can be used
  bool canUseAbility({
    required String abilityType,
    required Entity source,
    required HexCoordinate? target,
    required World world,
  });

  /// Use an ability
  bool useAbility({
    required String abilityType,
    required Entity source,
    required HexCoordinate? target,
    required World world,
  });

  /// Get ability description and details
  Map<String, dynamic> getAbilityInfo(String abilityType);

  /// Get abilities available to a specific entity
  List<String> getEntityAbilities(Entity entity, World world);

  /// Check if an ability is on cooldown
  bool isAbilityOnCooldown({
    required String abilityType,
    required Entity source,
    required World world,
  });

  /// Get remaining cooldown time for an ability
  int getAbilityCooldown({
    required String abilityType,
    required Entity source,
    required World world,
  });
}
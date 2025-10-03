import 'package:f_card_engine/f_card_engine.dart';
import 'package:oxygen/oxygen.dart';
import '../../core/interfaces/ability_system.dart';
import '../../core/models/hex_coordinate.dart';

/// Ability system for card game (stub implementation)
class CardAbilitySystem implements AbilitySystem {
  final GameStateManager _gameStateManager;

  CardAbilitySystem(this._gameStateManager);

  @override
  List<String> getAvailableAbilities() {
    // Card games don't use traditional hex-based abilities
    return [];
  }

  @override
  bool canUseAbility({
    required String abilityType,
    required Entity source,
    required HexCoordinate? target,
    required World world,
  }) {
    return false; // Card games handle abilities differently
  }

  @override
  bool useAbility({
    required String abilityType,
    required Entity source,
    required HexCoordinate? target,
    required World world,
  }) {
    return false; // Card games handle abilities differently
  }

  @override
  Map<String, dynamic> getAbilityInfo(String abilityType) {
    return {}; // Card games don't use traditional abilities
  }

  @override
  List<String> getEntityAbilities(Entity entity, World world) {
    return []; // Card games don't use traditional hex entities
  }

  @override
  bool isAbilityOnCooldown({
    required String abilityType,
    required Entity source,
    required World world,
  }) {
    return false; // Card games don't use cooldowns
  }

  @override
  int getAbilityCooldown({
    required String abilityType,
    required Entity source,
    required World world,
  }) {
    return 0; // Card games don't use cooldowns
  }
}

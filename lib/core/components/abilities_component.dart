import 'package:oxygen/oxygen.dart';

/// Component for entity abilities and cooldowns
class AbilitiesComponent extends Component<AbilitiesComponent> {
  List<String> availableAbilities;
  Map<String, int> cooldowns;

  AbilitiesComponent({
    List<String>? availableAbilities,
    Map<String, int>? cooldowns,
  }) :
    availableAbilities = availableAbilities ?? [],
    cooldowns = cooldowns ?? {};

  /// Check if ability is available (not on cooldown)
  bool isAbilityAvailable(String abilityName) {
    return availableAbilities.contains(abilityName) &&
           (cooldowns[abilityName] ?? 0) <= 0;
  }

  /// Use ability and set cooldown
  void useAbility(String abilityName, int cooldownTurns) {
    cooldowns[abilityName] = cooldownTurns;
  }

  /// Update cooldowns (call each turn)
  void updateCooldowns() {
    final keys = cooldowns.keys.toList();
    for (final key in keys) {
      cooldowns[key] = (cooldowns[key]! - 1).clamp(0, 999);
      if (cooldowns[key]! <= 0) {
        cooldowns.remove(key);
      }
    }
  }

  /// Get remaining cooldown for ability
  int getCooldown(String abilityName) {
    return cooldowns[abilityName] ?? 0;
  }

  @override
  void init([AbilitiesComponent? data]) {
    availableAbilities = data?.availableAbilities ?? [];
    cooldowns = data?.cooldowns ?? {};
  }

  @override
  void reset() {
    availableAbilities.clear();
    cooldowns.clear();
  }
}
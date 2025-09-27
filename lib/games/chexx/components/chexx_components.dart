import 'package:oxygen/oxygen.dart';

/// Component for unit level and experience
class LevelComponent extends Component<LevelComponent> {
  int level;
  int experience;
  int experienceToNextLevel;

  LevelComponent({
    this.level = 1,
    this.experience = 0,
    int? experienceToNextLevel,
  }) : experienceToNextLevel = experienceToNextLevel ?? (level * 2);

  /// Get experience progress (0.0 to 1.0)
  double get experienceProgress => experience / experienceToNextLevel;

  /// Gain experience and potentially level up
  bool gainExperience(int exp) {
    experience += exp;
    if (experience >= experienceToNextLevel) {
      level++;
      experience -= experienceToNextLevel;
      experienceToNextLevel = level * 2;
      return true; // Leveled up
    }
    return false; // No level up
  }

  @override
  void init([LevelComponent? data]) {
    level = data?.level ?? 1;
    experience = data?.experience ?? 0;
    experienceToNextLevel = data?.experienceToNextLevel ?? (level * 2);
  }

  @override
  void reset() {
    level = 1;
    experience = 0;
    experienceToNextLevel = 2;
  }
}

/// Component for tracking experience gained
class ExperienceComponent extends Component<ExperienceComponent> {
  int totalExperience;

  ExperienceComponent({this.totalExperience = 0});

  @override
  void init([ExperienceComponent? data]) {
    totalExperience = data?.totalExperience ?? 0;
  }

  @override
  void reset() {
    totalExperience = 0;
  }
}

/// Component for meta hex abilities
class MetaAbilityComponent extends Component<MetaAbilityComponent> {
  List<String> availableAbilities;
  Map<String, int> cooldowns;
  bool isMetaHex;

  MetaAbilityComponent({
    List<String>? availableAbilities,
    Map<String, int>? cooldowns,
    this.isMetaHex = false,
  }) :
    availableAbilities = availableAbilities ?? [],
    cooldowns = cooldowns ?? {};

  /// Check if ability is available
  bool isAbilityAvailable(String abilityName) {
    return availableAbilities.contains(abilityName) &&
           (cooldowns[abilityName] ?? 0) <= 0;
  }

  /// Use ability and set cooldown
  void useAbility(String abilityName, int cooldownTurns) {
    cooldowns[abilityName] = cooldownTurns;
  }

  /// Update cooldowns
  void updateCooldowns() {
    final keys = cooldowns.keys.toList();
    for (final key in keys) {
      cooldowns[key] = (cooldowns[key]! - 1).clamp(0, 999);
      if (cooldowns[key]! <= 0) {
        cooldowns.remove(key);
      }
    }
  }

  @override
  void init([MetaAbilityComponent? data]) {
    availableAbilities = data?.availableAbilities ?? [];
    cooldowns = data?.cooldowns ?? {};
    isMetaHex = data?.isMetaHex ?? false;
  }

  @override
  void reset() {
    availableAbilities.clear();
    cooldowns.clear();
    isMetaHex = false;
  }
}
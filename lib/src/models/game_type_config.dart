import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Enumeration of turn system types
enum TurnSystemType {
  multipleUnitsPerTurn,
  singleUnitPerTurn,
}

/// Enumeration of damage system types
enum DamageSystemType {
  standard,
  wwiiCombat,
}

/// Configuration for action cards resource system
class ActionCardsConfig {
  final bool enabled;
  final int cardsPerPlayer;
  final bool configurable;
  final int minCards;
  final int maxCards;

  const ActionCardsConfig({
    required this.enabled,
    required this.cardsPerPlayer,
    this.configurable = false,
    this.minCards = 0,
    this.maxCards = 10,
  });

  factory ActionCardsConfig.fromJson(Map<String, dynamic> json) {
    return ActionCardsConfig(
      enabled: json['enabled'] as bool,
      cardsPerPlayer: json['cards_per_player'] as int,
      configurable: json['configurable'] as bool? ?? false,
      minCards: json['min_cards'] as int? ?? 0,
      maxCards: json['max_cards'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'cards_per_player': cardsPerPlayer,
      'configurable': configurable,
      'min_cards': minCards,
      'max_cards': maxCards,
    };
  }
}

/// Configuration for time limit system
class TimeLimitConfig {
  final bool enabled;
  final int secondsPerTurn;

  const TimeLimitConfig({
    required this.enabled,
    required this.secondsPerTurn,
  });

  factory TimeLimitConfig.fromJson(Map<String, dynamic> json) {
    return TimeLimitConfig(
      enabled: json['enabled'] as bool,
      secondsPerTurn: json['seconds_per_turn'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'seconds_per_turn': secondsPerTurn,
    };
  }
}

/// Configuration for turn system
class TurnSystemConfig {
  final TurnSystemType type;
  final String description;

  const TurnSystemConfig({
    required this.type,
    required this.description,
  });

  factory TurnSystemConfig.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String;
    final type = typeString == 'single_unit_per_turn'
        ? TurnSystemType.singleUnitPerTurn
        : TurnSystemType.multipleUnitsPerTurn;

    return TurnSystemConfig(
      type: type,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final typeString = type == TurnSystemType.singleUnitPerTurn
        ? 'single_unit_per_turn'
        : 'multiple_units_per_turn';

    return {
      'type': typeString,
      'description': description,
    };
  }
}

/// Configuration for resources in the game
class ResourcesConfig {
  final ActionCardsConfig actionCards;
  final TimeLimitConfig timeLimit;

  const ResourcesConfig({
    required this.actionCards,
    required this.timeLimit,
  });

  factory ResourcesConfig.fromJson(Map<String, dynamic> json) {
    return ResourcesConfig(
      actionCards: ActionCardsConfig.fromJson(json['action_cards'] as Map<String, dynamic>),
      timeLimit: TimeLimitConfig.fromJson(json['time_limit'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action_cards': actionCards.toJson(),
      'time_limit': timeLimit.toJson(),
    };
  }
}

/// Configuration for combat system
class CombatConfig {
  final DamageSystemType damageSystem;
  final String description;

  const CombatConfig({
    required this.damageSystem,
    required this.description,
  });

  factory CombatConfig.fromJson(Map<String, dynamic> json) {
    final systemString = json['damage_system'] as String;
    final damageSystem = systemString == 'wwii_combat'
        ? DamageSystemType.wwiiCombat
        : DamageSystemType.standard;

    return CombatConfig(
      damageSystem: damageSystem,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final systemString = damageSystem == DamageSystemType.wwiiCombat
        ? 'wwii_combat'
        : 'standard';

    return {
      'damage_system': systemString,
      'description': description,
    };
  }
}

/// Configuration for meta abilities
class MetaAbilitiesConfig {
  final bool enabled;
  final int spawnCost;
  final int healCost;

  const MetaAbilitiesConfig({
    required this.enabled,
    required this.spawnCost,
    required this.healCost,
  });

  factory MetaAbilitiesConfig.fromJson(Map<String, dynamic> json) {
    return MetaAbilitiesConfig(
      enabled: json['enabled'] as bool,
      spawnCost: json['spawn_cost'] as int,
      healCost: json['heal_cost'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'spawn_cost': spawnCost,
      'heal_cost': healCost,
    };
  }
}

/// Configuration for a single game type
class GameTypeConfig {
  final String id;
  final String name;
  final String description;
  final String version;
  final TurnSystemConfig turnSystem;
  final ResourcesConfig resources;
  final CombatConfig combat;
  final MetaAbilitiesConfig metaAbilities;
  final String defaultUnitSet;

  const GameTypeConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.turnSystem,
    required this.resources,
    required this.combat,
    required this.metaAbilities,
    required this.defaultUnitSet,
  });

  factory GameTypeConfig.fromJson(String id, Map<String, dynamic> json) {
    return GameTypeConfig(
      id: id,
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      turnSystem: TurnSystemConfig.fromJson(json['turn_system'] as Map<String, dynamic>),
      resources: ResourcesConfig.fromJson(json['resources'] as Map<String, dynamic>),
      combat: CombatConfig.fromJson(json['combat'] as Map<String, dynamic>),
      metaAbilities: MetaAbilitiesConfig.fromJson(json['meta_abilities'] as Map<String, dynamic>),
      defaultUnitSet: json['default_unit_set'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'version': version,
      'turn_system': turnSystem.toJson(),
      'resources': resources.toJson(),
      'combat': combat.toJson(),
      'meta_abilities': metaAbilities.toJson(),
      'default_unit_set': defaultUnitSet,
    };
  }
}

/// Loader for game type configurations
class GameTypeConfigLoader {
  static const String _configBasePath = 'lib/configs/game_types/';

  /// Available game type sets
  static const Map<String, String> availableGameTypes = {
    'chexx': 'chexx_game.json',
    'wwii': 'wwii_game.json',
  };

  /// Load a game type configuration by ID
  static Future<GameTypeConfig> loadGameTypeConfig(String gameTypeId) async {
    final fileName = availableGameTypes[gameTypeId];
    if (fileName == null) {
      throw ArgumentError('Unknown game type: $gameTypeId');
    }

    try {
      final jsonString = await rootBundle.loadString('$_configBasePath$fileName');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return GameTypeConfig.fromJson(gameTypeId, jsonData);
    } catch (e) {
      throw Exception('Failed to load game type "$gameTypeId": $e');
    }
  }

  /// Get list of available game type IDs
  static List<String> getAvailableGameTypeIds() => availableGameTypes.keys.toList();

  /// Get display names for available game types
  static Map<String, String> getAvailableGameTypeDisplayNames() {
    return {
      'chexx': 'CHEXX Game System',
      'wwii': 'WWII Game System',
    };
  }
}
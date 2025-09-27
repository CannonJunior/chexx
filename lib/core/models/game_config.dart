/// Configuration class for game rules and parameters
class GameConfig {
  final Map<String, UnitTypeConfig> unitTypes;
  final Map<String, AbilityConfig> abilities;
  final BoardConfig boardConfig;
  final VictoryConditions victoryConditions;
  final GameplayRules rules;

  const GameConfig({
    required this.unitTypes,
    required this.abilities,
    required this.boardConfig,
    required this.victoryConditions,
    required this.rules,
  });

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      unitTypes: (json['unitTypes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, UnitTypeConfig.fromJson(value)),
      ),
      abilities: (json['abilities'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, AbilityConfig.fromJson(value)),
      ),
      boardConfig: BoardConfig.fromJson(json['boardConfig']),
      victoryConditions: VictoryConditions.fromJson(json['victoryConditions']),
      rules: GameplayRules.fromJson(json['rules']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unitTypes': unitTypes.map((key, value) => MapEntry(key, value.toJson())),
      'abilities': abilities.map((key, value) => MapEntry(key, value.toJson())),
      'boardConfig': boardConfig.toJson(),
      'victoryConditions': victoryConditions.toJson(),
      'rules': rules.toJson(),
    };
  }
}

/// Configuration for a unit type
class UnitTypeConfig {
  final String name;
  final String displayName;
  final int maxHealth;
  final int attackDamage;
  final int attackRange;
  final int movementRange;
  final List<String> abilities;
  final MovementType movementType;
  final Map<String, dynamic> properties;

  const UnitTypeConfig({
    required this.name,
    required this.displayName,
    required this.maxHealth,
    required this.attackDamage,
    required this.attackRange,
    required this.movementRange,
    required this.abilities,
    required this.movementType,
    this.properties = const {},
  });

  factory UnitTypeConfig.fromJson(Map<String, dynamic> json) {
    return UnitTypeConfig(
      name: json['name'],
      displayName: json['displayName'],
      maxHealth: json['maxHealth'],
      attackDamage: json['attackDamage'],
      attackRange: json['attackRange'],
      movementRange: json['movementRange'],
      abilities: List<String>.from(json['abilities'] ?? []),
      movementType: MovementType.values.firstWhere(
        (e) => e.name == json['movementType'],
        orElse: () => MovementType.adjacent,
      ),
      properties: json['properties'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'maxHealth': maxHealth,
      'attackDamage': attackDamage,
      'attackRange': attackRange,
      'movementRange': movementRange,
      'abilities': abilities,
      'movementType': movementType.name,
      'properties': properties,
    };
  }
}

/// Movement types for units
enum MovementType {
  adjacent,     // Can move to any adjacent hex
  straight,     // Can only move in straight lines
  knight,       // L-shaped movement pattern
  custom,       // Custom movement rules
}

/// Configuration for an ability
class AbilityConfig {
  final String name;
  final String displayName;
  final String description;
  final int cooldown;
  final int range;
  final String targetType;
  final Map<String, dynamic> effects;

  const AbilityConfig({
    required this.name,
    required this.displayName,
    required this.description,
    required this.cooldown,
    required this.range,
    required this.targetType,
    required this.effects,
  });

  factory AbilityConfig.fromJson(Map<String, dynamic> json) {
    return AbilityConfig(
      name: json['name'],
      displayName: json['displayName'],
      description: json['description'],
      cooldown: json['cooldown'],
      range: json['range'],
      targetType: json['targetType'],
      effects: json['effects'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'description': description,
      'cooldown': cooldown,
      'range': range,
      'targetType': targetType,
      'effects': effects,
    };
  }
}

/// Board configuration
class BoardConfig {
  final int width;
  final int height;
  final List<String> terrainTypes;
  final Map<String, TerrainConfig> terrainConfigs;

  const BoardConfig({
    required this.width,
    required this.height,
    required this.terrainTypes,
    required this.terrainConfigs,
  });

  factory BoardConfig.fromJson(Map<String, dynamic> json) {
    return BoardConfig(
      width: json['width'],
      height: json['height'],
      terrainTypes: List<String>.from(json['terrainTypes'] ?? []),
      terrainConfigs: (json['terrainConfigs'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, TerrainConfig.fromJson(value)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'terrainTypes': terrainTypes,
      'terrainConfigs': terrainConfigs.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

/// Terrain configuration
class TerrainConfig {
  final String name;
  final String displayName;
  final int movementCost;
  final bool blocksMovement;
  final bool blocksLineOfSight;
  final Map<String, dynamic> properties;

  const TerrainConfig({
    required this.name,
    required this.displayName,
    required this.movementCost,
    required this.blocksMovement,
    required this.blocksLineOfSight,
    this.properties = const {},
  });

  factory TerrainConfig.fromJson(Map<String, dynamic> json) {
    return TerrainConfig(
      name: json['name'],
      displayName: json['displayName'],
      movementCost: json['movementCost'],
      blocksMovement: json['blocksMovement'],
      blocksLineOfSight: json['blocksLineOfSight'],
      properties: json['properties'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'movementCost': movementCost,
      'blocksMovement': blocksMovement,
      'blocksLineOfSight': blocksLineOfSight,
      'properties': properties,
    };
  }
}

/// Victory conditions
class VictoryConditions {
  final String type;
  final Map<String, dynamic> parameters;

  const VictoryConditions({
    required this.type,
    required this.parameters,
  });

  factory VictoryConditions.fromJson(Map<String, dynamic> json) {
    return VictoryConditions(
      type: json['type'],
      parameters: json['parameters'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'parameters': parameters,
    };
  }
}

/// General gameplay rules
class GameplayRules {
  final int maxPlayers;
  final double turnTimeLimit;
  final bool allowUndoMoves;
  final Map<String, dynamic> customRules;

  const GameplayRules({
    required this.maxPlayers,
    required this.turnTimeLimit,
    required this.allowUndoMoves,
    this.customRules = const {},
  });

  factory GameplayRules.fromJson(Map<String, dynamic> json) {
    return GameplayRules(
      maxPlayers: json['maxPlayers'],
      turnTimeLimit: (json['turnTimeLimit'] as num).toDouble(),
      allowUndoMoves: json['allowUndoMoves'],
      customRules: json['customRules'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxPlayers': maxPlayers,
      'turnTimeLimit': turnTimeLimit,
      'allowUndoMoves': allowUndoMoves,
      'customRules': customRules,
    };
  }
}
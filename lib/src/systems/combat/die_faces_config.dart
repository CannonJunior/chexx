import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

/// Configuration for a single die face
class DieFace {
  final String unitType;
  final String symbol;
  final String description;

  const DieFace({
    required this.unitType,
    required this.symbol,
    required this.description,
  });

  factory DieFace.fromJson(Map<String, dynamic> json) {
    return DieFace(
      unitType: json['unit_type'] as String,
      symbol: json['symbol'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit_type': unitType,
      'symbol': symbol,
      'description': description,
    };
  }

  @override
  String toString() => '$symbol ($unitType)';
}

/// Die specifications configuration
class DieSpecifications {
  final int sides;
  final String type;

  const DieSpecifications({
    required this.sides,
    required this.type,
  });

  factory DieSpecifications.fromJson(Map<String, dynamic> json) {
    return DieSpecifications(
      sides: json['sides'] as int,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sides': sides,
      'type': type,
    };
  }
}

/// Combat effectiveness modifiers
class CombatModifiers {
  final String description;
  final Map<String, Map<String, int>> effectiveness;

  const CombatModifiers({
    required this.description,
    required this.effectiveness,
  });

  factory CombatModifiers.fromJson(Map<String, dynamic> json) {
    final effectivenessJson = json['effectiveness'] as Map<String, dynamic>;
    final effectiveness = <String, Map<String, int>>{};

    for (final entry in effectivenessJson.entries) {
      final dieFaceType = entry.key;
      final unitModifiers = entry.value as Map<String, dynamic>;
      final modifiers = <String, int>{};

      for (final unitEntry in unitModifiers.entries) {
        modifiers[unitEntry.key] = (unitEntry.value as num).toInt();
      }

      effectiveness[dieFaceType] = modifiers;
    }

    return CombatModifiers(
      description: json['description'] as String,
      effectiveness: effectiveness,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'effectiveness': effectiveness,
    };
  }

  /// Get effectiveness modifier for die face vs tile type
  int getEffectiveness(String dieFaceType, String tileType) {
    return effectiveness[dieFaceType]?[tileType] ?? 1; // Default to 1 if not found
  }

  /// Get all available die face types
  Set<String> getAvailableDieFaceTypes() {
    return effectiveness.keys.toSet();
  }

  /// Get all available tile types for a specific die face
  Set<String> getAvailableTileTypes(String dieFaceType) {
    return effectiveness[dieFaceType]?.keys.toSet() ?? {};
  }
}

/// Complete die faces configuration
class DieFacesConfig {
  final String name;
  final String description;
  final String version;
  final DieSpecifications dieSpecifications;
  final Map<int, DieFace> dieFaces;
  final CombatModifiers combatModifiers;

  const DieFacesConfig({
    required this.name,
    required this.description,
    required this.version,
    required this.dieSpecifications,
    required this.dieFaces,
    required this.combatModifiers,
  });

  factory DieFacesConfig.fromJson(Map<String, dynamic> json) {
    final dieFacesJson = json['die_faces'] as Map<String, dynamic>;
    final dieFaces = <int, DieFace>{};

    for (final entry in dieFacesJson.entries) {
      final faceNumber = int.parse(entry.key);
      dieFaces[faceNumber] = DieFace.fromJson(entry.value as Map<String, dynamic>);
    }

    return DieFacesConfig(
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      dieSpecifications: DieSpecifications.fromJson(json['die_specifications'] as Map<String, dynamic>),
      dieFaces: dieFaces,
      combatModifiers: CombatModifiers.fromJson(json['combat_modifiers'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    final dieFacesJson = <String, dynamic>{};
    for (final entry in dieFaces.entries) {
      dieFacesJson[entry.key.toString()] = entry.value.toJson();
    }

    return {
      'name': name,
      'description': description,
      'version': version,
      'die_specifications': dieSpecifications.toJson(),
      'die_faces': dieFacesJson,
      'combat_modifiers': combatModifiers.toJson(),
    };
  }

  /// Roll a single die and return the result
  DieFace rollDie([Random? random]) {
    final rng = random ?? Random();
    final roll = rng.nextInt(dieSpecifications.sides) + 1;
    return dieFaces[roll]!;
  }

  /// Roll multiple dice and return all results
  List<DieFace> rollDice(int count, [Random? random]) {
    final results = <DieFace>[];
    for (int i = 0; i < count; i++) {
      results.add(rollDie(random));
    }
    return results;
  }

  /// Get all possible unit types that can appear on the die
  Set<String> getAvailableUnitTypes() {
    return dieFaces.values.map((face) => face.unitType).toSet();
  }

  /// Get effectiveness modifier for die face vs tile type
  int getCombatEffectiveness(String dieFaceType, String tileType) {
    return combatModifiers.getEffectiveness(dieFaceType, tileType);
  }
}

/// Loader for die faces configuration
class DieFacesConfigLoader {
  static const String _configPath = 'lib/configs/combat_systems/die_faces.json';

  /// Load the die faces configuration
  static Future<DieFacesConfig> loadDieFacesConfig() async {
    try {
      final jsonString = await rootBundle.loadString(_configPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return DieFacesConfig.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load die faces configuration: $e');
    }
  }
}
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Represents a combat hit result
enum CombatHitResult {
  hit,
  miss,
  retreat,
  cardAction,
}

/// Hit lookup configuration for WWII combat
class WWIIHitLookupTables {
  final Map<String, Map<String, dynamic>> tables;

  const WWIIHitLookupTables({required this.tables});

  factory WWIIHitLookupTables.fromJson(Map<String, dynamic> json) {
    final tables = <String, Map<String, dynamic>>{};
    for (final entry in json.entries) {
      tables[entry.key] = Map<String, dynamic>.from(entry.value as Map);
    }
    return WWIIHitLookupTables(tables: tables);
  }

  /// Get hit result for a die face vs target unit type
  CombatHitResult getHitResult(String dieFace, String targetUnitType) {
    final faceTable = tables[dieFace];
    if (faceTable == null) return CombatHitResult.miss;

    final result = faceTable[targetUnitType];
    if (result == null) return CombatHitResult.miss;

    switch (result) {
      case true:
        return CombatHitResult.hit;
      case false:
        return CombatHitResult.miss;
      case 'retreat':
        return CombatHitResult.retreat;
      case 'card_action':
        return CombatHitResult.cardAction;
      default:
        return CombatHitResult.miss;
    }
  }

  /// Check if a die face hits a target unit type
  bool isHit(String dieFace, String targetUnitType) {
    return getHitResult(dieFace, targetUnitType) == CombatHitResult.hit;
  }

  /// Get all available die face types
  Set<String> getAvailableDieFaces() {
    return tables.keys.toSet();
  }

  /// Get all available target unit types for a die face
  Set<String> getAvailableTargetTypes(String dieFace) {
    return tables[dieFace]?.keys.toSet() ?? {};
  }
}

/// Combat configuration for WWII game system
class WWIICombatConfig {
  final String damageSystem;
  final String description;
  final WWIIHitLookupTables hitLookupTables;

  const WWIICombatConfig({
    required this.damageSystem,
    required this.description,
    required this.hitLookupTables,
  });

  factory WWIICombatConfig.fromJson(Map<String, dynamic> json) {
    return WWIICombatConfig(
      damageSystem: json['damage_system'] as String,
      description: json['description'] as String,
      hitLookupTables: WWIIHitLookupTables.fromJson(
        json['hit_lookup_tables'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Complete WWII game configuration
class WWIIGameConfig {
  final String name;
  final String description;
  final String version;
  final String id;
  final WWIICombatConfig combat;

  const WWIIGameConfig({
    required this.name,
    required this.description,
    required this.version,
    required this.id,
    required this.combat,
  });

  factory WWIIGameConfig.fromJson(Map<String, dynamic> json) {
    return WWIIGameConfig(
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      id: json['id'] as String,
      combat: WWIICombatConfig.fromJson(json['combat'] as Map<String, dynamic>),
    );
  }
}

/// Loader for WWII game configuration
class WWIIGameConfigLoader {
  static const String _configPath = 'lib/configs/game_types/wwii_game.json';

  /// Load the WWII game configuration
  static Future<WWIIGameConfig> loadWWIIGameConfig() async {
    try {
      final jsonString = await rootBundle.loadString(_configPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return WWIIGameConfig.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load WWII game configuration: $e');
    }
  }
}
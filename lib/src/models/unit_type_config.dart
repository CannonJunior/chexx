import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Configuration for a single unit type
class UnitTypeConfig {
  final String id;
  final String name;
  final int health;
  final int maxHealth;
  final int movementRange;
  final int attackRange;
  final dynamic attackDamage; // Can be int (legacy) or List<int> (WWII style)
  final String movementType;
  final bool isIncrementable;
  final String symbol;
  final String description;
  final String? gameType; // Associated game type (e.g., 'chexx', 'wwii')
  final Map<String, dynamic>? special;

  const UnitTypeConfig({
    required this.id,
    required this.name,
    required this.health,
    required this.maxHealth,
    required this.movementRange,
    required this.attackRange,
    required this.attackDamage,
    required this.movementType,
    required this.isIncrementable,
    required this.symbol,
    required this.description,
    this.gameType,
    this.special,
  });

  factory UnitTypeConfig.fromJson(String id, Map<String, dynamic> json) {
    // Handle attack_damage as either int or List<int>
    final attackDamageJson = json['attack_damage'];
    dynamic attackDamage;
    if (attackDamageJson is List) {
      attackDamage = List<int>.from(attackDamageJson);
    } else {
      attackDamage = attackDamageJson as int;
    }

    return UnitTypeConfig(
      id: id,
      name: json['name'] as String,
      health: json['health'] as int,
      maxHealth: json['max_health'] as int? ?? json['health'] as int, // Fallback to health if max_health not present
      movementRange: json['movement_range'] as int,
      attackRange: json['attack_range'] as int,
      attackDamage: attackDamage,
      movementType: json['movement_type'] as String,
      isIncrementable: json['is_incrementable'] as bool,
      symbol: json['symbol'] as String,
      description: json['description'] as String,
      gameType: json['game_type'] as String?,
      special: json['special'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'health': health,
      'max_health': maxHealth,
      'movement_range': movementRange,
      'attack_range': attackRange,
      'attack_damage': attackDamage,
      'movement_type': movementType,
      'is_incrementable': isIncrementable,
      'symbol': symbol,
      'description': description,
      if (gameType != null) 'game_type': gameType,
      if (special != null) 'special': special,
    };
  }

  /// Get attack damage as a single integer (for legacy/CHEXX units)
  int get attackDamageAsInt {
    if (attackDamage is int) {
      return attackDamage as int;
    } else if (attackDamage is List<int>) {
      // For WWII units, return the length of the array as the "damage"
      return (attackDamage as List<int>).length;
    }
    return 1; // Fallback
  }

  /// Get attack damage as a list (for WWII units)
  List<int> get attackDamageAsList {
    if (attackDamage is List<int>) {
      return attackDamage as List<int>;
    } else if (attackDamage is int) {
      // Convert single integer to list for compatibility
      return List.filled(attackDamage as int, 1);
    }
    return [1]; // Fallback
  }

  /// Check if this unit uses WWII-style array-based attack damage
  bool get usesWWIIAttackSystem {
    return attackDamage is List<int> || gameType == 'wwii';
  }

  /// Check if this unit belongs to a specific game type
  bool belongsToGameType(String type) {
    return gameType == type;
  }
}

/// Configuration set for a collection of unit types
class UnitTypeSet {
  final String name;
  final String description;
  final String version;
  final Map<String, UnitTypeConfig> units;

  const UnitTypeSet({
    required this.name,
    required this.description,
    required this.version,
    required this.units,
  });

  factory UnitTypeSet.fromJson(Map<String, dynamic> json) {
    final unitsJson = json['units'] as Map<String, dynamic>;
    final units = <String, UnitTypeConfig>{};

    for (final entry in unitsJson.entries) {
      units[entry.key] = UnitTypeConfig.fromJson(
        entry.key,
        entry.value as Map<String, dynamic>,
      );
    }

    return UnitTypeSet(
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      units: units,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'version': version,
      'units': units.map((key, config) => MapEntry(key, config.toJson())),
    };
  }

  /// Get all unit type IDs in this set
  List<String> get unitTypeIds => units.keys.toList();

  /// Get configuration for a specific unit type
  UnitTypeConfig? getUnitConfig(String unitTypeId) => units[unitTypeId];

  /// Check if a unit type exists in this set
  bool hasUnitType(String unitTypeId) => units.containsKey(unitTypeId);
}

/// Loader for unit type configurations
class UnitTypeConfigLoader {
  static const String _configBasePath = 'lib/configs/unit_types/';

  /// Available unit type sets
  static const Map<String, String> availableSets = {
    'chexx': 'chexx_units.json',
    'wwii': 'wwii_units.json',
  };

  /// Load a unit type set by name
  static Future<UnitTypeSet> loadUnitTypeSet(String setName) async {
    final fileName = availableSets[setName];
    if (fileName == null) {
      throw ArgumentError('Unknown unit type set: $setName');
    }

    try {
      final jsonString = await rootBundle.loadString('$_configBasePath$fileName');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return UnitTypeSet.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load unit type set "$setName": $e');
    }
  }

  /// Get list of available unit type set names
  static List<String> getAvailableSetNames() => availableSets.keys.toList();

  /// Get display names for available sets
  static Map<String, String> getAvailableSetDisplayNames() {
    return {
      'chexx': 'CHEXX Units',
      'wwii': 'WWII Units',
    };
  }
}
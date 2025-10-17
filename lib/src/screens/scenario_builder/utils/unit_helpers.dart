import 'package:flutter/material.dart';
import 'package:chexx/core/interfaces/unit_factory.dart';
import '../../../models/game_board.dart';
import '../../../models/game_state.dart';
import '../../../models/scenario_builder_state.dart';
import '../../../models/unit_type_config.dart';

/// Helper class for unit-related operations in the scenario builder
class UnitHelpers {
  /// Convert string unit type ID back to enum (compatibility)
  static UnitType stringToUnitType(String unitTypeId) {
    switch (unitTypeId) {
      case 'minor':
        return UnitType.minor;
      case 'scout':
        return UnitType.scout;
      case 'knight':
        return UnitType.knight;
      case 'guardian':
        return UnitType.guardian;
      case 'infantry':
        return UnitType.minor; // Map infantry to minor for compatibility
      case 'armor':
        return UnitType.knight; // Map armor to knight for compatibility
      case 'artillery':
        return UnitType.scout; // Map artillery to scout for compatibility
      default:
        return UnitType.minor; // Default fallback
    }
  }

  /// Get the actual unit type ID from the template (reverse mapping)
  static String getUnitTypeIdFromTemplate(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    if (currentUnitTypeSet == null) {
      return template.type.toString().split('.').last;
    }

    // First, try to extract the unit type ID directly from template.id
    // Template IDs are formatted as 'p1_unitTypeId' or 'p2_unitTypeId'
    for (final unitTypeId in currentUnitTypeSet.unitTypeIds) {
      if (template.id.contains(unitTypeId)) {
        // Found the unit type ID in the template ID
        return unitTypeId;
      }
    }

    // Fallback: Look through the current unit type set to find matching type
    for (final unitTypeId in currentUnitTypeSet.unitTypeIds) {
      final mappedType = stringToUnitType(unitTypeId);
      if (mappedType == template.type) {
        return unitTypeId;
      }
    }

    // Final fallback to enum name
    return template.type.toString().split('.').last;
  }

  /// Get the actual unit config for a template
  static UnitTypeConfig? getUnitConfigFromTemplate(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final unitTypeId = getUnitTypeIdFromTemplate(template, currentUnitTypeSet);
    return currentUnitTypeSet?.getUnitConfig(unitTypeId);
  }

  /// Get display name from config or fallback to enum
  static String getActualUnitName(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    print('DEBUG: getActualUnitName - Template ID: ${template.id}, Type: ${template.type.name}');

    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    if (config != null) {
      print('DEBUG: getActualUnitName - Using config name: ${config.name}');
      return config.name;
    }

    // Extract unit type from template ID for WWII units
    if (template.id.contains('_')) {
      final parts = template.id.split('_');
      if (parts.length > 1) {
        final unitTypeFromId = parts[1]; // e.g., "p1_infantry" -> "infantry"
        print('DEBUG: getActualUnitName - Extracted from ID: $unitTypeFromId');

        // Convert to proper display names
        switch (unitTypeFromId.toLowerCase()) {
          case 'infantry':
            print('VALIDATION TEST: Unit name display - Infantry unit correctly identified and named');
            return 'Infantry';
          case 'armor':
            print('VALIDATION TEST: Unit name display - Armor unit correctly identified and named');
            return 'Armor';
          case 'artillery':
            print('VALIDATION TEST: Unit name display - Artillery unit correctly identified and named');
            return 'Artillery';
          default:
            print('DEBUG: getActualUnitName - Unknown type from ID, falling back to enum');
            return getUnitTypeName(template.type);
        }
      }
    }

    print('DEBUG: getActualUnitName - Falling back to enum name');
    return getUnitTypeName(template.type);
  }

  /// Get display symbol from config or fallback to enum
  static String getActualUnitSymbol(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    print('DEBUG: getActualUnitSymbol - Template ID: ${template.id}, Type: ${template.type.name}');

    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    if (config != null) {
      print('DEBUG: getActualUnitSymbol - Using config symbol: ${config.symbol}');
      return config.symbol;
    }

    // Extract unit type from template ID for WWII units
    if (template.id.contains('_')) {
      final parts = template.id.split('_');
      if (parts.length > 1) {
        final unitTypeFromId = parts[1]; // e.g., "p1_infantry" -> "infantry"
        print('DEBUG: getActualUnitSymbol - Extracted from ID: $unitTypeFromId');

        // Convert to proper symbols for WWII units
        switch (unitTypeFromId.toLowerCase()) {
          case 'infantry':
            return 'I';
          case 'armor':
            return 'A';
          case 'artillery':
            return 'R';
          default:
            print('DEBUG: getActualUnitSymbol - Unknown type from ID, falling back to enum');
            return getUnitSymbol(template.type);
        }
      }
    }

    print('DEBUG: getActualUnitSymbol - Falling back to enum symbol');
    return getUnitSymbol(template.type);
  }

  /// Get unit symbol from enum
  static String getUnitSymbol(UnitType type) {
    switch (type) {
      case UnitType.minor:
        return 'M';
      case UnitType.scout:
        return 'S';
      case UnitType.knight:
        return 'K';
      case UnitType.guardian:
        return 'G';
    }
  }

  /// Get unit type name for display
  static String getUnitTypeName(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 'Minor Unit';
      case UnitType.scout:
        return 'Scout';
      case UnitType.knight:
        return 'Knight';
      case UnitType.guardian:
        return 'Guardian';
    }
  }

  /// Get unit max health from enum
  static int getUnitMaxHealth(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 2;
      case UnitType.scout:
        return 2;
      case UnitType.knight:
        return 3;
      case UnitType.guardian:
        return 3;
    }
  }

  /// Get unit movement range from enum
  static int getUnitMovementRange(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 1;
      case UnitType.scout:
        return 3;
      case UnitType.knight:
        return 2;
      case UnitType.guardian:
        return 1;
    }
  }

  /// Get unit attack range from enum
  static int getUnitAttackRange(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 1;
      case UnitType.scout:
        return 3;
      case UnitType.knight:
        return 2;
      case UnitType.guardian:
        return 1;
    }
  }

  /// Get unit attack damage from enum
  static int getUnitAttackDamage(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 1;
      case UnitType.scout:
        return 1;
      case UnitType.knight:
        return 2;
      case UnitType.guardian:
        return 1;
    }
  }

  /// Get isIncrementable property for unit type from enum
  static bool getIsIncrementable(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return true;
      case UnitType.guardian:
        return true;
      case UnitType.scout:
        return false;
      case UnitType.knight:
        return false;
    }
  }

  /// Get movement type for unit type
  static String getMovementType(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 'adjacent';
      case UnitType.scout:
        return 'straight_line';
      case UnitType.knight:
        return 'l_shaped';
      case UnitType.guardian:
        return 'adjacent';
    }
  }

  /// Get can swap property for unit type
  static bool getCanSwap(UnitType unitType) {
    switch (unitType) {
      case UnitType.guardian:
        return true;
      case UnitType.minor:
      case UnitType.scout:
      case UnitType.knight:
        return false;
    }
  }

  /// Get base experience for unit type
  static int getBaseExperience(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 0;
      case UnitType.scout:
        return 10;
      case UnitType.knight:
        return 15;
      case UnitType.guardian:
        return 5;
    }
  }

  /// Get level cap for unit type
  static int getLevelCap(UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
        return 5;
      case UnitType.scout:
        return 3;
      case UnitType.knight:
        return 4;
      case UnitType.guardian:
        return 6;
    }
  }

  // Configuration-aware methods that use actual loaded unit data

  /// Get max health from configuration or fallback to enum
  static int getActualUnitMaxHealth(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    return config?.maxHealth ?? getUnitMaxHealth(template.type);
  }

  /// Get movement range from configuration or fallback to enum
  static int getActualUnitMovementRange(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    return config?.movementRange ?? getUnitMovementRange(template.type);
  }

  /// Get attack range from configuration or fallback to enum
  static int getActualUnitAttackRange(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    return config?.attackRange ?? getUnitAttackRange(template.type);
  }

  /// Get attack damage from configuration or fallback to enum
  static int getActualUnitAttackDamage(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    return config?.attackDamage ?? getUnitAttackDamage(template.type);
  }

  /// Get isIncrementable from configuration or fallback to enum
  static bool getActualIsIncrementable(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    return config?.isIncrementable ?? getIsIncrementable(template.type);
  }

  /// Get movement type from configuration or fallback to enum
  static String getActualMovementType(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    return config?.movementType ?? getMovementType(template.type);
  }

  /// Get starting health from configuration or fallback to enum
  static int getActualUnitStartingHealth(UnitTemplate template, UnitTypeSet? currentUnitTypeSet) {
    final config = getUnitConfigFromTemplate(template, currentUnitTypeSet);
    return config?.health ?? 1; // Default starting health is 1
  }

  /// Get current health of a placed unit
  static int getCurrentHealth(PlacedUnit unit, UnitTypeSet? currentUnitTypeSet) {
    return unit.customHealth ?? getActualUnitStartingHealth(unit.template, currentUnitTypeSet);
  }
}

/// Helper class for tile and structure icons and colors
class TileStructureHelpers {
  /// Get icon for tile type
  static IconData getTileTypeIcon(HexType tileType) {
    switch (tileType) {
      case HexType.normal:
        return Icons.hexagon_outlined;
      case HexType.meta:
        return Icons.star;
      case HexType.blocked:
        return Icons.block;
      case HexType.ocean:
        return Icons.water;
      case HexType.beach:
        return Icons.beach_access;
      case HexType.hill:
        return Icons.terrain;
      case HexType.town:
        return Icons.location_city;
      case HexType.forest:
        return Icons.park;
      case HexType.hedgerow:
        return Icons.grass;
    }
  }

  /// Get icon for structure (overload that accepts StructureTemplate)
  static IconData getStructureTypeIcon(dynamic structure) {
    if (structure is StructureTemplate) {
      // Handle StructureTemplate with player field
      switch (structure.type) {
        case StructureType.bunker:
          return Icons.security; // Shield icon for bunker
        case StructureType.bridge:
          return Icons.horizontal_rule; // Horizontal line for bridge
        case StructureType.sandbag:
          return Icons.fence; // Fence icon for sandbags
        case StructureType.barbwire:
          return Icons.grain; // Wire-like icon for barbwire
        case StructureType.dragonsTeeth:
          return Icons.change_history; // Triangle icon for dragon's teeth
        case StructureType.medal:
          return Icons.military_tech; // Medal icon
      }
    } else if (structure is StructureType) {
      // Handle StructureType enum directly (legacy support)
      switch (structure) {
        case StructureType.bunker:
          return Icons.security;
        case StructureType.bridge:
          return Icons.horizontal_rule;
        case StructureType.sandbag:
          return Icons.fence;
        case StructureType.barbwire:
          return Icons.grain;
        case StructureType.dragonsTeeth:
          return Icons.change_history;
        case StructureType.medal:
          return Icons.military_tech;
      }
    }
    return Icons.help_outline; // Fallback icon
  }

  /// Get color for structure (overload that accepts StructureTemplate)
  static Color getStructureTypeColor(dynamic structure) {
    if (structure is StructureTemplate) {
      // Handle StructureTemplate with player field
      switch (structure.type) {
        case StructureType.bunker:
          return Colors.brown.shade600; // Brown for bunker
        case StructureType.bridge:
          return Colors.grey.shade400; // Grey for bridge
        case StructureType.sandbag:
          return Colors.brown.shade300; // Light brown for sandbags
        case StructureType.barbwire:
          return Colors.grey.shade700; // Dark grey for barbwire
        case StructureType.dragonsTeeth:
          return Colors.grey.shade600; // Medium grey for dragon's teeth
        case StructureType.medal:
          // Return player-specific color for medals
          if (structure.player == Player.player1) {
            return Colors.blue.shade600; // Blue for Player 1
          } else if (structure.player == Player.player2) {
            return Colors.red.shade600; // Red for Player 2
          }
          return Colors.amber.shade600; // Gold for neutral/unowned medals
      }
    } else if (structure is StructureType) {
      // Handle StructureType enum directly (legacy support)
      switch (structure) {
        case StructureType.bunker:
          return Colors.brown.shade600;
        case StructureType.bridge:
          return Colors.grey.shade400;
        case StructureType.sandbag:
          return Colors.brown.shade300;
        case StructureType.barbwire:
          return Colors.grey.shade700;
        case StructureType.dragonsTeeth:
          return Colors.grey.shade600;
        case StructureType.medal:
          return Colors.amber.shade600; // Default gold for medals
      }
    }
    return Colors.grey; // Fallback color
  }

  /// Get name for structure (overload that accepts StructureTemplate)
  static String getStructureTypeName(dynamic structure) {
    if (structure is StructureTemplate) {
      // Handle StructureTemplate with player field
      switch (structure.type) {
        case StructureType.bunker:
          return 'Bunker';
        case StructureType.bridge:
          return 'Bridge';
        case StructureType.sandbag:
          return 'Sandbag';
        case StructureType.barbwire:
          return 'Barbwire';
        case StructureType.dragonsTeeth:
          return 'Dragon\'s Teeth';
        case StructureType.medal:
          // Return player-specific name for medals
          if (structure.player == Player.player1) {
            return 'Medal P1';
          } else if (structure.player == Player.player2) {
            return 'Medal P2';
          }
          return 'Medal'; // Neutral medal
      }
    } else if (structure is StructureType) {
      // Handle StructureType enum directly (legacy support)
      switch (structure) {
        case StructureType.bunker:
          return 'Bunker';
        case StructureType.bridge:
          return 'Bridge';
        case StructureType.sandbag:
          return 'Sandbag';
        case StructureType.barbwire:
          return 'Barbwire';
        case StructureType.dragonsTeeth:
          return 'Dragon\'s Teeth';
        case StructureType.medal:
          return 'Medal';
      }
    }
    return 'Unknown'; // Fallback name
  }
}

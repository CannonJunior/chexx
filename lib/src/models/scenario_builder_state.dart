import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'game_unit.dart';
import 'game_board.dart';
import 'game_state.dart';
import 'unit_type_config.dart';
import 'game_type_config.dart';
import 'hex_orientation.dart';
import '../../core/interfaces/unit_factory.dart';

/// Enumeration of structure types
enum StructureType {
  bunker,
  bridge,
  sandbag,
  barbwire,
  dragonsTeeth,
}

/// Represents a structure template in the scenario builder
class StructureTemplate {
  final StructureType type;
  final String id;

  const StructureTemplate({
    required this.type,
    required this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'id': id,
    };
  }

  factory StructureTemplate.fromJson(Map<String, dynamic> json) {
    return StructureTemplate(
      type: StructureType.values.firstWhere((e) => e.toString().split('.').last == json['type']),
      id: json['id'] as String,
    );
  }
}

/// Represents a unit template in the scenario builder
class UnitTemplate {
  final UnitType type;
  final Player owner;
  final String id;

  const UnitTemplate({
    required this.type,
    required this.owner,
    required this.id,
  });

  Map<String, dynamic> toJson() {
    // Extract actual unit type from ID if it contains one (e.g., "p1_infantry" -> "infantry")
    String unitTypeName;
    if (id.contains('_')) {
      final parts = id.split('_');
      if (parts.length > 1) {
        unitTypeName = parts[1]; // e.g., "p1_infantry" -> "infantry"
        print('DEBUG: UnitTemplate.toJson - Extracted unit type "$unitTypeName" from ID "$id"');
      } else {
        unitTypeName = type.toString().split('.').last;
        print('DEBUG: UnitTemplate.toJson - Fallback to enum name "$unitTypeName" for ID "$id"');
      }
    } else {
      unitTypeName = type.toString().split('.').last;
      print('DEBUG: UnitTemplate.toJson - Using enum name "$unitTypeName" for ID "$id"');
    }

    return {
      'type': unitTypeName,
      'owner': owner.toString().split('.').last,
      'id': id,
    };
  }

  factory UnitTemplate.fromJson(Map<String, dynamic> json) {
    return UnitTemplate(
      type: UnitType.values.firstWhere((e) => e.toString().split('.').last == json['type']),
      owner: Player.values.firstWhere((e) => e.toString().split('.').last == json['owner']),
      id: json['id'] as String,
    );
  }
}

/// Represents a placed structure in the scenario
class PlacedStructure {
  final StructureTemplate template;
  final HexCoordinate position;

  const PlacedStructure({
    required this.template,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'template': template.toJson(),
      'position': {
        'q': position.q,
        'r': position.r,
        's': position.s,
      },
    };
  }

  factory PlacedStructure.fromJson(Map<String, dynamic> json) {
    final positionData = json['position'] as Map<String, dynamic>;
    return PlacedStructure(
      template: StructureTemplate.fromJson(json['template'] as Map<String, dynamic>),
      position: HexCoordinate(
        positionData['q'] as int,
        positionData['r'] as int,
        positionData['s'] as int,
      ),
    );
  }
}

/// Represents a placed unit in the scenario
class PlacedUnit {
  final UnitTemplate template;
  final HexCoordinate position;
  final int? customHealth; // Custom health for scenario builder, null uses default

  const PlacedUnit({
    required this.template,
    required this.position,
    this.customHealth,
  });

  Map<String, dynamic> toJson() {
    return {
      'template': template.toJson(),
      'position': {
        'q': position.q,
        'r': position.r,
        's': position.s,
      },
      if (customHealth != null) 'customHealth': customHealth,
    };
  }

  factory PlacedUnit.fromJson(Map<String, dynamic> json) {
    final positionData = json['position'] as Map<String, dynamic>;
    return PlacedUnit(
      template: UnitTemplate.fromJson(json['template'] as Map<String, dynamic>),
      position: HexCoordinate(
        positionData['q'] as int,
        positionData['r'] as int,
        positionData['s'] as int,
      ),
      customHealth: json['customHealth'] as int?,
    );
  }
}

/// Scenario Builder state management
class ScenarioBuilderState extends ChangeNotifier {
  final GameBoard board = GameBoard();
  final List<UnitTemplate> availableUnits = [];
  final List<StructureTemplate> availableStructures = [];
  final List<PlacedUnit> placedUnits = [];
  final List<PlacedStructure> placedStructures = [];
  final Set<HexCoordinate> metaHexes = {};

  UnitTemplate? selectedUnitTemplate;
  StructureTemplate? selectedStructureTemplate;
  HexType? selectedTileType;
  String scenarioName = 'Custom Scenario';

  // New properties for enhanced editing
  HexCoordinate? lastEditedTile;
  HexCoordinate? cursorPosition;
  bool isCreateNewMode = false;
  bool isRemoveMode = false;

  // Hexagon orientation setting
  HexOrientation hexOrientation = HexOrientation.flat;

  // Selected placed unit for info display
  PlacedUnit? selectedPlacedUnit;

  // Current unit type set for configuration-based behavior
  UnitTypeSet? currentUnitTypeSet;

  // Current game type configuration
  GameTypeConfig? currentGameTypeConfig;

  ScenarioBuilderState() {
    _initializeAvailableUnits();
    _initializeAvailableStructures();
    _initializeDefaultMetaHexes();
  }

  /// Initialize available unit templates from config
  void _initializeAvailableUnits() {
    availableUnits.clear();

    if (currentUnitTypeSet != null && _hasWWIIUnits()) {
      print('DEBUG: Initializing WWII unit templates');
      // WWII unit templates
      availableUnits.addAll([
        const UnitTemplate(type: UnitType.minor, owner: Player.player1, id: 'p1_infantry'),
        const UnitTemplate(type: UnitType.scout, owner: Player.player1, id: 'p1_armor'),
        const UnitTemplate(type: UnitType.knight, owner: Player.player1, id: 'p1_artillery'),
      ]);

      availableUnits.addAll([
        const UnitTemplate(type: UnitType.minor, owner: Player.player2, id: 'p2_infantry'),
        const UnitTemplate(type: UnitType.scout, owner: Player.player2, id: 'p2_armor'),
        const UnitTemplate(type: UnitType.knight, owner: Player.player2, id: 'p2_artillery'),
      ]);
    } else {
      print('DEBUG: Initializing default CHEXX unit templates');
      // Default CHEXX unit templates
      availableUnits.addAll([
        const UnitTemplate(type: UnitType.minor, owner: Player.player1, id: 'p1_minor'),
        const UnitTemplate(type: UnitType.scout, owner: Player.player1, id: 'p1_scout'),
        const UnitTemplate(type: UnitType.knight, owner: Player.player1, id: 'p1_knight'),
        const UnitTemplate(type: UnitType.guardian, owner: Player.player1, id: 'p1_guardian'),
      ]);

      availableUnits.addAll([
        const UnitTemplate(type: UnitType.minor, owner: Player.player2, id: 'p2_minor'),
        const UnitTemplate(type: UnitType.scout, owner: Player.player2, id: 'p2_scout'),
        const UnitTemplate(type: UnitType.knight, owner: Player.player2, id: 'p2_knight'),
        const UnitTemplate(type: UnitType.guardian, owner: Player.player2, id: 'p2_guardian'),
      ]);
    }

    print('DEBUG: Initialized ${availableUnits.length} unit templates');
  }

  /// Initialize available structure templates from config
  void _initializeAvailableStructures() {
    availableStructures.clear();

    // Add structure types
    availableStructures.addAll([
      const StructureTemplate(type: StructureType.bunker, id: 'bunker_structure'),
      const StructureTemplate(type: StructureType.bridge, id: 'bridge_structure'),
      const StructureTemplate(type: StructureType.sandbag, id: 'sandbag_structure'),
      const StructureTemplate(type: StructureType.barbwire, id: 'barbwire_structure'),
      const StructureTemplate(type: StructureType.dragonsTeeth, id: 'dragons_teeth_structure'),
    ]);
  }

  /// Initialize default Meta hex positions
  void _initializeDefaultMetaHexes() {
    metaHexes.addAll([
      const HexCoordinate(0, -2, 2),
      const HexCoordinate(2, -1, -1),
      const HexCoordinate(-2, 1, 1),
      const HexCoordinate(0, 2, -2),
      const HexCoordinate(-1, -1, 2),
      const HexCoordinate(1, 1, -2),
    ]);
  }

  /// Select a unit template for placement
  void selectUnitTemplate(UnitTemplate? template) {
    selectedUnitTemplate = template;
    selectedStructureTemplate = null; // Deselect structure when selecting unit
    selectedTileType = null; // Deselect tile type when selecting unit
    notifyListeners();
  }

  /// Select a structure template for placement
  void selectStructureTemplate(StructureTemplate? template) {
    selectedStructureTemplate = template;
    selectedUnitTemplate = null; // Deselect unit when selecting structure
    selectedTileType = null; // Deselect tile type when selecting structure
    notifyListeners();
  }

  /// Select a tile type for placement
  void selectTileType(HexType tileType) {
    selectedTileType = tileType;
    selectedUnitTemplate = null; // Deselect unit when selecting tile type
    selectedStructureTemplate = null; // Deselect structure when selecting tile type
    isCreateNewMode = false;
    isRemoveMode = false;
    notifyListeners();
  }

  /// Enable Create New mode
  void enableCreateNewMode() {
    isCreateNewMode = true;
    isRemoveMode = false;
    selectedTileType = null;
    selectedUnitTemplate = null;
    selectedStructureTemplate = null;
    notifyListeners();
  }

  /// Enable Remove mode
  void enableRemoveMode() {
    isRemoveMode = true;
    isCreateNewMode = false;
    selectedTileType = null;
    selectedUnitTemplate = null;
    selectedStructureTemplate = null;
    notifyListeners();
  }

  /// Handle placing items (units, structures, or tile types) at the specified position
  bool placeItem(HexCoordinate position) {
    bool success = false;

    if (selectedUnitTemplate != null) {
      success = _placeUnit(position);
    } else if (selectedStructureTemplate != null) {
      success = _placeStructure(position);
    } else if (selectedTileType != null) {
      success = _placeTileType(position);
    } else if (isCreateNewMode) {
      success = _createNewTile(position);
    } else if (isRemoveMode) {
      success = _removeTile(position);
    }

    if (success) {
      lastEditedTile = position;
      cursorPosition = position;
    }

    return success;
  }

  /// Set the current unit type set for configuration-based behavior
  void setCurrentUnitTypeSet(UnitTypeSet? unitTypeSet) {
    print('DEBUG: Setting current unit type set: ${unitTypeSet?.name ?? "null"}');
    currentUnitTypeSet = unitTypeSet;
    // Reinitialize available units based on the new unit type set
    _initializeAvailableUnits();
    notifyListeners();
  }

  /// Set the current game type configuration
  void setCurrentGameTypeConfig(GameTypeConfig? gameTypeConfig) {
    currentGameTypeConfig = gameTypeConfig;
  }

  /// Get unit configuration from template
  UnitTypeConfig? _getUnitConfigFromTemplate(UnitTemplate template) {
    if (currentUnitTypeSet == null) return null;

    // Convert enum back to string ID for lookup
    final unitTypeId = _getUnitTypeIdFromTemplate(template);
    return currentUnitTypeSet!.getUnitConfig(unitTypeId);
  }

  /// Convert template back to unit type ID
  String _getUnitTypeIdFromTemplate(UnitTemplate template) {
    // Check if the template ID contains the actual unit type ID
    if (template.id.contains('_')) {
      final parts = template.id.split('_');
      if (parts.length > 1) {
        return parts[1]; // e.g., "p1_infantry" -> "infantry"
      }
    }

    // Fallback to enum name
    return template.type.toString().split('.').last;
  }

  /// Check if we have WWII units in the current unit type set
  bool _hasWWIIUnits() {
    if (currentUnitTypeSet == null) return false;

    // Check if any of the classic WWII unit types exist
    final wwiiTypes = ['infantry', 'armor', 'artillery'];
    for (final type in wwiiTypes) {
      if (currentUnitTypeSet!.getUnitConfig(type) != null) {
        return true;
      }
    }
    return false;
  }

  /// Check if a unit template is incrementable based on configuration
  bool _isIncrementableTemplate(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.isIncrementable ?? _isIncrementableType(template.type);
  }

  /// Get max health for a unit template
  int _getMaxHealthForTemplate(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.maxHealth ?? _getDefaultMaxHealth(template.type);
  }

  /// Get starting health for a unit template
  int _getStartingHealthForTemplate(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.health ?? 1; // Default starting health is 1
  }

  /// Increment health of the selected unit (if incrementable)
  bool incrementSelectedUnitHealth() {
    if (selectedPlacedUnit == null) return false;

    final unit = selectedPlacedUnit!;
    final isIncrementable = _isIncrementableTemplate(unit.template);

    if (!isIncrementable) return false;

    final currentHealth = unit.customHealth ?? _getStartingHealthForTemplate(unit.template);
    final maxHealth = _getMaxHealthForTemplate(unit.template);

    if (currentHealth >= maxHealth) return false; // Already at max

    // Remove old unit and add with incremented health
    placedUnits.remove(unit);
    final newUnit = PlacedUnit(
      template: unit.template,
      position: unit.position,
      customHealth: currentHealth + 1,
    );
    placedUnits.add(newUnit);

    // Update selected unit reference
    selectedPlacedUnit = newUnit;

    notifyListeners();
    return true;
  }

  /// Decrement health of the selected unit (if incrementable and above starting health)
  bool decrementSelectedUnitHealth() {
    if (selectedPlacedUnit == null) return false;

    final unit = selectedPlacedUnit!;
    final isIncrementable = _isIncrementableTemplate(unit.template);

    if (!isIncrementable) return false;

    final currentHealth = unit.customHealth ?? _getStartingHealthForTemplate(unit.template);
    final startingHealth = _getStartingHealthForTemplate(unit.template);

    if (currentHealth <= startingHealth) return false; // Already at starting health

    // Remove old unit and add with decremented health
    placedUnits.remove(unit);
    final newUnit = PlacedUnit(
      template: unit.template,
      position: unit.position,
      customHealth: currentHealth - 1,
    );
    placedUnits.add(newUnit);

    // Update selected unit reference
    selectedPlacedUnit = newUnit;

    notifyListeners();
    return true;
  }

  /// Legacy method: Get default max health (fallback)
  int _getDefaultMaxHealth(UnitType type) {
    switch (type) {
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

  /// Check if a unit type is incrementable (legacy fallback)
  bool _isIncrementableType(UnitType type) {
    switch (type) {
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

  /// Place a unit at the specified position (with health incrementation for incrementable units)
  bool _placeUnit(HexCoordinate position) {
    if (selectedUnitTemplate == null) return false;

    // Check if position is already occupied
    final existingUnits = placedUnits.where((unit) => unit.position == position).toList();
    final existingUnit = existingUnits.isNotEmpty ? existingUnits.first : null;

    // Check if this unit type is incrementable
    final isIncrementable = _isIncrementableTemplate(selectedUnitTemplate!);

    if (existingUnit != null) {
      // Remove existing unit (click to replace behavior)
      placedUnits.remove(existingUnit);
    }

    // Place new unit with starting health from configuration for incrementable units
    final customHealth = isIncrementable ? _getStartingHealthForTemplate(selectedUnitTemplate!) : null;

    placedUnits.add(PlacedUnit(
      template: selectedUnitTemplate!,
      position: position,
      customHealth: customHealth,
    ));

    notifyListeners();
    return true;
  }

  /// Place a structure at the specified position
  bool _placeStructure(HexCoordinate position) {
    if (selectedStructureTemplate == null) return false;

    // Check if position is already occupied by a structure
    final existingStructures = placedStructures.where((structure) => structure.position == position).toList();
    final existingStructure = existingStructures.isNotEmpty ? existingStructures.first : null;
    if (existingStructure != null) {
      // Replace existing structure
      placedStructures.remove(existingStructure);
    }

    placedStructures.add(PlacedStructure(
      template: selectedStructureTemplate!,
      position: position,
    ));

    notifyListeners();
    return true;
  }

  /// Place a tile type at the specified position
  bool _placeTileType(HexCoordinate position) {
    if (selectedTileType == null) return false;

    // Update the board tile type
    final tile = board.getTile(position);
    if (tile != null) {
      tile.type = selectedTileType!;

      // Handle meta hex logic
      if (selectedTileType == HexType.meta) {
        metaHexes.add(position);
      } else {
        metaHexes.remove(position);
      }

      notifyListeners();
      return true;
    }

    return false;
  }

  /// Create a new tile at the specified position
  bool _createNewTile(HexCoordinate position) {
    // No distance restrictions - allow tile creation anywhere like unit placement

    // Check if tile already exists
    final existingTile = board.getTile(position);
    if (existingTile != null) {
      // Tile already exists - this is valid, just return success
      return true;
    }

    // Create new tile with default type
    board.addTile(position, HexType.normal);
    notifyListeners();
    return true;
  }

  /// Remove the entire tile and everything on it (use sparingly)
  bool _removeTile(HexCoordinate position) {
    final tile = board.getTile(position);
    if (tile != null) {
      board.removeTile(position);
      metaHexes.remove(position);

      // Remove all units at this position (only when removing entire tile)
      final unitsToRemove = placedUnits.where((unit) => unit.position == position).toList();
      for (final unit in unitsToRemove) {
        placedUnits.remove(unit);
      }

      // Remove all structures at this position (only when removing entire tile)
      final structuresToRemove = placedStructures.where((structure) => structure.position == position).toList();
      for (final structure in structuresToRemove) {
        placedStructures.remove(structure);
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  /// Legacy method for backward compatibility
  bool placeUnit(HexCoordinate position) {
    return placeItem(position);
  }

  /// Remove unit at position
  bool removeUnit(HexCoordinate position) {
    final unitsToRemove = placedUnits.where((unit) => unit.position == position).toList();
    final unitToRemove = unitsToRemove.isNotEmpty ? unitsToRemove.first : null;
    if (unitToRemove != null) {
      placedUnits.remove(unitToRemove);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Remove structure at position
  bool removeStructure(HexCoordinate position) {
    final structuresToRemove = placedStructures.where((structure) => structure.position == position).toList();
    final structureToRemove = structuresToRemove.isNotEmpty ? structuresToRemove.first : null;
    if (structureToRemove != null) {
      placedStructures.remove(structureToRemove);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Remove tile at position
  bool removeTile(HexCoordinate position) {
    return _removeTile(position);
  }

  /// Toggle Meta hex at position
  void toggleMetaHex(HexCoordinate position) {
    if (!board.isValidCoordinate(position)) return;

    if (metaHexes.contains(position)) {
      metaHexes.remove(position);
    } else {
      metaHexes.add(position);
    }
    notifyListeners();
  }

  /// Get unit at position (if any)
  PlacedUnit? getUnitAt(HexCoordinate position) {
    final unitsAtPosition = placedUnits.where((unit) => unit.position == position).toList();
    return unitsAtPosition.isNotEmpty ? unitsAtPosition.first : null;
  }

  /// Get structure at position (if any)
  PlacedStructure? getStructureAt(HexCoordinate position) {
    final structuresAtPosition = placedStructures.where((structure) => structure.position == position).toList();
    return structuresAtPosition.isNotEmpty ? structuresAtPosition.first : null;
  }

  /// Check if position is a Meta hex
  bool isMetaHex(HexCoordinate position) {
    return metaHexes.contains(position);
  }

  /// Clear all placed units
  void clearUnits() {
    placedUnits.clear();
    notifyListeners();
  }

  /// Clear all placed structures
  void clearStructures() {
    placedStructures.clear();
    notifyListeners();
  }

  /// Reset Meta hexes to default positions
  void resetMetaHexes() {
    metaHexes.clear();
    _initializeDefaultMetaHexes();
    notifyListeners();
  }

  /// Generate scenario configuration for saving
  Map<String, dynamic> generateScenarioConfig() {
    print('DEBUG: GENERATE SCENARIO CONFIG START');
    print('DEBUG: Current game type config: ${currentGameTypeConfig?.name ?? "null"}');
    print('DEBUG: Placed units count: ${placedUnits.length}');

    // Determine game type and load appropriate unit configurations
    Map<String, dynamic> unitTypesConfig;
    Map<String, dynamic> metaAbilitiesConfig;

    if (currentGameTypeConfig?.name == "WWII Combat" ||
        (currentUnitTypeSet != null && _hasWWIIUnits())) {
      print('DEBUG: Using WWII unit configurations');
      // WWII unit configuration
      unitTypesConfig = {
        'infantry': {
          'health': 1,
          'max_health': 4,
          'movement_range': 2,
          'attack_range': 1,
          'attack_damage': [1],
          'movement_type': 'adjacent',
          'is_incrementable': true,
          'symbol': 'I',
          'game_type': 'wwii'
        },
        'armor': {
          'health': 1,
          'max_health': 3,
          'movement_range': 3,
          'attack_range': 2,
          'attack_damage': [1, 1],
          'movement_type': 'straight_line',
          'is_incrementable': true,
          'symbol': 'A',
          'game_type': 'wwii'
        },
        'artillery': {
          'health': 1,
          'max_health': 2,
          'movement_range': 1,
          'attack_range': 4,
          'attack_damage': [1, 1, 1, 1],
          'movement_type': 'adjacent',
          'special': 'indirect_fire',
          'is_incrementable': true,
          'symbol': 'R',
          'game_type': 'wwii'
        }
      };

      metaAbilitiesConfig = {
        'spawn': {
          'description': 'Create new Infantry Unit on adjacent hex',
          'range': 1,
          'cooldown': 3
        },
        'heal': {
          'description': 'Heal adjacent friendly unit by 1 HP',
          'range': 1,
          'heal_amount': 1,
          'cooldown': 2
        },
        'shield': {
          'description': 'Adjacent friendly units take -1 damage for 2 turns',
          'range': 1,
          'duration': 2,
          'cooldown': 4
        }
      };
    } else {
      print('DEBUG: Using default CHEXX unit configurations');
      // Default CHEXX unit configuration
      unitTypesConfig = {
        'minor': {
          'health': 1,
          'movement_range': 1,
          'attack_range': 1,
          'attack_damage': 1,
          'movement_type': 'adjacent'
        },
        'scout': {
          'health': 2,
          'movement_range': 3,
          'attack_range': 3,
          'attack_damage': 1,
          'movement_type': 'straight_line'
        },
        'knight': {
          'health': 3,
          'movement_range': 2,
          'attack_range': 2,
          'attack_damage': 2,
          'movement_type': 'l_shaped'
        },
        'guardian': {
          'health': 3,
          'movement_range': 1,
          'attack_range': 1,
          'attack_damage': 1,
          'movement_type': 'adjacent',
          'special': 'can_swap_with_friendly'
        }
      };

      metaAbilitiesConfig = {
        'spawn': {
          'description': 'Create new Minor Unit on adjacent hex',
          'range': 1,
          'cooldown': 3
        },
        'heal': {
          'description': 'Heal adjacent friendly unit by 1 HP',
          'range': 1,
          'heal_amount': 1,
          'cooldown': 2
        },
        'shield': {
          'description': 'Adjacent friendly units take -1 damage for 2 turns',
          'range': 1,
          'duration': 2,
          'cooldown': 4
        }
      };
    }

    // Load base config with detected unit types
    final baseConfig = <String, dynamic>{
      'board': {
        'total_hexes': 91,
        'hex_size': 60.0,
        'board_layout': 'standard_91'
      },
      'gameplay': {
        'turn_timer_seconds': 6,
        'max_reward_points': 61,
        'time_bonus_multiplier': 5
      },
      'unit_types': unitTypesConfig,
      'meta_abilities': metaAbilitiesConfig,
    };

    // Add scenario-specific data
    baseConfig['scenario_name'] = scenarioName;
    baseConfig['meta_hex_positions'] = metaHexes.map((hex) => {
      'q': hex.q,
      'r': hex.r,
    }).toList();

    final unitPlacements = placedUnits.map((unit) => unit.toJson()).toList();
    print('DEBUG: Generated unit placements: ${unitPlacements.length} units');

    // Validation tests for unit type conversion
    bool allUnitsHaveCorrectTypes = true;
    int wwiiUnitCount = 0;
    int chexxUnitCount = 0;

    for (final placement in unitPlacements) {
      final unitType = placement['template']['type'] as String;
      final unitId = placement['template']['id'] as String;

      print('DEBUG: Unit placement - Type: $unitType, Owner: ${placement['template']['owner']}, ID: $unitId');

      // Count unit types
      if (['infantry', 'armor', 'artillery'].contains(unitType)) {
        wwiiUnitCount++;
      } else if (['minor', 'scout', 'knight', 'guardian'].contains(unitType)) {
        chexxUnitCount++;
      }

      // Validate that unit type matches ID expectation
      if (unitId.contains('_')) {
        final expectedType = unitId.split('_')[1];
        if (unitType != expectedType) {
          allUnitsHaveCorrectTypes = false;
          print('VALIDATION ERROR: Unit type mismatch - ID: $unitId, Expected: $expectedType, Actual: $unitType');
        }
      }
    }

    print('VALIDATION TEST: Unit type conversion - Total units: ${unitPlacements.length}, WWII units: $wwiiUnitCount, CHEXX units: $chexxUnitCount');
    print('VALIDATION TEST: Unit type consistency - All types match IDs: $allUnitsHaveCorrectTypes');

    if (_hasWWIIUnits() && wwiiUnitCount > 0) {
      print('VALIDATION TEST: WWII unit detection - PASS: WWII units correctly preserved');
    } else if (!_hasWWIIUnits() && chexxUnitCount > 0) {
      print('VALIDATION TEST: CHEXX unit detection - PASS: CHEXX units correctly preserved');
    } else {
      print('VALIDATION TEST: Unit type detection - FAIL: Unexpected unit type distribution');
    }

    baseConfig['unit_placements'] = unitPlacements;
    baseConfig['structure_placements'] = placedStructures.map((structure) => structure.toJson()).toList();

    // Save board tile data (which tiles exist and their types)
    baseConfig['board_tiles'] = board.allTiles.map((tile) => {
      'q': tile.coordinate.q,
      'r': tile.coordinate.r,
      's': tile.coordinate.s,
      'type': tile.type.toString().split('.').last,
    }).toList();

    return baseConfig;
  }

  /// Set scenario name
  void setScenarioName(String name) {
    scenarioName = name.trim().isEmpty ? 'Custom Scenario' : name.trim();
    notifyListeners();
  }

  /// Move cursor using QWEASD keys
  void moveCursor(String direction) {
    if (cursorPosition == null && lastEditedTile != null) {
      cursorPosition = lastEditedTile;
    }

    if (cursorPosition == null) {
      // Start at center if no position set
      cursorPosition = const HexCoordinate(0, 0, 0);
    }

    HexCoordinate? directionVector;
    switch (direction.toLowerCase()) {
      case 'q':
        directionVector = const HexCoordinate(-1, 0, 1); // Northwest
        break;
      case 'w':
        directionVector = const HexCoordinate(0, -1, 1); // North
        break;
      case 'e':
        directionVector = const HexCoordinate(1, -1, 0); // Northeast
        break;
      case 'a':
        directionVector = const HexCoordinate(-1, 1, 0); // Southwest
        break;
      case 's':
        directionVector = const HexCoordinate(0, 1, -1); // South
        break;
      case 'd':
        directionVector = const HexCoordinate(1, 0, -1); // Southeast
        break;
    }

    if (directionVector != null) {
      cursorPosition = HexCoordinate(
        cursorPosition!.q + directionVector.q,
        cursorPosition!.r + directionVector.r,
        cursorPosition!.s + directionVector.s,
      );

      // If in Create New mode and cursor moved to a position, try to create tile
      if (isCreateNewMode) {
        if (_createNewTile(cursorPosition!)) {
          lastEditedTile = cursorPosition;
        }
      }

      notifyListeners();
    }
  }

  /// Load scenario data from a loaded scenario file
  void loadFromScenarioData(Map<String, dynamic> scenarioData) {
    try {
      // Clear existing state
      placedUnits.clear();
      placedStructures.clear();
      metaHexes.clear();

      // Reset board to default state first
      board.resetToDefault();

      // Load scenario name
      if (scenarioData.containsKey('scenario_name')) {
        scenarioName = scenarioData['scenario_name'] as String;
      }

      // Load board tiles (if saved in scenario)
      if (scenarioData.containsKey('board_tiles')) {
        // Clear the default board and load custom board state
        board.tiles.clear();

        final boardTiles = scenarioData['board_tiles'] as List<dynamic>;
        for (final tileData in boardTiles) {
          try {
            final tile = tileData as Map<String, dynamic>;
            final coord = HexCoordinate(
              tile['q'] as int,
              tile['r'] as int,
              tile['s'] as int,
            );

            final typeString = tile['type'] as String;
            final tileType = HexType.values.firstWhere(
              (e) => e.toString().split('.').last == typeString,
              orElse: () => HexType.normal,
            );

            board.addTile(coord, tileType);
          } catch (e) {
            print('Error loading individual tile: $e');
          }
        }
      }

      // Load meta hex positions
      if (scenarioData.containsKey('meta_hex_positions')) {
        final metaPositions = scenarioData['meta_hex_positions'] as List<dynamic>;
        for (final positionData in metaPositions) {
          final position = positionData as Map<String, dynamic>;
          final coord = HexCoordinate(
            position['q'] as int,
            position['r'] as int,
            // Calculate s from q and r if not provided
            -(position['q'] as int) - (position['r'] as int),
          );
          metaHexes.add(coord);

          // Update the board tile type
          final tile = board.getTile(coord);
          if (tile != null) {
            tile.type = HexType.meta;
          }
        }
      }

      // Load unit placements
      if (scenarioData.containsKey('unit_placements')) {
        final unitPlacements = scenarioData['unit_placements'] as List<dynamic>;
        for (final placementData in unitPlacements) {
          try {
            final placement = placementData as Map<String, dynamic>;
            final templateData = placement['template'] as Map<String, dynamic>;
            final positionData = placement['position'] as Map<String, dynamic>;

            // Extract unit data
            final unitTypeString = templateData['type'] as String;
            final ownerString = templateData['owner'] as String;
            final unitId = templateData['id'] as String;

            // Convert strings to enums
            final unitType = UnitType.values.firstWhere(
              (e) => e.toString().split('.').last == unitTypeString,
              orElse: () => UnitType.minor,
            );
            final owner = ownerString == 'player1' ? Player.player1 : Player.player2;

            // Create hex coordinate
            final position = HexCoordinate(
              positionData['q'] as int,
              positionData['r'] as int,
              positionData['s'] as int,
            );

            // Create unit template and placed unit
            final template = UnitTemplate(
              type: unitType,
              owner: owner,
              id: unitId,
            );

            final placedUnit = PlacedUnit(
              template: template,
              position: position,
            );

            placedUnits.add(placedUnit);
          } catch (e) {
            print('Error loading individual unit: $e');
          }
        }
      }

      // Load structure placements
      if (scenarioData.containsKey('structure_placements')) {
        final structurePlacements = scenarioData['structure_placements'] as List<dynamic>;
        for (final placementData in structurePlacements) {
          try {
            final placement = placementData as Map<String, dynamic>;
            final templateData = placement['template'] as Map<String, dynamic>;
            final positionData = placement['position'] as Map<String, dynamic>;

            // Extract structure data
            final structureTypeString = templateData['type'] as String;
            final structureId = templateData['id'] as String;

            // Convert string to enum
            final structureType = StructureType.values.firstWhere(
              (e) => e.toString().split('.').last == structureTypeString,
              orElse: () => StructureType.bunker,
            );

            // Create hex coordinate
            final position = HexCoordinate(
              positionData['q'] as int,
              positionData['r'] as int,
              positionData['s'] as int,
            );

            // Create structure template and placed structure
            final template = StructureTemplate(
              type: structureType,
              id: structureId,
            );

            final placedStructure = PlacedStructure(
              template: template,
              position: position,
            );

            placedStructures.add(placedStructure);
          } catch (e) {
            print('Error loading individual structure: $e');
          }
        }
      }

      print('Successfully loaded scenario: $scenarioName with ${board.allTiles.length} tiles, ${placedUnits.length} units, ${placedStructures.length} structures, and ${metaHexes.length} meta hexes');
      notifyListeners();
    } catch (e) {
      print('Error loading scenario data: $e');
    }
  }

  /// Toggle hexagon orientation between flat and pointy
  void toggleHexOrientation() {
    hexOrientation = hexOrientation == HexOrientation.flat
        ? HexOrientation.pointy
        : HexOrientation.flat;
    notifyListeners();
  }

  /// Select a placed unit for info display
  void selectPlacedUnit(PlacedUnit? unit) {
    selectedPlacedUnit = unit;
    notifyListeners();
  }

  /// Get placed unit at specific position
  PlacedUnit? getPlacedUnitAt(HexCoordinate position) {
    try {
      return placedUnits.firstWhere((unit) => unit.position == position);
    } catch (e) {
      return null;
    }
  }
}
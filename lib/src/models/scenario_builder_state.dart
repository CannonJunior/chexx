import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'game_unit.dart';
import 'game_board.dart';
import '../../core/interfaces/unit_factory.dart';

/// Enumeration of structure types
enum StructureType {
  bunker,
  bridge,
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
    return {
      'type': type.toString().split('.').last,
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

  const PlacedUnit({
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

  factory PlacedUnit.fromJson(Map<String, dynamic> json) {
    final positionData = json['position'] as Map<String, dynamic>;
    return PlacedUnit(
      template: UnitTemplate.fromJson(json['template'] as Map<String, dynamic>),
      position: HexCoordinate(
        positionData['q'] as int,
        positionData['r'] as int,
        positionData['s'] as int,
      ),
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

  ScenarioBuilderState() {
    _initializeAvailableUnits();
    _initializeAvailableStructures();
    _initializeDefaultMetaHexes();
  }

  /// Initialize available unit templates from config
  void _initializeAvailableUnits() {
    availableUnits.clear();

    // Player 1 units (blue) - one of each type
    availableUnits.addAll([
      const UnitTemplate(type: UnitType.minor, owner: Player.player1, id: 'p1_minor'),
      const UnitTemplate(type: UnitType.scout, owner: Player.player1, id: 'p1_scout'),
      const UnitTemplate(type: UnitType.knight, owner: Player.player1, id: 'p1_knight'),
      const UnitTemplate(type: UnitType.guardian, owner: Player.player1, id: 'p1_guardian'),
    ]);

    // Player 2 units (red) - one of each type
    availableUnits.addAll([
      const UnitTemplate(type: UnitType.minor, owner: Player.player2, id: 'p2_minor'),
      const UnitTemplate(type: UnitType.scout, owner: Player.player2, id: 'p2_scout'),
      const UnitTemplate(type: UnitType.knight, owner: Player.player2, id: 'p2_knight'),
      const UnitTemplate(type: UnitType.guardian, owner: Player.player2, id: 'p2_guardian'),
    ]);
  }

  /// Initialize available structure templates from config
  void _initializeAvailableStructures() {
    availableStructures.clear();

    // Add structure types
    availableStructures.addAll([
      const StructureTemplate(type: StructureType.bunker, id: 'bunker_structure'),
      const StructureTemplate(type: StructureType.bridge, id: 'bridge_structure'),
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

  /// Place a unit at the specified position
  bool _placeUnit(HexCoordinate position) {
    if (selectedUnitTemplate == null) return false;

    // Check if position is already occupied
    final existingUnits = placedUnits.where((unit) => unit.position == position).toList();
    final existingUnit = existingUnits.isNotEmpty ? existingUnits.first : null;
    if (existingUnit != null) {
      // Replace existing unit
      placedUnits.remove(existingUnit);
    }

    placedUnits.add(PlacedUnit(
      template: selectedUnitTemplate!,
      position: position,
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

  /// Remove tile at the specified position
  bool _removeTile(HexCoordinate position) {
    final tile = board.getTile(position);
    if (tile != null) {
      board.removeTile(position);
      metaHexes.remove(position);

      // Also remove any units at this position
      final unitsToRemove = placedUnits.where((unit) => unit.position == position).toList();
      for (final unit in unitsToRemove) {
        placedUnits.remove(unit);
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
    // Load base config (this would normally be loaded from assets)
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
      'unit_types': {
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
      },
      'meta_abilities': {
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
      }
    };

    // Add scenario-specific data
    baseConfig['scenario_name'] = scenarioName;
    baseConfig['meta_hex_positions'] = metaHexes.map((hex) => {
      'q': hex.q,
      'r': hex.r,
    }).toList();

    baseConfig['unit_placements'] = placedUnits.map((unit) => unit.toJson()).toList();
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
}
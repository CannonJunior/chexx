import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'game_unit.dart';
import 'game_board.dart';
import 'game_state.dart';
import 'unit_type_config.dart';
import 'game_type_config.dart';
import 'hex_orientation.dart';
import '../../core/interfaces/unit_factory.dart';

/// Enumeration of which vertical line is being dragged (for board thirds)
enum DraggingLine {
  leftLine,
  rightLine,
}

/// Enumeration of structure types
enum StructureType {
  bunker,
  bridge,
  sandbag,
  barbwire,
  dragonsTeeth,
  medal,
}

/// Represents a structure template in the scenario builder
class StructureTemplate {
  final StructureType type;
  final String id;
  final Player? player; // Which player can control/earn VP from this structure

  const StructureTemplate({
    required this.type,
    required this.id,
    this.player,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'id': id,
      if (player != null) 'player': player.toString().split('.').last,
    };
  }

  factory StructureTemplate.fromJson(Map<String, dynamic> json) {
    return StructureTemplate(
      type: StructureType.values.firstWhere((e) => e.toString().split('.').last == json['type']),
      id: json['id'] as String,
      player: json['player'] != null
          ? Player.values.firstWhere((e) => e.toString().split('.').last == json['player'])
          : null,
    );
  }

  /// Create a copy with modified fields
  StructureTemplate copyWith({
    StructureType? type,
    String? id,
    Player? player,
  }) {
    return StructureTemplate(
      type: type ?? this.type,
      id: id ?? this.id,
      player: player ?? this.player,
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

  // Win conditions
  int player1WinPoints = 10;
  int player2WinPoints = 10;

  // Game start settings
  int player1InitialCards = 5; // Number of cards Player 1 starts with
  int player2InitialCards = 5; // Number of cards Player 2 starts with
  Player firstPlayer = Player.player1; // Which player goes first

  // New properties for enhanced editing
  HexCoordinate? lastEditedTile;
  HexCoordinate? cursorPosition;
  bool isCreateNewMode = false;
  bool isRemoveMode = false;

  // Hexagon orientation setting (default to pointy)
  HexOrientation hexOrientation = HexOrientation.pointy;

  // Selected placed unit for info display
  PlacedUnit? selectedPlacedUnit;

  // Current unit type set for configuration-based behavior
  UnitTypeSet? currentUnitTypeSet;

  // Current game type configuration
  GameTypeConfig? currentGameTypeConfig;

  // Board partitioning: divide board into thirds with vertical lines
  bool showVerticalLines = false;
  bool highlightLeftThird = false;
  bool highlightMiddleThird = false;
  bool highlightRightThird = false;
  Set<HexCoordinate> leftThirdHexes = {};
  Set<HexCoordinate> middleThirdHexes = {};
  Set<HexCoordinate> rightThirdHexes = {};
  double leftLineX = 0.0;
  double rightLineX = 0.0;

  // Line dragging state
  DraggingLine? currentlyDraggedLine;
  double? dragStartX;

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
      const StructureTemplate(type: StructureType.medal, id: 'medal_p1', player: Player.player1),
      const StructureTemplate(type: StructureType.medal, id: 'medal_p2', player: Player.player2),
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
    // Only clear selectedPlacedUnit when actually selecting a NEW template (not null)
    if (template != null) {
      selectedPlacedUnit = null; // Deselect placed unit when selecting a new template
    }
    notifyListeners();
  }

  /// Select a structure template for placement
  void selectStructureTemplate(StructureTemplate? template) {
    selectedStructureTemplate = template;
    selectedUnitTemplate = null; // Deselect unit when selecting structure
    selectedTileType = null; // Deselect tile type when selecting structure
    // Only clear selectedPlacedUnit when actually selecting a NEW template (not null)
    if (template != null) {
      selectedPlacedUnit = null; // Deselect placed unit when selecting a new template
    }
    notifyListeners();
  }

  /// Select a tile type for placement
  void selectTileType(HexType tileType) {
    selectedTileType = tileType;
    selectedUnitTemplate = null; // Deselect unit when selecting tile type
    selectedStructureTemplate = null; // Deselect structure when selecting tile type
    selectedPlacedUnit = null; // Deselect placed unit when selecting tile type
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
    print('DEBUG STATE: ========== INCREMENT HEALTH CALLED ==========');
    print('DEBUG STATE: selectedPlacedUnit: ${selectedPlacedUnit != null ? "NOT NULL" : "NULL"}');

    // Don't allow health modification while a template is selected (placement mode)
    if (selectedUnitTemplate != null || selectedStructureTemplate != null) {
      print('DEBUG STATE: FAILED - Template is selected (in placement mode)');
      return false;
    }

    if (selectedPlacedUnit == null) {
      print('DEBUG STATE: FAILED - No unit selected');
      return false;
    }

    final unit = selectedPlacedUnit!;
    print('DEBUG STATE: Unit ID: ${unit.template.id}');
    print('DEBUG STATE: Unit Type: ${unit.template.type}');
    print('DEBUG STATE: Unit Owner: ${unit.template.owner}');
    print('DEBUG STATE: Unit Position: (${unit.position.q}, ${unit.position.r})');

    final isIncrementable = _isIncrementableTemplate(unit.template);
    print('DEBUG STATE: isIncrementable: $isIncrementable');

    if (!isIncrementable) {
      print('DEBUG STATE: FAILED - Unit type "${unit.template.id}" is not incrementable');
      print('DEBUG STATE: Only units with isIncrementable=true can have health adjusted');
      return false;
    }

    final currentHealth = unit.customHealth ?? _getStartingHealthForTemplate(unit.template);
    final maxHealth = _getMaxHealthForTemplate(unit.template);
    print('DEBUG STATE: Current health: $currentHealth');
    print('DEBUG STATE: Max health: $maxHealth');

    if (currentHealth >= maxHealth) {
      print('DEBUG STATE: FAILED - Already at max health ($maxHealth)');
      return false;
    }

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

    print('DEBUG STATE: SUCCESS - Health incremented from $currentHealth to ${currentHealth + 1}');
    print('DEBUG STATE: ========================================');
    notifyListeners();
    return true;
  }

  /// Decrement health of the selected unit (if incrementable and above minimum of 1)
  bool decrementSelectedUnitHealth() {
    print('DEBUG STATE: ========== DECREMENT HEALTH CALLED ==========');
    print('DEBUG STATE: selectedPlacedUnit: ${selectedPlacedUnit != null ? "NOT NULL" : "NULL"}');

    // Don't allow health modification while a template is selected (placement mode)
    if (selectedUnitTemplate != null || selectedStructureTemplate != null) {
      print('DEBUG STATE: FAILED - Template is selected (in placement mode)');
      return false;
    }

    if (selectedPlacedUnit == null) {
      print('DEBUG STATE: FAILED - No unit selected');
      return false;
    }

    final unit = selectedPlacedUnit!;
    print('DEBUG STATE: Unit ID: ${unit.template.id}');
    print('DEBUG STATE: Unit Type: ${unit.template.type}');
    print('DEBUG STATE: Unit Position: (${unit.position.q}, ${unit.position.r})');

    final isIncrementable = _isIncrementableTemplate(unit.template);
    print('DEBUG STATE: isIncrementable: $isIncrementable');

    if (!isIncrementable) {
      print('DEBUG STATE: FAILED - Unit type "${unit.template.id}" is not incrementable');
      return false;
    }

    // Get current health - if customHealth is null, it means the unit was just placed
    // In that case, use starting health from config
    final currentHealth = unit.customHealth ?? _getStartingHealthForTemplate(unit.template);
    const minHealth = 1; // Minimum health is always 1, regardless of starting health

    print('DEBUG STATE: Current health: $currentHealth');
    print('DEBUG STATE: Minimum health: $minHealth (hard minimum)');

    if (currentHealth <= minHealth) {
      print('DEBUG STATE: FAILED - Already at minimum health ($minHealth)');
      print('DEBUG STATE: Cannot go below 1 health');
      return false;
    }

    // Remove old unit and add with decremented health
    placedUnits.remove(unit);
    final newHealth = currentHealth - 1;
    final newUnit = PlacedUnit(
      template: unit.template,
      position: unit.position,
      customHealth: newHealth,
    );
    placedUnits.add(newUnit);

    // Update selected unit reference
    selectedPlacedUnit = newUnit;

    print('DEBUG STATE: SUCCESS - Health decremented from $currentHealth to $newHealth');
    print('DEBUG STATE: ========================================');
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

  /// Place a unit at the specified position (with click cycle: place → select → remove)
  bool _placeUnit(HexCoordinate position) {
    if (selectedUnitTemplate == null) return false;

    // Check if position is already occupied
    final existingUnits = placedUnits.where((unit) => unit.position == position).toList();
    final existingUnit = existingUnits.isNotEmpty ? existingUnits.first : null;

    if (existingUnit != null) {
      // Click cycle behavior:
      // If unit is already selected, remove it (Click 3)
      if (selectedPlacedUnit == existingUnit) {
        placedUnits.remove(existingUnit);
        selectedPlacedUnit = null;
        notifyListeners();
        return true;
      }

      // If unit exists but not selected, select it (Click 2)
      selectedPlacedUnit = existingUnit;
      print('DEBUG: Placed unit SELECTED at (${existingUnit.position.q}, ${existingUnit.position.r}) - ID: ${existingUnit.template.id}');
      print('  Ready for health modification with arrow keys!');
      notifyListeners();
      return true;
    }

    // No unit at position, place new unit (Click 1)
    // Check if this unit type is incrementable
    final isIncrementable = _isIncrementableTemplate(selectedUnitTemplate!);
    final customHealth = isIncrementable ? _getStartingHealthForTemplate(selectedUnitTemplate!) : null;

    placedUnits.add(PlacedUnit(
      template: selectedUnitTemplate!,
      position: position,
      customHealth: customHealth,
    ));

    notifyListeners();
    return true;
  }

  /// Place a structure at the specified position (with click cycle: place → remove)
  bool _placeStructure(HexCoordinate position) {
    if (selectedStructureTemplate == null) return false;

    // Check if position is already occupied by a structure
    final existingStructures = placedStructures.where((structure) => structure.position == position).toList();
    final existingStructure = existingStructures.isNotEmpty ? existingStructures.first : null;

    if (existingStructure != null) {
      // Click cycle behavior: If structure exists, remove it (Click 2)
      placedStructures.remove(existingStructure);
      notifyListeners();
      return true;
    }

    // No structure at position, place new structure (Click 1)
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

    // Save game type information
    if (currentGameTypeConfig != null) {
      baseConfig['game_type'] = currentGameTypeConfig!.id;
      print('DEBUG: Saving game type: ${currentGameTypeConfig!.id}');
    } else if (_hasWWIIUnits()) {
      baseConfig['game_type'] = 'wwii';
      print('DEBUG: Auto-detected WWII game type from units');
    } else {
      baseConfig['game_type'] = 'chexx';
      print('DEBUG: Defaulting to CHEXX game type');
    }

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

    // Save board thirds data
    baseConfig['board_thirds'] = {
      'left_line_x': leftLineX,
      'right_line_x': rightLineX,
      'left_third_hexes': leftThirdHexes.map((hex) => {
        'q': hex.q,
        'r': hex.r,
        's': hex.s,
      }).toList(),
      'middle_third_hexes': middleThirdHexes.map((hex) => {
        'q': hex.q,
        'r': hex.r,
        's': hex.s,
      }).toList(),
      'right_third_hexes': rightThirdHexes.map((hex) => {
        'q': hex.q,
        'r': hex.r,
        's': hex.s,
      }).toList(),
    };

    baseConfig['win_conditions'] = {
      'player1_points': player1WinPoints,
      'player2_points': player2WinPoints,
    };

    baseConfig['game_start_settings'] = {
      'player1_initial_cards': player1InitialCards,
      'player2_initial_cards': player2InitialCards,
      'first_player': firstPlayer.toString().split('.').last,
    };

    // Save hex orientation (flat or pointy)
    baseConfig['hex_orientation'] = hexOrientation == HexOrientation.flat ? 'flat' : 'pointy';
    print('DEBUG: Saving hex orientation: ${baseConfig['hex_orientation']}');

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

      // Load game type configuration
      if (scenarioData.containsKey('game_type')) {
        final gameTypeId = scenarioData['game_type'] as String;
        print('DEBUG: Loading game type: $gameTypeId');
        try {
          // Load the game type configuration asynchronously
          GameTypeConfigLoader.loadGameTypeConfig(gameTypeId).then((gameTypeConfig) {
            currentGameTypeConfig = gameTypeConfig;
            print('DEBUG: Successfully loaded game type config: ${gameTypeConfig.name}');
            notifyListeners();
          }).catchError((error) {
            print('Error loading game type config for $gameTypeId: $error');
            // Fallback to default (chexx)
            GameTypeConfigLoader.loadGameTypeConfig('chexx').then((defaultConfig) {
              currentGameTypeConfig = defaultConfig;
              print('DEBUG: Loaded fallback chexx game type config');
              notifyListeners();
            });
          });
        } catch (e) {
          print('Error loading game type: $e');
        }
      } else {
        print('DEBUG: No game_type in scenario data, keeping current game type config');
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

      // Load board thirds data
      if (scenarioData.containsKey('board_thirds')) {
        try {
          final thirdsData = scenarioData['board_thirds'] as Map<String, dynamic>;

          leftLineX = thirdsData['left_line_x'] as double? ?? 0.0;
          rightLineX = thirdsData['right_line_x'] as double? ?? 0.0;

          // Load left third hexes
          if (thirdsData.containsKey('left_third_hexes')) {
            leftThirdHexes.clear();
            final leftHexes = thirdsData['left_third_hexes'] as List<dynamic>;
            for (final hexData in leftHexes) {
              final hex = hexData as Map<String, dynamic>;
              leftThirdHexes.add(HexCoordinate(
                hex['q'] as int,
                hex['r'] as int,
                hex['s'] as int,
              ));
            }
          }

          // Load middle third hexes
          if (thirdsData.containsKey('middle_third_hexes')) {
            middleThirdHexes.clear();
            final middleHexes = thirdsData['middle_third_hexes'] as List<dynamic>;
            for (final hexData in middleHexes) {
              final hex = hexData as Map<String, dynamic>;
              middleThirdHexes.add(HexCoordinate(
                hex['q'] as int,
                hex['r'] as int,
                hex['s'] as int,
              ));
            }
          }

          // Load right third hexes
          if (thirdsData.containsKey('right_third_hexes')) {
            rightThirdHexes.clear();
            final rightHexes = thirdsData['right_third_hexes'] as List<dynamic>;
            for (final hexData in rightHexes) {
              final hex = hexData as Map<String, dynamic>;
              rightThirdHexes.add(HexCoordinate(
                hex['q'] as int,
                hex['r'] as int,
                hex['s'] as int,
              ));
            }
          }

          print('Successfully loaded board thirds: left=${leftThirdHexes.length}, middle=${middleThirdHexes.length}, right=${rightThirdHexes.length}');
        } catch (e) {
          print('Error loading board thirds data: $e');
        }
      }

      // Load win conditions
      if (scenarioData.containsKey('win_conditions')) {
        try {
          final winConditions = scenarioData['win_conditions'] as Map<String, dynamic>;
          player1WinPoints = winConditions['player1_points'] as int? ?? 10;
          player2WinPoints = winConditions['player2_points'] as int? ?? 10;
          print('Successfully loaded win conditions: P1=$player1WinPoints, P2=$player2WinPoints');
        } catch (e) {
          print('Error loading win conditions: $e');
        }
      }

      // Load game start settings
      if (scenarioData.containsKey('game_start_settings')) {
        try {
          final gameStartSettings = scenarioData['game_start_settings'] as Map<String, dynamic>;
          // Support both old format (initial_card_count) and new format (player1/player2_initial_cards)
          if (gameStartSettings.containsKey('initial_card_count')) {
            final cardCount = gameStartSettings['initial_card_count'] as int? ?? 5;
            player1InitialCards = cardCount;
            player2InitialCards = cardCount;
          } else {
            player1InitialCards = gameStartSettings['player1_initial_cards'] as int? ?? 5;
            player2InitialCards = gameStartSettings['player2_initial_cards'] as int? ?? 5;
          }
          final firstPlayerString = gameStartSettings['first_player'] as String? ?? 'player1';
          firstPlayer = firstPlayerString == 'player1' ? Player.player1 : Player.player2;
          print('Successfully loaded game start settings: P1Cards=$player1InitialCards, P2Cards=$player2InitialCards, First=$firstPlayerString');
        } catch (e) {
          print('Error loading game start settings: $e');
        }
      }

      // Load hex orientation (default to pointy if not saved)
      if (scenarioData.containsKey('hex_orientation')) {
        try {
          final orientationString = scenarioData['hex_orientation'] as String;
          hexOrientation = orientationString == 'flat' ? HexOrientation.flat : HexOrientation.pointy;
          print('Successfully loaded hex orientation: $orientationString');
        } catch (e) {
          print('Error loading hex orientation: $e, defaulting to pointy');
          hexOrientation = HexOrientation.pointy;
        }
      } else {
        // Default to pointy if no orientation is saved
        hexOrientation = HexOrientation.pointy;
        print('No hex orientation in scenario, defaulting to pointy');
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
    if (unit != null) {
      print('DEBUG: Placed unit SELECTED at (${unit.position.q}, ${unit.position.r}) - ID: ${unit.template.id}');
      print('  Ready for health modification with arrow keys!');
    } else {
      print('DEBUG: Placed unit DESELECTED');
    }
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

  /// Toggle vertical lines display
  void toggleVerticalLines() {
    showVerticalLines = !showVerticalLines;
    if (showVerticalLines) {
      calculateBoardThirds();
    }
    notifyListeners();
  }

  /// Toggle left third highlighting
  void toggleLeftThirdHighlight() {
    highlightLeftThird = !highlightLeftThird;
    if (highlightLeftThird && leftThirdHexes.isEmpty) {
      calculateBoardThirds();
    }
    notifyListeners();
  }

  /// Toggle middle third highlighting
  void toggleMiddleThirdHighlight() {
    highlightMiddleThird = !highlightMiddleThird;
    if (highlightMiddleThird && middleThirdHexes.isEmpty) {
      calculateBoardThirds();
    }
    notifyListeners();
  }

  /// Toggle right third highlighting
  void toggleRightThirdHighlight() {
    highlightRightThird = !highlightRightThird;
    if (highlightRightThird && rightThirdHexes.isEmpty) {
      calculateBoardThirds();
    }
    notifyListeners();
  }

  /// Calculate board partitioning into thirds with vertical lines (for POINTY-TOP layout)
  void calculateBoardThirds() {
    leftThirdHexes.clear();
    middleThirdHexes.clear();
    rightThirdHexes.clear();

    if (board.tiles.isEmpty) return;

    // Calculate x-positions for all hexes using POINTY-TOP formula
    // x = sqrt(3) * q + sqrt(3)/2 * r
    double? minX;
    double? maxX;

    final sqrt3 = sqrt(3.0);
    final hexPositions = <HexCoordinate, double>{};

    for (final tile in board.tiles.values) {
      final q = tile.coordinate.q.toDouble();
      final r = tile.coordinate.r.toDouble();

      // Pointy-top x-coordinate (normalized, hexSize = 1)
      final hexCenterX = sqrt3 * q + (sqrt3 / 2.0) * r;
      hexPositions[tile.coordinate] = hexCenterX;

      if (minX == null || hexCenterX < minX) minX = hexCenterX;
      if (maxX == null || hexCenterX > maxX) maxX = hexCenterX;
    }

    if (minX == null || maxX == null) return;

    // Calculate the range and third boundaries in x-coordinate space
    final xRange = maxX - minX;
    final thirdSize = xRange / 3.0;

    // Boundaries in x-coordinate space
    final leftBoundary = minX + thirdSize;
    final rightBoundary = minX + (thirdSize * 2);

    print('DEBUG Board Thirds (Pointy): minX=$minX, maxX=$maxX, xRange=$xRange');
    print('DEBUG Boundaries: left=$leftBoundary, right=$rightBoundary');

    // Categorize each hex into thirds
    // Hexes near boundaries may belong to multiple thirds
    for (final tile in board.tiles.values) {
      final hexCenterX = hexPositions[tile.coordinate]!;

      // A hex in pointy-top spans approximately ±(sqrt(3)/2) in x-space
      final hexHalfWidth = sqrt3 / 2.0;
      final hexLeftEdgeX = hexCenterX - hexHalfWidth;
      final hexRightEdgeX = hexCenterX + hexHalfWidth;

      // Determine which third(s) this hex belongs to
      bool inLeft = hexLeftEdgeX < leftBoundary;
      bool inRight = hexRightEdgeX > rightBoundary;
      bool inMiddle = hexRightEdgeX > leftBoundary && hexLeftEdgeX < rightBoundary;

      // A hex can belong to multiple thirds if it straddles a boundary
      if (inLeft) {
        leftThirdHexes.add(tile.coordinate);
      }
      if (inMiddle) {
        middleThirdHexes.add(tile.coordinate);
      }
      if (inRight) {
        rightThirdHexes.add(tile.coordinate);
      }
    }

    print('DEBUG Thirds: left=${leftThirdHexes.length}, middle=${middleThirdHexes.length}, right=${rightThirdHexes.length}');

    // Store the x-coordinates of the vertical lines for rendering
    // These are in normalized x-coordinate space (will be multiplied by hexSize during rendering)
    leftLineX = leftBoundary;
    rightLineX = rightBoundary;

    notifyListeners();
  }

  /// Start dragging a vertical line (only allowed in Pointy orientation)
  void startDraggingLine(DraggingLine line, double startX) {
    if (hexOrientation != HexOrientation.pointy) {
      return; // Only allow dragging in pointy mode
    }
    currentlyDraggedLine = line;
    dragStartX = startX;
    notifyListeners();
  }

  /// Update line position during drag
  void updateDraggedLinePosition(double newX) {
    if (currentlyDraggedLine == null) return;

    if (currentlyDraggedLine == DraggingLine.leftLine) {
      leftLineX = newX;
    } else if (currentlyDraggedLine == DraggingLine.rightLine) {
      rightLineX = newX;
    }

    notifyListeners();
  }

  /// End dragging: snap to nearest hex edge and recalculate hex membership
  void endDraggingLine() {
    if (currentlyDraggedLine == null) return;

    // Find nearest hex edge x-coordinate
    final allEdgeXs = _getAllHexEdgeXCoordinates();

    if (currentlyDraggedLine == DraggingLine.leftLine) {
      leftLineX = _findNearestValue(leftLineX, allEdgeXs);
    } else if (currentlyDraggedLine == DraggingLine.rightLine) {
      rightLineX = _findNearestValue(rightLineX, allEdgeXs);
    }

    // Recalculate hex membership with new line positions
    _recalculateThirdsWithCustomBoundaries(leftLineX, rightLineX);

    // Clear drag state
    currentlyDraggedLine = null;
    dragStartX = null;

    notifyListeners();
  }

  /// Get all hex edge x-coordinates for snapping
  List<double> _getAllHexEdgeXCoordinates() {
    final sqrt3 = sqrt(3.0);
    final hexHalfWidth = sqrt3 / 2.0;
    final edgeXs = <double>{};

    for (final tile in board.tiles.values) {
      final q = tile.coordinate.q.toDouble();
      final r = tile.coordinate.r.toDouble();
      final hexCenterX = sqrt3 * q + (sqrt3 / 2.0) * r;

      // Add both left and right edges of this hex
      edgeXs.add(hexCenterX - hexHalfWidth);
      edgeXs.add(hexCenterX + hexHalfWidth);
    }

    return edgeXs.toList()..sort();
  }

  /// Find nearest value in a list
  double _findNearestValue(double target, List<double> values) {
    if (values.isEmpty) return target;

    double nearest = values[0];
    double minDistance = (target - values[0]).abs();

    for (final value in values) {
      final distance = (target - value).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearest = value;
      }
    }

    return nearest;
  }

  /// Recalculate hex thirds membership with custom boundary positions
  void _recalculateThirdsWithCustomBoundaries(double leftBoundary, double rightBoundary) {
    leftThirdHexes.clear();
    middleThirdHexes.clear();
    rightThirdHexes.clear();

    if (board.tiles.isEmpty) return;

    final sqrt3 = sqrt(3.0);
    final hexHalfWidth = sqrt3 / 2.0;

    for (final tile in board.tiles.values) {
      final q = tile.coordinate.q.toDouble();
      final r = tile.coordinate.r.toDouble();
      final hexCenterX = sqrt3 * q + (sqrt3 / 2.0) * r;

      final hexLeftEdgeX = hexCenterX - hexHalfWidth;
      final hexRightEdgeX = hexCenterX + hexHalfWidth;

      // Determine which third(s) this hex belongs to
      bool inLeft = hexLeftEdgeX < leftBoundary;
      bool inRight = hexRightEdgeX > rightBoundary;
      bool inMiddle = hexRightEdgeX > leftBoundary && hexLeftEdgeX < rightBoundary;

      if (inLeft) {
        leftThirdHexes.add(tile.coordinate);
      }
      if (inMiddle) {
        middleThirdHexes.add(tile.coordinate);
      }
      if (inRight) {
        rightThirdHexes.add(tile.coordinate);
      }
    }

    print('DEBUG Recalculated Thirds: left=${leftThirdHexes.length}, middle=${middleThirdHexes.length}, right=${rightThirdHexes.length}');
  }
}
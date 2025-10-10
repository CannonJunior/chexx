import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import '../utils/tile_colors.dart';
import '../models/scenario_builder_state.dart';
import '../models/hex_coordinate.dart';
import '../models/game_unit.dart';
import '../models/game_board.dart';
import '../models/game_state.dart';
import '../models/unit_type_config.dart';
import '../models/game_type_config.dart';
import '../models/hex_orientation.dart';
import '../engine/game_engine.dart';
import '../../core/interfaces/unit_factory.dart';

/// Scenario Builder screen for creating custom game configurations
class ScenarioBuilderScreen extends StatefulWidget {
  final Map<String, dynamic>? initialScenarioData;

  const ScenarioBuilderScreen({super.key, this.initialScenarioData});

  @override
  State<ScenarioBuilderScreen> createState() => _ScenarioBuilderScreenState();
}

class _ScenarioBuilderScreenState extends State<ScenarioBuilderScreen> {
  late ScenarioBuilderState builderState;
  final double hexSize = 50.0;
  Offset? _lastTapPosition;
  late FocusNode _focusNode;

  // Unit type configuration
  UnitTypeSet? currentUnitTypeSet;
  String currentUnitSetName = 'chexx';
  final Map<String, String> availableUnitSets = UnitTypeConfigLoader.getAvailableSetDisplayNames();

  // Game type configuration
  GameTypeConfig? currentGameTypeConfig;
  String currentGameTypeId = 'chexx';
  final Map<String, String> availableGameTypes = GameTypeConfigLoader.getAvailableGameTypeDisplayNames();

  @override
  void initState() {
    super.initState();
    builderState = ScenarioBuilderState();
    _focusNode = FocusNode();

    // Load initial scenario data if provided
    if (widget.initialScenarioData != null) {
      builderState.loadFromScenarioData(widget.initialScenarioData!);
    }

    // Load default game type and unit type set
    _loadGameType(currentGameTypeId);
    _loadUnitTypeSet(currentUnitSetName);

    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Load a game type configuration
  Future<void> _loadGameType(String gameTypeId) async {
    try {
      final gameTypeConfig = await GameTypeConfigLoader.loadGameTypeConfig(gameTypeId);
      setState(() {
        currentGameTypeConfig = gameTypeConfig;
        currentGameTypeId = gameTypeId;
      });

      // Pass the game type config to the builder state
      builderState.setCurrentGameTypeConfig(gameTypeConfig);

      // Auto-load the default unit set for this game type
      if (gameTypeConfig.defaultUnitSet != currentUnitSetName) {
        _loadUnitTypeSet(gameTypeConfig.defaultUnitSet);
      }
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Loading Game Type'),
            content: Text('Failed to load game type "$gameTypeId": $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Load a unit type set and update available unit templates
  Future<void> _loadUnitTypeSet(String setName) async {
    try {
      final unitTypeSet = await UnitTypeConfigLoader.loadUnitTypeSet(setName);
      setState(() {
        currentUnitTypeSet = unitTypeSet;
        currentUnitSetName = setName;
      });

      // Update the available unit templates in the builder state
      _updateAvailableUnitTemplates();

      // Pass the unit type set to the builder state for configuration-based behavior
      builderState.setCurrentUnitTypeSet(unitTypeSet);
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Loading Unit Types'),
            content: Text('Failed to load unit type set "$setName": $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Update available unit templates based on current unit type set
  void _updateAvailableUnitTemplates() {
    if (currentUnitTypeSet == null) return;

    // Clear existing templates
    builderState.availableUnits.clear();

    // Add templates for each unit type in the set for both players
    for (final unitTypeId in currentUnitTypeSet!.unitTypeIds) {
      final config = currentUnitTypeSet!.getUnitConfig(unitTypeId);
      if (config != null) {
        // Convert string ID back to enum for compatibility
        final unitType = _stringToUnitType(unitTypeId);

        // Add for both players
        builderState.availableUnits.addAll([
          UnitTemplate(type: unitType, owner: Player.player1, id: 'p1_$unitTypeId'),
          UnitTemplate(type: unitType, owner: Player.player2, id: 'p2_$unitTypeId'),
        ]);
      }
    }
  }

  /// Convert string unit type ID back to enum (compatibility)
  UnitType _stringToUnitType(String unitTypeId) {
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
  String _getUnitTypeIdFromTemplate(UnitTemplate template) {
    if (currentUnitTypeSet == null) {
      return template.type.toString().split('.').last;
    }

    // First, try to extract the unit type ID directly from template.id
    // Template IDs are formatted as 'p1_unitTypeId' or 'p2_unitTypeId'
    for (final unitTypeId in currentUnitTypeSet!.unitTypeIds) {
      if (template.id.contains(unitTypeId)) {
        // Found the unit type ID in the template ID
        return unitTypeId;
      }
    }

    // Fallback: Look through the current unit type set to find matching type
    for (final unitTypeId in currentUnitTypeSet!.unitTypeIds) {
      final mappedType = _stringToUnitType(unitTypeId);
      if (mappedType == template.type) {
        return unitTypeId;
      }
    }

    // Final fallback to enum name
    return template.type.toString().split('.').last;
  }

  /// Get the actual unit config for a template
  UnitTypeConfig? _getUnitConfigFromTemplate(UnitTemplate template) {
    final unitTypeId = _getUnitTypeIdFromTemplate(template);
    return currentUnitTypeSet?.getUnitConfig(unitTypeId);
  }

  /// Get display name from config or fallback to enum
  String _getActualUnitName(UnitTemplate template) {
    print('DEBUG: _getActualUnitName - Template ID: ${template.id}, Type: ${template.type.name}');

    final config = _getUnitConfigFromTemplate(template);
    if (config != null) {
      print('DEBUG: _getActualUnitName - Using config name: ${config.name}');
      return config.name;
    }

    // Extract unit type from template ID for WWII units
    if (template.id.contains('_')) {
      final parts = template.id.split('_');
      if (parts.length > 1) {
        final unitTypeFromId = parts[1]; // e.g., "p1_infantry" -> "infantry"
        print('DEBUG: _getActualUnitName - Extracted from ID: $unitTypeFromId');

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
            print('DEBUG: _getActualUnitName - Unknown type from ID, falling back to enum');
            return _getUnitTypeName(template.type);
        }
      }
    }

    print('DEBUG: _getActualUnitName - Falling back to enum name');
    return _getUnitTypeName(template.type);
  }

  /// Get display symbol from config or fallback to enum
  String _getActualUnitSymbol(UnitTemplate template) {
    print('DEBUG: _getActualUnitSymbol - Template ID: ${template.id}, Type: ${template.type.name}');

    final config = _getUnitConfigFromTemplate(template);
    if (config != null) {
      print('DEBUG: _getActualUnitSymbol - Using config symbol: ${config.symbol}');
      return config.symbol;
    }

    // Extract unit type from template ID for WWII units
    if (template.id.contains('_')) {
      final parts = template.id.split('_');
      if (parts.length > 1) {
        final unitTypeFromId = parts[1]; // e.g., "p1_infantry" -> "infantry"
        print('DEBUG: _getActualUnitSymbol - Extracted from ID: $unitTypeFromId');

        // Convert to proper symbols for WWII units
        switch (unitTypeFromId.toLowerCase()) {
          case 'infantry':
            return 'I';
          case 'armor':
            return 'A';
          case 'artillery':
            return 'R';
          default:
            print('DEBUG: _getActualUnitSymbol - Unknown type from ID, falling back to enum');
            return _getUnitSymbol(template.type);
        }
      }
    }

    print('DEBUG: _getActualUnitSymbol - Falling back to enum symbol');
    return _getUnitSymbol(template.type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: Row(
            children: [
              // Left panel: Unit palette
              Container(
                width: 200,
                color: Colors.grey.shade900,
                child: _buildUnitPalette(),
              ),

              // Main area: Game board
              Expanded(
                child: Column(
                  children: [
                    // Top toolbar
                    _buildTopToolbar(),

                    // Game board
                    Expanded(
                      child: _buildGameBoard(),
                    ),
                  ],
                ),
              ),

              // Right panel: Controls
              Container(
                width: 200,
                color: Colors.grey.shade900,
                child: _buildControlPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitPalette() {
    return AnimatedBuilder(
      animation: builderState,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade800,
              width: double.infinity,
              child: const Text(
                'Unit Palette',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  // Game Type Section
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Game Type',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.gamepad, color: Colors.white, size: 18),
                        tooltip: 'Load Game Type',
                        onSelected: (String gameTypeId) {
                          _loadGameType(gameTypeId);
                        },
                        itemBuilder: (BuildContext context) {
                          return availableGameTypes.entries.map((entry) {
                            final isSelected = entry.key == currentGameTypeId;
                            return PopupMenuItem<String>(
                              value: entry.key,
                              child: Row(
                                children: [
                                  if (isSelected)
                                    const Icon(Icons.check, size: 16, color: Colors.green),
                                  if (isSelected) const SizedBox(width: 8),
                                  Expanded(child: Text(entry.value)),
                                ],
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Unit Types',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                        tooltip: 'Load Unit Type Set',
                        onSelected: (String setName) {
                          _loadUnitTypeSet(setName);
                        },
                        itemBuilder: (BuildContext context) {
                          return availableUnitSets.entries.map((entry) {
                            final isSelected = entry.key == currentUnitSetName;
                            return PopupMenuItem<String>(
                              value: entry.key,
                              child: Row(
                                children: [
                                  if (isSelected)
                                    const Icon(Icons.check, size: 16, color: Colors.green),
                                  if (isSelected) const SizedBox(width: 8),
                                  Expanded(child: Text(entry.value)),
                                ],
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPlayerUnits('Player 1 (Blue)', Player.player1),
                  const SizedBox(height: 16),
                  _buildPlayerUnits('Player 2 (Red)', Player.player2),
                  const SizedBox(height: 24),
                  _buildTileTypes(),
                  const SizedBox(height: 24),
                  _buildStructureTypes(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerUnits(String title, Player player) {
    final units = builderState.availableUnits
        .where((unit) => unit.owner == player)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: player == Player.player1 ? Colors.blue.shade300 : Colors.red.shade300,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: units.map((unit) => _buildUnitButton(unit)).toList(),
        ),
      ],
    );
  }

  Widget _buildUnitButton(UnitTemplate unit) {
    final isSelected = builderState.selectedUnitTemplate == unit;
    final baseColor = unit.owner == Player.player1 ? Colors.blue : Colors.red;

    return GestureDetector(
      onTap: () => builderState.selectUnitTemplate(isSelected ? null : unit),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: baseColor.withOpacity(isSelected ? 0.8 : 0.6),
          border: Border.all(
            color: isSelected ? Colors.yellow : Colors.white30,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _getActualUnitSymbol(unit),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTileTypes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tile Types',
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _buildTileTypeButton(HexType.normal, 'Normal', TileColors.getButtonColorForTileType(HexType.normal)),
            _buildTileTypeButton(HexType.meta, 'Meta', TileColors.getButtonColorForTileType(HexType.meta)),
            _buildTileTypeButton(HexType.blocked, 'Blocked', TileColors.getButtonColorForTileType(HexType.blocked)),
            _buildTileTypeButton(HexType.ocean, 'Ocean', TileColors.getButtonColorForTileType(HexType.ocean)),
            _buildTileTypeButton(HexType.beach, 'Beach', TileColors.getButtonColorForTileType(HexType.beach)),
            _buildTileTypeButton(HexType.hill, 'Hill', TileColors.getButtonColorForTileType(HexType.hill)),
            _buildTileTypeButton(HexType.town, 'Town', TileColors.getButtonColorForTileType(HexType.town)),
            _buildTileTypeButton(HexType.forest, 'Forest', TileColors.getButtonColorForTileType(HexType.forest)),
            _buildTileTypeButton(HexType.hedgerow, 'Hedgerow', TileColors.getButtonColorForTileType(HexType.hedgerow)),
            _buildSpecialModeButton('Create New', Colors.blue.shade300, isCreateNew: true),
            _buildSpecialModeButton('Remove', Colors.red.shade400, isRemove: true),
          ],
        ),
      ],
    );
  }

  Widget _buildStructureTypes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Structure Types',
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: builderState.availableStructures.map((structure) {
            return _buildStructureTypeButton(structure);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTileTypeButton(HexType tileType, String name, Color color) {
    final isSelected = builderState.selectedTileType == tileType;

    return GestureDetector(
      onTap: () => builderState.selectTileType(tileType),
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.8) : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getTileTypeIcon(tileType),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialModeButton(String name, Color color, {bool isCreateNew = false, bool isRemove = false}) {
    final isSelected = (isCreateNew && builderState.isCreateNewMode) || (isRemove && builderState.isRemoveMode);

    return GestureDetector(
      onTap: () {
        if (isCreateNew) {
          builderState.enableCreateNewMode();
        } else if (isRemove) {
          builderState.enableRemoveMode();
        }
      },
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.8) : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCreateNew ? Icons.add_circle : Icons.delete,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructureTypeButton(StructureTemplate structure) {
    final isSelected = builderState.selectedStructureTemplate == structure;
    final color = _getStructureTypeColor(structure.type);
    final name = _getStructureTypeName(structure.type);

    return GestureDetector(
      onTap: () => builderState.selectStructureTemplate(structure),
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.8) : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStructureTypeIcon(structure.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTileTypeIcon(HexType tileType) {
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

  IconData _getStructureTypeIcon(StructureType structureType) {
    switch (structureType) {
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
    }
  }

  Color _getStructureTypeColor(StructureType structureType) {
    switch (structureType) {
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
    }
  }

  String _getStructureTypeName(StructureType structureType) {
    switch (structureType) {
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
    }
  }

  Widget _buildTopToolbar() {
    return Container(
      height: 50,
      color: Colors.grey.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Scenario Builder',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // Orientation toggle button
          AnimatedBuilder(
            animation: builderState,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: () => builderState.toggleHexOrientation(),
                  icon: Icon(
                    builderState.hexOrientation == HexOrientation.flat
                        ? Icons.hexagon_outlined
                        : Icons.change_history_outlined,
                    size: 16,
                  ),
                  label: Text(
                    builderState.hexOrientation == HexOrientation.flat
                        ? 'Flat'
                        : 'Pointy',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: builderState.hexOrientation == HexOrientation.flat
                        ? Colors.blue.shade600
                        : Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(80, 36),
                  ),
                ),
              );
            },
          ),

          // Board thirds buttons
          AnimatedBuilder(
            animation: builderState,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lines toggle button
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: ElevatedButton.icon(
                      onPressed: () => builderState.toggleVerticalLines(),
                      icon: Icon(
                        builderState.showVerticalLines
                            ? Icons.view_column
                            : Icons.view_column_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        'Lines',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: builderState.showVerticalLines
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(80, 36),
                      ),
                    ),
                  ),
                  // Third highlighting buttons column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Left third toggle
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        child: ElevatedButton(
                          onPressed: () => builderState.toggleLeftThirdHighlight(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: builderState.highlightLeftThird
                                ? Colors.cyan.shade600
                                : Colors.grey.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(60, 28),
                          ),
                          child: const Text('Left', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      // Middle third toggle
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        child: ElevatedButton(
                          onPressed: () => builderState.toggleMiddleThirdHighlight(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: builderState.highlightMiddleThird
                                ? Colors.yellow.shade700
                                : Colors.grey.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(60, 28),
                          ),
                          child: const Text('Mid', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      // Right third toggle
                      ElevatedButton(
                        onPressed: () => builderState.toggleRightThirdHighlight(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: builderState.highlightRightThird
                              ? Colors.pink.shade600
                              : Colors.grey.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(60, 28),
                        ),
                        child: const Text('Right', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(width: 8),

          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back to Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return AnimatedBuilder(
      animation: builderState,
      builder: (context, child) {
        return Container(
          color: const Color(0xFF1a1a2e),
          child: GestureDetector(
            onTapDown: (details) => _handleBoardTap(details.globalPosition),
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: CustomPaint(
              painter: ScenarioBuilderPainter(builderState, hexSize, this),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlPanel() {
    return AnimatedBuilder(
      animation: builderState,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade800,
              width: double.infinity,
              child: const Text(
                'Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scenario name input
                    const Text(
                      'Scenario Name:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      onChanged: builderState.setScenarioName,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter scenario name...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Unit info card (if unit is selected)
                    if (builderState.selectedPlacedUnit != null) ...[
                      _buildUnitInfoCard(builderState.selectedPlacedUnit!),
                      const SizedBox(height: 20),
                    ],

                    // Instructions
                    const Text(
                      'Instructions:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildInstructionItem(
                      '• Click units in palette to select',
                    ),
                    _buildInstructionItem(
                      '• Click board to place selected unit',
                    ),
                    _buildInstructionItem(
                      '• Double-click hex to toggle Meta',
                    ),
                    _buildInstructionItem(
                      '• Click placed unit to view info',
                    ),
                    _buildInstructionItem(
                      '• ↑/↓ arrows: increment/decrement health',
                    ),
                    _buildInstructionItem(
                      '• Click again on selected unit to remove',
                    ),

                    const Spacer(),

                    // Win Conditions Section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Win Conditions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Player 1 Points:',
                                      style: TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                    TextField(
                                      controller: TextEditingController(
                                        text: builderState.player1WinPoints.toString(),
                                      ),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.all(4),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.blue.shade300),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final points = int.tryParse(value);
                                        if (points != null && points > 0) {
                                          builderState.player1WinPoints = points;
                                          builderState.notifyListeners();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Player 2 Points:',
                                      style: TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                    TextField(
                                      controller: TextEditingController(
                                        text: builderState.player2WinPoints.toString(),
                                      ),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.all(4),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.red.shade300),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final points = int.tryParse(value);
                                        if (points != null && points > 0) {
                                          builderState.player2WinPoints = points;
                                          builderState.notifyListeners();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Action buttons
                    _buildActionButton(
                      'Clear All Units',
                      Colors.orange.shade600,
                      () => _showClearUnitsDialog(),
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      'Save Scenario',
                      Colors.green.shade600,
                      () => _saveScenario(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      // Handle health increment/decrement with arrow keys
      if (key == LogicalKeyboardKey.arrowUp) {
        if (builderState.incrementSelectedUnitHealth()) {
          setState(() {}); // Update UI
        }
        return;
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        if (builderState.decrementSelectedUnitHealth()) {
          setState(() {}); // Update UI
        }
        return;
      }

      // Handle cursor movement with QWEASD keys
      if (key == LogicalKeyboardKey.keyQ ||
          key == LogicalKeyboardKey.keyW ||
          key == LogicalKeyboardKey.keyE ||
          key == LogicalKeyboardKey.keyA ||
          key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.keyD) {
        builderState.moveCursor(key.keyLabel.toLowerCase());
        setState(() {}); // Update UI
      }
    }
  }

  void _handleBoardTap(Offset globalPosition) {
    _lastTapPosition = globalPosition; // Store for double-tap handling

    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);

    // Adjust for the left panel width and top toolbar
    final adjustedPosition = Offset(
      localPosition.dx - 200, // Subtract left panel width
      localPosition.dy - 50,  // Subtract top toolbar height
    );

    final hexCoord = _screenToHex(adjustedPosition, renderBox.size);
    if (hexCoord == null) return;

    // Handle removal mode - removes everything from the hex
    if (builderState.isRemoveMode) {
      builderState.placeItem(hexCoord); // Use placeItem which handles remove mode properly
      return;
    }

    // Handle specific type placement/removal based on what's currently selected
    if (builderState.selectedUnitTemplate != null) {
      // Unit mode: interact with units
      final existingUnit = builderState.getUnitAt(hexCoord);
      if (existingUnit != null) {
        // First click: select unit for info display
        final placedUnit = builderState.getPlacedUnitAt(hexCoord);
        if (placedUnit != null && builderState.selectedPlacedUnit != placedUnit) {
          builderState.selectPlacedUnit(placedUnit);
          return;
        }
        // Second click (or if already selected): remove existing unit
        builderState.removeUnit(hexCoord);
        builderState.selectPlacedUnit(null); // Clear selection when removing
        return;
      }
      // Place new unit on empty hex
      builderState.placeItem(hexCoord);
      return;
    }

    if (builderState.selectedStructureTemplate != null) {
      // Structure mode: prioritize structure interaction, but allow unit selection
      final existingStructure = builderState.getStructureAt(hexCoord);
      if (existingStructure != null) {
        // Remove existing structure
        builderState.removeStructure(hexCoord);
        return;
      }

      // Check for unit selection if no structure at this position
      final placedUnit = builderState.getPlacedUnitAt(hexCoord);
      if (placedUnit != null) {
        builderState.selectPlacedUnit(placedUnit);
        return;
      }

      // Place new structure on empty hex
      builderState.placeItem(hexCoord);
      return;
    }

    if (builderState.selectedTileType != null) {
      // Tile mode: prioritize tile interaction, but allow unit selection
      final existingTile = builderState.board.getTile(hexCoord);

      // Check for unit selection first (before tile operations)
      final placedUnit = builderState.getPlacedUnitAt(hexCoord);
      if (placedUnit != null) {
        builderState.selectPlacedUnit(placedUnit);
        return;
      }

      if (existingTile != null && existingTile.type == builderState.selectedTileType) {
        // Clicking on a tile that already has the selected type - remove the entire tile
        builderState.removeTile(hexCoord);
      } else {
        // Place or change tile type
        builderState.placeItem(hexCoord);
      }
      return;
    }

    if (builderState.isCreateNewMode) {
      // Create new hex mode
      builderState.placeItem(hexCoord);
      return;
    }

    // If nothing is selected, check for unit selection
    final placedUnit = builderState.getPlacedUnitAt(hexCoord);
    if (placedUnit != null) {
      // Select the unit for info display
      builderState.selectPlacedUnit(placedUnit);
    } else {
      // Clear selection if clicking on empty space
      builderState.selectPlacedUnit(null);
    }
  }

  /// Handle pan start - detect if user is starting to drag a vertical line
  void _handlePanStart(DragStartDetails details) {
    // Only allow dragging in pointy orientation
    if (builderState.hexOrientation != HexOrientation.pointy) return;
    if (!builderState.showVerticalLines) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    // Adjust for the left panel width and top toolbar
    final adjustedPosition = Offset(
      localPosition.dx - 200, // Subtract left panel width
      localPosition.dy - 50,  // Subtract top toolbar height
    );

    final size = renderBox.size;
    final centerX = (size.width - 400) / 2; // Subtract panels

    // Convert line x-coordinates from normalized space to screen space
    final leftLineScreenX = centerX + hexSize * builderState.leftLineX;
    final rightLineScreenX = centerX + hexSize * builderState.rightLineX;

    // Check if tap is near left line (within 20 pixels)
    const tapThreshold = 20.0;
    if ((adjustedPosition.dx - leftLineScreenX).abs() < tapThreshold) {
      builderState.startDraggingLine(DraggingLine.leftLine, adjustedPosition.dx);
      return;
    }

    // Check if tap is near right line (within 20 pixels)
    if ((adjustedPosition.dx - rightLineScreenX).abs() < tapThreshold) {
      builderState.startDraggingLine(DraggingLine.rightLine, adjustedPosition.dx);
      return;
    }
  }

  /// Handle pan update - update line position during drag
  void _handlePanUpdate(DragUpdateDetails details) {
    if (builderState.currentlyDraggedLine == null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    // Adjust for the left panel width and top toolbar
    final adjustedPosition = Offset(
      localPosition.dx - 200, // Subtract left panel width
      localPosition.dy - 50,  // Subtract top toolbar height
    );

    final size = renderBox.size;
    final centerX = (size.width - 400) / 2; // Subtract panels

    // Convert screen x to normalized x-coordinate (divide by hexSize, subtract centerX offset)
    final normalizedX = (adjustedPosition.dx - centerX) / hexSize;

    builderState.updateDraggedLinePosition(normalizedX);
  }

  /// Handle pan end - snap line to nearest hex edge
  void _handlePanEnd(DragEndDetails details) {
    if (builderState.currentlyDraggedLine == null) return;
    builderState.endDraggingLine();
  }

  HexCoordinate? _screenToHex(Offset screenPos, Size canvasSize) {
    final centerX = (canvasSize.width - 400) / 2; // Subtract panels
    final centerY = (canvasSize.height - 50) / 2;  // Subtract toolbar

    final gameX = screenPos.dx - centerX;
    final gameY = screenPos.dy - centerY;

    return HexCoordinate.fromPixel(gameX, gameY, hexSize, builderState.hexOrientation);
  }

  String _getUnitSymbol(UnitType type) {
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

  void _showClearUnitsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade800,
        title: const Text(
          'Clear All Units',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove all placed units?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          TextButton(
            onPressed: () {
              builderState.clearUnits();
              Navigator.of(context).pop();
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: Colors.orange.shade400),
            ),
          ),
        ],
      ),
    );
  }

  void _saveScenario() {
    final config = builderState.generateScenarioConfig();
    final jsonString = const JsonEncoder.withIndent('  ').convert(config);

    // Create and download file
    final blob = html.Blob([jsonString], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = '${builderState.scenarioName.replaceAll(' ', '_').toLowerCase()}.json'
      ..click();

    html.Url.revokeObjectUrl(url);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scenario "${builderState.scenarioName}" saved successfully!'),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  /// Build unit info card for selected placed unit
  Widget _buildUnitInfoCard(PlacedUnit unit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unit.template.owner == Player.player1
            ? Colors.blue.shade900.withOpacity(0.9)
            : Colors.red.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: unit.template.owner == Player.player1
              ? Colors.blue.shade400
              : Colors.red.shade400,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Unit Info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => builderState.selectPlacedUnit(null),
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Unit type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: unit.template.owner == Player.player1
                  ? Colors.blue.shade600
                  : Colors.red.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _getActualUnitName(unit.template),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Position info
          _buildInfoRow('Position', '(${unit.position.q}, ${unit.position.r})', Icons.location_on),
          _buildInfoRow('Owner', unit.template.owner == Player.player1 ? 'Player 1' : 'Player 2', Icons.person),

          const SizedBox(height: 8),

          // Unit stats
          _buildInfoRow('Current Health', '${_getCurrentHealth(unit)}', Icons.favorite),
          _buildInfoRow('Max Health', '${_getActualUnitMaxHealth(unit.template)}', Icons.favorite_border),
          _buildInfoRow('Starting Health', '${_getActualUnitStartingHealth(unit.template)}', Icons.favorite_outline),
          _buildInfoRow('Movement', '${_getActualUnitMovementRange(unit.template)}', Icons.directions_run),
          _buildInfoRow('Attack Range', '${_getActualUnitAttackRange(unit.template)}', Icons.gps_fixed),
          _buildInfoRow('Attack Damage', '${_getActualUnitAttackDamage(unit.template)}', Icons.flash_on),

          const SizedBox(height: 8),

          // Abilities section
          const Text(
            'Abilities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          ..._buildUnitAbilitiesForBuilder(unit.template.type),

          const SizedBox(height: 12),

          // Parametric Info section (Scenario Builder only)
          const Text(
            'Parametric Info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          ..._buildParametricInfo(unit.template),
        ],
      ),
    );
  }

  /// Build info row for unit info card
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Get unit type name for display
  String _getUnitTypeName(UnitType unitType) {
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

  /// Get unit max health
  int _getUnitMaxHealth(UnitType unitType) {
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

  /// Get unit movement range
  int _getUnitMovementRange(UnitType unitType) {
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

  /// Get unit attack range
  int _getUnitAttackRange(UnitType unitType) {
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

  /// Get unit attack damage
  int _getUnitAttackDamage(UnitType unitType) {
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

  /// Build unit abilities for scenario builder
  List<Widget> _buildUnitAbilitiesForBuilder(UnitType unitType) {
    switch (unitType) {
      case UnitType.scout:
        return [
          _buildAbilityCard('Long Range', 'Attack range +2'),
        ];
      case UnitType.knight:
        return [
          _buildAbilityCard('Heavy Attack', 'Deals 2 damage'),
          _buildAbilityCard('L-Shaped Movement', 'Moves in L pattern'),
        ];
      case UnitType.guardian:
        return [
          _buildAbilityCard('Defensive', 'High health unit'),
          _buildAbilityCard('Swap', 'Can swap with friendly'),
        ];
      case UnitType.minor:
      default:
        return [
          _buildAbilityCard('Basic Unit', 'Standard combat'),
        ];
    }
  }

  /// Build ability card for unit info
  Widget _buildAbilityCard(String name, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  /// Build parametric info section for scenario builder
  List<Widget> _buildParametricInfo(UnitTemplate template) {
    return [
      _buildParametricInfoRow('isIncrementable', _getActualIsIncrementable(template).toString(), Icons.trending_up),
      _buildParametricInfoRow('Movement Type', _getActualMovementType(template), Icons.navigation),
      _buildParametricInfoRow('Can Swap', _getCanSwap(template.type).toString(), Icons.swap_horiz),
      _buildParametricInfoRow('Base Experience', _getBaseExperience(template.type).toString(), Icons.star_outline),
      _buildParametricInfoRow('Level Cap', _getLevelCap(template.type).toString(), Icons.vertical_align_top),
    ];
  }

  /// Build parametric info row
  Widget _buildParametricInfoRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange.shade300, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.orange.shade200,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Get isIncrementable property for unit type
  bool _getIsIncrementable(UnitType unitType) {
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
  String _getMovementType(UnitType unitType) {
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
  bool _getCanSwap(UnitType unitType) {
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
  int _getBaseExperience(UnitType unitType) {
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
  int _getLevelCap(UnitType unitType) {
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
  int _getActualUnitMaxHealth(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.maxHealth ?? _getUnitMaxHealth(template.type);
  }

  /// Get movement range from configuration or fallback to enum
  int _getActualUnitMovementRange(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.movementRange ?? _getUnitMovementRange(template.type);
  }

  /// Get attack range from configuration or fallback to enum
  int _getActualUnitAttackRange(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.attackRange ?? _getUnitAttackRange(template.type);
  }

  /// Get attack damage from configuration or fallback to enum
  int _getActualUnitAttackDamage(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.attackDamage ?? _getUnitAttackDamage(template.type);
  }

  /// Get isIncrementable from configuration or fallback to enum
  bool _getActualIsIncrementable(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.isIncrementable ?? _getIsIncrementable(template.type);
  }

  /// Get movement type from configuration or fallback to enum
  String _getActualMovementType(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.movementType ?? _getMovementType(template.type);
  }

  /// Get starting health from configuration or fallback to enum
  int _getActualUnitStartingHealth(UnitTemplate template) {
    final config = _getUnitConfigFromTemplate(template);
    return config?.health ?? 1; // Default starting health is 1
  }

  /// Get current health of a placed unit
  int _getCurrentHealth(PlacedUnit unit) {
    return unit.customHealth ?? _getActualUnitStartingHealth(unit.template);
  }
}

/// Custom painter for the scenario builder board
class ScenarioBuilderPainter extends CustomPainter {
  final ScenarioBuilderState state;
  final double hexSize;
  final _ScenarioBuilderScreenState widgetState;

  ScenarioBuilderPainter(this.state, this.hexSize, this.widgetState);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw hex tiles
    _drawHexTiles(canvas, size, centerX, centerY);

    // Draw placed structures (above tiles, below units)
    _drawPlacedStructures(canvas, size, centerX, centerY);

    // Draw vertical partition lines (if enabled)
    _drawVerticalLines(canvas, size, centerX, centerY);

    // Draw placed units (on top)
    _drawPlacedUnits(canvas, size, centerX, centerY);
  }

  void _drawHexTiles(Canvas canvas, Size size, double centerX, double centerY) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black54;

    final goldHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.amber.shade600;

    final cursorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.cyan.shade400;

    // Draw expanded grid for tile creation (up to radius 8 for visual creation area)
    final allPositions = HexCoordinate.hexesInRange(const HexCoordinate(0, 0, 0), 8);

    for (final coord in allPositions) {
      final vertices = _getHexVertices(coord, centerX, centerY);
      final path = Path();

      if (vertices.isNotEmpty) {
        path.moveTo(vertices[0].dx, vertices[0].dy);
        for (int i = 1; i < vertices.length; i++) {
          path.lineTo(vertices[i].dx, vertices[i].dy);
        }
        path.close();

        // Determine tile type and fill color
        final existingTile = state.board.getTile(coord);
        Paint fillPaint;

        if (existingTile != null) {
          // Existing tile - use appropriate color based on tile type
          fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = _getTileTypeColor(existingTile.type);
        } else {
          // Empty grid space - use subtle background
          fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.grey.shade200.withOpacity(0.3);
        }

        // Fill hex
        canvas.drawPath(path, fillPaint);

        // Draw border (lighter for empty spaces)
        final borderPaint = existingTile != null ? strokePaint :
          (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Colors.black26);
        canvas.drawPath(path, borderPaint);

        // Board thirds: Highlight hexes by third membership (when individual third toggles are active)
        if (state.highlightLeftThird || state.highlightMiddleThird || state.highlightRightThird) {
          final inLeft = state.leftThirdHexes.contains(coord);
          final inMiddle = state.middleThirdHexes.contains(coord);
          final inRight = state.rightThirdHexes.contains(coord);

          // Determine which highlights should be shown
          final showLeft = state.highlightLeftThird && inLeft;
          final showMiddle = state.highlightMiddleThird && inMiddle;
          final showRight = state.highlightRightThird && inRight;

          // Use distinct colors for each third
          if (showLeft && showMiddle) {
            // Hex belongs to both left and middle (on boundary) and both are highlighted
            final boundaryOverlay = Paint()
              ..color = Colors.purple.withOpacity(0.2)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, boundaryOverlay);
          } else if (showMiddle && showRight) {
            // Hex belongs to both middle and right (on boundary) and both are highlighted
            final boundaryOverlay = Paint()
              ..color = Colors.orange.withOpacity(0.2)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, boundaryOverlay);
          } else if (showLeft) {
            // Hex in left third and left is highlighted
            final leftOverlay = Paint()
              ..color = Colors.cyan.withOpacity(0.15)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, leftOverlay);
          } else if (showMiddle) {
            // Hex in middle third and middle is highlighted
            final middleOverlay = Paint()
              ..color = Colors.yellow.withOpacity(0.15)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, middleOverlay);
          } else if (showRight) {
            // Hex in right third and right is highlighted
            final rightOverlay = Paint()
              ..color = Colors.pink.withOpacity(0.15)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, rightOverlay);
          }
        }

        // Draw gold highlight for last edited tile
        if (state.lastEditedTile == coord) {
          canvas.drawPath(path, goldHighlightPaint);
        }

        // Draw cursor highlight
        if (state.cursorPosition == coord) {
          canvas.drawPath(path, cursorPaint);
        }
      }
    }

  }

  void _drawPlacedStructures(Canvas canvas, Size size, double centerX, double centerY) {
    for (final placedStructure in state.placedStructures) {
      final center = _hexToScreen(placedStructure.position, centerX, centerY);
      final size = hexSize * 0.9; // Increased from 0.6 to 0.9 to be visible under units

      // Structure colors based on type
      final Color structureColor = _getStructureColor(placedStructure.template.type);

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = structureColor;

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.black87;

      // Draw structure shape based on type
      switch (placedStructure.template.type) {
        case StructureType.bunker:
          // Draw bunker as a square
          final rect = Rect.fromCenter(center: center, width: size, height: size);
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, strokePaint);
          break;
        case StructureType.bridge:
          // Draw bridge as a rounded rectangle
          final rect = Rect.fromCenter(center: center, width: size * 1.2, height: size * 0.6);
          final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.1));
          canvas.drawRRect(rrect, fillPaint);
          canvas.drawRRect(rrect, strokePaint);
          break;
        case StructureType.sandbag:
          // Draw sandbag as multiple small circles
          final radius = size * 0.15;
          for (int i = 0; i < 3; i++) {
            final offset = Offset(center.dx + (i - 1) * radius, center.dy);
            canvas.drawCircle(offset, radius, fillPaint);
            canvas.drawCircle(offset, radius, strokePaint);
          }
          break;
        case StructureType.barbwire:
          // Draw barbwire as zigzag lines
          final path = Path();
          final halfSize = size * 0.5;
          path.moveTo(center.dx - halfSize, center.dy);
          for (int i = 0; i < 4; i++) {
            final x = center.dx - halfSize + (i * halfSize / 2);
            final y = center.dy + ((i % 2 == 0) ? -halfSize * 0.3 : halfSize * 0.3);
            path.lineTo(x, y);
          }
          path.lineTo(center.dx + halfSize, center.dy);
          canvas.drawPath(path, strokePaint);
          break;
        case StructureType.dragonsTeeth:
          // Draw dragon's teeth as triangles
          final path = Path();
          final halfSize = size * 0.4;
          path.moveTo(center.dx, center.dy - halfSize);
          path.lineTo(center.dx - halfSize, center.dy + halfSize);
          path.lineTo(center.dx + halfSize, center.dy + halfSize);
          path.close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, strokePaint);
          break;
      }

      // Draw structure symbol
      final textPainter = TextPainter(
        text: TextSpan(
          text: _getStructureSymbol(placedStructure.template.type),
          style: TextStyle(
            color: Colors.white,
            fontSize: hexSize * 0.25,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final textOffset = Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawPlacedUnits(Canvas canvas, Size size, double centerX, double centerY) {
    for (final placedUnit in state.placedUnits) {
      final center = _hexToScreen(placedUnit.position, centerX, centerY);
      final radius = hexSize * 0.4;

      // Check if unit is incrementable
      final isIncrementable = widgetState._getActualIsIncrementable(placedUnit.template);
      final health = widgetState._getCurrentHealth(placedUnit);

      // Unit colors
      final baseColor = placedUnit.template.owner == Player.player1
          ? Colors.blue.shade600
          : Colors.red.shade600;

      if (isIncrementable && health <= 6) {
        // Draw multiple icons based on health (1-6)
        _drawMultipleIconsForUnit(canvas, center, radius, baseColor, health, placedUnit.template);
      } else if (isIncrementable && health > 6) {
        // Draw single icon with health number for health > 6
        _drawSingleIconWithNumber(canvas, center, radius, baseColor, health, placedUnit.template);
      } else {
        // Draw standard unit (non-incrementable)
        _drawStandardUnit(canvas, center, radius, baseColor, placedUnit.template);
      }
    }
  }

  void _drawMultipleIconsForUnit(Canvas canvas, Offset center, double radius, Color baseColor, int health, UnitTemplate template) {
    final iconRadius = radius * 0.6; // Smaller icons when multiple
    final positions = _calculateIconPositions(center, health, iconRadius);

    for (final position in positions) {
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor;

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.black87;

      canvas.drawCircle(position, iconRadius, fillPaint);
      canvas.drawCircle(position, iconRadius, strokePaint);

      // Draw unit symbol on each icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: widgetState._getActualUnitSymbol(template),
          style: TextStyle(
            color: Colors.white,
            fontSize: iconRadius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawSingleIconWithNumber(Canvas canvas, Offset center, double radius, Color baseColor, int health, UnitTemplate template) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black87;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw health number
    final textPainter = TextPainter(
      text: TextSpan(
        text: health.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawStandardUnit(Canvas canvas, Offset center, double radius, Color baseColor, UnitTemplate template) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black87;

    // Draw unit circle
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw unit type symbol
    final textPainter = TextPainter(
      text: TextSpan(
        text: widgetState._getActualUnitSymbol(template),
        style: TextStyle(
          color: Colors.white,
          fontSize: hexSize * 0.3,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  List<Offset> _calculateIconPositions(Offset center, int count, double iconRadius) {
    List<Offset> positions = [];

    // Increased spacing multiplier for better visual separation (matching game mode)
    final spacing = iconRadius * 1.5;

    if (count == 1) {
      positions.add(center);
    } else if (count == 2) {
      positions.add(Offset(center.dx - spacing, center.dy));
      positions.add(Offset(center.dx + spacing, center.dy));
    } else if (count == 3) {
      positions.add(Offset(center.dx, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy + spacing * 0.6));
      positions.add(Offset(center.dx + spacing, center.dy + spacing * 0.6));
    } else if (count == 4) {
      positions.add(Offset(center.dx - spacing, center.dy - spacing));
      positions.add(Offset(center.dx + spacing, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy + spacing));
      positions.add(Offset(center.dx + spacing, center.dy + spacing));
    } else if (count == 5) {
      positions.add(Offset(center.dx, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy - spacing * 0.3));
      positions.add(Offset(center.dx + spacing, center.dy - spacing * 0.3));
      positions.add(Offset(center.dx - spacing, center.dy + spacing));
      positions.add(Offset(center.dx + spacing, center.dy + spacing));
    } else if (count == 6) {
      positions.add(Offset(center.dx - spacing, center.dy - spacing));
      positions.add(Offset(center.dx, center.dy - spacing));
      positions.add(Offset(center.dx + spacing, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy + spacing));
      positions.add(Offset(center.dx, center.dy + spacing));
      positions.add(Offset(center.dx + spacing, center.dy + spacing));
    }

    return positions;
  }

  /// Draw health indicators as small dots around the unit
  void _drawHealthIndicators(Canvas canvas, Offset center, int health) {
    const dotRadius = 3.0;
    const spacing = 8.0;
    final healthPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green.shade400;

    final healthStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black87;

    // Draw health dots in a line below the unit
    final startX = center.dx - ((health - 1) * spacing) / 2;
    final dotY = center.dy + hexSize * 0.6;

    for (int i = 0; i < health; i++) {
      final dotX = startX + (i * spacing);
      final dotCenter = Offset(dotX, dotY);

      canvas.drawCircle(dotCenter, dotRadius, healthPaint);
      canvas.drawCircle(dotCenter, dotRadius, healthStrokePaint);
    }
  }

  List<Offset> _getHexVertices(HexCoordinate hex, double centerX, double centerY) {
    final center = _hexToScreen(hex, centerX, centerY);
    final vertices = <Offset>[];

    for (int i = 0; i < 6; i++) {
      // Calculate hexagon vertices based on orientation
      double angle;
      if (state.hexOrientation == HexOrientation.flat) {
        // Flat-top orientation: first vertex at angle 0 (flat top/bottom)
        angle = i * pi / 3;
      } else {
        // Pointy-top orientation: first vertex at angle π/6 (pointed top/bottom)
        angle = (i * pi / 3) + (pi / 6);
      }

      final x = center.dx + hexSize * cos(angle);
      final y = center.dy + hexSize * sin(angle);
      vertices.add(Offset(x, y));
    }

    return vertices;
  }

  Offset _hexToScreen(HexCoordinate hex, double centerX, double centerY) {
    final (x, y) = hex.toPixel(hexSize, state.hexOrientation);
    return Offset(centerX + x, centerY + y);
  }

  String _getUnitSymbol(UnitType type) {
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

  Color _getStructureColor(StructureType type) {
    switch (type) {
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
    }
  }

  String _getStructureSymbol(StructureType type) {
    switch (type) {
      case StructureType.bunker:
        return 'B';
      case StructureType.bridge:
        return '=';
      case StructureType.sandbag:
        return 'S';
      case StructureType.barbwire:
        return 'W';
      case StructureType.dragonsTeeth:
        return 'T';
    }
  }

  Color _getTileTypeColor(HexType type) {
    return TileColors.getColorForTileType(type);
  }

  void _drawVerticalLines(Canvas canvas, Size size, double centerX, double centerY) {
    if (!state.showVerticalLines) return;

    // Convert normalized x-coordinates to screen x-coordinates
    // The boundaries are stored in normalized space (as if hexSize = 1)
    // Multiply by hexSize to get actual screen coordinates
    final leftLineScreenX = centerX + hexSize * state.leftLineX;
    final rightLineScreenX = centerX + hexSize * state.rightLineX;

    // Draw vertical lines from top to bottom of canvas
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw left dividing line
    canvas.drawLine(
      Offset(leftLineScreenX, 0),
      Offset(leftLineScreenX, size.height),
      linePaint,
    );

    // Draw right dividing line
    canvas.drawLine(
      Offset(rightLineScreenX, 0),
      Offset(rightLineScreenX, size.height),
      linePaint,
    );

    // Draw labels for the thirds
    final labelPaint = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Use a better calculation: find the midpoint between left edge of screen and left line
    final leftEdgeX = 0.0;
    final leftThirdCenterX = (leftEdgeX + leftLineScreenX) / 2;

    // Left third label
    labelPaint.text = TextSpan(
      text: 'LEFT THIRD',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPaint.layout();
    labelPaint.paint(
      canvas,
      Offset(leftThirdCenterX - labelPaint.width / 2, 20),
    );

    // Middle third label
    final middleThirdCenterX = (leftLineScreenX + rightLineScreenX) / 2;
    labelPaint.text = TextSpan(
      text: 'MIDDLE THIRD',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPaint.layout();
    labelPaint.paint(
      canvas,
      Offset(middleThirdCenterX - labelPaint.width / 2, 20),
    );

    // Right third label
    final rightThirdCenterX = (rightLineScreenX + size.width) / 2;
    labelPaint.text = TextSpan(
      text: 'RIGHT THIRD',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPaint.layout();
    labelPaint.paint(
      canvas,
      Offset(rightThirdCenterX - labelPaint.width / 2, 20),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
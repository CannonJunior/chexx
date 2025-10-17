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
import 'scenario_builder/painters/scenario_builder_painter.dart';
import 'scenario_builder/utils/unit_helpers.dart';
import 'scenario_builder/utils/input_validator.dart';

/// Scenario Builder screen for creating custom game configurations
class ScenarioBuilderScreen extends StatefulWidget {
  final Map<String, dynamic>? initialScenarioData;

  const ScenarioBuilderScreen({super.key, this.initialScenarioData});

  @override
  State<ScenarioBuilderScreen> createState() => ScenarioBuilderScreenState();
}

class ScenarioBuilderScreenState extends State<ScenarioBuilderScreen> {
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
        final unitType = UnitHelpers.stringToUnitType(unitTypeId);

        // Add for both players
        builderState.availableUnits.addAll([
          UnitTemplate(type: unitType, owner: Player.player1, id: 'p1_$unitTypeId'),
          UnitTemplate(type: unitType, owner: Player.player2, id: 'p2_$unitTypeId'),
        ]);
      }
    }
  }

  /// Get display symbol from config or fallback to enum (public for painter)
  String getActualUnitSymbol(UnitTemplate template) {
    return UnitHelpers.getActualUnitSymbol(template, currentUnitTypeSet);
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
            getActualUnitSymbol(unit),
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
              TileStructureHelpers.getTileTypeIcon(tileType),
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
    final color = TileStructureHelpers.getStructureTypeColor(structure);
    final name = TileStructureHelpers.getStructureTypeName(structure);

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
              TileStructureHelpers.getStructureTypeIcon(structure),
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
                      onChanged: (value) {
                        // Sanitize and validate scenario name
                        final sanitized = InputValidator.sanitizeScenarioName(value);
                        if (sanitized != null) {
                          builderState.setScenarioName(sanitized);
                        }
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter scenario name (max ${InputValidator.maxScenarioNameLength} chars)...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      maxLength: InputValidator.maxScenarioNameLength,
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
                      '• Deselect palette (click it again)',
                    ),
                    _buildInstructionItem(
                      '• Then click placed unit to select',
                    ),
                    _buildInstructionItem(
                      '• ↑/↓ arrows: adjust health (1 to max)',
                    ),
                    _buildInstructionItem(
                      '• Select palette & click unit to remove',
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
                                        helperText: '${InputValidator.minWinPoints}-${InputValidator.maxWinPoints}',
                                        helperStyle: const TextStyle(fontSize: 8),
                                      ),
                                      onChanged: (value) {
                                        final points = int.tryParse(value);
                                        if (points != null && InputValidator.isWinPointsValid(points)) {
                                          builderState.player1WinPoints = InputValidator.clampWinPoints(points);
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
                                        helperText: '${InputValidator.minWinPoints}-${InputValidator.maxWinPoints}',
                                        helperStyle: const TextStyle(fontSize: 8),
                                      ),
                                      onChanged: (value) {
                                        final points = int.tryParse(value);
                                        if (points != null && InputValidator.isWinPointsValid(points)) {
                                          builderState.player2WinPoints = InputValidator.clampWinPoints(points);
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

                    // Game Start Settings Section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Game Start Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Initial Card Counts
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Player 1 Cards:',
                                      style: TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                    DropdownButton<int>(
                                      value: builderState.player1InitialCards,
                                      isExpanded: true,
                                      dropdownColor: Colors.grey.shade800,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      items: List.generate(10, (index) => index + 1)
                                          .map((count) => DropdownMenuItem<int>(
                                                value: count,
                                                child: Text('$count'),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          builderState.player1InitialCards = value;
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
                                      'Player 2 Cards:',
                                      style: TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                    DropdownButton<int>(
                                      value: builderState.player2InitialCards,
                                      isExpanded: true,
                                      dropdownColor: Colors.grey.shade800,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      items: List.generate(10, (index) => index + 1)
                                          .map((count) => DropdownMenuItem<int>(
                                                value: count,
                                                child: Text('$count'),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          builderState.player2InitialCards = value;
                                          builderState.notifyListeners();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // First Player Selection
                          const Text(
                            'First Player:',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Column(
                            children: [
                              RadioListTile<Player>(
                                title: const Text(
                                  'Player 1 (Blue)',
                                  style: TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                value: Player.player1,
                                groupValue: builderState.firstPlayer,
                                activeColor: Colors.blue.shade300,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) {
                                  if (value != null) {
                                    builderState.firstPlayer = value;
                                    builderState.notifyListeners();
                                  }
                                },
                              ),
                              RadioListTile<Player>(
                                title: const Text(
                                  'Player 2 (Red)',
                                  style: TextStyle(color: Colors.white, fontSize: 11),
                                ),
                                value: Player.player2,
                                groupValue: builderState.firstPlayer,
                                activeColor: Colors.red.shade300,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) {
                                  if (value != null) {
                                    builderState.firstPlayer = value;
                                    builderState.notifyListeners();
                                  }
                                },
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

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      // Handle health increment/decrement with arrow keys
      if (key == LogicalKeyboardKey.arrowUp) {
        print('DEBUG: Arrow UP pressed - attempting to increment health');
        print('DEBUG: selectedPlacedUnit: ${builderState.selectedPlacedUnit?.template.id}');
        print('DEBUG: selectedUnitTemplate: ${builderState.selectedUnitTemplate?.id}');
        if (builderState.incrementSelectedUnitHealth()) {
          setState(() {}); // Update UI
          print('DEBUG: Health incremented successfully');
          return KeyEventResult.handled;
        } else {
          print('DEBUG: Health increment FAILED - Make sure:');
          print('  1. No template is selected in palette (click palette again to deselect)');
          print('  2. Click on a placed unit to select it for modification');
          print('  3. Then use arrow keys to adjust health');
          return KeyEventResult.ignored;
        }
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        print('DEBUG: Arrow DOWN pressed - attempting to decrement health');
        print('DEBUG: selectedPlacedUnit: ${builderState.selectedPlacedUnit?.template.id}');
        print('DEBUG: selectedUnitTemplate: ${builderState.selectedUnitTemplate?.id}');
        if (builderState.decrementSelectedUnitHealth()) {
          setState(() {}); // Update UI
          print('DEBUG: Health decremented successfully');
          return KeyEventResult.handled;
        } else {
          print('DEBUG: Health decrement FAILED - Make sure:');
          print('  1. No template is selected in palette (click palette again to deselect)');
          print('  2. Click on a placed unit to select it for modification');
          print('  3. Then use arrow keys to adjust health');
          return KeyEventResult.ignored;
        }
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
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
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
    if (hexCoord == null) {
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
      return;
    }

    // Handle removal mode - removes everything from the hex
    if (builderState.isRemoveMode) {
      builderState.placeItem(hexCoord); // Use placeItem which handles remove mode properly
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
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
          // Re-request focus to ensure keyboard input continues working
          _focusNode.requestFocus();
          return;
        }
        // Second click (or if already selected): remove existing unit
        builderState.removeUnit(hexCoord);
        builderState.selectPlacedUnit(null); // Clear selection when removing
        // Re-request focus to ensure keyboard input continues working
        _focusNode.requestFocus();
        return;
      }
      // Place new unit on empty hex
      builderState.placeItem(hexCoord);
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
      return;
    }

    if (builderState.selectedStructureTemplate != null) {
      // Structure mode: prioritize structure interaction, but allow unit selection
      final existingStructure = builderState.getStructureAt(hexCoord);
      if (existingStructure != null) {
        // Remove existing structure
        builderState.removeStructure(hexCoord);
        // Re-request focus to ensure keyboard input continues working
        _focusNode.requestFocus();
        return;
      }

      // Check for unit selection if no structure at this position
      final placedUnit = builderState.getPlacedUnitAt(hexCoord);
      if (placedUnit != null) {
        builderState.selectPlacedUnit(placedUnit);
        // Re-request focus to ensure keyboard input continues working
        _focusNode.requestFocus();
        return;
      }

      // Place new structure on empty hex
      builderState.placeItem(hexCoord);
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
      return;
    }

    if (builderState.selectedTileType != null) {
      // Tile mode: prioritize tile interaction, but allow unit selection
      final existingTile = builderState.board.getTile(hexCoord);

      // Check for unit selection first (before tile operations)
      final placedUnit = builderState.getPlacedUnitAt(hexCoord);
      if (placedUnit != null) {
        builderState.selectPlacedUnit(placedUnit);
        // Re-request focus to ensure keyboard input continues working
        _focusNode.requestFocus();
        return;
      }

      if (existingTile != null && existingTile.type == builderState.selectedTileType) {
        // Clicking on a tile that already has the selected type - remove the entire tile
        builderState.removeTile(hexCoord);
      } else {
        // Place or change tile type
        builderState.placeItem(hexCoord);
      }
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
      return;
    }

    if (builderState.isCreateNewMode) {
      // Create new hex mode
      builderState.placeItem(hexCoord);
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
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

    // Re-request focus to ensure keyboard input continues working
    _focusNode.requestFocus();
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
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
      return;
    }

    // Check if tap is near right line (within 20 pixels)
    if ((adjustedPosition.dx - rightLineScreenX).abs() < tapThreshold) {
      builderState.startDraggingLine(DraggingLine.rightLine, adjustedPosition.dx);
      // Re-request focus to ensure keyboard input continues working
      _focusNode.requestFocus();
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
    // Re-request focus to ensure keyboard input continues working
    _focusNode.requestFocus();
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

    // Validate JSON before saving
    final validation = InputValidator.validateScenarioJson(jsonString);
    if (!validation.isValid) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${validation.error}'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    // Generate safe filename
    final safeFilename = InputValidator.getSafeFilename(builderState.scenarioName);

    // Create and download file
    final blob = html.Blob([jsonString], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = '$safeFilename.json'
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
              UnitHelpers.getActualUnitName(unit.template, currentUnitTypeSet),
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
          _buildInfoRow('Current Health', '${getCurrentHealth(unit)}', Icons.favorite),
          _buildInfoRow('Max Health', '${UnitHelpers.getActualUnitMaxHealth(unit.template, currentUnitTypeSet)}', Icons.favorite_border),
          _buildInfoRow('Starting Health', '${UnitHelpers.getActualUnitStartingHealth(unit.template, currentUnitTypeSet)}', Icons.favorite_outline),
          _buildInfoRow('Movement', '${UnitHelpers.getActualUnitMovementRange(unit.template, currentUnitTypeSet)}', Icons.directions_run),
          _buildInfoRow('Attack Range', '${UnitHelpers.getActualUnitAttackRange(unit.template, currentUnitTypeSet)}', Icons.gps_fixed),
          _buildInfoRow('Attack Damage', '${UnitHelpers.getActualUnitAttackDamage(unit.template, currentUnitTypeSet)}', Icons.flash_on),

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
      _buildParametricInfoRow('isIncrementable', getActualIsIncrementable(template).toString(), Icons.trending_up),
      _buildParametricInfoRow('Movement Type', UnitHelpers.getActualMovementType(template, currentUnitTypeSet), Icons.navigation),
      _buildParametricInfoRow('Can Swap', UnitHelpers.getCanSwap(template.type).toString(), Icons.swap_horiz),
      _buildParametricInfoRow('Base Experience', UnitHelpers.getBaseExperience(template.type).toString(), Icons.star_outline),
      _buildParametricInfoRow('Level Cap', UnitHelpers.getLevelCap(template.type).toString(), Icons.vertical_align_top),
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

  /// Get isIncrementable from configuration or fallback to enum (public for painter and UI)
  bool getActualIsIncrementable(UnitTemplate template) {
    return UnitHelpers.getActualIsIncrementable(template, currentUnitTypeSet);
  }

  /// Get current health of a placed unit (public for painter and UI)
  int getCurrentHealth(PlacedUnit unit) {
    return UnitHelpers.getCurrentHealth(unit, currentUnitTypeSet);
  }
}
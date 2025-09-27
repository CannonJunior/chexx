import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import '../models/scenario_builder_state.dart';
import '../models/hex_coordinate.dart';
import '../models/game_unit.dart';
import '../models/game_board.dart';
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

  @override
  void initState() {
    super.initState();
    builderState = ScenarioBuilderState();
    _focusNode = FocusNode();

    // Load initial scenario data if provided
    if (widget.initialScenarioData != null) {
      builderState.loadFromScenarioData(widget.initialScenarioData!);
    }

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
                  Text(
                    'Unit Types',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
            _getUnitSymbol(unit.type),
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
            _buildTileTypeButton(HexType.normal, 'Normal', Colors.green.shade200),
            _buildTileTypeButton(HexType.meta, 'Meta', Colors.purple.shade300),
            _buildTileTypeButton(HexType.blocked, 'Blocked', Colors.grey.shade600),
            _buildTileTypeButton(HexType.ocean, 'Ocean', Colors.blue.shade300),
            _buildTileTypeButton(HexType.beach, 'Beach', Colors.amber.shade200),
            _buildTileTypeButton(HexType.hill, 'Hill', Colors.brown.shade300),
            _buildTileTypeButton(HexType.town, 'Town', Colors.grey.shade400),
            _buildTileTypeButton(HexType.forest, 'Forest', Colors.green.shade600),
            _buildTileTypeButton(HexType.hedgerow, 'Hedgerow', Colors.green.shade800),
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
            child: CustomPaint(
              painter: ScenarioBuilderPainter(builderState, hexSize),
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
                      '• Click again on selected unit to remove',
                    ),

                    const Spacer(),

                    // Action buttons
                    _buildActionButton(
                      'Clear All Units',
                      Colors.orange.shade600,
                      () => _showClearUnitsDialog(),
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      'Reset Meta Hexes',
                      Colors.purple.shade600,
                      () => builderState.resetMetaHexes(),
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
              _getUnitTypeName(unit.template.type),
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
          _buildInfoRow('Health', '${_getUnitMaxHealth(unit.template.type)}', Icons.favorite),
          _buildInfoRow('Movement', '${_getUnitMovementRange(unit.template.type)}', Icons.directions_run),
          _buildInfoRow('Attack Range', '${_getUnitAttackRange(unit.template.type)}', Icons.gps_fixed),
          _buildInfoRow('Attack Damage', '${_getUnitAttackDamage(unit.template.type)}', Icons.flash_on),

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

          ..._buildParametricInfo(unit.template.type),
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
  List<Widget> _buildParametricInfo(UnitType unitType) {
    return [
      _buildParametricInfoRow('isIncrementable', _getIsIncrementable(unitType).toString(), Icons.trending_up),
      _buildParametricInfoRow('Movement Type', _getMovementType(unitType), Icons.navigation),
      _buildParametricInfoRow('Can Swap', _getCanSwap(unitType).toString(), Icons.swap_horiz),
      _buildParametricInfoRow('Base Experience', _getBaseExperience(unitType).toString(), Icons.star_outline),
      _buildParametricInfoRow('Level Cap', _getLevelCap(unitType).toString(), Icons.vertical_align_top),
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
}

/// Custom painter for the scenario builder board
class ScenarioBuilderPainter extends CustomPainter {
  final ScenarioBuilderState state;
  final double hexSize;

  ScenarioBuilderPainter(this.state, this.hexSize);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw hex tiles
    _drawHexTiles(canvas, size, centerX, centerY);

    // Draw placed structures (above tiles, below units)
    _drawPlacedStructures(canvas, size, centerX, centerY);

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

      // Unit colors
      final baseColor = placedUnit.template.owner == Player.player1
          ? Colors.blue.shade600
          : Colors.red.shade600;

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
          text: _getUnitSymbol(placedUnit.template.type),
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
    switch (type) {
      case HexType.normal:
        return Colors.lightGreen.shade100;
      case HexType.meta:
        return Colors.purple.shade200;
      case HexType.blocked:
        return Colors.grey.shade600;
      case HexType.ocean:
        return Colors.blue.shade300;
      case HexType.beach:
        return Colors.amber.shade200;
      case HexType.hill:
        return Colors.brown.shade300;
      case HexType.town:
        return Colors.grey.shade400;
      case HexType.forest:
        return Colors.green.shade600;
      case HexType.hedgerow:
        return Colors.green.shade800;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
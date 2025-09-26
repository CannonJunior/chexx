import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import '../models/scenario_builder_state.dart';
import '../models/hex_coordinate.dart';
import '../models/game_unit.dart';
import '../engine/game_engine.dart';

/// Scenario Builder screen for creating custom game configurations
class ScenarioBuilderScreen extends StatefulWidget {
  const ScenarioBuilderScreen({super.key});

  @override
  State<ScenarioBuilderScreen> createState() => _ScenarioBuilderScreenState();
}

class _ScenarioBuilderScreenState extends State<ScenarioBuilderScreen> {
  late ScenarioBuilderState builderState;
  final double hexSize = 50.0;
  Offset? _lastTapPosition;

  @override
  void initState() {
    super.initState();
    builderState = ScenarioBuilderState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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
                  _buildPlayerUnits('Player 1 (Blue)', Player.player1),
                  const SizedBox(height: 16),
                  _buildPlayerUnits('Player 2 (Red)', Player.player2),
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
            onDoubleTap: () => _handleBoardDoubleTap(_lastTapPosition),
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
                      '• Click placed unit to remove it',
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

    // Check if there's already a unit at this position
    final existingUnit = builderState.getUnitAt(hexCoord);
    if (existingUnit != null) {
      // Remove existing unit
      builderState.removeUnit(hexCoord);
      return;
    }

    // If no unit selected, do nothing
    if (builderState.selectedUnitTemplate == null) return;

    // Place unit
    builderState.placeUnit(hexCoord);
  }

  void _handleBoardDoubleTap(Offset? globalPosition) {
    if (globalPosition == null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);

    // Adjust for the left panel width and top toolbar
    final adjustedPosition = Offset(
      localPosition.dx - 200,
      localPosition.dy - 50,
    );

    final hexCoord = _screenToHex(adjustedPosition, renderBox.size);
    if (hexCoord != null) {
      builderState.toggleMetaHex(hexCoord);
    }
  }


  HexCoordinate? _screenToHex(Offset screenPos, Size canvasSize) {
    final centerX = (canvasSize.width - 400) / 2; // Subtract panels
    final centerY = (canvasSize.height - 50) / 2;  // Subtract toolbar

    final gameX = screenPos.dx - centerX;
    final gameY = screenPos.dy - centerY;

    return HexCoordinate.fromPixel(gameX, gameY, hexSize);
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

    // Draw placed units
    _drawPlacedUnits(canvas, size, centerX, centerY);
  }

  void _drawHexTiles(Canvas canvas, Size size, double centerX, double centerY) {
    final normalPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.lightGreen.shade100;

    final metaPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.purple.shade200;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black54;

    // Draw all valid board positions
    final allPositions = HexCoordinate.hexesInRange(const HexCoordinate(0, 0, 0), 4);

    for (final coord in allPositions) {
      if (!state.board.isValidCoordinate(coord)) continue;

      final vertices = _getHexVertices(coord, centerX, centerY);
      final path = Path();

      if (vertices.isNotEmpty) {
        path.moveTo(vertices[0].dx, vertices[0].dy);
        for (int i = 1; i < vertices.length; i++) {
          path.lineTo(vertices[i].dx, vertices[i].dy);
        }
        path.close();

        // Fill hex
        canvas.drawPath(path, state.isMetaHex(coord) ? metaPaint : normalPaint);

        // Draw border
        canvas.drawPath(path, strokePaint);
      }
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
      final angle = i * 3.14159 / 3;
      final x = center.dx + hexSize * cos(angle);
      final y = center.dy + hexSize * sin(angle);
      vertices.add(Offset(x, y));
    }

    return vertices;
  }

  Offset _hexToScreen(HexCoordinate hex, double centerX, double centerY) {
    final (x, y) = hex.toPixel(hexSize);
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

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
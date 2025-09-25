import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/hex_coordinate.dart';
import '../models/game_state.dart';
import '../models/game_unit.dart';
import '../models/game_board.dart';

/// Custom lightweight game engine for CHEXX using Flutter's CustomPainter
class ChexxGameEngine extends ChangeNotifier {
  late GameState gameState;
  final double hexSize = 25.0;

  // Input handling
  HexCoordinate? _hoveredHex;
  HexCoordinate? _selectedHex;

  // Animation
  Timer? _gameTimer;

  ChexxGameEngine() {
    gameState = GameState();
    gameState.initializeGame();
    _startGameLoop();
  }

  /// Start the game loop timer
  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // Update game timer
      gameState.updateTimer(0.016);
      notifyListeners();
    });
  }

  /// Handle tap at screen coordinates
  void handleTap(Offset globalPosition, Size canvasSize) {
    final hexCoord = _screenToHex(globalPosition, canvasSize);

    if (hexCoord != null && gameState.board.isValidCoordinate(hexCoord)) {
      final unit = gameState.board.getUnitAt(hexCoord, gameState.units);

      if (unit != null && unit.owner == gameState.currentPlayer) {
        // Select own unit
        selectUnit(unit);
      } else if (gameState.selectedUnit != null) {
        if (gameState.availableMoves.contains(hexCoord)) {
          // Move to empty hex
          gameState.moveUnit(hexCoord);
        } else if (gameState.availableAttacks.contains(hexCoord)) {
          // Attack enemy unit
          gameState.attackPosition(hexCoord);
        } else {
          // Deselect
          gameState.deselectUnit();
        }
      }

      notifyListeners();
    }
  }

  /// Handle hover at screen coordinates
  void handleHover(Offset globalPosition, Size canvasSize) {
    final hexCoord = _screenToHex(globalPosition, canvasSize);

    if (hexCoord != _hoveredHex) {
      _hoveredHex = hexCoord;
      notifyListeners();
    }
  }

  /// Select a unit
  void selectUnit(GameUnit unit) {
    gameState.selectUnit(unit);
    notifyListeners();
  }

  /// Convert screen coordinates to hex coordinate
  HexCoordinate? _screenToHex(Offset screenPos, Size canvasSize) {
    // Convert screen position to game world position
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    final gameX = screenPos.dx - centerX;
    final gameY = screenPos.dy - centerY;

    return HexCoordinate.fromPixel(gameX, gameY, hexSize);
  }

  /// Convert hex coordinate to screen position
  Offset hexToScreen(HexCoordinate hex, Size canvasSize) {
    final (x, y) = hex.toPixel(hexSize);

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    return Offset(centerX + x, centerY + y);
  }

  /// Get hex vertices for rendering
  List<Offset> getHexVertices(HexCoordinate hex, Size canvasSize) {
    final center = hexToScreen(hex, canvasSize);
    final vertices = <Offset>[];

    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final x = center.dx + hexSize * cos(angle);
      final y = center.dy + hexSize * sin(angle);
      vertices.add(Offset(x, y));
    }

    return vertices;
  }

  /// End current turn
  void endTurn() {
    gameState.endTurn();
    notifyListeners();
  }

  /// Skip current action
  void skipAction() {
    gameState.skipAction();
    notifyListeners();
  }

  /// Reset game
  void resetGame() {
    gameState.resetGame();
    notifyListeners();
  }

  /// Toggle pause
  void togglePause() {
    gameState.togglePause();
    notifyListeners();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}

/// Custom painter for rendering the game
class ChexxGamePainter extends CustomPainter {
  final ChexxGameEngine engine;
  final HexCoordinate? hoveredHex;

  ChexxGamePainter(this.engine, this.hoveredHex);

  @override
  void paint(Canvas canvas, Size size) {
    // Clear background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1a1a2e),
    );

    // Draw all hex tiles
    _drawHexTiles(canvas, size);

    // Draw units
    _drawUnits(canvas, size);

    // Draw UI overlays
    _drawUIOverlays(canvas, size);
  }

  void _drawHexTiles(Canvas canvas, Size size) {
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

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final hoverPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(0.5);

    for (final tile in engine.gameState.board.allTiles) {
      final vertices = engine.getHexVertices(tile.coordinate, size);
      final path = Path();

      if (vertices.isNotEmpty) {
        path.moveTo(vertices[0].dx, vertices[0].dy);
        for (int i = 1; i < vertices.length; i++) {
          path.lineTo(vertices[i].dx, vertices[i].dy);
        }
        path.close();

        // Fill hex
        canvas.drawPath(path, tile.isMetaHex ? metaPaint : normalPaint);

        // Draw border
        canvas.drawPath(path, strokePaint);

        // Draw highlights
        if (tile.isHighlighted) {
          canvas.drawPath(path, highlightPaint);
        }

        // Draw hover
        if (hoveredHex == tile.coordinate) {
          canvas.drawPath(path, hoverPaint);
        }
      }
    }
  }

  void _drawUnits(Canvas canvas, Size size) {
    for (final unit in engine.gameState.units) {
      if (unit.isAlive) {
        _drawUnit(canvas, size, unit);
      }
    }
  }

  void _drawUnit(Canvas canvas, Size size, GameUnit unit) {
    final center = engine.hexToScreen(unit.position, size);
    final radius = engine.hexSize * 0.4;

    // Unit colors
    final baseColor = unit.owner == Player.player1
        ? Colors.blue.shade600
        : Colors.red.shade600;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = unit.state == UnitState.selected
          ? baseColor.withOpacity(0.9)
          : baseColor;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit.state == UnitState.selected ? 4.0 : 2.0
      ..color = unit.state == UnitState.selected
          ? Colors.yellow.shade700
          : Colors.black87;

    // Draw unit circle
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw unit type symbol
    final textPainter = TextPainter(
      text: TextSpan(
        text: _getUnitSymbol(unit),
        style: TextStyle(
          color: Colors.white,
          fontSize: engine.hexSize * 0.3,
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

    // Draw health bar if damaged
    if (unit.currentHealth < unit.maxHealth) {
      _drawHealthBar(canvas, center, unit);
    }
  }

  void _drawHealthBar(Canvas canvas, Offset center, GameUnit unit) {
    const barWidth = 30.0;
    const barHeight = 4.0;
    final barY = center.dy - engine.hexSize * 0.8;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, barWidth, barHeight),
      Paint()..color = Colors.grey.shade700,
    );

    // Health
    final healthPercent = unit.currentHealth / unit.maxHealth;
    final healthWidth = barWidth * healthPercent;

    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, healthWidth, barHeight),
      Paint()..color = Colors.green.shade600,
    );
  }

  void _drawUIOverlays(Canvas canvas, Size size) {
    // Draw turn indicator
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${engine.gameState.currentPlayer == Player.player1 ? 'Player 1' : 'Player 2'} Turn',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(20, 20));

    // Draw timer
    final timerPainter = TextPainter(
      text: TextSpan(
        text: 'Time: ${engine.gameState.turnTimeRemaining.toStringAsFixed(1)}s',
        style: TextStyle(
          color: engine.gameState.turnTimeRemaining <= 2.0 ? Colors.red : Colors.white,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    timerPainter.layout();
    timerPainter.paint(canvas, const Offset(20, 50));
  }

  String _getUnitSymbol(GameUnit unit) {
    switch (unit.type) {
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
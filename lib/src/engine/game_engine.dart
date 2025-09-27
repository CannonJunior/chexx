import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/hex_coordinate.dart';
import '../models/game_state.dart';
import '../models/game_unit.dart';
import '../models/game_board.dart';
import '../models/meta_ability.dart';
import '../models/scenario_builder_state.dart'; // For HexOrientation enum
import '../../core/interfaces/unit_factory.dart';

/// Custom lightweight game engine for CHEXX using Flutter's CustomPainter
class ChexxGameEngine extends ChangeNotifier {
  late GameState gameState;
  final double hexSize = 50.0;

  // Hexagon orientation setting
  HexOrientation hexOrientation = HexOrientation.flat;

  // Input handling
  HexCoordinate? _hoveredHex;
  HexCoordinate? _selectedHex;

  // Animation
  Timer? _gameTimer;

  // Performance caching
  final Map<HexCoordinate, List<Offset>> _hexVerticesCache = {};
  Size? _lastCanvasSize;

  ChexxGameEngine({Map<String, dynamic>? scenarioConfig}) {
    gameState = GameState();
    if (scenarioConfig != null) {
      gameState.initializeFromScenario(scenarioConfig);
    } else {
      gameState.initializeGame();
    }
    _startGameLoop();
  }

  /// Start the game loop timer
  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Update game timer only during active gameplay
      if (gameState.gamePhase == GamePhase.playing && !gameState.isPaused) {
        final oldTimeRemaining = gameState.turnTimeRemaining;
        gameState.updateTimer(0.1);

        // Only notify if time actually changed significantly or game ended
        if ((gameState.turnTimeRemaining - oldTimeRemaining).abs() > 0.05 ||
            gameState.gamePhase == GamePhase.gameOver) {
          notifyListeners();
        }
      }
    });
  }

  /// Handle tap at screen coordinates
  void handleTap(Offset globalPosition, Size canvasSize) {
    final hexCoord = _screenToHex(globalPosition, canvasSize);

    if (hexCoord != null && gameState.board.isValidCoordinate(hexCoord)) {
      final unit = gameState.board.getUnitAt(hexCoord, gameState.units);
      final metaHex = gameState.getMetaHexAt(hexCoord);

      // Priority 1: Select own unit (even if on Meta hex)
      if (unit != null && unit.owner == gameState.currentPlayer) {
        selectUnit(unit);
        // Deselect Meta hex when selecting a unit
        if (gameState.selectedMetaHex != null) {
          gameState.selectedMetaHex = null;
        }
      }
      // Priority 2: Select Meta hex (only if no unit present)
      else if (metaHex != null) {
        gameState.selectMetaHex(metaHex);
        gameState.deselectUnit();
      }
      // Priority 3: Execute actions with selected unit/Meta hex
      else if (gameState.selectedUnit != null) {
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
      // Priority 4: Use Meta ability if Meta hex is selected
      else if (gameState.selectedMetaHex != null) {
        // For now, use heal ability as default (can be extended later)
        if (unit != null && unit.owner == gameState.currentPlayer) {
          gameState.useMetaAbility(MetaAbilityType.heal, hexCoord);
        } else {
          // Try spawn if targeting empty hex
          gameState.useMetaAbility(MetaAbilityType.spawn, hexCoord);
        }
        gameState.selectedMetaHex = null;
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

    return HexCoordinate.fromPixel(gameX, gameY, hexSize, hexOrientation);
  }

  /// Convert hex coordinate to screen position
  Offset hexToScreen(HexCoordinate hex, Size canvasSize) {
    final (x, y) = hex.toPixel(hexSize, hexOrientation);

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    return Offset(centerX + x, centerY + y);
  }

  /// Get hex vertices for rendering (cached for performance)
  List<Offset> getHexVertices(HexCoordinate hex, Size canvasSize) {
    // Clear cache if canvas size changed
    if (_lastCanvasSize != canvasSize) {
      _hexVerticesCache.clear();
      _lastCanvasSize = canvasSize;
    }

    // Return cached vertices if available
    if (_hexVerticesCache.containsKey(hex)) {
      return _hexVerticesCache[hex]!;
    }

    // Calculate and cache vertices
    final center = hexToScreen(hex, canvasSize);
    final vertices = <Offset>[];

    for (int i = 0; i < 6; i++) {
      // Calculate hexagon vertices based on orientation
      double angle;
      if (hexOrientation == HexOrientation.flat) {
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

    _hexVerticesCache[hex] = vertices;
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

  /// Handle keyboard input for movement
  void handleKeyboardInput(String key) {
    if (gameState.handleKeyboardMovement(key)) {
      notifyListeners();
    }
  }

  /// Toggle hexagon orientation between flat and pointy
  void toggleHexOrientation() {
    hexOrientation = hexOrientation == HexOrientation.flat
        ? HexOrientation.pointy
        : HexOrientation.flat;

    // Clear vertex cache to force recalculation with new orientation
    _hexVerticesCache.clear();
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

  // Cached paint objects for performance
  static final Paint _normalPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.lightGreen.shade100;

  static final Paint _metaPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.purple.shade200;

  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.black54;

  static final Paint _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..color = Colors.yellow;

  static final Paint _hoverPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.white.withOpacity(0.5);

  static final Paint _metaSelectionPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0
    ..color = Colors.purple.shade400;

  static final Paint _metaPlayer1ControlPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.blue.shade300;

  static final Paint _metaPlayer2ControlPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.red.shade300;

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
    // Use cached paint objects for better performance

    for (final tile in engine.gameState.board.allTiles) {
      final vertices = engine.getHexVertices(tile.coordinate, size);
      final path = Path();

      if (vertices.isNotEmpty) {
        path.moveTo(vertices[0].dx, vertices[0].dy);
        for (int i = 1; i < vertices.length; i++) {
          path.lineTo(vertices[i].dx, vertices[i].dy);
        }
        path.close();

        // Check if this is a Meta hex
        final metaHex = engine.gameState.getMetaHexAt(tile.coordinate);
        final isMetaHex = metaHex != null;

        // Fill hex
        canvas.drawPath(path, isMetaHex ? _metaPaint : _normalPaint);

        // Draw border
        canvas.drawPath(path, _strokePaint);

        // Draw highlights
        if (tile.isHighlighted) {
          canvas.drawPath(path, _highlightPaint);
        }

        // Draw hover
        if (hoveredHex == tile.coordinate) {
          canvas.drawPath(path, _hoverPaint);
        }

        // Draw Meta hex selection indicator
        if (metaHex != null && engine.gameState.selectedMetaHex == metaHex) {
          canvas.drawPath(path, _metaSelectionPaint);
        }

        // Draw Meta hex control indicator
        if (metaHex != null && metaHex.controlledBy != null) {
          final controlPaint = metaHex.controlledBy == Player.player1
              ? _metaPlayer1ControlPaint
              : _metaPlayer2ControlPaint;
          canvas.drawPath(path, controlPaint);
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

    // Draw level indicator if above level 1
    if (unit.level > 1) {
      _drawLevelIndicator(canvas, center, unit);
    }

    // Draw experience progress bar
    if (unit.experience > 0) {
      _drawExperienceBar(canvas, center, unit);
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

  void _drawLevelIndicator(Canvas canvas, Offset center, GameUnit unit) {
    final levelBadgeRadius = engine.hexSize * 0.15;
    final badgeCenter = Offset(
      center.dx + engine.hexSize * 0.45,
      center.dy - engine.hexSize * 0.45,
    );

    // Draw level badge background
    canvas.drawCircle(
      badgeCenter,
      levelBadgeRadius,
      Paint()..color = Colors.amber.shade600,
    );

    // Draw level badge border
    canvas.drawCircle(
      badgeCenter,
      levelBadgeRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black87,
    );

    // Draw level number
    final levelPainter = TextPainter(
      text: TextSpan(
        text: '${unit.level}',
        style: TextStyle(
          color: Colors.white,
          fontSize: engine.hexSize * 0.2,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    levelPainter.layout();
    levelPainter.paint(
      canvas,
      Offset(
        badgeCenter.dx - levelPainter.width / 2,
        badgeCenter.dy - levelPainter.height / 2,
      ),
    );
  }

  void _drawExperienceBar(Canvas canvas, Offset center, GameUnit unit) {
    const barWidth = 25.0;
    const barHeight = 3.0;
    final barY = center.dy + engine.hexSize * 0.6;

    // Background bar
    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, barWidth, barHeight),
      Paint()..color = Colors.grey.shade600,
    );

    // Experience progress bar
    final expWidth = barWidth * unit.experienceProgress;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, expWidth, barHeight),
      Paint()..color = Colors.cyan.shade400,
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
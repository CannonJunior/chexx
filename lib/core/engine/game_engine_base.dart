import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:oxygen/oxygen.dart';
import '../models/hex_coordinate.dart';
import '../models/game_state_base.dart';
import '../systems/movement_system.dart';
import '../systems/combat_system.dart';
import '../interfaces/game_plugin.dart';

/// Base game engine that can be extended by specific games
abstract class GameEngineBase extends ChangeNotifier {
  late GameStateBase gameState;
  late GamePlugin gamePlugin;
  final double hexSize = 50.0;

  // Input handling
  HexCoordinate? _hoveredHex;
  HexCoordinate? _selectedHex;

  // Animation and timing
  Timer? _gameTimer;

  // Performance caching
  final Map<HexCoordinate, List<Offset>> _hexVerticesCache = {};
  Size? _lastCanvasSize;

  // Core systems
  late MovementSystem movementSystem;
  late CombatSystem combatSystem;

  GameEngineBase({
    required this.gamePlugin,
    Map<String, dynamic>? scenarioConfig,
  }) {
    gameState = gamePlugin.createGameState();

    // Initialize core systems
    movementSystem = MovementSystem();
    combatSystem = CombatSystem();

    // Register systems with ECS world
    gameState.world.registerSystem(movementSystem);
    gameState.world.registerSystem(combatSystem);

    // Let plugin register its components and systems
    gamePlugin.registerECSComponents(gameState.world);

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
      if (gameState.gamePhase == GamePhase.playing && !gameState.isPaused) {
        final oldTimeRemaining = gameState.turnTimeRemaining;
        gameState.updateTimer(0.1);

        // Update ECS world
        gameState.world.execute(0.1);

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
    if (hexCoord != null) {
      handleHexTap(hexCoord);
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

  /// Handle tap on a hex coordinate (to be implemented by subclasses)
  void handleHexTap(HexCoordinate hexCoord);

  /// Convert screen coordinates to hex coordinate
  HexCoordinate? _screenToHex(Offset screenPos, Size canvasSize) {
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

  /// Get hex vertices for rendering (cached for performance)
  List<Offset> getHexVertices(HexCoordinate hex, Size canvasSize) {
    if (_lastCanvasSize != canvasSize) {
      _hexVerticesCache.clear();
      _lastCanvasSize = canvasSize;
    }

    if (_hexVerticesCache.containsKey(hex)) {
      return _hexVerticesCache[hex]!;
    }

    final center = hexToScreen(hex, canvasSize);
    final vertices = <Offset>[];

    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
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

  /// Get current hovered hex
  HexCoordinate? get hoveredHex => _hoveredHex;

  @override
  void dispose() {
    _gameTimer?.cancel();
    gameState.dispose();
    super.dispose();
  }
}
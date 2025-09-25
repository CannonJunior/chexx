import 'dart:async';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/hex_coordinate.dart';
import '../models/game_state.dart';
import '../models/game_unit.dart';
import '../components/hex_tile_component.dart';
import '../components/unit_component.dart';

/// Main Flame game engine for CHEXX
class ChexxGame extends FlameGame with ChangeNotifier {
  late GameState gameState;
  final double hexSize = 25.0;

  final Map<HexCoordinate, HexTileComponent> tileComponents = {};
  final Map<String, UnitComponent> unitComponents = {};

  final StreamController<GameState> _gameStateController =
      StreamController<GameState>.broadcast();

  Stream<GameState> get gameStateStream => _gameStateController.stream;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    gameState = GameState();

    // Initialize camera
    camera.viewfinder.visibleGameSize = size;

    // Create board tiles
    await _createBoardTiles();

    // Initialize game
    gameState.initializeGame();
    await _createUnitComponents();

    // Center camera on board
    _centerCamera();

    // Start game loop
    _gameStateController.add(gameState);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update game timer
    gameState.updateTimer(dt);

    // Update UI
    notifyListeners();
    _gameStateController.add(gameState);
  }

  @override
  void onDispose() {
    _gameStateController.close();
    super.onDispose();
  }

  /// Handle tile tap
  void onTileTapped(HexCoordinate coordinate) {
    if (gameState.gamePhase != GamePhase.playing) return;

    // Check if we can move selected unit to this tile
    if (gameState.selectedUnit != null) {
      if (gameState.availableMoves.contains(coordinate)) {
        // Move unit
        gameState.moveUnit(coordinate);
        _updateUnitPositions();
      } else if (gameState.availableAttacks.contains(coordinate)) {
        // Attack position
        gameState.attackPosition(coordinate);
        _updateUnitPositions();
      } else {
        // Deselect if clicking elsewhere
        gameState.deselectUnit();
      }
    }
  }

  /// Handle unit tap
  void onUnitTapped(GameUnit unit) {
    if (gameState.gamePhase != GamePhase.playing) return;

    if (unit.owner == gameState.currentPlayer) {
      // Select own unit
      gameState.selectUnit(unit);
    } else if (gameState.selectedUnit != null &&
               gameState.availableAttacks.contains(unit.position)) {
      // Attack enemy unit
      gameState.attackPosition(unit.position);
      _updateUnitPositions();
    }
  }

  /// Create hex tile components
  Future<void> _createBoardTiles() async {
    for (final tile in gameState.board.allTiles) {
      final tileComponent = HexTileComponent(
        tile: tile,
        hexSize: hexSize,
      );

      tileComponents[tile.coordinate] = tileComponent;
      await add(tileComponent);
    }
  }

  /// Create unit components
  Future<void> _createUnitComponents() async {
    // Clear existing unit components
    for (final component in unitComponents.values) {
      remove(component);
    }
    unitComponents.clear();

    // Create new unit components
    for (final unit in gameState.units) {
      if (unit.isAlive) {
        final unitComponent = UnitComponent(
          unit: unit,
          hexSize: hexSize,
        );

        unitComponents[unit.id] = unitComponent;
        await add(unitComponent);
      }
    }
  }

  /// Update unit component positions
  void _updateUnitPositions() {
    for (final unit in gameState.units) {
      final component = unitComponents[unit.id];
      if (component != null) {
        if (unit.isAlive) {
          final (x, y) = unit.position.toPixel(hexSize);
          component.position = Vector2(x, y);
        } else {
          // Remove dead units
          remove(component);
          unitComponents.remove(unit.id);
        }
      }
    }
  }

  /// Center camera on the board
  void _centerCamera() {
    // Calculate board bounds
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final tile in gameState.board.allTiles) {
      final (x, y) = tile.coordinate.toPixel(hexSize);
      minX = minX < x ? minX : x;
      maxX = maxX > x ? maxX : x;
      minY = minY < y ? minY : y;
      maxY = maxY > y ? maxY : y;
    }

    // Center on board
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    camera.viewfinder.position = Vector2(centerX, centerY);

    // Adjust zoom to fit board
    final boardWidth = maxX - minX + hexSize * 2;
    final boardHeight = maxY - minY + hexSize * 2;
    final scaleX = size.x / boardWidth;
    final scaleY = size.y / boardHeight;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.8;

    camera.viewfinder.zoom = scale;
  }

  /// Handle game reset
  void resetGame() {
    gameState.resetGame();
    _createUnitComponents();
    _centerCamera();
  }
}


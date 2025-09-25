import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../models/hex_coordinate.dart';
import '../models/game_board.dart';
import '../systems/chexx_game.dart';

/// Visual component for rendering a hexagonal tile
class HexTileComponent extends PositionComponent with HasGameRef<ChexxGame>, TapCallbacks {
  final HexTile tile;
  final double hexSize;

  late Paint _fillPaint;
  late Paint _strokePaint;
  late Paint _highlightPaint;

  HexTileComponent({
    required this.tile,
    required this.hexSize,
  }) : super(size: Vector2.all(hexSize * 2));

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Set position based on hex coordinates
    final (x, y) = tile.coordinate.toPixel(hexSize);
    position = Vector2(x, y);

    // Initialize paints
    _fillPaint = Paint()..style = PaintingStyle.fill;
    _strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black54;
    _highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    _updateColors();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateColors();
  }

  @override
  void render(Canvas canvas) {
    // Draw filled hexagon
    canvas.drawPath(_createHexagonPath(), _fillPaint);

    // Draw border
    canvas.drawPath(_createHexagonPath(), _strokePaint);

    // Draw highlight if needed
    if (tile.isHighlighted) {
      canvas.drawPath(_createHexagonPath(), _highlightPaint);
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    // Notify game of tile tap
    (gameRef as ChexxGame).onTileTapped(tile.coordinate);
    return true;
  }

  /// Create hexagon vertices
  List<Vector2> _createHexagonVertices() {
    final vertices = <Vector2>[];

    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final x = hexSize * cos(angle);
      final y = hexSize * sin(angle);
      vertices.add(Vector2(x, y));
    }

    return vertices;
  }

  /// Create hexagon path for drawing
  Path _createHexagonPath() {
    final path = Path();
    final vertices = _createHexagonVertices();

    if (vertices.isNotEmpty) {
      path.moveTo(vertices[0].x, vertices[0].y);
      for (int i = 1; i < vertices.length; i++) {
        path.lineTo(vertices[i].x, vertices[i].y);
      }
      path.close();
    }

    return path;
  }

  /// Update colors based on tile state
  void _updateColors() {
    switch (tile.type) {
      case HexType.normal:
        _fillPaint.color = Colors.lightGreen.shade100;
        break;
      case HexType.meta:
        _fillPaint.color = Colors.purple.shade200;
        break;
      case HexType.blocked:
        _fillPaint.color = Colors.grey.shade400;
        break;
    }

    if (tile.isHighlighted) {
      _fillPaint.color = _fillPaint.color.withOpacity(0.8);
    }
  }
}


import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../models/game_unit.dart';
import '../models/hex_coordinate.dart';
import '../systems/chexx_game.dart';

/// Visual component for rendering game units
class UnitComponent extends CircleComponent with HasGameRef<ChexxGame>, TapCallbacks {
  final GameUnit unit;
  final double hexSize;

  late Paint _fillPaint;
  late Paint _strokePaint;
  late Paint _healthPaint;
  late TextComponent _typeText;
  late TextComponent _healthText;

  UnitComponent({
    required this.unit,
    required this.hexSize,
  }) : super(radius: hexSize * 0.4);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Set initial position
    _updatePosition();

    // Initialize paints
    _fillPaint = Paint()..style = PaintingStyle.fill;
    _strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    _healthPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    // Create text components
    _typeText = TextComponent(
      text: _getUnitTypeSymbol(),
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: hexSize * 0.3,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    _healthText = TextComponent(
      text: '${unit.currentHealth}',
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: hexSize * 0.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    add(_typeText);
    add(_healthText);

    _updateColors();
    _updateTextPositions();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updatePosition();
    _updateColors();
    _updateHealth();
  }

  @override
  void render(Canvas canvas) {
    if (!unit.isAlive) return;

    super.render(canvas);

    // Draw health bar if damaged
    if (unit.currentHealth < unit.maxHealth) {
      _drawHealthBar(canvas);
    }

    // Draw selection indicator
    if (unit.state == UnitState.selected) {
      _drawSelectionIndicator(canvas);
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    if (!unit.isAlive) return false;

    // Notify game of unit tap
    gameRef.onUnitTapped(unit);
    return true;
  }

  /// Update unit position based on hex coordinate
  void _updatePosition() {
    final (x, y) = unit.position.toPixel(hexSize);
    position = Vector2(x, y);
  }

  /// Update colors based on unit state and owner
  void _updateColors() {
    // Base color based on owner
    final baseColor = unit.owner == Player.player1
        ? Colors.blue.shade600
        : Colors.red.shade600;

    _fillPaint.color = unit.state == UnitState.selected
        ? baseColor.withOpacity(0.9)
        : baseColor;

    _strokePaint.color = unit.state == UnitState.selected
        ? Colors.yellow.shade700
        : Colors.black87;

    // Update stroke width for selected units
    _strokePaint.strokeWidth = unit.state == UnitState.selected ? 4.0 : 2.0;
  }

  /// Update health display
  void _updateHealth() {
    _healthText.text = '${unit.currentHealth}';

    // Hide component if unit is dead
    if (!unit.isAlive) {
      opacity = 0.0;
    }
  }

  /// Update text positions
  void _updateTextPositions() {
    _typeText.position = Vector2(-_typeText.size.x / 2, -_typeText.size.y / 2);
    _healthText.position = Vector2(
      -_healthText.size.x / 2,
      hexSize * 0.6,
    );
  }

  /// Draw health bar above unit
  void _drawHealthBar(Canvas canvas) {
    final barWidth = hexSize * 0.8;
    final barHeight = 4.0;
    final barY = -hexSize * 0.8;

    // Background bar
    canvas.drawRect(
      Rect.fromLTWH(-barWidth / 2, barY, barWidth, barHeight),
      Paint()..color = Colors.grey.shade700,
    );

    // Health bar
    final healthPercent = unit.currentHealth / unit.maxHealth;
    final healthWidth = barWidth * healthPercent;

    canvas.drawRect(
      Rect.fromLTWH(-barWidth / 2, barY, healthWidth, barHeight),
      Paint()..color = Colors.green.shade600,
    );
  }

  /// Draw selection indicator
  void _drawSelectionIndicator(Canvas canvas) {
    final indicatorRadius = hexSize * 0.6;

    canvas.drawCircle(
      Offset.zero,
      indicatorRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.yellow.shade400,
    );
  }

  /// Get symbol for unit type
  String _getUnitTypeSymbol() {
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
}


import 'dart:math';
import 'package:flutter/material.dart';
import 'package:oxygen/oxygen.dart';
import '../../../core/engine/game_engine_base.dart';
import '../../../core/models/hex_coordinate.dart';
import '../../../core/interfaces/game_plugin.dart';
import '../../../core/interfaces/unit_factory.dart';
import '../../../core/components/position_component.dart';
import '../../../core/components/owner_component.dart';
import '../../../core/components/health_component.dart';
import '../../../core/components/selection_component.dart';
import '../models/chexx_game_state.dart';

/// CHEXX-specific game engine
class ChexxGameEngine extends GameEngineBase {
  ChexxGameEngine({
    required GamePlugin gamePlugin,
    Map<String, dynamic>? scenarioConfig,
  }) : super(gamePlugin: gamePlugin, scenarioConfig: scenarioConfig);

  @override
  void handleHexTap(HexCoordinate hexCoord) {
    final chexxGameState = gameState as ChexxGameState;

    print('Hex tapped at: $hexCoord');

    // Find unit at this position using simple loop
    SimpleGameUnit? unitAtPosition;
    for (final unit in chexxGameState.simpleUnits) {
      if (unit.position == hexCoord) {
        unitAtPosition = unit;
        break;
      }
    }

    if (unitAtPosition != null) {
      // Select unit if it belongs to current player
      if (unitAtPosition.owner == chexxGameState.currentPlayer) {
        // Deselect all units first
        for (final unit in chexxGameState.simpleUnits) {
          unit.isSelected = false;
        }
        // Select this unit
        unitAtPosition.isSelected = true;
        print('Selected unit: ${unitAtPosition.id}');
      }
    } else {
      // Try to move selected unit to this position
      SimpleGameUnit? selectedUnit;
      for (final unit in chexxGameState.simpleUnits) {
        if (unit.isSelected) {
          selectedUnit = unit;
          break;
        }
      }

      if (selectedUnit != null) {
        // Simple movement validation - adjacent hexes only
        final distance = selectedUnit.position.distanceTo(hexCoord);
        if (distance <= 1) {
          // Create new unit with updated position
          final updatedUnit = SimpleGameUnit(
            id: selectedUnit.id,
            unitType: selectedUnit.unitType,
            owner: selectedUnit.owner,
            position: hexCoord,
            health: selectedUnit.health,
            maxHealth: selectedUnit.maxHealth,
            isSelected: true,
          );

          // Replace unit in list
          final index = chexxGameState.simpleUnits.indexOf(selectedUnit);
          if (index != -1) {
            chexxGameState.simpleUnits[index] = updatedUnit;
          }
          print('Moved unit to: $hexCoord');
        }
      }
    }

    notifyListeners();
  }

  void _selectSimpleUnit(ChexxGameState gameState, SimpleGameUnit unit) {
    // Deselect all other units
    for (final u in gameState.simpleUnits) {
      u.isSelected = false;
    }
    // Select this unit
    unit.isSelected = true;
  }

  void _deselectAllSimpleUnits(ChexxGameState gameState) {
    for (final u in gameState.simpleUnits) {
      u.isSelected = false;
    }
  }

  void _moveSimpleUnit(ChexxGameState gameState, SimpleGameUnit unit, HexCoordinate target) {
    // Update unit position (create new unit with updated position)
    final updatedUnit = SimpleGameUnit(
      id: unit.id,
      unitType: unit.unitType,
      owner: unit.owner,
      position: target,
      health: unit.health,
      maxHealth: unit.maxHealth,
      isSelected: unit.isSelected,
    );

    // Replace the unit in the list
    final index = gameState.simpleUnits.indexOf(unit);
    if (index != -1) {
      gameState.simpleUnits[index] = updatedUnit;
    }
  }

  void _attackSimpleUnit(ChexxGameState gameState, SimpleGameUnit target) {
    final selectedUnits = gameState.simpleUnits.where((u) => u.isSelected).toList();
    final selectedUnit = selectedUnits.isNotEmpty ? selectedUnits.first : null;
    if (selectedUnit != null && _isValidAttack(selectedUnit, target)) {
      // Deal damage to target
      final newHealth = (target.health - 1).clamp(0, target.maxHealth);

      final updatedTarget = SimpleGameUnit(
        id: target.id,
        unitType: target.unitType,
        owner: target.owner,
        position: target.position,
        health: newHealth,
        maxHealth: target.maxHealth,
        isSelected: target.isSelected,
      );

      // Replace the target in the list
      final index = gameState.simpleUnits.indexOf(target);
      if (index != -1) {
        if (newHealth <= 0) {
          // Remove dead unit
          gameState.simpleUnits.removeAt(index);
        } else {
          // Update damaged unit
          gameState.simpleUnits[index] = updatedTarget;
        }
      }
    }
  }

  bool _isValidMove(SimpleGameUnit unit, HexCoordinate target) {
    // Simple movement validation - adjacent hexes only for now
    final distance = unit.position.distanceTo(target);
    return distance <= 1;
  }

  bool _isValidAttack(SimpleGameUnit attacker, SimpleGameUnit target) {
    // Simple attack validation - adjacent hexes only for now
    final distance = attacker.position.distanceTo(target.position);
    return distance <= 1 && attacker.owner != target.owner;
  }
}

/// Custom painter for CHEXX game rendering
class ChexxGamePainter extends CustomPainter {
  final ChexxGameEngine engine;

  // Cached paint objects for performance
  static final Paint _normalPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.lightGreen.shade100;

  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.black54;

  static final Paint _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..color = Colors.yellow;

  static final Paint _movePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.blue.shade400;

  static final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.red.shade400;

  ChexxGamePainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    // Clear background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1a1a2e),
    );

    final gameState = engine.gameState as ChexxGameState;

    // Draw hex tiles
    _drawHexTiles(canvas, size, gameState);

    // Draw units
    _drawUnits(canvas, size, gameState);
  }

  void _drawHexTiles(Canvas canvas, Size size, ChexxGameState gameState) {
    // Draw a simple hex grid around the center
    final center = HexCoordinate(0, 0, 0);
    final hexes = HexCoordinate.hexesInRange(center, 5);

    for (final hex in hexes) {
      final vertices = engine.getHexVertices(hex, size);
      if (vertices.isNotEmpty) {
        final path = Path();
        path.moveTo(vertices[0].dx, vertices[0].dy);
        for (int i = 1; i < vertices.length; i++) {
          path.lineTo(vertices[i].dx, vertices[i].dy);
        }
        path.close();

        // Fill hex
        canvas.drawPath(path, _normalPaint);

        // Draw border
        canvas.drawPath(path, _strokePaint);

        // Highlight available moves
        if (gameState.availableMoves.contains(hex)) {
          canvas.drawPath(path, _movePaint);
        }

        // Highlight available attacks
        if (gameState.availableAttacks.contains(hex)) {
          canvas.drawPath(path, _attackPaint);
        }
      }
    }
  }

  void _drawUnits(Canvas canvas, Size size, ChexxGameState gameState) {
    // Render simple units with basic drawing
    for (int i = 0; i < gameState.simpleUnits.length; i++) {
      final unit = gameState.simpleUnits[i];
      final center = engine.hexToScreen(unit.position, size);

      // Simple unit colors
      final color = (unit.owner == Player.player1) ? Colors.blue : Colors.red;
      final paint = Paint()..color = color;

      // Draw unit as circle
      canvas.drawCircle(center, 20, paint);

      // Draw border if selected
      if (unit.isSelected) {
        final borderPaint = Paint()
          ..color = Colors.yellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, 20, borderPaint);
      }
    }
  }

  void _drawUnit(Canvas canvas, Size size, Entity entity) {
    final position = entity.get<PositionComponent>()!;
    final owner = entity.get<OwnerComponent>()!;
    final health = entity.get<HealthComponent>()!;
    final selection = entity.get<SelectionComponent>();

    if (!health.isAlive) return;

    final center = engine.hexToScreen(position.coordinate, size);
    final radius = engine.hexSize * 0.4;

    // Unit colors
    final baseColor = owner.owner.name == 'player1'
        ? Colors.blue.shade600
        : Colors.red.shade600;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selection?.isSelected == true ? 4.0 : 2.0
      ..color = selection?.isSelected == true
          ? Colors.yellow.shade700
          : Colors.black87;

    // Draw unit circle
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw health bar if damaged
    if (health.currentHealth < health.maxHealth) {
      _drawHealthBar(canvas, center, health);
    }
  }

  void _drawSimpleUnit(Canvas canvas, Size size, SimpleGameUnit unit) {
    final center = engine.hexToScreen(unit.position, size);
    final radius = engine.hexSize * 0.4;

    // Unit colors based on owner
    final baseColor = unit.owner == Player.player1
        ? Colors.blue.shade600
        : Colors.red.shade600;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit.isSelected ? 4.0 : 2.0
      ..color = unit.isSelected
          ? Colors.yellow.shade700
          : Colors.black87;

    // Draw unit circle
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw health bar if damaged
    if (unit.health < unit.maxHealth) {
      _drawSimpleHealthBar(canvas, center, unit.health, unit.maxHealth);
    }
  }

  void _drawHealthBar(Canvas canvas, Offset center, HealthComponent health) {
    const barWidth = 30.0;
    const barHeight = 4.0;
    final barY = center.dy - engine.hexSize * 0.8;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, barWidth, barHeight),
      Paint()..color = Colors.grey.shade700,
    );

    // Health
    final healthPercent = health.healthPercentage;
    final healthWidth = barWidth * healthPercent;

    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, healthWidth, barHeight),
      Paint()..color = Colors.green.shade600,
    );
  }

  void _drawSimpleHealthBar(Canvas canvas, Offset center, int currentHealth, int maxHealth) {
    const barWidth = 30.0;
    const barHeight = 4.0;
    final barY = center.dy - engine.hexSize * 0.8;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, barWidth, barHeight),
      Paint()..color = Colors.grey.shade700,
    );

    // Health
    final healthPercent = currentHealth / maxHealth;
    final healthWidth = barWidth * healthPercent;

    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, healthWidth, barHeight),
      Paint()..color = Colors.green.shade600,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
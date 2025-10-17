import 'package:flutter/material.dart';
import 'dart:math';
import 'package:chexx/core/interfaces/unit_factory.dart';
import '../../../utils/tile_colors.dart';
import '../../../models/scenario_builder_state.dart';
import '../../../models/hex_coordinate.dart';
import '../../../models/game_board.dart';
import '../../../models/game_state.dart';
import '../../../models/hex_orientation.dart';
import '../../scenario_builder_screen.dart';

/// Custom painter for the scenario builder board
class ScenarioBuilderPainter extends CustomPainter {
  final ScenarioBuilderState state;
  final double hexSize;
  final ScenarioBuilderScreenState widgetState;

  ScenarioBuilderPainter(this.state, this.hexSize, this.widgetState);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw hex tiles
    _drawHexTiles(canvas, size, centerX, centerY);

    // Draw placed structures (above tiles, below units)
    _drawPlacedStructures(canvas, size, centerX, centerY);

    // Draw vertical partition lines (if enabled)
    _drawVerticalLines(canvas, size, centerX, centerY);

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

        // Board thirds: Highlight hexes by third membership (when individual third toggles are active)
        if (state.highlightLeftThird || state.highlightMiddleThird || state.highlightRightThird) {
          final inLeft = state.leftThirdHexes.contains(coord);
          final inMiddle = state.middleThirdHexes.contains(coord);
          final inRight = state.rightThirdHexes.contains(coord);

          // Determine which highlights should be shown
          final showLeft = state.highlightLeftThird && inLeft;
          final showMiddle = state.highlightMiddleThird && inMiddle;
          final showRight = state.highlightRightThird && inRight;

          // Use distinct colors for each third
          if (showLeft && showMiddle) {
            // Hex belongs to both left and middle (on boundary) and both are highlighted
            final boundaryOverlay = Paint()
              ..color = Colors.purple.withOpacity(0.2)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, boundaryOverlay);
          } else if (showMiddle && showRight) {
            // Hex belongs to both middle and right (on boundary) and both are highlighted
            final boundaryOverlay = Paint()
              ..color = Colors.orange.withOpacity(0.2)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, boundaryOverlay);
          } else if (showLeft) {
            // Hex in left third and left is highlighted
            final leftOverlay = Paint()
              ..color = Colors.cyan.withOpacity(0.15)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, leftOverlay);
          } else if (showMiddle) {
            // Hex in middle third and middle is highlighted
            final middleOverlay = Paint()
              ..color = Colors.yellow.withOpacity(0.15)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, middleOverlay);
          } else if (showRight) {
            // Hex in right third and right is highlighted
            final rightOverlay = Paint()
              ..color = Colors.pink.withOpacity(0.15)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, rightOverlay);
          }
        }

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
        case StructureType.medal:
          // Draw medal as a 5-pointed star
          final path = Path();
          final outerRadius = size * 0.5;
          final innerRadius = size * 0.2;
          for (int i = 0; i < 5; i++) {
            final outerAngle = (i * 2 * pi / 5) - (pi / 2);
            final innerAngle = ((i * 2 * pi / 5) + (pi / 5)) - (pi / 2);

            final outerX = center.dx + outerRadius * cos(outerAngle);
            final outerY = center.dy + outerRadius * sin(outerAngle);
            final innerX = center.dx + innerRadius * cos(innerAngle);
            final innerY = center.dy + innerRadius * sin(innerAngle);

            if (i == 0) {
              path.moveTo(outerX, outerY);
            } else {
              path.lineTo(outerX, outerY);
            }
            path.lineTo(innerX, innerY);
          }
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

      // Check if unit is incrementable
      final isIncrementable = widgetState.getActualIsIncrementable(placedUnit.template);
      final health = widgetState.getCurrentHealth(placedUnit);

      // Unit colors
      final baseColor = placedUnit.template.owner == Player.player1
          ? Colors.blue.shade600
          : Colors.red.shade600;

      if (isIncrementable && health <= 6) {
        // Draw multiple icons based on health (1-6)
        _drawMultipleIconsForUnit(canvas, center, radius, baseColor, health, placedUnit.template);
      } else if (isIncrementable && health > 6) {
        // Draw single icon with health number for health > 6
        _drawSingleIconWithNumber(canvas, center, radius, baseColor, health, placedUnit.template);
      } else {
        // Draw standard unit (non-incrementable)
        _drawStandardUnit(canvas, center, radius, baseColor, placedUnit.template);
      }
    }
  }

  void _drawMultipleIconsForUnit(Canvas canvas, Offset center, double radius, Color baseColor, int health, UnitTemplate template) {
    final iconRadius = radius * 0.6; // Smaller icons when multiple
    final positions = _calculateIconPositions(center, health, iconRadius);

    for (final position in positions) {
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor;

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.black87;

      canvas.drawCircle(position, iconRadius, fillPaint);
      canvas.drawCircle(position, iconRadius, strokePaint);

      // Draw unit symbol on each icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: widgetState.getActualUnitSymbol(template),
          style: TextStyle(
            color: Colors.white,
            fontSize: iconRadius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawSingleIconWithNumber(Canvas canvas, Offset center, double radius, Color baseColor, int health, UnitTemplate template) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black87;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    // Draw health number
    final textPainter = TextPainter(
      text: TextSpan(
        text: health.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
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

  void _drawStandardUnit(Canvas canvas, Offset center, double radius, Color baseColor, UnitTemplate template) {
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
        text: widgetState.getActualUnitSymbol(template),
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

  List<Offset> _calculateIconPositions(Offset center, int count, double iconRadius) {
    List<Offset> positions = [];

    // Increased spacing multiplier for better visual separation (matching game mode)
    final spacing = iconRadius * 1.5;

    if (count == 1) {
      positions.add(center);
    } else if (count == 2) {
      positions.add(Offset(center.dx - spacing, center.dy));
      positions.add(Offset(center.dx + spacing, center.dy));
    } else if (count == 3) {
      positions.add(Offset(center.dx, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy + spacing * 0.6));
      positions.add(Offset(center.dx + spacing, center.dy + spacing * 0.6));
    } else if (count == 4) {
      positions.add(Offset(center.dx - spacing, center.dy - spacing));
      positions.add(Offset(center.dx + spacing, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy + spacing));
      positions.add(Offset(center.dx + spacing, center.dy + spacing));
    } else if (count == 5) {
      positions.add(Offset(center.dx, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy - spacing * 0.3));
      positions.add(Offset(center.dx + spacing, center.dy - spacing * 0.3));
      positions.add(Offset(center.dx - spacing, center.dy + spacing));
      positions.add(Offset(center.dx + spacing, center.dy + spacing));
    } else if (count == 6) {
      positions.add(Offset(center.dx - spacing, center.dy - spacing));
      positions.add(Offset(center.dx, center.dy - spacing));
      positions.add(Offset(center.dx + spacing, center.dy - spacing));
      positions.add(Offset(center.dx - spacing, center.dy + spacing));
      positions.add(Offset(center.dx, center.dy + spacing));
      positions.add(Offset(center.dx + spacing, center.dy + spacing));
    }

    return positions;
  }

  /// Draw health indicators as small dots around the unit
  void _drawHealthIndicators(Canvas canvas, Offset center, int health) {
    const dotRadius = 3.0;
    const spacing = 8.0;
    final healthPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green.shade400;

    final healthStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black87;

    // Draw health dots in a line below the unit
    final startX = center.dx - ((health - 1) * spacing) / 2;
    final dotY = center.dy + hexSize * 0.6;

    for (int i = 0; i < health; i++) {
      final dotX = startX + (i * spacing);
      final dotCenter = Offset(dotX, dotY);

      canvas.drawCircle(dotCenter, dotRadius, healthPaint);
      canvas.drawCircle(dotCenter, dotRadius, healthStrokePaint);
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
      case StructureType.medal:
        return Colors.amber.shade600;
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
      case StructureType.medal:
        return 'M';
    }
  }

  Color _getTileTypeColor(HexType type) {
    return TileColors.getColorForTileType(type);
  }

  void _drawVerticalLines(Canvas canvas, Size size, double centerX, double centerY) {
    if (!state.showVerticalLines) return;

    // Convert normalized x-coordinates to screen x-coordinates
    // The boundaries are stored in normalized space (as if hexSize = 1)
    // Multiply by hexSize to get actual screen coordinates
    final leftLineScreenX = centerX + hexSize * state.leftLineX;
    final rightLineScreenX = centerX + hexSize * state.rightLineX;

    // Draw vertical lines from top to bottom of canvas
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw left dividing line
    canvas.drawLine(
      Offset(leftLineScreenX, 0),
      Offset(leftLineScreenX, size.height),
      linePaint,
    );

    // Draw right dividing line
    canvas.drawLine(
      Offset(rightLineScreenX, 0),
      Offset(rightLineScreenX, size.height),
      linePaint,
    );

    // Draw labels for the thirds
    final labelPaint = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Use a better calculation: find the midpoint between left edge of screen and left line
    final leftEdgeX = 0.0;
    final leftThirdCenterX = (leftEdgeX + leftLineScreenX) / 2;

    // Left third label
    labelPaint.text = TextSpan(
      text: 'LEFT THIRD',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPaint.layout();
    labelPaint.paint(
      canvas,
      Offset(leftThirdCenterX - labelPaint.width / 2, 20),
    );

    // Middle third label
    final middleThirdCenterX = (leftLineScreenX + rightLineScreenX) / 2;
    labelPaint.text = TextSpan(
      text: 'MIDDLE THIRD',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPaint.layout();
    labelPaint.paint(
      canvas,
      Offset(middleThirdCenterX - labelPaint.width / 2, 20),
    );

    // Right third label
    final rightThirdCenterX = (rightLineScreenX + size.width) / 2;
    labelPaint.text = TextSpan(
      text: 'RIGHT THIRD',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    labelPaint.layout();
    labelPaint.paint(
      canvas,
      Offset(rightThirdCenterX - labelPaint.width / 2, 20),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

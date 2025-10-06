import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oxygen/oxygen.dart';
import '../../../src/utils/tile_colors.dart';
import '../../../core/engine/game_engine_base.dart';
import '../../../core/models/hex_coordinate.dart';
import '../../../src/models/hex_orientation.dart';
import '../../../core/interfaces/game_plugin.dart';
import '../../../core/interfaces/unit_factory.dart';
import '../../../core/components/position_component.dart';
import '../../../core/components/owner_component.dart';
import '../../../core/components/health_component.dart';
import '../../../core/components/selection_component.dart';
import '../models/chexx_game_state.dart';
import '../../../src/models/hex_orientation.dart';
import '../../../src/models/scenario_builder_state.dart';
import '../../../src/models/game_board.dart';
import '../../../src/systems/combat/die_faces_config.dart';

/// CHEXX-specific game engine
class ChexxGameEngine extends GameEngineBase {
  // Note: Using gameState.hexOrientation instead of local orientation


  ChexxGameEngine({
    required GamePlugin gamePlugin,
    Map<String, dynamic>? scenarioConfig,
  }) : super(gamePlugin: gamePlugin, scenarioConfig: scenarioConfig);

  int _getUnitAttackRange(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  int _getUnitAttackDamage(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 1;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  int _getUnitMovementRange(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  void handleTap(Offset position, Size canvasSize) {
    final chexxGameState = gameState as ChexxGameState;

    // Convert screen position to hex coordinate using current orientation
    final hexCoord = _screenToHex(position, canvasSize);

    if (hexCoord != null) {
      handleHexTap(hexCoord);
    }
  }

  HexCoordinate? _screenToHex(Offset screenPos, Size canvasSize) {
    final chexxGameState = gameState as ChexxGameState;

    // Convert screen position to game world position
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    final gameX = screenPos.dx - centerX;
    final gameY = screenPos.dy - centerY;

    // Convert pixel to hex using orientation-aware math
    final hexSize = 50.0;
    double q, r;

    if (chexxGameState.hexOrientation == HexOrientation.flat) {
      // Flat-top orientation
      q = (2.0 / 3.0 * gameX) / hexSize;
      r = (-1.0 / 3.0 * gameX + sqrt(3) / 3.0 * gameY) / hexSize;
    } else {
      // Pointy-top orientation
      q = (sqrt(3) / 3.0 * gameX - 1.0 / 3.0 * gameY) / hexSize;
      r = (2.0 / 3.0 * gameY) / hexSize;
    }

    // Round to integer coordinates
    final s = -q - r;
    var rQ = q.round();
    var rR = r.round();
    var rS = s.round();

    final qDiff = (rQ - q).abs();
    final rDiff = (rR - r).abs();
    final sDiff = (rS - s).abs();

    if (qDiff > rDiff && qDiff > sDiff) {
      rQ = -rR - rS;
    } else if (rDiff > sDiff) {
      rR = -rQ - rS;
    } else {
      rS = -rQ - rR;
    }

    return HexCoordinate(rQ, rR, rS);
  }

  @override
  void handleHexTap(HexCoordinate hexCoord) {
    final chexxGameState = gameState as ChexxGameState;


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
        // Clear previous wayfinding, attack range, and targeted enemy
        chexxGameState.moveAndFireHexes.clear();
        chexxGameState.moveOnlyHexes.clear();
        chexxGameState.attackRangeHexes.clear();
        chexxGameState.targetedEnemy = null;
        // Select this unit
        unitAtPosition.isSelected = true;
        print('Selected unit: ${unitAtPosition.id}');

        // Calculate wayfinding for the selected unit
        chexxGameState.calculateWayfinding(unitAtPosition);

        // Calculate attack range for the selected unit
        chexxGameState.calculateAttackRange(unitAtPosition);

        // Notify card game if in card mode (unit selected)
        if (chexxGameState.gameMode == 'card' && chexxGameState.onUnitSelected != null) {
          chexxGameState.onUnitSelected!();
        }

        notifyListeners();
      } else {
        // Enemy unit - try to attack if we have a selected unit
        SimpleGameUnit? selectedUnit;
        for (final unit in chexxGameState.simpleUnits) {
          if (unit.isSelected) {
            selectedUnit = unit;
            break;
          }
        }

        if (selectedUnit != null) {
          // In card mode, require an active card action AND highlighted hex
          if (chexxGameState.gameMode == 'card') {
            if (!chexxGameState.isCardActionActive) {
              print('Cannot attack - play a card action first');
              return;
            }
            // In card mode, can only attack if unit's hex is highlighted
            if (!chexxGameState.highlightedHexes.contains(selectedUnit.position)) {
              print('Cannot attack - unit not in highlighted hex for current action');
              return;
            }
          }

          final distance = selectedUnit.position.distanceTo(hexCoord);
          final attackRange = _getUnitAttackRange(selectedUnit.unitType);

          if (distance <= attackRange) {
            // Two-click attack system: first click targets, second click confirms
            if (chexxGameState.targetedEnemy == unitAtPosition) {
              // Second click on same enemy - perform attack
              print('Confirming attack on ${unitAtPosition.unitType}');

              // Check if this is a special attack by a tank (after overrun)
              final isSpecialAttack = selectedUnit.unitType == 'armor' &&
                                     (chexxGameState.unitCanSpecialAttack[selectedUnit.id] ?? false) &&
                                     !(chexxGameState.unitUsedSpecialAttack[selectedUnit.id] ?? false);

              // Attack the target unit
              // Roll dice for attack
              final diceRollResults = _performDiceBasedAttack(selectedUnit, unitAtPosition);
              final damage = diceRollResults.$1;
              final diceRolls = diceRollResults.$2;

              // Record dice roll results for display
              final result = '$damage damage dealt';
              chexxGameState.recordDiceRoll(diceRolls, result);
              final newHealth = (unitAtPosition.health - damage).clamp(0, unitAtPosition.maxHealth).toInt();

              if (isSpecialAttack) {
                print('${selectedUnit.unitType} makes SPECIAL ATTACK on ${unitAtPosition.unitType} for $damage damage (dice: ${diceRolls.map((d) => d.symbol).join(', ')})');
                // Mark special attack as used and clear the ability
                chexxGameState.unitUsedSpecialAttack[selectedUnit.id] = true;
                chexxGameState.unitCanSpecialAttack[selectedUnit.id] = false;
              } else {
                print('${selectedUnit.unitType} attacks ${unitAtPosition.unitType} for $damage damage (dice: ${diceRolls.map((d) => d.symbol).join(', ')})');
              }

              // Notify card game if in card mode (combat occurred)
              if (chexxGameState.gameMode == 'card' && chexxGameState.onCombatOccurred != null) {
                chexxGameState.onCombatOccurred!();
              }

              // Clear targeted enemy after attack
              chexxGameState.targetedEnemy = null;

              if (newHealth <= 0) {
                // Remove dead unit
                final destroyedPosition = unitAtPosition.position;
                chexxGameState.simpleUnits.remove(unitAtPosition);
                print('${unitAtPosition.unitType} destroyed!');

                // Combat movement (overrun): Tanks and Infantry can move into the hex
                if (selectedUnit.unitType == 'armor' || selectedUnit.unitType == 'infantry') {
                  // Calculate move_after_combat: base value + bonus from card action
                  final moveAfterCombat = selectedUnit.moveAfterCombat +
                                         (chexxGameState.unitMoveAfterCombatBonus[selectedUnit.id] ?? 0);

                  // Move attacking unit to the now-empty hex with additional movement if applicable
                  final updatedAttacker = SimpleGameUnit(
                    id: selectedUnit.id,
                    unitType: selectedUnit.unitType,
                    owner: selectedUnit.owner,
                    position: destroyedPosition,
                    health: selectedUnit.health,
                    maxHealth: selectedUnit.maxHealth,
                    remainingMovement: selectedUnit.remainingMovement + moveAfterCombat,
                    moveAfterCombat: selectedUnit.moveAfterCombat,
                    isSelected: true,
                  );

                  final attackerIndex = chexxGameState.simpleUnits.indexOf(selectedUnit);
                  if (attackerIndex != -1) {
                    chexxGameState.simpleUnits[attackerIndex] = updatedAttacker;
                  }

                  if (moveAfterCombat > 0) {
                    print('${selectedUnit.unitType} moves into conquered hex (combat movement) and gains $moveAfterCombat additional movement');
                  } else {
                    print('${selectedUnit.unitType} moves into conquered hex (combat movement)');
                  }

                  // Notify card game if in card mode (after combat movement)
                  if (chexxGameState.gameMode == 'card' && chexxGameState.onAfterCombatMovement != null) {
                    chexxGameState.onAfterCombatMovement!();
                  }

                  // If tank, enable special attack (if not already used this turn)
                  if (selectedUnit.unitType == 'armor') {
                    if (!(chexxGameState.unitUsedSpecialAttack[selectedUnit.id] ?? false)) {
                      chexxGameState.unitCanSpecialAttack[selectedUnit.id] = true;
                      print('${selectedUnit.unitType} can now make a special attack!');
                    }
                  }

                  // Recalculate attack range for new position (but not wayfinding during card actions)
                  chexxGameState.calculateAttackRange(updatedAttacker);
                }
              } else {
                // Update damaged unit
                final updatedUnit = SimpleGameUnit(
                  id: unitAtPosition.id,
                  unitType: unitAtPosition.unitType,
                  owner: unitAtPosition.owner,
                  position: unitAtPosition.position,
                  health: newHealth,
                  maxHealth: unitAtPosition.maxHealth,
                  remainingMovement: unitAtPosition.remainingMovement,
                  moveAfterCombat: unitAtPosition.moveAfterCombat,
                  isSelected: unitAtPosition.isSelected,
                );

                final index = chexxGameState.simpleUnits.indexOf(unitAtPosition);
                if (index != -1) {
                  chexxGameState.simpleUnits[index] = updatedUnit;
                }
                print('${unitAtPosition.unitType} health: $newHealth/${unitAtPosition.maxHealth}');
              }

              // Clear attack range highlights after attacking
              chexxGameState.attackRangeHexes.clear();

              // Notify card game if in card mode (action completed)
              if (chexxGameState.gameMode == 'card' && chexxGameState.onUnitOrdered != null) {
                chexxGameState.onUnitOrdered!();
              }
            } else {
              // First click on enemy - target it for attack
              chexxGameState.targetedEnemy = unitAtPosition;
              print('Targeting ${unitAtPosition.unitType} for attack - click again to confirm');
              notifyListeners();
            }
          } else {
            print('Target out of range (distance: $distance, range: $attackRange)');
          }
        }
      }
    } else {
      // Clicking on empty hex - clear targeted enemy
      chexxGameState.targetedEnemy = null;

      // Try to move selected unit to this position
      SimpleGameUnit? selectedUnit;
      for (final unit in chexxGameState.simpleUnits) {
        if (unit.isSelected) {
          selectedUnit = unit;
          break;
        }
      }

      if (selectedUnit != null) {
        // In card mode, require an active card action AND highlighted hex
        if (chexxGameState.gameMode == 'card') {
          if (!chexxGameState.isCardActionActive) {
            print('Cannot move - play a card action first');
            return;
          }
          // In card mode, can only move if unit's hex is highlighted
          if (!chexxGameState.highlightedHexes.contains(selectedUnit.position)) {
            print('Cannot move - unit not in highlighted hex for current action');
            return;
          }
        }

        // Movement validation - check if hex is reachable via wayfinding
        final isInMoveAndFire = chexxGameState.moveAndFireHexes.contains(hexCoord);
        final isInMoveOnly = chexxGameState.moveOnlyHexes.contains(hexCoord);

        if (isInMoveAndFire || isInMoveOnly) {
          // Calculate actual movement cost for this hex
          final distance = selectedUnit.position.distanceTo(hexCoord);
          // Create new unit with updated position and reduced movement
          final updatedUnit = SimpleGameUnit(
            id: selectedUnit.id,
            unitType: selectedUnit.unitType,
            owner: selectedUnit.owner,
            position: hexCoord,
            health: selectedUnit.health,
            maxHealth: selectedUnit.maxHealth,
            remainingMovement: selectedUnit.remainingMovement - distance,
            moveAfterCombat: selectedUnit.moveAfterCombat,
            isSelected: true,
          );

          // Replace unit in list
          final index = chexxGameState.simpleUnits.indexOf(selectedUnit);
          if (index != -1) {
            chexxGameState.simpleUnits[index] = updatedUnit;
          }
          print('Moved unit to: $hexCoord');

          // Clear targeted enemy and wayfinding highlights after moving
          chexxGameState.targetedEnemy = null;
          chexxGameState.moveAndFireHexes.clear();
          chexxGameState.moveOnlyHexes.clear();

          // Recalculate attack range for new position (but not wayfinding during card actions)
          chexxGameState.calculateAttackRange(updatedUnit);

          // Notify card game if in card mode (unit moved)
          if (chexxGameState.gameMode == 'card' && chexxGameState.onUnitMoved != null) {
            chexxGameState.onUnitMoved!();
          }

          // Don't complete action after movement - allow unit to attack first
          // Action will complete when attack is made or another unit is ordered
        } else {
          print('Cannot move to this hex - not within reachable range');
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
    gameState.attackRangeHexes.clear();
    gameState.targetedEnemy = null;
  }

  void _moveSimpleUnit(ChexxGameState gameState, SimpleGameUnit unit, HexCoordinate target) {
    final distance = unit.position.distanceTo(target);
    // Update unit position (create new unit with updated position)
    final updatedUnit = SimpleGameUnit(
      id: unit.id,
      unitType: unit.unitType,
      owner: unit.owner,
      position: target,
      health: unit.health,
      maxHealth: unit.maxHealth,
      remainingMovement: unit.remainingMovement - distance,
      moveAfterCombat: unit.moveAfterCombat,
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
        remainingMovement: target.remainingMovement,
        moveAfterCombat: target.moveAfterCombat,
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
    // Movement validation with remaining movement check
    final distance = unit.position.distanceTo(target);
    final movementRange = _getUnitMovementRange(unit.unitType);
    return distance <= movementRange && unit.remainingMovement >= distance;
  }

  bool _isValidAttack(SimpleGameUnit attacker, SimpleGameUnit target) {
    // Simple attack validation - adjacent hexes only for now
    final distance = attacker.position.distanceTo(target.position);
    return distance <= 1 && attacker.owner != target.owner;
  }

  /// Perform dice-based attack using WWII combat system
  (int, List<DieFace>) _performDiceBasedAttack(SimpleGameUnit attacker, SimpleGameUnit defender) {
    // Load die faces configuration - for now, use a simplified version
    // In a real implementation, this would be cached
    final diceConfig = _getDefaultDiceConfig();

    // Calculate number of dice to roll based on attacker damage
    final baseDamage = _getUnitAttackDamage(attacker.unitType);
    final numDice = baseDamage;

    // Roll dice
    final diceRolls = <DieFace>[];
    final random = Random();
    int totalDamage = 0;

    for (int i = 0; i < numDice; i++) {
      final roll = random.nextInt(6) + 1; // 1-6
      final dieFace = _getDieFaceForRoll(roll);
      diceRolls.add(dieFace);

      // Calculate damage based on die face type
      final damage = _calculateDamageFromDieFace(dieFace, defender);
      totalDamage += damage;
    }

    return (totalDamage, diceRolls);
  }

  /// Get default dice configuration (simplified version)
  Map<int, DieFace> _getDefaultDiceConfig() {
    return {
      1: const DieFace(unitType: 'infantry', symbol: 'I', description: 'Infantry unit face'),
      2: const DieFace(unitType: 'armor', symbol: 'A', description: 'Armor unit face'),
      3: const DieFace(unitType: 'grenade', symbol: 'G', description: 'Grenade die face'),
      4: const DieFace(unitType: 'infantry', symbol: 'I', description: 'Infantry unit face #2'),
      5: const DieFace(unitType: 'retreat', symbol: 'R', description: 'Flag/Retreat die face'),
      6: const DieFace(unitType: 'star', symbol: 'S', description: 'Star die face'),
    };
  }

  /// Get die face for a specific roll result
  DieFace _getDieFaceForRoll(int roll) {
    final config = _getDefaultDiceConfig();
    return config[roll] ?? const DieFace(unitType: 'infantry', symbol: 'I', description: 'Default infantry');
  }

  /// Calculate damage from a die face result
  int _calculateDamageFromDieFace(DieFace dieFace, SimpleGameUnit defender) {
    // Base damage based on die face type
    switch (dieFace.unitType) {
      case 'infantry':
        return 1;
      case 'armor':
        return 2;
      case 'grenade':
        return 3;
      case 'star':
        return 2;
      case 'retreat':
        return 0; // Retreat does no damage
      default:
        return 1;
    }
  }

  // Note: toggleHexOrientation is now handled by gameState.toggleHexOrientation()

  /// Convert hex coordinate to screen position
  Offset hexToScreen(HexCoordinate hex, Size canvasSize) {
    final hexSize = 50.0; // Same as the other engine
    final currentOrientation = (gameState as ChexxGameState).hexOrientation;

    // Implement orientation-aware pixel conversion
    late double x, y;
    if (currentOrientation == HexOrientation.flat) {
      // Flat-top orientation (original)
      x = hexSize * (3.0 / 2.0 * hex.q);
      y = hexSize * (sqrt(3.0) / 2.0 * hex.q + sqrt(3.0) * hex.r);
    } else {
      // Pointy-top orientation
      x = hexSize * (sqrt(3.0) * hex.q + sqrt(3.0) / 2.0 * hex.r);
      y = hexSize * (3.0 / 2.0 * hex.r);
    }

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    return Offset(centerX + x, centerY + y);
  }

  /// Get hex vertices for rendering
  List<Offset> getHexVertices(HexCoordinate hex, Size canvasSize) {
    final hexSize = 50.0; // Same as the other engine
    final center = hexToScreen(hex, canvasSize);
    final vertices = <Offset>[];

    // Use gameState's orientation instead of engine's local orientation
    final currentOrientation = (gameState as ChexxGameState).hexOrientation;


    for (int i = 0; i < 6; i++) {
      // Calculate hexagon vertices based on orientation
      double angle;
      if (currentOrientation == HexOrientation.flat) {
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
}

/// Custom painter for CHEXX game rendering
class ChexxGamePainter extends CustomPainter {
  final ChexxGameEngine engine;

  // Cached paint objects for performance
  static final Paint _normalPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.lightGreen.shade100;

  static final Paint _metaPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = TileColors.getColorForTileType(HexType.meta);

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

    // Draw structures
    _drawStructures(canvas, size, gameState);

    // Draw units
    _drawUnits(canvas, size, gameState);
  }

  void _drawHexTiles(Canvas canvas, Size size, ChexxGameState gameState) {
    if (gameState.board.allTiles.isEmpty) {
      return;
    }

    // Draw board tiles from game state (supporting custom scenarios)
    int matchCount = 0;
    for (final tile in gameState.board.allTiles) {
      final hex = HexCoordinate(tile.coordinate.q, tile.coordinate.r, tile.coordinate.s);
      final vertices = engine.getHexVertices(hex, size);
      if (vertices.isNotEmpty) {
        final path = Path();
        path.moveTo(vertices[0].dx, vertices[0].dy);
        for (int i = 1; i < vertices.length; i++) {
          path.lineTo(vertices[i].dx, vertices[i].dy);
        }
        path.close();

        // Check if this tile is a meta hex
        bool isMetaHex = tile.type == HexType.meta;

        // Choose paint based on tile type and meta hex status
        Paint tilePaint = _normalPaint;
        if (isMetaHex) {
          tilePaint = _metaPaint;
        } else {
          // Use centralized tile colors from TileColors utility
          tilePaint = TileColors.getPaintForTileType(tile.type);
        }

        // Fill hex
        canvas.drawPath(path, tilePaint);

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

        // Highlight hexes for card actions (use player's color overlay)
        // Convert tile coordinate to core HexCoordinate for comparison
        final coreCoord = HexCoordinate(tile.coordinate.q, tile.coordinate.r, tile.coordinate.s);
        if (gameState.highlightedHexes.contains(coreCoord)) {
          matchCount++;
          // Get current player's color with alpha
          final playerColor = gameState.currentPlayer == Player.player1
              ? Colors.blue.withOpacity(0.37)
              : Colors.red.withOpacity(0.37);

          final highlightOverlay = Paint()
            ..color = playerColor
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, highlightOverlay);
        }

        // Wayfinding: Highlight move_and_fire hexes (green)
        if (gameState.moveAndFireHexes.contains(coreCoord)) {
          final greenOverlay = Paint()
            ..color = Colors.green.withOpacity(0.37)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, greenOverlay);
        }

        // Wayfinding: Highlight move_only hexes (yellow)
        if (gameState.moveOnlyHexes.contains(coreCoord)) {
          final yellowOverlay = Paint()
            ..color = Colors.yellow.withOpacity(0.37)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, yellowOverlay);
        }

        // Attack range: Highlight enemy hexes with red, varying alpha by damage
        if (gameState.attackRangeHexes.containsKey(coreCoord)) {
          final damage = gameState.attackRangeHexes[coreCoord]!;
          // Map damage to alpha: 1=0.20, 2=0.40, 3=0.60, 4=0.80
          final alpha = (damage * 0.20).clamp(0.20, 0.80);
          final redOverlay = Paint()
            ..color = Colors.red.withOpacity(alpha)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, redOverlay);
        }

        // Targeted enemy: Draw bright orange outline
        if (gameState.targetedEnemy != null && gameState.targetedEnemy!.position == coreCoord) {
          final targetOutline = Paint()
            ..color = Colors.orange
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4;
          canvas.drawPath(path, targetOutline);
        }
      }
    }

    if (gameState.highlightedHexes.isNotEmpty && matchCount == 0) {
      print('HIGHLIGHT ERROR: 0 matches found! Highlighted: ${gameState.highlightedHexes.first}, Sample tile: ${gameState.board.allTiles.first.coordinate}');
    }
  }

  void _drawUnits(Canvas canvas, Size size, ChexxGameState gameState) {
    if (gameState.simpleUnits.isEmpty) {
      return;
    }

    for (int i = 0; i < gameState.simpleUnits.length; i++) {
      final unit = gameState.simpleUnits[i];

      final center = engine.hexToScreen(unit.position, size);

      // Check if unit is incrementable
      final isIncrementable = _isUnitIncrementable(unit.unitType);

      if (isIncrementable) {
        _drawIncrementableUnit(canvas, center, unit);
      } else {
        _drawStandardUnit(canvas, center, unit);
      }
    }
  }

  void _drawStandardUnit(Canvas canvas, Offset center, SimpleGameUnit unit) {
    // Unit size based on type
    final radius = _getUnitRadius(unit.unitType);

    // Base color by owner
    final baseColor = (unit.owner == Player.player1) ? Colors.blue : Colors.red;

    // Modify color intensity based on unit type
    final color = _getUnitColor(baseColor, unit.unitType);
    final paint = Paint()..color = color;

    // Draw unit as circle
    canvas.drawCircle(center, radius, paint);

    // Draw border if selected
    if (unit.isSelected) {
      final borderPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius, borderPaint);
    }

    // Draw health indicator for units with more than 1 health
    if (unit.maxHealth > 1) {
      _drawSimpleHealthIndicator(canvas, center, unit.health, unit.maxHealth, radius);
    }
  }

  void _drawIncrementableUnit(Canvas canvas, Offset center, SimpleGameUnit unit) {
    final radius = _getUnitRadius(unit.unitType);
    final baseColor = (unit.owner == Player.player1) ? Colors.blue : Colors.red;
    final color = _getUnitColor(baseColor, unit.unitType);

    if (unit.health > 6) {
      // Draw single icon with health number for health > 6
      final paint = Paint()..color = color;
      canvas.drawCircle(center, radius, paint);

      // Draw border if selected
      if (unit.isSelected) {
        final borderPaint = Paint()
          ..color = Colors.yellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, radius, borderPaint);
      }

      // Draw health number
      _drawHealthNumber(canvas, center, unit.health, radius);
    } else {
      // Draw multiple icons based on current health (1-6)
      _drawMultipleIcons(canvas, center, unit, radius, color);
    }
  }

  void _drawMultipleIcons(Canvas canvas, Offset center, SimpleGameUnit unit, double radius, Color color) {
    final health = unit.health;
    final iconRadius = radius * 0.6; // Smaller icons when multiple

    // Calculate positions for multiple icons in a compact arrangement
    final positions = _calculateIconPositions(center, health, iconRadius);

    for (int i = 0; i < positions.length; i++) {
      final iconPaint = Paint()..color = color;
      canvas.drawCircle(positions[i], iconRadius, iconPaint);

      // Draw border for selected unit on all icons
      if (unit.isSelected) {
        final borderPaint = Paint()
          ..color = Colors.yellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(positions[i], iconRadius, borderPaint);
      }
    }
  }

  List<Offset> _calculateIconPositions(Offset center, int count, double iconRadius) {
    List<Offset> positions = [];

    if (count == 1) {
      positions.add(center);
    } else if (count == 2) {
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy));
    } else if (count == 3) {
      positions.add(Offset(center.dx, center.dy - iconRadius * 0.8));
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy + iconRadius * 0.5));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy + iconRadius * 0.5));
    } else if (count == 4) {
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy - iconRadius * 0.8));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy - iconRadius * 0.8));
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy + iconRadius * 0.8));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy + iconRadius * 0.8));
    } else if (count == 5) {
      positions.add(Offset(center.dx, center.dy - iconRadius * 0.8));
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy - iconRadius * 0.3));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy - iconRadius * 0.3));
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy + iconRadius * 0.8));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy + iconRadius * 0.8));
    } else if (count == 6) {
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy - iconRadius * 0.8));
      positions.add(Offset(center.dx, center.dy - iconRadius * 0.8));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy - iconRadius * 0.8));
      positions.add(Offset(center.dx - iconRadius * 0.8, center.dy + iconRadius * 0.8));
      positions.add(Offset(center.dx, center.dy + iconRadius * 0.8));
      positions.add(Offset(center.dx + iconRadius * 0.8, center.dy + iconRadius * 0.8));
    }

    return positions;
  }

  void _drawHealthNumber(Canvas canvas, Offset center, int health, double radius) {
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
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  bool _isUnitIncrementable(String unitType) {
    // Check unit configuration for incrementable property
    switch (unitType) {
      case 'minor': return true;
      case 'guardian': return true;
      case 'scout': return false;
      case 'knight': return false;
      default: return false;
    }
  }

  double _getUnitRadius(String unitType) {
    switch (unitType) {
      case 'minor': return 15.0;
      case 'scout': return 18.0;
      case 'knight': return 22.0;
      case 'guardian': return 20.0;
      default: return 15.0;
    }
  }

  Color _getUnitColor(Color baseColor, String unitType) {
    switch (unitType) {
      case 'minor': return baseColor.withOpacity(0.7);
      case 'scout': return baseColor.withOpacity(0.9);
      case 'knight': return baseColor;
      case 'guardian': return baseColor.withOpacity(0.8);
      default: return baseColor.withOpacity(0.7);
    }
  }

  void _drawSimpleHealthIndicator(Canvas canvas, Offset center, int health, int maxHealth, double radius) {
    if (health >= maxHealth) return;

    final barWidth = radius * 1.5;
    final barHeight = 3.0;
    final barY = center.dy - radius - 8;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, barWidth, barHeight),
      Paint()..color = Colors.grey.shade700,
    );

    // Health
    final healthPercent = health / maxHealth;
    final healthWidth = barWidth * healthPercent;

    canvas.drawRect(
      Rect.fromLTWH(center.dx - barWidth / 2, barY, healthWidth, barHeight),
      Paint()..color = Colors.green.shade600,
    );
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

    // Draw health indicators as circles (matching scenario builder display)
    if (health.currentHealth > 1) {
      _drawHealthIndicators(canvas, center, health.currentHealth);
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

    // Draw health indicators as circles (matching scenario builder display)
    if (unit.health > 1) {
      _drawHealthIndicators(canvas, center, unit.health);
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

  /// Draw health indicators as small circles below the unit (matching scenario builder)
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
    final dotY = center.dy + engine.hexSize * 0.6;

    for (int i = 0; i < health; i++) {
      final dotX = startX + (i * spacing);
      final dotCenter = Offset(dotX, dotY);

      canvas.drawCircle(dotCenter, dotRadius, healthPaint);
      canvas.drawCircle(dotCenter, dotRadius, healthStrokePaint);
    }
  }

  void _drawStructures(Canvas canvas, Size size, ChexxGameState gameState) {
    // Access structures from game state
    for (final placedStructure in gameState.placedStructures) {
      final center = engine.hexToScreen(placedStructure.position, size);
      final structureSize = engine.hexSize * 0.9;

      // Get structure color based on type
      final Color structureColor = _getStructureColor(placedStructure.type);

      // Create paints for structure rendering
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = structureColor;

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = structureColor.withOpacity(0.8)
        ..strokeWidth = 2.0;

      // Draw structure shape based on type (same as scenario builder)
      switch (placedStructure.type) {
        case StructureType.bunker:
          // Draw bunker as a square
          final rect = Rect.fromCenter(center: center, width: structureSize, height: structureSize);
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, strokePaint);
          break;
        case StructureType.bridge:
          // Draw bridge as a rounded rectangle
          final rect = Rect.fromCenter(center: center, width: structureSize * 1.2, height: structureSize * 0.6);
          final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
          canvas.drawRRect(rrect, fillPaint);
          canvas.drawRRect(rrect, strokePaint);
          break;
        case StructureType.sandbag:
          // Draw sandbag as multiple small circles
          final radius = structureSize * 0.15;
          for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 2; j++) {
              final offset = Offset(center.dx + (i - 1) * radius * 1.5, center.dy + (j - 0.5) * radius * 1.5);
              canvas.drawCircle(offset, radius, fillPaint);
              canvas.drawCircle(offset, radius, strokePaint);
            }
          }
          break;
        case StructureType.barbwire:
          // Draw barbwire as zigzag lines
          final path = Path();
          final startX = center.dx - structureSize * 0.4;
          final endX = center.dx + structureSize * 0.4;
          final y = center.dy;
          path.moveTo(startX, y);
          for (double x = startX; x < endX; x += structureSize * 0.1) {
            final isUp = ((x - startX) / (structureSize * 0.1)).round() % 2 == 0;
            path.lineTo(x, y + (isUp ? -structureSize * 0.1 : structureSize * 0.1));
          }
          path.lineTo(endX, y);
          canvas.drawPath(path, strokePaint);
          break;
        case StructureType.dragonsTeeth:
          // Draw dragon's teeth as triangles
          final path = Path();
          for (int i = 0; i < 3; i++) {
            final x = center.dx + (i - 1) * structureSize * 0.3;
            path.moveTo(x, center.dy + structureSize * 0.2);
            path.lineTo(x - structureSize * 0.1, center.dy - structureSize * 0.2);
            path.lineTo(x + structureSize * 0.1, center.dy - structureSize * 0.2);
            path.close();
          }
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, strokePaint);
          break;
      }

      // Draw structure symbol (same as scenario builder)
      final symbol = _getStructureSymbol(placedStructure.type);
      final textPainter = TextPainter(
        text: TextSpan(
          text: symbol,
          style: TextStyle(
            color: Colors.white,
            fontSize: engine.hexSize * 0.4,
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

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
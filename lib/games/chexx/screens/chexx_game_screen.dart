import 'package:flutter/material.dart';
import '../../../core/engine/game_engine_base.dart';
import '../../../core/models/hex_coordinate.dart';
import '../../../core/interfaces/unit_factory.dart';
import '../chexx_plugin.dart';
import '../models/chexx_game_state.dart';
import 'chexx_game_engine.dart';

/// CHEXX game screen implementation
class ChexxGameScreen extends StatefulWidget {
  final Map<String, dynamic>? scenarioConfig;
  final ChexxPlugin? gamePlugin;

  const ChexxGameScreen({super.key, this.scenarioConfig, this.gamePlugin});

  @override
  State<ChexxGameScreen> createState() => _ChexxGameScreenState();
}

class _ChexxGameScreenState extends State<ChexxGameScreen> {
  late ChexxGameEngine gameEngine;

  @override
  void initState() {
    super.initState();
    gameEngine = ChexxGameEngine(
      gamePlugin: widget.gamePlugin ?? ChexxPlugin(),
      scenarioConfig: widget.scenarioConfig,
    );
    gameEngine.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    gameEngine.removeListener(_onGameStateChanged);
    gameEngine.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Game canvas
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (details) => _handleTap(details.globalPosition),
                child: CustomPaint(
                  painter: ChexxGamePainter(gameEngine),
                  size: Size.infinite,
                ),
              ),
            ),

            // Game UI overlay
            Positioned.fill(
              child: _buildGameUI(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(Offset position) {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    gameEngine.handleTap(position, size);
  }

  Widget _buildGameUI() {
    final gameState = gameEngine.gameState as ChexxGameState;

    return Stack(
      children: [
        // Top UI
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildTopUI(gameState),
        ),

        // Bottom UI
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _buildBottomUI(gameState),
        ),

        // Right side unit info panel
        if (_getSelectedUnit(gameState) != null)
          Positioned(
            top: 80,
            right: 16,
            child: _buildUnitInfoPanel(_getSelectedUnit(gameState)!),
          ),
      ],
    );
  }

  Widget _buildTopUI(ChexxGameState gameState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Current player indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: gameState.currentPlayer.name == 'player1'
                ? Colors.blue.shade600
                : Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${gameState.currentPlayer.name == 'player1' ? 'Player 1' : 'Player 2'} Turn',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),

        // Turn counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Turn ${gameState.turnNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomUI(ChexxGameState gameState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // End turn button
        ElevatedButton(
          onPressed: () => gameEngine.endTurn(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('End Turn'),
        ),

        // Reset game button
        ElevatedButton(
          onPressed: () => gameEngine.resetGame(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reset'),
        ),

        // Back button
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Menu'),
        ),
      ],
    );
  }

  SimpleGameUnit? _getSelectedUnit(ChexxGameState gameState) {
    for (final unit in gameState.simpleUnits) {
      if (unit.isSelected) {
        return unit;
      }
    }
    return null;
  }

  Widget _buildUnitInfoPanel(SimpleGameUnit unit) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unit.owner == Player.player1
            ? Colors.blue.shade900.withOpacity(0.9)
            : Colors.red.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unit.owner == Player.player1
              ? Colors.blue.shade400
              : Colors.red.shade400,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit Info',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Unit type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: unit.owner == Player.player1
                  ? Colors.blue.shade600
                  : Colors.red.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getUnitTypeName(unit.unitType),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Unit stats
          _buildStatRow('Health', '${unit.health}/${unit.maxHealth}', Icons.favorite),
          _buildStatRow('Movement', '${_getMovementRange(unit.unitType)}', Icons.directions_run),
          _buildStatRow('Attack Range', '${_getAttackRange(unit.unitType)}', Icons.gps_fixed),
          _buildStatRow('Attack Damage', '${_getAttackDamage(unit.unitType)}', Icons.flash_on),

          const SizedBox(height: 8),

          // Abilities section
          Text(
            'Abilities',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          ..._buildUnitAbilities(unit.unitType),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getUnitTypeName(String unitType) {
    switch (unitType) {
      case 'minor': return 'Minor Unit';
      case 'scout': return 'Scout';
      case 'knight': return 'Knight';
      case 'guardian': return 'Guardian';
      default: return 'Unknown';
    }
  }

  int _getMovementRange(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  int _getAttackRange(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  int _getAttackDamage(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 1;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  List<Widget> _buildUnitAbilities(String unitType) {
    switch (unitType) {
      case 'scout':
        return [
          _buildAbilityCard('Long Range', 'Attack range +2'),
        ];
      case 'knight':
        return [
          _buildAbilityCard('Heavy Attack', 'Deals 2 damage'),
        ];
      case 'guardian':
        return [
          _buildAbilityCard('Defensive', 'High health unit'),
        ];
      case 'minor':
      default:
        return [
          _buildAbilityCard('Basic Unit', 'Standard combat'),
        ];
    }
  }

  Widget _buildAbilityCard(String name, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
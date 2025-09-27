import 'package:flutter/material.dart';
import '../../../core/engine/game_engine_base.dart';
import '../../../core/models/hex_coordinate.dart';
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
}
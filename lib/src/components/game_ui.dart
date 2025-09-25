import 'package:flutter/material.dart';
import '../systems/chexx_game.dart';
import '../models/game_state.dart';
import '../models/game_unit.dart';

/// Game UI overlay with turn timer, player info, and controls
class GameUI extends StatefulWidget {
  final ChexxGame game;

  const GameUI({super.key, required this.game});

  @override
  State<GameUI> createState() => _GameUIState();
}

class _GameUIState extends State<GameUI> with TickerProviderStateMixin {
  late AnimationController _timerAnimationController;
  late AnimationController _rewardAnimationController;

  @override
  void initState() {
    super.initState();

    _timerAnimationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    _rewardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Listen to game state changes
    widget.game.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    _timerAnimationController.dispose();
    _rewardAnimationController.dispose();
    widget.game.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (mounted) {
      setState(() {
        // Update timer animation
        final progress = 1.0 - (widget.game.gameState.turnTimeRemaining / 6.0);
        _timerAnimationController.animateTo(progress);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameState>(
      stream: widget.game.gameStateStream,
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? widget.game.gameState;

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

            // Center messages
            if (gameState.gamePhase == GamePhase.gameOver)
              Positioned.fill(
                child: _buildGameOverOverlay(gameState),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopUI(GameState gameState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Current player indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: gameState.currentPlayer == Player.player1
                ? Colors.blue.shade600
                : Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${gameState.currentPlayer == Player.player1 ? 'Player 1' : 'Player 2'} Turn',
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

        // Pause button
        IconButton(
          onPressed: () => widget.game.gameState.togglePause(),
          icon: Icon(
            gameState.isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.white,
            size: 28,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            shape: const CircleBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomUI(GameState gameState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Turn timer
        _buildTurnTimer(gameState),
        const SizedBox(height: 16),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Skip action button
            if (gameState.turnPhase == TurnPhase.acting)
              _buildActionButton(
                label: 'Skip Action',
                onPressed: () => widget.game.gameState.skipAction(),
                color: Colors.orange.shade600,
              ),

            // End turn button
            _buildActionButton(
              label: 'End Turn',
              onPressed: () => widget.game.gameState.endTurn(),
              color: Colors.grey.shade600,
            ),

            // Reset game button
            _buildActionButton(
              label: 'Reset',
              onPressed: () => widget.game.gameState.resetGame(),
              color: Colors.red.shade600,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Reward progress bars
        _buildRewardBars(gameState),
      ],
    );
  }

  Widget _buildTurnTimer(GameState gameState) {
    final timeRemaining = gameState.turnTimeRemaining;
    final isLowTime = timeRemaining <= 2.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowTime ? Colors.red.shade400 : Colors.white24,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Time Remaining',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          // Timer display
          Text(
            '${timeRemaining.toStringAsFixed(1)}s',
            style: TextStyle(
              color: isLowTime ? Colors.red.shade400 : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Timer progress bar
          LinearProgressIndicator(
            value: timeRemaining / 6.0,
            backgroundColor: Colors.grey.shade700,
            valueColor: AlwaysStoppedAnimation<Color>(
              isLowTime ? Colors.red.shade400 : Colors.blue.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRewardBars(GameState gameState) {
    return Row(
      children: [
        // Player 1 rewards
        Expanded(
          child: _buildRewardBar(
            label: 'Player 1',
            progress: gameState.player1Rewards / 61.0,
            color: Colors.blue.shade600,
            value: gameState.player1Rewards,
          ),
        ),
        const SizedBox(width: 16),

        // Player 2 rewards
        Expanded(
          child: _buildRewardBar(
            label: 'Player 2',
            progress: gameState.player2Rewards / 61.0,
            color: Colors.red.shade600,
            value: gameState.player2Rewards,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardBar({
    required String label,
    required double progress,
    required Color color,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            '$value / 61',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay(GameState gameState) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 64,
                color: Colors.amber,
              ),
              const SizedBox(height: 16),

              Text(
                'Game Over!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (gameState.winner != null) ...[
                Text(
                  '${gameState.winner == Player.player1 ? 'Player 1' : 'Player 2'} Wins!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: gameState.winner == Player.player1
                        ? Colors.blue.shade600
                        : Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Text(
                  'Draw!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => widget.game.gameState.resetGame(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Play Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
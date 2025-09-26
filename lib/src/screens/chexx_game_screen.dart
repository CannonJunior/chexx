import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/game_unit.dart';
import '../models/meta_ability.dart';

/// Main game screen using custom game engine
class ChexxGameScreen extends StatefulWidget {
  final Map<String, dynamic>? scenarioConfig;

  const ChexxGameScreen({super.key, this.scenarioConfig});

  @override
  State<ChexxGameScreen> createState() => _ChexxGameScreenState();
}

class _ChexxGameScreenState extends State<ChexxGameScreen>
    with TickerProviderStateMixin {
  late ChexxGameEngine gameEngine;
  late AnimationController _timerAnimationController;

  @override
  void initState() {
    super.initState();
    gameEngine = ChexxGameEngine(scenarioConfig: widget.scenarioConfig);

    _timerAnimationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    // Listen to game state changes
    gameEngine.addListener(_onGameStateChanged);
  }

  @override
  void dispose() {
    _timerAnimationController.dispose();
    gameEngine.removeListener(_onGameStateChanged);
    gameEngine.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (mounted) {
      setState(() {
        // Update timer animation
        final progress = 1.0 - (gameEngine.gameState.turnTimeRemaining / 6.0);
        _timerAnimationController.animateTo(progress);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey.keyLabel.toLowerCase();
            gameEngine.handleKeyboardInput(key);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Game canvas
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: (details) => _handleTap(details.globalPosition),
                  onPanUpdate: (details) => _handleHover(details.globalPosition),
                  child: CustomPaint(
                    painter: ChexxGamePainter(gameEngine, null),
                    size: Size.infinite,
                  ),
                ),
              ),

              // Game UI overlay
              Positioned.fill(
                child: _buildGameUI(),
              ),

              // Keyboard controls help
              Positioned(
                bottom: 16,
                left: 16,
                child: _buildKeyboardHelp(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset position) {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    gameEngine.handleTap(position, size);
  }

  void _handleHover(Offset position) {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    gameEngine.handleHover(position, size);
  }

  Widget _buildGameUI() {
    return AnimatedBuilder(
      animation: gameEngine,
      builder: (context, child) {
        final gameState = gameEngine.gameState;

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

            // Unit abilities panel
            if (gameState.selectedUnit != null)
              Positioned(
                top: 80,
                right: 16,
                child: _buildUnitAbilitiesPanel(gameState),
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
          onPressed: () => gameEngine.togglePause(),
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
                onPressed: () => gameEngine.skipAction(),
                color: Colors.orange.shade600,
              ),

            // End turn button
            _buildActionButton(
              label: 'End Turn',
              onPressed: () => gameEngine.endTurn(),
              color: Colors.grey.shade600,
            ),

            // Reset game button
            _buildActionButton(
              label: 'Reset',
              onPressed: () => gameEngine.resetGame(),
              color: Colors.red.shade600,
            ),

            // Back button
            _buildActionButton(
              label: 'Menu',
              onPressed: () => Navigator.of(context).pop(),
              color: Colors.blue.shade600,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Reward progress bars
        _buildRewardBars(gameState),

        const SizedBox(height: 8),

        // Active effects display
        if (gameState.activeMetaEffects.isNotEmpty)
          _buildActiveEffectsPanel(gameState),
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
          const Text(
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
                  color: Colors.black,
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
                onPressed: () => gameEngine.resetGame(),
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

  Widget _buildUnitAbilitiesPanel(GameState gameState) {
    final selectedUnit = gameState.selectedUnit!;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selectedUnit.owner == Player.player1
            ? Colors.blue.shade900.withOpacity(0.9)
            : Colors.red.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedUnit.owner == Player.player1
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
            'Abilities',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Unit type and stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selectedUnit.owner == Player.player1
                  ? Colors.blue.shade600
                  : Colors.red.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_getUnitTypeName(selectedUnit.type)} (Lv.${selectedUnit.level})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Unit stats
          _buildUnitStatItem('Health', '${selectedUnit.currentHealth}/${selectedUnit.maxHealth}', Icons.favorite),
          _buildUnitStatItem('Movement', '${selectedUnit.effectiveMovementRange}', Icons.directions_run),
          _buildUnitStatItem('Attack Range', '${selectedUnit.attackRange}', Icons.gps_fixed),
          _buildUnitStatItem('Attack Damage', '${selectedUnit.effectiveAttackDamage}', Icons.flash_on),

          const SizedBox(height: 8),

          // Special abilities
          Text(
            'Special Abilities:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),

          ..._getUnitAbilities(selectedUnit),

          const SizedBox(height: 8),

          Text(
            _getMovementDescription(selectedUnit.type),
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbilityItem(MetaAbility ability, bool isAvailable) {
    final cooldownTime = gameEngine.gameState.selectedMetaHex!.cooldowns[ability.type] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade800.withOpacity(0.3) : Colors.grey.shade800.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAvailable ? Colors.green.shade400 : Colors.grey.shade600,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getAbilityName(ability.type),
                style: TextStyle(
                  color: isAvailable ? Colors.green.shade300 : Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isAvailable)
                Text(
                  '${cooldownTime}T',
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            ability.description,
            style: TextStyle(
              color: isAvailable ? Colors.white70 : Colors.grey.shade500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _getUnitTypeName(UnitType type) {
    switch (type) {
      case UnitType.minor:
        return 'Minor Unit';
      case UnitType.scout:
        return 'Scout';
      case UnitType.knight:
        return 'Knight';
      case UnitType.guardian:
        return 'Guardian';
    }
  }

  Widget _buildUnitStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getUnitAbilities(GameUnit unit) {
    final abilities = <Widget>[];

    switch (unit.type) {
      case UnitType.minor:
        abilities.add(_buildAbilityDescription('No special abilities', 'Basic combat unit'));
        break;
      case UnitType.scout:
        abilities.add(_buildAbilityDescription(
          'Long Range Scan',
          'Reveals enemy positions',
          isAvailable: unit.canUseSpecialAbility('long_range_scan'),
        ));
        break;
      case UnitType.knight:
        abilities.add(_buildAbilityDescription('No special abilities', 'High damage combat unit'));
        break;
      case UnitType.guardian:
        abilities.add(_buildAbilityDescription(
          'Swap Position',
          'Switch places with friendly unit',
          isAvailable: unit.canUseSpecialAbility('swap'),
        ));
        break;
    }

    return abilities;
  }

  Widget _buildAbilityDescription(String name, String description, {bool isAvailable = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.white10 : Colors.grey.shade800.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAvailable ? Colors.white30 : Colors.grey.shade600,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: isAvailable ? Colors.white : Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              color: isAvailable ? Colors.white70 : Colors.grey.shade500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _getMovementDescription(UnitType type) {
    switch (type) {
      case UnitType.minor:
        return 'Can move to any adjacent hex';
      case UnitType.scout:
        return 'Moves in straight lines only';
      case UnitType.knight:
        return 'Moves in L-shaped patterns';
      case UnitType.guardian:
        return 'Can move to any adjacent hex';
    }
  }

  Widget _buildActiveEffectsPanel(GameState gameState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade400, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Active Effects',
            style: TextStyle(
              color: Colors.indigo.shade200,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: gameState.activeMetaEffects.map((effect) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getEffectColor(effect.type).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getEffectColor(effect.type), width: 1),
                ),
                child: Text(
                  '${_getEffectName(effect.type)} (${effect.remainingTurns}T)',
                  style: TextStyle(
                    color: _getEffectColor(effect.type),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getEffectColor(MetaAbilityType type) {
    switch (type) {
      case MetaAbilityType.spawn:
        return Colors.green.shade400;
      case MetaAbilityType.heal:
        return Colors.cyan.shade400;
      case MetaAbilityType.shield:
        return Colors.amber.shade400;
    }
  }

  String _getEffectName(MetaAbilityType type) {
    switch (type) {
      case MetaAbilityType.spawn:
        return 'Spawn Boost';
      case MetaAbilityType.heal:
        return 'Regeneration';
      case MetaAbilityType.shield:
        return 'Shield';
    }
  }

  String _getAbilityName(MetaAbilityType type) {
    switch (type) {
      case MetaAbilityType.spawn:
        return 'Spawn Unit';
      case MetaAbilityType.heal:
        return 'Heal';
      case MetaAbilityType.shield:
        return 'Shield';
    }
  }

  Widget _buildKeyboardHelp() {
    return AnimatedBuilder(
      animation: gameEngine,
      builder: (context, child) {
        final gameState = gameEngine.gameState;

        // Only show keyboard help when a unit is selected and can move
        if (gameState.selectedUnit == null || gameState.turnPhase != TurnPhase.moving) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black87.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Keyboard Movement (${gameState.remainingMoves} moves left)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              _buildKeyboardGrid(),

              const SizedBox(height: 4),
              Text(
                'Click to select units • Mouse still works',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeyboardGrid() {
    return Column(
      children: [
        // Top row: Q W E
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKeyIndicator('Q', '10°'),
            const SizedBox(width: 2),
            _buildKeyIndicator('W', '12°'),
            const SizedBox(width: 2),
            _buildKeyIndicator('E', '2°'),
          ],
        ),
        const SizedBox(height: 2),
        // Bottom row: A S D
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKeyIndicator('A', '8°'),
            const SizedBox(width: 2),
            _buildKeyIndicator('S', '6°'),
            const SizedBox(width: 2),
            _buildKeyIndicator('D', '4°'),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyIndicator(String key, String direction) {
    return Container(
      width: 20,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white30, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            key,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            direction,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 6,
            ),
          ),
        ],
      ),
    );
  }
}
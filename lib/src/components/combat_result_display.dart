import 'package:flutter/material.dart';
import '../systems/combat/wwii_combat_system.dart';
import '../systems/combat/die_faces_config.dart';

/// Widget to display individual die roll results for WWII combat
class CombatResultDisplay extends StatefulWidget {
  final CombatResult combatResult;
  final VoidCallback? onDismiss;

  const CombatResultDisplay({
    super.key,
    required this.combatResult,
    this.onDismiss,
  });

  @override
  State<CombatResultDisplay> createState() => _CombatResultDisplayState();
}

class _CombatResultDisplayState extends State<CombatResultDisplay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _fadeController.reverse();
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildCombatResultCard(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCombatResultCard() {
    return Card(
      elevation: 8,
      color: Colors.grey.shade900,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildDiceGrid(),
            const SizedBox(height: 16),
            _buildSummary(),
            const SizedBox(height: 20),
            _buildDismissButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Combat Result',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.combatResult.attacker.unitTypeId} vs ${widget.combatResult.defender.unitTypeId}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildDiceGrid() {
    final diceResults = widget.combatResult.dieRolls;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Die Rolls (${diceResults.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: diceResults.map((result) => _buildDieResult(result)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDieResult(DieRollResult result) {
    Color backgroundColor;
    Color borderColor;
    Color textColor = Colors.white;

    switch (result.hitResult) {
      case CombatHitResult.hit:
        backgroundColor = Colors.green.shade700;
        borderColor = Colors.green.shade400;
        break;
      case CombatHitResult.miss:
        backgroundColor = Colors.grey.shade600;
        borderColor = Colors.grey.shade400;
        break;
      case CombatHitResult.retreat:
        backgroundColor = Colors.orange.shade700;
        borderColor = Colors.orange.shade400;
        break;
      case CombatHitResult.cardAction:
        backgroundColor = Colors.purple.shade700;
        borderColor = Colors.purple.shade400;
        break;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            result.face.symbol,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (result.hitResult != CombatHitResult.miss)
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final result = widget.combatResult;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Hits', '${result.hitCount}', Colors.green.shade400),
          _buildSummaryRow('Misses', '${result.missCount}', Colors.grey.shade400),
          if (result.retreatCount > 0)
            _buildSummaryRow('Retreats', '${result.retreatCount}', Colors.orange.shade400),
          if (result.cardActionCount > 0)
            _buildSummaryRow('Card Actions', '${result.cardActionCount}', Colors.purple.shade400),
          const Divider(color: Colors.grey),
          _buildSummaryRow('Total Damage', '${result.totalDamage}', Colors.red.shade400),
          if (result.defenderDestroyed)
            _buildSummaryRow('Result', 'Unit Destroyed', Colors.red.shade600),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade300),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _dismiss,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('Continue'),
      ),
    );
  }
}

/// Overlay manager for displaying combat results
class CombatResultOverlay {
  static OverlayEntry? _currentOverlay;

  static void show(BuildContext context, CombatResult combatResult) {
    // Remove any existing overlay
    dismiss();

    _currentOverlay = OverlayEntry(
      builder: (context) => CombatResultDisplay(
        combatResult: combatResult,
        onDismiss: dismiss,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}
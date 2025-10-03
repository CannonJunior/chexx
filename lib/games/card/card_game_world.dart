import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'card_plugin.dart';
import 'card_game_state_adapter.dart';

/// Flame game world for card game (minimal - just background for now)
class CardGameWorld extends FlameGame {
  final CardGameStateAdapter gameState;
  final CardPlugin gamePlugin;

  CardGameWorld({
    required this.gameState,
    required this.gamePlugin,
  });

  @override
  Color backgroundColor() => Colors.grey.shade800;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // TODO: Add visual elements for game board, units, etc.
    // For now, this is just a background
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Game logic updates handled by f-card engine
  }
}

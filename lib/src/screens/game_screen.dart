import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../systems/chexx_game.dart';
import '../models/game_state.dart';
import '../components/game_ui.dart';

/// Main game screen that hosts the Flame game and UI
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ChexxGame game;

  @override
  void initState() {
    super.initState();
    game = ChexxGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Game view
            Positioned.fill(
              child: GameWidget<ChexxGame>.controlled(gameFactory: () => game),
            ),

            // Game UI overlay
            Positioned.fill(
              child: GameUI(game: game),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    game.onDispose();
    super.dispose();
  }
}
/// Example usage patterns for f-card engine integration
///
/// This file demonstrates how to interact with the card game system
/// from within the Chexx project.

import 'package:flutter/material.dart';
import 'package:f_card_engine/f_card_engine.dart';
import '../../core/engine/game_plugin_manager.dart';
import 'card_plugin.dart';
import 'card_game_state_adapter.dart';

/// Example 1: Accessing game state from anywhere in the app
void exampleAccessGameState() {
  // Get the plugin manager
  final pluginManager = GamePluginManager();

  // Get the card plugin
  final cardPlugin = pluginManager.getPlugin('card') as CardPlugin?;

  if (cardPlugin != null) {
    // Create or get game state
    final gameState = cardPlugin.createGameState() as CardGameStateAdapter;

    // Access current game information
    print('Current Player: ${gameState.currentPlayer}');
    print('Player Life: ${gameState.playerLife}');
    print('Current Phase: ${gameState.currentPhase}');
    print('Game Over: ${gameState.isGameOver}');

    if (gameState.isGameOver && gameState.winner != null) {
      print('Winner: Player ${gameState.winner}');
    }
  }
}

/// Example 2: Reading the event log
void exampleReadEventLog() {
  final pluginManager = GamePluginManager();
  final cardPlugin = pluginManager.getPlugin('card') as CardPlugin?;

  if (cardPlugin != null) {
    final gameState = cardPlugin.createGameState() as CardGameStateAdapter;

    // Get all events
    final allEvents = gameState.eventLog;
    print('Total events: ${allEvents.length}');

    // Get recent events (last 10)
    final recentEvents = allEvents.reversed.take(10).toList();
    for (var event in recentEvents) {
      print('${event.timestamp}: ${event.type} - ${event.description}');
    }

    // Filter by event type
    final cardPlayEvents = allEvents.where((e) => e.type == 'play_card').toList();
    print('Cards played: ${cardPlayEvents.length}');

    final attackEvents = allEvents.where((e) => e.type == 'attack').toList();
    print('Attacks: ${attackEvents.length}');

    final drawEvents = allEvents.where((e) => e.type == 'draw').toList();
    print('Card draws: ${drawEvents.length}');
  }
}

/// Example 3: Playing cards programmatically
Future<void> examplePlayCard() async {
  final pluginManager = GamePluginManager();
  final cardPlugin = pluginManager.getPlugin('card') as CardPlugin?;

  if (cardPlugin != null) {
    final gameState = cardPlugin.createGameState() as CardGameStateAdapter;

    // Get current player's hand
    final currentPlayer = gameState.currentPlayer;
    final hand = gameState.playerHands[currentPlayer] ?? [];

    if (hand.isNotEmpty) {
      // Play the first card in hand
      final cardToPlay = hand.first;

      // Play without target
      bool success = await gameState.playCard(currentPlayer, cardToPlay);
      print('Card played successfully: $success');

      // Or play with target (if card requires targeting)
      // bool success = await gameState.playCard(currentPlayer, cardToPlay, target: targetCard);
    }
  }
}

/// Example 4: Combat
Future<void> exampleCombat() async {
  final pluginManager = GamePluginManager();
  final cardPlugin = pluginManager.getPlugin('card') as CardPlugin?;

  if (cardPlugin != null) {
    final gameState = cardPlugin.createGameState() as CardGameStateAdapter;

    // Get battlefield zone
    final battlefield = gameState.zones['battlefield'];

    if (battlefield != null && battlefield.cards.isNotEmpty) {
      final attacker = battlefield.cards.first;

      // Declare attacker (unblocked)
      bool success = await gameState.declareAttacker(attacker);
      print('Attack declared: $success');

      // Or with blocker
      // final blocker = battlefield.cards.last;
      // bool success = await gameState.declareAttacker(attacker, blocker: blocker);
    }
  }
}

/// Example 5: Direct f-card engine access (headless mode)
Future<void> exampleHeadlessMode() async {
  final pluginManager = GamePluginManager();
  final cardPlugin = pluginManager.getPlugin('card') as CardPlugin?;

  if (cardPlugin != null) {
    // Get direct access to f-card engine components
    final engine = cardPlugin.cardGameStateManager;
    final deckManager = cardPlugin.deckManager;

    // Start a new game
    await engine.startGame([1, 2]);

    // Draw initial hands
    await engine.drawCards(1, 5);
    await engine.drawCards(2, 5);

    // Access all zones
    final battlefield = engine.zones['battlefield'];
    final graveyard = engine.zones['graveyard'];
    final exile = engine.zones['exile'];

    print('Battlefield cards: ${battlefield?.cards.length ?? 0}');
    print('Graveyard cards: ${graveyard?.cards.length ?? 0}');

    // Programmatically control the game
    // This is useful for AI, simulations, or testing
  }
}

/// Example 6: Widget that displays event log
class EventLogWidget extends StatelessWidget {
  final CardGameStateAdapter gameState;

  const EventLogWidget({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Log',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: gameState.eventLog.length,
              reverse: true, // Show newest first
              itemBuilder: (context, index) {
                final event = gameState.eventLog.reversed.elementAt(index);
                return ListTile(
                  dense: true,
                  leading: _getEventIcon(event.type),
                  title: Text(event.description),
                  subtitle: Text(
                    'Player ${event.playerId} - ${event.timestamp}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Icon _getEventIcon(String eventType) {
    switch (eventType) {
      case 'play_card':
        return const Icon(Icons.add_card, color: Colors.blue);
      case 'attack':
        return const Icon(Icons.whatshot, color: Colors.red);
      case 'draw':
        return const Icon(Icons.arrow_downward, color: Colors.green);
      case 'ability':
        return const Icon(Icons.auto_awesome, color: Colors.purple);
      default:
        return const Icon(Icons.circle, color: Colors.grey);
    }
  }
}

/// Example 7: Widget that displays game state
class GameStateWidget extends StatelessWidget {
  final CardGameStateAdapter gameState;

  const GameStateWidget({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Player: ${gameState.currentPlayer}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Phase: ${gameState.currentPhase}'),
          const SizedBox(height: 8),
          const Text('Life Totals:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...gameState.playerLife.entries.map(
            (e) => Text('  Player ${e.key}: ${e.value}'),
          ),
          const SizedBox(height: 8),
          const Text('Hand Sizes:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...gameState.playerHands.entries.map(
            (e) => Text('  Player ${e.key}: ${e.value.length} cards'),
          ),
          if (gameState.isGameOver) ...[
            const SizedBox(height: 16),
            Text(
              'Game Over - Winner: Player ${gameState.winner}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Example 8: Monitoring game state changes
class GameStateMonitor extends StatefulWidget {
  final CardPlugin plugin;
  final Function(GameEvent) onEvent;

  const GameStateMonitor({
    super.key,
    required this.plugin,
    required this.onEvent,
  });

  @override
  State<GameStateMonitor> createState() => _GameStateMonitorState();
}

class _GameStateMonitorState extends State<GameStateMonitor> {
  late CardGameStateAdapter gameState;
  int lastEventCount = 0;

  @override
  void initState() {
    super.initState();
    gameState = widget.plugin.createGameState() as CardGameStateAdapter;
    _startMonitoring();
  }

  void _startMonitoring() {
    // Check for new events periodically
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return false;

      final currentEventCount = gameState.eventLog.length;
      if (currentEventCount > lastEventCount) {
        // New events detected
        final newEvents = gameState.eventLog.sublist(lastEventCount);
        for (var event in newEvents) {
          widget.onEvent(event);
        }
        lastEventCount = currentEventCount;
      }

      return mounted; // Continue while widget is mounted
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Invisible monitoring widget
  }
}

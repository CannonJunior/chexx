import 'package:flutter/material.dart';
import '../chexx/screens/chexx_game_screen.dart';
import '../chexx/chexx_plugin.dart';
import 'card_plugin.dart';
import 'card_game_state_adapter.dart';

/// Card game screen - Chexx game board with card UI overlay
class CardGameScreen extends StatefulWidget {
  final CardPlugin gamePlugin;
  final Map<String, dynamic>? scenarioConfig;

  const CardGameScreen({
    super.key,
    required this.gamePlugin,
    this.scenarioConfig,
  });

  @override
  State<CardGameScreen> createState() => _CardGameScreenState();
}

class _CardGameScreenState extends State<CardGameScreen> {
  late CardGameStateAdapter cardGameState;

  @override
  void initState() {
    super.initState();
    print('=== CARD GAME SCREEN INIT ===');
    cardGameState = widget.gamePlugin.createGameState() as CardGameStateAdapter;

    // Initialize from scenario if provided, otherwise use defaults
    if (widget.scenarioConfig != null) {
      print('Initializing card game from scenario');
      cardGameState.initializeFromScenario(widget.scenarioConfig!);
    } else {
      print('No scenario config - starting with defaults');
      cardGameState.startGame(initialHandSize: 5);
    }

    print('Game started: ${cardGameState.gameStarted}');
    print('Players: ${cardGameState.players.length}');
    print('Current player: ${cardGameState.cardCurrentPlayer?.name}');
    print('Deck remaining: ${widget.gamePlugin.deckManager.cardsRemaining}');

    if (cardGameState.cardCurrentPlayer != null) {
      print('Current player hand: ${cardGameState.cardCurrentPlayer!.hand.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the regular Chexx game screen as the base
    // We use ChexxPlugin for the board, but add card UI on top
    return Stack(
      children: [
        // Chexx game board (same as other game modes)
        ChexxGameScreen(
          scenarioConfig: widget.scenarioConfig,
          gamePlugin: ChexxPlugin(), // Use Chexx board
        ),

        // Card UI overlay on top
        SafeArea(
          child: Column(
            children: [
              // Top bar with card-specific info
              _buildCardInfoBar(),

              const Spacer(),

              // Bottom bar with player hand
              _buildCardHandBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardInfoBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(color: Colors.purple.shade700, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Deck counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.shade800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade400),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.style, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${widget.gamePlugin.deckManager.cardsRemaining}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Event log button
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: _showEventLog,
            tooltip: 'Event Log',
          ),
        ],
      ),
    );
  }

  Widget _buildCardHandBar() {
    final currentPlayer = cardGameState.cardCurrentPlayer;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: Colors.purple.shade700, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Player info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentPlayer?.name ?? 'No player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${currentPlayer?.hand.length ?? 0} cards',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Cards
          Expanded(
            child: _buildPlayerHand(),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ElevatedButton.icon(
              onPressed: _endTurn,
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('END TURN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerHand() {
    final currentPlayer = cardGameState.cardCurrentPlayer;

    if (currentPlayer == null || currentPlayer.hand.isEmpty) {
      return const Center(
        child: Text(
          'No cards in hand',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: currentPlayer.hand.length,
      itemBuilder: (context, index) {
        final card = currentPlayer.hand[index];
        return _buildCardWidget(card);
      },
    );
  }

  Widget _buildCardWidget(dynamic card) {
    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.purple.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade400, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onCardTapped(card),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.style,
                  color: Colors.purple.shade200,
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  card.card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  card.card.type,
                  style: TextStyle(
                    color: Colors.purple.shade200,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onCardTapped(dynamic card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          card.card.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${card.card.type}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              card.card.description ?? 'No description',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _playCard(card);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
            ),
            child: const Text('Play Card'),
          ),
        ],
      ),
    );
  }

  void _playCard(dynamic card) {
    cardGameState.playCard(card);
    setState(() {});
  }

  void _endTurn() {
    final success = cardGameState.cardGameState.endTurn();
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Must play a card before ending turn'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      setState(() {});
    }
  }

  void _showEventLog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Event Log',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          height: 500,
          child: cardGameState.eventLog.isEmpty
              ? const Center(
                  child: Text(
                    'No events yet',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.builder(
                  itemCount: cardGameState.eventLog.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final event = cardGameState.eventLog.reversed.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: _getEventIcon(event['type'] as String),
                      title: Text(
                        event['type'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        event['timestamp'] as String,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Icon _getEventIcon(String eventType) {
    switch (eventType) {
      case 'card_played':
        return const Icon(Icons.add_card, color: Colors.blue);
      case 'cards_drawn':
        return const Icon(Icons.arrow_downward, color: Colors.green);
      case 'turn_ended':
        return const Icon(Icons.refresh, color: Colors.orange);
      case 'game_started':
        return const Icon(Icons.play_arrow, color: Colors.green);
      default:
        return const Icon(Icons.circle, color: Colors.grey);
    }
  }
}

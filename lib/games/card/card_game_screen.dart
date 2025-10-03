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
  dynamic selectedCard; // Track selected card for info panel

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

        // Card UI overlay on top - positioned to not obscure game controls
        // Wrap in IgnorePointer with absorbing: false to allow clicks through empty areas
        SafeArea(
          child: IgnorePointer(
            ignoring: true, // Ignore pointer events on the Stack itself
            child: Stack(
              children: [
                // Top-right card info (deck counter and event log)
                Positioned(
                  top: 60, // Below the Chexx game's top UI bar
                  right: 8,
                  child: IgnorePointer(
                    ignoring: false, // Allow interactions with this widget
                    child: _buildCardInfoBar(),
                  ),
                ),

                // Right side panels (Card Info and Unit Info)
                if (selectedCard != null)
                  Positioned(
                    top: 120, // Below deck counter
                    right: 8,
                    child: IgnorePointer(
                      ignoring: false, // Allow interactions with this widget
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildSelectedCardPanel(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                // Bottom card hand bar
                Positioned(
                  bottom: 60, // Above the Chexx game's bottom button bar
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: false, // Allow interactions with this widget
                    child: _buildCardHandBar(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardInfoBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Deck counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.purple.shade800.withOpacity(0.9),
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
        Container(
          decoration: BoxDecoration(
            color: Colors.purple.shade800.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 20),
            onPressed: _showEventLog,
            tooltip: 'Event Log',
          ),
        ),
      ],
    );
  }

  Widget _buildCardHandBar() {
    final currentPlayer = cardGameState.cardCurrentPlayer;

    return Container(
      height: 140, // Reduced from 180
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7), // More transparent
        border: Border(
          top: BorderSide(color: Colors.purple.shade700, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Player info (compact, vertical on left)
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentPlayer?.name ?? 'No player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentPlayer?.hand.length ?? 0} cards',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                // PLAY CARD button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCard != null ? () => _playCard(selectedCard) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('PLAY CARD', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 4),
                // END TURN button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _endTurn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('END TURN', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),

          // Vertical divider
          Container(
            width: 2,
            color: Colors.purple.shade700,
          ),

          // Cards (horizontal scrolling)
          Expanded(
            child: _buildPlayerHand(),
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
      width: 85, // Reduced from 100
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.style,
                  color: Colors.purple.shade200,
                  size: 28, // Reduced from 32
                ),
                const SizedBox(height: 3),
                Text(
                  card.card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9, // Reduced from 10
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
                    fontSize: 7, // Reduced from 8
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
    setState(() {
      selectedCard = card;
    });
  }

  void _playCard(dynamic card) {
    cardGameState.playCard(card);
    setState(() {
      selectedCard = null; // Clear selection after playing
    });
  }

  Widget _buildSelectedCardPanel() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade900.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade400, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CARD INFO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () => setState(() => selectedCard = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.purple),
          const SizedBox(height: 8),

          // Card name
          Text(
            selectedCard.card.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Card type
          Text(
            'Type: ${selectedCard.card.type}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),

          // Card description
          Text(
            selectedCard.card.description ?? 'No description',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),

          // Actions section (if available)
          if (selectedCard.card.actions != null && selectedCard.card.actions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.purple),
            const SizedBox(height: 8),
            const Text(
              'ACTIONS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            ...(selectedCard.card.actions!.map((action) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, color: Colors.purple, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${action['action_type']}: ${action['hex_restrictions']} (${action['hex_tiles']})',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ],
      ),
    );
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

# Card Game Quick Start

## ✅ Integration Status: COMPLETE

The f-card engine from `../f-card` is fully integrated and working.

## How It Works

When you select "Card Game" mode and click "START GAME":

1. **Plugin System Routes to Card Plugin** (`lib/main.dart:369`)
   ```dart
   final pluginId = selectedGameMode == 'card' ? 'card' : 'chexx';
   ```

2. **CardPlugin Loads** (`lib/games/card/card_plugin.dart`)
   - Initializes f-card engine's `GameStateManager`
   - Initializes f-card engine's `DeckManager`
   - Loads cards from assets
   - Sets up 2-player game with 5-card starting hands

3. **CardGameScreen Displays** (`lib/games/card/card_game_screen.dart`)
   - Wraps f-card's `GameScreen` widget
   - Provides Provider context for state management
   - Adds custom app bar with info/event log buttons

## Quick Test

```bash
# Run the app
flutter run -d chrome

# Or use your start script
./start.sh
```

Then:
1. Select "Card Game" from the menu
2. Click "START GAME"
3. The f-card engine UI will launch
4. Click "START GAME" in the f-card UI to begin playing

## Accessing Game State (Headless Mode)

```dart
import 'package:chexx/core/engine/game_plugin_manager.dart';
import 'package:chexx/games/card/card_plugin.dart';
import 'package:f_card_engine/f_card_engine.dart';

// Get the card plugin
final pluginManager = GamePluginManager();
final cardPlugin = pluginManager.getPlugin('card') as CardPlugin;

// Access f-card engine directly
final engine = cardPlugin.cardGameStateManager;
final deck = cardPlugin.deckManager;

// Check state
print('Players: ${engine.players.length}');
print('Game started: ${engine.gameStarted}');
print('Deck cards: ${deck.cardsRemaining}');

// Access event log
for (var event in engine.eventLog) {
  print('${event['type']}: ${event['data']}');
}

// Play programmatically
if (engine.gameStarted) {
  final player = engine.currentPlayer;
  if (player != null && player.hand.isNotEmpty) {
    engine.playCard(player.hand.first, destination: CardZone.discard);
  }
}
```

## Event Log Structure

Each event in `eventLog` has this structure:

```dart
{
  'type': 'event_type',      // e.g., 'card_played', 'turn_ended'
  'timestamp': '2025-10-03T...', // ISO 8601 timestamp
  'data': {                  // Event-specific data
    // varies by event type
  }
}
```

### Event Types:
- `game_initialized` - Players initialized
- `game_started` - Game started, cards dealt
- `card_played` - Card played from hand
- `cards_drawn` - Cards drawn
- `card_moved` - Card moved between zones
- `turn_ended` - Turn successfully ended
- `turn_end_failed` - Turn end failed (must play card)
- `game_reset` - Game reset to initial state

## F-Card Engine Components

### GameStateManager
- `List<Player> players` - All players
- `Player? currentPlayer` - Current player
- `bool gameStarted` - Is game started?
- `List<CardInstance> inPlay` - Cards in play
- `List<CardInstance> discard` - Discard pile
- `List<CardInstance> removed` - Removed cards
- `List<Map<String, dynamic>> eventLog` - Event history

### DeckManager
- `int cardsRemaining` - Cards left in deck
- `List<CardInstance> deck` - Deck contents
- `Future<void> loadCards()` - Load from assets
- `void shuffle()` - Shuffle deck
- `List<CardInstance> drawCards(int count)` - Draw cards

### Player (from f-card)
- `String id` - Player ID
- `String name` - Player name
- `List<CardInstance> hand` - Player's hand
- `bool hasPlayedCardThisTurn` - Play status

## Build Commands

```bash
# Web build
flutter build web --no-tree-shake-icons

# Development
flutter run -d chrome

# Clean build
flutter clean && flutter pub get && flutter build web --no-tree-shake-icons
```

## File Locations

```
lib/games/card/
├── card_plugin.dart              # Main plugin (uses ../f-card)
├── card_game_state_adapter.dart  # State bridge
├── card_game_screen.dart         # UI wrapper
└── ...stubs...                   # Unused interface implementations

../f-card/                        # F-Card engine source
├── lib/
│   ├── managers/
│   │   ├── game_state_manager.dart
│   │   └── deck_manager.dart
│   ├── models/
│   └── ui/
└── assets/cards/                 # Card JSON files
```

## Verification

The integration is complete and working when:

✅ Build succeeds: `flutter build web --no-tree-shake-icons`
✅ "Card Game" appears in main menu
✅ Selecting "Card Game" + "START GAME" launches f-card UI
✅ Game state accessible via `cardPlugin.cardGameStateManager`
✅ Event log accessible via `eventLog` property

## Next Steps

To use the card game headlessly in your Chexx UI:

1. Access the `GameStateManager` from `CardPlugin`
2. Listen to `eventLog` for game events
3. Call `playCard()`, `endTurn()`, etc. programmatically
4. Build custom UI using f-card's data models

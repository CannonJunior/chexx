# F-Card Engine Integration - Updated

## Integration Complete ✓

The f-card engine has been successfully integrated into the Chexx Flutter project.

## What Was Done

### 1. Added Dependency (`pubspec.yaml`)
```yaml
dependencies:
  f_card_engine:
    path: ../f-card
```

### 2. Created Card Game Plugin (`lib/games/card/`)

**Files created:**
- `card_plugin.dart` - Main plugin implementing GamePlugin interface
- `card_game_state_adapter.dart` - Adapter bridging f-card with Chexx architecture
- `card_game_screen.dart` - UI screen using f-card's GameScreen
- `card_unit_factory.dart` - Stub for unit factory (not used in card games)
- `card_rules_engine.dart` - Stub for rules engine
- `card_ability_system.dart` - Stub for ability system

### 3. Registered Plugin (`lib/main.dart`)
- Imported and initialized CardPlugin
- Wired "card" game mode to launch f-card engine

## How to Use

### Starting the Card Game
1. Run the app: `flutter run -d chrome` or `./start.sh`
2. Select "Card Game" from main menu
3. Click "START GAME"
4. F-card engine UI will launch

### Accessing Game State

```dart
// Get the card plugin
final pluginManager = GamePluginManager();
final cardPlugin = pluginManager.getPlugin('card') as CardPlugin;

// Access game state adapter
final gameState = cardPlugin.createGameState() as CardGameStateAdapter;

// Access f-card engine components directly
GameStateManager fCardState = cardPlugin.cardGameStateManager;
DeckManager deckManager = cardPlugin.deckManager;
```

### Game State Properties

**From CardGameStateAdapter:**
```dart
// Event log
List<Map<String, dynamic>> eventLog = gameState.eventLog;

// Current player (f-card Player object)
Player? currentPlayer = gameState.cardCurrentPlayer;

// All players
List<Player> players = gameState.players;

// Game started?
bool gameStarted = gameState.gameStarted;

// Game over?
bool isGameOver = gameState.isGameOver;
```

**From GameStateManager (direct access):**
```dart
// Cards in play
List<CardInstance> inPlay = fCardState.inPlay;

// Discard pile
List<CardInstance> discard = fCardState.discard;

// Removed cards
List<CardInstance> removed = fCardState.removed;

// Deck info
int cardsInDeck = deckManager.cardsRemaining;
```

### Event Log Access

```dart
// Get all events
final events = gameState.eventLog;

// Each event has structure:
// {
//   'type': 'event_type',
//   'timestamp': '2025-10-03T...',
//   'data': { ... event-specific data ... }
// }

// Filter by event type
final cardPlays = events.where((e) => e['type'] == 'card_played').toList();
final draws = events.where((e) => e['type'] == 'cards_drawn').toList();
final turnEnds = events.where((e) => e['type'] == 'turn_ended').toList();
```

### Event Types

The f-card engine logs these events:
- `game_initialized` - Game initialized with players
- `game_started` - Game started, cards dealt
- `card_played` - Card played from hand
- `cards_drawn` - Cards drawn
- `card_moved` - Card moved between zones
- `turn_ended` - Turn ended
- `turn_end_failed` - Turn end failed (e.g., must play card)
- `game_reset` - Game reset

### Playing Cards Programmatically

```dart
// Get current player
final player = fCardState.currentPlayer;

if (player != null && player.hand.isNotEmpty) {
  final card = player.hand.first;

  // Play card to discard
  gameState.playCard(card, destination: CardZone.discard);

  // Or play to in-play zone
  gameState.playCard(card, destination: CardZone.inPlay);
}
```

### Managing Turns

```dart
// End current turn
gameState.endTurn();

// Start game (if not started)
gameState.startGame(initialHandSize: 5);

// Reset game
gameState.resetGame();
```

### Headless Mode (No UI)

You can use the f-card engine without the UI:

```dart
// Access engine directly
final engine = cardPlugin.cardGameStateManager;
final deck = cardPlugin.deckManager;

// Game flow
await engine.initializeGame(numberOfPlayers: 2);
engine.startGame(initialHandSize: 5);

// Get player hands
for (var player in engine.players) {
  print('${player.name}: ${player.hand.length} cards');

  // Play first card
  if (player.hand.isNotEmpty) {
    engine.playCard(player.hand.first);
  }
}

// End turn
engine.endTurn();

// Access event log
print('Events: ${engine.eventLog.length}');
for (var event in engine.eventLog) {
  print('${event['type']}: ${event['data']}');
}
```

## UI Integration

The CardGameScreen wraps f-card's GameScreen widget with:
- Custom app bar with info and event log buttons
- Game state info dialog
- Event log viewer dialog

Access these by tapping the icons in the app bar.

## F-Card Engine API Summary

### GameStateManager
```dart
// Properties
List<Player> players
Player? currentPlayer
bool gameStarted
List<CardInstance> inPlay
List<CardInstance> discard
List<CardInstance> removed
List<Map<String, dynamic>> eventLog

// Methods
Future<void> initializeGame({int? numberOfPlayers})
void startGame({int? initialHandSize})
void playCard(CardInstance card, {CardZone destination})
bool endTurn()
void moveCardFromPlay(CardInstance card, CardZone destination)
void resetGame()
String getEventLogJson()
void clearEventLog()
```

### DeckManager
```dart
// Properties
int cardsRemaining
List<CardInstance> deck

// Methods
Future<void> loadCards()
void shuffle()
CardInstance? drawCard()
List<CardInstance> drawCards(int count)
void returnToDeck(CardInstance card, {bool toTop})
void reset()
```

### Player (f-card model)
```dart
String id
String name
List<CardInstance> hand
bool hasPlayedCardThisTurn

void addToHand(CardInstance card)
void removeFromHand(CardInstance card)
void clearHand()
void resetTurn()
```

### CardInstance
```dart
String instanceId
CardModel card
CardZone currentZone
CardZone? origin
CardZone? destination

void moveToZone(CardZone zone)
Map<String, dynamic> toExternalData()
```

### CardZone (enum)
```dart
CardZone.deck
CardZone.hand
CardZone.inPlay
CardZone.discard
CardZone.removed
```

## Building

The project builds successfully with:

```bash
# For web
flutter build web --no-tree-shake-icons

# For development
flutter run -d chrome
# or use the start script
./start.sh
```

## File Structure

```
lib/games/card/
├── card_plugin.dart              # Main plugin
├── card_game_state_adapter.dart  # State adapter
├── card_game_screen.dart         # UI screen
├── card_unit_factory.dart        # Stub (not used)
├── card_rules_engine.dart        # Stub (not used)
├── card_ability_system.dart      # Stub (not used)
└── README.md                     # Detailed docs
```

## Next Steps

To enhance the integration:

1. **Custom UI** - Build Chexx-specific card UI instead of using f-card's default
2. **Game Rules** - Implement card game rules (damage, effects, etc.)
3. **Deck Builder** - Add deck customization from assets
4. **Save/Load** - Implement game state persistence
5. **Multiplayer** - Add network play support

## Notes

- The f-card engine uses a simple card play system
- Each player must play a card per turn (configurable)
- Cards are drawn at turn end (configurable)
- Event log tracks all game actions
- The integration uses Provider pattern for state management

# F-Card Engine Integration

This module integrates the f-card engine into the Chexx project as a card game mode.

## Overview

The integration uses a plugin architecture to seamlessly incorporate the f-card engine's card game functionality into the existing Chexx framework.

## Architecture

### Key Components

1. **CardPlugin** (`card_plugin.dart`)
   - Main plugin implementing the `GamePlugin` interface
   - Manages f-card engine components (GameStateManager, DeckManager)
   - Provides access to card game state and functionality

2. **CardGameStateAdapter** (`card_game_state_adapter.dart`)
   - Bridges f-card engine's GameStateManager with Chexx's GameStateBase
   - Provides unified API for accessing game state
   - Exposes event log and game state information

3. **CardGameScreen** (`card_game_screen.dart`)
   - Flutter widget for card game UI
   - Uses f-card engine's GameScreen widget
   - Provides additional UI for game info and event log viewing

4. **Supporting Components**
   - `CardUnitFactory` - Stub implementation (card games don't use traditional units)
   - `CardRulesEngine` - Delegates to f-card engine's game rules
   - `CardAbilitySystem` - Delegates to f-card engine's ability system

## Accessing Game State

### From Within the Game Screen

```dart
// Access the card game state adapter
CardGameStateAdapter gameState = widget.gamePlugin.createGameState() as CardGameStateAdapter;

// Get current player
int currentPlayer = gameState.currentPlayer;

// Get player life totals
Map<int, int> playerLife = gameState.playerLife;

// Get player hands
Map<int, List<GameCard>> hands = gameState.playerHands;

// Get zones (battlefield, graveyard, exile, etc.)
Map<String, CardZone> zones = gameState.zones;

// Get current game phase
String phase = gameState.currentPhase;

// Check if game is over
bool gameOver = gameState.isGameOver;

// Get winner (if game is over)
int? winner = gameState.winner;
```

### Accessing the Event Log

```dart
// Get all game events
List<GameEvent> events = gameState.eventLog;

// Iterate through events
for (var event in events) {
  print('${event.timestamp}: ${event.type} - ${event.description}');
  print('Player: ${event.playerId}');
  print('Data: ${event.data}');
}

// Filter events by type
List<GameEvent> cardPlays = events.where((e) => e.type == 'play_card').toList();
List<GameEvent> attacks = events.where((e) => e.type == 'attack').toList();
List<GameEvent> draws = events.where((e) => e.type == 'draw').toList();
```

### Direct Access to F-Card Engine Components

```dart
// Get the CardPlugin instance
CardPlugin cardPlugin = pluginManager.getPlugin('card') as CardPlugin;

// Access f-card engine's GameStateManager directly
GameStateManager cardGameState = cardPlugin.cardGameStateManager;

// Access f-card engine's DeckManager
DeckManager deckManager = cardPlugin.deckManager;
```

## Game Actions

### Playing Cards

```dart
// Play a card from hand
GameCard card = gameState.playerHands[playerId].first;
bool success = await gameState.playCard(playerId, card, target: targetCard);
```

### Drawing Cards

```dart
// Draw cards
List<GameCard> drawnCards = await gameState.drawCards(playerId, 2);
```

### Combat

```dart
// Declare attacker
GameCard attacker = /* get card from battlefield */;
GameCard blocker = /* optional blocking card */;
bool success = await gameState.declareAttacker(attacker, blocker: blocker);
```

### Activating Abilities

```dart
// Activate a card ability
bool success = await gameState.activateAbility(
  card,
  'tap_ability_id',
  target: targetCard,
);
```

### Ending Turn

```dart
// End the current turn
await gameState.endTurn();
```

## Event Types

The event log tracks the following event types:

- `play_card` - A card was played from hand
- `draw` - Cards were drawn
- `attack` - An attack was declared
- `block` - A blocker was declared
- `ability` - An ability was activated
- `phase_change` - Game phase changed
- `damage` - Damage was dealt
- `life_change` - Player life total changed
- `zone_change` - A card moved between zones

## Example: Monitoring Game State Changes

```dart
class MyCardGameWidget extends StatefulWidget {
  final CardPlugin plugin;

  @override
  State<MyCardGameWidget> createState() => _MyCardGameWidgetState();
}

class _MyCardGameWidgetState extends State<MyCardGameWidget> {
  late CardGameStateAdapter gameState;

  @override
  void initState() {
    super.initState();
    gameState = widget.plugin.createGameState() as CardGameStateAdapter;

    // Listen to event log updates
    _setupEventListener();
  }

  void _setupEventListener() {
    // Poll for new events (in a real implementation, use proper state management)
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          // UI will rebuild with latest event log
          final latestEvent = gameState.eventLog.lastOrNull;
          if (latestEvent != null) {
            _handleGameEvent(latestEvent);
          }
        });
      }
    });
  }

  void _handleGameEvent(GameEvent event) {
    switch (event.type) {
      case 'play_card':
        print('Card played: ${event.data['card_name']}');
        break;
      case 'attack':
        print('Attack declared by ${event.data['attacker']}');
        break;
      case 'life_change':
        print('Player ${event.playerId} life: ${event.data['new_life']}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Current Player: ${gameState.currentPlayer}'),
        Text('Life: ${gameState.playerLife[gameState.currentPlayer]}'),
        Text('Phase: ${gameState.currentPhase}'),
        Text('Events: ${gameState.eventLog.length}'),
      ],
    );
  }
}
```

## Headless Usage

To use the f-card engine headlessly (without the built-in UI):

```dart
// Get the plugin
CardPlugin cardPlugin = pluginManager.getPlugin('card') as CardPlugin;

// Create game state
CardGameStateAdapter gameState = cardPlugin.createGameState() as CardGameStateAdapter;

// Access f-card engine directly for headless operations
GameStateManager engine = gameState.cardGameState;

// Perform game actions programmatically
await engine.startGame([playerId1, playerId2]);
await engine.drawCards(playerId1, 5);
await engine.drawCards(playerId2, 5);

// Access all game data
var battlefield = engine.zones['battlefield'];
var graveyard = engine.zones['graveyard'];
var exile = engine.zones['exile'];

// Monitor events
for (var event in engine.eventLog) {
  // Process events for AI, analytics, etc.
}
```

## Configuration

The card game is configured in `CardPlugin._createCardGameConfig()` and uses f-card engine's `GameConfig` for card-specific settings:

- Starting hand size: 5 cards
- Maximum hand size: 7 cards
- Starting life: 20
- Maximum mana: 10

These can be customized by modifying the `_initializeGame()` method in `card_plugin.dart`.

## Integration with Chexx UI

The card game integrates seamlessly with the existing Chexx UI:

1. Main menu shows "Card Game" option
2. Selecting "Card Game" and clicking "START GAME" launches the f-card engine
3. The game uses f-card engine's built-in UI or can be customized with Chexx's UI components
4. Game state and events are accessible through the unified plugin architecture

## File Structure

```
lib/games/card/
├── card_plugin.dart              # Main plugin implementation
├── card_game_state_adapter.dart  # State adapter bridging f-card and Chexx
├── card_game_screen.dart         # Game UI screen
├── card_unit_factory.dart        # Stub unit factory
├── card_rules_engine.dart        # Rules engine delegation
├── card_ability_system.dart      # Ability system delegation
└── README.md                     # This file
```

## Dependencies

This integration requires the f-card_engine package to be available at `../f-card` relative to the project root. The dependency is configured in `pubspec.yaml`:

```yaml
dependencies:
  f_card_engine:
    path: ../f-card
```

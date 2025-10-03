# Card Game Integration - Chexx UI Edition

## ✅ Status: COMPLETE

The f-card engine is now integrated with **Chexx UI** (not f-card UI). Cards are drawn correctly and the game uses the f-card engine for all card logic while displaying in Chexx-style interface.

## What Changed

### 1. **Cards Now Draw Correctly** ✅
- Players start with **5 cards** (configurable via `initial_hand_size` in scenario config)
- Cards are drawn when `startGame()` is called in `CardGameScreen.initState()`
- Configuration: `lib/main.dart:365` sets `initial_hand_size: 5`

### 2. **Chexx UI Instead of F-Card UI** ✅
- **New UI**: `lib/games/card/card_game_screen.dart`
  - Chexx-style dark theme with purple accents
  - Top bar: Back button, title, deck counter, info/event log buttons
  - Bottom bar: Player hand display (horizontal scrolling cards)
  - Action buttons: End Turn (more actions coming)

- **Game World**: `lib/games/card/card_game_world.dart`
  - Flame game engine background
  - Placeholder for future unit rendering

### 3. **Configuration** ✅
- `lib/configs/card_game_config.json` - Card game settings
- `lib/main.dart:365` - Initial hand size (default: 5)
- Configurable per game session via scenario config

## How It Works Now

### Starting Card Game

1. Select "Card Game" from main menu
2. Click "START GAME"
3. **Chexx UI loads** with:
   - 5 cards in hand (drawn automatically)
   - Deck counter showing remaining cards
   - Purple-themed game board

### Current Features

**UI Components:**
- ✅ Top bar with game info
- ✅ Bottom bar with player hand
- ✅ Card display (name, type, icon)
- ✅ Deck counter
- ✅ Event log viewer
- ✅ Game state info dialog
- ✅ End turn button

**F-Card Engine Integration:**
- ✅ GameStateManager handles all card logic
- ✅ DeckManager loads cards from assets
- ✅ Event log tracks all actions
- ✅ Turn system with card play requirement
- ✅ Configurable game rules

## Configuration

### Initial Hand Size

**Method 1: Main Menu (Default)**
```dart
// lib/main.dart:365
'initial_hand_size': 5, // Change this number
```

**Method 2: Scenario Config**
```dart
final scenarioConfig = {
  'game_type': 'card',
  'initial_hand_size': 7, // Custom hand size
};
```

**Method 3: Config File**
```json
// lib/configs/card_game_config.json
{
  "initial_hand_size": 5,
  "max_hand_size": 10,
  "cards_drawn_per_turn": 1
}
```

### Game Rules Configuration

Edit `lib/games/card/card_plugin.dart:68-74`:

```dart
final fCardConfig = GameConfig(
  numberOfPlayers: 2,
  initialHandSize: 5,                // Starting hand size
  requireCardPlayedPerTurn: true,    // Must play card to end turn
  drawCardOnTurnEnd: true,            // Draw when turn ends
  cardsDrawnOnTurnEnd: 1,            // How many to draw
);
```

## Using Cards for Unit Orders (Future)

Cards will be used to order units. Example card types:

### Order Cards
- **Move Order**: Command unit to move to position
- **Attack Order**: Order unit to attack target
- **Formation Order**: Set unit formation/stance

### Spell Cards
- **Buff Unit**: Enhance unit stats
- **Area Effect**: Damage/heal area
- **Summon**: Create new unit

### Implementation Plan

```dart
void _onCardTapped(dynamic card) {
  final cardType = card.card.type;

  if (cardType == 'order_move') {
    // Show hex grid for movement selection
    _showHexSelection(onSelected: (hex) {
      // Move selected unit to hex
      // Play card from hand
    });
  } else if (cardType == 'order_attack') {
    // Show targets for attack
    _showTargetSelection(onSelected: (target) {
      // Attack target
      // Play card from hand
    });
  }
}
```

## Accessing Game State

```dart
// Get card plugin
final pluginManager = GamePluginManager();
final cardPlugin = pluginManager.getPlugin('card') as CardPlugin;

// Access game state
final gameState = cardPlugin.createGameState() as CardGameStateAdapter;

// Get current player's hand
final player = gameState.cardCurrentPlayer;
if (player != null) {
  print('Hand size: ${player.hand.length}');
  for (var card in player.hand) {
    print('Card: ${card.card.name} (${card.card.type})');
  }
}

// Access event log
for (var event in gameState.eventLog) {
  print('${event['type']}: ${event['data']}');
}

// Play card programmatically
if (player != null && player.hand.isNotEmpty) {
  gameState.playCard(player.hand.first);
}
```

## Files Changed/Created

### Modified
- `lib/main.dart` - Added `initial_hand_size: 5` to scenario config
- `lib/games/card/card_game_screen.dart` - **Replaced with Chexx UI**
- `lib/games/card/card_plugin.dart` - Already correct

### Created
- `lib/games/card/card_game_world.dart` - Flame game world
- `lib/configs/card_game_config.json` - Card game configuration

## Build & Run

```bash
# Build for web
flutter build web --no-tree-shake-icons

# Run in development
flutter run -d chrome

# Or use start script
./start.sh
```

## UI Screenshots (Description)

**Top Bar:**
```
[← Back] CARD GAME MODE                    [🎴 40] [ℹ️] [📜]
```

**Bottom Bar:**
```
┌─────────────────────────────────────────────────────┐
│  [Card 1]  [Card 2]  [Card 3]  [Card 4]  [Card 5]  │
│                                                      │
│              [ END TURN ]                           │
└─────────────────────────────────────────────────────┘
```

**Card Widget:**
```
┌──────────┐
│    🎴    │
│  Card    │
│  Name    │
│   type   │
└──────────┘
```

## Event Log Example

```json
[
  {
    "type": "game_initialized",
    "timestamp": "2025-10-03T12:00:00.000Z",
    "data": {"numberOfPlayers": 2, "totalCards": 40}
  },
  {
    "type": "game_started",
    "timestamp": "2025-10-03T12:00:01.000Z",
    "data": {"initialHandSize": 5, "cardsRemaining": 30}
  },
  {
    "type": "card_played",
    "timestamp": "2025-10-03T12:00:05.000Z",
    "data": {"card": "Move Order", "player": "Player 1"}
  }
]
```

## Next Steps

### Immediate
1. ✅ Cards draw correctly (5 per player)
2. ✅ Chexx UI instead of f-card UI
3. ✅ Configurable hand size

### Phase 2: Card-Based Unit Control
- [ ] Create "Order" cards for unit commands
- [ ] Implement card → hex grid interaction
- [ ] Add card effects to unit actions
- [ ] Visual feedback for card plays

### Phase 3: Advanced Features
- [ ] Custom card deck builder
- [ ] Card synergies with meta hexes
- [ ] Special card types (summon, spell, etc.)
- [ ] Card-based resource system

## Summary

✅ **Fixed Issues:**
1. Cards now draw correctly (5 cards at start)
2. Using Chexx UI (not f-card UI)
3. Initial hand size is configurable

✅ **F-Card Engine Integration:**
- All card logic handled by f-card engine
- Event logging works
- Turn system functional
- Deck management operational

✅ **Future Ready:**
- Card system ready for unit ordering
- Extensible for spell cards, summons, etc.
- Configuration system in place

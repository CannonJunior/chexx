# Card Game Quick Reference

## ✅ Integration Complete

F-card engine integrated with **Chexx UI** (no f-card UI).

## Key Facts

### 🎴 Cards Work Correctly
- **5 cards drawn at start** ✅
- Configurable via `lib/main.dart:365` → `'initial_hand_size': 5`
- Cards visible in bottom panel

### 🎨 UI is Chexx-Style
- **NOT using f-card UI** ✅
- Chexx dark theme with purple accents
- Flame game engine for rendering
- Hand displayed at bottom

### 🔧 Fully Configurable
- Hand size: Change `initial_hand_size` in scenario config
- Game rules: Edit `lib/games/card/card_plugin.dart:68-74`
- UI settings: `lib/configs/card_game_config.json`

## File Locations

```
lib/games/card/
├── card_plugin.dart           # F-card engine initialization
├── card_game_screen.dart      # CHEXX UI (NEW)
├── card_game_world.dart       # Flame game world (NEW)
├── card_game_state_adapter.dart
└── ...

lib/configs/
└── card_game_config.json      # Configuration (NEW)

lib/main.dart:365              # initial_hand_size: 5
```

## How to Change Hand Size

**Option 1: Main Menu Default**
```dart
// lib/main.dart:365
'initial_hand_size': 7,  // Change from 5 to 7
```

**Option 2: Per-Game**
```dart
final scenarioConfig = {
  'game_type': 'card',
  'initial_hand_size': 10,  // Custom for this game
};
```

## Accessing Cards

```dart
// Get plugin
final cardPlugin = GamePluginManager().getPlugin('card') as CardPlugin;

// Get state
final gameState = cardPlugin.createGameState() as CardGameStateAdapter;

// Get current player
final player = gameState.cardCurrentPlayer;

// Access hand
print('Cards in hand: ${player?.hand.length}');
for (var card in player?.hand ?? []) {
  print('${card.card.name} - ${card.card.type}');
}

// Play card
gameState.playCard(card);

// End turn
gameState.cardGameState.endTurn();
```

## UI Components

### Top Bar
- Back button
- Title: "CARD GAME MODE"
- Deck counter (shows remaining cards)
- Info button (game state)
- Event log button

### Bottom Bar
- Player hand (horizontal scroll)
- Card widgets (name, type, icon)
- End Turn button

### Card Widget
Each card shows:
- Icon (🎴)
- Card name
- Card type
- Tap to play/view

## Build & Test

```bash
flutter build web --no-tree-shake-icons
# or
./start.sh
```

## Next: Cards for Unit Orders

Cards will be used to command units:

1. **Order Cards** - Move/attack commands
2. **Spell Cards** - Buffs, debuffs, area effects
3. **Summon Cards** - Create units

Example flow:
```
Tap "Move Order" card
  → Select unit on board
  → Select destination hex
  → Card played, unit moves
  → Event logged
```

## Event Log

Access via info button or:
```dart
final events = gameState.eventLog;
// Each event: {'type': '...', 'timestamp': '...', 'data': {...}}
```

## Summary

✅ Cards draw: 5 at start
✅ UI: Chexx style (not f-card)
✅ Configurable: initial_hand_size
✅ F-card engine: All logic
✅ Ready for: Unit order cards

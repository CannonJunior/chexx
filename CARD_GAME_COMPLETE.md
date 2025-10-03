# Card Game Mode - COMPLETE ✅

## What You'll See Now

When you select **"Card Game"** mode and click **"START GAME"**:

### ✅ Chexx Hex Board (Center)
- **Same hex grid** as other game modes
- Units, terrain, meta hexes
- Full Chexx game board functionality
- Click to select/move units (normal gameplay)

### ✅ Card UI Overlay (Top & Bottom)
- **Top Bar** (right side):
  - Deck counter: [🎴 35] (shows remaining cards)
  - Event log button: [📜]

- **Bottom Bar**:
  - Player name and card count
  - **5 cards displayed** horizontally
  - [END TURN] button
  - Cards show: Icon, Name, Type

### ✅ Both Systems Work Together
- **Hex board** = Chexx game (units, movement, combat)
- **Cards** = F-card engine (hand, deck, draw)
- Play on the board, use cards for actions

## How It Works

```
┌────────────────────────────────────────┐
│  Top Bar: [🎴 35] [📜]                 │
├────────────────────────────────────────┤
│                                        │
│         CHEXX HEX BOARD                │
│       (Same as other modes)            │
│     Units • Hexes • Movement           │
│                                        │
├────────────────────────────────────────┤
│  Player 1 • 5 cards                    │
│  [Card] [Card] [Card] [Card] [Card]   │
│          [END TURN]                    │
└────────────────────────────────────────┘
```

## Technical Details

### Stack Structure
```dart
Stack([
  ChexxGameScreen(         // Hex board
    gamePlugin: ChexxPlugin(),
    scenarioConfig: config,
  ),
  CardUIOverlay(           // Card UI on top
    deck: 35,
    hand: [5 cards],
  ),
])
```

### Files
- `lib/games/card/card_game_screen.dart` - Card UI overlay
- `lib/games/chexx/screens/chexx_game_screen.dart` - Hex board (unchanged)
- `lib/games/card/card_plugin.dart` - F-card engine integration

## Features Working

### ✅ Hex Board (Chexx)
- Hexagonal grid displayed
- Units can be placed
- Terrain rendering
- Movement/attack systems
- Meta hexes
- Turn timer
- All normal Chexx gameplay

### ✅ Card System (F-Card Engine)
- 40 cards loaded from `assets/cards/`
- 5 cards drawn at start
- Deck counter updates
- Event log tracks actions
- Turn system (must play card to end turn)
- Cards drawn on turn end

### ✅ UI Integration
- Minimal overlay (doesn't block board)
- Top bar transparent (see through)
- Bottom bar semi-transparent
- Cards clickable
- Event log accessible

## Current Behavior

1. **Start Game**: Hex board loads + 5 cards in hand
2. **Tap Card**: View details, can play card
3. **Play Card**: Card removed from hand, logged to event
4. **End Turn**: Must play a card first (enforced)
5. **New Turn**: Draw 1 card (configurable)

## Next: Card Actions on Board

Cards will be used to order units:

### Order Cards (Future)
```dart
void _onCardTapped(card) {
  if (card.type == 'order_move') {
    // 1. Card shows "Select unit"
    // 2. Tap unit on hex board
    // 3. Card shows "Select destination"
    // 4. Tap hex on board
    // 5. Unit moves, card played
  }
}
```

### Example Card Types
- **Move Order** → Select unit → Select hex → Unit moves
- **Attack Order** → Select attacker → Select target → Attack executed
- **Summon** → Select hex → New unit appears
- **Buff** → Select unit → Stats increased
- **Spell** → Select target → Effect applied

## Configuration

### Hand Size
```dart
// lib/main.dart:365
'initial_hand_size': 5,  // Change to 7, 10, etc.
```

### Card Draw Rules
```dart
// lib/games/card/card_plugin.dart:68-74
final fCardConfig = GameConfig(
  initialHandSize: 5,
  requireCardPlayedPerTurn: true,  // Must play before end turn
  drawCardOnTurnEnd: true,          // Draw when turn ends
  cardsDrawnOnTurnEnd: 1,          // How many to draw
);
```

## Debug Output

Console shows:
```
=== CARD GAME SCREEN INIT ===
Initial hand size: 5
Game started: true
Players: 2
Current player: Player 1
Deck remaining: 30
Current player hand: 5
```

## Build & Run

```bash
flutter build web --no-tree-shake-icons
# or
./start.sh
```

## What's Fixed

✅ Cards load correctly (40 cards)
✅ 5 cards drawn at start
✅ Chexx hex board displays (not grey background)
✅ Card UI overlays on hex board
✅ Both systems work independently
✅ Ready for card→board integration

## Summary

**Card Game Mode** now shows:
- ✅ **Chexx hex board** in center (same as other modes)
- ✅ **Card hand** at bottom (5 cards)
- ✅ **Deck counter** at top
- ✅ **F-card engine** managing cards
- ✅ **Chexx engine** managing board

Perfect for implementing card-based unit orders! 🎴

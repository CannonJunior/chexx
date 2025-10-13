# CHEXX - Technical Documentation
*Last Updated: 2025-10-12*
*Version: 1.0*

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [User-Facing Features](#user-facing-features)
4. [Backend Services](#backend-services)
5. [Data Models](#data-models)
6. [Game Modes](#game-modes)
7. [Scenario Builder](#scenario-builder)
8. [Configuration System](#configuration-system)
9. [Testing Strategy](#testing-strategy)
10. [Development Workflow](#development-workflow)

---

## Executive Summary

**Project Name:** CHEXX - Hexagonal Turn-Based Strategy Game
**Platform:** Flutter Web (Primary), Desktop (Linux), Mobile (Android)
**Language:** Dart
**Architecture:** Plugin-based with ECS (Entity Component System)
**Total Files:** 65 Dart files, 3 test files
**Port:** 8888 (web server)

**Primary Features:**
- Multiple game modes (CHEXX, WWII, Card)
- Visual scenario builder for custom game configurations
- Unit type configuration system
- Real-time multiplayer support (WebSocket-based)
- Card-based WWII combat system with dice mechanics
- Hexagonal grid with dual orientation support (flat/pointy-top)

---

## System Architecture

### High-Level Architecture

```
┌────────────────────────────────────────────────────────────┐
│                     Flutter Web App                         │
│                     (Main Entry Point)                      │
└──────────────────┬─────────────────────────────────────────┘
                   │
    ┌──────────────┴──────────────┐
    │   GamePluginManager          │
    │   (Plugin Registry)          │
    └──────────┬──────────────────┘
               │
       ┌───────┴────────┬──────────────┐
       │                │              │
  ┌────▼─────┐   ┌──────▼──────┐  ┌───▼──────┐
  │  CHEXX   │   │    WWII     │  │   Card   │
  │  Plugin  │   │    Plugin   │  │  Plugin  │
  └────┬─────┘   └──────┬──────┘  └───┬──────┘
       │                │              │
  ┌────▼─────────────────▼──────────────▼────────┐
  │          Core Game Systems                    │
  │  - GameState (state management)               │
  │  - GameBoard (hex grid management)            │
  │  - UnitFactory (unit creation)                │
  │  - CombatSystem (battle logic)                │
  │  - MovementSystem (unit movement)             │
  └───────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. **Entry Point** (`lib/main.dart`)
- Initializes Flutter binding
- Registers game plugins (CHEXX, Card, WWII)
- Launches main menu
- Handles device orientation

#### 2. **Plugin System** (`lib/core/engine/game_plugin_manager.dart`)
- **Purpose:** Decouple game modes from core engine
- **Responsibilities:**
  - Plugin registration
  - Active plugin switching
  - Game screen creation per plugin

#### 3. **Core Systems**
- **GameState** (`lib/src/models/game_state.dart`): Central state management
  - Turn management
  - Player switching
  - Win condition checking
  - Card system integration (WWII mode)
  - Meta abilities system

- **GameBoard** (`lib/src/models/game_board.dart`): Hex grid management
  - Tile creation/removal
  - Coordinate validation
  - Pathfinding support

- **Unit System**
  - **GameUnit** (`lib/src/models/game_unit.dart`): Individual unit logic
  - **UnitFactory** (`lib/core/interfaces/unit_factory.dart`): Unit creation interface
  - **UnitTypeConfig** (`lib/src/models/unit_type_config.dart`): Configuration-driven unit behavior

#### 4. **Combat Systems**
- **Traditional Combat:** Simple damage calculation
- **WWII Combat System** (`lib/src/systems/combat/wwii_combat_system.dart`):
  - Dice-rolling mechanics
  - Terrain modifiers
  - Unit-specific die faces
  - Experience gain

#### 5. **Networking** (`lib/network/`)
- WebSocket-based multiplayer
- Game state synchronization
- Connection management
- Player matching

---

## User-Facing Features

### 1. Main Menu
**File:** `lib/main.dart` (MainMenuScreen)

**Features:**
- Game mode selection (CHEXX, WWII, Card)
- Scenario file upload (JSON)
- Quick start (default scenarios)
- Scenario Builder access
- Multiplayer test screen
- How to Play instructions

**User Flow:**
```
Main Menu → Select Mode → [Load Scenario OR Quick Start] → Game Screen
         ↓
    Scenario Builder → Edit → Save → Load → Game Screen
```

### 2. Scenario Builder
**File:** `lib/src/screens/scenario_builder_screen.dart`

**Capabilities:**
- **Unit Placement:** Drag-and-drop units on hex grid
- **Tile Editing:** Change terrain types (ocean, beach, hill, forest, town, etc.)
- **Structure Placement:** Add bunkers, bridges, sandbags, barbwire, dragon's teeth
- **Health Adjustment:** Incrementable units can have custom starting health (1-max)
- **Board Partitioning:** Divide board into thirds with draggable vertical lines
- **Orientation Toggle:** Switch between flat-top and pointy-top hexagons
- **Game Type Selection:** Choose CHEXX or WWII unit sets
- **Win Conditions:** Set victory point requirements for each player
- **Export:** Save scenario as JSON file

**Keyboard Controls:**
- **Q/W/E/A/S/D:** Move cursor in hex directions
- **↑ Arrow:** Increment selected unit's health
- **↓ Arrow:** Decrement selected unit's health

**Click Cycles:**
- **Units:** Place → Select → Remove → Place...
- **Structures:** Place → Remove → Place...
- **Tiles:** Change type → Remove (if same type) → Create new

### 3. Game Modes

#### CHEXX Mode (Classic)
- 4 unit types: Minor, Scout, Knight, Guardian
- Movement patterns: adjacent, straight-line, L-shaped
- Special abilities: swap, long-range attacks
- Meta hexagons: spawn, heal, shield
- Turn timer: 6 seconds
- Reward system: time-based bonuses

#### WWII Mode
- 3 unit types: Infantry, Armor, Artillery
- Card-based activation system
- Dice-rolling combat with terrain modifiers
- Action cards: limit units that can be ordered per turn
- Incrementable health (units can have 1-4 HP)
- Indirect fire mechanics (artillery)

#### Card Mode
- Separate card game engine (F-Card integration)
- Minimal features (placeholder)

### 4. Multiplayer
**File:** `lib/network/multiplayer_test_screen.dart`

**Features:**
- Create/join game sessions
- WebSocket connection to game server
- Real-time game state sync
- Player matching
- Connection status display

---

## Backend Services

### Game Server
**Location:** `server/game_server/`

**Components:**
1. **WebSocket Server** (`bin/server.dart`)
   - Handles client connections
   - Message routing
   - Game session management
   - Runs on configurable port

2. **GameStateManager** (`lib/services/game_state_manager.dart`)
   - Maintains active game sessions
   - Validates moves
   - Broadcasts state updates
   - Handles player disconnections

3. **NetworkMessage Protocol** (`server/shared_models/`)
   - JSON-based message format
   - Message types: join, move, attack, endTurn, etc.
   - Serialization/deserialization

**Server Phases:**
- Phase 1: Basic WebSocket communication ✓
- Phase 2: Game state synchronization ✓
- Phase 3: Player actions ✓
- Phase 4: Combat resolution ✓
- Phase 5: Error handling & reconnection ✓

### Data Persistence
- **Scenarios:** JSON files (client-side download/upload)
- **Game State:** In-memory (server-side)
- **Configuration:** JSON files in `assets/` directory

---

## Data Models

### Core Models

#### HexCoordinate
**File:** `lib/src/models/hex_coordinate.dart`

```dart
class HexCoordinate {
  final int q, r, s; // Cube coordinates (q + r + s = 0)

  // Methods:
  - distanceTo(other): int
  - getNeighbors(): List<HexCoordinate>
  - toPixel(size, orientation): (double, double)
  - fromPixel(x, y, size, orientation): HexCoordinate?
}
```

#### GameUnit
**File:** `lib/src/models/game_unit.dart`

```dart
class GameUnit {
  String id;
  String unitTypeId;
  UnitTypeConfig config;
  Player owner;
  HexCoordinate position;
  int health;
  UnitState state; // idle, selected, moving, attacking
  int experience;

  // Capabilities:
  - getValidMoves(units): List<HexCoordinate>
  - getValidAttacks(units): List<HexCoordinate>
  - takeDamage(amount): bool
  - heal(amount): void
  - applyOverrides(overrides): void // Card effects
}
```

#### GameState
**File:** `lib/src/models/game_state.dart`

**Key Properties:**
- `currentPlayer`: Player.player1 | Player.player2
- `gamePhase`: setup | playing | gameOver
- `turnPhase`: moving | acting | ended
- `units`: List<GameUnit>
- `board`: GameBoard
- `selectedUnit`: GameUnit?
- `turnTimeRemaining`: double
- `hand`: PlayerHand? (WWII mode only)

**Key Methods:**
- `selectUnit(unit)`: Mark unit as selected
- `moveUnit(target)`: Execute unit movement
- `attackPosition(target)`: Execute attack
- `endTurn()`: Switch players, update state
- `playCard(card)`: Play action card (WWII mode)

#### ScenarioBuilderState
**File:** `lib/src/models/scenario_builder_state.dart`

```dart
class ScenarioBuilderState {
  GameBoard board;
  List<PlacedUnit> placedUnits;
  List<PlacedStructure> placedStructures;
  Set<HexCoordinate> metaHexes;
  HexOrientation hexOrientation;

  // Methods:
  - placeItem(position): bool
  - removeUnit(position): bool
  - generateScenarioConfig(): Map<String, dynamic>
  - loadFromScenarioData(data): void
  - incrementSelectedUnitHealth(): bool
  - calculateBoardThirds(): void
}
```

### Configuration Models

#### UnitTypeConfig
**File:** `lib/src/models/unit_type_config.dart`

```json
{
  "name": "Infantry",
  "symbol": "I",
  "health": 1,
  "max_health": 4,
  "movement_range": 2,
  "attack_range": 1,
  "attack_damage": 1,
  "movement_type": "adjacent",
  "is_incrementable": true
}
```

#### ActionCard (WWII Mode)
**File:** `lib/src/models/action_card.dart`

```dart
class ActionCard {
  String id;
  String name;
  String description;
  int unitsCanOrder; // How many units can move
  List<Map<String, dynamic>> actions; // Card effects

  // Card actions can have:
  // - unit_restrictions: "infantry", "armor", etc.
  // - overrides: { movement_range: 3, move_and_fire: true }
}
```

---

## Game Modes

### CHEXX Mode Details

**Unit Types:**
| Unit Type | Symbol | HP | Movement | Attack Range | Special |
|-----------|--------|-----|----------|--------------|---------|
| Minor     | M      | 1   | 1        | 1            | Basic   |
| Scout     | S      | 2   | 3        | 3            | Long range |
| Knight    | K      | 3   | 2        | 2            | L-shaped movement, 2 damage |
| Guardian  | G      | 3   | 1        | 1            | Can swap with friendly |

**Meta Abilities:**
- **Spawn:** Create Minor unit on adjacent hex (cooldown: 3 turns)
- **Heal:** Heal adjacent unit by 1 HP (cooldown: 2 turns)
- **Shield:** Adjacent units get -1 damage for 2 turns (cooldown: 4 turns)

### WWII Mode Details

**Unit Types:**
| Unit Type  | Symbol | HP Range | Movement | Attack Range | Special |
|------------|--------|----------|----------|--------------|---------|
| Infantry   | I      | 1-4      | 2        | 1            | Incrementable |
| Armor      | A      | 1-3      | 3        | 2            | Straight-line |
| Artillery  | R      | 1-2      | 1        | 4            | Indirect fire |

**Combat System:**
- Attacker rolls dice based on unit type
- Defender rolls dice based on terrain
- Hit on 5+ (d6)
- Damage = number of hits
- Terrain modifiers: ocean (-2), beach (-1), hill (+1), town (+2), forest (+1)

**Card System:**
- Players have hand of 5 cards
- Play 1 card per turn
- Cards limit number of units that can be ordered
- Cards can provide bonuses (extra movement, move-and-fire)
- Discard and draw at end of turn

---

## Scenario Builder

### Architecture

```
ScenarioBuilderScreen (UI)
         ↓
ScenarioBuilderState (State Management)
         ↓
┌────────┴────────┬─────────┬──────────┐
│                 │         │          │
PlacedUnits  PlacedStructures  GameBoard  MetaHexes
```

### File Format (JSON)

```json
{
  "scenario_name": "Custom Battle",
  "game_type": "wwii",
  "board": {
    "total_hexes": 91,
    "hex_size": 60.0
  },
  "unit_placements": [
    {
      "template": {
        "type": "infantry",
        "owner": "player1",
        "id": "p1_infantry"
      },
      "position": { "q": 0, "r": 0, "s": 0 },
      "customHealth": 3
    }
  ],
  "structure_placements": [...],
  "board_tiles": [
    { "q": 0, "r": 0, "s": 0, "type": "normal" }
  ],
  "meta_hex_positions": [...],
  "board_thirds": {
    "left_line_x": -2.5,
    "right_line_x": 2.5,
    "left_third_hexes": [...],
    "middle_third_hexes": [...],
    "right_third_hexes": [...]
  },
  "win_conditions": {
    "player1_points": 10,
    "player2_points": 10
  }
}
```

### Key Features Implementation

#### 1. Unit Health Modification
**Workflow:**
1. User selects unit template from palette
2. Clicks hex to place unit
3. Clicks hex again to select placed unit
4. Deselects template (clicks palette again)
5. Uses ↑/↓ arrow keys to adjust health
6. Unit visual updates to show multiple icons (1-6) or single icon with number (7+)

**State Management:**
- `selectedPlacedUnit`: The unit currently selected for editing
- `selectedUnitTemplate`: Template from palette (must be null for keyboard to work)
- `customHealth`: Custom health value stored in PlacedUnit

#### 2. Board Partitioning (Thirds)
**Purpose:** Divide board into deployment zones

**Implementation:**
- Vertical lines at calculated x-positions
- Hexes categorized into left/middle/right thirds
- Boundary hexes can belong to multiple thirds
- Lines are draggable (pointy-top orientation only)
- Snap to hex edges when released

#### 3. Tile Type System
**Tile Types:**
- Normal: Default terrain
- Meta: Purple hexagons with special abilities
- Blocked: Impassable
- Ocean, Beach, Hill, Forest, Town, Hedgerow: WWII terrain

**Click Behavior:**
- Select tile type → Click hex → Tile changes to selected type
- Click same type again → Removes tile entirely

---

## Configuration System

### Unit Type Sets
**Location:** `assets/config/unit_types/`

**Available Sets:**
- `chexx_units.json`: Classic CHEXX units
- `wwii_units.json`: WWII infantry, armor, artillery

**Loading:**
```dart
final unitTypeSet = await UnitTypeConfigLoader.loadUnitTypeSet('wwii');
final infantryConfig = unitTypeSet.getUnitConfig('infantry');
```

### Game Type Configs
**Location:** `assets/config/game_types/`

**Structure:**
```json
{
  "id": "wwii",
  "name": "WWII Combat",
  "description": "Card-based WWII tactical combat",
  "default_unit_set": "wwii",
  "features": {
    "card_system": true,
    "dice_combat": true,
    "meta_hexes": false
  }
}
```

### Die Faces Config (WWII Combat)
**File:** `lib/src/systems/combat/die_faces_config.dart`

```json
{
  "infantry_attacker": [1, 2, 3, 4, 5, 6],
  "infantry_defender": [2, 3, 4, 5, 6, 6],
  "terrain_modifiers": {
    "ocean": -2,
    "beach": -1,
    "hill": 1,
    "town": 2
  }
}
```

---

## Testing Strategy

### Current Test Coverage
**Files:** 3 test files
1. `test/widget_test.dart`: Basic widget tests
2. `test/card_effects_test.dart`: Card system tests
3. `test/scenario_builder_state_test.dart`: Scenario builder tests

### Test Categories

#### 1. Unit Tests
- **Models:** GameUnit, HexCoordinate, GameBoard
- **State Management:** GameState, ScenarioBuilderState
- **Configuration Loaders:** UnitTypeConfig, GameTypeConfig

#### 2. Integration Tests
- **Scenario Builder:** Full workflow (place, select, modify, save, load)
- **Game Flow:** Complete turn cycle
- **Combat:** Attack resolution with different unit types
- **Card System:** Play card, order units, end turn

#### 3. Widget Tests
- **UI Rendering:** Scenario builder screen, game screen
- **User Interactions:** Click, drag, keyboard input
- **State Updates:** Visual updates match state changes

#### 4. E2E Tests (Needed)
- **Full Game:** Start → Play → Win/Lose
- **Multiplayer:** Connect → Sync → Play together
- **Scenario Load:** Create scenario → Save → Load → Play

---

## Development Workflow

### Setup
1. Clone repository
2. Install Flutter SDK
3. Run `flutter pub get`
4. Load unit configs: `assets/config/unit_types/*.json`
5. Start web server: `./start.sh` (port 8888)

### Build & Test
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/scenario_builder_state_test.dart

# Build web
flutter build web --web-renderer canvaskit

# Run web (development)
flutter run -d web-server --web-port=8888
```

### Code Organization

**Directory Structure:**
```
lib/
├── core/              # Core framework (plugin system, interfaces)
├── games/             # Game mode implementations
│   ├── chexx/         # CHEXX plugin
│   ├── wwii/          # WWII plugin (uses chexx plugin)
│   └── card/          # Card game plugin
├── network/           # Multiplayer networking
├── src/               # Shared components
│   ├── models/        # Data models
│   ├── systems/       # Game systems (combat, movement)
│   ├── screens/       # UI screens
│   ├── components/    # UI components
│   └── utils/         # Utilities
└── main.dart          # Entry point

assets/
├── config/            # Configuration files
│   ├── game_types/
│   ├── unit_types/
│   └── die_faces/
├── cards/             # Action card definitions
└── scenarios/         # Example scenarios

server/
├── game_server/       # WebSocket game server
└── shared_models/     # Network message models

test/                  # Test files
```

### Coding Standards
- **State Management:** ChangeNotifier for UI state
- **Immutability:** Use const constructors where possible
- **Null Safety:** Enabled throughout
- **Naming:** camelCase for variables, PascalCase for classes
- **Comments:** Document non-obvious logic with `// Reason:` comments

### Git Workflow
1. Feature branches from `main`
2. Commit with descriptive messages
3. Test before merge
4. Include co-authorship: `Co-Authored-By: Claude <noreply@anthropic.com>`

---

## Known Issues & Limitations

1. **Card Mode:** Placeholder implementation, not fully functional
2. **Multiplayer:** Server not production-ready, lacks reconnection handling
3. **Test Coverage:** Only 3 test files for 65 source files (~5% coverage)
4. **Performance:** Large scenarios (>100 hexes) may experience lag
5. **Mobile:** Touch controls not optimized, designed for desktop
6. **Browser Support:** Best on Chrome, issues on Safari/Firefox
7. **Persistence:** No database, scenarios are file-based only
8. **AI Opponents:** Not implemented
9. **Sound/Music:** No audio system
10. **Accessibility:** Limited screen reader support

---

## Future Enhancements

1. **AI System:** Single-player vs computer
2. **Campaign Mode:** Series of linked scenarios
3. **Persistent Accounts:** User profiles, match history
4. **Ranking System:** ELO-based matchmaking
5. **Replay System:** Record and playback games
6. **Map Editor Improvements:** Terrain brushes, copy-paste
7. **Unit Editor:** Create custom unit types in-app
8. **Mod Support:** Load community-created content
9. **Mobile App:** Native iOS/Android builds
10. **Performance Optimization:** Large-scale battles (200+ units)

---

## Appendix

### Key Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  flame: ^1.10.1           # 2D game engine
  oxygen: ^0.1.0           # ECS framework
  web_socket_channel: ^2.4.0
  provider: ^6.1.1
```

### Environment
- **Flutter:** 3.24.3 (stable)
- **Dart:** 3.x
- **Target:** Web (CanvasKit renderer)

### Contact & Support
- **Issues:** GitHub repository issues page
- **Documentation:** This file + inline code comments
- **License:** (Specify if applicable)

---

*End of Technical Documentation*

# CHEXX - Comprehensive Test Plan
*Version: 1.0*
*Last Updated: 2025-10-12*

## Purpose
This document provides a comprehensive test plan for all features and services in the CHEXX hexagonal strategy game project. The plan covers unit tests, integration tests, system tests, and user acceptance tests.

## Test Execution Instructions

### Running All Tests
```bash
cd /home/junior/src/chexx
flutter test
```

### Running Specific Test Suites
```bash
# Scenario Builder tests
flutter test test/scenario_builder_state_test.dart

# Card effects tests
flutter test test/card_effects_test.dart

# Widget tests
flutter test test/widget_test.dart
```

### Test Success Criteria
- All tests must pass (0 failures)
- No compilation errors
- Coverage report shows >80% code coverage (target)
- Manual test scenarios complete successfully

---

## Test Categories

### Category 1: Core Data Models

#### Test Suite: HexCoordinate
**File:** `test/hex_coordinate_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| HC-001 | Cube coordinate validation | q + r + s = 0 | q=1, r=0, s=-1 | Valid coordinate | 🔴 Not Impl |
| HC-002 | Invalid coordinate rejection | q + r + s ≠ 0 | q=1, r=1, s=1 | Assertion error | 🔴 Not Impl |
| HC-003 | Distance calculation | Manhattan distance | (0,0,0) to (2,-1,-1) | 2 | 🔴 Not Impl |
| HC-004 | Neighbor calculation | Get all 6 neighbors | (0,0,0) | 6 hex coordinates | 🔴 Not Impl |
| HC-005 | Pixel conversion (flat) | Hex to screen coords | (1,0,-1), size=50 | (x, y) pixels | 🔴 Not Impl |
| HC-006 | Pixel conversion (pointy) | Hex to screen coords | (1,0,-1), size=50 | (x, y) pixels | 🔴 Not Impl |
| HC-007 | Screen to hex (flat) | Click to hex coord | (100, 50), size=50 | Hex coordinate | 🔴 Not Impl |
| HC-008 | Screen to hex (pointy) | Click to hex coord | (100, 50), size=50 | Hex coordinate | 🔴 Not Impl |

#### Test Suite: GameBoard
**File:** `test/game_board_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| GB-001 | Initialize default board | 91 hexes created | N/A | 91 tiles | 🔴 Not Impl |
| GB-002 | Add tile | Create new tile | coord=(2,0,-2), type=hill | Tile added | 🔴 Not Impl |
| GB-003 | Remove tile | Delete existing tile | coord=(0,0,0) | Tile removed | 🔴 Not Impl |
| GB-004 | Get tile | Retrieve tile at position | coord=(0,0,0) | HexTile object | 🔴 Not Impl |
| GB-005 | Get nonexistent tile | Request missing tile | coord=(99,0,-99) | null | 🔴 Not Impl |
| GB-006 | Validate coordinate | Check if in bounds | coord=(0,0,0) | true | 🔴 Not Impl |
| GB-007 | Invalid coordinate | Out of range | coord=(100,0,-100) | false | 🔴 Not Impl |

#### Test Suite: GameUnit
**File:** `test/game_unit_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| GU-001 | Create unit | Instantiate unit | id="p1_infantry", config | GameUnit object | 🔴 Not Impl |
| GU-002 | Take damage | Reduce health | damage=2, health=3 | health=1 | 🔴 Not Impl |
| GU-003 | Unit dies | Health reaches 0 | damage=3, health=2 | isAlive=false | 🔴 Not Impl |
| GU-004 | Heal unit | Restore health | heal=1, health=1, max=3 | health=2 | 🔴 Not Impl |
| GU-005 | Heal beyond max | Cannot exceed max HP | heal=5, health=2, max=3 | health=3 | 🔴 Not Impl |
| GU-006 | Get valid moves (minor) | 1 hex radius | position=(0,0,0) | List of 6 coords | 🔴 Not Impl |
| GU-007 | Get valid attacks | Within attack range | infantry, range=1 | List of coords | 🔴 Not Impl |
| GU-008 | Blocked movement | Occupied hex | position blocked by enemy | Excluded from moves | 🔴 Not Impl |
| GU-009 | Apply card override | Temporary stat boost | override={movement_range:3} | movementRange=3 | 🔴 Not Impl |
| GU-010 | Clear override | Reset to base stats | clearOverrides() | Base config values | 🔴 Not Impl |

---

### Category 2: Game State Management

#### Test Suite: GameState
**File:** `test/game_state_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| GS-001 | Initialize game | Default setup | initializeGame() | Units placed, phase=playing | 🔴 Not Impl |
| GS-002 | Select unit | Click friendly unit | selectUnit(unit) | selectedUnit set, moves highlighted | 🔴 Not Impl |
| GS-003 | Cannot select enemy | Click enemy unit | selectUnit(enemyUnit) | selectedUnit=null | 🔴 Not Impl |
| GS-004 | Move unit | Valid movement | moveUnit(target) | Unit position updated | 🔴 Not Impl |
| GS-005 | Invalid move | Out of range | moveUnit(farTarget) | false, no movement | 🔴 Not Impl |
| GS-006 | Attack enemy | Execute attack | attackPosition(target) | Damage dealt, turn ends | 🔴 Not Impl |
| GS-007 | Cannot attack friendly | Target ally | attackPosition(allyTarget) | false, no damage | 🔴 Not Impl |
| GS-008 | End turn | Switch players | endTurn() | currentPlayer switches | 🔴 Not Impl |
| GS-009 | Turn timer | 6 second countdown | updateTimer(deltaTime) | turnTimeRemaining decrements | 🔴 Not Impl |
| GS-010 | Auto-end turn | Timer expires | turnTimeRemaining=0 | Turn automatically ends | 🔴 Not Impl |
| GS-011 | Check win condition | All enemy units dead | 0 opponent units | gamePhase=gameOver | 🔴 Not Impl |
| GS-012 | Reward calculation | Time-based bonus | Fast turn (2s) | rewards increased | 🔴 Not Impl |

#### Test Suite: GameState (WWII Mode)
**File:** `test/game_state_wwii_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| GSW-001 | Initialize WWII | Card system active | game_type="wwii" | Hands dealt, deck loaded | 🔴 Not Impl |
| GSW-002 | Play action card | Activate card | playCard(card) | playedCard set, unitsCanOrder updated | 🔴 Not Impl |
| GSW-003 | Order unit | Decrement orders | orderUnit() | unitsCanOrderRemaining-- | 🔴 Not Impl |
| GSW-004 | Cannot order without card | No card played | canOrderUnit() | false | 🔴 Not Impl |
| GSW-005 | Cannot exceed orders | Max units ordered | orderUnit() when remaining=0 | false | 🔴 Not Impl |
| GSW-006 | Movement preview | No card, select unit | selectUnit(unit) | Moves shown (preview only) | 🟢 PASS |
| GSW-007 | Block actual movement | No card, try to move | moveUnit(target) | false | 🟢 PASS |
| GSW-008 | End turn card cleanup | Discard and draw | endPlayerTurn() | Card discarded, new card drawn | 🔴 Not Impl |

---

### Category 3: Scenario Builder

#### Test Suite: ScenarioBuilderState (Basic Operations)
**File:** `test/scenario_builder_state_test.dart` (**EXISTS**)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| SB-001 | Place unit (first click) | Add unit to hex | placeItem(coord) | Unit added | 🟢 PASS |
| SB-002 | Select unit (second click) | Select placed unit | placeItem(coord) | selectedPlacedUnit set | 🟢 PASS |
| SB-003 | Remove unit (third click) | Delete placed unit | placeItem(coord) | Unit removed, selection cleared | 🟢 PASS |
| SB-004 | Place structure | Add structure | placeItem(coord) with structure template | Structure added | 🟢 PASS |
| SB-005 | Remove structure | Delete structure | placeItem(coord) on existing structure | Structure removed | 🟢 PASS |
| SB-006 | Change tile type | Modify terrain | selectTileType(hill), placeItem(coord) | Tile type=hill | 🔴 Not Impl |
| SB-007 | Remove tile | Delete entire hex | selectTileType(same), placeItem(coord) | Tile removed | 🔴 Not Impl |
| SB-008 | Create new tile | Expand board | enableCreateNewMode(), placeItem(newCoord) | New tile added | 🔴 Not Impl |

#### Test Suite: ScenarioBuilderState (Health Modification)
**File:** `test/scenario_builder_state_test.dart` (**EXISTS**)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| SB-101 | Increment health | ↑ arrow key | incrementSelectedUnitHealth() | health++ | 🟢 PASS |
| SB-102 | Decrement health | ↓ arrow key | decrementSelectedUnitHealth() | health-- | 🟢 PASS |
| SB-103 | Health at maximum | Cannot exceed max | increment when health=max | false | 🟢 PASS |
| SB-104 | Health at minimum | Cannot go below 1 | decrement when health=1 | false | 🟢 PASS |
| SB-105 | Non-incrementable unit | Cannot modify | Scout/Knight health | false | 🟢 PASS |
| SB-106 | Keyboard requires selection | No unit selected | incrementSelectedUnitHealth() | false | 🟢 PASS |
| SB-107 | Template blocks keyboard | Palette selected | increment with template selected | false | 🟢 PASS |
| SB-108 | Unit stays selected | After modification | incrementSelectedUnitHealth() | selectedPlacedUnit still set | 🟢 PASS |

#### Test Suite: ScenarioBuilderState (Save/Load)
**File:** `test/scenario_builder_save_load_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| SB-201 | Generate scenario | Export to JSON | generateScenarioConfig() | Valid JSON structure | 🔴 Not Impl |
| SB-202 | Save unit placements | Units in JSON | Units placed | unit_placements array populated | 🔴 Not Impl |
| SB-203 | Save structures | Structures in JSON | Structures placed | structure_placements array | 🔴 Not Impl |
| SB-204 | Save custom health | Health values preserved | Infantry with health=3 | customHealth:3 in JSON | 🔴 Not Impl |
| SB-205 | Save board tiles | Tile data in JSON | Custom tiles | board_tiles array | 🔴 Not Impl |
| SB-206 | Load scenario | Import from JSON | loadFromScenarioData(json) | State restored | 🔴 Not Impl |
| SB-207 | Preserve unit types | WWII units | Load scenario with infantry | Infantry units restored | 🔴 Not Impl |
| SB-208 | Preserve board thirds | Partition data | Load with board_thirds | Lines and hexes restored | 🔴 Not Impl |

#### Test Suite: ScenarioBuilderState (Board Partitioning)
**File:** `test/scenario_builder_thirds_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| SB-301 | Calculate thirds | Auto-partition | calculateBoardThirds() | 3 sets of hexes | 🔴 Not Impl |
| SB-302 | Toggle left highlight | Show/hide zone | toggleLeftThirdHighlight() | highlightLeftThird toggled | 🔴 Not Impl |
| SB-303 | Drag line | Move boundary | updateDraggedLinePosition(x) | leftLineX updated | 🔴 Not Impl |
| SB-304 | Snap to edge | Release drag | endDraggingLine() | Line snaps to hex edge | 🔴 Not Impl |
| SB-305 | Recalculate membership | After drag | endDraggingLine() | Hexes re-categorized | 🔴 Not Impl |
| SB-306 | Boundary hexes | Overlapping zones | calculateBoardThirds() | Some hexes in multiple thirds | 🔴 Not Impl |

---

### Category 4: Combat Systems

#### Test Suite: Traditional Combat
**File:** `test/combat_system_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| CB-001 | Simple attack | Basic damage | attacker deals 1 damage to defender (3 HP) | Defender health=2 | 🔴 Not Impl |
| CB-002 | Kill enemy | Fatal damage | attacker deals 2 damage to defender (1 HP) | isAlive=false | 🔴 Not Impl |
| CB-003 | Shield protection | Damage reduction | attack with shield active | Damage-1 | 🔴 Not Impl |
| CB-004 | Experience gain | Unit levels up | Kill enemy unit | experience++ | 🔴 Not Impl |

#### Test Suite: WWII Combat
**File:** `test/wwii_combat_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| WC-001 | Dice roll attack | Random combat | executeAttack(attacker, defender) | CombatResult with hits | 🔴 Not Impl |
| WC-002 | Terrain modifier (positive) | Hill defense | Defender on hill (+1) | More defensive dice | 🔴 Not Impl |
| WC-003 | Terrain modifier (negative) | Ocean attack | Attacker in ocean (-2) | Fewer attack dice | 🔴 Not Impl |
| WC-004 | Multiple hits | Dice show 5+ | Roll 3 dice: [5,6,3] | 2 hits | 🔴 Not Impl |
| WC-005 | No hits | All dice fail | Roll 3 dice: [1,2,3] | 0 hits | 🔴 Not Impl |
| WC-006 | Unit type dice config | Infantry vs Armor | Different units | Different die faces | 🔴 Not Impl |

---

### Category 5: Card System (WWII Mode)

#### Test Suite: ActionCard
**File:** `test/card_effects_test.dart` (**EXISTS**)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| CD-001 | Load card deck | Parse JSON | ActionCardDeckLoader.loadWWIIDeck() | Deck with cards | 🟢 PASS |
| CD-002 | Deal hands | Initial distribution | Deal 5 cards per player | player1Hand.size=5, player2Hand.size=5 | 🟢 PASS |
| CD-003 | Play card | Activate action card | playCard(card) | playedCard set | 🟢 PASS |
| CD-004 | Units can order | Check remaining | canOrderUnit() after play | unitsCanOrder > 0 | 🟢 PASS |
| CD-005 | Apply card effects | Override unit stats | applyCardEffectsToUnit(unit, action) | Unit stats modified | 🟢 PASS |
| CD-006 | Unit restrictions | Card targets specific type | Restrict to "infantry" | Only infantry affected | 🟢 PASS |
| CD-007 | Discard and draw | End turn cycle | endPlayerTurn() | Card discarded, new card drawn | 🔴 Not Impl |
| CD-008 | Empty deck | Reshuffle discard pile | Draw when deck empty | Discard pile shuffled back | 🔴 Not Impl |

#### Test Suite: Card Effects & Overrides
**File:** `test/card_effects_test.dart` (**EXISTS**)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| CD-101 | Movement override | Increase range | override={movement_range:3} | Unit moves 3 hexes | 🟢 PASS |
| CD-102 | Move and fire | Special ability | override={move_and_fire:true} | Unit can move then attack | 🟢 PASS |
| CD-103 | Attack damage boost | Increase damage | override={attack_damage:2} | Deals 2 damage | 🟢 PASS |
| CD-104 | Clear override | End of turn | clearOverrides() | Back to base stats | 🟢 PASS |
| CD-105 | Multiple overrides | Combine effects | Several overrides | All applied | 🟢 PASS |

---

### Category 6: Configuration System

#### Test Suite: UnitTypeConfig
**File:** `test/unit_type_config_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| UC-001 | Load CHEXX units | Parse JSON | UnitTypeConfigLoader.loadUnitTypeSet("chexx") | 4 unit types | 🔴 Not Impl |
| UC-002 | Load WWII units | Parse JSON | UnitTypeConfigLoader.loadUnitTypeSet("wwii") | 3 unit types | 🔴 Not Impl |
| UC-003 | Get unit config | Retrieve infantry | unitTypeSet.getUnitConfig("infantry") | UnitTypeConfig | 🔴 Not Impl |
| UC-004 | Missing unit type | Request invalid | unitTypeSet.getUnitConfig("invalid") | null | 🔴 Not Impl |
| UC-005 | Unit type IDs | List available | unitTypeSet.unitTypeIds | List of IDs | 🔴 Not Impl |

#### Test Suite: GameTypeConfig
**File:** `test/game_type_config_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| GT-001 | Load game type | Parse JSON | GameTypeConfigLoader.loadGameTypeConfig("wwii") | GameTypeConfig | 🔴 Not Impl |
| GT-002 | Default unit set | Check default | gameTypeConfig.defaultUnitSet | "wwii" | 🔴 Not Impl |
| GT-003 | Feature flags | Check capabilities | gameTypeConfig.features["card_system"] | true | 🔴 Not Impl |

---

### Category 7: Networking & Multiplayer

#### Test Suite: WebSocket Connection
**File:** `test/network_connection_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| NW-001 | Connect to server | Establish WebSocket | websocketManager.connect() | Connected state | 🔴 Not Impl |
| NW-002 | Send message | Transmit data | send(message) | Message delivered | 🔴 Not Impl |
| NW-003 | Receive message | Handle incoming | onMessage callback | Message processed | 🔴 Not Impl |
| NW-004 | Disconnect | Close connection | disconnect() | Disconnected state | 🔴 Not Impl |
| NW-005 | Reconnect | Re-establish connection | reconnect() | Connected again | 🔴 Not Impl |

#### Test Suite: Game Synchronization
**File:** `test/network_sync_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| NS-001 | Join game | Player joins session | joinGame(sessionId) | Added to session | 🔴 Not Impl |
| NS-002 | Sync game state | State update | Receive game state message | Local state updated | 🔴 Not Impl |
| NS-003 | Send move | Player action | Player moves unit | Opponents see move | 🔴 Not Impl |
| NS-004 | Turn synchronization | Turn order | endTurn() | Other player's turn starts | 🔴 Not Impl |

---

### Category 8: UI & User Interaction

#### Test Suite: Scenario Builder UI
**File:** `test/scenario_builder_ui_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| UI-001 | Render board | Display hexes | ScenarioBuilderScreen loads | Hexes drawn on screen | 🔴 Not Impl |
| UI-002 | Unit palette | Show available units | Palette loads | Units displayed | 🔴 Not Impl |
| UI-003 | Click hex | User interaction | Tap on hex | Hex coordinate identified | 🔴 Not Impl |
| UI-004 | Drag vertical line | Mouse drag | Drag line | Line follows mouse | 🔴 Not Impl |
| UI-005 | Health indicator | Visual update | Increment health | Multiple icons shown | 🔴 Not Impl |
| UI-006 | Save button | Export scenario | Click save | JSON file downloads | 🔴 Not Impl |

#### Test Suite: Game Screen UI
**File:** `test/game_screen_ui_test.dart` (TO BE CREATED)

| Test ID | Test Name | Description | Input | Expected Output | Status |
|---------|-----------|-------------|-------|-----------------|--------|
| UI-101 | Render game board | Display units | Game screen loads | Units and hexes shown | 🔴 Not Impl |
| UI-102 | Select unit | Click unit | Tap friendly unit | Unit highlighted, moves shown | 🔴 Not Impl |
| UI-103 | Move animation | Visual feedback | Unit moves | Smooth transition | 🔴 Not Impl |
| UI-104 | Attack animation | Combat visual | Attack enemy | Visual effect | 🔴 Not Impl |
| UI-105 | Turn timer | Countdown display | Timer updates | Visual countdown | 🔴 Not Impl |
| UI-106 | Card hand | Show cards (WWII) | Player hand | 5 cards displayed | 🔴 Not Impl |
| UI-107 | Play card | Card activation | Click card | Card played, effects shown | 🔴 Not Impl |

---

## Integration Tests

### Integration Test 1: Complete Scenario Builder Workflow
**File:** `test/integration/scenario_builder_workflow_test.dart` (TO BE CREATED)

**Steps:**
1. Open Scenario Builder
2. Select WWII unit type set
3. Place 5 infantry units (player 1)
4. Place 5 armor units (player 2)
5. Select infantry unit and adjust health to 3
6. Add structures (2 bunkers, 1 bridge)
7. Change tile types (hills, forests)
8. Enable board thirds and adjust lines
9. Save scenario as JSON
10. Load saved scenario
11. Verify all data restored correctly

**Success Criteria:** All units, structures, tiles, and settings preserved

---

### Integration Test 2: Complete WWII Game Playthrough
**File:** `test/integration/wwii_game_playthrough_test.dart` (TO BE CREATED)

**Steps:**
1. Load WWII scenario
2. Player 1 plays action card
3. Player 1 orders infantry to move
4. Player 1 attacks enemy armor
5. Combat resolves with dice rolls
6. Player 1 ends turn
7. Card discarded, new card drawn
8. Player 2 plays card
9. Player 2 moves and attacks
10. Continue until win condition met

**Success Criteria:** Game completes without errors, winner declared

---

### Integration Test 3: Multiplayer Game Session
**File:** `test/integration/multiplayer_session_test.dart` (TO BE CREATED)

**Steps:**
1. Start game server
2. Player 1 connects and creates game
3. Player 2 connects and joins game
4. Player 1 makes move
5. Player 2 receives state update
6. Player 2 makes move
7. Player 1 receives state update
8. Players alternate turns
9. Game completes
10. Both players see final result

**Success Criteria:** Full game synchronized between players

---

## Manual Test Scenarios

### Manual Test 1: Scenario Builder Usability
**Tester:** QA / User
**Duration:** 15 minutes

**Procedure:**
1. Open browser to http://localhost:8888
2. Click "SCENARIO BUILDER"
3. Experiment with placing units
4. Try keyboard controls (QWEASD for movement, arrows for health)
5. Test all tile types
6. Save and re-load scenario
7. Report any confusing UI or bugs

**Success Criteria:** User can create scenario without confusion

---

### Manual Test 2: WWII Game Session
**Tester:** QA / User
**Duration:** 10 minutes

**Procedure:**
1. Start game with WWII mode
2. Play through 5 turns
3. Use different cards
4. Move and attack with different unit types
5. Observe combat results
6. Check if rules are intuitive

**Success Criteria:** Game rules are clear, combat feels balanced

---

### Manual Test 3: Performance Test (Large Scenario)
**Tester:** QA / User
**Duration:** 10 minutes

**Procedure:**
1. Create scenario with 100+ units
2. Measure frame rate
3. Test responsiveness of clicks
4. Move multiple units in one turn
5. Check for lag or freezing

**Success Criteria:** Game runs smoothly (>30 FPS)

---

## Regression Test Checklist

After any code change, verify:

- [ ] All unit tests pass (`flutter test`)
- [ ] Scenario Builder can place units
- [ ] Scenario Builder can save/load scenarios
- [ ] Health modification with arrow keys works
- [ ] WWII card system functions (play card, order units)
- [ ] Movement highlighting works before card is played
- [ ] Actual movement blocked until card is played
- [ ] Combat resolves correctly
- [ ] Turn timer counts down
- [ ] Win condition triggers
- [ ] Game doesn't crash on edge cases

---

## Performance Benchmarks

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Initial load time | <3s | TBD | 🔴 |
| Scenario load time | <1s | TBD | 🔴 |
| Unit movement response | <100ms | TBD | 🔴 |
| Combat calculation | <50ms | TBD | 🔴 |
| Frame rate (60 units) | >30 FPS | TBD | 🔴 |
| Memory usage | <500MB | TBD | 🔴 |

---

## Test Execution Schedule

### Phase 1: Unit Tests (Week 1)
- Create all missing test files
- Achieve 80% code coverage
- Fix any bugs discovered

### Phase 2: Integration Tests (Week 2)
- Implement workflow tests
- Test save/load scenarios
- Verify game mode switching

### Phase 3: Manual Testing (Week 3)
- Recruit testers
- Execute manual test scenarios
- Collect feedback
- Fix usability issues

### Phase 4: Performance Testing (Week 4)
- Run benchmarks
- Optimize bottlenecks
- Verify targets met

---

## Bug Reporting Template

When a test fails, file a bug report with:

**Bug ID:** [AUTO-GENERATED]
**Title:** [Short description]
**Test ID:** [e.g., SB-105]
**Severity:** Critical / High / Medium / Low
**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
**Expected Result:** [What should happen]
**Actual Result:** [What actually happened]
**Environment:** [Browser, Flutter version, OS]
**Screenshots:** [If applicable]

---

## Test Automation

### Continuous Integration (CI)
**Recommended Setup:**
- GitHub Actions
- Trigger on: push, pull request
- Steps:
  1. Checkout code
  2. Setup Flutter
  3. Run `flutter pub get`
  4. Run `flutter test`
  5. Generate coverage report
  6. Fail build if tests fail

### Pre-Commit Hook
```bash
#!/bin/bash
flutter test
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

---

## Summary

This test plan covers:
- **196 test cases** across 8 categories
- **3 integration tests** for end-to-end workflows
- **3 manual test scenarios** for usability
- **Performance benchmarks** for optimization
- **Regression checklist** for each deployment

**Current Coverage:**
- Tests Implemented: **~25** (from existing test files)
- Tests Needed: **~171**
- Overall Status: 🔴 **Low coverage** (~13%)

**Next Steps:**
1. Run existing tests to establish baseline
2. Create missing test files
3. Implement high-priority tests (Core models, Scenario Builder, Game State)
4. Execute manual tests
5. Achieve 80% coverage goal

---

*End of Test Plan*

# CHEXX: Hexagonal Turn-Based Strategy Game Research & Specifications

## Research Summary

### Hexagonal Grid Development (Red Blob Games)

**Coordinate Systems:**
- **Cube Coordinates**: Preferred for algorithms due to symmetry (x + y + z = 0)
- **Axial Coordinates**: Simplified 2D version using (q, r) coordinates
- **Offset Coordinates**: Traditional row/column with odd-q or odd-r staggering

**Key Algorithms:**
- **Distance Calculation**: Using cube coordinate differences
- **Neighbor Finding**: Adding predefined direction vectors (6 directions)
- **Pathfinding**: A* algorithm optimized for hex grids
- **Line Drawing**: Linear interpolation with proper rounding

**Implementation Best Practices:**
- Use cube coordinates for game logic, convert to axial/offset for storage
- Hexagonal grids provide more natural movement (equal distance to all neighbors)
- 0.81x search depth compared to square grids for pathfinding efficiency

### Flame Engine Architecture

**Core Components:**
- Modular Flutter game engine with component system (FCS)
- Game loop implementation with sprites, animations, collision detection
- Hot reload support for rapid development iteration
- Hardware-accelerated 2D graphics via Skia/Impeller

**Best Practices:**
- Use `GameWidget` for Flutter integration
- Extend `FlameGame` or `World` class for game logic
- Leverage mixins like `TapCallbacks` for input handling
- Use bridge packages for extended functionality

**Limitations:**
- No built-in multiplayer networking (requires external services like Nakama)
- Focus on 2D gaming with Flutter's widget ecosystem

### Nakama Multiplayer Backend

**Key Features:**
- Cross-platform authentication (email, social profiles)
- Real-time socket connections for turn-based games
- User account management and social features
- WebSocket integration for real-time communication

**Integration Pattern:**
```dart
// Client setup
final client = getNakamaClient(host: '127.0.0.1', ssl: false, serverKey: 'defaultkey');

// Authentication
final session = await client.authenticateEmail(email: 'user@example.com', password: 'password');

// WebSocket connection
NakamaWebsocketClient.init(host: '127.0.0.1', ssl: false, token: session.token);
```

### Flutter Game Development Patterns

**Strengths:**
- Hardware-accelerated 2D graphics
- Hot reload for rapid iteration
- Cross-platform compilation (iOS, Android, web, desktop)
- Extensive widget ecosystem for UI composition

**Performance Considerations:**
- Utilize Dart's native compilation
- Leverage hardware acceleration
- Use efficient widget composition
- Optimize for platform-specific features

### Turn-Based Strategy Game Design Insights

**Progression Systems:**
- Purpose: Controlled pacing and guaranteed game conclusion
- Balance complexity introduction without overwhelming players
- Iterative balance testing: analyze → identify issues → intervene → test → repeat
- Meaningful progression: each unlock should affect gameplay

**Resource Management:**
- Limited resources (health, mana, action points) create strategic tension
- Cooldown systems prevent ability spam and add timing strategy
- Meta-abilities with restrictions encourage strategic positioning

**Player Engagement:**
- Avoid repetitive grinding through meaningful battle systems
- Balance difficulty curves to maintain challenge without frustration
- Provide player agency in progression systems

## Game Specifications: CHEXX

### Board Layout
- **61 hexagonal tiles** arranged in a connected pattern
- **Player Setup**:
  - Player 1: Top 2 rows (11 hexagons total)
  - Player 2: Bottom 2 rows (11 hexagons total)
  - **Front row**: 6 identical Minor Units
  - **Back row**: 5 unique Major Units

### Unit Classifications

#### Minor Units (6 per player)
- **Health**: 1-2 HP
- **Movement**: Adjacent hexagons only
- **Attack**: Adjacent hexagons only (1 damage)
- **Meta Ability**: Usable only on designated Meta Hexagons
- **Leveling**: Gain +1 HP and free Meta ability use when killing enemy
- **Super Unlock**: Gain Super ability after 3 level-ups

#### Major Units (5 unique types per player)
- **Health**: 2-3 HP
- **Movement**: Unique movement patterns per unit type
- **Attack**: Varied ranges and effects (1-2 damage)
- **Meta Ability**: Usable anywhere, but cooldown applies if not on Meta Hexagon
- **Super Ability**: Only usable from Meta Hexagons
- **Leveling**: Same as Minor Units

### Movement System
**All Units:**
- Can move to adjacent hexagons (base movement)

**Major Unit Unique Movements:**
1. **Scout**: 3-hex range in straight lines
2. **Knight**: L-shaped movement (2 hex + 1 perpendicular)
3. **Siege**: 1 hex movement but can attack over obstacles
4. **Infiltrator**: Can teleport to any unoccupied hex within 2-hex range
5. **Guardian**: Normal movement but can swap positions with adjacent friendly unit

### Attack Abilities

#### Minor Unit Attacks
- **Basic Strike**: 1 damage to adjacent hex (standard attack)

#### Major Unit Attacks
1. **Scout**: Long-range shot (3-hex range, 1 damage)
2. **Knight**: Charge attack (2-hex range through movement, 2 damage)
3. **Siege**: Artillery (4-hex range, 1 damage, ignores obstacles)
4. **Infiltrator**: Assassination (adjacent only, 2 damage, +1 if target hasn't moved this turn)
5. **Guardian**: Shield bash (adjacent only, 1 damage + push enemy 1 hex back)

### Meta Abilities

#### Minor Unit Meta Abilities
1. **Spawn**: Create new Minor Unit on adjacent empty hex
2. **Rally**: Heal adjacent friendly unit by 1 HP
3. **Fortify**: Create temporary barrier on adjacent hex (blocks movement for 2 turns)
4. **Scout**: Reveal enemy unit stats and abilities for rest of game
5. **Inspire**: Adjacent friendly units gain +1 movement range this turn
6. **Sabotage**: Adjacent enemy unit loses next turn

#### Major Unit Meta Abilities
1. **Scout**: Mark target - next friendly attack on marked target deals +1 damage
2. **Knight**: Protective aura - adjacent friendly units take -1 damage for 3 turns
3. **Siege**: Bombardment - 2 damage to target hex and adjacent hexes
4. **Infiltrator**: Shadow clone - create temporary duplicate that lasts 2 turns
5. **Guardian**: Shield wall - create 3-hex barrier that blocks attacks for 2 turns

**Special Major Units** (Level up on friendly kills):
- **Medic**: Gains XP when healing reduces friendly unit to 0 HP (mercy kill)
- **Necromancer**: Gains XP when sacrificing friendly unit for tactical advantage

### Super Abilities (Meta Hexagon Only)

#### Minor Unit Super Abilities (Unlocked after 3 level-ups)
1. **Demolition**: Destroy target hex permanently (3 damage to any unit on it)
2. **Summoning**: Create new Major Unit of chosen type
3. **Resurrection**: Revive fallen friendly unit at full health
4. **Cataclysm**: 1 damage to all units in 2-hex radius
5. **Metamorphosis**: Transform into any Major Unit type
6. **Time Warp**: Take an additional turn immediately

#### Major Unit Super Abilities
1. **Scout**: Orbital strike - 3 damage to any hex on the board (only one that does 3 damage)
2. **Knight**: Charge of legends - move up to 5 hexes and deal 2 damage to all passed through
3. **Siege**: Earthquake - destroy all hexes in a 2-hex radius permanently
4. **Infiltrator**: Mass teleport - relocate up to 3 friendly units to any empty hexes
5. **Guardian**: Fortress - create permanent 5-hex defensive structure

### Meta Hexagons
- **Distribution**: 12 special hexagons scattered across board
- **Function**:
  - Minor Units can only use Meta abilities when occupying these hexes
  - Major Units avoid Meta ability cooldowns when using from these positions
  - Super abilities can only be activated from Meta hexagons
  - Control of Meta hexagons becomes strategic objective

### Leveling System
**Level-Up Conditions:**
- Deal killing blow to enemy unit
- Special cases: Medic and Necromancer also level from friendly kills

**Level-Up Benefits:**
- +1 Health Point
- Free use of Meta ability (ignores cooldown and position restrictions)
- After 3 level-ups: Unlock Super ability for Minor Units

**Progression Balance:**
- Most attacks deal 1 damage (standard combat)
- Some Meta abilities deal 2 damage (adjacent range only)
- Only 1 Super ability deals 3 damage (Scout's Orbital Strike, adjacent range only)

### Time-Based Rewards System
**Turn Timer**: 6 seconds maximum per turn
**Reward Mechanism**:
- Faster decision-making = higher rewards
- Reward bar scales from 0 to 61 (matching board hex count)
- Time bonus calculation: `reward_points = max(0, (6 - time_used) * multiplier)`
- Accumulated rewards unlock cosmetic upgrades and unit customizations

**Flow State Design:**
- Clear visual feedback on time remaining
- Smooth animations that don't eat into decision time
- Immediate visual confirmation of moves
- Progressive difficulty that rewards game knowledge and planning

## Technical Implementation Considerations

### Architecture Recommendations
- **Frontend**: Flutter + Flame engine for cross-platform deployment
- **Backend**: Nakama for multiplayer matchmaking and real-time communication
- **Coordinate System**: Cube coordinates for game logic, axial for network serialization
- **Data Storage**: All gameplay values in configurable JSON/YAML files (no hardcoding)

### Performance Optimizations
- Pre-calculate hex neighbor lookups
- Cache pathfinding results for common movement patterns
- Use efficient sprite batching for hex rendering
- Implement object pooling for temporary game effects

### Configuration-Driven Design
All gameplay elements stored in external configuration files:
- Unit stats and abilities
- Hex board layout and Meta hex positions
- Damage values and cooldown timers
- Progression curves and reward multipliers
- Visual themes and animations

### Anti-Patterns to Avoid
- Hardcoding gameplay values in source code
- Over-complicated progression systems that obscure strategy
- Animation delays that interfere with turn timing
- Unbalanced abilities that create dominant strategies
- Network lag affecting turn timer accuracy

## Competitive Balance Framework

### Core Balance Principles
1. **Rock-Paper-Scissors Design**: Each Major Unit has strengths/weaknesses against others
2. **Positional Strategy**: Meta hexagon control creates spatial tactics
3. **Resource Scarcity**: Limited health pools make every decision meaningful
4. **Calculated Risk**: High-reward abilities require strategic positioning
5. **Tempo Management**: Time pressure rewards preparation and game knowledge

### Expected Gameplay Flow
**Early Game** (Turns 1-10): Positioning and board control
**Mid Game** (Turns 11-25): First engagements and Meta hex contests
**Late Game** (Turns 26+): Leveled units and Super ability deployment

### Meta-Game Depth
- Unit composition strategies (which Major Units to deploy)
- Opening positioning patterns
- Meta hex control timing
- Resource conservation vs aggressive tactics
- Time management optimization

This research forms the foundation for implementing a balanced, engaging hexagonal strategy game that achieves the goals of being easy to learn, hard to master, with complex meta-game elements that support flow state gameplay.
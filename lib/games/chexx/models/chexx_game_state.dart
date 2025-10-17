import 'dart:math';
import 'package:oxygen/oxygen.dart';
import '../../../core/models/game_state_base.dart';
import '../../../core/models/hex_coordinate.dart' as core_hex;
import '../../../core/interfaces/unit_factory.dart';
import '../../../core/components/position_component.dart';
import '../../../core/components/health_component.dart';
import '../../../core/components/owner_component.dart';
import '../../../core/components/unit_type_component.dart';
import '../../../core/components/movement_component.dart';
import '../../../core/components/combat_component.dart';
import '../../../core/components/selection_component.dart';
import '../../../core/models/game_config.dart';
import '../../../src/models/game_board.dart';
import '../../../src/models/hex_coordinate.dart' as src_hex;
import '../../../src/models/hex_orientation.dart';
import '../../../src/models/scenario_builder_state.dart';
import '../../../src/systems/combat/die_faces_config.dart';

/// Structure placed in the game (using core HexCoordinate for compatibility)
class GameStructure {
  final StructureType type;
  final core_hex.HexCoordinate position;
  final String id;
  final Player? player; // Which player can earn victory points from this medal

  const GameStructure({
    required this.type,
    required this.position,
    required this.id,
    this.player,
  });
}

/// Simple unit representation for temporary use
class SimpleGameUnit {
  final String id;
  final String unitType;
  final Player owner;
  final core_hex.HexCoordinate position;
  final int health;
  final int maxHealth;
  final int remainingMovement;
  final int moveAfterCombat;
  bool isSelected;

  SimpleGameUnit({
    required this.id,
    required this.unitType,
    required this.owner,
    required this.position,
    required this.health,
    required this.maxHealth,
    required this.remainingMovement,
    this.moveAfterCombat = 0,
    this.isSelected = false,
  });
}

/// CHEXX-specific game state implementation
class ChexxGameState extends GameStateBase {
  // CHEXX-specific state
  int player1Rewards = 0;
  int player2Rewards = 0;

  // Point tracking and win conditions
  int player1Points = 0;
  int player2Points = 0;
  int player1WinPoints = 10;
  int player2WinPoints = 10;

  // Victory point tracking for medals
  int player1VictoryPoints = 0;
  int player2VictoryPoints = 0;
  Map<core_hex.HexCoordinate, Player> medalVictoryPoints = {}; // Track which medals are currently controlled

  // Hex orientation for rendering
  HexOrientation hexOrientation = HexOrientation.flat;

  // Game board
  final GameBoard board = GameBoard();

  // Temporary: Simple unit storage until ECS is working
  List<SimpleGameUnit> simpleUnits = [];

  // Structures storage
  List<GameStructure> placedStructures = [];

  // Dice roll state for combat display
  List<DieFace>? lastDiceRolls;
  String? lastCombatResult;
  DateTime? lastCombatTime;

  // Game mode tracking
  String? gameMode;

  // Card mode: track if a card action is currently active (allows unit ordering)
  bool isCardActionActive = false;

  // Card mode: hexes that should be highlighted for current action
  Set<core_hex.HexCoordinate> highlightedHexes = {};

  // Card mode: hex_tiles restriction for current action (e.g., "left third", "middle third", "right third")
  String? activeCardActionHexTiles;

  // Card mode: track which unit is performing the current card action
  String? activeCardActionUnitId;

  // Card mode: lock the unit after movement so combat must use same unit
  bool isCardActionUnitLocked = false;

  // Card mode: callback when unit is ordered (for completing card actions)
  void Function()? onUnitOrdered;

  // Card mode: callbacks for sub-step tracking
  void Function()? onUnitSelected;
  void Function()? onUnitMoved;
  void Function()? onCombatOccurred;
  void Function()? onAfterCombatMovement;

  // Card mode: track if we're waiting for after-combat movement decision
  bool isWaitingForAfterCombatMovement = false;

  // Card mode: track if last movement was move-only (beyond move_and_fire range)
  bool lastMoveWasMoveOnly = false;

  // Barbwire decision: track when unit moved onto barbwire and needs to decide
  bool isWaitingForBarbwireDecision = false;
  core_hex.HexCoordinate? barbwireDecisionHex;
  void Function()? onBarbwireRemove;
  void Function()? onBarbwireKeep;

  // Retreat system: track unit that must retreat and how many retreat dice rolled
  SimpleGameUnit? unitMustRetreat;
  int retreatDiceCount = 0;
  Set<core_hex.HexCoordinate> retreatHexes = {};
  bool isWaitingForRetreat = false;

  // Board partitioning: divide board into thirds with vertical lines (loaded from scenario)
  bool showVerticalLines = false; // Always true in game mode when thirds data is loaded
  Set<core_hex.HexCoordinate> leftThirdHexes = {};
  Set<core_hex.HexCoordinate> middleThirdHexes = {};
  Set<core_hex.HexCoordinate> rightThirdHexes = {};
  double leftLineX = 0.0;
  double rightLineX = 0.0;

  // Wayfinding: hexes reachable with move_and_fire (green)
  Set<core_hex.HexCoordinate> moveAndFireHexes = {};

  // Wayfinding: hexes reachable with move_only (yellow)
  Set<core_hex.HexCoordinate> moveOnlyHexes = {};

  // Attack range highlighting: hexes within attack range mapped to expected damage
  Map<core_hex.HexCoordinate, int> attackRangeHexes = {};

  // Targeted enemy unit for attack (requires two clicks: first to target, second to confirm)
  SimpleGameUnit? targetedEnemy;

  // Combat movement tracking
  Map<String, bool> unitUsedSpecialAttack = {}; // Track which tanks used special attack this turn
  Map<String, bool> unitCanSpecialAttack = {}; // Track which tanks can currently make special attack (after overrun)
  Map<String, int> unitMoveAfterCombatBonus = {}; // Track temporary move_after_combat bonuses from card actions

  // Card effect overrides - temporary attribute modifications from cards (cleared at end of turn)
  Map<String, Map<String, dynamic>> unitOverrides = {}; // unitId -> {attribute -> value}

  // Barrage action: store active barrage action metadata for direct combat
  Map<String, dynamic>? activeBarrageAction;

  @override
  void initializeGame() {
    gamePhase = GamePhase.playing;
    _setupInitialUnits();
    _calculateAvailableActions();
  }

  @override
  void initializeFromScenario(Map<String, dynamic> scenarioConfig) {
    print('DEBUG: INITIALIZE FROM SCENARIO START');
    print('DEBUG: Scenario config keys: ${scenarioConfig.keys.toList()}');
    print('DEBUG: Scenario config size: ${scenarioConfig.length}');

    // Extract and store game mode
    gameMode = scenarioConfig['game_type'] as String?;
    print('DEBUG: Game mode: $gameMode');

    gamePhase = GamePhase.playing;

    print('DEBUG: About to load board tiles from scenario');
    _loadBoardTilesFromScenario(scenarioConfig);
    print('DEBUG: Finished loading board tiles, total tiles now: ${board.allTiles.length}');

    print('DEBUG: About to load units from scenario');
    _loadUnitsFromScenario(scenarioConfig);
    print('DEBUG: Finished loading units, total units now: ${simpleUnits.length}');

    print('DEBUG: About to load structures from scenario');
    _loadStructuresFromScenario(scenarioConfig);
    print('DEBUG: Finished loading structures, total structures now: ${placedStructures.length}');

    print('DEBUG: About to load board thirds from scenario');
    _loadBoardThirdsFromScenario(scenarioConfig);
    print('DEBUG: Finished loading board thirds');

    print('DEBUG: About to load win conditions from scenario');
    _loadWinConditionsFromScenario(scenarioConfig);
    print('DEBUG: Finished loading win conditions');

    _calculateAvailableActions();
    print('DEBUG: INITIALIZE FROM SCENARIO END');
  }

  @override
  void resetGame() {
    // TODO: Clear all entities - need correct Oxygen 0.3.1 API
    // world.clear();

    // Reset state
    gamePhase = GamePhase.playing;
    currentPlayer = Player.player1;
    turnNumber = 1;
    turnPhase = TurnPhase.moving;
    turnTimeRemaining = 6.0;
    isPaused = false;
    winner = null;
    selectedEntity = null;
    availableMoves.clear();
    availableAttacks.clear();
    remainingMoves = 0;
    player1Rewards = 0;
    player2Rewards = 0;

    // Reinitialize
    initializeGame();
    notifyListeners();
  }

  @override
  void endTurn() {
    // Clear dice roll display
    clearDiceRoll();

    // Clear card effect overrides for all units (effects last only one turn)
    if (unitOverrides.isNotEmpty) {
      print('DEBUG: Clearing ${unitOverrides.length} unit override(s) at end of turn');
      unitOverrides.clear();
    }

    // Clear special attack tracking for new turn
    unitUsedSpecialAttack.clear();
    unitCanSpecialAttack.clear();

    // Switch players FIRST
    currentPlayer = currentPlayer == Player.player1 ? Player.player2 : Player.player1;

    if (currentPlayer == Player.player1) {
      turnNumber++;
    }

    // THEN reset movement for the NEW current player (whose turn is starting)
    _resetPlayerMovement();

    turnPhase = TurnPhase.moving;
    turnTimeRemaining = 6.0;
    deselectEntity();

    checkVictoryConditions();
    notifyListeners();
  }

  @override
  void skipAction() {
    if (turnPhase == TurnPhase.moving) {
      turnPhase = TurnPhase.acting;
    } else if (turnPhase == TurnPhase.acting) {
      endTurn();
    }
    notifyListeners();
  }

  @override
  void togglePause() {
    isPaused = !isPaused;
    notifyListeners();
  }

  @override
  void updateTimer(double deltaTime) {
    // Card mode has no time limit - turns only end with END TURN button
    if (gameMode == 'card') {
      return;
    }

    if (gamePhase == GamePhase.playing && !isPaused) {
      turnTimeRemaining -= deltaTime;
      if (turnTimeRemaining <= 0) {
        endTurn();
      }
    }
  }

  @override
  void selectEntity(Entity entity) {
    deselectEntity();
    selectedEntity = entity;

    // Add selection component
    final selectionComponent = SelectionComponent(isSelected: true);
    entity.add<SelectionComponent, SelectionComponent>(selectionComponent);

    _calculateAvailableActions();
    notifyListeners();
  }

  @override
  void deselectEntity() {
    if (selectedEntity != null) {
      final selection = selectedEntity!.get<SelectionComponent>();
      if (selection != null) {
        selection.isSelected = false;
      }
      selectedEntity = null;
    }
    availableMoves.clear();
    availableAttacks.clear();
    remainingMoves = 0;
    notifyListeners();
  }

  @override
  bool moveEntity(core_hex.HexCoordinate target) {
    if (selectedEntity == null) return false;

    final position = selectedEntity!.get<PositionComponent>();
    if (position == null) return false;

    if (availableMoves.contains(target)) {
      position.coordinate = target;
      _calculateAvailableActions();
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  bool attackPosition(core_hex.HexCoordinate target) {
    if (selectedEntity == null) return false;

    if (availableAttacks.contains(target)) {
      final targetEntity = getEntityAt(target);
      if (targetEntity != null) {
        final targetHealth = targetEntity.get<HealthComponent>();
        if (targetHealth != null) {
          targetHealth.takeDamage(1); // Simple damage for now
          _calculateAvailableActions();
          notifyListeners();
          return true;
        }
      }
    }
    return false;
  }

  @override
  bool handleKeyboardMovement(String key) {
    // TODO: Implement keyboard movement
    return false;
  }

  @override
  void checkVictoryConditions() {
    // Check if there are any medals in the scenario
    final hasMedals = placedStructures.any((s) => s.type == StructureType.medal && s.player != null);

    if (hasMedals) {
      // Medal-based victory: check victory points
      if (player1VictoryPoints >= player1WinPoints) {
        winner = Player.player1;
        gamePhase = GamePhase.gameOver;
        print('Player 1 wins with $player1VictoryPoints victory points!');
      } else if (player2VictoryPoints >= player2WinPoints) {
        winner = Player.player2;
        gamePhase = GamePhase.gameOver;
        print('Player 2 wins with $player2VictoryPoints victory points!');
      }
    } else {
      // Simple victory condition: eliminate all enemy units
      final player1Units = getPlayerEntities(Player.player1);
      final player2Units = getPlayerEntities(Player.player2);

      if (player1Units.isEmpty) {
        winner = Player.player2;
        gamePhase = GamePhase.gameOver;
      } else if (player2Units.isEmpty) {
        winner = Player.player1;
        gamePhase = GamePhase.gameOver;
      }
    }
  }

  @override
  Entity? getEntityAt(core_hex.HexCoordinate coordinate) {
    // TODO: Fix world.query for Oxygen 0.3.1 API
    // final query = world.query([Has<PositionComponent>()]);
    // for (final entity in query.entities) {
    //   final position = entity.get<PositionComponent>()!;
    //   if (position.coordinate == coordinate) {
    //     return entity;
    //   }
    // }
    return null;
  }

  @override
  List<Entity> getPlayerEntities(Player player) {
    final entities = <Entity>[];
    // TODO: Fix world.query for Oxygen 0.3.1 API
    // final query = world.query([Has<OwnerComponent>()]);
    // for (final entity in query.entities) {
    //   final owner = entity.get<OwnerComponent>()!;
    //   if (owner.owner == player) {
    //     entities.add(entity);
    //   }
    // }
    return entities;
  }

  @override
  List<Entity> getEntitiesAt(core_hex.HexCoordinate position) {
    final entities = <Entity>[];
    // TODO: Fix world.query for Oxygen 0.3.1 API
    // final query = world.query([Has<PositionComponent>()]);
    // for (final entity in query.entities) {
    //   final pos = entity.get<PositionComponent>()!;
    //   if (pos.coordinate == position) {
    //     entities.add(entity);
    //   }
    // }
    return entities;
  }

  /// Setup initial units for CHEXX
  void _setupInitialUnits() {
    // Create units using simple approach first
    simpleUnits.clear();

    // Player 1 units (bottom)
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const core_hex.HexCoordinate(-2, 2, 0)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const core_hex.HexCoordinate(-1, 2, -1)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const core_hex.HexCoordinate(0, 2, -2)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const core_hex.HexCoordinate(1, 2, -3)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const core_hex.HexCoordinate(2, 2, -4)));

    // Player 2 units (top)
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const core_hex.HexCoordinate(-2, -2, 4)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const core_hex.HexCoordinate(-1, -2, 3)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const core_hex.HexCoordinate(0, -2, 2)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const core_hex.HexCoordinate(1, -2, 1)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const core_hex.HexCoordinate(2, -2, 0)));

    print('Created ${simpleUnits.length} simple units');
  }

  /// Load units from scenario configuration
  void _loadUnitsFromScenario(Map<String, dynamic> scenarioConfig) {
    simpleUnits.clear();

    final unitPlacements = scenarioConfig['unit_placements'] as List<dynamic>?;
    if (unitPlacements == null) {
      print('No unit_placements found in scenario, using default setup');
      _setupInitialUnits();
      return;
    }

    print('Loading ${unitPlacements.length} units from scenario');

    for (final placementData in unitPlacements) {
      try {
        final placement = placementData as Map<String, dynamic>;
        final templateData = placement['template'] as Map<String, dynamic>;
        final positionData = placement['position'] as Map<String, dynamic>;

        // Extract unit data
        final unitType = templateData['type'] as String;
        final ownerString = templateData['owner'] as String;
        final unitId = templateData['id'] as String;

        print('Processing unit: type=$unitType, owner=$ownerString, id=$unitId');

        // Convert owner string to Player enum
        final owner = ownerString == 'player1' ? Player.player1 : Player.player2;

        // Create hex coordinate
        final position = core_hex.HexCoordinate(
          positionData['q'] as int,
          positionData['r'] as int,
          positionData['s'] as int,
        );

        // Check for saved custom health
        final savedHealth = placement['customHealth'] as int?;
        final actualHealth = savedHealth ?? _getUnitHealth(unitType);
        final maxHealth = _getUnitMaxHealth(unitType);

        print('Loading unit: $unitType, savedHealth: $savedHealth, actualHealth: $actualHealth, maxHealth: $maxHealth');

        // Create simple unit with unique ID based on position
        final unit = SimpleGameUnit(
          id: '${unitType}_${owner.name}_${position.q}_${position.r}_${position.s}',
          unitType: unitType,
          owner: owner,
          position: position,
          health: actualHealth,
          maxHealth: maxHealth,
          remainingMovement: _getUnitMovement(unitType),
          moveAfterCombat: 0,
        );

        simpleUnits.add(unit);
        print('Loaded unit: $unitType at $position for ${owner.name}');
      } catch (e) {
        print('Error loading unit: $e');
      }
    }

    print('Successfully loaded ${simpleUnits.length} units from scenario');
  }

  /// Load board tiles from scenario configuration
  void _loadBoardTilesFromScenario(Map<String, dynamic> scenarioConfig) {
    print('DEBUG: BOARD TILES LOADING START');
    print('DEBUG: Scenario contains board_tiles key: ${scenarioConfig.containsKey('board_tiles')}');
    print('DEBUG: Current board has ${board.allTiles.length} tiles before loading');

    // Load board tiles (if saved in scenario)
    if (scenarioConfig.containsKey('board_tiles')) {
      // Clear the default board and load custom board state
      print('DEBUG: Clearing default board tiles');
      board.tiles.clear();

      final boardTiles = scenarioConfig['board_tiles'] as List<dynamic>;
      print('DEBUG: Loading ${boardTiles.length} board tiles from scenario');

      for (final tileData in boardTiles) {
        try {
          final tile = tileData as Map<String, dynamic>;
          // Create board HexCoordinate (src/models version)
          final coord = src_hex.HexCoordinate(
            tile['q'] as int,
            tile['r'] as int,
            tile['s'] as int,
          );

          final typeString = tile['type'] as String;
          final tileType = HexType.values.firstWhere(
            (e) => e.toString().split('.').last == typeString,
            orElse: () => HexType.normal,
          );

          print('DEBUG: Adding tile at ($coord) with type $tileType');
          board.addTile(coord, tileType);
        } catch (e) {
          print('DEBUG: Error loading board tile: $e');
        }
      }

      print('DEBUG: Successfully loaded ${board.allTiles.length} board tiles from scenario');
    } else {
      print('DEBUG: No board_tiles found in scenario, using default board');
      print('DEBUG: Default board has ${board.allTiles.length} tiles after initialization');
      // Keep the default board initialized by GameBoard constructor
    }

    // Validation test for board tile loading
    final totalTiles = board.allTiles.length;
    final metaTileCount = board.allTiles.where((tile) => tile.type == HexType.meta).length;
    final normalTileCount = board.allTiles.where((tile) => tile.type == HexType.normal).length;

    print('VALIDATION TEST: Board tile loading - Total tiles: $totalTiles, Normal: $normalTileCount, Meta: $metaTileCount');
    print('VALIDATION TEST: Board tile loading - Has tiles loaded: ${totalTiles > 0}');

    if (totalTiles > 0) {
      print('VALIDATION TEST: Board tile loading - PASS: Board tiles successfully loaded');
    } else {
      print('VALIDATION TEST: Board tile loading - FAIL: No board tiles loaded');
    }

    print('DEBUG: BOARD TILES LOADING END');
  }

  /// Load structures from scenario configuration
  void _loadStructuresFromScenario(Map<String, dynamic> scenarioConfig) {
    placedStructures.clear();

    final structurePlacements = scenarioConfig['structure_placements'] as List<dynamic>?;
    if (structurePlacements == null) {
      print('No structure_placements found in scenario');
      return;
    }

    print('Loading ${structurePlacements.length} structures from scenario');

    for (final structureData in structurePlacements) {
      try {
        final template = structureData['template'] as Map<String, dynamic>;
        final position = structureData['position'] as Map<String, dynamic>;

        final structureType = StructureType.values.firstWhere(
          (e) => e.toString().split('.').last == template['type'],
          orElse: () => StructureType.bunker,
        );
        final structurePosition = core_hex.HexCoordinate(
          position['q'] as int,
          position['r'] as int,
          position['s'] as int,
        );

        // Parse player field if present (for medals)
        Player? structurePlayer;
        if (template.containsKey('player')) {
          final playerString = template['player'] as String;
          structurePlayer = playerString == 'player1' ? Player.player1 : Player.player2;
        }

        placedStructures.add(GameStructure(
          type: structureType,
          position: structurePosition,
          id: template['id'] as String,
          player: structurePlayer,
        ));
      } catch (e) {
        print('Error loading structure: $e');
      }
    }

    print('Successfully loaded ${placedStructures.length} structures from scenario');
  }

  void _loadBoardThirdsFromScenario(Map<String, dynamic> scenarioConfig) {
    // Clear existing thirds data
    leftThirdHexes.clear();
    middleThirdHexes.clear();
    rightThirdHexes.clear();

    final boardThirds = scenarioConfig['board_thirds'] as Map<String, dynamic>?;
    if (boardThirds == null) {
      print('No board_thirds found in scenario');
      return;
    }

    try {
      leftLineX = boardThirds['left_line_x'] as double? ?? 0.0;
      rightLineX = boardThirds['right_line_x'] as double? ?? 0.0;

      // Load left third hexes
      if (boardThirds.containsKey('left_third_hexes')) {
        final leftHexes = boardThirds['left_third_hexes'] as List<dynamic>;
        for (final hexData in leftHexes) {
          final hex = hexData as Map<String, dynamic>;
          leftThirdHexes.add(core_hex.HexCoordinate(
            hex['q'] as int,
            hex['r'] as int,
            hex['s'] as int,
          ));
        }
      }

      // Load middle third hexes
      if (boardThirds.containsKey('middle_third_hexes')) {
        final middleHexes = boardThirds['middle_third_hexes'] as List<dynamic>;
        for (final hexData in middleHexes) {
          final hex = hexData as Map<String, dynamic>;
          middleThirdHexes.add(core_hex.HexCoordinate(
            hex['q'] as int,
            hex['r'] as int,
            hex['s'] as int,
          ));
        }
      }

      // Load right third hexes
      if (boardThirds.containsKey('right_third_hexes')) {
        final rightHexes = boardThirds['right_third_hexes'] as List<dynamic>;
        for (final hexData in rightHexes) {
          final hex = hexData as Map<String, dynamic>;
          rightThirdHexes.add(core_hex.HexCoordinate(
            hex['q'] as int,
            hex['r'] as int,
            hex['s'] as int,
          ));
        }
      }

      // Always show vertical lines in game mode (no toggle needed)
      showVerticalLines = true;

      print('Successfully loaded board thirds: left=${leftThirdHexes.length}, middle=${middleThirdHexes.length}, right=${rightThirdHexes.length}');
    } catch (e) {
      print('Error loading board thirds data: $e');
    }
  }

  void _loadWinConditionsFromScenario(Map<String, dynamic> scenarioConfig) {
    final winConditions = scenarioConfig['win_conditions'] as Map<String, dynamic>?;
    if (winConditions == null) {
      print('No win_conditions found in scenario, using defaults');
      return;
    }

    try {
      player1WinPoints = winConditions['player1_points'] as int? ?? 10;
      player2WinPoints = winConditions['player2_points'] as int? ?? 10;
      print('Successfully loaded win conditions: P1=$player1WinPoints, P2=$player2WinPoints');
    } catch (e) {
      print('Error loading win conditions data: $e');
    }
  }

  /// Award points to a player (for defeating units or achieving medals)
  void awardPoints(Player player, int points) {
    if (player == Player.player1) {
      player1Points += points;
      print('Player 1 awarded $points points (total: $player1Points/$player1WinPoints)');
    } else {
      player2Points += points;
      print('Player 2 awarded $points points (total: $player2Points/$player2WinPoints)');
    }
    notifyListeners();
  }

  /// Toggle hexagon orientation between flat and pointy
  void toggleHexOrientation() {
    print('DEBUG: TOGGLE HEX ORIENTATION - Before: ${hexOrientation.name}');
    hexOrientation = hexOrientation == HexOrientation.flat
        ? HexOrientation.pointy
        : HexOrientation.flat;
    print('DEBUG: TOGGLE HEX ORIENTATION - After: ${hexOrientation.name}');
    print('DEBUG: TOGGLE HEX ORIENTATION - notifyListeners() called');

    // Validation test
    final expectedOrientation = hexOrientation == HexOrientation.flat ? 'flat' : 'pointy';
    print('VALIDATION TEST: Hex orientation toggle - Expected: $expectedOrientation, Actual: ${hexOrientation.name}, PASS: ${expectedOrientation == hexOrientation.name}');

    notifyListeners();
  }

  /// Convert core HexCoordinate to board HexCoordinate
  src_hex.HexCoordinate _convertCoreToBoard(core_hex.HexCoordinate coreHex) {
    return src_hex.HexCoordinate(coreHex.q, coreHex.r, coreHex.s);
  }

  /// Convert board HexCoordinate to core HexCoordinate
  core_hex.HexCoordinate _convertBoardToCore(src_hex.HexCoordinate boardHex) {
    return core_hex.HexCoordinate(boardHex.q, boardHex.r, boardHex.s);
  }

  /// Create a simple unit (temporary until ECS is working)
  SimpleGameUnit _createSimpleUnit(String unitType, Player owner, core_hex.HexCoordinate position) {
    return SimpleGameUnit(
      id: '${unitType}_${owner.name}_${position.q}_${position.r}_${position.s}',
      unitType: unitType,
      owner: owner,
      position: position,
      health: _getUnitHealth(unitType),
      maxHealth: _getUnitMaxHealth(unitType),
      remainingMovement: _getUnitMovement(unitType),
      moveAfterCombat: 0,
    );
  }

  /// Create a unit entity (ECS version - currently disabled)
  Entity _createUnit(String unitType, Player owner, src_hex.HexCoordinate position) {
    final entity = world.createEntity();
    // TODO: Fix ECS component adding when Oxygen 0.3.1 API is clarified
    return entity;
  }

  /// Calculate available moves and attacks for selected entity
  void _calculateAvailableActions() {
    availableMoves.clear();
    availableAttacks.clear();
    remainingMoves = 0;

    if (selectedEntity == null) return;

    final position = selectedEntity!.get<PositionComponent>();
    final movement = selectedEntity!.get<MovementComponent>();
    final combat = selectedEntity!.get<CombatComponent>();

    if (position == null) return;

    // Calculate available moves
    if (movement != null && movement.canMove) {
      final range = movement.remainingMovement;
      final possibleMoves = core_hex.HexCoordinate.hexesInRange(position.coordinate, range);

      for (final target in possibleMoves) {
        if (target != position.coordinate && getEntityAt(target) == null) {
          availableMoves.add(target);
        }
      }
      remainingMoves = movement.remainingMovement;
    }

    // Calculate available attacks
    if (combat != null && combat.canAttack) {
      final range = combat.attackRange;
      final possibleTargets = core_hex.HexCoordinate.hexesInRange(position.coordinate, range);

      for (final target in possibleTargets) {
        final targetEntity = getEntityAt(target);
        if (targetEntity != null) {
          final targetOwner = targetEntity.get<OwnerComponent>();
          final selectedOwner = selectedEntity!.get<OwnerComponent>();

          if (targetOwner != null && selectedOwner != null &&
              targetOwner.owner != selectedOwner.owner) {
            availableAttacks.add(target);
          }
        }
      }
    }
  }

  /// Calculate reachable hexes for a unit using BFS pathfinding
  void calculateWayfinding(SimpleGameUnit unit, {int? moveAndFireBonus, int? moveOnlyBonus}) {
    print('DEBUG WAYFINDING: Calculating for unit ${unit.id} (${unit.unitType}) at position ${unit.position}');
    moveAndFireHexes.clear();
    moveOnlyHexes.clear();

    // Get unit's movement stats from unit type config (check overrides first)
    final baseMoveAndFire = _getUnitMoveAndFire(unit.unitType, unitId: unit.id);
    final baseMoveOnly = _getUnitMoveOnly(unit.unitType, unitId: unit.id);
    print('DEBUG WAYFINDING: baseMoveAndFire=$baseMoveAndFire, baseMoveOnly=$baseMoveOnly (overrides: ${unitOverrides[unit.id]})');

    // Use the lesser of remaining movement or base movement capability
    final moveAndFire = baseMoveAndFire.clamp(0, unit.remainingMovement);
    final moveOnly = baseMoveOnly.clamp(0, unit.remainingMovement);

    // Apply bonuses from cards if any
    final actualMoveAndFire = moveAndFire + (moveAndFireBonus ?? 0);
    final actualMoveOnly = moveOnly + (moveOnlyBonus ?? 0);

    // Check if infantry unit is in barbwire - cannot move until barbwire is removed
    if (unit.unitType.toLowerCase() == 'infantry') {
      for (final structure in placedStructures) {
        if (structure.position.q == unit.position.q &&
            structure.position.r == unit.position.r &&
            structure.position.s == unit.position.s) {
          final structureType = structure.type.name.toLowerCase();
          if (structureType == 'barbwire' || structureType == 'barbed_wire') {
            // Infantry cannot move from barbwire until it's removed
            return;
          }
        }
      }
    }

    // Check if unit is in hedgerow - can only move 1 hex
    bool inHedgerow = false;
    for (final tile in board.allTiles) {
      if (tile.coordinate.q == unit.position.q &&
          tile.coordinate.r == unit.position.r &&
          tile.coordinate.s == unit.position.s &&
          tile.type.name.toLowerCase() == 'hedgerow') {
        inHedgerow = true;
        break;
      }
    }

    // Use BFS to find all reachable hexes
    final visited = <core_hex.HexCoordinate, int>{}; // hex -> distance
    final queue = <(core_hex.HexCoordinate, int)>[];

    queue.add((unit.position, 0));
    visited[unit.position] = 0;

    while (queue.isNotEmpty) {
      final (currentHex, distance) = queue.removeAt(0);

      // Hedgerow restriction: can only move to 1 adjacent hex
      if (inHedgerow && distance >= 1) {
        continue; // Stop expanding after 1 move
      }

      // Get all adjacent hexes
      final neighbors = _getAdjacentHexes(currentHex);

      for (final neighbor in neighbors) {
        // Skip if already visited
        if (visited.containsKey(neighbor)) continue;

        // Get movement cost
        final moveCost = _getHexMovementCost(neighbor, unit, currentHex);
        if (moveCost == 0) continue; // Impassable

        // Barbwire: costs 1 to enter but must stop there
        final isBarbwire = moveCost >= 999;
        final actualMoveCost = isBarbwire ? 1 : moveCost;

        final newDistance = distance + actualMoveCost;

        // Mark as visited
        visited[neighbor] = newDistance;

        // Check if reachable and add to appropriate set
        if (newDistance <= actualMoveAndFire) {
          moveAndFireHexes.add(neighbor);
          // If barbwire, don't add to queue (movement stops)
          if (!isBarbwire) {
            queue.add((neighbor, newDistance));
          }
        } else if (newDistance <= actualMoveOnly) {
          moveOnlyHexes.add(neighbor);
          // If barbwire, don't add to queue (movement stops)
          if (!isBarbwire) {
            queue.add((neighbor, newDistance));
          }
        }
      }
    }
  }

  /// Calculate attack ranges for a selected unit
  /// Maps enemy hex positions to expected damage values
  void calculateAttackRange(SimpleGameUnit unit) {
    attackRangeHexes.clear();

    final attackRange = _getUnitAttackRange(unit.unitType, unitId: unit.id);
    final baseDamage = _getUnitBaseDamage(unit.unitType, unitId: unit.id);

    // Find all enemy units within attack range AND with clear line of sight
    for (final targetUnit in simpleUnits) {
      if (targetUnit.owner != unit.owner) {
        final distance = unit.position.distanceTo(targetUnit.position);
        if (distance <= attackRange && hasLineOfSight(unit.position, targetUnit.position)) {
          // Calculate expected damage at this distance
          final damage = _calculateExpectedDamage(unit, targetUnit, distance);
          attackRangeHexes[targetUnit.position] = damage;
        }
      }
    }
  }

  /// Get unit attack range
  int _getUnitAttackRange(String unitType, {String? unitId}) {
    // Check for unit-specific overrides first
    if (unitId != null && unitOverrides.containsKey(unitId)) {
      final overrides = unitOverrides[unitId]!;
      if (overrides.containsKey('attack_range')) {
        return overrides['attack_range'] as int;
      }
    }

    // Fall back to base values
    switch (unitType) {
      // WWII unit types
      case 'infantry': return 3;
      case 'armor': return 2;
      case 'artillery': return 6;
      // CHEXX unit types
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  /// Get base damage for unit type
  int _getUnitBaseDamage(String unitType, {String? unitId}) {
    // Check for unit-specific overrides first
    if (unitId != null && unitOverrides.containsKey(unitId)) {
      final overrides = unitOverrides[unitId]!;
      if (overrides.containsKey('attack_damage')) {
        final damage = overrides['attack_damage'];
        // Handle array format from card JSON
        if (damage is List) {
          return damage.cast<int>().fold(0, (sum, d) => sum + d) ~/ damage.length;
        }
        return damage as int;
      }
    }

    // Fall back to base values
    switch (unitType) {
      // WWII unit types
      case 'infantry': return 2; // Average of [3, 2, 1]
      case 'armor': return 3; // Average of [3, 3, 3]
      case 'artillery': return 2; // Average of [3, 3, 2, 2, 1, 1]
      // CHEXX unit types
      case 'minor': return 1;
      case 'scout': return 1;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  /// Calculate expected damage for an attack
  int _calculateExpectedDamage(SimpleGameUnit attacker, SimpleGameUnit defender, int distance) {
    // For now, return base damage
    // Could be enhanced to factor in distance, terrain, etc.
    return _getUnitBaseDamage(attacker.unitType, unitId: attacker.id);
  }

  /// Get adjacent hexes to a given hex
  List<core_hex.HexCoordinate> _getAdjacentHexes(core_hex.HexCoordinate hex) {
    return [
      core_hex.HexCoordinate(hex.q + 1, hex.r - 1, hex.s),
      core_hex.HexCoordinate(hex.q + 1, hex.r, hex.s - 1),
      core_hex.HexCoordinate(hex.q, hex.r + 1, hex.s - 1),
      core_hex.HexCoordinate(hex.q - 1, hex.r + 1, hex.s),
      core_hex.HexCoordinate(hex.q - 1, hex.r, hex.s + 1),
      core_hex.HexCoordinate(hex.q, hex.r - 1, hex.s + 1),
    ];
  }

  /// Check if a hex is passable for a unit
  /// Returns movement cost (0 = impassable, 1+ = passable with cost)
  int _getHexMovementCost(core_hex.HexCoordinate hex, SimpleGameUnit unit, core_hex.HexCoordinate? fromHex) {
    // Check if another unit occupies this hex
    for (final otherUnit in simpleUnits) {
      if (otherUnit.position == hex && otherUnit != unit) {
        return 0; // Occupied by another unit - impassable
      }
    }

    // Find the tile
    HexTile? targetTile;
    for (final tile in board.allTiles) {
      if (tile.coordinate.q == hex.q &&
          tile.coordinate.r == hex.r &&
          tile.coordinate.s == hex.s) {
        targetTile = tile;
        break;
      }
    }

    if (targetTile == null) return 0; // Hex doesn't exist

    // Check tile type restrictions
    final tileType = targetTile.type.name.toLowerCase();

    // Ocean: Cannot move into unless already in ocean
    if (tileType == 'ocean') {
      bool unitInOcean = false;
      for (final tile in board.allTiles) {
        if (tile.coordinate.q == unit.position.q &&
            tile.coordinate.r == unit.position.r &&
            tile.coordinate.s == unit.position.s &&
            tile.type.name.toLowerCase() == 'ocean') {
          unitInOcean = true;
          break;
        }
      }
      if (!unitInOcean) return 0; // Can't enter ocean from land
    }

    // Hedgerow: Can only enter if starting adjacent
    if (tileType == 'hedgerow') {
      if (fromHex == null) return 1; // Starting in hedgerow is ok

      bool startedAdjacentToHedgerow = false;
      final adjacentToStart = _getAdjacentHexes(unit.position);
      for (final adjHex in adjacentToStart) {
        for (final tile in board.allTiles) {
          if (tile.coordinate.q == adjHex.q &&
              tile.coordinate.r == adjHex.r &&
              tile.coordinate.s == adjHex.s &&
              tile.type.name.toLowerCase() == 'hedgerow') {
            startedAdjacentToHedgerow = true;
            break;
          }
        }
        if (startedAdjacentToHedgerow) break;
      }
      if (!startedAdjacentToHedgerow) return 0; // Can't enter hedgerow
    }

    // Check structure restrictions
    for (final structure in placedStructures) {
      if (structure.position.q == hex.q &&
          structure.position.r == hex.r &&
          structure.position.s == hex.s) {

        final structureType = structure.type.name.toLowerCase();

        // Dragon's Teeth: Tanks cannot enter
        if (structureType == 'dragonsteeth' || structureType == 'dragons_teeth') {
          if (unit.unitType.toLowerCase() == 'armor') {
            return 0; // Tanks blocked by Dragon's Teeth
          }
        }

        // Barbwire: Must stop movement
        if (structureType == 'barbwire' || structureType == 'barbed_wire') {
          return 999; // Special cost to indicate "stop here"
        }
      }
    }

    // Hill: costs 1 movement
    if (tileType == 'hill') {
      return 1;
    }

    // Default movement cost
    return 1;
  }

  /// Check if a hex is passable for a unit (legacy wrapper)
  bool _isHexPassable(core_hex.HexCoordinate hex, SimpleGameUnit unit) {
    return _getHexMovementCost(hex, unit, null) > 0;
  }

  // Helper methods for unit stats
  String _getUnitDisplayName(String unitType) {

    switch (unitType.toLowerCase()) {
      // CHEXX unit types
      case 'minor':
        print('VALIDATION TEST: Unit display name - CHEXX Minor unit correctly identified');
        return 'Minor Unit';
      case 'scout':
        print('VALIDATION TEST: Unit display name - CHEXX Scout unit correctly identified');
        return 'Scout';
      case 'knight':
        print('VALIDATION TEST: Unit display name - CHEXX Knight unit correctly identified');
        return 'Knight';
      case 'guardian':
        print('VALIDATION TEST: Unit display name - CHEXX Guardian unit correctly identified');
        return 'Guardian';

      // WWII unit types
      case 'infantry':
        print('VALIDATION TEST: Unit display name - WWII Infantry unit correctly identified');
        return 'Infantry';
      case 'armor':
        print('VALIDATION TEST: Unit display name - WWII Armor unit correctly identified');
        return 'Armor';
      case 'artillery':
        print('VALIDATION TEST: Unit display name - WWII Artillery unit correctly identified');
        return 'Artillery';

      default:
        print('VALIDATION ERROR: Unit display name - Unknown unit type: "$unitType"');
        return 'Unknown';
    }
  }

  int _getUnitHealth(String unitType) {
    final health = switch (unitType) {
      // CHEXX unit types
      'minor' => 2,
      'scout' => 2,
      'knight' => 3,
      'guardian' => 3,
      // WWII unit types
      'infantry' => 4,
      'armor' => 3,
      'artillery' => 2,
      _ => 1,
    };
    print('Unit type: "$unitType" -> health: $health');
    return health;
  }

  int _getUnitMaxHealth(String unitType) {
    final maxHealth = switch (unitType) {
      // CHEXX unit types
      'minor' => 2,
      'scout' => 2,
      'knight' => 3,
      'guardian' => 3,
      // WWII unit types
      'infantry' => 4,
      'armor' => 3,
      'artillery' => 2,
      _ => 1,
    };
    print('Unit type: "$unitType" -> max health: $maxHealth');
    return maxHealth;
  }

  int _getUnitMovement(String unitType, {String? unitId}) {
    // Check for unit-specific overrides first
    if (unitId != null && unitOverrides.containsKey(unitId)) {
      final overrides = unitOverrides[unitId]!;
      if (overrides.containsKey('movement_range')) {
        return overrides['movement_range'] as int;
      }
    }

    // Fall back to base values
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      // For WWII units, return the move_only value as default movement
      case 'infantry': return 2;
      case 'armor': return 3;
      case 'artillery': return 1;
      default: return 1;
    }
  }

  /// Get move_and_fire value for unit type (how far unit can move and still attack)
  int _getUnitMoveAndFire(String unitType, {String? unitId}) {
    // Check for unit-specific overrides first
    if (unitId != null && unitOverrides.containsKey(unitId)) {
      final overrides = unitOverrides[unitId]!;
      if (overrides.containsKey('move_and_fire')) {
        return overrides['move_and_fire'] as int;
      }
    }

    // Fall back to base values
    switch (unitType) {
      case 'infantry': return 1;
      case 'armor': return 3;
      case 'artillery': return 0;
      // CHEXX units use same value as movement
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  /// Get move_only value for unit type (how far unit can move without attacking)
  int _getUnitMoveOnly(String unitType, {String? unitId}) {
    // Check for unit-specific overrides first
    if (unitId != null && unitOverrides.containsKey(unitId)) {
      final overrides = unitOverrides[unitId]!;
      if (overrides.containsKey('move_only')) {
        return overrides['move_only'] as int;
      }
    }

    // Fall back to base values
    switch (unitType) {
      case 'infantry': return 2;
      case 'armor': return 3;
      case 'artillery': return 1;
      // CHEXX units use same value as movement
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  int _getUnitAttack(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 1;
      case 'knight': return 2;
      case 'guardian': return 1;
      default: return 1;
    }
  }

  MovementType _getUnitMovementType(String unitType) {
    switch (unitType) {
      case 'minor': return MovementType.adjacent;
      case 'scout': return MovementType.straight;
      case 'knight': return MovementType.knight;
      case 'guardian': return MovementType.adjacent;
      default: return MovementType.adjacent;
    }
  }

  /// Reset movement for all units of the current player
  void _resetPlayerMovement() {
    for (int i = 0; i < simpleUnits.length; i++) {
      final unit = simpleUnits[i];
      if (unit.owner == currentPlayer) {
        final resetUnit = SimpleGameUnit(
          id: unit.id,
          unitType: unit.unitType,
          owner: unit.owner,
          position: unit.position,
          health: unit.health,
          maxHealth: unit.maxHealth,
          remainingMovement: _getUnitMovement(unit.unitType),
          moveAfterCombat: unit.moveAfterCombat,
          isSelected: unit.isSelected,
        );
        simpleUnits[i] = resetUnit;
      }
    }
  }

  /// Record dice roll results for display
  void recordDiceRoll(List<DieFace> diceRolls, String combatResult) {
    lastDiceRolls = diceRolls;
    lastCombatResult = combatResult;
    lastCombatTime = DateTime.now();
    notifyListeners();
  }

  /// Clear dice roll display
  void clearDiceRoll() {
    lastDiceRolls = null;
    lastCombatResult = null;
    lastCombatTime = null;
    notifyListeners();
  }

  /// Check if dice roll should still be displayed (until END TURN is clicked)
  bool get shouldShowDiceRoll {
    if (lastCombatTime == null) return false;
    // In card mode, dice rolls persist until END TURN is clicked
    if (gameMode == 'card') {
      return true;
    }
    // In other modes, show for 5 seconds
    return DateTime.now().difference(lastCombatTime!).inSeconds < 5;
  }

  /// Calculate valid retreat hexes for a unit
  /// Player 1 units retreat in r direction -1 (backwards)
  /// Player 2 units retreat in r direction +1 (backwards for them)
  void calculateRetreatHexes(SimpleGameUnit unit, int retreatCount) {
    retreatHexes.clear();

    // Determine retreat direction based on player
    final retreatDirection = unit.owner == Player.player1 ? -1 : 1;

    // Calculate retreat positions (each retreat die = 1 hex in r direction)
    for (int i = 1; i <= retreatCount; i++) {
      final retreatCoord = core_hex.HexCoordinate(
        unit.position.q,
        unit.position.r + (retreatDirection * i),
        unit.position.s,
      );

      // Check if this hex is valid for retreat
      if (_isValidRetreatHex(unit, retreatCoord)) {
        retreatHexes.add(retreatCoord);
      }
    }

    notifyListeners();
  }

  /// Check if a hex is valid for retreat
  bool _isValidRetreatHex(SimpleGameUnit unit, core_hex.HexCoordinate hex) {
    // Get tile at this position
    final srcCoord = src_hex.HexCoordinate(hex.q, hex.r, hex.s);
    final tile = board.tiles[srcCoord];

    if (tile == null) return false;

    // Cannot retreat into ocean
    if (tile.type == HexType.ocean) {
      return false;
    }

    // Armor cannot retreat into Dragon's Teeth
    if (unit.unitType == 'armor') {
      // Check if there's a Dragon's Teeth structure at this hex
      for (final structure in placedStructures) {
        if (structure.position == hex && structure.type == StructureType.dragonsTeeth) {
          return false;
        }
      }
    }

    // Check if hex is occupied by another unit
    for (final otherUnit in simpleUnits) {
      if (otherUnit.position == hex) {
        return false; // Cannot retreat into occupied hex
      }
    }

    return true;
  }

  /// Clear retreat state
  void clearRetreatState() {
    unitMustRetreat = null;
    retreatDiceCount = 0;
    retreatHexes.clear();
    isWaitingForRetreat = false;
    notifyListeners();
  }

  /// Apply card effects (overrides) to a specific unit
  /// Returns true if successful, false if unit doesn't match restrictions
  bool applyCardEffectsToUnit(String unitId, Map<String, dynamic> cardAction) {
    print('DEBUG APPLY: applyCardEffectsToUnit called for unitId=$unitId');

    // Find the unit
    final unitIndex = simpleUnits.indexWhere((u) => u.id == unitId);
    if (unitIndex == -1) {
      throw Exception('Unit not found: $unitId');
    }
    final unit = simpleUnits[unitIndex];
    print('DEBUG APPLY: Found unit: ${unit.id} (${unit.unitType}) at position ${unit.position}');

    // Check unit restrictions
    final unitRestriction = cardAction['unit_restrictions'] as String?;
    if (unitRestriction != null && unitRestriction.isNotEmpty && unitRestriction.toLowerCase() != 'all') {
      final restrictionLower = unitRestriction.toLowerCase();
      final unitTypeLower = unit.unitType.toLowerCase();

      // Check if unit type contains the restriction string
      if (!unitTypeLower.contains(restrictionLower)) {
        print('DEBUG APPLY: Unit ${unit.id} (${unit.unitType}) does not match restriction: $unitRestriction');
        return false;
      }
    }

    // Get overrides from card action
    final overrides = cardAction['overrides'] as Map<String, dynamic>?;
    final effectiveOverrides = <String, dynamic>{};

    // Copy overrides if they exist
    if (overrides != null && overrides.isNotEmpty) {
      effectiveOverrides.addAll(overrides);
    }

    // Check for battle_die modifier at action level (not in overrides)
    if (cardAction.containsKey('battle_die')) {
      effectiveOverrides['battle_die'] = cardAction['battle_die'];
      print('DEBUG APPLY: Found battle_die modifier at action level: ${cardAction['battle_die']}');
    }

    // Store effective overrides for this unit
    if (effectiveOverrides.isNotEmpty) {
      unitOverrides[unitId] = effectiveOverrides;
      print('DEBUG APPLY: Applied card overrides to unit $unitId: $effectiveOverrides');

      // Update unit's remainingMovement if movement_range override exists
      if (effectiveOverrides.containsKey('movement_range')) {
        final newMovement = effectiveOverrides['movement_range'] as int;
        final updatedUnit = SimpleGameUnit(
          id: unit.id,
          unitType: unit.unitType,
          owner: unit.owner,
          position: unit.position,
          health: unit.health,
          maxHealth: unit.maxHealth,
          remainingMovement: newMovement,
          moveAfterCombat: effectiveOverrides['move_after_combat'] as int? ?? unit.moveAfterCombat,
          isSelected: unit.isSelected,
        );
        simpleUnits[unitIndex] = updatedUnit;
        print('DEBUG APPLY: Updated unit remainingMovement to $newMovement and moveAfterCombat to ${updatedUnit.moveAfterCombat}');
      }
    } else {
      print('DEBUG APPLY: No overrides found in card action - will use base unit stats');
    }

    print('DEBUG APPLY: About to call calculateWayfinding for unit ${unit.id} at ${unit.position}');

    // Get the updated unit reference
    final updatedUnit = simpleUnits[unitIndex];

    // Recalculate movement for this unit (ALWAYS do this, even without overrides)
    calculateWayfinding(updatedUnit);
    calculateAttackRange(updatedUnit);

    notifyListeners();
    return true;
  }

  /// Get units that match a unit restriction filter
  /// Supports both String and List<String> formats
  List<SimpleGameUnit> getUnitsMatchingRestriction(dynamic restriction, Player player) {
    // Handle null or "all" case
    if (restriction == null) {
      return simpleUnits.where((u) => u.owner == player).toList();
    }

    // Handle String format
    if (restriction is String) {
      if (restriction.isEmpty || restriction.toLowerCase() == 'all') {
        return simpleUnits.where((u) => u.owner == player).toList();
      }

      final restrictionLower = restriction.toLowerCase();
      return simpleUnits.where((u) {
        return u.owner == player && u.unitType.toLowerCase().contains(restrictionLower);
      }).toList();
    }

    // Handle List<String> format (e.g., ["infantry", "armor"])
    if (restriction is List) {
      final restrictionList = restriction.cast<String>();
      if (restrictionList.isEmpty) {
        return simpleUnits.where((u) => u.owner == player).toList();
      }

      final restrictionsLower = restrictionList.map((r) => r.toLowerCase()).toList();
      return simpleUnits.where((u) {
        return u.owner == player &&
               restrictionsLower.any((r) => u.unitType.toLowerCase().contains(r));
      }).toList();
    }

    // Fallback: return all units for player
    return simpleUnits.where((u) => u.owner == player).toList();
  }

  /// Clear overrides for a specific unit
  void clearUnitOverrides(String unitId) {
    if (unitOverrides.containsKey(unitId)) {
      print('DEBUG: Clearing overrides for unit $unitId');
      unitOverrides.remove(unitId);
      notifyListeners();
    }
  }

  /// Get hexes for a specific third (loaded from scenario)
  /// Also supports dynamic filters like "adjacent to enemy units" and "not adjacent"
  Set<core_hex.HexCoordinate> getHexesForThird(String hexTiles) {
    switch (hexTiles.toLowerCase()) {
      case 'left third':
        return leftThirdHexes;
      case 'middle third':
        return middleThirdHexes;
      case 'right third':
        return rightThirdHexes;
      case 'adjacent to enemy units':
        return getHexesAdjacentToEnemyUnits();
      case 'not adjacent':
        return getHexesNotAdjacentToEnemyUnits();
      default:
        return {};
    }
  }

  /// Get all hexes that are adjacent to enemy units (for current player)
  /// Returns all hexes that are adjacent to at least one enemy unit
  Set<core_hex.HexCoordinate> getHexesAdjacentToEnemyUnits() {
    final adjacentHexes = <core_hex.HexCoordinate>{};
    final enemyPlayer = currentPlayer == Player.player1 ? Player.player2 : Player.player1;

    print('DEBUG ADJACENT: Current player: ${currentPlayer.name}, Enemy player: ${enemyPlayer.name}');

    // Find all enemy units
    final enemyUnits = simpleUnits.where((u) => u.owner == enemyPlayer);
    print('DEBUG ADJACENT: Found ${enemyUnits.length} enemy units');

    // For each enemy unit, get all adjacent hexes
    for (final enemy in enemyUnits) {
      final neighbors = _getAdjacentHexes(enemy.position);
      print('DEBUG ADJACENT: Enemy unit at ${enemy.position} has ${neighbors.length} neighbors');
      adjacentHexes.addAll(neighbors);
    }

    print('DEBUG ADJACENT: Result: ${adjacentHexes.length} hexes adjacent to enemies');
    return adjacentHexes;
  }

  /// Get all hexes with current player's units that are NOT adjacent to enemy units
  Set<core_hex.HexCoordinate> getHexesNotAdjacentToEnemyUnits() {
    final adjacentHexes = getHexesAdjacentToEnemyUnits();
    final notAdjacentHexes = <core_hex.HexCoordinate>{};

    print('DEBUG NOT ADJACENT: Current player: ${currentPlayer.name}');
    print('DEBUG NOT ADJACENT: Total units: ${simpleUnits.length}');
    print('DEBUG NOT ADJACENT: Adjacent hexes count: ${adjacentHexes.length}');

    // Get all hexes with current player's units that are NOT adjacent to enemies
    for (final unit in simpleUnits) {
      if (unit.owner == currentPlayer) {
        final isAdjacent = adjacentHexes.contains(unit.position);
        print('DEBUG NOT ADJACENT: Unit ${unit.id} (${unit.unitType}) at ${unit.position} - adjacent: $isAdjacent');
        if (!isAdjacent) {
          notAdjacentHexes.add(unit.position);
          print('  -> ADDED to not adjacent set');
        }
      }
    }

    print('DEBUG NOT ADJACENT: Result: ${notAdjacentHexes.length} hexes not adjacent to enemies');
    return notAdjacentHexes;
  }

  /// Roll a battle die and return the face result
  /// Returns one of: 'infantry', 'armor', 'artillery', 'grenade', 'flag', 'star'
  String rollBattleDie() {
    final random = Random();
    final roll = random.nextInt(6);

    // Standard battle die faces
    switch (roll) {
      case 0: return 'infantry';
      case 1: return 'armor';
      case 2: return 'artillery';
      case 3: return 'grenade';
      case 4: return 'flag';
      case 5: return 'star';
      default: return 'infantry';
    }
  }

  /// Get neighboring hexes for a given coordinate
  List<core_hex.HexCoordinate> getNeighbors(core_hex.HexCoordinate hex) {
    return _getAdjacentHexes(hex);
  }

  /// Update a unit's health
  /// Returns true if successful, false if unit not found
  bool updateUnitHealth(String unitId, int newHealth) {
    final unitIndex = simpleUnits.indexWhere((u) => u.id == unitId);
    if (unitIndex == -1) {
      print('ERROR: Cannot update health - unit not found: $unitId');
      return false;
    }

    final unit = simpleUnits[unitIndex];
    final clampedHealth = newHealth.clamp(0, unit.maxHealth);

    final updatedUnit = SimpleGameUnit(
      id: unit.id,
      unitType: unit.unitType,
      owner: unit.owner,
      position: unit.position,
      health: clampedHealth,
      maxHealth: unit.maxHealth,
      remainingMovement: unit.remainingMovement,
      moveAfterCombat: unit.moveAfterCombat,
      isSelected: unit.isSelected,
    );

    simpleUnits[unitIndex] = updatedUnit;
    print('Updated unit $unitId health: ${unit.health} -> $clampedHealth');
    notifyListeners();
    return true;
  }

  /// Track the last combat target position for card actions
  core_hex.HexCoordinate? lastCombatTargetPosition;

  /// Set the last combat target position (called by combat system)
  void setLastCombatTarget(core_hex.HexCoordinate position) {
    lastCombatTargetPosition = position;
    print('Last combat target position set to: $position');
  }

  /// Check if there is a clear line of sight between two hexes for combat
  /// Returns true if the attacker can see the defender
  ///
  /// Line of sight rules (to be implemented):
  /// - Basic implementation: always returns true (no LOS blocking yet)
  /// - Future: Check for blocking terrain, structures, or units between positions
  bool hasLineOfSight(core_hex.HexCoordinate from, core_hex.HexCoordinate to) {
    // TODO: Implement line of sight blocking rules
    // For now, always return true (no LOS blocking)
    //
    // Future rules to implement:
    // 1. Check if any blocking structures are in the path (e.g., bunkers, hills)
    // 2. Check if any blocking terrain is in the path (e.g., forests, buildings)
    // 3. Adjacent hexes always have LOS (distance 1)
    // 4. Use Bresenham's line algorithm to check all hexes in the path

    return true;
  }

  /// Update victory points for medal structures
  /// Called after unit movement, combat, and unit death
  void updateMedalVictoryPoints() {
    // Store previous state for comparison
    final previousMedalControl = Map<core_hex.HexCoordinate, Player>.from(medalVictoryPoints);

    // Clear current medal control
    medalVictoryPoints.clear();

    // Iterate through all placed structures to find medals
    for (final structure in placedStructures) {
      // Only process medal structures
      if (structure.type != StructureType.medal) continue;

      // Only process medals that have a player assignment
      if (structure.player == null) continue;

      // Check if there's a unit at this position
      SimpleGameUnit? unitAtPosition;
      for (final unit in simpleUnits) {
        if (unit.position.q == structure.position.q &&
            unit.position.r == structure.position.r &&
            unit.position.s == structure.position.s) {
          unitAtPosition = unit;
          break;
        }
      }

      // If a unit occupies this medal and the unit's owner matches the medal's player
      if (unitAtPosition != null && unitAtPosition.owner == structure.player) {
        medalVictoryPoints[structure.position] = unitAtPosition.owner;
      }
    }

    // Calculate victory point changes
    // Check for newly controlled medals
    for (final entry in medalVictoryPoints.entries) {
      final position = entry.key;
      final controllingPlayer = entry.value;

      if (!previousMedalControl.containsKey(position)) {
        // Newly controlled medal - award 1 victory point
        if (controllingPlayer == Player.player1) {
          player1VictoryPoints++;
          print('Player 1 gained control of medal at $position (VP: $player1VictoryPoints)');
        } else {
          player2VictoryPoints++;
          print('Player 2 gained control of medal at $position (VP: $player2VictoryPoints)');
        }
      }
    }

    // Check for lost medals
    for (final entry in previousMedalControl.entries) {
      final position = entry.key;
      final previousPlayer = entry.value;

      if (!medalVictoryPoints.containsKey(position)) {
        // Lost control of medal - remove 1 victory point
        if (previousPlayer == Player.player1) {
          player1VictoryPoints--;
          print('Player 1 lost control of medal at $position (VP: $player1VictoryPoints)');
        } else {
          player2VictoryPoints--;
          print('Player 2 lost control of medal at $position (VP: $player2VictoryPoints)');
        }
      }
    }
  }
}
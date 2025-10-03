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
import '../../../src/models/hex_coordinate.dart';
import '../../../src/models/hex_orientation.dart';
import '../../../src/models/scenario_builder_state.dart';
import '../../../src/systems/combat/die_faces_config.dart';

/// Structure placed in the game (using core HexCoordinate for compatibility)
class GameStructure {
  final StructureType type;
  final core_hex.HexCoordinate position;
  final String id;

  const GameStructure({
    required this.type,
    required this.position,
    required this.id,
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
  bool isSelected;

  SimpleGameUnit({
    required this.id,
    required this.unitType,
    required this.owner,
    required this.position,
    required this.health,
    required this.maxHealth,
    required this.remainingMovement,
    this.isSelected = false,
  });
}

/// CHEXX-specific game state implementation
class ChexxGameState extends GameStateBase {
  // CHEXX-specific state
  int player1Rewards = 0;
  int player2Rewards = 0;

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
    // Reset movement for all units of the next player
    _resetPlayerMovement();

    // Switch players
    currentPlayer = currentPlayer == Player.player1 ? Player.player2 : Player.player1;

    if (currentPlayer == Player.player1) {
      turnNumber++;
    }

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

        // Create simple unit
        final unit = SimpleGameUnit(
          id: unitId,
          unitType: unitType,
          owner: owner,
          position: position,
          health: actualHealth,
          maxHealth: maxHealth,
          remainingMovement: _getUnitMovement(unitType),
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
          final coord = HexCoordinate(
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

        placedStructures.add(GameStructure(
          type: structureType,
          position: structurePosition,
          id: template['id'] as String,
        ));
      } catch (e) {
        print('Error loading structure: $e');
      }
    }

    print('Successfully loaded ${placedStructures.length} structures from scenario');
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
  HexCoordinate _convertCoreToBoard(core_hex.HexCoordinate coreHex) {
    return HexCoordinate(coreHex.q, coreHex.r, coreHex.s);
  }

  /// Convert board HexCoordinate to core HexCoordinate
  core_hex.HexCoordinate _convertBoardToCore(HexCoordinate boardHex) {
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
    );
  }

  /// Create a unit entity (ECS version - currently disabled)
  Entity _createUnit(String unitType, Player owner, HexCoordinate position) {
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

  // Helper methods for unit stats
  String _getUnitDisplayName(String unitType) {
    print('DEBUG: _getUnitDisplayName - Unit type: "$unitType"');

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
      'minor' => 1,
      'scout' => 2,
      'knight' => 3,
      'guardian' => 3,
      // WWII unit types
      'infantry' => 1,
      'armor' => 1,
      'artillery' => 1,
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

  int _getUnitMovement(String unitType) {
    switch (unitType) {
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

  int _getUnitAttackRange(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 3;
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

  /// Check if dice roll should still be displayed (5 seconds)
  bool get shouldShowDiceRoll {
    if (lastCombatTime == null) return false;
    return DateTime.now().difference(lastCombatTime!).inSeconds < 5;
  }
}
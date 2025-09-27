import 'package:oxygen/oxygen.dart';
import '../../../core/models/game_state_base.dart';
import '../../../core/models/hex_coordinate.dart';
import '../../../core/interfaces/unit_factory.dart';
import '../../../core/components/position_component.dart';
import '../../../core/components/health_component.dart';
import '../../../core/components/owner_component.dart';
import '../../../core/components/unit_type_component.dart';
import '../../../core/components/movement_component.dart';
import '../../../core/components/combat_component.dart';
import '../../../core/components/selection_component.dart';
import '../../../core/models/game_config.dart';

/// Simple unit representation for temporary use
class SimpleGameUnit {
  final String id;
  final String unitType;
  final Player owner;
  final HexCoordinate position;
  final int health;
  final int maxHealth;
  bool isSelected;

  SimpleGameUnit({
    required this.id,
    required this.unitType,
    required this.owner,
    required this.position,
    required this.health,
    required this.maxHealth,
    this.isSelected = false,
  });
}

/// CHEXX-specific game state implementation
class ChexxGameState extends GameStateBase {
  // CHEXX-specific state
  int player1Rewards = 0;
  int player2Rewards = 0;

  // Temporary: Simple unit storage until ECS is working
  List<SimpleGameUnit> simpleUnits = [];

  @override
  void initializeGame() {
    gamePhase = GamePhase.playing;
    _setupInitialUnits();
    _calculateAvailableActions();
  }

  @override
  void initializeFromScenario(Map<String, dynamic> scenarioConfig) {
    gamePhase = GamePhase.playing;
    _loadUnitsFromScenario(scenarioConfig);
    _calculateAvailableActions();
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
  bool moveEntity(HexCoordinate target) {
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
  bool attackPosition(HexCoordinate target) {
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
  Entity? getEntityAt(HexCoordinate coordinate) {
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
  List<Entity> getEntitiesAt(HexCoordinate position) {
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
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const HexCoordinate(-2, 2, 0)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const HexCoordinate(-1, 2, -1)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const HexCoordinate(0, 2, -2)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const HexCoordinate(1, 2, -3)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player1, const HexCoordinate(2, 2, -4)));

    // Player 2 units (top)
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const HexCoordinate(-2, -2, 4)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const HexCoordinate(-1, -2, 3)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const HexCoordinate(0, -2, 2)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const HexCoordinate(1, -2, 1)));
    simpleUnits.add(_createSimpleUnit('minor', Player.player2, const HexCoordinate(2, -2, 0)));

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

        // Convert owner string to Player enum
        final owner = ownerString == 'player1' ? Player.player1 : Player.player2;

        // Create hex coordinate
        final position = HexCoordinate(
          positionData['q'] as int,
          positionData['r'] as int,
          positionData['s'] as int,
        );

        // Create simple unit
        final unit = SimpleGameUnit(
          id: unitId,
          unitType: unitType,
          owner: owner,
          position: position,
          health: _getUnitHealth(unitType),
          maxHealth: _getUnitHealth(unitType),
        );

        simpleUnits.add(unit);
        print('Loaded unit: $unitType at $position for ${owner.name}');
      } catch (e) {
        print('Error loading unit: $e');
      }
    }

    print('Successfully loaded ${simpleUnits.length} units from scenario');
  }

  /// Create a simple unit (temporary until ECS is working)
  SimpleGameUnit _createSimpleUnit(String unitType, Player owner, HexCoordinate position) {
    return SimpleGameUnit(
      id: '${unitType}_${owner.name}_${position.q}_${position.r}_${position.s}',
      unitType: unitType,
      owner: owner,
      position: position,
      health: _getUnitHealth(unitType),
      maxHealth: _getUnitHealth(unitType),
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
      final possibleMoves = HexCoordinate.hexesInRange(position.coordinate, range);

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
      final possibleTargets = HexCoordinate.hexesInRange(position.coordinate, range);

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
    switch (unitType) {
      case 'minor': return 'Minor Unit';
      case 'scout': return 'Scout';
      case 'knight': return 'Knight';
      case 'guardian': return 'Guardian';
      default: return 'Unknown';
    }
  }

  int _getUnitHealth(String unitType) {
    switch (unitType) {
      case 'minor': return 1;
      case 'scout': return 2;
      case 'knight': return 3;
      case 'guardian': return 3;
      default: return 1;
    }
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
}
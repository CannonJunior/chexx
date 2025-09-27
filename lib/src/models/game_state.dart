import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'game_unit.dart';
import 'game_board.dart';
import 'meta_ability.dart';
import '../../core/interfaces/unit_factory.dart';

enum GamePhase { setup, playing, gameOver }

enum TurnPhase { moving, acting, ended }

/// Represents the complete state of the game
class GameState extends ChangeNotifier {
  final GameBoard board;
  final List<GameUnit> units;

  Player currentPlayer;
  GamePhase gamePhase;
  TurnPhase turnPhase;
  int turnNumber;

  // Turn timer
  DateTime? turnStartTime;
  double turnTimeRemaining;
  bool isPaused;

  // Selected unit and actions
  GameUnit? selectedUnit;
  List<HexCoordinate> availableMoves;
  List<HexCoordinate> availableAttacks;

  // Keyboard movement tracking
  int remainingMoves;
  HexCoordinate? originalPosition;

  // Meta abilities system
  List<MetaHex> metaHexes;
  MetaHex? selectedMetaHex;
  List<ActiveMetaEffect> activeMetaEffects;
  Map<MetaAbilityType, List<MetaAbility>> metaAbilityDefinitions;

  // Rewards system
  int player1Rewards;
  int player2Rewards;

  GameState()
      : board = GameBoard(),
        units = [],
        currentPlayer = Player.player1,
        gamePhase = GamePhase.setup,
        turnPhase = TurnPhase.moving,
        turnNumber = 1,
        turnTimeRemaining = 6.0,
        isPaused = false,
        availableMoves = [],
        availableAttacks = [],
        remainingMoves = 0,
        metaHexes = [],
        activeMetaEffects = [],
        metaAbilityDefinitions = {},
        player1Rewards = 0,
        player2Rewards = 0;

  /// Initialize game from scenario configuration
  void initializeFromScenario(Map<String, dynamic> scenarioConfig) {
    units.clear();
    metaHexes.clear();

    // Initialize Meta system first to get ability definitions
    _initializeMetaSystem();

    // Load Meta hex positions
    final metaHexData = scenarioConfig['meta_hex_positions'] as List<dynamic>? ?? [];
    for (final hexData in metaHexData) {
      final q = hexData['q'] as int;
      final r = hexData['r'] as int;
      metaHexes.add(MetaHex(
        position: HexCoordinate.axial(q, r),
        availableAbilities: [
          metaAbilityDefinitions[MetaAbilityType.spawn]!.first,
          metaAbilityDefinitions[MetaAbilityType.heal]!.first,
          metaAbilityDefinitions[MetaAbilityType.shield]!.first,
        ],
      ));
    }

    // Load unit placements
    final unitPlacements = scenarioConfig['unit_placements'] as List<dynamic>? ?? [];
    for (final unitData in unitPlacements) {
      final template = unitData['template'] as Map<String, dynamic>;
      final position = unitData['position'] as Map<String, dynamic>;

      final unitType = UnitType.values.firstWhere(
        (e) => e.toString().split('.').last == template['type']
      );
      final owner = Player.values.firstWhere(
        (e) => e.toString().split('.').last == template['owner']
      );
      final unitPosition = HexCoordinate(
        position['q'] as int,
        position['r'] as int,
        position['s'] as int,
      );

      units.add(GameUnit.create(
        id: template['id'] as String,
        type: unitType,
        owner: owner,
        position: unitPosition,
      ));
    }

    // Set scenario name if provided
    if (scenarioConfig['scenario_name'] != null) {
      // Could store this for display if needed
    }

    notifyListeners();
  }

  /// Initialize game with starting units
  void initializeGame() {
    units.clear();

    // Create Player 1 units (top rows)
    final p1Positions = board.getStartingPositions(Player.player1);

    // Back row: 3 major units (simplified from 5)
    final majorUnits1 = [UnitType.scout, UnitType.knight, UnitType.guardian];
    for (int i = 0; i < majorUnits1.length; i++) {
      units.add(GameUnit.create(
        id: 'p1_major_$i',
        type: majorUnits1[i],
        owner: Player.player1,
        position: p1Positions[i],
      ));
    }

    // Front row: 6 minor units
    for (int i = 0; i < 6; i++) {
      units.add(GameUnit.create(
        id: 'p1_minor_$i',
        type: UnitType.minor,
        owner: Player.player1,
        position: p1Positions[3 + i], // Offset by major units
      ));
    }

    // Create Player 2 units (bottom rows)
    final p2Positions = board.getStartingPositions(Player.player2);

    // Front row: 6 minor units
    for (int i = 0; i < 6; i++) {
      units.add(GameUnit.create(
        id: 'p2_minor_$i',
        type: UnitType.minor,
        owner: Player.player2,
        position: p2Positions[i],
      ));
    }

    // Back row: 3 major units
    final majorUnits2 = [UnitType.scout, UnitType.knight, UnitType.guardian];
    for (int i = 0; i < majorUnits2.length; i++) {
      units.add(GameUnit.create(
        id: 'p2_major_$i',
        type: majorUnits2[i],
        owner: Player.player2,
        position: p2Positions[6 + i], // Offset by minor units
      ));
    }

    // Initialize Meta abilities
    _initializeMetaSystem();

    gamePhase = GamePhase.playing;
    _startTurn();
  }

  /// Get current player's alive units
  List<GameUnit> get currentPlayerUnits {
    return units.where((unit) =>
        unit.owner == currentPlayer && unit.isAlive).toList();
  }

  /// Get opponent's alive units
  List<GameUnit> get opponentUnits {
    final opponent = currentPlayer == Player.player1 ? Player.player2 : Player.player1;
    return units.where((unit) =>
        unit.owner == opponent && unit.isAlive).toList();
  }

  /// Select a unit
  void selectUnit(GameUnit unit) {
    if (unit.owner != currentPlayer || !unit.canMove) return;

    selectedUnit = unit;
    unit.state = UnitState.selected;

    // Initialize keyboard movement tracking
    remainingMoves = unit.effectiveMovementRange;
    originalPosition = unit.position;

    // Calculate available moves and attacks
    availableMoves = unit.getValidMoves(units);
    availableAttacks = unit.getValidAttacks(units);

    // Highlight valid moves
    board.highlightCoordinates(availableMoves);
  }

  /// Deselect current unit
  void deselectUnit() {
    if (selectedUnit != null) {
      selectedUnit!.state = UnitState.idle;
      selectedUnit = null;
    }
    availableMoves.clear();
    availableAttacks.clear();
    remainingMoves = 0;
    originalPosition = null;
    board.clearHighlights();
  }

  /// Handle keyboard movement input
  bool handleKeyboardMovement(String key) {
    if (selectedUnit == null || turnPhase != TurnPhase.moving) return false;
    if (!HexCoordinate.isValidMovementKey(key)) return false;
    if (remainingMoves <= 0) return false;

    final currentPosition = selectedUnit!.position;
    final nextPosition = currentPosition.getNeighborInDirection(key);

    if (nextPosition == null) return false;

    // Check if movement is valid
    if (!board.isValidCoordinate(nextPosition)) return false;
    if (!selectedUnit!.canMoveTo(nextPosition, units)) return false;

    // Check if unit type allows this movement pattern
    if (!_isValidKeyboardMovementForUnitType(originalPosition!, nextPosition, selectedUnit!.type)) {
      return false;
    }

    // Perform the movement
    selectedUnit!.position = nextPosition;
    remainingMoves--;

    // Update available attacks for current position
    availableAttacks = selectedUnit!.getValidAttacks(units);

    // If no moves remaining, transition to acting phase
    if (remainingMoves <= 0) {
      turnPhase = TurnPhase.acting;
      board.highlightCoordinates(availableAttacks);
    } else {
      // Update available moves for remaining movement
      _updateRemainingMovesHighlights();
    }

    return true;
  }

  /// Validate movement pattern for unit type during keyboard movement
  bool _isValidKeyboardMovementForUnitType(HexCoordinate origin, HexCoordinate target, UnitType unitType) {
    switch (unitType) {
      case UnitType.minor:
      case UnitType.guardian:
        return true; // Can move in any direction

      case UnitType.scout:
        // Scout must move in straight lines from original position
        final diff = target - origin;
        return diff.q == 0 || diff.r == 0 || diff.s == 0;

      case UnitType.knight:
        // Knight moves in L-shapes - check if total movement forms valid L
        final totalDistance = origin.distanceTo(target);
        if (totalDistance > 2) return false;

        if (totalDistance == 2) {
          final diff = target - origin;
          final isStraightLine = diff.q == 0 || diff.r == 0 || diff.s == 0;
          return !isStraightLine; // L-shape: not straight line
        }
        return true; // Single step is always valid
    }
  }

  /// Update highlights for remaining keyboard movement
  void _updateRemainingMovesHighlights() {
    final possibleMoves = <HexCoordinate>[];
    final currentPos = selectedUnit!.position;

    // Get all adjacent hexes
    for (final direction in HexCoordinate.keyboardDirections.values) {
      final nextPos = currentPos + direction;
      if (board.isValidCoordinate(nextPos) && selectedUnit!.canMoveTo(nextPos, units)) {
        // Check if this move would still be valid for unit type
        if (_isValidKeyboardMovementForUnitType(originalPosition!, nextPos, selectedUnit!.type)) {
          possibleMoves.add(nextPos);
        }
      }
    }

    board.highlightCoordinates(possibleMoves);
  }

  /// Move selected unit to position
  bool moveUnit(HexCoordinate target) {
    if (selectedUnit == null || turnPhase != TurnPhase.moving) return false;

    if (!availableMoves.contains(target)) return false;

    selectedUnit!.moveTo(target);
    turnPhase = TurnPhase.acting;

    // Update available attacks after moving
    availableAttacks = selectedUnit!.getValidAttacks(units);
    board.highlightCoordinates(availableAttacks);

    return true;
  }

  /// Attack with selected unit
  bool attackPosition(HexCoordinate target) {
    if (selectedUnit == null || turnPhase != TurnPhase.acting) return false;

    if (!availableAttacks.contains(target)) return false;

    final targetUnit = board.getUnitAt(target, units);
    if (targetUnit == null || targetUnit.owner == currentPlayer) return false;

    // Perform attack (check for shield effects and level bonuses)
    final damage = selectedUnit!.effectiveAttackDamage;
    final hasShield = isUnitShielded(targetUnit);
    final unitKilled = targetUnit.takeDamageWithShield(damage, hasShield);

    // Gain experience if unit was killed
    if (unitKilled) {
      selectedUnit!.gainExperience(1);
    }

    // End turn after attacking
    endTurn();
    return true;
  }

  /// Skip turn without attacking
  void skipAction() {
    if (turnPhase == TurnPhase.acting) {
      endTurn();
    }
  }

  /// End current turn
  void endTurn() {
    // Calculate time bonus rewards
    if (turnStartTime != null) {
      final timeUsed = DateTime.now().difference(turnStartTime!).inMilliseconds / 1000.0;
      final timeBonus = (6.0 - timeUsed).clamp(0.0, 6.0) * 5; // 5 points per second saved

      if (currentPlayer == Player.player1) {
        player1Rewards += timeBonus.round();
      } else {
        player2Rewards += timeBonus.round();
      }
    }

    // Update all unit cooldowns
    for (final unit in currentPlayerUnits) {
      unit.updateCooldowns();
    }

    // Update Meta abilities system
    _updateMetaSystem();

    deselectUnit();
    turnPhase = TurnPhase.ended;

    // Switch players
    currentPlayer = currentPlayer == Player.player1 ? Player.player2 : Player.player1;

    if (currentPlayer == Player.player1) {
      turnNumber++;
    }

    // Check win condition
    if (_checkWinCondition()) {
      gamePhase = GamePhase.gameOver;
      return;
    }

    // Start next turn
    _startTurn();
  }

  /// Start new turn
  void _startTurn() {
    turnPhase = TurnPhase.moving;
    turnTimeRemaining = 6.0;
    turnStartTime = DateTime.now();
    isPaused = false;
  }

  /// Update turn timer
  void updateTimer(double deltaTime) {
    if (gamePhase != GamePhase.playing || isPaused || turnStartTime == null) return;

    turnTimeRemaining -= deltaTime;

    if (turnTimeRemaining <= 0) {
      // Auto-end turn when time runs out
      endTurn();
    }
  }

  /// Pause/resume game
  void togglePause() {
    isPaused = !isPaused;
  }

  /// Check if game is over
  bool _checkWinCondition() {
    final p1UnitsAlive = units.where((u) => u.owner == Player.player1 && u.isAlive);
    final p2UnitsAlive = units.where((u) => u.owner == Player.player2 && u.isAlive);

    return p1UnitsAlive.isEmpty || p2UnitsAlive.isEmpty;
  }

  /// Get winner (only valid if game is over)
  Player? get winner {
    if (gamePhase != GamePhase.gameOver) return null;

    final p1UnitsAlive = units.where((u) => u.owner == Player.player1 && u.isAlive);
    final p2UnitsAlive = units.where((u) => u.owner == Player.player2 && u.isAlive);

    if (p1UnitsAlive.isNotEmpty && p2UnitsAlive.isEmpty) return Player.player1;
    if (p2UnitsAlive.isNotEmpty && p1UnitsAlive.isEmpty) return Player.player2;

    return null; // Draw
  }

  /// Get reward progress for current player (0.0 to 1.0)
  double get currentPlayerRewardProgress {
    final rewards = currentPlayer == Player.player1 ? player1Rewards : player2Rewards;
    return (rewards / 61.0).clamp(0.0, 1.0);
  }

  /// Initialize Meta ability system
  void _initializeMetaSystem() {
    // Load Meta ability definitions from config
    metaAbilityDefinitions = {
      MetaAbilityType.spawn: [
        const MetaAbility(
          type: MetaAbilityType.spawn,
          description: 'Create new Minor Unit on adjacent hex',
          range: 1,
          cooldown: 3,
        ),
      ],
      MetaAbilityType.heal: [
        const MetaAbility(
          type: MetaAbilityType.heal,
          description: 'Heal adjacent friendly unit by 1 HP',
          range: 1,
          cooldown: 2,
          healAmount: 1,
        ),
      ],
      MetaAbilityType.shield: [
        const MetaAbility(
          type: MetaAbilityType.shield,
          description: 'Adjacent friendly units take -1 damage for 2 turns',
          range: 1,
          cooldown: 4,
          duration: 2,
        ),
      ],
    };

    // Create Meta hexes at predefined positions
    final metaPositions = [
      const HexCoordinate(0, -2, 2),
      const HexCoordinate(2, -1, -1),
      const HexCoordinate(-2, 1, 1),
      const HexCoordinate(0, 2, -2),
      const HexCoordinate(-1, -1, 2),
      const HexCoordinate(1, 1, -2),
    ];

    metaHexes = metaPositions
        .map((pos) => MetaHex(
              position: pos,
              availableAbilities: [
                metaAbilityDefinitions[MetaAbilityType.spawn]!.first,
                metaAbilityDefinitions[MetaAbilityType.heal]!.first,
                metaAbilityDefinitions[MetaAbilityType.shield]!.first,
              ],
            ))
        .toList();

    activeMetaEffects.clear();
  }

  /// Select a Meta hex for ability use
  void selectMetaHex(MetaHex metaHex) {
    if (metaHex.controlledBy != currentPlayer && metaHex.controlledBy != null) {
      return; // Can't use opponent's controlled Meta hex
    }

    selectedMetaHex = metaHex;
  }

  /// Use Meta ability from selected Meta hex
  bool useMetaAbility(MetaAbilityType abilityType, HexCoordinate target) {
    if (selectedMetaHex == null) return false;

    final matchingAbilities = selectedMetaHex!.availableAbilities
        .where((a) => a.type == abilityType).toList();
    final ability = matchingAbilities.isNotEmpty ? matchingAbilities.first : null;

    if (ability == null || !selectedMetaHex!.isAbilityAvailable(abilityType)) {
      return false;
    }

    // Check if target is within range
    final distance = selectedMetaHex!.position.distanceTo(target);
    if (distance > ability.range) return false;

    // Execute ability effect
    switch (abilityType) {
      case MetaAbilityType.spawn:
        return _executeSpawnAbility(target);
      case MetaAbilityType.heal:
        return _executeHealAbility(target, ability.healAmount!);
      case MetaAbilityType.shield:
        return _executeShieldAbility(target, ability.duration!);
    }
  }

  /// Execute spawn ability - create new Minor unit
  bool _executeSpawnAbility(HexCoordinate target) {
    // Check if target hex is empty
    if (board.getUnitAt(target, units) != null) return false;
    if (!board.isValidCoordinate(target)) return false;

    // Create new Minor unit
    final newUnit = GameUnit.create(
      id: 'spawned_${DateTime.now().millisecondsSinceEpoch}',
      type: UnitType.minor,
      owner: currentPlayer,
      position: target,
    );

    units.add(newUnit);
    selectedMetaHex!.useAbility(MetaAbilityType.spawn);
    selectedMetaHex!.controlledBy = currentPlayer;

    return true;
  }

  /// Execute heal ability - heal target unit
  bool _executeHealAbility(HexCoordinate target, int healAmount) {
    final targetUnit = board.getUnitAt(target, units);
    if (targetUnit == null || targetUnit.owner != currentPlayer) return false;

    targetUnit.heal(healAmount);
    selectedMetaHex!.useAbility(MetaAbilityType.heal);
    selectedMetaHex!.controlledBy = currentPlayer;

    return true;
  }

  /// Execute shield ability - apply damage reduction effect
  bool _executeShieldAbility(HexCoordinate target, int duration) {
    // Find all friendly units within range of target
    final affectedUnits = units.where((unit) =>
        unit.owner == currentPlayer &&
        unit.isAlive &&
        unit.position.distanceTo(target) <= 1);

    if (affectedUnits.isEmpty) return false;

    // Apply shield effect
    final shieldEffect = ActiveMetaEffect(
      type: MetaAbilityType.shield,
      remainingTurns: duration,
      affectedPlayer: currentPlayer,
    );

    activeMetaEffects.add(shieldEffect);
    selectedMetaHex!.useAbility(MetaAbilityType.shield);
    selectedMetaHex!.controlledBy = currentPlayer;

    return true;
  }

  /// Update Meta abilities system each turn
  void _updateMetaSystem() {
    // Update Meta hex cooldowns
    for (final metaHex in metaHexes) {
      metaHex.updateCooldowns();
    }

    // Update active effects
    activeMetaEffects = activeMetaEffects
        .map((effect) => effect.copyWith(
              remainingTurns: effect.remainingTurns - 1,
            ))
        .where((effect) => !effect.isExpired)
        .toList();
  }

  /// Check if unit has shield protection
  bool isUnitShielded(GameUnit unit) {
    return activeMetaEffects.where((effect) =>
        effect.type == MetaAbilityType.shield &&
        effect.affectedPlayer == unit.owner).toList().isNotEmpty;
  }

  /// Get Meta hex at position
  MetaHex? getMetaHexAt(HexCoordinate position) {
    final matchingMetaHexes = metaHexes
        .where((metaHex) => metaHex.position == position).toList();
    return matchingMetaHexes.isNotEmpty ? matchingMetaHexes.first : null;
  }

  /// Reset game to initial state
  void resetGame() {
    units.clear();
    currentPlayer = Player.player1;
    gamePhase = GamePhase.setup;
    turnPhase = TurnPhase.moving;
    turnNumber = 1;
    turnTimeRemaining = 6.0;
    isPaused = false;
    selectedUnit = null;
    selectedMetaHex = null;
    availableMoves.clear();
    availableAttacks.clear();
    remainingMoves = 0;
    originalPosition = null;
    metaHexes.clear();
    activeMetaEffects.clear();
    metaAbilityDefinitions.clear();
    player1Rewards = 0;
    player2Rewards = 0;
    board.clearHighlights();
    initializeGame();
  }
}
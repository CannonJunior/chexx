import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'game_unit.dart';
import 'game_board.dart';
import 'meta_ability.dart';
import 'unit_type_config.dart';
import 'hex_orientation.dart';
import 'action_card.dart';
import '../../core/interfaces/unit_factory.dart';
import '../systems/combat/wwii_combat_system.dart';

enum GamePhase { setup, playing, gameOver }

enum TurnPhase { moving, acting, ended }

// Compatibility enum for the old UnitType system
enum UnitType { minor, scout, knight, guardian }

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

  // Unit type system
  UnitTypeSet? unitTypeSet;

  // Hexagon orientation setting
  HexOrientation hexOrientation;

  // WWII Combat System
  WWIICombatSystem? _combatSystem;
  Function(CombatResult)? onCombatResult;

  // Card system for WWII mode
  ActionCardDeck? _actionCardDeck;
  PlayerHand? _player1Hand;
  PlayerHand? _player2Hand;
  List<ActionCard> _discardPile;
  int _unitsOrderedThisTurn;

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
        player2Rewards = 0,
        hexOrientation = HexOrientation.flat,
        _discardPile = [],
        _unitsOrderedThisTurn = 0;

  /// Initialize game from scenario configuration
  void initializeFromScenario(Map<String, dynamic> scenarioConfig) {
    units.clear();
    metaHexes.clear();

    // Initialize game type system based on scenario configuration
    _initializeGameTypeFromScenario(scenarioConfig);

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

      units.add(createUnit(
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
      units.add(createUnit(
        id: 'p1_major_$i',
        type: majorUnits1[i],
        owner: Player.player1,
        position: p1Positions[i],
      ));
    }

    // Front row: 6 minor units
    for (int i = 0; i < 6; i++) {
      units.add(createUnit(
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
      units.add(createUnit(
        id: 'p2_minor_$i',
        type: UnitType.minor,
        owner: Player.player2,
        position: p2Positions[i],
      ));
    }

    // Back row: 3 major units
    final majorUnits2 = [UnitType.scout, UnitType.knight, UnitType.guardian];
    for (int i = 0; i < majorUnits2.length; i++) {
      units.add(createUnit(
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

    // In WWII mode, players must play a card before selecting units
    if (_actionCardDeck != null && !canOrderUnit()) {
      print('DEBUG: Cannot select unit - no card played in WWII mode');
      return;
    }

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
    if (!_isValidKeyboardMovementForUnitType(originalPosition!, nextPosition, _stringToUnitType(selectedUnit!.unitTypeId))) {
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
        if (_isValidKeyboardMovementForUnitType(originalPosition!, nextPos, _stringToUnitType(selectedUnit!.unitTypeId))) {
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

    // Check if we should use WWII combat system for WWII units
    if (_shouldUseWWIICombat(selectedUnit!, targetUnit)) {
      _performWWIICombat(selectedUnit!, targetUnit, target);
    } else {
      // Use traditional combat for non-WWII units
      _performTraditionalCombat(selectedUnit!, targetUnit);
    }

    // End turn after attacking
    endTurn();
    return true;
  }

  /// Check if WWII combat system should be used
  bool _shouldUseWWIICombat(GameUnit attacker, GameUnit defender) {
    // Use WWII combat if either unit is a WWII type
    final wwiiTypes = ['infantry', 'armor', 'artillery'];
    return wwiiTypes.contains(attacker.unitTypeId) ||
           wwiiTypes.contains(defender.unitTypeId);
  }

  /// Perform WWII-style combat with dice rolling
  Future<void> _performWWIICombat(GameUnit attacker, GameUnit defender, HexCoordinate target) async {
    // Initialize combat system if needed
    _combatSystem ??= await WWIICombatSystemFactory.create();

    // Get unit configurations
    final attackerConfig = attacker.config;
    final defenderConfig = defender.config;

    // Get tile type for defender position
    final tile = board.getTile(target);
    final tileType = tile?.type.toString().split('.').last ?? 'normal';

    try {
      // Execute combat
      final combatResult = await _combatSystem!.executeAttack(
        attacker,
        defender,
        attackerConfig,
        defenderConfig,
        tileType,
      );

      // Gain experience if unit was killed
      if (combatResult.defenderDestroyed) {
        attacker.gainExperience(1);
      }

      // Show combat result to UI if callback is set
      if (onCombatResult != null) {
        onCombatResult!(combatResult);
      }
    } catch (e) {
      print('WWII Combat error: $e');
      // Fallback to traditional combat
      _performTraditionalCombat(attacker, defender);
    }
  }

  /// Perform traditional combat (for non-WWII units)
  void _performTraditionalCombat(GameUnit attacker, GameUnit defender) {
    final damage = attacker.effectiveAttackDamage;
    final hasShield = isUnitShielded(defender);
    final unitKilled = defender.takeDamageWithShield(damage, hasShield);

    // Gain experience if unit was killed
    if (unitKilled) {
      attacker.gainExperience(1);
    }
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

  /// Initialize game type system from scenario configuration
  void _initializeGameTypeFromScenario(Map<String, dynamic> scenarioConfig) {
    // Check if game type is specified in scenario
    final gameTypeId = scenarioConfig['game_type'] as String?;
    print('DEBUG: Initializing game type from scenario: $gameTypeId');

    if (gameTypeId == 'wwii') {
      print('DEBUG: Initializing WWII game system');
      // Initialize WWII-specific systems asynchronously
      _initializeWWIISystemAsync();
    } else {
      print('DEBUG: Using default CHEXX game system (game_type: ${gameTypeId ?? 'not specified'})');
      // Default to CHEXX system - no additional initialization needed
    }
  }

  /// Initialize WWII-specific systems asynchronously
  void _initializeWWIISystemAsync() {
    // Start async initialization - don't block the main initialization
    initializeCardSystem().then((_) {
      print('DEBUG: WWII card system initialized successfully');
      notifyListeners(); // Notify UI that card system is ready
    }).catchError((e) {
      print('Error initializing WWII card system: $e');
    });
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
    final newUnit = createUnit(
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
    resetCardSystem(); // Reset card system
    board.clearHighlights();
    initializeGame();
  }

  /// Initialize unit type set (should be called after creating GameState)
  Future<void> loadUnitTypeSet(String setName) async {
    unitTypeSet = await UnitTypeConfigLoader.loadUnitTypeSet(setName);
  }

  /// Toggle hexagon orientation between flat and pointy
  void toggleHexOrientation() {
    hexOrientation = hexOrientation == HexOrientation.flat
        ? HexOrientation.pointy
        : HexOrientation.flat;
    notifyListeners();
  }

  /// Compatibility method to convert UnitType enum to string
  String _unitTypeToString(UnitType type) {
    switch (type) {
      case UnitType.minor:
        return 'minor';
      case UnitType.scout:
        return 'scout';
      case UnitType.knight:
        return 'knight';
      case UnitType.guardian:
        return 'guardian';
    }
  }

  /// Compatibility method to convert string back to UnitType enum
  UnitType _stringToUnitType(String unitTypeId) {
    switch (unitTypeId) {
      case 'minor':
        return UnitType.minor;
      case 'scout':
        return UnitType.scout;
      case 'knight':
        return UnitType.knight;
      case 'guardian':
        return UnitType.guardian;
      default:
        throw ArgumentError('Unknown unit type: $unitTypeId');
    }
  }

  /// Compatibility method to create units with the new system
  GameUnit createUnit({
    required String id,
    required UnitType type,
    required Player owner,
    required HexCoordinate position,
  }) {
    final unitTypeId = _unitTypeToString(type);
    final config = unitTypeSet?.getUnitConfig(unitTypeId);

    if (config == null) {
      throw StateError('Unit type set not loaded or unit type $unitTypeId not found');
    }

    return GameUnit(
      id: id,
      unitTypeId: unitTypeId,
      config: config,
      owner: owner,
      position: position,
    );
  }

  // ========== CARD MANAGEMENT METHODS ==========

  /// Initialize card system for WWII mode
  Future<void> initializeCardSystem() async {
    _actionCardDeck = await ActionCardDeckLoader.loadWWIIDeck();

    // Deal initial hands to both players
    final shuffledDeck = _actionCardDeck!.shuffle();
    final cardsPerPlayer = 5; // From config

    _player1Hand = PlayerHand(shuffledDeck.cards.take(cardsPerPlayer).toList());
    _player2Hand = PlayerHand(shuffledDeck.cards.skip(cardsPerPlayer).take(cardsPerPlayer).toList());

    _discardPile.clear();
    _unitsOrderedThisTurn = 0;

    notifyListeners();
  }

  /// Get current player's hand
  PlayerHand? get currentPlayerHand {
    return currentPlayer == Player.player1 ? _player1Hand : _player2Hand;
  }

  /// Get opponent's hand
  PlayerHand? get opponentHand {
    return currentPlayer == Player.player1 ? _player2Hand : _player1Hand;
  }

  /// Check if card system is initialized
  bool get isCardSystemInitialized => _actionCardDeck != null && _player1Hand != null && _player2Hand != null;

  /// Play a card from current player's hand
  bool playCard(ActionCard card) {
    final hand = currentPlayerHand;
    if (hand == null || !hand.cards.contains(card)) {
      return false;
    }

    if (hand.hasPlayedCard) {
      return false; // Already played a card this turn
    }

    final success = hand.playCard(card);
    if (success) {
      _unitsOrderedThisTurn = 0; // Reset counter when new card is played
      notifyListeners();
    }
    return success;
  }

  /// Get number of units that can still be ordered this turn
  int get unitsCanOrderRemaining {
    final hand = currentPlayerHand;
    if (hand?.playedCard == null) return 0;
    return hand!.unitsCanOrder - _unitsOrderedThisTurn;
  }

  /// Check if player can order a unit (based on played card)
  bool canOrderUnit() {
    return unitsCanOrderRemaining > 0;
  }

  /// Order a unit (decrements remaining orders)
  bool orderUnit() {
    if (!canOrderUnit()) return false;
    _unitsOrderedThisTurn++;
    notifyListeners();
    return true;
  }

  /// End current player's turn (handle card cleanup and drawing)
  void endPlayerTurn() {
    final hand = currentPlayerHand;
    if (hand != null) {
      // Discard played card and draw new one
      final playedCard = hand.endTurn();
      if (playedCard != null) {
        _discardPile.add(playedCard);

        // Draw new card from deck (if available)
        _drawCardForPlayer(currentPlayer);
      }

      _unitsOrderedThisTurn = 0;
    }

    // Switch players
    currentPlayer = currentPlayer == Player.player1 ? Player.player2 : Player.player1;

    if (currentPlayer == Player.player1) {
      turnNumber++;
    }

    notifyListeners();
  }

  /// Draw a new card for specified player
  void _drawCardForPlayer(Player player) {
    if (_actionCardDeck == null) return;

    final availableCards = _actionCardDeck!.cards
        .where((card) => !_discardPile.contains(card) &&
                         !_player1Hand!.cards.contains(card) &&
                         !_player2Hand!.cards.contains(card) &&
                         _player1Hand?.playedCard != card &&
                         _player2Hand?.playedCard != card)
        .toList();

    if (availableCards.isEmpty) {
      // Reshuffle discard pile back into deck
      _discardPile.clear();
      availableCards.addAll(_actionCardDeck!.cards
          .where((card) => !_player1Hand!.cards.contains(card) &&
                           !_player2Hand!.cards.contains(card) &&
                           _player1Hand?.playedCard != card &&
                           _player2Hand?.playedCard != card));
    }

    if (availableCards.isNotEmpty) {
      availableCards.shuffle();
      final newCard = availableCards.first;

      if (player == Player.player1) {
        _player1Hand?.addCard(newCard);
      } else {
        _player2Hand?.addCard(newCard);
      }
    }
  }

  /// Reset card system (for game reset)
  void resetCardSystem() {
    _actionCardDeck = null;
    _player1Hand = null;
    _player2Hand = null;
    _discardPile.clear();
    _unitsOrderedThisTurn = 0;
  }

  /// Get card system debug info
  Map<String, dynamic> getCardSystemInfo() {
    return {
      'deck_loaded': _actionCardDeck != null,
      'deck_size': _actionCardDeck?.totalCards ?? 0,
      'player1_hand_size': _player1Hand?.size ?? 0,
      'player2_hand_size': _player2Hand?.size ?? 0,
      'discard_pile_size': _discardPile.length,
      'current_player_played_card': currentPlayerHand?.playedCard?.name,
      'units_can_order_remaining': unitsCanOrderRemaining,
      'units_ordered_this_turn': _unitsOrderedThisTurn,
    };
  }
}
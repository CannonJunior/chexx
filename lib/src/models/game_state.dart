import 'hex_coordinate.dart';
import 'game_unit.dart';
import 'game_board.dart';

enum GamePhase { setup, playing, gameOver }

enum TurnPhase { moving, acting, ended }

/// Represents the complete state of the game
class GameState {
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
        player1Rewards = 0,
        player2Rewards = 0;

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
    board.clearHighlights();
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

    // Perform attack
    final damage = selectedUnit!.attackDamage;
    final unitKilled = targetUnit.takeDamage(damage);

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
    availableMoves.clear();
    availableAttacks.clear();
    player1Rewards = 0;
    player2Rewards = 0;
    board.clearHighlights();
    initializeGame();
  }
}
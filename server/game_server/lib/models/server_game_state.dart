import 'package:chexx_shared_models/chexx_shared_models.dart';

/// Server-side game state representation
class ServerGameState {
  final String gameId;
  final String scenarioId;
  final List<PlayerInfo> players;
  final Map<String, dynamic> scenarioConfig;

  int turnNumber;
  int currentPlayer; // 1 or 2
  String gameStatus; // 'setup', 'playing', 'ended'
  List<UnitData> units;
  int player1Points;
  int player2Points;
  int player1WinPoints;
  int player2WinPoints;
  int? winner; // null, 1, or 2
  String? selectedUnitId;

  DateTime createdAt;
  DateTime lastUpdatedAt;

  ServerGameState({
    required this.gameId,
    required this.scenarioId,
    required this.players,
    required this.scenarioConfig,
    this.turnNumber = 1,
    this.currentPlayer = 1,
    this.gameStatus = 'setup',
    List<UnitData>? units,
    this.player1Points = 0,
    this.player2Points = 0,
    this.player1WinPoints = 10,
    this.player2WinPoints = 10,
    this.winner,
    this.selectedUnitId,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) :
    units = units ?? [],
    createdAt = createdAt ?? DateTime.now(),
    lastUpdatedAt = lastUpdatedAt ?? DateTime.now();

  /// Initialize game state from scenario configuration
  void initializeFromScenario() {
    print('Initializing game from scenario: $scenarioId');

    // Extract game type
    final gameType = scenarioConfig['game_type'] as String? ?? 'chexx';
    print('Game type: $gameType');

    // Load units from scenario
    final unitPlacements = scenarioConfig['unit_placements'] as List<dynamic>? ?? [];
    units.clear();

    for (final placementData in unitPlacements) {
      try {
        final placement = placementData as Map<String, dynamic>;
        final templateData = placement['template'] as Map<String, dynamic>;
        final positionData = placement['position'] as Map<String, dynamic>;

        // Create unit data
        final unitId = templateData['id'] as String;
        final unitType = templateData['type'] as String;
        final ownerString = templateData['owner'] as String;
        final owner = ownerString == 'player1' ? 1 : 2;

        final position = HexCoordinateData(
          positionData['q'] as int,
          positionData['r'] as int,
          positionData['s'] as int,
        );

        // Check for saved custom health (for incrementable units)
        final savedHealth = placement['customHealth'] as int?;
        final health = savedHealth ?? _getUnitHealth(unitType);
        final maxHealth = _getUnitMaxHealth(unitType);

        print('Loading unit: $unitType, savedHealth: $savedHealth, actualHealth: $health, maxHealth: $maxHealth');

        units.add(UnitData(
          unitId: unitId,
          unitType: unitType,
          owner: owner,
          position: position,
          health: health,
          maxHealth: maxHealth,
          hasMoved: false,
          hasAttacked: false,
        ));

        print('Loaded unit: $unitType at $position for player $owner with health $health/$maxHealth');
      } catch (e) {
        print('Error loading unit: $e');
      }
    }

    // Load win conditions if available
    final winConditions = scenarioConfig['win_conditions'] as Map<String, dynamic>?;
    if (winConditions != null) {
      player1WinPoints = winConditions['player1_points'] as int? ?? 10;
      player2WinPoints = winConditions['player2_points'] as int? ?? 10;
    }

    // Set game status to playing
    gameStatus = 'playing';
    lastUpdatedAt = DateTime.now();

    print('Game initialized with ${units.length} units');
  }

  /// Get unit health based on type
  int _getUnitHealth(String unitType) {
    switch (unitType.toLowerCase()) {
      case 'minor': return 1;
      case 'scout': return 2;
      case 'knight': return 3;
      case 'guardian': return 3;
      case 'infantry': return 1;
      case 'armor': return 1;
      case 'artillery': return 1;
      default: return 1;
    }
  }

  /// Get unit max health based on type
  int _getUnitMaxHealth(String unitType) {
    switch (unitType.toLowerCase()) {
      case 'minor': return 2;
      case 'scout': return 2;
      case 'knight': return 3;
      case 'guardian': return 3;
      case 'infantry': return 4;
      case 'armor': return 3;
      case 'artillery': return 2;
      default: return 1;
    }
  }

  /// Convert to network snapshot
  GameStateSnapshot toSnapshot() {
    return GameStateSnapshot(
      gameId: gameId,
      turnNumber: turnNumber,
      currentPlayer: currentPlayer,
      players: players,
      units: units,
      player1Points: player1Points,
      player2Points: player2Points,
      player1WinPoints: player1WinPoints,
      player2WinPoints: player2WinPoints,
      gameStatus: gameStatus,
      winner: winner,
      customData: {
        'scenarioId': scenarioId,
        'selectedUnitId': selectedUnitId,
      },
    );
  }

  /// Check victory conditions
  void checkVictory() {
    // Check if either player has enough points
    if (player1Points >= player1WinPoints) {
      gameStatus = 'ended';
      winner = 1;
      print('Player 1 wins by points! ($player1Points >= $player1WinPoints)');
      return;
    }

    if (player2Points >= player2WinPoints) {
      gameStatus = 'ended';
      winner = 2;
      print('Player 2 wins by points! ($player2Points >= $player2WinPoints)');
      return;
    }

    // Check if either player has no units left
    final player1Units = units.where((u) => u.owner == 1).toList();
    final player2Units = units.where((u) => u.owner == 2).toList();

    if (player1Units.isEmpty) {
      gameStatus = 'ended';
      winner = 2;
      print('Player 2 wins by elimination!');
      return;
    }

    if (player2Units.isEmpty) {
      gameStatus = 'ended';
      winner = 1;
      print('Player 1 wins by elimination!');
      return;
    }
  }

  @override
  String toString() {
    return 'ServerGameState(gameId: $gameId, turn: $turnNumber, player: $currentPlayer, units: ${units.length}, status: $gameStatus)';
  }
}

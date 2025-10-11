import 'unit_data.dart';
import 'player_info.dart';

/// Complete snapshot of game state for synchronization
class GameStateSnapshot {
  /// Unique game ID
  final String gameId;

  /// Current turn number
  final int turnNumber;

  /// Current player's turn (player number: 1 or 2)
  final int currentPlayer;

  /// Player information
  final List<PlayerInfo> players;

  /// All units on the board
  final List<UnitData> units;

  /// Player 1 points
  final int player1Points;

  /// Player 2 points
  final int player2Points;

  /// Player 1 win condition points
  final int player1WinPoints;

  /// Player 2 win condition points
  final int player2WinPoints;

  /// Game status (playing, ended, etc.)
  final String gameStatus;

  /// Winner (if game ended) - player number or null
  final int? winner;

  /// Timestamp of this snapshot
  final int timestamp;

  /// Custom game data (scenario config, etc.)
  final Map<String, dynamic>? customData;

  GameStateSnapshot({
    required this.gameId,
    required this.turnNumber,
    required this.currentPlayer,
    required this.players,
    required this.units,
    required this.player1Points,
    required this.player2Points,
    required this.player1WinPoints,
    required this.player2WinPoints,
    this.gameStatus = 'playing',
    this.winner,
    int? timestamp,
    this.customData,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'turnNumber': turnNumber,
      'currentPlayer': currentPlayer,
      'players': players.map((p) => p.toJson()).toList(),
      'units': units.map((u) => u.toJson()).toList(),
      'player1Points': player1Points,
      'player2Points': player2Points,
      'player1WinPoints': player1WinPoints,
      'player2WinPoints': player2WinPoints,
      'gameStatus': gameStatus,
      if (winner != null) 'winner': winner,
      'timestamp': timestamp,
      if (customData != null) 'customData': customData,
    };
  }

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) {
    return GameStateSnapshot(
      gameId: json['gameId'] as String,
      turnNumber: json['turnNumber'] as int,
      currentPlayer: json['currentPlayer'] as int,
      players: (json['players'] as List)
          .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      units: (json['units'] as List)
          .map((u) => UnitData.fromJson(u as Map<String, dynamic>))
          .toList(),
      player1Points: json['player1Points'] as int,
      player2Points: json['player2Points'] as int,
      player1WinPoints: json['player1WinPoints'] as int,
      player2WinPoints: json['player2WinPoints'] as int,
      gameStatus: json['gameStatus'] as String? ?? 'playing',
      winner: json['winner'] as int?,
      timestamp: json['timestamp'] as int?,
      customData: json['customData'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'GameStateSnapshot(gameId: $gameId, turn: $turnNumber, currentPlayer: $currentPlayer, units: ${units.length}, status: $gameStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameStateSnapshot &&
        other.gameId == gameId &&
        other.turnNumber == turnNumber &&
        other.currentPlayer == currentPlayer &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(gameId, turnNumber, currentPlayer, timestamp);
  }
}

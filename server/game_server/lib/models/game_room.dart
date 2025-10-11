import 'package:chexx_shared_models/chexx_shared_models.dart';

/// Represents a game room in the lobby
class GameRoom {
  final String roomId;
  final String scenarioId;
  final String hostClientId;
  final Map<String, dynamic>? gameConfig;
  final DateTime createdAt;

  final Map<int, PlayerInfo> players; // playerNumber -> PlayerInfo
  GameRoomStatus status;

  GameRoom({
    required this.roomId,
    required this.scenarioId,
    required this.hostClientId,
    this.gameConfig,
    DateTime? createdAt,
    this.status = GameRoomStatus.waiting,
  }) :
    players = {},
    createdAt = createdAt ?? DateTime.now();

  /// Add a player to the room
  bool addPlayer(PlayerInfo player) {
    if (players.length >= 2) {
      return false; // Room full
    }

    // Assign player number (1 or 2)
    final playerNumber = players.isEmpty ? 1 : 2;
    final playerWithNumber = player.copyWith(playerNumber: playerNumber);

    players[playerNumber] = playerWithNumber;
    return true;
  }

  /// Remove a player from the room
  void removePlayer(String playerId) {
    players.removeWhere((_, player) => player.playerId == playerId);

    // If no players left, mark for deletion
    if (players.isEmpty) {
      status = GameRoomStatus.abandoned;
    }
  }

  /// Get player by client ID
  PlayerInfo? getPlayerByClientId(String clientId) {
    try {
      return players.values.firstWhere(
        (player) => player.playerId == clientId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if a client is in this room
  bool hasClient(String clientId) {
    return players.values.any((player) => player.playerId == clientId);
  }

  /// Check if room is full (2 players)
  bool get isFull => players.length >= 2;

  /// Check if all players are ready
  bool get allPlayersReady {
    if (players.isEmpty) return false;
    return players.values.every((player) => player.isReady);
  }

  /// Check if room can start (full and all ready)
  bool get canStart => isFull && allPlayersReady;

  /// Set player ready state
  bool setPlayerReady(String clientId, bool ready) {
    final player = players.values.firstWhere(
      (p) => p.playerId == clientId,
      orElse: () => throw StateError('Player not found'),
    );

    final playerNumber = player.playerNumber;
    players[playerNumber] = player.copyWith(isReady: ready);
    return true;
  }

  /// Get room info for network transmission
  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'scenarioId': scenarioId,
      'hostClientId': hostClientId,
      'gameConfig': gameConfig,
      'status': status.toString().split('.').last,
      'players': players.values.map((p) => p.toJson()).toList(),
      'playerCount': players.length,
      'isFull': isFull,
      'canStart': canStart,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'GameRoom(id: $roomId, status: $status, players: ${players.length}/2, ready: $allPlayersReady)';
  }
}

/// Game room status
enum GameRoomStatus {
  waiting,    // Waiting for players
  ready,      // All players ready
  starting,   // Game is starting
  inProgress, // Game in progress
  ended,      // Game ended
  abandoned,  // All players left
}

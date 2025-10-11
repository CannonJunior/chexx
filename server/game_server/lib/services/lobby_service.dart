import 'dart:math';
import 'package:chexx_shared_models/chexx_shared_models.dart';
import '../models/game_room.dart';

/// Manages game lobby and rooms
class LobbyService {
  final Map<String, GameRoom> _rooms = {};
  final Random _random = Random();

  /// Create a new game room
  GameRoom createRoom({
    required String hostClientId,
    required String hostPlayerName,
    required String scenarioId,
    Map<String, dynamic>? gameConfig,
  }) {
    final roomId = _generateRoomId();

    final room = GameRoom(
      roomId: roomId,
      scenarioId: scenarioId,
      hostClientId: hostClientId,
      gameConfig: gameConfig,
    );

    // Add host as first player
    final hostPlayer = PlayerInfo(
      playerId: hostClientId,
      displayName: hostPlayerName,
      playerNumber: 1,
      isReady: false,
    );
    room.addPlayer(hostPlayer);

    _rooms[roomId] = room;

    print('Created room: $roomId for $hostPlayerName');
    return room;
  }

  /// Join an existing room
  GameRoom? joinRoom({
    required String roomId,
    required String clientId,
    required String playerName,
  }) {
    final room = _rooms[roomId];
    if (room == null) {
      print('Room not found: $roomId');
      return null;
    }

    if (room.isFull) {
      print('Room full: $roomId');
      return null;
    }

    if (room.status != GameRoomStatus.waiting) {
      print('Room not accepting players: $roomId (status: ${room.status})');
      return null;
    }

    final player = PlayerInfo(
      playerId: clientId,
      displayName: playerName,
      playerNumber: 2, // Will be assigned by addPlayer
      isReady: false,
    );

    if (room.addPlayer(player)) {
      print('Player $playerName joined room $roomId');
      return room;
    }

    return null;
  }

  /// Leave a room
  void leaveRoom(String roomId, String clientId) {
    final room = _rooms[roomId];
    if (room == null) return;

    room.removePlayer(clientId);
    print('Player $clientId left room $roomId');

    // Clean up abandoned rooms
    if (room.status == GameRoomStatus.abandoned) {
      _rooms.remove(roomId);
      print('Removed abandoned room: $roomId');
    }
  }

  /// Set player ready state
  bool setPlayerReady(String roomId, String clientId, bool ready) {
    final room = _rooms[roomId];
    if (room == null) return false;

    try {
      room.setPlayerReady(clientId, ready);

      // Update room status
      if (room.canStart) {
        room.status = GameRoomStatus.ready;
      } else {
        room.status = GameRoomStatus.waiting;
      }

      print('Player $clientId ready: $ready in room $roomId');
      return true;
    } catch (e) {
      print('Error setting player ready: $e');
      return false;
    }
  }

  /// Start a game
  GameRoom? startGame(String roomId, String clientId) {
    final room = _rooms[roomId];
    if (room == null) return null;

    // Only host can start
    if (room.hostClientId != clientId) {
      print('Only host can start game: $roomId');
      return null;
    }

    // Check if can start
    if (!room.canStart) {
      print('Cannot start game: $roomId (not ready)');
      return null;
    }

    room.status = GameRoomStatus.starting;
    print('Starting game: $roomId');
    return room;
  }

  /// Mark game as in progress
  void markGameInProgress(String roomId) {
    final room = _rooms[roomId];
    if (room != null) {
      room.status = GameRoomStatus.inProgress;
    }
  }

  /// Get a room by ID
  GameRoom? getRoom(String roomId) {
    return _rooms[roomId];
  }

  /// Get room by client ID
  GameRoom? getRoomByClientId(String clientId) {
    return _rooms.values.firstWhere(
      (room) => room.hasClient(clientId),
      orElse: () => throw StateError('No room found for client'),
    );
  }

  /// List all available rooms
  List<GameRoom> listRooms() {
    return _rooms.values
        .where((room) => room.status == GameRoomStatus.waiting && !room.isFull)
        .toList();
  }

  /// Generate a unique room ID
  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String id;

    do {
      id = List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
    } while (_rooms.containsKey(id));

    return id;
  }

  /// Clean up disconnected player
  void handleDisconnect(String clientId) {
    // Find and remove player from any room
    for (final room in _rooms.values) {
      if (room.hasClient(clientId)) {
        room.removePlayer(clientId);

        // Mark player as disconnected
        try {
          final player = room.getPlayerByClientId(clientId);
          if (player != null) {
            final playerNumber = player.playerNumber;
            room.players[playerNumber] = player.copyWith(isConnected: false);
          }
        } catch (e) {
          // Player already removed
        }

        // Clean up abandoned rooms
        if (room.status == GameRoomStatus.abandoned) {
          _rooms.remove(room.roomId);
          print('Removed abandoned room after disconnect: ${room.roomId}');
        }
        break;
      }
    }
  }

  /// Get lobby statistics
  Map<String, dynamic> getStats() {
    return {
      'totalRooms': _rooms.length,
      'waitingRooms': _rooms.values.where((r) => r.status == GameRoomStatus.waiting).length,
      'activeGames': _rooms.values.where((r) => r.status == GameRoomStatus.inProgress).length,
      'totalPlayers': _rooms.values.fold(0, (sum, room) => sum + room.players.length),
    };
  }
}

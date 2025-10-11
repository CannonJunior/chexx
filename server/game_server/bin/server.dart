import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chexx_shared_models/chexx_shared_models.dart';

import '../lib/services/lobby_service.dart';
import '../lib/services/game_state_manager.dart';

// Global services
final lobbyService = LobbyService();
final gameStateManager = GameStateManager();

// Connection Manager to track connected clients
class ConnectionManager {
  final Map<String, WebSocketChannel> _connections = {};
  final Map<String, Timer> _heartbeatTimers = {};

  void addConnection(String clientId, WebSocketChannel channel) {
    _connections[clientId] = channel;
    print('Client connected: $clientId (Total: ${_connections.length})');

    // Start heartbeat timer for this client
    _startHeartbeat(clientId);

    // Listen for messages
    channel.stream.listen(
      (message) => _handleMessage(clientId, message),
      onDone: () => removeConnection(clientId),
      onError: (error) {
        print('Error from client $clientId: $error');
        removeConnection(clientId);
      },
    );
  }

  void removeConnection(String clientId) {
    _connections.remove(clientId);
    _heartbeatTimers[clientId]?.cancel();
    _heartbeatTimers.remove(clientId);

    // Notify lobby service of disconnection
    lobbyService.handleDisconnect(clientId);

    print('Client disconnected: $clientId (Total: ${_connections.length})');
  }

  void _startHeartbeat(String clientId) {
    // Send ping every 30 seconds
    _heartbeatTimers[clientId] = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_connections.containsKey(clientId)) {
        final ping = NetworkMessage(
          type: MessageType.ping,
          clientId: clientId,
        );
        sendToClient(clientId, ping);
      } else {
        timer.cancel();
      }
    });
  }

  void _handleMessage(String clientId, dynamic message) {
    try {
      // Parse message using NetworkMessage
      final networkMessage = NetworkMessage.fromJsonString(message as String);
      print('Message from $clientId: ${networkMessage.type}');

      switch (networkMessage.type) {
        case MessageType.pong:
          // Client responded to ping
          print('Received PONG from $clientId');
          break;

        case MessageType.ping:
          // Client sent ping, respond with pong
          final response = NetworkMessage(
            type: MessageType.pong,
            clientId: clientId,
          );
          sendToClient(clientId, response);
          break;

        case MessageType.createGame:
          _handleCreateGame(clientId, networkMessage);
          break;

        case MessageType.joinGame:
          _handleJoinGame(clientId, networkMessage);
          break;

        case MessageType.leaveGame:
          _handleLeaveGame(clientId, networkMessage);
          break;

        case MessageType.listGames:
          _handleListGames(clientId);
          break;

        case MessageType.startGame:
          _handleStartGame(clientId, networkMessage);
          break;

        case 'SET_READY':
          _handleSetReady(clientId, networkMessage);
          break;

        case MessageType.gameAction:
          _handleGameAction(clientId, networkMessage);
          break;

        case 'ECHO':
          // Echo back for testing (legacy support)
          final response = NetworkMessage(
            type: 'ECHO_RESPONSE',
            clientId: clientId,
            payload: {
              'originalMessage': networkMessage.payload?['payload'],
            },
          );
          sendToClient(clientId, response);
          break;

        default:
          // Unknown message type - echo it back for now
          final response = NetworkMessage(
            type: 'UNKNOWN',
            clientId: clientId,
            payload: {
              'received': networkMessage.toJson(),
            },
          );
          sendToClient(clientId, response);
      }
    } catch (e) {
      print('Error handling message from $clientId: $e');
      final errorMessage = NetworkMessage(
        type: MessageType.error,
        clientId: clientId,
        payload: {
          'message': 'Invalid message format',
          'error': e.toString(),
        },
      );
      sendToClient(clientId, errorMessage);
    }
  }

  void sendToClient(String clientId, NetworkMessage message) {
    final channel = _connections[clientId];
    if (channel != null) {
      try {
        channel.sink.add(message.toJsonString());
      } catch (e) {
        print('Error sending to client $clientId: $e');
        removeConnection(clientId);
      }
    }
  }

  void broadcast(NetworkMessage message) {
    final encoded = message.toJsonString();
    for (final entry in _connections.entries) {
      try {
        entry.value.sink.add(encoded);
      } catch (e) {
        print('Error broadcasting to ${entry.key}: $e');
        removeConnection(entry.key);
      }
    }
  }

  int get connectionCount => _connections.length;

  // Lobby message handlers
  void _handleCreateGame(String clientId, NetworkMessage message) {
    final scenarioId = message.payload?['scenarioId'] as String? ?? 'default';
    final playerName = message.payload?['playerName'] as String? ?? 'Player';
    final gameConfig = message.payload?['gameConfig'] as Map<String, dynamic>?;

    final room = lobbyService.createRoom(
      hostClientId: clientId,
      hostPlayerName: playerName,
      scenarioId: scenarioId,
      gameConfig: gameConfig,
    );

    // Send success response to creator
    final response = NetworkMessage(
      type: MessageType.gameCreated,
      clientId: clientId,
      payload: {
        'gameId': room.roomId,
        'room': room.toJson(),
      },
    );
    sendToClient(clientId, response);

    print('Game created: ${room.roomId} by $playerName');
  }

  void _handleJoinGame(String clientId, NetworkMessage message) {
    final gameId = message.payload?['gameId'] as String?;
    final playerName = message.payload?['playerName'] as String? ?? 'Player';

    if (gameId == null) {
      _sendError(clientId, 'Game ID required');
      return;
    }

    final room = lobbyService.joinRoom(
      roomId: gameId,
      clientId: clientId,
      playerName: playerName,
    );

    if (room == null) {
      _sendError(clientId, 'Could not join game (full or not found)');
      return;
    }

    // Send success response to joiner
    final joinResponse = NetworkMessage(
      type: MessageType.gameJoined,
      clientId: clientId,
      payload: {
        'gameId': room.roomId,
        'room': room.toJson(),
      },
    );
    sendToClient(clientId, joinResponse);

    // Notify all players in room
    _broadcastToRoom(room.roomId, NetworkMessage(
      type: MessageType.playerJoined,
      payload: {
        'gameId': room.roomId,
        'room': room.toJson(),
      },
    ));

    print('Player $playerName joined game ${room.roomId}');
  }

  void _handleLeaveGame(String clientId, NetworkMessage message) {
    final gameId = message.payload?['gameId'] as String?;

    if (gameId == null) {
      _sendError(clientId, 'Game ID required');
      return;
    }

    lobbyService.leaveRoom(gameId, clientId);

    final response = NetworkMessage(
      type: MessageType.gameLeft,
      clientId: clientId,
      payload: {'gameId': gameId},
    );
    sendToClient(clientId, response);

    // Notify remaining players
    final room = lobbyService.getRoom(gameId);
    if (room != null) {
      _broadcastToRoom(room.roomId, NetworkMessage(
        type: MessageType.playerLeft,
        payload: {
          'gameId': room.roomId,
          'room': room.toJson(),
        },
      ));
    }
  }

  void _handleListGames(String clientId) {
    final rooms = lobbyService.listRooms();

    final response = NetworkMessage(
      type: MessageType.gamesListed,
      clientId: clientId,
      payload: {
        'games': rooms.map((r) => r.toJson()).toList(),
      },
    );
    sendToClient(clientId, response);
  }

  void _handleSetReady(String clientId, NetworkMessage message) {
    final gameId = message.payload?['gameId'] as String?;
    final ready = message.payload?['ready'] as bool? ?? false;

    if (gameId == null) {
      _sendError(clientId, 'Game ID required');
      return;
    }

    final success = lobbyService.setPlayerReady(gameId, clientId, ready);

    if (!success) {
      _sendError(clientId, 'Could not set ready state');
      return;
    }

    // Broadcast updated room state to all players
    final room = lobbyService.getRoom(gameId);
    if (room != null) {
      _broadcastToRoom(room.roomId, NetworkMessage(
        type: 'ROOM_UPDATE',
        payload: {
          'gameId': room.roomId,
          'room': room.toJson(),
        },
      ));
    }

    print('Player $clientId ready: $ready in game $gameId');
  }

  void _handleStartGame(String clientId, NetworkMessage message) async {
    final gameId = message.payload?['gameId'] as String?;

    if (gameId == null) {
      _sendError(clientId, 'Game ID required');
      return;
    }

    final room = lobbyService.startGame(gameId, clientId);

    if (room == null) {
      _sendError(clientId, 'Cannot start game (not host or not ready)');
      return;
    }

    // Mark game as in progress
    lobbyService.markGameInProgress(gameId);

    // Create game state from scenario
    try {
      final gameState = await gameStateManager.createGame(
        gameId: gameId,
        scenarioId: room.scenarioId,
        players: room.players.values.toList(),
      );

      // Get initial state snapshot
      final initialState = gameStateManager.getStateSnapshot(gameId);

      // Broadcast game started with initial state to all players
      _broadcastToRoom(room.roomId, NetworkMessage(
        type: MessageType.gameStarted,
        payload: {
          'gameId': room.roomId,
          'room': room.toJson(),
          'gameState': initialState.toJson(),
        },
      ));

      print('Game started: ${room.roomId} with scenario: ${room.scenarioId}');
    } catch (e) {
      print('Error starting game: $e');
      _sendError(clientId, 'Failed to start game: $e');
    }
  }

  void _handleGameAction(String clientId, NetworkMessage message) {
    final gameId = message.payload?['gameId'] as String?;
    final actionData = message.payload?['action'] as Map<String, dynamic>?;

    if (gameId == null || actionData == null) {
      _sendError(clientId, 'Game action requires gameId and action');
      return;
    }

    try {
      // Parse game action
      final action = GameAction.fromJson(actionData);

      // Process action through game state manager
      final result = gameStateManager.processAction(gameId, action);

      if (!result.success) {
        _sendError(clientId, result.error ?? 'Action failed');
        return;
      }

      // If state changed, broadcast update to all players in the room
      if (result.stateChanged) {
        final stateSnapshot = gameStateManager.getStateSnapshot(gameId);

        _broadcastToRoom(gameId, NetworkMessage(
          type: MessageType.stateUpdate,
          payload: {
            'gameId': gameId,
            'gameState': stateSnapshot.toJson(),
          },
        ));

        print('Game action processed: ${action.actionType} by player ${action.playerId}');
      }

      // Send action result to client
      final response = NetworkMessage(
        type: MessageType.actionResult,
        clientId: clientId,
        payload: {
          'success': true,
          'gameId': gameId,
          'action': action.toJson(),
        },
      );
      sendToClient(clientId, response);
    } catch (e) {
      print('Error processing game action: $e');
      _sendError(clientId, 'Failed to process action: $e');
    }
  }

  void _broadcastToRoom(String roomId, NetworkMessage message) {
    final room = lobbyService.getRoom(roomId);
    if (room == null) return;

    for (final player in room.players.values) {
      sendToClient(player.playerId, message);
    }
  }

  void _sendError(String clientId, String errorMessage) {
    final response = NetworkMessage(
      type: MessageType.error,
      clientId: clientId,
      payload: {'message': errorMessage},
    );
    sendToClient(clientId, response);
  }
}

// Global connection manager
final connectionManager = ConnectionManager();

// WebSocket handler
Handler wsHandler = webSocketHandler((WebSocketChannel webSocket) {
  // Generate unique client ID
  final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}_${_nextClientId++}';

  // Add to connection manager
  connectionManager.addConnection(clientId, webSocket);

  // Send welcome message
  final welcomeMessage = NetworkMessage(
    type: MessageType.connected,
    clientId: clientId,
    payload: {
      'message': 'Welcome to Chexx Game Server',
      'version': '2.0.0',
    },
  );
  webSocket.sink.add(welcomeMessage.toJsonString());
});

int _nextClientId = 0;

// CORS middleware for development
Middleware corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        });
      }

      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
      });
    };
  };
}

// Configure routes with WebSocket support
Handler _createHandler() {
  final router = Router()
    ..get('/', _rootHandler)
    ..get('/status', _statusHandler);

  return (Request request) {
    // Check if this is a WebSocket upgrade request for /ws
    if (request.url.path == 'ws' &&
        request.headers['upgrade']?.toLowerCase() == 'websocket') {
      return wsHandler(request);
    }

    // Otherwise use router
    return router(request);
  };
}

Response _rootHandler(Request req) {
  return Response.ok('''
Chexx Game Server

WebSocket endpoint: ws://localhost:8888/ws
Status endpoint: http://localhost:8888/status

Server is running and ready to accept connections.
''');
}

Response _statusHandler(Request req) {
  return Response.ok(
    jsonEncode({
      'status': 'online',
      'connections': connectionManager.connectionCount,
      'timestamp': DateTime.now().toIso8601String(),
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline with CORS and logging
  final handler = Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(_createHandler());

  // IMPORTANT: Use port 8888 as per project requirements
  final port = int.parse(Platform.environment['PORT'] ?? '8888');

  final server = await serve(handler, ip, port);
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  🎯 Chexx Game Server Started');
  print('═══════════════════════════════════════════════════════');
  print('  Host: ${server.address.address}');
  print('  Port: ${server.port}');
  print('');
  print('  HTTP: http://localhost:${server.port}');
  print('  WebSocket: ws://localhost:${server.port}/ws');
  print('  Status: http://localhost:${server.port}/status');
  print('');
  print('  Press Ctrl+C to stop the server');
  print('═══════════════════════════════════════════════════════');
  print('');
}

import 'dart:async';
import 'package:chexx_shared_models/chexx_shared_models.dart';
import 'websocket_manager.dart';
import 'connection_state.dart';

/// High-level network service for game operations
class GameNetworkService {
  final WebSocketManager _wsManager;

  // Message streams
  final _gameCreatedController = StreamController<String>.broadcast();
  final _gameJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStartedController = StreamController<GameStateSnapshot>.broadcast();
  final _stateUpdateController = StreamController<GameStateSnapshot>.broadcast();
  final _actionResultController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  GameNetworkService(this._wsManager) {
    // Subscribe to incoming messages and route them
    _wsManager.messages.listen(_handleMessage);
  }

  /// Stream of game created events (emits gameId)
  Stream<String> get onGameCreated => _gameCreatedController.stream;

  /// Stream of game joined events
  Stream<Map<String, dynamic>> get onGameJoined => _gameJoinedController.stream;

  /// Stream of game started events with initial state
  Stream<GameStateSnapshot> get onGameStarted => _gameStartedController.stream;

  /// Stream of state updates
  Stream<GameStateSnapshot> get onStateUpdate => _stateUpdateController.stream;

  /// Stream of action results
  Stream<Map<String, dynamic>> get onActionResult => _actionResultController.stream;

  /// Stream of error messages
  Stream<String> get onError => _errorController.stream;

  /// Connection status stream
  Stream<ConnectionStatus> get connectionStatus => _wsManager.status;

  /// Current connection status
  ConnectionStatus get currentStatus => _wsManager.currentStatus;

  /// Client ID (if connected)
  String? get clientId => _wsManager.clientId;

  /// Whether connected to server
  bool get isConnected => _wsManager.isConnected;

  /// Connect to the game server
  Future<void> connect() async {
    await _wsManager.connect();
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    await _wsManager.disconnect();
  }

  /// Create a new game
  void createGame({
    required String scenarioId,
    required String playerName,
    Map<String, dynamic>? gameConfig,
  }) {
    final message = NetworkMessage(
      type: MessageType.createGame,
      clientId: clientId,
      payload: {
        'scenarioId': scenarioId,
        'playerName': playerName,
        if (gameConfig != null) 'gameConfig': gameConfig,
      },
    );
    _wsManager.send(message);
  }

  /// Join an existing game
  void joinGame({
    required String gameId,
    required String playerName,
  }) {
    final message = NetworkMessage(
      type: MessageType.joinGame,
      clientId: clientId,
      payload: {
        'gameId': gameId,
        'playerName': playerName,
      },
    );
    _wsManager.send(message);
  }

  /// Leave the current game
  void leaveGame(String gameId) {
    final message = NetworkMessage(
      type: MessageType.leaveGame,
      clientId: clientId,
      payload: {
        'gameId': gameId,
      },
    );
    _wsManager.send(message);
  }

  /// Request list of available games
  void listGames() {
    final message = NetworkMessage(
      type: MessageType.listGames,
      clientId: clientId,
    );
    _wsManager.send(message);
  }

  /// Start the game (host only)
  void startGame(String gameId) {
    final message = NetworkMessage(
      type: MessageType.startGame,
      clientId: clientId,
      payload: {
        'gameId': gameId,
      },
    );
    _wsManager.send(message);
  }

  /// Send a game action
  void sendAction(String gameId, GameAction action) {
    final message = NetworkMessage(
      type: MessageType.gameAction,
      clientId: clientId,
      payload: {
        'gameId': gameId,
        'action': action.toJson(),
      },
    );
    _wsManager.send(message);
  }

  /// End turn
  void endTurn(String gameId) {
    final message = NetworkMessage(
      type: MessageType.endTurn,
      clientId: clientId,
      payload: {
        'gameId': gameId,
      },
    );
    _wsManager.send(message);
  }

  /// Request full state sync
  void requestStateSync(String gameId) {
    final message = NetworkMessage(
      type: MessageType.stateSync,
      clientId: clientId,
      payload: {
        'gameId': gameId,
      },
    );
    _wsManager.send(message);
  }

  /// Handle incoming messages and route to appropriate streams
  void _handleMessage(NetworkMessage message) {
    print('GameNetworkService: Received ${message.type}');

    switch (message.type) {
      case MessageType.gameCreated:
        final gameId = message.payload?['gameId'] as String?;
        if (gameId != null) {
          _gameCreatedController.add(gameId);
        }
        break;

      case MessageType.gameJoined:
        if (message.payload != null) {
          _gameJoinedController.add(message.payload!);
        }
        break;

      case MessageType.gameStarted:
        if (message.payload?['gameState'] != null) {
          final snapshot = GameStateSnapshot.fromJson(
            message.payload!['gameState'] as Map<String, dynamic>,
          );
          _gameStartedController.add(snapshot);
        }
        break;

      case MessageType.stateUpdate:
      case MessageType.fullState:
        if (message.payload?['gameState'] != null) {
          final snapshot = GameStateSnapshot.fromJson(
            message.payload!['gameState'] as Map<String, dynamic>,
          );
          _stateUpdateController.add(snapshot);
        }
        break;

      case MessageType.actionResult:
        if (message.payload != null) {
          _actionResultController.add(message.payload!);
        }
        break;

      case MessageType.error:
        final errorMsg = message.payload?['message'] as String? ?? 'Unknown error';
        _errorController.add(errorMsg);
        break;

      default:
        print('Unhandled message type: ${message.type}');
    }
  }

  /// Clean up resources
  void dispose() {
    _gameCreatedController.close();
    _gameJoinedController.close();
    _gameStartedController.close();
    _stateUpdateController.close();
    _actionResultController.close();
    _errorController.close();
    _wsManager.dispose();
  }
}

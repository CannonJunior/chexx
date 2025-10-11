import 'package:flutter/material.dart';
import 'package:chexx_shared_models/chexx_shared_models.dart';
import 'network_service_provider.dart';
import 'connection_state.dart' as network;

/// Test screen for multiplayer network functionality
class MultiplayerTestScreen extends StatefulWidget {
  const MultiplayerTestScreen({super.key});

  @override
  State<MultiplayerTestScreen> createState() => _MultiplayerTestScreenState();
}

class _MultiplayerTestScreenState extends State<MultiplayerTestScreen> {
  final _playerNameController = TextEditingController(text: 'Player1');
  final _gameIdController = TextEditingController();
  final _serverUrlController = TextEditingController(text: 'ws://localhost:8888/ws');

  network.ConnectionStatus? _connectionStatus;
  final List<String> _messages = [];
  String? _currentGameId;
  Map<String, dynamic>? _currentRoom;

  @override
  void initState() {
    super.initState();
    _initializeNetworkServices();
  }

  void _initializeNetworkServices() {
    // Initialize network services
    NetworkServiceProvider.initialize(
      serverUrl: _serverUrlController.text,
    );

    final gameService = NetworkServiceProvider.instance.gameService;

    // Listen to connection status
    gameService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
          _addMessage('Connection: ${status.state.name}');
        });
      }
    });

    // Listen to game events
    gameService.onGameCreated.listen((gameId) {
      _addMessage('Game created: $gameId');
      setState(() {
        _currentGameId = gameId;
        _gameIdController.text = gameId;
      });
    });

    gameService.onGameJoined.listen((data) {
      final gameId = data['gameId'] as String?;
      final room = data['room'] as Map<String, dynamic>?;
      _addMessage('Joined game: $gameId');
      setState(() {
        _currentGameId = gameId;
        _currentRoom = room;
      });
    });

    gameService.onGameStarted.listen((snapshot) {
      _addMessage('Game started! Turn ${snapshot.turnNumber}');
    });

    gameService.onStateUpdate.listen((snapshot) {
      _addMessage('State update: Turn ${snapshot.turnNumber}, Player ${snapshot.currentPlayer}');
    });

    gameService.onError.listen((error) {
      _addMessage('ERROR: $error', isError: true);
    });

    // Listen to custom messages
    NetworkServiceProvider.instance.wsManager.messages.listen((message) {
      if (message.type == 'ROOM_UPDATE') {
        setState(() {
          _currentRoom = message.payload?['room'] as Map<String, dynamic>?;
        });
        _addMessage('Room updated');
      }
    });
  }

  void _addMessage(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now().toString().split('.')[0];
        _messages.insert(0, '[$timestamp] $message');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameService = NetworkServiceProvider.instance.gameService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Network Test'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Server URL
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
              ),
              enabled: !gameService.isConnected,
            ),
            const SizedBox(height: 8),

            // Connection Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: gameService.isConnected ? null : () => gameService.connect(),
                    icon: const Icon(Icons.login),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !gameService.isConnected ? null : () => gameService.disconnect(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Player Name
            TextField(
              controller: _playerNameController,
              decoration: const InputDecoration(
                labelText: 'Player Name',
                border: OutlineInputBorder(),
              ),
              enabled: gameService.isConnected,
            ),
            const SizedBox(height: 8),

            // Game Actions
            if (_currentGameId == null) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !gameService.isConnected
                          ? null
                          : () {
                              gameService.createGame(
                                scenarioId: 'test_scenario',
                                playerName: _playerNameController.text,
                              );
                            },
                      child: const Text('Create Game'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !gameService.isConnected
                          ? null
                          : () {
                              final gameId = _gameIdController.text.trim();
                              if (gameId.isNotEmpty) {
                                gameService.joinGame(
                                  gameId: gameId,
                                  playerName: _playerNameController.text,
                                );
                              }
                            },
                      child: const Text('Join Game'),
                    ),
                  ),
                ],
              ),
            ],

            if (_currentGameId != null) ...[
              // Current room controls
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final ready = !(_currentRoom?['players']?[0]?['isReady'] ?? false);
                        NetworkServiceProvider.instance.wsManager.send(
                          NetworkMessage(
                            type: 'SET_READY',
                            payload: {
                              'gameId': _currentGameId!,
                              'ready': ready,
                            },
                          ),
                        );
                      },
                      child: Text(_currentRoom?['players']?[0]?['isReady'] == true ? 'Unready' : 'Ready'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentRoom?['canStart'] == true
                          ? () {
                              gameService.startGame(_currentGameId!);
                            }
                          : null,
                      child: const Text('Start Game'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  gameService.leaveGame(_currentGameId!);
                  setState(() {
                    _currentGameId = null;
                    _currentRoom = null;
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                child: const Text('Leave Game'),
              ),
            ],
            const SizedBox(height: 8),

            // Game ID
            TextField(
              controller: _gameIdController,
              decoration: const InputDecoration(
                labelText: 'Game ID',
                border: OutlineInputBorder(),
              ),
              enabled: gameService.isConnected,
            ),
            const SizedBox(height: 16),

            // Current Room Status
            if (_currentRoom != null) ...[
              Card(
                color: Colors.blue.shade900.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room: $_currentGameId',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Players: ${_currentRoom!['playerCount']}/2'),
                      Text('Can Start: ${_currentRoom!['canStart']}'),
                      const SizedBox(height: 8),
                      ...(_currentRoom!['players'] as List? ?? []).map((player) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                player['isReady'] ? Icons.check_circle : Icons.circle_outlined,
                                color: player['isReady'] ? Colors.green : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text('${player['displayName']} (P${player['playerNumber']})'),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Messages
            const Text(
              'Messages:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isError = message.contains('ERROR');
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: isError ? Colors.red.shade300 : Colors.green.shade300,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _connectionStatus;
    Color statusColor;
    IconData statusIcon;

    if (status == null) {
      statusColor = Colors.grey;
      statusIcon = Icons.circle;
    } else {
      switch (status.state) {
        case network.NetworkConnectionState.connected:
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          break;
        case network.NetworkConnectionState.connecting:
        case network.NetworkConnectionState.reconnecting:
          statusColor = Colors.orange;
          statusIcon = Icons.refresh;
          break;
        case network.NetworkConnectionState.failed:
          statusColor = Colors.red;
          statusIcon = Icons.error;
          break;
        case network.NetworkConnectionState.disconnected:
          statusColor = Colors.grey;
          statusIcon = Icons.circle;
          break;
      }
    }

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status?.state.name.toUpperCase() ?? 'NOT INITIALIZED',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (status?.clientId != null)
                    Text(
                      'Client ID: ${status!.clientId}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (status?.error != null)
                    Text(
                      'Error: ${status!.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _gameIdController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }
}

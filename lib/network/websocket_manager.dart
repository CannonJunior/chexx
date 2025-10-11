import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chexx_shared_models/chexx_shared_models.dart';
import 'connection_state.dart';

/// Manages WebSocket connection lifecycle with automatic reconnection
class WebSocketManager {
  final String serverUrl;
  final Duration heartbeatInterval;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final _messageController = StreamController<NetworkMessage>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _currentStatus = const ConnectionStatus(
    state: NetworkConnectionState.disconnected,
  );

  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;
  String? _clientId;

  WebSocketManager({
    required this.serverUrl,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 5,
  });

  /// Stream of incoming messages
  Stream<NetworkMessage> get messages => _messageController.stream;

  /// Stream of connection status changes
  Stream<ConnectionStatus> get status => _statusController.stream;

  /// Current connection status
  ConnectionStatus get currentStatus => _currentStatus;

  /// Current client ID (if connected)
  String? get clientId => _clientId;

  /// Whether currently connected
  bool get isConnected => _currentStatus.isConnected;

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_currentStatus.isConnected || _currentStatus.isConnecting) {
      print('Already connected or connecting');
      return;
    }

    _shouldReconnect = true;
    await _attemptConnection();
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectAttempts = 0;

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    await _channel?.sink.close();
    _channel = null;
    _clientId = null;

    _updateStatus(NetworkConnectionState.disconnected);
  }

  /// Send a message to the server
  void send(NetworkMessage message) {
    if (!isConnected) {
      print('Cannot send message: not connected');
      return;
    }

    try {
      _channel?.sink.add(message.toJsonString());
      print('Sent message: ${message.type}');
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Send a PING to keep connection alive
  void sendPing() {
    send(NetworkMessage(
      type: MessageType.ping,
      clientId: _clientId,
    ));
  }

  /// Attempt to establish WebSocket connection
  Future<void> _attemptConnection() async {
    _updateStatus(
      _reconnectAttempts > 0
        ? NetworkConnectionState.reconnecting
        : NetworkConnectionState.connecting,
      reconnectAttempts: _reconnectAttempts,
    );

    try {
      // Determine the actual WebSocket URL based on platform and protocol
      final wsUrl = _getWebSocketUrl();
      print('Connecting to WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      // Connection successful - wait for CONNECTED message
      print('WebSocket connection established');
    } catch (e) {
      print('Connection error: $e');
      _handleError(e);
    }
  }

  /// Get the appropriate WebSocket URL for the current platform
  String _getWebSocketUrl() {
    // If serverUrl already has ws:// or wss://, use it as-is
    if (serverUrl.startsWith('ws://') || serverUrl.startsWith('wss://')) {
      return serverUrl;
    }

    // Otherwise, construct the URL based on platform
    final uri = Uri.parse(serverUrl);

    // For localhost on web, use the same protocol as the page
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return 'ws://${uri.host}:${uri.port}${uri.path}';
    }

    // For production, use secure WebSocket
    return 'wss://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    try {
      final networkMessage = NetworkMessage.fromJsonString(message as String);
      print('Received: ${networkMessage.type}');

      // Handle connection handshake
      if (networkMessage.type == MessageType.connected) {
        _clientId = networkMessage.clientId;
        _reconnectAttempts = 0;
        _updateStatus(
          NetworkConnectionState.connected,
          clientId: _clientId,
          connectedAt: DateTime.now(),
        );

        // Start heartbeat
        _startHeartbeat();

        print('Connected! Client ID: $_clientId');
      }

      // Handle PING from server
      if (networkMessage.type == MessageType.ping) {
        send(NetworkMessage(
          type: MessageType.pong,
          clientId: _clientId,
        ));
      }

      // Emit message to subscribers
      _messageController.add(networkMessage);
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  /// Handle WebSocket error
  void _handleError(dynamic error) {
    print('WebSocket error: $error');

    _updateStatus(
      NetworkConnectionState.failed,
      error: error.toString(),
    );

    // Try to reconnect if appropriate
    if (_shouldReconnect && _reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  /// Handle WebSocket disconnection
  void _handleDisconnect() {
    print('WebSocket disconnected');

    _heartbeatTimer?.cancel();
    _clientId = null;

    if (_shouldReconnect && _reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      _updateStatus(
        _reconnectAttempts >= maxReconnectAttempts
          ? NetworkConnectionState.failed
          : NetworkConnectionState.disconnected,
        error: _reconnectAttempts >= maxReconnectAttempts
          ? 'Max reconnect attempts reached'
          : null,
      );
    }
  }

  /// Schedule a reconnection attempt
  void _scheduleReconnect() {
    _reconnectAttempts++;
    print('Scheduling reconnect attempt $_reconnectAttempts in ${reconnectDelay.inSeconds}s');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () async {
      await _attemptConnection();
    });
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (isConnected) {
        sendPing();
      }
    });
  }

  /// Update connection status
  void _updateStatus(
    NetworkConnectionState state, {
    String? error,
    String? clientId,
    DateTime? connectedAt,
    int? reconnectAttempts,
  }) {
    _currentStatus = _currentStatus.copyWith(
      state: state,
      error: error,
      clientId: clientId,
      connectedAt: connectedAt,
      reconnectAttempts: reconnectAttempts,
    );
    _statusController.add(_currentStatus);
  }

  /// Clean up resources
  void dispose() {
    _shouldReconnect = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
  }
}

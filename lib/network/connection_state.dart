/// Connection state for the WebSocket
enum NetworkConnectionState {
  /// Not connected
  disconnected,

  /// Attempting to connect
  connecting,

  /// Successfully connected
  connected,

  /// Connection lost, attempting to reconnect
  reconnecting,

  /// Connection failed and won't retry
  failed,
}

/// Connection status with metadata
class ConnectionStatus {
  final NetworkConnectionState state;
  final String? error;
  final String? clientId;
  final DateTime? connectedAt;
  final int reconnectAttempts;

  const ConnectionStatus({
    required this.state,
    this.error,
    this.clientId,
    this.connectedAt,
    this.reconnectAttempts = 0,
  });

  ConnectionStatus copyWith({
    NetworkConnectionState? state,
    String? error,
    String? clientId,
    DateTime? connectedAt,
    int? reconnectAttempts,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      error: error ?? this.error,
      clientId: clientId ?? this.clientId,
      connectedAt: connectedAt ?? this.connectedAt,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }

  bool get isConnected => state == NetworkConnectionState.connected;
  bool get isConnecting => state == NetworkConnectionState.connecting;
  bool get isReconnecting => state == NetworkConnectionState.reconnecting;
  bool get isDisconnected => state == NetworkConnectionState.disconnected;
  bool get isFailed => state == NetworkConnectionState.failed;

  @override
  String toString() {
    return 'ConnectionStatus(state: $state, clientId: $clientId, error: $error, attempts: $reconnectAttempts)';
  }
}

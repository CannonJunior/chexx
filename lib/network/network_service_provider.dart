import 'package:flutter/foundation.dart';
import 'websocket_manager.dart';
import 'game_network_service.dart';

/// Singleton provider for network services
class NetworkServiceProvider {
  static NetworkServiceProvider? _instance;

  late final WebSocketManager wsManager;
  late final GameNetworkService gameService;

  NetworkServiceProvider._({
    required String serverUrl,
  }) {
    wsManager = WebSocketManager(
      serverUrl: serverUrl,
      heartbeatInterval: const Duration(seconds: 30),
      reconnectDelay: const Duration(seconds: 3),
      maxReconnectAttempts: 5,
    );

    gameService = GameNetworkService(wsManager);
  }

  /// Initialize the network services (call once at app startup)
  static void initialize({String? serverUrl}) {
    if (_instance != null) {
      debugPrint('NetworkServiceProvider already initialized');
      return;
    }

    // Determine server URL based on platform
    final url = serverUrl ?? _getDefaultServerUrl();

    _instance = NetworkServiceProvider._(serverUrl: url);
    debugPrint('NetworkServiceProvider initialized with URL: $url');
  }

  /// Get the singleton instance
  static NetworkServiceProvider get instance {
    if (_instance == null) {
      throw StateError(
        'NetworkServiceProvider not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }

  /// Get default server URL based on platform
  static String _getDefaultServerUrl() {
    // For development, use localhost
    // Platform-specific URLs:
    // - Web: ws://localhost:8888/ws
    // - Android emulator: ws://10.0.2.2:8888/ws
    // - iOS simulator: ws://localhost:8888/ws
    // - Physical device: ws://<your-ip>:8888/ws

    if (kIsWeb) {
      return 'ws://localhost:8888/ws';
    }

    // For mobile platforms, detect if running on emulator
    // In production, this would come from configuration
    return 'ws://localhost:8888/ws';
  }

  /// Set a custom server URL (useful for switching between dev/prod)
  static void setServerUrl(String url) {
    if (_instance != null) {
      debugPrint('Creating new NetworkServiceProvider with URL: $url');
      _instance?.dispose();
      _instance = NetworkServiceProvider._(serverUrl: url);
    } else {
      initialize(serverUrl: url);
    }
  }

  /// Clean up resources
  void dispose() {
    gameService.dispose();
    _instance = null;
  }
}

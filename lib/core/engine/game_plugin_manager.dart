import 'package:flutter/material.dart';
import '../interfaces/game_plugin.dart';

/// Manages game plugins and provides access to available games
class GamePluginManager {
  static final GamePluginManager _instance = GamePluginManager._internal();
  factory GamePluginManager() => _instance;
  GamePluginManager._internal();

  final Map<String, GamePlugin> _plugins = {};
  GamePlugin? _activePlugin;

  /// Register a game plugin
  void registerPlugin(GamePlugin plugin) {
    _plugins[plugin.gameId] = plugin;
  }

  /// Get all registered plugins
  List<GamePlugin> get availablePlugins => _plugins.values.toList();

  /// Get plugin by ID
  GamePlugin? getPlugin(String gameId) => _plugins[gameId];

  /// Set active plugin
  Future<void> setActivePlugin(String gameId) async {
    final plugin = _plugins[gameId];
    if (plugin != null) {
      _activePlugin = plugin;
      await plugin.initialize();
    }
  }

  /// Get current active plugin
  GamePlugin? get activePlugin => _activePlugin;

  /// Check if a plugin is registered
  bool hasPlugin(String gameId) => _plugins.containsKey(gameId);

  /// Unregister a plugin
  void unregisterPlugin(String gameId) {
    final plugin = _plugins[gameId];
    if (plugin != null) {
      plugin.dispose();
      _plugins.remove(gameId);
      if (_activePlugin == plugin) {
        _activePlugin = null;
      }
    }
  }

  /// Dispose all plugins
  void disposeAll() {
    for (final plugin in _plugins.values) {
      plugin.dispose();
    }
    _plugins.clear();
    _activePlugin = null;
  }

  /// Create game screen for active plugin
  Widget? createGameScreen({Map<String, dynamic>? scenarioConfig}) {
    return _activePlugin?.createGameScreen(scenarioConfig: scenarioConfig);
  }

  /// Get plugin display names for UI
  Map<String, String> get pluginDisplayNames {
    return _plugins.map((key, value) => MapEntry(key, value.displayName));
  }
}
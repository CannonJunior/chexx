import 'package:flutter/material.dart';
import 'package:oxygen/oxygen.dart';
import '../models/game_config.dart';
import '../models/game_state_base.dart';
import 'unit_factory.dart';
import 'rules_engine.dart';
import 'ability_system.dart';

/// Main interface for game plugins that define specific game implementations
abstract class GamePlugin {
  /// Unique identifier for this game
  String get gameId;

  /// Display name for the game
  String get displayName;

  /// Game configuration and rules
  GameConfig get config;

  /// Factory for creating game units
  UnitFactory get unitFactory;

  /// Rules engine for game logic
  RulesEngine get rulesEngine;

  /// Ability system for special actions
  AbilitySystem get abilitySystem;

  /// Create a new game state instance
  GameStateBase createGameState();

  /// Create the main game screen widget
  Widget createGameScreen({Map<String, dynamic>? scenarioConfig});

  /// Register ECS components and systems
  void registerECSComponents(World world);

  /// Initialize the plugin (called once during app startup)
  Future<void> initialize();

  /// Clean up resources
  void dispose();
}
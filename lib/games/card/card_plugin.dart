import 'package:flutter/material.dart';
import 'package:oxygen/oxygen.dart';
import 'package:f_card_engine/f_card_engine.dart';
import '../../core/interfaces/game_plugin.dart';
import '../../core/interfaces/unit_factory.dart';
import '../../core/interfaces/rules_engine.dart';
import '../../core/interfaces/ability_system.dart';
import '../../core/models/game_config.dart' as chexx_config;
import '../../core/models/game_state_base.dart';
import 'card_game_screen.dart';
import 'card_game_state_adapter.dart';
import 'card_unit_factory.dart';
import 'card_rules_engine.dart';
import 'card_ability_system.dart';

/// Card game plugin implementation using f-card engine
class CardPlugin implements GamePlugin {
  CardUnitFactory? _unitFactory;
  CardRulesEngine? _rulesEngine;
  CardAbilitySystem? _abilitySystem;
  chexx_config.GameConfig? _config;

  // F-Card engine components
  late GameStateManager _gameStateManager;
  late DeckManager _deckManager;

  @override
  String get gameId => 'card';

  @override
  String get displayName => 'Card Game';

  @override
  chexx_config.GameConfig get config {
    _config ??= _createCardGameConfig();
    return _config!;
  }

  @override
  UnitFactory get unitFactory {
    _unitFactory ??= CardUnitFactory();
    return _unitFactory!;
  }

  @override
  RulesEngine get rulesEngine {
    _rulesEngine ??= CardRulesEngine(_gameStateManager);
    return _rulesEngine!;
  }

  @override
  AbilitySystem get abilitySystem {
    _abilitySystem ??= CardAbilitySystem(_gameStateManager);
    return _abilitySystem!;
  }

  /// Access to f-card engine's game state manager
  GameStateManager get cardGameStateManager => _gameStateManager;

  /// Access to f-card engine's deck manager
  DeckManager get deckManager => _deckManager;

  @override
  Future<void> initialize() async {
    // Initialize f-card engine components
    _deckManager = DeckManager();

    final fCardConfig = GameConfig(
      numberOfPlayers: 2,
      initialHandSize: 5,
      requireCardPlayedPerTurn: true,
      drawCardOnTurnEnd: true,
      cardsDrawnOnTurnEnd: 1,
    );

    _gameStateManager = GameStateManager(
      deckManager: _deckManager,
      config: fCardConfig,
    );

    // Load cards from assets
    await _deckManager.loadCards();

    // Initialize the game with players
    await _gameStateManager.initializeGame();

    // Initialize other components
    config;
    unitFactory;
    rulesEngine;
    abilitySystem;
  }

  @override
  GameStateBase createGameState() {
    return CardGameStateAdapter(_gameStateManager);
  }

  @override
  Widget createGameScreen({Map<String, dynamic>? scenarioConfig}) {
    return CardGameScreen(
      gamePlugin: this,
      scenarioConfig: scenarioConfig,
    );
  }

  @override
  void registerECSComponents(World world) {
    // Card game uses f-card engine, so no custom ECS components needed
  }

  @override
  void dispose() {
    // Dispose resources
  }

  /// Create card game configuration
  chexx_config.GameConfig _createCardGameConfig() {
    return chexx_config.GameConfig(
      unitTypes: {}, // Card game doesn't use traditional units
      abilities: {}, // Abilities are card-based
      boardConfig: chexx_config.BoardConfig(
        width: 0,
        height: 0,
        terrainTypes: [],
        terrainConfigs: {},
      ),
      victoryConditions: chexx_config.VictoryConditions(
        type: 'deck_depletion',
        parameters: {},
      ),
      rules: chexx_config.GameplayRules(
        maxPlayers: 2,
        turnTimeLimit: 0, // No time limit for card games
        allowUndoMoves: false,
        customRules: {
          'card_based': true,
        },
      ),
    );
  }
}

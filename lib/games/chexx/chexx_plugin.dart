import 'package:flutter/material.dart';
import 'package:oxygen/oxygen.dart';
import '../../core/interfaces/game_plugin.dart';
import '../../core/interfaces/unit_factory.dart';
import '../../core/interfaces/rules_engine.dart';
import '../../core/interfaces/ability_system.dart';
import '../../core/models/game_config.dart';
import '../../core/models/game_state_base.dart';
import 'models/chexx_game_state.dart';
import 'units/chexx_unit_factory.dart';
import 'systems/chexx_rules_engine.dart';
import 'systems/chexx_ability_system.dart';
import 'screens/chexx_game_screen.dart';
import 'components/chexx_components.dart';

/// CHEXX game plugin implementation
class ChexxPlugin implements GamePlugin {
  ChexxUnitFactory? _unitFactory;
  ChexxRulesEngine? _rulesEngine;
  ChexxAbilitySystem? _abilitySystem;
  GameConfig? _config;

  @override
  String get gameId => 'chexx';

  @override
  String get displayName => 'CHEXX - Hexagonal Strategy';

  @override
  GameConfig get config {
    _config ??= _createChexxConfig();
    return _config!;
  }

  @override
  UnitFactory get unitFactory {
    _unitFactory ??= ChexxUnitFactory();
    return _unitFactory!;
  }

  @override
  RulesEngine get rulesEngine {
    _rulesEngine ??= ChexxRulesEngine();
    return _rulesEngine!;
  }

  @override
  AbilitySystem get abilitySystem {
    _abilitySystem ??= ChexxAbilitySystem();
    return _abilitySystem!;
  }

  @override
  Future<void> initialize() async {
    // Initialize CHEXX-specific configuration (lazy initialization via getters)
    // Force initialization of all components
    config;
    unitFactory;
    rulesEngine;
    abilitySystem;
  }

  @override
  GameStateBase createGameState() {
    return ChexxGameState();
  }

  @override
  Widget createGameScreen({Map<String, dynamic>? scenarioConfig}) {
    return ChexxGameScreen(scenarioConfig: scenarioConfig, gamePlugin: this);
  }

  @override
  void registerECSComponents(World world) {
    // Register CHEXX-specific components
    // TODO: Fix component registration for Oxygen 0.3.1
    // world.registerComponent<LevelComponent>(() => LevelComponent());
    // world.registerComponent<ExperienceComponent>(() => ExperienceComponent());
    // world.registerComponent<MetaAbilityComponent>(() => MetaAbilityComponent());
  }

  @override
  void dispose() {
    // Clean up CHEXX-specific resources
  }

  /// Create CHEXX game configuration
  GameConfig _createChexxConfig() {
    return GameConfig(
      unitTypes: {
        'minor': UnitTypeConfig(
          name: 'minor',
          displayName: 'Minor Unit',
          maxHealth: 1,
          attackDamage: 1,
          attackRange: 1,
          movementRange: 1,
          abilities: [],
          movementType: MovementType.adjacent,
        ),
        'scout': UnitTypeConfig(
          name: 'scout',
          displayName: 'Scout',
          maxHealth: 2,
          attackDamage: 1,
          attackRange: 3,
          movementRange: 3,
          abilities: ['long_range_scan'],
          movementType: MovementType.straight,
        ),
        'knight': UnitTypeConfig(
          name: 'knight',
          displayName: 'Knight',
          maxHealth: 3,
          attackDamage: 2,
          attackRange: 2,
          movementRange: 2,
          abilities: [],
          movementType: MovementType.knight,
        ),
        'guardian': UnitTypeConfig(
          name: 'guardian',
          displayName: 'Guardian',
          maxHealth: 3,
          attackDamage: 1,
          attackRange: 1,
          movementRange: 1,
          abilities: ['swap'],
          movementType: MovementType.adjacent,
        ),
      },
      abilities: {
        'spawn': AbilityConfig(
          name: 'spawn',
          displayName: 'Spawn Unit',
          description: 'Create a new minor unit',
          cooldown: 3,
          range: 2,
          targetType: 'empty_hex',
          effects: {'spawn_unit': 'minor'},
        ),
        'heal': AbilityConfig(
          name: 'heal',
          displayName: 'Heal',
          description: 'Restore health to friendly unit',
          cooldown: 2,
          range: 2,
          targetType: 'friendly_unit',
          effects: {'heal_amount': 2},
        ),
        'shield': AbilityConfig(
          name: 'shield',
          displayName: 'Shield',
          description: 'Provide damage reduction',
          cooldown: 4,
          range: 0,
          targetType: 'area',
          effects: {'damage_reduction': 1, 'duration': 3},
        ),
        'long_range_scan': AbilityConfig(
          name: 'long_range_scan',
          displayName: 'Long Range Scan',
          description: 'Reveal enemy positions',
          cooldown: 4,
          range: 4,
          targetType: 'area',
          effects: {'reveal_duration': 2},
        ),
        'swap': AbilityConfig(
          name: 'swap',
          displayName: 'Swap Position',
          description: 'Exchange positions with friendly unit',
          cooldown: 3,
          range: 1,
          targetType: 'friendly_unit',
          effects: {'swap_positions': true},
        ),
      },
      boardConfig: BoardConfig(
        width: 19,
        height: 15,
        terrainTypes: ['normal', 'meta'],
        terrainConfigs: {
          'normal': TerrainConfig(
            name: 'normal',
            displayName: 'Normal',
            movementCost: 1,
            blocksMovement: false,
            blocksLineOfSight: false,
          ),
          'meta': TerrainConfig(
            name: 'meta',
            displayName: 'Meta Hexagon',
            movementCost: 1,
            blocksMovement: false,
            blocksLineOfSight: false,
            properties: {'provides_abilities': true},
          ),
        },
      ),
      victoryConditions: VictoryConditions(
        type: 'eliminate_all',
        parameters: {},
      ),
      rules: GameplayRules(
        maxPlayers: 2,
        turnTimeLimit: 6.0,
        allowUndoMoves: false,
        customRules: {
          'reward_system': true,
          'meta_hexes': true,
        },
      ),
    );
  }
}
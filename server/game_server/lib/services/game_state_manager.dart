import 'dart:convert';
import 'dart:io';
import 'package:chexx_shared_models/chexx_shared_models.dart';
import '../models/server_game_state.dart';

/// Manages game state for all active games
class GameStateManager {
  /// Active game states by game ID
  final Map<String, ServerGameState> _gameStates = {};

  /// Create a new game state from scenario
  Future<ServerGameState> createGame({
    required String gameId,
    required String scenarioId,
    required List<PlayerInfo> players,
  }) async {
    if (_gameStates.containsKey(gameId)) {
      throw StateError('Game already exists: $gameId');
    }

    // Load scenario configuration
    final scenarioConfig = await _loadScenario(scenarioId);

    // Create game state
    final gameState = ServerGameState(
      gameId: gameId,
      scenarioId: scenarioId,
      players: players,
      scenarioConfig: scenarioConfig,
    );

    // Initialize from scenario
    gameState.initializeFromScenario();

    _gameStates[gameId] = gameState;
    print('Created game: $gameId with scenario: $scenarioId');

    return gameState;
  }

  /// Get game state by ID
  ServerGameState? getGameState(String gameId) {
    return _gameStates[gameId];
  }

  /// Process a game action
  GameActionResult processAction(String gameId, GameAction action) {
    final gameState = _gameStates[gameId];
    if (gameState == null) {
      return GameActionResult(
        success: false,
        error: 'Game not found: $gameId',
      );
    }

    // Validate action
    final validation = _validateAction(gameState, action);
    if (!validation.isValid) {
      return GameActionResult(
        success: false,
        error: validation.error,
      );
    }

    // Process action based on type
    try {
      switch (action.actionType) {
        case GameActionType.selectUnit:
          return _processSelectUnit(gameState, action);
        case GameActionType.move:
          return _processMove(gameState, action);
        case GameActionType.attack:
          return _processAttack(gameState, action);
        case GameActionType.endTurn:
          return _processEndTurn(gameState, action);
        default:
          return GameActionResult(
            success: false,
            error: 'Unknown action type: ${action.actionType}',
          );
      }
    } catch (e) {
      print('Error processing action: $e');
      return GameActionResult(
        success: false,
        error: 'Failed to process action: $e',
      );
    }
  }

  /// Get current game state snapshot
  GameStateSnapshot getStateSnapshot(String gameId) {
    final gameState = _gameStates[gameId];
    if (gameState == null) {
      throw StateError('Game not found: $gameId');
    }

    return gameState.toSnapshot();
  }

  /// Remove a game
  void removeGame(String gameId) {
    _gameStates.remove(gameId);
    print('Removed game: $gameId');
  }

  /// Load scenario configuration from file
  Future<Map<String, dynamic>> _loadScenario(String scenarioId) async {
    // Try to load from client's scenario directory first
    final clientScenarioPath = '/home/junior/src/chexx/lib/configs/scenarios/$scenarioId.json';
    final clientFile = File(clientScenarioPath);

    if (await clientFile.exists()) {
      print('Loading scenario from client: $clientScenarioPath');
      final content = await clientFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    }

    // Fallback: Try server scenarios directory
    final serverScenarioPath = 'scenarios/$scenarioId.json';
    final serverFile = File(serverScenarioPath);

    if (await serverFile.exists()) {
      print('Loading scenario from server: $serverScenarioPath');
      final content = await serverFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    }

    // If no scenario file found, return default scenario
    print('Scenario not found: $scenarioId, using default');
    return _getDefaultScenario();
  }

  /// Get default scenario if file not found
  Map<String, dynamic> _getDefaultScenario() {
    return {
      'name': 'Default Scenario',
      'game_type': 'chexx',
      'board': {
        'width': 7,
        'height': 5,
        'layout': 'hexagonal',
      },
      'unit_placements': [
        {
          'template': {'id': 'p1_unit1', 'type': 'minor', 'owner': 'player1'},
          'position': {'q': -2, 'r': 2, 's': 0},
        },
        {
          'template': {'id': 'p1_unit2', 'type': 'minor', 'owner': 'player1'},
          'position': {'q': -1, 'r': 2, 's': -1},
        },
        {
          'template': {'id': 'p2_unit1', 'type': 'minor', 'owner': 'player2'},
          'position': {'q': 1, 'r': -2, 's': 1},
        },
        {
          'template': {'id': 'p2_unit2', 'type': 'minor', 'owner': 'player2'},
          'position': {'q': 2, 'r': -2, 's': 0},
        },
      ],
    };
  }

  /// Validate an action
  ActionValidation _validateAction(ServerGameState gameState, GameAction action) {
    // Check if it's the correct player's turn
    if (action.playerId != gameState.currentPlayer) {
      return ActionValidation(
        isValid: false,
        error: 'Not your turn (current player: ${gameState.currentPlayer})',
      );
    }

    // Check game phase
    if (gameState.gameStatus != 'playing') {
      return ActionValidation(
        isValid: false,
        error: 'Game is not in playing state: ${gameState.gameStatus}',
      );
    }

    // Action-specific validation
    switch (action.actionType) {
      case GameActionType.move:
        return _validateMove(gameState, action);
      case GameActionType.attack:
        return _validateAttack(gameState, action);
      default:
        return ActionValidation(isValid: true);
    }
  }

  /// Validate move action
  ActionValidation _validateMove(ServerGameState gameState, GameAction action) {
    if (action.unitId == null || action.toPosition == null) {
      return ActionValidation(
        isValid: false,
        error: 'Move action requires unitId and toPosition',
      );
    }

    // Find the unit
    final unit = gameState.units.firstWhere(
      (u) => u.unitId == action.unitId,
      orElse: () => throw StateError('Unit not found: ${action.unitId}'),
    );

    // Check if unit belongs to current player
    if (unit.owner != action.playerId) {
      return ActionValidation(
        isValid: false,
        error: 'Cannot move opponent\'s unit',
      );
    }

    // Check if unit has already moved
    if (unit.hasMoved) {
      return ActionValidation(
        isValid: false,
        error: 'Unit has already moved this turn',
      );
    }

    // Check if target position is valid (basic check - can be enhanced)
    final distance = _calculateDistance(unit.position, action.toPosition!);
    if (distance > 3) { // Max movement range for now
      return ActionValidation(
        isValid: false,
        error: 'Target position is too far',
      );
    }

    return ActionValidation(isValid: true);
  }

  /// Validate attack action
  ActionValidation _validateAttack(ServerGameState gameState, GameAction action) {
    if (action.unitId == null || action.toPosition == null) {
      return ActionValidation(
        isValid: false,
        error: 'Attack action requires unitId and toPosition',
      );
    }

    // Find the attacking unit
    final attacker = gameState.units.firstWhere(
      (u) => u.unitId == action.unitId,
      orElse: () => throw StateError('Unit not found: ${action.unitId}'),
    );

    // Check if unit belongs to current player
    if (attacker.owner != action.playerId) {
      return ActionValidation(
        isValid: false,
        error: 'Cannot attack with opponent\'s unit',
      );
    }

    // Check if unit has already attacked
    if (attacker.hasAttacked) {
      return ActionValidation(
        isValid: false,
        error: 'Unit has already attacked this turn',
      );
    }

    // Find target unit at position
    final targetUnit = gameState.units.firstWhere(
      (u) => u.position.q == action.toPosition!.q &&
             u.position.r == action.toPosition!.r &&
             u.position.s == action.toPosition!.s,
      orElse: () => throw StateError('No unit at target position'),
    );

    // Check if target is enemy
    if (targetUnit.owner == action.playerId) {
      return ActionValidation(
        isValid: false,
        error: 'Cannot attack your own unit',
      );
    }

    // Check attack range (basic check - can be enhanced based on unit type)
    final distance = _calculateDistance(attacker.position, targetUnit.position);
    if (distance > 3) { // Max attack range for now
      return ActionValidation(
        isValid: false,
        error: 'Target is out of attack range',
      );
    }

    return ActionValidation(isValid: true);
  }

  /// Process select unit action
  GameActionResult _processSelectUnit(ServerGameState gameState, GameAction action) {
    if (action.unitId == null) {
      return GameActionResult(
        success: false,
        error: 'Select action requires unitId',
      );
    }

    gameState.selectedUnitId = action.unitId;

    return GameActionResult(
      success: true,
      stateChanged: true,
    );
  }

  /// Process move action
  GameActionResult _processMove(ServerGameState gameState, GameAction action) {
    final unitIndex = gameState.units.indexWhere((u) => u.unitId == action.unitId);
    if (unitIndex == -1) {
      return GameActionResult(
        success: false,
        error: 'Unit not found',
      );
    }

    // Update unit position and mark as moved
    final unit = gameState.units[unitIndex];
    gameState.units[unitIndex] = unit.copyWith(
      position: action.toPosition!,
      hasMoved: true,
    );

    print('Unit ${unit.unitId} moved from ${unit.position} to ${action.toPosition}');

    return GameActionResult(
      success: true,
      stateChanged: true,
    );
  }

  /// Process attack action
  GameActionResult _processAttack(ServerGameState gameState, GameAction action) {
    final attackerIndex = gameState.units.indexWhere((u) => u.unitId == action.unitId);
    if (attackerIndex == -1) {
      return GameActionResult(
        success: false,
        error: 'Attacker not found',
      );
    }

    // Find target unit
    final targetIndex = gameState.units.indexWhere((u) =>
      u.position.q == action.toPosition!.q &&
      u.position.r == action.toPosition!.r &&
      u.position.s == action.toPosition!.s
    );

    if (targetIndex == -1) {
      return GameActionResult(
        success: false,
        error: 'No target at position',
      );
    }

    // Calculate damage (simple: 1 damage for now)
    final attacker = gameState.units[attackerIndex];
    final target = gameState.units[targetIndex];
    final damage = 1;
    final newHealth = (target.health - damage).clamp(0, target.maxHealth);

    // Update attacker (mark as attacked)
    gameState.units[attackerIndex] = attacker.copyWith(hasAttacked: true);

    // Update or remove target
    if (newHealth <= 0) {
      // Unit destroyed
      gameState.units.removeAt(targetIndex);
      print('Unit ${target.unitId} destroyed by ${attacker.unitId}');

      // Award points to attacker's player
      if (attacker.owner == 1) {
        gameState.player1Points++;
      } else {
        gameState.player2Points++;
      }
    } else {
      // Unit damaged
      gameState.units[targetIndex] = target.copyWith(health: newHealth);
      print('Unit ${target.unitId} took $damage damage (${newHealth}/${target.maxHealth} HP remaining)');
    }

    // Check victory conditions
    gameState.checkVictory();

    return GameActionResult(
      success: true,
      stateChanged: true,
    );
  }

  /// Process end turn action
  GameActionResult _processEndTurn(ServerGameState gameState, GameAction action) {
    // Switch to next player
    gameState.currentPlayer = gameState.currentPlayer == 1 ? 2 : 1;

    if (gameState.currentPlayer == 1) {
      gameState.turnNumber++;
    }

    // Reset unit actions for new player
    for (int i = 0; i < gameState.units.length; i++) {
      final unit = gameState.units[i];
      if (unit.owner == gameState.currentPlayer) {
        gameState.units[i] = unit.copyWith(
          hasMoved: false,
          hasAttacked: false,
        );
      }
    }

    print('Turn ended. Now Player ${gameState.currentPlayer}\'s turn (Turn ${gameState.turnNumber})');

    return GameActionResult(
      success: true,
      stateChanged: true,
    );
  }

  /// Calculate distance between two coordinates
  int _calculateDistance(HexCoordinateData a, HexCoordinateData b) {
    return ((a.q - b.q).abs() + (a.r - b.r).abs() + (a.s - b.s).abs()) ~/ 2;
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'activeGames': _gameStates.length,
      'games': _gameStates.keys.toList(),
    };
  }
}

/// Result of action validation
class ActionValidation {
  final bool isValid;
  final String? error;

  ActionValidation({required this.isValid, this.error});
}

/// Result of processing an action
class GameActionResult {
  final bool success;
  final bool stateChanged;
  final String? error;
  final Map<String, dynamic>? additionalData;

  GameActionResult({
    required this.success,
    this.stateChanged = false,
    this.error,
    this.additionalData,
  });
}

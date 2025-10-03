import 'package:f_card_engine/f_card_engine.dart';
import 'package:oxygen/oxygen.dart';
import '../../core/interfaces/rules_engine.dart';
import '../../core/interfaces/unit_factory.dart' as chexx;
import '../../core/models/hex_coordinate.dart';

/// Rules engine that delegates to f-card engine's game state manager
class CardRulesEngine implements RulesEngine {
  final GameStateManager _gameStateManager;

  CardRulesEngine(this._gameStateManager);

  // All hex-based methods are stubs since card games don't use hex grids

  @override
  bool canUnitMoveTo({
    required Entity unit,
    required HexCoordinate target,
    required World world,
  }) {
    return false; // Card games don't have movement
  }

  @override
  bool canUnitAttack({
    required Entity unit,
    required HexCoordinate target,
    required World world,
  }) {
    return false; // Card games use different attack mechanics
  }

  @override
  List<HexCoordinate> getValidMoves({
    required Entity unit,
    required World world,
  }) {
    return []; // Card games don't have movement
  }

  @override
  List<HexCoordinate> getValidAttacks({
    required Entity unit,
    required World world,
  }) {
    return []; // Card games don't use hex coordinates for attacks
  }

  @override
  chexx.Player? checkVictoryCondition(World world) {
    // Simple victory condition: last player with cards wins
    if (_gameStateManager.deckManager.cardsRemaining == 0) {
      // Find player with most cards (simplified)
      if (_gameStateManager.players.isNotEmpty) {
        final playersWithCards = _gameStateManager.players
            .where((p) => p.hand.isNotEmpty)
            .toList();
        if (playersWithCards.length == 1) {
          // Could map to Player.player1 or Player.player2
          return chexx.Player.player1;
        }
      }
    }
    return null;
  }

  @override
  bool isActionValid({
    required String action,
    required Map<String, dynamic> params,
    required World world,
  }) {
    // Card-specific validation would go here
    return true;
  }

  @override
  int getMovementCost({
    required Entity unit,
    required HexCoordinate target,
    required World world,
  }) {
    return 0; // No movement in card games
  }

  @override
  int calculateDamage({
    required Entity attacker,
    required Entity target,
    required World world,
  }) {
    return 0; // Card games handle damage differently
  }
}

import 'package:flutter/foundation.dart';
import 'package:oxygen/oxygen.dart';
import '../interfaces/unit_factory.dart';
import 'hex_coordinate.dart';

/// Game phases
enum GamePhase { menu, playing, paused, gameOver }

/// Turn phases for turn-based games
enum TurnPhase { moving, acting, waiting }

/// Base class for game state management
abstract class GameStateBase extends ChangeNotifier {
  /// ECS World for managing entities and components
  late final World world;

  /// Current game phase
  GamePhase gamePhase = GamePhase.menu;

  /// Current player whose turn it is
  Player currentPlayer = Player.player1;

  /// Current turn number
  int turnNumber = 1;

  /// Turn phase for turn-based games
  TurnPhase turnPhase = TurnPhase.moving;

  /// Time remaining in current turn (seconds)
  double turnTimeRemaining = 6.0;

  /// Whether the game is paused
  bool isPaused = false;

  /// Winner of the game (null if game not over)
  Player? winner;

  /// Currently selected entity
  Entity? selectedEntity;

  /// Available move positions for selected entity
  Set<HexCoordinate> availableMoves = {};

  /// Available attack positions for selected entity
  Set<HexCoordinate> availableAttacks = {};

  /// Remaining moves for current turn
  int remainingMoves = 0;

  GameStateBase() {
    world = World();
  }

  /// Initialize the game state
  void initializeGame();

  /// Initialize from scenario configuration
  void initializeFromScenario(Map<String, dynamic> scenarioConfig);

  /// Reset the game to initial state
  void resetGame();

  /// End the current turn
  void endTurn();

  /// Skip the current action
  void skipAction();

  /// Toggle pause state
  void togglePause();

  /// Update game timer
  void updateTimer(double deltaTime);

  /// Select an entity
  void selectEntity(Entity entity);

  /// Deselect current entity
  void deselectEntity();

  /// Move selected entity to target position
  bool moveEntity(HexCoordinate target);

  /// Attack target position with selected entity
  bool attackPosition(HexCoordinate target);

  /// Handle keyboard movement input
  bool handleKeyboardMovement(String key);

  /// Check victory conditions
  void checkVictoryConditions();

  /// Get entity at specific coordinate
  Entity? getEntityAt(HexCoordinate coordinate);

  /// Get all entities belonging to a player
  List<Entity> getPlayerEntities(Player player);

  /// Get all entities at a specific position
  List<Entity> getEntitiesAt(HexCoordinate position);

  @override
  void dispose() {
    // Note: World doesn't have dispose method in Oxygen 0.3.1
    super.dispose();
  }
}
import 'package:f_card_engine/f_card_engine.dart';
import 'package:oxygen/oxygen.dart';
import '../../core/models/game_state_base.dart';
import '../../core/models/hex_coordinate.dart';
import '../../core/interfaces/unit_factory.dart' as chexx;

/// Adapter to bridge f-card engine's GameStateManager with chexx's GameStateBase
class CardGameStateAdapter extends GameStateBase {
  final GameStateManager _cardGameState;

  CardGameStateAdapter(this._cardGameState);

  /// Access to the underlying f-card engine game state
  GameStateManager get cardGameState => _cardGameState;

  /// Get all game events from the event log
  List<Map<String, dynamic>> get eventLog => _cardGameState.eventLog;

  /// Get current player from f-card engine
  Player? get cardCurrentPlayer => _cardGameState.currentPlayer;

  /// Get all players
  List<Player> get players => _cardGameState.players;

  /// Check if game is started
  bool get gameStarted => _cardGameState.gameStarted;

  /// Check if game is over (deck depleted or other conditions)
  @override
  bool get isGameOver => _cardGameState.deckManager.cardsRemaining == 0;

  /// Play a card from hand
  void playCard(CardInstance card, {CardZone destination = CardZone.discard}) {
    _cardGameState.playCard(card, destination: destination);
  }

  /// End current turn
  @override
  void endTurn() {
    _cardGameState.endTurn();
    notifyListeners();
  }

  /// Move card from play to another zone
  void moveCardFromPlay(CardInstance card, CardZone destination) {
    _cardGameState.moveCardFromPlay(card, destination);
  }

  /// Start the game
  void startGame({int? initialHandSize}) {
    _cardGameState.startGame(initialHandSize: initialHandSize);
    gamePhase = GamePhase.playing;
    notifyListeners();
  }

  /// Reset the game state
  @override
  void resetGame() {
    _cardGameState.resetGame();
    gamePhase = GamePhase.menu;
    notifyListeners();
  }

  // Stub implementations for hex-based game methods (not used in card game)

  @override
  void initializeGame() {
    // Card game initialization is handled through CardPlugin.initialize()
  }

  @override
  void initializeFromScenario(Map<String, dynamic> scenarioConfig) {
    // Not applicable for card games
  }

  @override
  void skipAction() {
    // In card games, this would be "end turn"
    endTurn();
  }

  @override
  void togglePause() {
    isPaused = !isPaused;
    notifyListeners();
  }

  @override
  void updateTimer(double deltaTime) {
    // Card games don't use timed turns
  }

  @override
  void selectEntity(Entity entity) {
    // Not applicable - card games don't use hex entities
  }

  @override
  void deselectEntity() {
    selectedEntity = null;
    notifyListeners();
  }

  @override
  bool moveEntity(HexCoordinate target) {
    // Not applicable for card games
    return false;
  }

  @override
  bool attackPosition(HexCoordinate target) {
    // Not applicable for card games
    return false;
  }

  @override
  bool handleKeyboardMovement(String key) {
    // Not applicable for card games
    return false;
  }

  @override
  void checkVictoryConditions() {
    if (isGameOver) {
      gamePhase = GamePhase.gameOver;
      // In the simple f-card engine, the last player with cards could be considered winner
      // This would need more sophisticated logic for a real card game
      notifyListeners();
    }
  }

  @override
  Entity? getEntityAt(HexCoordinate coordinate) {
    // Not applicable for card games
    return null;
  }

  @override
  List<Entity> getPlayerEntities(chexx.Player player) {
    // Not applicable for card games
    return [];
  }

  @override
  List<Entity> getEntitiesAt(HexCoordinate position) {
    // Not applicable for card games
    return [];
  }
}

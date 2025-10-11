/// Network message types for client-server communication
class MessageType {
  // Connection messages
  static const String connected = 'CONNECTED';
  static const String disconnected = 'DISCONNECTED';
  static const String ping = 'PING';
  static const String pong = 'PONG';
  static const String error = 'ERROR';

  // Lobby messages
  static const String createGame = 'CREATE_GAME';
  static const String gameCreated = 'GAME_CREATED';
  static const String joinGame = 'JOIN_GAME';
  static const String gameJoined = 'GAME_JOINED';
  static const String leaveGame = 'LEAVE_GAME';
  static const String gameLeft = 'GAME_LEFT';
  static const String listGames = 'LIST_GAMES';
  static const String gamesListed = 'GAMES_LISTED';
  static const String playerJoined = 'PLAYER_JOINED';
  static const String playerLeft = 'PLAYER_LEFT';

  // Game lifecycle messages
  static const String startGame = 'START_GAME';
  static const String gameStarted = 'GAME_STARTED';
  static const String gameEnded = 'GAME_ENDED';
  static const String gameAborted = 'GAME_ABORTED';

  // Game action messages
  static const String gameAction = 'GAME_ACTION';
  static const String actionResult = 'ACTION_RESULT';
  static const String endTurn = 'END_TURN';
  static const String turnEnded = 'TURN_ENDED';

  // State synchronization messages
  static const String stateSync = 'STATE_SYNC';
  static const String stateUpdate = 'STATE_UPDATE';
  static const String fullState = 'FULL_STATE';

  // Chat messages (future)
  static const String chatMessage = 'CHAT_MESSAGE';
  static const String chatReceived = 'CHAT_RECEIVED';

  // Validation helper
  static bool isValid(String type) {
    return _allTypes.contains(type);
  }

  static final Set<String> _allTypes = {
    connected, disconnected, ping, pong, error,
    createGame, gameCreated, joinGame, gameJoined, leaveGame, gameLeft,
    listGames, gamesListed, playerJoined, playerLeft,
    startGame, gameStarted, gameEnded, gameAborted,
    gameAction, actionResult, endTurn, turnEnded,
    stateSync, stateUpdate, fullState,
    chatMessage, chatReceived,
  };
}

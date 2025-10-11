/// Shared models and network messages for Chexx multiplayer game
///
/// This package contains all data structures that are shared between
/// the client (Flutter app) and server (Dart backend).
library chexx_shared_models;

// Network Messages
export 'src/network/network_message.dart';
export 'src/network/message_types.dart';

// Game Models
export 'src/models/player_info.dart';
export 'src/models/game_action.dart';
export 'src/models/game_state_snapshot.dart';
export 'src/models/unit_data.dart';
export 'src/models/hex_coordinate_data.dart';

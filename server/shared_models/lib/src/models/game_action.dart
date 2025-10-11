import 'hex_coordinate_data.dart';

/// Types of actions a player can take
class GameActionType {
  static const String move = 'MOVE';
  static const String attack = 'ATTACK';
  static const String endTurn = 'END_TURN';
  static const String playCard = 'PLAY_CARD';
  static const String selectUnit = 'SELECT_UNIT';
  static const String useAbility = 'USE_ABILITY';
  static const String surrender = 'SURRENDER';

  static final Set<String> _allTypes = {
    move, attack, endTurn, playCard, selectUnit, useAbility, surrender,
  };

  static bool isValid(String type) => _allTypes.contains(type);
}

/// Represents a game action taken by a player
class GameAction {
  /// Action type
  final String actionType;

  /// Player who is performing the action
  final int playerId;

  /// Target unit ID (for move, attack, select)
  final String? unitId;

  /// Source position (for move actions)
  final HexCoordinateData? fromPosition;

  /// Target position (for move, attack actions)
  final HexCoordinateData? toPosition;

  /// Additional action data (for extensibility)
  final Map<String, dynamic>? actionData;

  /// Timestamp when action was created
  final int timestamp;

  GameAction({
    required this.actionType,
    required this.playerId,
    this.unitId,
    this.fromPosition,
    this.toPosition,
    this.actionData,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() {
    return {
      'actionType': actionType,
      'playerId': playerId,
      if (unitId != null) 'unitId': unitId,
      if (fromPosition != null) 'fromPosition': fromPosition!.toJson(),
      if (toPosition != null) 'toPosition': toPosition!.toJson(),
      if (actionData != null) 'actionData': actionData,
      'timestamp': timestamp,
    };
  }

  factory GameAction.fromJson(Map<String, dynamic> json) {
    return GameAction(
      actionType: json['actionType'] as String,
      playerId: json['playerId'] as int,
      unitId: json['unitId'] as String?,
      fromPosition: json['fromPosition'] != null
          ? HexCoordinateData.fromJson(json['fromPosition'] as Map<String, dynamic>)
          : null,
      toPosition: json['toPosition'] != null
          ? HexCoordinateData.fromJson(json['toPosition'] as Map<String, dynamic>)
          : null,
      actionData: json['actionData'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as int?,
    );
  }

  @override
  String toString() {
    return 'GameAction(type: $actionType, player: $playerId, unit: $unitId, from: $fromPosition, to: $toPosition)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameAction &&
        other.actionType == actionType &&
        other.playerId == playerId &&
        other.unitId == unitId &&
        other.fromPosition == fromPosition &&
        other.toPosition == toPosition &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      actionType, playerId, unitId,
      fromPosition, toPosition, timestamp,
    );
  }
}

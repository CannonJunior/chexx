/// Player information for multiplayer games
class PlayerInfo {
  /// Unique player ID (assigned by server)
  final String playerId;

  /// Player display name
  final String displayName;

  /// Player number in game (1 or 2)
  final int playerNumber;

  /// Whether this player is ready to start
  final bool isReady;

  /// Whether this player is currently connected
  final bool isConnected;

  PlayerInfo({
    required this.playerId,
    required this.displayName,
    required this.playerNumber,
    this.isReady = false,
    this.isConnected = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'displayName': displayName,
      'playerNumber': playerNumber,
      'isReady': isReady,
      'isConnected': isConnected,
    };
  }

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      playerId: json['playerId'] as String,
      displayName: json['displayName'] as String,
      playerNumber: json['playerNumber'] as int,
      isReady: json['isReady'] as bool? ?? false,
      isConnected: json['isConnected'] as bool? ?? true,
    );
  }

  /// Create a copy with updated fields
  PlayerInfo copyWith({
    String? playerId,
    String? displayName,
    int? playerNumber,
    bool? isReady,
    bool? isConnected,
  }) {
    return PlayerInfo(
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      playerNumber: playerNumber ?? this.playerNumber,
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  String toString() {
    return 'PlayerInfo(id: $playerId, name: $displayName, #$playerNumber, ready: $isReady, connected: $isConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerInfo &&
        other.playerId == playerId &&
        other.displayName == displayName &&
        other.playerNumber == playerNumber &&
        other.isReady == isReady &&
        other.isConnected == isConnected;
  }

  @override
  int get hashCode {
    return Object.hash(playerId, displayName, playerNumber, isReady, isConnected);
  }
}

import 'hex_coordinate_data.dart';

/// Serializable unit data for network transmission
class UnitData {
  /// Unique unit ID
  final String unitId;

  /// Unit type (e.g., 'infantry', 'armor', 'artillery')
  final String unitType;

  /// Owner player number (1 or 2)
  final int owner;

  /// Current position
  final HexCoordinateData position;

  /// Current health
  final int health;

  /// Maximum health
  final int maxHealth;

  /// Whether unit has moved this turn
  final bool hasMoved;

  /// Whether unit has attacked this turn
  final bool hasAttacked;

  /// Custom properties (for extensibility)
  final Map<String, dynamic>? customData;

  UnitData({
    required this.unitId,
    required this.unitType,
    required this.owner,
    required this.position,
    required this.health,
    required this.maxHealth,
    this.hasMoved = false,
    this.hasAttacked = false,
    this.customData,
  });

  Map<String, dynamic> toJson() {
    return {
      'unitId': unitId,
      'unitType': unitType,
      'owner': owner,
      'position': position.toJson(),
      'health': health,
      'maxHealth': maxHealth,
      'hasMoved': hasMoved,
      'hasAttacked': hasAttacked,
      if (customData != null) 'customData': customData,
    };
  }

  factory UnitData.fromJson(Map<String, dynamic> json) {
    return UnitData(
      unitId: json['unitId'] as String,
      unitType: json['unitType'] as String,
      owner: json['owner'] as int,
      position: HexCoordinateData.fromJson(json['position'] as Map<String, dynamic>),
      health: json['health'] as int,
      maxHealth: json['maxHealth'] as int,
      hasMoved: json['hasMoved'] as bool? ?? false,
      hasAttacked: json['hasAttacked'] as bool? ?? false,
      customData: json['customData'] as Map<String, dynamic>?,
    );
  }

  /// Create a copy with updated fields
  UnitData copyWith({
    String? unitId,
    String? unitType,
    int? owner,
    HexCoordinateData? position,
    int? health,
    int? maxHealth,
    bool? hasMoved,
    bool? hasAttacked,
    Map<String, dynamic>? customData,
  }) {
    return UnitData(
      unitId: unitId ?? this.unitId,
      unitType: unitType ?? this.unitType,
      owner: owner ?? this.owner,
      position: position ?? this.position,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      hasMoved: hasMoved ?? this.hasMoved,
      hasAttacked: hasAttacked ?? this.hasAttacked,
      customData: customData ?? this.customData,
    );
  }

  @override
  String toString() {
    return 'UnitData(id: $unitId, type: $unitType, owner: $owner, pos: $position, hp: $health/$maxHealth)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnitData &&
        other.unitId == unitId &&
        other.unitType == unitType &&
        other.owner == owner &&
        other.position == position &&
        other.health == health &&
        other.maxHealth == maxHealth &&
        other.hasMoved == hasMoved &&
        other.hasAttacked == hasAttacked;
  }

  @override
  int get hashCode {
    return Object.hash(
      unitId, unitType, owner, position,
      health, maxHealth, hasMoved, hasAttacked,
    );
  }
}

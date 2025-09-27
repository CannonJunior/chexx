import 'hex_coordinate.dart';
import 'game_unit.dart';
import '../../core/interfaces/unit_factory.dart';

/// Types of Meta abilities available
enum MetaAbilityType { spawn, heal, shield }

/// Meta ability definition with stats and effects
class MetaAbility {
  final MetaAbilityType type;
  final String description;
  final int range;
  final int cooldown;
  final int? healAmount;
  final int? duration;

  const MetaAbility({
    required this.type,
    required this.description,
    required this.range,
    required this.cooldown,
    this.healAmount,
    this.duration,
  });

  factory MetaAbility.fromJson(String type, Map<String, dynamic> json) {
    return MetaAbility(
      type: _parseType(type),
      description: json['description'] as String,
      range: json['range'] as int,
      cooldown: json['cooldown'] as int,
      healAmount: json['heal_amount'] as int?,
      duration: json['duration'] as int?,
    );
  }

  static MetaAbilityType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'spawn':
        return MetaAbilityType.spawn;
      case 'heal':
        return MetaAbilityType.heal;
      case 'shield':
        return MetaAbilityType.shield;
      default:
        throw ArgumentError('Unknown meta ability type: $type');
    }
  }
}

/// Active Meta ability effect on a unit
class ActiveMetaEffect {
  final MetaAbilityType type;
  final int remainingTurns;
  final Player affectedPlayer;

  const ActiveMetaEffect({
    required this.type,
    required this.remainingTurns,
    required this.affectedPlayer,
  });

  ActiveMetaEffect copyWith({
    MetaAbilityType? type,
    int? remainingTurns,
    Player? affectedPlayer,
  }) {
    return ActiveMetaEffect(
      type: type ?? this.type,
      remainingTurns: remainingTurns ?? this.remainingTurns,
      affectedPlayer: affectedPlayer ?? this.affectedPlayer,
    );
  }

  bool get isExpired => remainingTurns <= 0;
}

/// Meta hexagon with ability and cooldown state
class MetaHex {
  final HexCoordinate position;
  final List<MetaAbility> availableAbilities;
  final Map<MetaAbilityType, int> cooldowns;
  Player? controlledBy;

  MetaHex({
    required this.position,
    required this.availableAbilities,
    Map<MetaAbilityType, int>? cooldowns,
    this.controlledBy,
  }) : cooldowns = cooldowns ?? {};

  /// Check if ability is available (not on cooldown)
  bool isAbilityAvailable(MetaAbilityType type) {
    final cooldown = cooldowns[type] ?? 0;
    return cooldown <= 0;
  }

  /// Get available abilities not on cooldown
  List<MetaAbility> get usableAbilities {
    return availableAbilities
        .where((ability) => isAbilityAvailable(ability.type))
        .toList();
  }

  /// Use an ability and start its cooldown
  void useAbility(MetaAbilityType type) {
    final ability = availableAbilities.firstWhere(
      (a) => a.type == type,
      orElse: () => throw ArgumentError('Ability $type not available on this Meta hex'),
    );
    cooldowns[type] = ability.cooldown;
  }

  /// Update cooldowns (call each turn)
  void updateCooldowns() {
    for (final type in cooldowns.keys.toList()) {
      if (cooldowns[type]! > 0) {
        cooldowns[type] = cooldowns[type]! - 1;
      }
    }
  }

  /// Copy with updated values
  MetaHex copyWith({
    HexCoordinate? position,
    List<MetaAbility>? availableAbilities,
    Map<MetaAbilityType, int>? cooldowns,
    Player? controlledBy,
  }) {
    return MetaHex(
      position: position ?? this.position,
      availableAbilities: availableAbilities ?? this.availableAbilities,
      cooldowns: cooldowns ?? Map.from(this.cooldowns),
      controlledBy: controlledBy ?? this.controlledBy,
    );
  }
}
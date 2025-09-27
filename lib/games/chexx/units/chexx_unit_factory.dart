import 'package:oxygen/oxygen.dart';
import '../../../core/interfaces/unit_factory.dart';
import '../../../core/models/hex_coordinate.dart';
import '../../../core/components/position_component.dart';
import '../../../core/components/health_component.dart';
import '../../../core/components/owner_component.dart';
import '../../../core/components/unit_type_component.dart';
import '../../../core/components/movement_component.dart';
import '../../../core/components/combat_component.dart';
import '../../../core/components/selection_component.dart';
import '../../../core/models/game_config.dart';

/// CHEXX unit factory implementation
class ChexxUnitFactory implements UnitFactory {
  @override
  Entity createUnit({
    required String unitType,
    required Player owner,
    required HexCoordinate position,
    required String id,
  }) {
    // This would typically get the world from a game manager
    // For now, return a mock entity
    throw UnimplementedError('Entity creation requires world context');
  }

  @override
  List<String> getAvailableUnitTypes() {
    return ['minor', 'scout', 'knight', 'guardian'];
  }

  @override
  Map<String, dynamic> getUnitConfig(String unitType) {
    switch (unitType) {
      case 'minor':
        return {
          'name': 'minor',
          'displayName': 'Minor Unit',
          'maxHealth': 1,
          'attackDamage': 1,
          'attackRange': 1,
          'movementRange': 1,
          'movementType': 'adjacent',
        };
      case 'scout':
        return {
          'name': 'scout',
          'displayName': 'Scout',
          'maxHealth': 2,
          'attackDamage': 1,
          'attackRange': 3,
          'movementRange': 3,
          'movementType': 'straight',
        };
      case 'knight':
        return {
          'name': 'knight',
          'displayName': 'Knight',
          'maxHealth': 3,
          'attackDamage': 2,
          'attackRange': 2,
          'movementRange': 2,
          'movementType': 'knight',
        };
      case 'guardian':
        return {
          'name': 'guardian',
          'displayName': 'Guardian',
          'maxHealth': 3,
          'attackDamage': 1,
          'attackRange': 1,
          'movementRange': 1,
          'movementType': 'adjacent',
        };
      default:
        return {};
    }
  }

  @override
  bool isValidUnitType(String unitType) {
    return getAvailableUnitTypes().contains(unitType);
  }
}
import 'package:oxygen/oxygen.dart';
import '../../core/interfaces/unit_factory.dart';
import '../../core/models/hex_coordinate.dart';

/// Card game doesn't use traditional units, so this is a stub implementation
class CardUnitFactory implements UnitFactory {
  @override
  Entity createUnit({
    required String unitType,
    required Player owner,
    required HexCoordinate position,
    required String id,
  }) {
    throw UnsupportedError('Card game does not use traditional units');
  }

  @override
  List<String> getAvailableUnitTypes() => [];

  @override
  Map<String, dynamic> getUnitConfig(String unitType) {
    throw UnsupportedError('Card game does not use traditional units');
  }

  @override
  bool isValidUnitType(String unitType) => false;
}

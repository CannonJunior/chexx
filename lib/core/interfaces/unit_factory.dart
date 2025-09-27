import 'package:oxygen/oxygen.dart';
import '../models/hex_coordinate.dart';

/// Player enumeration
enum Player { player1, player2 }

/// Interface for creating game units
abstract class UnitFactory {
  /// Create a unit entity with the specified type and position
  Entity createUnit({
    required String unitType,
    required Player owner,
    required HexCoordinate position,
    required String id,
  });

  /// Get all available unit types for this game
  List<String> getAvailableUnitTypes();

  /// Get unit configuration for a specific type
  Map<String, dynamic> getUnitConfig(String unitType);

  /// Validate if a unit type exists
  bool isValidUnitType(String unitType);
}
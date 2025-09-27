import 'hex_coordinate.dart';
import 'game_unit.dart';
import '../../core/interfaces/unit_factory.dart';

enum HexType { normal, meta, blocked }

/// Represents a single hex tile on the game board
class HexTile {
  final HexCoordinate coordinate;
  HexType type;
  bool isHighlighted;

  HexTile({
    required this.coordinate,
    this.type = HexType.normal,
    this.isHighlighted = false,
  });

  bool get isMetaHex => type == HexType.meta;
  bool get isBlocked => type == HexType.blocked;
  bool get isNormal => type == HexType.normal;
}

/// Represents the complete game board with 61 hexes
class GameBoard {
  final Map<HexCoordinate, HexTile> tiles = {};
  final List<HexCoordinate> metaHexes = [];

  GameBoard() {
    _initializeBoard();
  }

  /// Get tile at coordinate
  HexTile? getTile(HexCoordinate coord) => tiles[coord];

  /// Get all tiles
  List<HexTile> get allTiles => tiles.values.toList();

  /// Get tile type at coordinate
  HexType getTileType(HexCoordinate coord) {
    return getTile(coord)?.type ?? HexType.blocked;
  }

  /// Check if coordinate is valid on board
  bool isValidCoordinate(HexCoordinate coord) {
    return tiles.containsKey(coord);
  }

  /// Get unit at position
  GameUnit? getUnitAt(HexCoordinate position, List<GameUnit> units) {
    final matchingUnits = units.where((unit) =>
        unit.isAlive && unit.position == position).toList();
    return matchingUnits.isNotEmpty ? matchingUnits.first : null;
  }

  /// Get all units of a player
  List<GameUnit> getPlayerUnits(Player player, List<GameUnit> units) {
    return units.where((unit) => unit.owner == player && unit.isAlive).toList();
  }

  /// Get starting positions for a player
  List<HexCoordinate> getStartingPositions(Player player) {
    if (player == Player.player1) {
      // Top two rows
      return [
        // Back row (5 major units)
        HexCoordinate.axial(-2, -2),
        HexCoordinate.axial(-1, -2),
        HexCoordinate.axial(0, -2),
        HexCoordinate.axial(1, -2),
        HexCoordinate.axial(2, -2),
        // Front row (6 minor units)
        HexCoordinate.axial(-2, -1),
        HexCoordinate.axial(-1, -1),
        HexCoordinate.axial(0, -1),
        HexCoordinate.axial(1, -1),
        HexCoordinate.axial(2, -1),
        HexCoordinate.axial(3, -1),
      ];
    } else {
      // Bottom two rows
      return [
        // Front row (6 minor units)
        HexCoordinate.axial(-3, 1),
        HexCoordinate.axial(-2, 1),
        HexCoordinate.axial(-1, 1),
        HexCoordinate.axial(0, 1),
        HexCoordinate.axial(1, 1),
        HexCoordinate.axial(2, 1),
        // Back row (5 major units)
        HexCoordinate.axial(-2, 2),
        HexCoordinate.axial(-1, 2),
        HexCoordinate.axial(0, 2),
        HexCoordinate.axial(1, 2),
        HexCoordinate.axial(2, 2),
      ];
    }
  }

  /// Clear all highlights
  void clearHighlights() {
    for (final tile in tiles.values) {
      tile.isHighlighted = false;
    }
  }

  /// Highlight specific coordinates
  void highlightCoordinates(List<HexCoordinate> coords) {
    clearHighlights();
    for (final coord in coords) {
      final tile = getTile(coord);
      if (tile != null) {
        tile.isHighlighted = true;
      }
    }
  }

  /// Initialize the 61-hex board layout
  void _initializeBoard() {
    // Create standard 61-hex layout (hexagonal shape with radius 4)
    final radius = 4;

    for (int q = -radius; q <= radius; q++) {
      final r1 = (-radius - q).clamp(-radius, radius);
      final r2 = (radius - q).clamp(-radius, radius);

      for (int r = r1; r <= r2; r++) {
        final coord = HexCoordinate.axial(q, r);
        tiles[coord] = HexTile(coordinate: coord);
      }
    }

    // Set up meta hexes (6 strategic positions)
    final metaPositions = [
      HexCoordinate.axial(0, -2),   // Top center
      HexCoordinate.axial(2, -1),   // Top right
      HexCoordinate.axial(2, 1),    // Bottom right
      HexCoordinate.axial(0, 2),    // Bottom center
      HexCoordinate.axial(-2, 1),   // Bottom left
      HexCoordinate.axial(-2, -1),  // Top left
    ];

    for (final coord in metaPositions) {
      final tile = getTile(coord);
      if (tile != null) {
        tile.type = HexType.meta;
        metaHexes.add(coord);
      }
    }
  }

  /// Get all neighboring coordinates of a position
  List<HexCoordinate> getNeighbors(HexCoordinate position) {
    return position.neighbors.where((coord) => isValidCoordinate(coord)).toList();
  }

  /// Find shortest path between two coordinates
  List<HexCoordinate> findPath(
    HexCoordinate start,
    HexCoordinate goal,
    List<GameUnit> units,
  ) {
    if (!isValidCoordinate(start) || !isValidCoordinate(goal)) {
      return [];
    }

    // Simple breadth-first search for shortest path
    final queue = <HexCoordinate>[start];
    final visited = <HexCoordinate>{start};
    final parent = <HexCoordinate, HexCoordinate>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (current == goal) {
        // Reconstruct path
        final path = <HexCoordinate>[];
        HexCoordinate? node = goal;

        while (node != null) {
          path.insert(0, node);
          node = parent[node];
        }

        return path.length > 1 ? path.sublist(1) : []; // Exclude start position
      }

      for (final neighbor in getNeighbors(current)) {
        if (!visited.contains(neighbor)) {
          // Check if neighbor is occupied
          final occupant = getUnitAt(neighbor, units);
          if (occupant == null || neighbor == goal) {
            visited.add(neighbor);
            parent[neighbor] = current;
            queue.add(neighbor);
          }
        }
      }
    }

    return []; // No path found
  }

  /// Get all coordinates within a range of a center point
  List<HexCoordinate> getCoordinatesInRange(HexCoordinate center, int range) {
    return HexCoordinate.hexesInRange(center, range)
        .where((coord) => isValidCoordinate(coord))
        .toList();
  }

  /// Check if two coordinates have line of sight (for scout attacks)
  bool hasLineOfSight(HexCoordinate start, HexCoordinate end, List<GameUnit> units) {
    if (start == end) return true;

    // For simplicity, assume line of sight is clear if no units block the direct path
    // In a full implementation, you'd check each hex along the line
    return true; // Simplified for MVP
  }
}
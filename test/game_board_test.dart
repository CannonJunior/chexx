import 'package:flutter_test/flutter_test.dart';
import 'package:chexx/src/models/game_board.dart';
import 'package:chexx/src/models/hex_coordinate.dart';
import 'package:chexx/src/models/game_unit.dart';
import 'package:chexx/core/interfaces/unit_factory.dart';

void main() {
  group('GameBoard - Board Initialization', () {
    test('GB-001: Initialize default board with 91 hexes', () {
      final board = GameBoard();

      // The default board should have 91 tiles (radius 5 hexagonal shape)
      expect(board.tiles.length, 91, reason: 'Default board should have 91 hexes');

      // Check that origin tile exists
      final origin = board.getTile(HexCoordinate(0, 0, 0));
      expect(origin, isNotNull);
      expect(origin!.coordinate, HexCoordinate(0, 0, 0));

      // Verify all tiles have valid coordinates
      for (final tile in board.allTiles) {
        final coord = tile.coordinate;
        expect(coord.q + coord.r + coord.s, 0,
            reason: 'All tiles should have valid cube coordinates');
      }
    });

    test('Default board has 6 meta hexes', () {
      final board = GameBoard();

      expect(board.metaHexes.length, 6,
          reason: 'Default board should have 6 meta hexes');

      // Verify meta hexes are marked correctly
      for (final metaCoord in board.metaHexes) {
        final tile = board.getTile(metaCoord);
        expect(tile, isNotNull);
        expect(tile!.type, HexType.meta);
        expect(tile.isMetaHex, isTrue);
      }
    });

    test('Reset to default restores original board', () {
      final board = GameBoard();

      // Modify the board
      final customCoord = HexCoordinate(10, -5, -5);
      board.addTile(customCoord, HexType.hill);
      expect(board.tiles.length, 92);

      // Reset to default
      board.resetToDefault();

      expect(board.tiles.length, 91);
      expect(board.getTile(customCoord), isNull);
    });
  });

  group('GameBoard - Tile Management', () {
    late GameBoard board;

    setUp(() {
      board = GameBoard();
    });

    test('GB-002: Add tile at new coordinate', () {
      final coord = HexCoordinate(2, 0, -2);
      final initialCount = board.tiles.length;

      // Check if tile already exists
      final existingTile = board.getTile(coord);
      if (existingTile != null) {
        // If it exists, add a tile outside default range
        final newCoord = HexCoordinate(6, -3, -3);
        board.addTile(newCoord, HexType.hill);

        final tile = board.getTile(newCoord);
        expect(tile, isNotNull, reason: 'Tile should be added');
        expect(tile!.type, HexType.hill);
        expect(tile.coordinate, newCoord);
        expect(board.tiles.length, initialCount + 1);
      } else {
        board.addTile(coord, HexType.hill);

        final tile = board.getTile(coord);
        expect(tile, isNotNull, reason: 'Tile should be added');
        expect(tile!.type, HexType.hill);
        expect(tile.coordinate, coord);
        expect(board.tiles.length, initialCount + 1);
      }
    });

    test('GB-003: Remove tile at existing coordinate', () {
      final coord = HexCoordinate(0, 0, 0);
      final initialCount = board.tiles.length;

      // Verify tile exists before removal
      expect(board.getTile(coord), isNotNull);

      // Remove the tile
      board.removeTile(coord);

      expect(board.getTile(coord), isNull,
          reason: 'Tile should be removed');
      expect(board.tiles.length, initialCount - 1);
    });

    test('GB-004: Get tile at existing position', () {
      final coord = HexCoordinate(0, 0, 0);

      final tile = board.getTile(coord);

      expect(tile, isNotNull, reason: 'Origin tile should exist');
      expect(tile, isA<HexTile>());
      expect(tile!.coordinate, coord);
    });

    test('GB-005: Get nonexistent tile returns null', () {
      final coord = HexCoordinate(99, 0, -99);

      final tile = board.getTile(coord);

      expect(tile, isNull, reason: 'Should return null for nonexistent tile');
    });

    test('Get tile type at coordinate', () {
      final origin = HexCoordinate(0, 0, 0);

      expect(board.getTileType(origin), HexType.normal);

      // Add a hill tile
      final hillCoord = HexCoordinate(7, -3, -4);
      board.addTile(hillCoord, HexType.hill);
      expect(board.getTileType(hillCoord), HexType.hill);

      // Nonexistent tile should return blocked
      final nonexistent = HexCoordinate(100, 0, -100);
      expect(board.getTileType(nonexistent), HexType.blocked);
    });

    test('Add tile beyond max radius is rejected', () {
      final farCoord = HexCoordinate(50, -25, -25); // Beyond maxRadius of 40
      final initialCount = board.tiles.length;

      board.addTile(farCoord, HexType.hill);

      // Tile should not be added
      expect(board.getTile(farCoord), isNull);
      expect(board.tiles.length, initialCount,
          reason: 'Tiles beyond max radius should not be added');
    });
  });

  group('GameBoard - Coordinate Validation', () {
    late GameBoard board;

    setUp(() {
      board = GameBoard();
    });

    test('GB-006: Validate coordinate within bounds', () {
      final coord = HexCoordinate(0, 0, 0);

      final isValid = board.isValidCoordinate(coord);

      expect(isValid, isTrue, reason: 'Origin should be valid');

      // Test edge coordinates within default board
      final edge = HexCoordinate(5, 0, -5);
      expect(board.isValidCoordinate(edge), isTrue);
    });

    test('GB-007: Invalid coordinate beyond max radius', () {
      final coord = HexCoordinate(100, 0, -100);

      final isValid = board.isValidCoordinate(coord);

      expect(isValid, isFalse,
          reason: 'Coordinates beyond max radius should be invalid');
    });

    test('Coordinate at max radius boundary is valid', () {
      final maxRadius = GameBoard.maxRadius;
      final boundaryCoord = HexCoordinate(maxRadius, 0, -maxRadius);

      expect(board.isValidCoordinate(boundaryCoord), isTrue);

      // One beyond max radius should be invalid
      final beyondBoundary = HexCoordinate(maxRadius + 1, 0, -(maxRadius + 1));
      expect(board.isValidCoordinate(beyondBoundary), isFalse);
    });

    test('Added tiles are considered valid coordinates', () {
      final newCoord = HexCoordinate(10, -5, -5);

      // Add tile within max radius
      board.addTile(newCoord, HexType.hill);

      expect(board.isValidCoordinate(newCoord), isTrue);
    });
  });

  group('GameBoard - Highlighting', () {
    late GameBoard board;

    setUp(() {
      board = GameBoard();
    });

    test('Clear highlights resets all tiles', () {
      // Highlight some tiles manually
      final coords = [
        HexCoordinate(0, 0, 0),
        HexCoordinate(1, 0, -1),
        HexCoordinate(0, 1, -1),
      ];

      for (final coord in coords) {
        final tile = board.getTile(coord);
        if (tile != null) {
          tile.isHighlighted = true;
        }
      }

      // Clear all highlights
      board.clearHighlights();

      // Verify no tiles are highlighted
      for (final tile in board.allTiles) {
        expect(tile.isHighlighted, isFalse);
      }
    });

    test('Highlight specific coordinates', () {
      final coordsToHighlight = [
        HexCoordinate(0, 0, 0),
        HexCoordinate(1, 0, -1),
        HexCoordinate(-1, 1, 0),
      ];

      board.highlightCoordinates(coordsToHighlight);

      // Check highlighted tiles
      for (final coord in coordsToHighlight) {
        final tile = board.getTile(coord);
        expect(tile?.isHighlighted, isTrue,
            reason: 'Specified coordinate should be highlighted');
      }

      // Check that other tiles are not highlighted
      final otherCoord = HexCoordinate(2, -1, -1);
      final otherTile = board.getTile(otherCoord);
      expect(otherTile?.isHighlighted, isFalse,
          reason: 'Non-specified coordinates should not be highlighted');
    });

    test('Highlight coordinates clears previous highlights', () {
      // First highlight
      board.highlightCoordinates([HexCoordinate(0, 0, 0)]);
      expect(board.getTile(HexCoordinate(0, 0, 0))?.isHighlighted, isTrue);

      // Second highlight (should clear first)
      board.highlightCoordinates([HexCoordinate(1, 0, -1)]);

      expect(board.getTile(HexCoordinate(0, 0, 0))?.isHighlighted, isFalse);
      expect(board.getTile(HexCoordinate(1, 0, -1))?.isHighlighted, isTrue);
    });
  });

  group('GameBoard - Neighbors and Pathfinding', () {
    late GameBoard board;

    setUp(() {
      board = GameBoard();
    });

    test('Get neighbors of coordinate', () {
      final center = HexCoordinate(0, 0, 0);

      final neighbors = board.getNeighbors(center);

      // Should have 6 neighbors (all within default board)
      expect(neighbors.length, 6);

      // All neighbors should be valid
      for (final neighbor in neighbors) {
        expect(board.isValidCoordinate(neighbor), isTrue);
        expect(center.distanceTo(neighbor), 1);
      }
    });

    test('Get neighbors at board edge has fewer neighbors', () {
      // Coordinate at the max radius boundary
      final maxRadius = GameBoard.maxRadius;
      final edge = HexCoordinate(maxRadius, 0, -maxRadius);

      final neighbors = board.getNeighbors(edge);

      // Should have fewer than 6 neighbors (some outside max radius)
      expect(neighbors.length, lessThanOrEqualTo(6),
          reason: 'Neighbors should be 6 or fewer at boundary');

      // All returned neighbors should be valid
      for (final neighbor in neighbors) {
        expect(board.isValidCoordinate(neighbor), isTrue);
      }

      // Some neighbors would be beyond max radius if we tried all 6 directions
      final allPotentialNeighbors = edge.neighbors;
      expect(allPotentialNeighbors.length, 6);

      // At least one neighbor should be invalid (beyond max radius)
      final invalidNeighbors = allPotentialNeighbors
          .where((n) => !board.isValidCoordinate(n))
          .toList();
      expect(invalidNeighbors.isNotEmpty, isTrue,
          reason: 'At boundary, some neighbors should be beyond max radius');
    });

    test('Get coordinates in range', () {
      final center = HexCoordinate(0, 0, 0);

      // Range 0 should return only center (if it exists on board)
      final range0 = board.getCoordinatesInRange(center, 0);
      expect(range0.length, 1);
      expect(range0.contains(center), isTrue);

      // Range 1 should return center + 6 neighbors = 7
      final range1 = board.getCoordinatesInRange(center, 1);
      expect(range1.length, 7);

      // All coordinates should be valid
      for (final coord in range1) {
        expect(board.isValidCoordinate(coord), isTrue);
        expect(center.distanceTo(coord), lessThanOrEqualTo(1));
      }
    });

    test('Find path between two adjacent coordinates', () {
      final start = HexCoordinate(0, 0, 0);
      final goal = HexCoordinate(1, 0, -1);
      final units = <GameUnit>[];

      final path = board.findPath(start, goal, units);

      expect(path.isNotEmpty, isTrue);
      expect(path.last, goal);
      // Path should be short (adjacent hexes)
      expect(path.length, 1);
    });

    test('Find path between distant coordinates', () {
      final start = HexCoordinate(0, 0, 0);
      final goal = HexCoordinate(3, -1, -2);
      final units = <GameUnit>[];

      final path = board.findPath(start, goal, units);

      expect(path.isNotEmpty, isTrue);
      expect(path.last, goal);

      // Verify path length is reasonable (Manhattan distance is 3)
      expect(path.length, greaterThanOrEqualTo(start.distanceTo(goal)));
    });

    test('Find path returns empty for invalid coordinates', () {
      final start = HexCoordinate(0, 0, 0);
      final goal = HexCoordinate(100, 0, -100); // Beyond max radius
      final units = <GameUnit>[];

      final path = board.findPath(start, goal, units);

      expect(path, isEmpty, reason: 'Should return empty path for invalid goal');
    });
  });

  group('GameBoard - Starting Positions', () {
    late GameBoard board;

    setUp(() {
      board = GameBoard();
    });

    test('Get starting positions for player 1', () {
      final positions = board.getStartingPositions(Player.player1);

      expect(positions.length, 11,
          reason: 'Player 1 should have 11 starting positions (5 back row + 6 front row)');

      // Verify all positions are valid
      for (final pos in positions) {
        expect(board.isValidCoordinate(pos), isTrue);
      }

      // Player 1 should be in top rows (negative r values)
      for (final pos in positions) {
        expect(pos.r, lessThanOrEqualTo(-1),
            reason: 'Player 1 positions should be in top rows');
      }
    });

    test('Get starting positions for player 2', () {
      final positions = board.getStartingPositions(Player.player2);

      expect(positions.length, 11,
          reason: 'Player 2 should have 11 starting positions (6 front row + 5 back row)');

      // Verify all positions are valid
      for (final pos in positions) {
        expect(board.isValidCoordinate(pos), isTrue);
      }

      // Player 2 should be in bottom rows (positive r values)
      for (final pos in positions) {
        expect(pos.r, greaterThanOrEqualTo(1),
            reason: 'Player 2 positions should be in bottom rows');
      }
    });

    test('Player starting positions do not overlap', () {
      final p1Positions = board.getStartingPositions(Player.player1);
      final p2Positions = board.getStartingPositions(Player.player2);

      // Check for any overlap
      for (final p1Pos in p1Positions) {
        expect(p2Positions.contains(p1Pos), isFalse,
            reason: 'Player starting positions should not overlap');
      }
    });
  });

  group('GameBoard - HexTile Properties', () {
    test('HexTile has correct properties', () {
      final coord = HexCoordinate(1, 0, -1);
      final tile = HexTile(coordinate: coord, type: HexType.hill);

      expect(tile.coordinate, coord);
      expect(tile.type, HexType.hill);
      expect(tile.isHighlighted, isFalse);
      expect(tile.isNormal, isFalse);
      expect(tile.isMetaHex, isFalse);
      expect(tile.isBlocked, isFalse);
    });

    test('HexTile type checks work correctly', () {
      final coord = HexCoordinate(0, 0, 0);

      final normalTile = HexTile(coordinate: coord, type: HexType.normal);
      expect(normalTile.isNormal, isTrue);
      expect(normalTile.isMetaHex, isFalse);
      expect(normalTile.isBlocked, isFalse);

      final metaTile = HexTile(coordinate: coord, type: HexType.meta);
      expect(metaTile.isMetaHex, isTrue);
      expect(metaTile.isNormal, isFalse);

      final blockedTile = HexTile(coordinate: coord, type: HexType.blocked);
      expect(blockedTile.isBlocked, isTrue);
      expect(blockedTile.isNormal, isFalse);
    });

    test('HexTile can be highlighted', () {
      final tile = HexTile(
        coordinate: HexCoordinate(0, 0, 0),
        isHighlighted: true,
      );

      expect(tile.isHighlighted, isTrue);

      tile.isHighlighted = false;
      expect(tile.isHighlighted, isFalse);
    });
  });

  group('GameBoard - HexType Enum', () {
    test('All HexType values are defined', () {
      final types = HexType.values;

      expect(types.contains(HexType.normal), isTrue);
      expect(types.contains(HexType.meta), isTrue);
      expect(types.contains(HexType.blocked), isTrue);
      expect(types.contains(HexType.ocean), isTrue);
      expect(types.contains(HexType.beach), isTrue);
      expect(types.contains(HexType.hill), isTrue);
      expect(types.contains(HexType.town), isTrue);
      expect(types.contains(HexType.forest), isTrue);
      expect(types.contains(HexType.hedgerow), isTrue);

      expect(types.length, 9, reason: 'Should have 9 hex types');
    });
  });

  group('GameBoard - Edge Cases', () {
    late GameBoard board;

    setUp(() {
      board = GameBoard();
    });

    test('Remove nonexistent tile does not crash', () {
      final coord = HexCoordinate(99, 0, -99);
      final initialCount = board.tiles.length;

      // Should not throw
      expect(() => board.removeTile(coord), returnsNormally);
      expect(board.tiles.length, initialCount);
    });

    test('Highlight nonexistent coordinates does not crash', () {
      final coords = [
        HexCoordinate(99, 0, -99),
        HexCoordinate(100, -50, -50),
      ];

      // Should not throw
      expect(() => board.highlightCoordinates(coords), returnsNormally);
    });

    test('Get neighbors of invalid coordinate returns empty list', () {
      final invalid = HexCoordinate(100, 0, -100);

      final neighbors = board.getNeighbors(invalid);

      expect(neighbors, isEmpty);
    });

    test('Multiple resets restore board correctly', () {
      final board = GameBoard();
      final originalCount = board.tiles.length;

      // Reset multiple times
      board.resetToDefault();
      board.resetToDefault();
      board.resetToDefault();

      expect(board.tiles.length, originalCount);
      expect(board.metaHexes.length, 6);
    });

    test('AllTiles returns all tiles', () {
      final tiles = board.allTiles;

      expect(tiles.length, board.tiles.length);

      // Verify it's a list of HexTiles
      for (final tile in tiles) {
        expect(tile, isA<HexTile>());
      }
    });
  });
}

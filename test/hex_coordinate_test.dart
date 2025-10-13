import 'package:flutter_test/flutter_test.dart';
import 'package:chexx/src/models/hex_coordinate.dart';
import 'package:chexx/src/models/hex_orientation.dart';
import 'dart:math';

void main() {
  group('HexCoordinate - Cube Coordinate Validation', () {
    test('HC-001: Valid cube coordinate (q + r + s = 0)', () {
      // Test various valid coordinates
      final coord1 = HexCoordinate(1, 0, -1);
      expect(coord1.q, 1);
      expect(coord1.r, 0);
      expect(coord1.s, -1);
      expect(coord1.q + coord1.r + coord1.s, 0);

      final coord2 = HexCoordinate(0, 0, 0);
      expect(coord2.q + coord2.r + coord2.s, 0);

      final coord3 = HexCoordinate(-2, 3, -1);
      expect(coord3.q + coord3.r + coord3.s, 0);
    });

    test('HC-002: Invalid coordinate rejection (q + r + s ≠ 0)', () {
      // This should throw an assertion error since q + r + s != 0
      expect(
        () => HexCoordinate(1, 1, 1),
        throwsA(isA<AssertionError>()),
        reason: 'Should throw AssertionError when q + r + s != 0',
      );

      expect(
        () => HexCoordinate(2, 2, 2),
        throwsA(isA<AssertionError>()),
        reason: 'Should throw AssertionError when q + r + s != 0',
      );
    });

    test('Axial coordinate creation', () {
      final coord = HexCoordinate.axial(2, -1);
      expect(coord.q, 2);
      expect(coord.r, -1);
      expect(coord.s, -1); // s = -q - r = -2 - (-1) = -1
      expect(coord.q + coord.r + coord.s, 0);

      // Test axial getter
      final (q, r) = coord.axial;
      expect(q, 2);
      expect(r, -1);
    });
  });

  group('HexCoordinate - Distance Calculations', () {
    test('HC-003: Distance calculation between coordinates', () {
      final origin = HexCoordinate(0, 0, 0);
      final target = HexCoordinate(2, -1, -1);

      final distance = origin.distanceTo(target);
      expect(distance, 2, reason: 'Distance from (0,0,0) to (2,-1,-1) should be 2');

      // Test symmetric distance
      expect(target.distanceTo(origin), distance);

      // Test distance to self
      expect(origin.distanceTo(origin), 0);

      // Test longer distance
      final farTarget = HexCoordinate(3, -3, 0);
      expect(origin.distanceTo(farTarget), 3);
    });

    test('Distance calculation with negative coordinates', () {
      final coord1 = HexCoordinate(-2, 1, 1);
      final coord2 = HexCoordinate(1, -2, 1);

      expect(coord1.distanceTo(coord2), 3);
    });

    test('Adjacent hexes have distance 1', () {
      final center = HexCoordinate(0, 0, 0);
      final adjacent = HexCoordinate(1, 0, -1);

      expect(center.distanceTo(adjacent), 1);
      expect(center.isAdjacentTo(adjacent), isTrue);
    });
  });

  group('HexCoordinate - Neighbor Calculation', () {
    test('HC-004: Get all 6 neighbors', () {
      final center = HexCoordinate(0, 0, 0);
      final neighbors = center.neighbors;

      expect(neighbors.length, 6, reason: 'Should have exactly 6 neighbors');

      // Verify all neighbors are at distance 1
      for (final neighbor in neighbors) {
        expect(center.distanceTo(neighbor), 1,
            reason: 'Each neighbor should be distance 1 from center');
      }

      // Verify the expected neighbor coordinates
      final expectedNeighbors = [
        HexCoordinate(1, 0, -1),   // East
        HexCoordinate(1, -1, 0),   // Northeast
        HexCoordinate(0, -1, 1),   // Northwest
        HexCoordinate(-1, 0, 1),   // West
        HexCoordinate(-1, 1, 0),   // Southwest
        HexCoordinate(0, 1, -1),   // Southeast
      ];

      for (final expected in expectedNeighbors) {
        expect(neighbors.contains(expected), isTrue,
            reason: 'Should contain neighbor $expected');
      }
    });

    test('Neighbors of non-origin hex', () {
      final hex = HexCoordinate(2, -1, -1);
      final neighbors = hex.neighbors;

      expect(neighbors.length, 6);

      // All should be adjacent (distance 1)
      for (final neighbor in neighbors) {
        expect(hex.isAdjacentTo(neighbor), isTrue);
      }
    });

    test('Direction to adjacent hex', () {
      final center = HexCoordinate(0, 0, 0);
      final east = HexCoordinate(1, 0, -1);

      final direction = center.directionTo(east);
      expect(direction, isNotNull);
      expect(direction, 0, reason: 'East should be direction 0');

      // Test non-adjacent hex
      final farHex = HexCoordinate(3, 0, -3);
      expect(center.directionTo(farHex), isNull,
          reason: 'Should return null for non-adjacent hex');
    });
  });

  group('HexCoordinate - Pixel Conversion', () {
    test('HC-005: Hex to pixel conversion (flat orientation)', () {
      final hex = HexCoordinate(1, 0, -1);
      final size = 50.0;

      final (x, y) = hex.toPixel(size, HexOrientation.flat);

      // Verify the conversion formula for flat orientation
      final expectedX = size * (3.0 / 2.0 * hex.q);
      final expectedY = size * (sqrt(3) / 2.0 * hex.q + sqrt(3) * hex.r);

      expect(x, closeTo(expectedX, 0.001));
      expect(y, closeTo(expectedY, 0.001));

      // Test with specific values
      expect(x, closeTo(75.0, 0.001)); // 50 * 1.5
      expect(y, closeTo(43.301, 0.1)); // 50 * sqrt(3)/2
    });

    test('HC-006: Hex to pixel conversion (pointy orientation)', () {
      final hex = HexCoordinate(1, 0, -1);
      final size = 50.0;

      final (x, y) = hex.toPixel(size, HexOrientation.pointy);

      // Verify the conversion formula for pointy orientation
      final expectedX = size * (sqrt(3) * hex.q + sqrt(3) / 2.0 * hex.r);
      final expectedY = size * (3.0 / 2.0 * hex.r);

      expect(x, closeTo(expectedX, 0.001));
      expect(y, closeTo(expectedY, 0.001));

      // Test with specific values
      expect(x, closeTo(86.603, 0.1)); // 50 * sqrt(3)
      expect(y, closeTo(0.0, 0.001));  // 50 * 1.5 * 0
    });

    test('Origin converts to (0, 0) in both orientations', () {
      final origin = HexCoordinate(0, 0, 0);
      final size = 50.0;

      final (flatX, flatY) = origin.toPixel(size, HexOrientation.flat);
      expect(flatX, 0.0);
      expect(flatY, 0.0);

      final (pointyX, pointyY) = origin.toPixel(size, HexOrientation.pointy);
      expect(pointyX, 0.0);
      expect(pointyY, 0.0);
    });
  });

  group('HexCoordinate - Screen to Hex Conversion', () {
    test('HC-007: Pixel to hex conversion (flat orientation)', () {
      final size = 50.0;

      // Convert a hex to pixel and back
      final originalHex = HexCoordinate(2, -1, -1);
      final (x, y) = originalHex.toPixel(size, HexOrientation.flat);
      final convertedHex = HexCoordinate.fromPixel(x, y, size, HexOrientation.flat);

      expect(convertedHex, originalHex,
          reason: 'Converting hex->pixel->hex should preserve the coordinate');
    });

    test('HC-008: Pixel to hex conversion (pointy orientation)', () {
      final size = 50.0;

      // Convert a hex to pixel and back
      final originalHex = HexCoordinate(2, -1, -1);
      final (x, y) = originalHex.toPixel(size, HexOrientation.pointy);
      final convertedHex = HexCoordinate.fromPixel(x, y, size, HexOrientation.pointy);

      expect(convertedHex, originalHex,
          reason: 'Converting hex->pixel->hex should preserve the coordinate');
    });

    test('Screen to hex with specific pixel values (flat)', () {
      final size = 50.0;

      // Test clicking near origin
      final hex = HexCoordinate.fromPixel(10.0, 10.0, size, HexOrientation.flat);
      expect(hex, isNotNull);
      expect(hex.q + hex.r + hex.s, 0, reason: 'Result must be valid hex coordinate');
    });

    test('Screen to hex with specific pixel values (pointy)', () {
      final size = 50.0;

      // Test clicking near origin
      final hex = HexCoordinate.fromPixel(10.0, 10.0, size, HexOrientation.pointy);
      expect(hex, isNotNull);
      expect(hex.q + hex.r + hex.s, 0, reason: 'Result must be valid hex coordinate');
    });
  });

  group('HexCoordinate - Arithmetic Operations', () {
    test('Addition operator', () {
      final hex1 = HexCoordinate(1, 0, -1);
      final hex2 = HexCoordinate(2, -1, -1);

      final result = hex1 + hex2;
      expect(result.q, 3);
      expect(result.r, -1);
      expect(result.s, -2);
      expect(result.q + result.r + result.s, 0);
    });

    test('Subtraction operator', () {
      final hex1 = HexCoordinate(3, -1, -2);
      final hex2 = HexCoordinate(1, 0, -1);

      final result = hex1 - hex2;
      expect(result.q, 2);
      expect(result.r, -1);
      expect(result.s, -1);
      expect(result.q + result.r + result.s, 0);
    });

    test('Scalar multiplication operator', () {
      final hex = HexCoordinate(1, -1, 0);
      final result = hex * 3;

      expect(result.q, 3);
      expect(result.r, -3);
      expect(result.s, 0);
      expect(result.q + result.r + result.s, 0);
    });
  });

  group('HexCoordinate - Equality and Hashing', () {
    test('Equality operator', () {
      final hex1 = HexCoordinate(1, 0, -1);
      final hex2 = HexCoordinate(1, 0, -1);
      final hex3 = HexCoordinate(2, 0, -2);

      expect(hex1 == hex2, isTrue);
      expect(hex1 == hex3, isFalse);
    });

    test('Hash code consistency', () {
      final hex1 = HexCoordinate(1, 0, -1);
      final hex2 = HexCoordinate(1, 0, -1);

      expect(hex1.hashCode, hex2.hashCode,
          reason: 'Equal coordinates should have equal hash codes');
    });

    test('toString method', () {
      final hex = HexCoordinate(1, -2, 1);
      final str = hex.toString();

      expect(str, contains('1'));
      expect(str, contains('-2'));
      expect(str, contains('HexCoordinate'));
    });
  });

  group('HexCoordinate - Range and Area', () {
    test('isInRange method', () {
      final center = HexCoordinate(0, 0, 0);
      final nearby = HexCoordinate(1, 0, -1);
      final far = HexCoordinate(5, -3, -2);

      expect(nearby.isInRange(center, 2), isTrue);
      expect(nearby.isInRange(center, 1), isTrue);
      expect(nearby.isInRange(center, 0), isFalse);

      expect(far.isInRange(center, 3), isFalse);
      expect(far.isInRange(center, 10), isTrue);
    });

    test('hexesInRange static method', () {
      final center = HexCoordinate(0, 0, 0);

      // Range 0 should only return center
      final range0 = HexCoordinate.hexesInRange(center, 0);
      expect(range0.length, 1);
      expect(range0.contains(center), isTrue);

      // Range 1 should return center + 6 neighbors = 7 hexes
      final range1 = HexCoordinate.hexesInRange(center, 1);
      expect(range1.length, 7);
      expect(range1.contains(center), isTrue);

      // Range 2 should return 19 hexes (1 + 6 + 12)
      final range2 = HexCoordinate.hexesInRange(center, 2);
      expect(range2.length, 19);

      // Verify all hexes are within range
      for (final hex in range2) {
        expect(center.distanceTo(hex), lessThanOrEqualTo(2));
      }
    });

    test('hexesInRange with non-origin center', () {
      final center = HexCoordinate(5, -2, -3);
      final range1 = HexCoordinate.hexesInRange(center, 1);

      expect(range1.length, 7);
      expect(range1.contains(center), isTrue);

      for (final hex in range1) {
        expect(center.distanceTo(hex), lessThanOrEqualTo(1));
      }
    });
  });

  group('HexCoordinate - Keyboard Directions', () {
    test('Valid keyboard movement keys', () {
      expect(HexCoordinate.isValidMovementKey('w'), isTrue);
      expect(HexCoordinate.isValidMovementKey('e'), isTrue);
      expect(HexCoordinate.isValidMovementKey('d'), isTrue);
      expect(HexCoordinate.isValidMovementKey('s'), isTrue);
      expect(HexCoordinate.isValidMovementKey('a'), isTrue);
      expect(HexCoordinate.isValidMovementKey('q'), isTrue);

      // Test uppercase
      expect(HexCoordinate.isValidMovementKey('W'), isTrue);
      expect(HexCoordinate.isValidMovementKey('E'), isTrue);

      // Test invalid keys
      expect(HexCoordinate.isValidMovementKey('x'), isFalse);
      expect(HexCoordinate.isValidMovementKey('z'), isFalse);
    });

    test('Get neighbor in keyboard direction', () {
      final center = HexCoordinate(0, 0, 0);

      // Test each direction
      final neighborW = center.getNeighborInDirection('w');
      expect(neighborW, HexCoordinate(0, -1, 1));

      final neighborE = center.getNeighborInDirection('e');
      expect(neighborE, HexCoordinate(1, -1, 0));

      final neighborD = center.getNeighborInDirection('d');
      expect(neighborD, HexCoordinate(1, 0, -1));

      final neighborS = center.getNeighborInDirection('s');
      expect(neighborS, HexCoordinate(0, 1, -1));

      final neighborA = center.getNeighborInDirection('a');
      expect(neighborA, HexCoordinate(-1, 1, 0));

      final neighborQ = center.getNeighborInDirection('q');
      expect(neighborQ, HexCoordinate(-1, 0, 1));

      // Test invalid key
      final invalid = center.getNeighborInDirection('x');
      expect(invalid, isNull);
    });

    test('Keyboard directions work with uppercase', () {
      final center = HexCoordinate(0, 0, 0);

      final neighborW = center.getNeighborInDirection('W');
      expect(neighborW, HexCoordinate(0, -1, 1));
    });

    test('All keyboard directions are valid neighbors', () {
      final center = HexCoordinate(0, 0, 0);
      final keys = ['w', 'e', 'd', 's', 'a', 'q'];

      for (final key in keys) {
        final neighbor = center.getNeighborInDirection(key);
        expect(neighbor, isNotNull);
        expect(center.distanceTo(neighbor!), 1);
        expect(center.isAdjacentTo(neighbor), isTrue);
      }
    });
  });

  group('HexCoordinate - Edge Cases', () {
    test('Large coordinate values', () {
      final large = HexCoordinate(1000, -500, -500);
      expect(large.q + large.r + large.s, 0);

      final distance = HexCoordinate(0, 0, 0).distanceTo(large);
      expect(distance, 1000);
    });

    test('Negative coordinate values', () {
      final negative = HexCoordinate(-5, 3, 2);
      expect(negative.q + negative.r + negative.s, 0);

      final neighbors = negative.neighbors;
      expect(neighbors.length, 6);
    });

    test('Operations preserve cube constraint', () {
      final hex1 = HexCoordinate(2, -1, -1);
      final hex2 = HexCoordinate(1, 1, -2);

      final sum = hex1 + hex2;
      expect(sum.q + sum.r + sum.s, 0);

      final diff = hex1 - hex2;
      expect(diff.q + diff.r + diff.s, 0);

      final scaled = hex1 * 5;
      expect(scaled.q + scaled.r + scaled.s, 0);
    });
  });
}

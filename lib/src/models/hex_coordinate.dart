import 'dart:math';
import 'scenario_builder_state.dart'; // For HexOrientation enum

/// Represents a hexagonal coordinate using the cube coordinate system
/// where q + r + s = 0, providing symmetrical calculations
class HexCoordinate {
  final int q;
  final int r;
  final int s;

  const HexCoordinate(this.q, this.r, this.s) : assert(q + r + s == 0);

  /// Create from axial coordinates (q, r)
  HexCoordinate.axial(int q, int r) : this(q, r, -q - r);

  /// Get axial representation (q, r)
  (int, int) get axial => (q, r);

  /// Calculate distance to another hex coordinate
  int distanceTo(HexCoordinate other) {
    return ((q - other.q).abs() + (r - other.r).abs() + (s - other.s).abs()) ~/ 2;
  }

  /// Get all 6 neighboring hex coordinates
  List<HexCoordinate> get neighbors {
    return _directions.map((dir) => this + dir).toList();
  }

  /// Add two hex coordinates
  HexCoordinate operator +(HexCoordinate other) {
    return HexCoordinate(q + other.q, r + other.r, s + other.s);
  }

  /// Subtract two hex coordinates
  HexCoordinate operator -(HexCoordinate other) {
    return HexCoordinate(q - other.q, r - other.r, s - other.s);
  }

  /// Scale hex coordinate by a factor
  HexCoordinate operator *(int scale) {
    return HexCoordinate(q * scale, r * scale, s * scale);
  }

  /// Check if this hex is adjacent to another hex
  bool isAdjacentTo(HexCoordinate other) {
    return distanceTo(other) == 1;
  }

  /// Get direction from this hex to another hex (if adjacent)
  int? directionTo(HexCoordinate other) {
    if (!isAdjacentTo(other)) return null;

    final diff = other - this;
    for (int i = 0; i < _directions.length; i++) {
      if (_directions[i] == diff) return i;
    }
    return null;
  }

  /// Check if this coordinate is within a certain range of another
  bool isInRange(HexCoordinate center, int range) {
    return distanceTo(center) <= range;
  }

  /// Convert to pixel coordinates for rendering
  (double, double) toPixel(double size, [HexOrientation orientation = HexOrientation.flat]) {
    if (orientation == HexOrientation.flat) {
      // Flat-top orientation (original)
      final x = size * (3.0 / 2.0 * q);
      final y = size * (sqrt(3) / 2.0 * q + sqrt(3) * r);
      return (x, y);
    } else {
      // Pointy-top orientation
      final x = size * (sqrt(3) * q + sqrt(3) / 2.0 * r);
      final y = size * (3.0 / 2.0 * r);
      return (x, y);
    }
  }

  /// Create hex coordinate from pixel coordinates
  static HexCoordinate fromPixel(double x, double y, double size, [HexOrientation orientation = HexOrientation.flat]) {
    if (orientation == HexOrientation.flat) {
      // Flat-top orientation (original)
      final q = (2.0 / 3.0 * x) / size;
      final r = (-1.0 / 3.0 * x + sqrt(3) / 3.0 * y) / size;
      return _roundHex(q, r, -q - r);
    } else {
      // Pointy-top orientation
      final q = (sqrt(3) / 3.0 * x - 1.0 / 3.0 * y) / size;
      final r = (2.0 / 3.0 * y) / size;
      return _roundHex(q, r, -q - r);
    }
  }

  /// Round fractional hex coordinates to nearest integer coordinates
  static HexCoordinate _roundHex(double q, double r, double s) {
    int rq = q.round();
    int rr = r.round();
    int rs = s.round();

    final qDiff = (rq - q).abs();
    final rDiff = (rr - r).abs();
    final sDiff = (rs - s).abs();

    if (qDiff > rDiff && qDiff > sDiff) {
      rq = -rr - rs;
    } else if (rDiff > sDiff) {
      rr = -rq - rs;
    } else {
      rs = -rq - rr;
    }

    return HexCoordinate(rq, rr, rs);
  }

  /// Get all hex coordinates within a certain range
  static List<HexCoordinate> hexesInRange(HexCoordinate center, int range) {
    final List<HexCoordinate> results = [];

    for (int q = -range; q <= range; q++) {
      final r1 = max(-range, -q - range);
      final r2 = min(range, -q + range);

      for (int r = r1; r <= r2; r++) {
        results.add(HexCoordinate.axial(center.q + q, center.r + r));
      }
    }

    return results;
  }

  /// Six direction vectors for hex neighbors
  static const List<HexCoordinate> _directions = [
    HexCoordinate(1, 0, -1),   // East
    HexCoordinate(1, -1, 0),  // Northeast
    HexCoordinate(0, -1, 1),  // Northwest
    HexCoordinate(-1, 0, 1),  // West
    HexCoordinate(-1, 1, 0),  // Southwest
    HexCoordinate(0, 1, -1),  // Southeast
  ];

  /// Keyboard direction mappings (clock positions)
  /// W: 12 o'clock, E: 2 o'clock, D: 4 o'clock, S: 6 o'clock, A: 8 o'clock, Q: 10 o'clock
  static const Map<String, HexCoordinate> keyboardDirections = {
    'w': HexCoordinate(0, -1, 1),   // 12 o'clock (North/Northwest)
    'e': HexCoordinate(1, -1, 0),   // 2 o'clock (Northeast)
    'd': HexCoordinate(1, 0, -1),   // 4 o'clock (East/Southeast)
    's': HexCoordinate(0, 1, -1),   // 6 o'clock (South/Southeast)
    'a': HexCoordinate(-1, 1, 0),   // 8 o'clock (Southwest)
    'q': HexCoordinate(-1, 0, 1),   // 10 o'clock (West/Northwest)
  };

  /// Get neighbor in specific keyboard direction
  HexCoordinate? getNeighborInDirection(String key) {
    final direction = keyboardDirections[key.toLowerCase()];
    return direction != null ? this + direction : null;
  }

  /// Check if a key represents a valid movement direction
  static bool isValidMovementKey(String key) {
    return keyboardDirections.containsKey(key.toLowerCase());
  }

  @override
  bool operator ==(Object other) {
    return other is HexCoordinate &&
           other.q == q &&
           other.r == r &&
           other.s == s;
  }

  @override
  int get hashCode => Object.hash(q, r, s);

  @override
  String toString() => 'HexCoordinate($q, $r, $s)';
}
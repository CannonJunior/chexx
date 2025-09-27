import 'dart:math';

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

  /// Check equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HexCoordinate && other.q == q && other.r == r && other.s == s;
  }

  @override
  int get hashCode => Object.hash(q, r, s);

  @override
  String toString() => 'HexCoordinate($q, $r, $s)';

  /// Convert to pixel coordinates for rendering
  (double, double) toPixel(double hexSize) {
    final x = hexSize * (3.0 / 2.0 * q);
    final y = hexSize * (sqrt(3.0) / 2.0 * q + sqrt(3.0) * r);
    return (x, y);
  }

  /// Create from pixel coordinates
  static HexCoordinate fromPixel(double x, double y, double hexSize) {
    final q = (2.0 / 3.0 * x) / hexSize;
    final r = (-1.0 / 3.0 * x + sqrt(3.0) / 3.0 * y) / hexSize;
    return _roundToCube(q, r, -q - r);
  }

  /// Get all hexes within a certain range
  static List<HexCoordinate> hexesInRange(HexCoordinate center, int range) {
    final results = <HexCoordinate>[];
    for (int q = -range; q <= range; q++) {
      final r1 = max(-range, -q - range);
      final r2 = min(range, -q + range);
      for (int r = r1; r <= r2; r++) {
        final hex = HexCoordinate(center.q + q, center.r + r, center.s + (-q - r));
        results.add(hex);
      }
    }
    return results;
  }

  /// Round fractional cube coordinates to nearest integer coordinates
  static HexCoordinate _roundToCube(double q, double r, double s) {
    var rQ = q.round();
    var rR = r.round();
    var rS = s.round();

    final qDiff = (rQ - q).abs();
    final rDiff = (rR - r).abs();
    final sDiff = (rS - s).abs();

    if (qDiff > rDiff && qDiff > sDiff) {
      rQ = -rR - rS;
    } else if (rDiff > sDiff) {
      rR = -rQ - rS;
    } else {
      rS = -rQ - rR;
    }

    return HexCoordinate(rQ, rR, rS);
  }

  /// Six directions for hexagonal movement
  static const List<HexCoordinate> _directions = [
    HexCoordinate(1, 0, -1),   // East
    HexCoordinate(1, -1, 0),   // Northeast
    HexCoordinate(0, -1, 1),   // Northwest
    HexCoordinate(-1, 0, 1),   // West
    HexCoordinate(-1, 1, 0),   // Southwest
    HexCoordinate(0, 1, -1),   // Southeast
  ];

  /// Get direction at index (0-5)
  static HexCoordinate direction(int index) {
    return _directions[index % 6];
  }

  /// Get hex in specific direction
  HexCoordinate neighbor(int direction) {
    return this + HexCoordinate.direction(direction);
  }

  /// Line drawing between two hex coordinates
  static List<HexCoordinate> line(HexCoordinate from, HexCoordinate to) {
    final distance = from.distanceTo(to);
    if (distance == 0) return [from];

    final results = <HexCoordinate>[];
    for (int i = 0; i <= distance; i++) {
      final t = i / distance;
      final q = from.q * (1 - t) + to.q * t;
      final r = from.r * (1 - t) + to.r * t;
      final s = from.s * (1 - t) + to.s * t;
      results.add(_roundToCube(q, r, s));
    }
    return results;
  }

  /// Check if this coordinate is within bounds of a board
  bool isWithinBounds({required int minQ, required int maxQ, required int minR, required int maxR}) {
    return q >= minQ && q <= maxQ && r >= minR && r <= maxR;
  }
}
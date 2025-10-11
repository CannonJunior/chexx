/// Serializable hex coordinate data for network transmission
class HexCoordinateData {
  final int q;
  final int r;
  final int s;

  const HexCoordinateData(this.q, this.r, this.s);

  /// Validate that q + r + s = 0 (cube coordinate constraint)
  bool get isValid => q + r + s == 0;

  Map<String, dynamic> toJson() {
    return {
      'q': q,
      'r': r,
      's': s,
    };
  }

  factory HexCoordinateData.fromJson(Map<String, dynamic> json) {
    return HexCoordinateData(
      json['q'] as int,
      json['r'] as int,
      json['s'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HexCoordinateData &&
        other.q == q &&
        other.r == r &&
        other.s == s;
  }

  @override
  int get hashCode => Object.hash(q, r, s);

  @override
  String toString() => 'HexCoordinate($q, $r, $s)';
}

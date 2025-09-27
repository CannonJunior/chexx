import 'package:oxygen/oxygen.dart';
import '../models/hex_coordinate.dart';

/// Component for entity position on the hex grid
class PositionComponent extends Component<PositionComponent> {
  HexCoordinate coordinate = const HexCoordinate(0, 0, 0);

  PositionComponent({HexCoordinate? coordinate}) {
    if (coordinate != null) this.coordinate = coordinate;
  }

  @override
  void init([PositionComponent? data]) {
    coordinate = data?.coordinate ?? const HexCoordinate(0, 0, 0);
  }

  @override
  void reset() {
    coordinate = const HexCoordinate(0, 0, 0);
  }
}
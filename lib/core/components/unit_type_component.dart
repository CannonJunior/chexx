import 'package:oxygen/oxygen.dart';

/// Component for unit type identification
class UnitTypeComponent extends Component<UnitTypeComponent> {
  String unitType = '';
  String displayName = '';

  UnitTypeComponent({
    String? unitType,
    String? displayName,
  }) {
    if (unitType != null) this.unitType = unitType;
    if (displayName != null) this.displayName = displayName;
  }

  @override
  void init([UnitTypeComponent? data]) {
    unitType = data?.unitType ?? '';
    displayName = data?.displayName ?? '';
  }

  @override
  void reset() {
    unitType = '';
    displayName = '';
  }
}
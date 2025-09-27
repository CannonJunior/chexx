import 'package:oxygen/oxygen.dart';

/// Component for entity selection state
class SelectionComponent extends Component<SelectionComponent> {
  bool isSelected;
  bool isHovered;

  SelectionComponent({
    this.isSelected = false,
    this.isHovered = false,
  });

  @override
  void init([SelectionComponent? data]) {
    isSelected = data?.isSelected ?? false;
    isHovered = data?.isHovered ?? false;
  }

  @override
  void reset() {
    isSelected = false;
    isHovered = false;
  }
}
import 'package:oxygen/oxygen.dart';
import '../interfaces/unit_factory.dart';

/// Component for entity ownership (which player owns this entity)
class OwnerComponent extends Component<OwnerComponent> {
  Player owner = Player.player1;

  OwnerComponent({Player? owner}) {
    if (owner != null) this.owner = owner;
  }

  @override
  void init([OwnerComponent? data]) {
    owner = data?.owner ?? Player.player1;
  }

  @override
  void reset() {
    owner = Player.player1;
  }
}
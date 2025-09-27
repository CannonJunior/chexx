import 'package:oxygen/oxygen.dart';
import '../models/game_config.dart';

/// Component for movement capabilities
class MovementComponent extends Component<MovementComponent> {
  int movementRange = 1;
  MovementType movementType = MovementType.adjacent;
  int remainingMovement = 1;

  MovementComponent({
    int? movementRange,
    MovementType? movementType,
    int? remainingMovement,
  }) {
    if (movementRange != null) this.movementRange = movementRange;
    if (movementType != null) this.movementType = movementType;
    this.remainingMovement = remainingMovement ?? this.movementRange;
  }

  @override
  void init([MovementComponent? data]) {
    movementRange = data?.movementRange ?? 1;
    movementType = data?.movementType ?? MovementType.adjacent;
    remainingMovement = data?.remainingMovement ?? movementRange;
  }

  /// Reset movement for new turn
  void resetMovement() {
    remainingMovement = movementRange;
  }

  /// Use movement points
  bool useMovement(int cost) {
    if (remainingMovement >= cost) {
      remainingMovement -= cost;
      return true;
    }
    return false;
  }

  /// Check if entity can move
  bool get canMove => remainingMovement > 0;

  @override
  void reset() {
    movementRange = 1;
    movementType = MovementType.adjacent;
    remainingMovement = 1;
  }
}
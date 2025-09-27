import 'package:oxygen/oxygen.dart';

/// Component for combat capabilities
class CombatComponent extends Component<CombatComponent> {
  int attackDamage;
  int attackRange;
  bool hasAttacked;

  CombatComponent({
    required this.attackDamage,
    required this.attackRange,
    this.hasAttacked = false,
  });

  /// Reset attack flag for new turn
  void resetAttack() {
    hasAttacked = false;
  }

  /// Mark as having attacked this turn
  void markAttacked() {
    hasAttacked = true;
  }

  /// Check if entity can attack
  bool get canAttack => !hasAttacked;

  @override
  void init([CombatComponent? data]) {
    attackDamage = data?.attackDamage ?? 1;
    attackRange = data?.attackRange ?? 1;
    hasAttacked = data?.hasAttacked ?? false;
  }

  @override
  void reset() {
    attackDamage = 1;
    attackRange = 1;
    hasAttacked = false;
  }
}
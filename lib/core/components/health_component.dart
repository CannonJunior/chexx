import 'package:oxygen/oxygen.dart';

/// Component for entity health and damage tracking
class HealthComponent extends Component<HealthComponent> {
  int currentHealth = 1;
  int maxHealth = 1;

  HealthComponent({
    int? currentHealth,
    int? maxHealth,
  }) {
    if (currentHealth != null) this.currentHealth = currentHealth;
    if (maxHealth != null) this.maxHealth = maxHealth;
  }

  @override
  void init([HealthComponent? data]) {
    currentHealth = data?.currentHealth ?? 1;
    maxHealth = data?.maxHealth ?? 1;
  }

  /// Check if entity is alive
  bool get isAlive => currentHealth > 0;

  /// Take damage and return true if entity died
  bool takeDamage(int damage) {
    currentHealth = (currentHealth - damage).clamp(0, maxHealth);
    return !isAlive;
  }

  /// Heal entity
  void heal(int amount) {
    currentHealth = (currentHealth + amount).clamp(0, maxHealth);
  }

  /// Get health percentage (0.0 to 1.0)
  double get healthPercentage => currentHealth / maxHealth;

  @override
  void reset() {
    currentHealth = 1;
    maxHealth = 1;
  }
}
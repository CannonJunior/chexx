import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'hex_coordinate.dart';
import 'game_unit.dart';
import 'game_board.dart';

/// Represents a unit template in the scenario builder
class UnitTemplate {
  final UnitType type;
  final Player owner;
  final String id;

  const UnitTemplate({
    required this.type,
    required this.owner,
    required this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'owner': owner.toString().split('.').last,
      'id': id,
    };
  }

  factory UnitTemplate.fromJson(Map<String, dynamic> json) {
    return UnitTemplate(
      type: UnitType.values.firstWhere((e) => e.toString().split('.').last == json['type']),
      owner: Player.values.firstWhere((e) => e.toString().split('.').last == json['owner']),
      id: json['id'] as String,
    );
  }
}

/// Represents a placed unit in the scenario
class PlacedUnit {
  final UnitTemplate template;
  final HexCoordinate position;

  const PlacedUnit({
    required this.template,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'template': template.toJson(),
      'position': {
        'q': position.q,
        'r': position.r,
        's': position.s,
      },
    };
  }

  factory PlacedUnit.fromJson(Map<String, dynamic> json) {
    final positionData = json['position'] as Map<String, dynamic>;
    return PlacedUnit(
      template: UnitTemplate.fromJson(json['template'] as Map<String, dynamic>),
      position: HexCoordinate(
        positionData['q'] as int,
        positionData['r'] as int,
        positionData['s'] as int,
      ),
    );
  }
}

/// Scenario Builder state management
class ScenarioBuilderState extends ChangeNotifier {
  final GameBoard board = GameBoard();
  final List<UnitTemplate> availableUnits = [];
  final List<PlacedUnit> placedUnits = [];
  final Set<HexCoordinate> metaHexes = {};

  UnitTemplate? selectedUnitTemplate;
  String scenarioName = 'Custom Scenario';

  ScenarioBuilderState() {
    _initializeAvailableUnits();
    _initializeDefaultMetaHexes();
  }

  /// Initialize available unit templates from config
  void _initializeAvailableUnits() {
    availableUnits.clear();

    // Player 1 units (blue)
    for (int i = 0; i < 6; i++) {
      availableUnits.add(UnitTemplate(
        type: UnitType.minor,
        owner: Player.player1,
        id: 'p1_minor_$i',
      ));
    }

    availableUnits.addAll([
      const UnitTemplate(type: UnitType.scout, owner: Player.player1, id: 'p1_scout'),
      const UnitTemplate(type: UnitType.knight, owner: Player.player1, id: 'p1_knight'),
      const UnitTemplate(type: UnitType.guardian, owner: Player.player1, id: 'p1_guardian'),
    ]);

    // Player 2 units (red)
    for (int i = 0; i < 6; i++) {
      availableUnits.add(UnitTemplate(
        type: UnitType.minor,
        owner: Player.player2,
        id: 'p2_minor_$i',
      ));
    }

    availableUnits.addAll([
      const UnitTemplate(type: UnitType.scout, owner: Player.player2, id: 'p2_scout'),
      const UnitTemplate(type: UnitType.knight, owner: Player.player2, id: 'p2_knight'),
      const UnitTemplate(type: UnitType.guardian, owner: Player.player2, id: 'p2_guardian'),
    ]);
  }

  /// Initialize default Meta hex positions
  void _initializeDefaultMetaHexes() {
    metaHexes.addAll([
      const HexCoordinate(0, -2, 2),
      const HexCoordinate(2, -1, -1),
      const HexCoordinate(-2, 1, 1),
      const HexCoordinate(0, 2, -2),
      const HexCoordinate(-1, -1, 2),
      const HexCoordinate(1, 1, -2),
    ]);
  }

  /// Select a unit template for placement
  void selectUnitTemplate(UnitTemplate? template) {
    selectedUnitTemplate = template;
    notifyListeners();
  }

  /// Place a unit at the specified position
  bool placeUnit(HexCoordinate position) {
    if (selectedUnitTemplate == null) return false;
    if (!board.isValidCoordinate(position)) return false;

    // Check if position is already occupied
    final existingUnit = placedUnits.where((unit) => unit.position == position).firstOrNull;
    if (existingUnit != null) {
      // Replace existing unit
      placedUnits.remove(existingUnit);
    }

    placedUnits.add(PlacedUnit(
      template: selectedUnitTemplate!,
      position: position,
    ));

    notifyListeners();
    return true;
  }

  /// Remove unit at position
  bool removeUnit(HexCoordinate position) {
    final unitToRemove = placedUnits.where((unit) => unit.position == position).firstOrNull;
    if (unitToRemove != null) {
      placedUnits.remove(unitToRemove);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Toggle Meta hex at position
  void toggleMetaHex(HexCoordinate position) {
    if (!board.isValidCoordinate(position)) return;

    if (metaHexes.contains(position)) {
      metaHexes.remove(position);
    } else {
      metaHexes.add(position);
    }
    notifyListeners();
  }

  /// Get unit at position (if any)
  PlacedUnit? getUnitAt(HexCoordinate position) {
    return placedUnits.where((unit) => unit.position == position).firstOrNull;
  }

  /// Check if position is a Meta hex
  bool isMetaHex(HexCoordinate position) {
    return metaHexes.contains(position);
  }

  /// Clear all placed units
  void clearUnits() {
    placedUnits.clear();
    notifyListeners();
  }

  /// Reset Meta hexes to default positions
  void resetMetaHexes() {
    metaHexes.clear();
    _initializeDefaultMetaHexes();
    notifyListeners();
  }

  /// Generate scenario configuration for saving
  Map<String, dynamic> generateScenarioConfig() {
    // Load base config (this would normally be loaded from assets)
    final baseConfig = <String, dynamic>{
      'board': {
        'total_hexes': 61,
        'hex_size': 60.0,
        'board_layout': 'standard_61'
      },
      'gameplay': {
        'turn_timer_seconds': 6,
        'max_reward_points': 61,
        'time_bonus_multiplier': 5
      },
      'unit_types': {
        'scout': {
          'health': 2,
          'movement_range': 3,
          'attack_range': 3,
          'attack_damage': 1,
          'movement_type': 'straight_line'
        },
        'knight': {
          'health': 3,
          'movement_range': 2,
          'attack_range': 2,
          'attack_damage': 2,
          'movement_type': 'l_shaped'
        },
        'guardian': {
          'health': 3,
          'movement_range': 1,
          'attack_range': 1,
          'attack_damage': 1,
          'movement_type': 'adjacent',
          'special': 'can_swap_with_friendly'
        }
      },
      'meta_abilities': {
        'spawn': {
          'description': 'Create new Minor Unit on adjacent hex',
          'range': 1,
          'cooldown': 3
        },
        'heal': {
          'description': 'Heal adjacent friendly unit by 1 HP',
          'range': 1,
          'heal_amount': 1,
          'cooldown': 2
        },
        'shield': {
          'description': 'Adjacent friendly units take -1 damage for 2 turns',
          'range': 1,
          'duration': 2,
          'cooldown': 4
        }
      }
    };

    // Add scenario-specific data
    baseConfig['scenario_name'] = scenarioName;
    baseConfig['meta_hex_positions'] = metaHexes.map((hex) => {
      'q': hex.q,
      'r': hex.r,
    }).toList();

    baseConfig['unit_placements'] = placedUnits.map((unit) => unit.toJson()).toList();

    return baseConfig;
  }

  /// Set scenario name
  void setScenarioName(String name) {
    scenarioName = name.trim().isEmpty ? 'Custom Scenario' : name.trim();
    notifyListeners();
  }
}
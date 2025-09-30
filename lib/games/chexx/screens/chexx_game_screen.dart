import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/engine/game_engine_base.dart';
import '../../../core/models/hex_coordinate.dart';
import '../../../core/interfaces/unit_factory.dart';
import '../chexx_plugin.dart';
import '../models/chexx_game_state.dart';
import 'chexx_game_engine.dart';
import '../../../src/models/hex_orientation.dart';
import '../../../src/systems/combat/die_faces_config.dart';
import '../../../src/utils/tile_colors.dart';
import '../../../src/models/game_board.dart';
import '../../../src/models/hex_coordinate.dart' as src_hex;

/// CHEXX game screen implementation
class ChexxGameScreen extends StatefulWidget {
  final Map<String, dynamic>? scenarioConfig;
  final ChexxPlugin? gamePlugin;

  const ChexxGameScreen({super.key, this.scenarioConfig, this.gamePlugin});

  @override
  State<ChexxGameScreen> createState() => _ChexxGameScreenState();
}

class _ChexxGameScreenState extends State<ChexxGameScreen> {
  late ChexxGameEngine gameEngine;
  late FocusNode _focusNode;
  bool _showSettingsPanel = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    gameEngine = ChexxGameEngine(
      gamePlugin: widget.gamePlugin ?? ChexxPlugin(),
      scenarioConfig: widget.scenarioConfig,
    );
    gameEngine.addListener(_onGameStateChanged);

    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    gameEngine.removeListener(_onGameStateChanged);
    gameEngine.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: Stack(
            children: [
              // Game canvas
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: (details) => _handleTap(details.globalPosition),
                  child: CustomPaint(
                    painter: ChexxGamePainter(gameEngine),
                    size: Size.infinite,
                  ),
                ),
              ),

              // Game UI overlay
              Positioned.fill(
                child: _buildGameUI(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset position) {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    gameEngine.handleTap(position, size);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _handleKeyPress(event.logicalKey);
    }
  }

  void _handleKeyPress(LogicalKeyboardKey key) {
    final gameState = gameEngine.gameState as ChexxGameState;
    SimpleGameUnit? selectedUnit;

    // Find selected unit
    for (final unit in gameState.simpleUnits) {
      if (unit.isSelected && unit.owner == gameState.currentPlayer) {
        selectedUnit = unit;
        break;
      }
    }

    if (selectedUnit == null || selectedUnit.remainingMovement <= 0) return;

    // Map keys to hex directions
    HexCoordinate? direction;
    switch (key) {
      case LogicalKeyboardKey.keyQ:
        direction = const HexCoordinate(-1, 0, 1); // Northwest
        break;
      case LogicalKeyboardKey.keyW:
        direction = const HexCoordinate(0, -1, 1); // North
        break;
      case LogicalKeyboardKey.keyE:
        direction = const HexCoordinate(1, -1, 0); // Northeast
        break;
      case LogicalKeyboardKey.keyA:
        direction = const HexCoordinate(-1, 1, 0); // Southwest
        break;
      case LogicalKeyboardKey.keyS:
        direction = const HexCoordinate(0, 1, -1); // South
        break;
      case LogicalKeyboardKey.keyD:
        direction = const HexCoordinate(1, 0, -1); // Southeast
        break;
    }

    if (direction != null) {
      _moveUnitInDirection(selectedUnit, direction);
    }
  }

  void _moveUnitInDirection(SimpleGameUnit unit, HexCoordinate direction) {
    final gameState = gameEngine.gameState as ChexxGameState;
    final targetPosition = HexCoordinate(
      unit.position.q + direction.q,
      unit.position.r + direction.r,
      unit.position.s + direction.s,
    );

    // Check if target position is valid (no other unit there)
    bool isOccupied = false;
    for (final otherUnit in gameState.simpleUnits) {
      if (otherUnit.position == targetPosition) {
        isOccupied = true;
        break;
      }
    }

    if (!isOccupied && unit.remainingMovement > 0) {
      // Create updated unit with new position and reduced movement
      final updatedUnit = SimpleGameUnit(
        id: unit.id,
        unitType: unit.unitType,
        owner: unit.owner,
        position: targetPosition,
        health: unit.health,
        maxHealth: unit.maxHealth,
        remainingMovement: unit.remainingMovement - 1,
        isSelected: true,
      );

      // Replace unit in the list
      final index = gameState.simpleUnits.indexOf(unit);
      if (index != -1) {
        gameState.simpleUnits[index] = updatedUnit;
        gameEngine.notifyListeners();
      }
    }
  }

  Widget _buildGameUI() {
    final gameState = gameEngine.gameState as ChexxGameState;

    return Stack(
      children: [
        // Top UI
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildTopUI(gameState),
        ),

        // Bottom UI
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _buildBottomUI(gameState),
        ),

        // Right side unit info panel
        if (_getSelectedUnit(gameState) != null)
          Positioned(
            top: 80,
            right: 16,
            child: Column(
              children: [
                _buildUnitInfoPanel(_getSelectedUnit(gameState)!),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: _buildTileInfoPanel(_getSelectedUnit(gameState)!, gameState),
                ),
                if (gameState.shouldShowDiceRoll && gameState.lastDiceRolls != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: _buildDiceRollDisplay(gameState),
                  ),
              ],
            ),
          ),

        // Settings panel
        if (_showSettingsPanel)
          Positioned(
            top: 80,
            left: 16,
            child: _buildSettingsPanel(gameState),
          ),
      ],
    );
  }

  Widget _buildTopUI(ChexxGameState gameState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Current player indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: gameState.currentPlayer.name == 'player1'
                ? Colors.blue.shade600
                : Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${gameState.currentPlayer.name == 'player1' ? 'Player 1' : 'Player 2'} Turn',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),

        // Orientation toggle button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ElevatedButton.icon(
            onPressed: () {
              print('DEBUG: TOGGLE BUTTON PRESSED - UI Level');
              final gameState = gameEngine.gameState as ChexxGameState;
              gameState.toggleHexOrientation();
            },
            icon: Icon(
              (gameEngine.gameState as ChexxGameState).hexOrientation == HexOrientation.flat
                  ? Icons.hexagon_outlined
                  : Icons.change_history_outlined,
              size: 16,
            ),
            label: Text(
              (gameEngine.gameState as ChexxGameState).hexOrientation == HexOrientation.flat
                  ? 'Flat'
                  : 'Pointy',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: (gameEngine.gameState as ChexxGameState).hexOrientation == HexOrientation.flat
                  ? Colors.blue.shade600
                  : Colors.purple.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(80, 36),
            ),
          ),
        ),

        // Settings and Turn counter row
        Row(
          children: [
            // Settings icon
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => setState(() {
                  _showSettingsPanel = !_showSettingsPanel;
                }),
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                ),
              ),
            ),
            // Turn counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Turn ${gameState.turnNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomUI(ChexxGameState gameState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // End turn button
        ElevatedButton(
          onPressed: () => gameEngine.endTurn(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('End Turn'),
        ),

        // Reset game button
        ElevatedButton(
          onPressed: () => gameEngine.resetGame(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reset'),
        ),

        // Back button
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Menu'),
        ),
      ],
    );
  }

  SimpleGameUnit? _getSelectedUnit(ChexxGameState gameState) {
    for (final unit in gameState.simpleUnits) {
      if (unit.isSelected) {
        return unit;
      }
    }
    return null;
  }

  Widget _buildUnitInfoPanel(SimpleGameUnit unit) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unit.owner == Player.player1
            ? Colors.blue.shade900.withOpacity(0.9)
            : Colors.red.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unit.owner == Player.player1
              ? Colors.blue.shade400
              : Colors.red.shade400,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit Info',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Unit type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: unit.owner == Player.player1
                  ? Colors.blue.shade600
                  : Colors.red.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getUnitTypeName(unit.unitType),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Unit stats
          _buildStatRow('Health', '${unit.health}/${unit.maxHealth}', Icons.favorite),
          _buildStatRow('Movement', '${unit.remainingMovement}/${_getMovementRange(unit.unitType)}', Icons.directions_run),
          _buildStatRow('Attack Range', '${_getAttackRange(unit.unitType)}', Icons.gps_fixed),
          _buildStatRow('Attack Damage', '${_getAttackDamage(unit.unitType)}', Icons.flash_on),

          const SizedBox(height: 8),

          // Abilities section
          Text(
            'Abilities',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          ..._buildUnitAbilities(unit.unitType),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getUnitTypeName(String unitType) {
    switch (unitType.toLowerCase()) {
      // CHEXX unit types
      case 'minor': return 'Minor Unit';
      case 'scout': return 'Scout';
      case 'knight': return 'Knight';
      case 'guardian': return 'Guardian';
      // WWII unit types
      case 'infantry': return 'Infantry';
      case 'armor': return 'Armor';
      case 'artillery': return 'Artillery';
      default: return 'Unknown';
    }
  }

  int _getMovementRange(String unitType) {
    switch (unitType.toLowerCase()) {
      // CHEXX unit types
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      // WWII unit types
      case 'infantry': return 1;
      case 'armor': return 2;
      case 'artillery': return 1;
      default: return 1;
    }
  }

  int _getAttackRange(String unitType) {
    switch (unitType.toLowerCase()) {
      // CHEXX unit types
      case 'minor': return 1;
      case 'scout': return 3;
      case 'knight': return 2;
      case 'guardian': return 1;
      // WWII unit types
      case 'infantry': return 1;
      case 'armor': return 2;
      case 'artillery': return 3;
      default: return 1;
    }
  }

  int _getAttackDamage(String unitType) {
    switch (unitType.toLowerCase()) {
      // CHEXX unit types
      case 'minor': return 1;
      case 'scout': return 1;
      case 'knight': return 2;
      case 'guardian': return 1;
      // WWII unit types
      case 'infantry': return 1;
      case 'armor': return 2;
      case 'artillery': return 3;
      default: return 1;
    }
  }

  List<Widget> _buildUnitAbilities(String unitType) {
    switch (unitType.toLowerCase()) {
      // CHEXX unit types
      case 'scout':
        return [
          _buildAbilityCard('Long Range', 'Attack range +2'),
        ];
      case 'knight':
        return [
          _buildAbilityCard('Heavy Attack', 'Deals 2 damage'),
        ];
      case 'guardian':
        return [
          _buildAbilityCard('Defensive', 'High health unit'),
        ];
      case 'minor':
        return [
          _buildAbilityCard('Basic Unit', 'Standard combat'),
        ];
      // WWII unit types
      case 'infantry':
        return [
          _buildAbilityCard('Basic Infantry', 'Standard ground combat'),
        ];
      case 'armor':
        return [
          _buildAbilityCard('Armored Vehicle', 'High mobility and firepower'),
        ];
      case 'artillery':
        return [
          _buildAbilityCard('Long Range Fire', 'Extended attack range'),
        ];
      default:
        return [
          _buildAbilityCard('Unknown Unit', 'No special abilities'),
        ];
    }
  }

  Widget _buildAbilityCard(String name, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(ChexxGameState gameState) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade600,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Game Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _showSettingsPanel = false;
                }),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Game Type
          _buildSettingsSection('Game Type', [
            _buildSettingRow('Type', 'CHEXX'),
            _buildSettingRow('Mode', widget.scenarioConfig != null ? 'Scenario' : 'Standard'),
            _buildSettingRow('Combat System', 'WWII Dice-based'),
          ]),

          const SizedBox(height: 12),

          // Unit Types
          _buildSettingsSection('Available Unit Types', [
            _buildUnitTypeRow('Minor', 'Basic unit', '1 HP, 1 Move, 1 Attack'),
            _buildUnitTypeRow('Scout', 'Fast reconnaissance', '2 HP, 3 Move, 1 Attack, Range 3'),
            _buildUnitTypeRow('Knight', 'Heavy assault', '3 HP, 2 Move, 2 Attack'),
            _buildUnitTypeRow('Guardian', 'Defensive tank', '3 HP, 1 Move, 1 Attack'),
          ]),

          const SizedBox(height: 12),

          // Combat System
          _buildSettingsSection('Combat System', [
            _buildSettingRow('Type', 'WWII Dice-based'),
            _buildSettingRow('Die Faces', '6-sided (I/A/G/I/R/S)'),
            _buildSettingRow('Damage', 'Based on die roll results'),
            _buildSettingRow('Terrain', 'Affects combat effectiveness'),
          ]),

          const SizedBox(height: 12),

          // Current Game State
          _buildSettingsSection('Current Game', [
            _buildSettingRow('Turn', '${gameState.turnNumber}'),
            _buildSettingRow('Phase', gameState.turnPhase.toString().split('.').last),
            _buildSettingRow('Active Player', gameState.currentPlayer.name == 'player1' ? 'Player 1' : 'Player 2'),
            _buildSettingRow('Units P1', '${gameState.simpleUnits.where((u) => u.owner == Player.player1).length}'),
            _buildSettingRow('Units P2', '${gameState.simpleUnits.where((u) => u.owner == Player.player2).length}'),
          ]),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.yellow,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitTypeRow(String name, String description, String stats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          Text(
            stats,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceRollDisplay(ChexxGameState gameState) {
    final diceRolls = gameState.lastDiceRolls!;
    final result = gameState.lastCombatResult ?? '';

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.shade400,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dice Roll Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Dice display
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: diceRolls.asMap().entries.map((entry) {
              final index = entry.key;
              final die = entry.value;
              return _buildDiceWidget(die, index);
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Combat result
          if (result.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result,
                style: const TextStyle(
                  color: Colors.yellow,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Auto-clear timer indicator
          LinearProgressIndicator(
            value: gameState.shouldShowDiceRoll ? 1.0 -
              (DateTime.now().difference(gameState.lastCombatTime!).inMilliseconds / 5000.0) : 0.0,
            backgroundColor: Colors.grey.shade700,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade300),
            minHeight: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildDiceWidget(DieFace die, int index) {
    Color diceColor;
    switch (die.unitType) {
      case 'infantry':
        diceColor = Colors.green.shade600;
        break;
      case 'armor':
        diceColor = Colors.orange.shade600;
        break;
      case 'grenade':
        diceColor = Colors.red.shade600;
        break;
      case 'retreat':
        diceColor = Colors.grey.shade600;
        break;
      case 'star':
        diceColor = Colors.yellow.shade600;
        break;
      default:
        diceColor = Colors.blue.shade600;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: diceColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          die.symbol,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTileInfoPanel(SimpleGameUnit unit, ChexxGameState gameState) {
    // Convert core hex coordinate to src hex coordinate for board tile lookup
    final srcHexCoord = src_hex.HexCoordinate(unit.position.q, unit.position.r, unit.position.s);
    final tile = gameState.board.tiles[srcHexCoord];

    if (tile == null) {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade600, width: 2),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terrain,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Tile Info',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'No tile data',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    String tileTypeName = tile.type.name.substring(0, 1).toUpperCase() +
                         tile.type.name.substring(1);

    List<String> effectivenessModifiers = _getTileEffectivenessModifiers(tile.type);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade600, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.terrain,
                color: TileColors.getColorForTileType(tile.type),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Tile Info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const Text(
                'Type: ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                tileTypeName,
                style: TextStyle(
                  color: TileColors.getColorForTileType(tile.type),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (effectivenessModifiers.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Effects:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            ...effectivenessModifiers.map((modifier) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_right,
                    color: Colors.white54,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      modifier,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  List<String> _getTileEffectivenessModifiers(HexType tileType) {
    switch (tileType) {
      case HexType.forest:
        return [
          '+1 Defense vs ranged attacks',
          'Blocks line of sight',
          '-1 Movement penalty'
        ];
      case HexType.hill:
        return [
          '+1 Attack from elevation',
          '+1 Defense advantage',
          'Extended vision range'
        ];
      case HexType.ocean:
        return [
          'Impassable to ground units',
          'Naval units only'
        ];
      case HexType.beach:
        return [
          '+1 Movement from land',
          'Landing zone for naval'
        ];
      case HexType.town:
        return [
          '+2 Defense when occupied',
          'Healing +1 HP per turn',
          'Supply depot'
        ];
      case HexType.hedgerow:
        return [
          '+2 Defense vs frontal attacks',
          'Blocks movement',
          'Flanking vulnerable'
        ];
      case HexType.blocked:
        return [
          'Impassable terrain',
          'Blocks line of sight'
        ];
      case HexType.meta:
        return [
          'Special abilities enabled',
          'Strategic importance'
        ];
      case HexType.normal:
        return [
          'No special effects'
        ];
    }
  }
}
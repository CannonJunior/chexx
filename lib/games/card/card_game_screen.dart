import 'package:flutter/material.dart';
import 'package:f_card_engine/f_card_engine.dart' as f_card;
import '../chexx/screens/chexx_game_screen.dart';
import '../chexx/screens/chexx_game_engine.dart';
import '../chexx/models/chexx_game_state.dart';
import '../chexx/chexx_plugin.dart';
import '../../core/models/hex_coordinate.dart' as core_hex;
import '../../core/interfaces/unit_factory.dart';
import 'card_plugin.dart';
import 'card_game_state_adapter.dart';

/// Card game screen - Chexx game board with card UI overlay
class CardGameScreen extends StatefulWidget {
  final CardPlugin gamePlugin;
  final Map<String, dynamic>? scenarioConfig;

  const CardGameScreen({
    super.key,
    required this.gamePlugin,
    this.scenarioConfig,
  });

  @override
  State<CardGameScreen> createState() => _CardGameScreenState();
}

class _CardGameScreenState extends State<CardGameScreen> {
  late CardGameStateAdapter cardGameState;
  dynamic selectedCard; // Track selected card for info panel
  ChexxGameEngine? _chexxGameEngine; // Reference to the Chexx game engine

  // Card action state
  dynamic playedCard; // Card currently being played (showing actions)
  Set<int> completedActions = {}; // Track which actions are completed
  int? activeActionIndex; // Which action is currently being used
  Map<String, Map<String, dynamic>> unitOriginalValues = {}; // Store original unit values before applying special attributes
  bool allActionsComplete = false; // Track when all card actions are complete and turn is ready to end

  // Sub-step tracking
  Map<int, int> actionCurrentSubStep = {}; // Track current sub-step index for each action
  Map<int, Set<int>> actionCompletedSubSteps = {}; // Track completed sub-steps for each action

  @override
  void initState() {
    super.initState();
    print('=== CARD GAME SCREEN INIT ===');
    cardGameState = widget.gamePlugin.createGameState() as CardGameStateAdapter;

    // Initialize from scenario if provided, otherwise use defaults
    if (widget.scenarioConfig != null) {
      print('Initializing card game from scenario');
      cardGameState.initializeFromScenario(widget.scenarioConfig!);
    } else {
      print('No scenario config - starting with defaults');
      cardGameState.startGame(initialHandSize: 5);
    }

    print('Game started: ${cardGameState.gameStarted}');
    print('Players: ${cardGameState.players.length}');
    print('Current player: ${cardGameState.cardCurrentPlayer?.name}');
    print('Deck remaining: ${widget.gamePlugin.deckManager.cardsRemaining}');

    if (cardGameState.cardCurrentPlayer != null) {
      print('Current player hand: ${cardGameState.cardCurrentPlayer!.hand.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the regular Chexx game screen as the base
    // We use ChexxPlugin for the board, but add card UI on top
    return Stack(
      children: [
        // Chexx game board (same as other game modes)
        _CardModeChexxGameScreen(
          scenarioConfig: widget.scenarioConfig,
          onEngineCreated: (engine) => _chexxGameEngine = engine,
        ),

        // Card UI overlay on top - use individual Positioned widgets to avoid blocking
        // Top-right card info (deck counter and event log)
        Positioned(
          top: 60, // Below the Chexx game's top UI bar
          right: 8,
          child: SafeArea(
            child: _buildCardInfoBar(),
          ),
        ),

        // Right side panels (Card Info or Played Card)
        if (playedCard != null)
          Positioned(
            top: 120, // Below deck counter
            right: 8,
            child: SafeArea(
              child: _buildPlayedCardPanel(),
            ),
          )
        else if (selectedCard != null)
          Positioned(
            top: 120, // Below deck counter
            right: 8,
            child: SafeArea(
              child: _buildSelectedCardPanel(),
            ),
          ),

        // Bottom card hand bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _buildCardHandBar(),
          ),
        ),
      ],
    );
  }

  Widget _buildCardInfoBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Deck counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.purple.shade800.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                '${widget.gamePlugin.deckManager.cardsRemaining}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Event log button
        Container(
          decoration: BoxDecoration(
            color: Colors.purple.shade800.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 20),
            onPressed: _showEventLog,
            tooltip: 'Event Log',
          ),
        ),
      ],
    );
  }

  Widget _buildCardHandBar() {
    final currentPlayer = cardGameState.cardCurrentPlayer;

    return Container(
      height: 140, // Reduced from 180
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7), // More transparent
        border: Border(
          top: BorderSide(color: Colors.purple.shade700, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Player info (compact, vertical on left)
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentPlayer?.name ?? 'No player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentPlayer?.hand.length ?? 0} cards',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                // PLAY CARD button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCard != null ? () => _playCard(selectedCard) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('PLAY CARD', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 4),
                // END TURN button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _endTurn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: allActionsComplete ? Colors.orange : Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('END TURN', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),

          // Vertical divider
          Container(
            width: 2,
            color: Colors.purple.shade700,
          ),

          // Cards (horizontal scrolling)
          Expanded(
            child: _buildPlayerHand(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerHand() {
    final currentPlayer = cardGameState.cardCurrentPlayer;

    if (currentPlayer == null || currentPlayer.hand.isEmpty) {
      return const Center(
        child: Text(
          'No cards in hand',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: currentPlayer.hand.length,
      itemBuilder: (context, index) {
        final card = currentPlayer.hand[index];
        return _buildCardWidget(card);
      },
    );
  }

  Widget _buildCardWidget(dynamic card) {
    return Container(
      width: 85, // Reduced from 100
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade400, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onCardTapped(card),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.style,
                  color: Colors.purple.shade200,
                  size: 28, // Reduced from 32
                ),
                const SizedBox(height: 3),
                Text(
                  card.card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9, // Reduced from 10
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  card.card.type,
                  style: TextStyle(
                    color: Colors.purple.shade200,
                    fontSize: 7, // Reduced from 8
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onCardTapped(dynamic card) {
    setState(() {
      selectedCard = card;
    });
  }

  void _playCard(dynamic card) {
    // Play card to f-card engine (moves to inPlay zone and sets hasPlayedCardThisTurn flag)
    cardGameState.playCard(card, destination: f_card.CardZone.inPlay);

    // Clear all hex highlights when card is played
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
      chexxState.moveAndFireHexes.clear();
      chexxState.moveOnlyHexes.clear();
      chexxState.attackRangeHexes.clear();
      chexxState.highlightedHexes.clear();
      chexxState.activeCardActionHexTiles = null;
      chexxState.targetedEnemy = null;

      // Deselect all units
      for (final unit in chexxState.simpleUnits) {
        unit.isSelected = false;
      }

      _chexxGameEngine!.notifyListeners();
      print('Cleared all hex highlights after playing card');
    }

    setState(() {
      playedCard = card;
      completedActions.clear();
      activeActionIndex = null;
      selectedCard = null; // Clear selection
      allActionsComplete = false; // Reset for new card
    });
  }

  Widget _buildPlayedCardPanel() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade400, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CARD PLAYED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () {
                  // Cancel card - return it to hand
                  setState(() => playedCard = null);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.green),
          const SizedBox(height: 8),

          // Card name
          Text(
            playedCard.card.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Actions (clickable)
          if (playedCard.card.actions != null && playedCard.card.actions!.isNotEmpty) ...[
            const Text(
              'ACTIONS - Click to activate, click again to complete:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            ...(playedCard.card.actions!.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              final isCompleted = completedActions.contains(index);
              final isActive = activeActionIndex == index;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isCompleted ? null : () => _onActionTapped(index, action),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.yellow.shade900.withOpacity(0.5)
                                : isCompleted
                                    ? Colors.grey.shade800.withOpacity(0.5)
                                    : Colors.green.shade800.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive
                                  ? Colors.yellow
                                  : isCompleted
                                      ? Colors.grey
                                      : Colors.green,
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle : Icons.arrow_right,
                                color: isActive
                                    ? Colors.yellow
                                    : isCompleted
                                        ? Colors.grey
                                        : Colors.green,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${action['action_type']}: ${action['hex_restrictions']} (${action['hex_tiles']})',
                                  style: TextStyle(
                                    color: isCompleted ? Colors.grey : Colors.white70,
                                    fontSize: 9,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Show sub-steps when action is active or completed (to show progress)
                  if ((isActive || isCompleted) && action['sub_steps'] != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 24, bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (action['sub_steps'] as List).asMap().entries.map((subEntry) {
                          final subIndex = subEntry.key;
                          final subStep = subEntry.value;
                          final currentSubStep = actionCurrentSubStep[index] ?? 0;
                          final completedSubSteps = actionCompletedSubSteps[index] ?? {};
                          final isSubCompleted = completedSubSteps.contains(subIndex);
                          final isSubActive = currentSubStep == subIndex && !isSubCompleted;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  isSubCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                                  color: isSubActive
                                      ? Colors.yellow
                                      : isSubCompleted
                                          ? Colors.grey
                                          : Colors.white60,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    subStep.toString().replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                      color: isSubActive
                                          ? Colors.yellow
                                          : isSubCompleted
                                              ? Colors.grey
                                              : Colors.white60,
                                      fontSize: 8,
                                      fontWeight: isSubActive ? FontWeight.bold : FontWeight.normal,
                                      decoration: isSubCompleted ? TextDecoration.lineThrough : null,
                                      backgroundColor: isSubActive ? Colors.yellow.withOpacity(0.2) : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              );
            }).toList()),
          ],
        ],
      ),
    );
  }

  void _onActionTapped(int actionIndex, dynamic action) {
    // Don't allow re-clicking - actions only complete when units are ordered
    if (activeActionIndex == actionIndex) {
      print('Action already active - order units to complete it');
      return;
    }

    setState(() {
      activeActionIndex = actionIndex;
      // Initialize sub-step tracking for this action
      actionCurrentSubStep[actionIndex] = 0;
      actionCompletedSubSteps[actionIndex] = {};
    });

    // Apply special attributes from action (if any)
    _applySpecialAttributes(action);

    // Enable card action mode and highlight player's unit hexes
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
      chexxState.isCardActionActive = true;
      chexxState.isCardActionUnitLocked = false;
      chexxState.isWaitingForAfterCombatMovement = false;

      // Clear wayfinding highlights when action is clicked
      chexxState.moveAndFireHexes.clear();
      chexxState.moveOnlyHexes.clear();

      // Set up sub-step tracking callbacks
      chexxState.onUnitSelected = () {
        _advanceSubStep(actionIndex, 'unit_selection');
      };

      chexxState.onUnitMoved = () {
        // Check if movement was already completed
        final action = playedCard.card.actions![actionIndex];
        final subSteps = action['sub_steps'] as List?;
        if (subSteps != null) {
          final movementStepIndex = subSteps.indexWhere((step) => step == 'before_combat_movement');
          final completedSteps = actionCompletedSubSteps[actionIndex] ?? {};
          if (movementStepIndex != -1 && completedSteps.contains(movementStepIndex)) {
            print('Movement already completed - cannot move again before combat');
            return;
          }
        }

        _advanceSubStep(actionIndex, 'before_combat_movement');
        // Lock the unit after movement - combat must use same unit
        chexxState.isCardActionUnitLocked = true;
        // Clear wayfinding to prevent further movement before combat
        chexxState.moveAndFireHexes.clear();
        chexxState.moveOnlyHexes.clear();
        print('Unit locked after movement - combat must use same unit');
      };

      chexxState.onCombatOccurred = () {
        // If unit didn't move before combat, auto-complete movement sub-step
        final action = playedCard.card.actions![actionIndex];
        final subSteps = action['sub_steps'] as List?;
        if (subSteps != null) {
          final movementStepIndex = subSteps.indexWhere((step) => step == 'before_combat_movement');
          final completedSteps = actionCompletedSubSteps[actionIndex] ?? {};
          if (movementStepIndex != -1 && !completedSteps.contains(movementStepIndex)) {
            print('Unit attacked without moving - auto-completing before_combat_movement');
            _advanceSubStep(actionIndex, 'before_combat_movement');
            // Lock the unit - must use same unit for after-combat movement
            chexxState.isCardActionUnitLocked = true;
          }
        }
        _advanceSubStep(actionIndex, 'combat');
      };

      chexxState.onAfterCombatMovement = () {
        _advanceSubStep(actionIndex, 'after_combat_movement');
      };

      // Don't auto-complete action - let player complete it manually or when all sub-steps are done

      // Extract hex_tiles restriction from action
      final hexTiles = action['hex_tiles'] as String?;
      chexxState.activeCardActionHexTiles = hexTiles;

      // Get allowed hexes based on hex_tiles restriction
      final allowedHexes = (hexTiles != null && hexTiles != 'none')
          ? chexxState.getHexesForThird(hexTiles)
          : null;

      // Highlight hexes with current player's units (filtered by hex_tiles if applicable)
      final currentPlayer = chexxState.currentPlayer;
      final playerUnitHexes = <core_hex.HexCoordinate>{};

      for (final unit in chexxState.simpleUnits) {
        if (unit.owner == currentPlayer) {
          // If hex_tiles restriction exists, only add units in allowed hexes
          if (allowedHexes == null || allowedHexes.contains(unit.position)) {
            playerUnitHexes.add(unit.position);
          }
        }
      }

      chexxState.highlightedHexes = playerUnitHexes;
      print('HIGHLIGHT: Set ${playerUnitHexes.length} hexes to highlight');
      if (playerUnitHexes.isNotEmpty) {
        print('HIGHLIGHT: Sample hex: ${playerUnitHexes.first}');
      }
      print('HIGHLIGHT: Calling notifyListeners on Chexx engine');
      _chexxGameEngine!.notifyListeners();
      print('HIGHLIGHT: After notifyListeners');
    } else {
      print('DEBUG: ERROR - Chexx engine is null!');
    }

    print('Action ${actionIndex} selected: ${action}');
  }

  void _advanceSubStep(int actionIndex, String subStepName) {
    if (!mounted) return;

    setState(() {
      final action = playedCard.card.actions![actionIndex];
      final subSteps = action['sub_steps'] as List?;

      if (subSteps == null) return;

      // Find the index of this sub-step
      final subStepIndex = subSteps.indexWhere((step) => step == subStepName);

      if (subStepIndex == -1) {
        print('Sub-step $subStepName not found in action');
        return;
      }

      // Mark this sub-step as completed
      final completedSteps = actionCompletedSubSteps[actionIndex] ?? {};
      completedSteps.add(subStepIndex);
      actionCompletedSubSteps[actionIndex] = completedSteps;

      // Advance to next sub-step if there is one
      if (subStepIndex + 1 < subSteps.length) {
        actionCurrentSubStep[actionIndex] = subStepIndex + 1;
      }

      print('Sub-step completed: $subStepName (index $subStepIndex), next: ${actionCurrentSubStep[actionIndex]}');

      // Check if all sub-steps are complete
      if (completedSteps.length >= subSteps.length) {
        print('All sub-steps complete for action $actionIndex');
        _completeAction(actionIndex);
      }
    });
  }

  void _completeAction(int actionIndex) {
    // Restore original unit attributes
    _restoreOriginalAttributes();

    setState(() {
      completedActions.add(actionIndex);
      activeActionIndex = null;

      // Clear card action state in Chexx engine
      if (_chexxGameEngine != null) {
        final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
        chexxState.isCardActionActive = false;
        chexxState.highlightedHexes.clear();
        chexxState.activeCardActionHexTiles = null;
        chexxState.activeCardActionUnitId = null;
        chexxState.isCardActionUnitLocked = false;
        chexxState.isWaitingForAfterCombatMovement = false;
        // Clear sub-step callbacks
        chexxState.onUnitSelected = null;
        chexxState.onUnitMoved = null;
        chexxState.onCombatOccurred = null;
        chexxState.onAfterCombatMovement = null;
        _chexxGameEngine!.notifyListeners();
      }

      // Check if all actions are complete
      final totalActions = playedCard.card.actions?.length ?? 0;
      if (completedActions.length >= totalActions) {
        // All actions complete - mark as ready but keep card visible until END TURN
        allActionsComplete = true;
        print('All card actions complete - card will remain visible until END TURN');
      }
    });
  }

  void _applySpecialAttributes(dynamic action) {
    if (_chexxGameEngine == null) return;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
    final currentPlayer = chexxState.currentPlayer;

    // Check if action has special attributes
    final specialAttributes = action['special'];
    if (specialAttributes == null) return;

    print('Applying special attributes: $specialAttributes');

    // Store original values and apply special attributes to current player's units
    unitOriginalValues.clear();
    for (final unit in chexxState.simpleUnits) {
      if (unit.owner == currentPlayer) {
        // Store original move_after_combat value (default is unit's base value)
        final originalMoveAfterCombat = chexxState.unitMoveAfterCombatBonus[unit.id] ?? unit.moveAfterCombat;
        unitOriginalValues[unit.id] = {
          'move_after_combat': originalMoveAfterCombat,
        };

        // Apply special attributes
        if (specialAttributes['move_after_combat'] != null) {
          final bonusValue = specialAttributes['move_after_combat'] as int;
          chexxState.unitMoveAfterCombatBonus[unit.id] = unit.moveAfterCombat + bonusValue;
          print('Unit ${unit.id} (${unit.unitType}) move_after_combat: ${unit.moveAfterCombat} + $bonusValue = ${chexxState.unitMoveAfterCombatBonus[unit.id]}');
        }
      }
    }
  }

  void _restoreOriginalAttributes() {
    if (_chexxGameEngine == null || unitOriginalValues.isEmpty) return;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;

    print('Restoring original attributes for ${unitOriginalValues.length} units');

    // Restore or clear move_after_combat bonuses
    for (final unitId in unitOriginalValues.keys) {
      final originalValues = unitOriginalValues[unitId]!;
      final originalMoveAfterCombat = originalValues['move_after_combat'] as int;

      if (originalMoveAfterCombat == 0) {
        chexxState.unitMoveAfterCombatBonus.remove(unitId);
      } else {
        chexxState.unitMoveAfterCombatBonus[unitId] = originalMoveAfterCombat;
      }
    }

    unitOriginalValues.clear();
  }

  Widget _buildSelectedCardPanel() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade900.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade400, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CARD INFO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                onPressed: () => setState(() => selectedCard = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.purple),
          const SizedBox(height: 8),

          // Card name
          Text(
            selectedCard.card.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Card type
          Text(
            'Type: ${selectedCard.card.type}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),

          // Card description
          Text(
            selectedCard.card.description ?? 'No description',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),

          // Actions section (if available)
          if (selectedCard.card.actions != null && selectedCard.card.actions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.purple),
            const SizedBox(height: 8),
            const Text(
              'ACTIONS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            ...(selectedCard.card.actions!.map((action) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, color: Colors.purple, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${action['action_type']}: ${action['hex_restrictions']} (${action['hex_tiles']})',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ],
      ),
    );
  }

  void _endTurn() {
    // If there's a played card with incomplete actions, show error
    if (playedCard != null) {
      final totalActions = playedCard.card.actions?.length ?? 0;
      if (completedActions.length < totalActions) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complete all card actions (${completedActions.length}/$totalActions done)'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(top: 80, left: 20, right: 20),
          ),
        );
        return;
      }

      // Discard the completed card now
      cardGameState.moveCardFromPlay(playedCard, f_card.CardZone.discard);
      print('Card discarded: ${playedCard.card.name}');
    }

    // End turn in f-card engine (checks if card was played)
    final success = cardGameState.cardGameState.endTurn();
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Must play a card before ending turn'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(top: 80, left: 20, right: 20),
        ),
      );
      return;
    }

    // End turn in Chexx engine
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;

      // Clear all highlights when turn ends
      chexxState.moveAndFireHexes.clear();
      chexxState.moveOnlyHexes.clear();
      chexxState.attackRangeHexes.clear();

      _chexxGameEngine!.endTurn();
    }

    setState(() {
      selectedCard = null; // Clear selected card for next turn
      playedCard = null;
      completedActions.clear();
      allActionsComplete = false; // Reset button color for next turn
      activeActionIndex = null;
    });
  }

  void _showEventLog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Event Log',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          height: 500,
          child: cardGameState.eventLog.isEmpty
              ? const Center(
                  child: Text(
                    'No events yet',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.builder(
                  itemCount: cardGameState.eventLog.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final event = cardGameState.eventLog.reversed.elementAt(index);
                    return ListTile(
                      dense: true,
                      leading: _getEventIcon(event['type'] as String),
                      title: Text(
                        event['type'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        event['timestamp'] as String,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Icon _getEventIcon(String eventType) {
    switch (eventType) {
      case 'card_played':
        return const Icon(Icons.add_card, color: Colors.blue);
      case 'cards_drawn':
        return const Icon(Icons.arrow_downward, color: Colors.green);
      case 'turn_ended':
        return const Icon(Icons.refresh, color: Colors.orange);
      case 'game_started':
        return const Icon(Icons.play_arrow, color: Colors.green);
      default:
        return const Icon(Icons.circle, color: Colors.grey);
    }
  }
}

/// Wrapper for ChexxGameScreen that exposes the game engine
class _CardModeChexxGameScreen extends StatefulWidget {
  final Map<String, dynamic>? scenarioConfig;
  final Function(ChexxGameEngine) onEngineCreated;

  const _CardModeChexxGameScreen({
    this.scenarioConfig,
    required this.onEngineCreated,
  });

  @override
  State<_CardModeChexxGameScreen> createState() => _CardModeChexxGameScreenState();
}

class _CardModeChexxGameScreenState extends State<_CardModeChexxGameScreen> {
  late ChexxGameEngine gameEngine;

  @override
  void initState() {
    super.initState();
    gameEngine = ChexxGameEngine(
      gamePlugin: ChexxPlugin(),
      scenarioConfig: widget.scenarioConfig,
    );
    widget.onEngineCreated(gameEngine); // Pass engine to parent
  }

  @override
  void dispose() {
    gameEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use ChexxGameScreen with the existing engine
    return ChexxGameScreen(
      scenarioConfig: widget.scenarioConfig,
      gamePlugin: ChexxPlugin(),
      existingEngine: gameEngine,
    );
  }
}

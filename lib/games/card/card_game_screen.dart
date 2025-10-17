import 'package:flutter/material.dart';
import 'package:f_card_engine/f_card_engine.dart' as f_card;
import '../chexx/screens/chexx_game_screen.dart';
import '../chexx/screens/chexx_game_engine.dart';
import '../chexx/models/chexx_game_state.dart';
import '../chexx/chexx_plugin.dart';
import '../../core/models/hex_coordinate.dart' as core_hex;
import '../../core/interfaces/unit_factory.dart';
import '../../src/models/scenario_builder_state.dart';
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
  List<Map<String, dynamic>>? generatedActions; // Store dynamically generated actions separate from the card
  Set<int> completedActions = {}; // Track which actions are completed
  int? activeActionIndex; // Which action is currently being used
  Map<String, Map<String, dynamic>> unitOriginalValues = {}; // Store original unit values before applying special attributes
  bool allActionsComplete = false; // Track when all card actions are complete and turn is ready to end

  // Sub-step tracking
  Map<int, int> actionCurrentSubStep = {}; // Track current sub-step index for each action
  Map<int, Set<int>> actionCompletedSubSteps = {}; // Track completed sub-steps for each action
  Map<int, Set<int>> actionCancelledSubSteps = {}; // Track cancelled sub-steps for each action

  // Unit usage tracking per card
  Set<String> usedUnitIds = {}; // Track units that have been used for actions on the current card

  // Air strike cluster tracking (for Air Power card)
  Set<core_hex.HexCoordinate> airStrikeCluster = {}; // Track targeted enemy unit positions

  // Section selection for cards like Infantry Assault
  bool isWaitingForSectionSelection = false;
  String? selectedSection; // 'left third', 'middle third', or 'right third'

  // Card choice for Recon card (card_23)
  bool isWaitingForCardChoice = false; // True when showing two cards to choose from
  List<dynamic> cardChoices = []; // The two cards to choose from

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

  /// Helper method to get the current actions for the played card
  /// Returns either the generated actions or the card's default actions
  List<Map<String, dynamic>>? _getCurrentActions() {
    if (generatedActions != null) {
      return generatedActions;
    }
    if (playedCard != null && playedCard.card.actions != null) {
      return List<Map<String, dynamic>>.from(playedCard.card.actions!);
    }
    return null;
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

        // Card choice dialog (for Recon card effect)
        if (isWaitingForCardChoice)
          Positioned.fill(
            child: _buildCardChoiceDialog(),
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
                    onPressed: _canPlaySelectedCard() ? () => _playCard(selectedCard) : null,
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

  bool _canPlaySelectedCard() {
    if (selectedCard == null) return false;

    // Check if the card is reactive (can only be played as a reaction)
    final isReactive = selectedCard.card.reactive;

    if (isReactive) {
      // Reactive cards cannot be played during the player's own turn
      // They can only be played as reactions during opponent's turn
      print('Card ${selectedCard.card.name} is reactive - cannot be played on player\'s own turn');
      return false;
    }

    return true;
  }

  void _selectSection(String section) {
    if (_chexxGameEngine == null || playedCard == null) return;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
    final currentPlayer = chexxState.currentPlayer;
    final templateAction = _getCurrentActions()![0];

    print('Section selected: $section');

    // Update the template action's hex_tiles to the selected section
    templateAction['hex_tiles'] = section;

    // Get matching units for this section
    final unitRestriction = templateAction['unit_restrictions'];
    List<SimpleGameUnit> matchingUnits = chexxState.getUnitsMatchingRestriction(unitRestriction, currentPlayer);
    print('Found ${matchingUnits.length} units matching restriction: $unitRestriction');

    // Filter by selected section
    final allowedHexes = chexxState.getHexesForThird(section);
    matchingUnits = matchingUnits.where((unit) => allowedHexes.contains(unit.position)).toList();
    print('Filtered to ${matchingUnits.length} units in $section');

    if (matchingUnits.isNotEmpty) {
      // Generate one action per matching unit
      final actions = matchingUnits.map((unit) {
        final actionCopy = Map<String, dynamic>.from(templateAction);
        actionCopy['generated_for_unit_id'] = unit.id;
        actionCopy['unit_restrictions'] = unit.unitType;
        print('Generated action for unit ${unit.id} (${unit.unitType})');
        return actionCopy;
      }).toList();

      generatedActions = actions;
      print('Generated ${actions.length} actions from section $section');
    } else {
      // No matching units in this section - use fallback action
      print('No matching units in $section - using fallback');
      final hasAnyUnits = chexxState.simpleUnits.any((unit) => unit.owner == currentPlayer);
      if (hasAnyUnits) {
        generatedActions = [
          {
            'action_type': 'order',
            'name': 'Select Unit',
            'unit_restrictions': 'none',
            'hex_tiles': 'all',
            'sub_steps': ['unit_selection', 'before_combat_movement', 'combat'],
          }
        ];
        print('Created fallback action for section with no matching units');
      }
    }

    setState(() {
      isWaitingForSectionSelection = false;
      selectedSection = section;
    });
  }

  void _playCard(dynamic card) {
    // Play card to f-card engine (moves to inPlay zone and sets hasPlayedCardThisTurn flag)
    cardGameState.playCard(card, destination: f_card.CardZone.inPlay);

    // DO NOT clear hex highlights here - they will be set when action is clicked
    // Highlights are managed by _onActionTapped() and _completeAction()
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;

      // Only deselect units, but don't clear highlights
      // This allows the action system to properly highlight hexes when actions are clicked
      for (final unit in chexxState.simpleUnits) {
        unit.isSelected = false;
      }

      _chexxGameEngine!.notifyListeners();
      print('Card played - highlights will be set when action is clicked');

      // First, check if the card's actions have any valid units
      // This applies to ALL cards, not just "type": "all"
      bool anyActionHasUnits = false;
      if (card.card.actions != null && card.card.actions!.isNotEmpty) {
        for (int i = 0; i < card.card.actions!.length; i++) {
          if (_actionHasValidUnitsForNewCard(card.card.actions![i])) {
            anyActionHasUnits = true;
            break;
          }
        }
      }

      // If no actions have valid units, replace with a fallback action
      if (!anyActionHasUnits) {
        print('No valid units for card actions - checking if player has any units');
        final currentPlayer = chexxState.currentPlayer;
        final hasAnyUnits = chexxState.simpleUnits.any((unit) => unit.owner == currentPlayer);

        if (hasAnyUnits) {
          // Replace card actions with a single fallback action that works with any unit
          generatedActions = [
            {
              'action_type': 'order',
              'name': 'Select Unit',
              'unit_restrictions': 'none',
              'hex_tiles': 'all',
              'sub_steps': ['unit_selection', 'before_combat_movement', 'combat'],
            }
          ];
          print('Replaced card actions with fallback action (player has ${chexxState.simpleUnits.where((u) => u.owner == currentPlayer).length} units)');
          anyActionHasUnits = true; // Mark as having valid actions now
        }
      } else {
        // Check if this is Infantry Assault card (needs section selection)
        if (card.card.name == 'Infantry Assault') {
          print('Infantry Assault card detected - enabling section selection');
          setState(() {
            playedCard = card;
            isWaitingForSectionSelection = true;
            completedActions.clear();
            actionCurrentSubStep.clear();
            actionCompletedSubSteps.clear();
            actionCancelledSubSteps.clear();
            usedUnitIds.clear();
            activeActionIndex = null;
            selectedCard = null;
            allActionsComplete = false;
          });
          return; // Don't process actions yet - wait for section selection
        }

        // Card has valid units - check if it's a "type": "all" card that needs per-unit action generation
        if (card.card.type == 'all' && card.card.actions != null && card.card.actions!.isNotEmpty) {
          print('Card has type "all" - generating actions for each matching unit');
          final currentPlayer = chexxState.currentPlayer;
          final templateAction = card.card.actions![0]; // Use first action as template
          final unitRestriction = templateAction['unit_restrictions']; // Can be String or List
          final hexTiles = templateAction['hex_tiles'] as String?;

          // Get all matching units for this player
          List<SimpleGameUnit> matchingUnits = chexxState.getUnitsMatchingRestriction(unitRestriction, currentPlayer);
          print('Found ${matchingUnits.length} units matching restriction: $unitRestriction');

          // If hex_tiles has a location restriction, filter the matching units
          if (hexTiles != null) {
            if (hexTiles.toLowerCase() == 'adjacent to enemy units') {
              final adjacentHexes = chexxState.getHexesAdjacentToEnemyUnits();
              matchingUnits = matchingUnits.where((unit) => adjacentHexes.contains(unit.position)).toList();
              print('Filtered to ${matchingUnits.length} units adjacent to enemy units');
            } else if (hexTiles.toLowerCase() == 'not adjacent') {
              final notAdjacentHexes = chexxState.getHexesNotAdjacentToEnemyUnits();
              matchingUnits = matchingUnits.where((unit) => notAdjacentHexes.contains(unit.position)).toList();
              print('Filtered to ${matchingUnits.length} units not adjacent to enemy units');
            }
          }

          if (matchingUnits.isNotEmpty) {
            // Generate one action per matching unit
            final actions = matchingUnits.map((unit) {
              // Clone the template action and set unit-specific restrictions
              final actionCopy = Map<String, dynamic>.from(templateAction);
              actionCopy['generated_for_unit_id'] = unit.id; // Track which unit this action is for
              actionCopy['unit_restrictions'] = unit.unitType; // Lock to this specific unit type
              print('Generated action for unit ${unit.id} (${unit.unitType})');
              return actionCopy;
            }).toList();

            generatedActions = actions;
            print('Generated ${actions.length} actions from "all" type card');
          } else {
            // No matching units after filtering - use fallback action
            print('No matching units after filtering for "all" type card - using fallback');
            final hasAnyUnits = chexxState.simpleUnits.any((unit) => unit.owner == currentPlayer);
            if (hasAnyUnits) {
              generatedActions = [
                {
                  'action_type': 'order',
                  'name': 'Select Unit',
                  'unit_restrictions': 'none',
                  'hex_tiles': 'all',
                  'sub_steps': ['unit_selection', 'before_combat_movement', 'combat'],
                }
              ];
              print('Created fallback action for "all" type card with no matching units');
            }
          }
        }
      }
    }

    setState(() {
      playedCard = card;
      generatedActions = null; // Clear generated actions for new card
      completedActions.clear();
      actionCurrentSubStep.clear();
      actionCompletedSubSteps.clear();
      actionCancelledSubSteps.clear();
      usedUnitIds.clear(); // Clear unit usage tracking for new card
      airStrikeCluster.clear(); // Clear air strike cluster for new card
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

          // Section selection (for cards like Infantry Assault)
          if (isWaitingForSectionSelection) ...[
            const Text(
              'SELECT SECTION:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectSection('left third'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('LEFT', style: TextStyle(fontSize: 9)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectSection('middle third'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('MIDDLE', style: TextStyle(fontSize: 9)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectSection('right third'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('RIGHT', style: TextStyle(fontSize: 9)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Actions (clickable)
          if (_getCurrentActions() != null && _getCurrentActions()!.isNotEmpty && !isWaitingForSectionSelection) ...[
            const Text(
              'ACTIONS - Click to activate, click again to complete:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            ...(_getCurrentActions()!.asMap().entries.map((entry) {
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
                                  '${action['name'] ?? action['action_type']}: ${action['unit_restrictions'] ?? 'all'} (${action['hex_tiles'] ?? 'all'})',
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
                          final cancelledSubSteps = actionCancelledSubSteps[index] ?? {};
                          final isSubCompleted = completedSubSteps.contains(subIndex);
                          final isSubCancelled = cancelledSubSteps.contains(subIndex);
                          final isSubActive = currentSubStep == subIndex && !isSubCompleted && !isSubCancelled;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  isSubCompleted
                                      ? Icons.check_box
                                      : isSubCancelled
                                          ? Icons.cancel
                                          : Icons.check_box_outline_blank,
                                  color: isSubActive
                                      ? Colors.yellow
                                      : isSubCompleted
                                          ? Colors.grey
                                          : isSubCancelled
                                              ? Colors.red.shade400
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
                                              : isSubCancelled
                                                  ? Colors.red.shade400
                                                  : Colors.white60,
                                      fontSize: 8,
                                      fontWeight: isSubActive ? FontWeight.bold : FontWeight.normal,
                                      decoration: (isSubCompleted || isSubCancelled) ? TextDecoration.lineThrough : null,
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
                  // Barbwire decision buttons (shown after BEFORE COMBAT MOVEMENT when waiting for decision)
                  if (isActive && _chexxGameEngine != null) ...[
                    Builder(
                      builder: (context) {
                        final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
                        if (chexxState.isWaitingForBarbwireDecision) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
                            child: Row(
                              children: [
                                // Remove Barbwire button
                                SizedBox(
                                  height: 20,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (chexxState.onBarbwireRemove != null) {
                                        chexxState.onBarbwireRemove!();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      minimumSize: const Size(0, 20),
                                    ),
                                    child: const Text('Remove Barbwire', style: TextStyle(fontSize: 9)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Keep Barbwire button
                                SizedBox(
                                  height: 20,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (chexxState.onBarbwireKeep != null) {
                                        chexxState.onBarbwireKeep!();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      minimumSize: const Size(0, 20),
                                    ),
                                    child: const Text('Keep Barbwire', style: TextStyle(fontSize: 9)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
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

    // Check if this is a "barrage" action (direct combat without unit selection)
    final actionType = action['action_type'] as String?;
    if (actionType == 'barrage') {
      _handleBarrageAction(actionIndex, action);
      return;
    }

    // Check if this is a "heal" action (healing damaged units)
    if (actionType == 'heal') {
      _handleHealAction(actionIndex, action);
      return;
    }

    // Check if this is a "their_finest_hour" action (roll dice to generate unit orders)
    if (actionType == 'their_finest_hour') {
      _handleTheirFinestHourAction(actionIndex, action);
      return;
    }

    // Check if this is an "air_strike" action (target adjacent cluster of enemy units)
    if (actionType == 'air_strike') {
      _handleAirStrikeAction(actionIndex, action);
      return;
    }

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
        // Get the action first
        final currentAction = _getCurrentActions()![actionIndex];

        // Track that this unit has been used for an action on this card
        if (chexxState.activeCardActionUnitId != null) {
          usedUnitIds.add(chexxState.activeCardActionUnitId!);
          print('Unit ${chexxState.activeCardActionUnitId} added to used units: $usedUnitIds');

          // Apply card overrides to the selected unit
          final success = chexxState.applyCardEffectsToUnit(chexxState.activeCardActionUnitId!, currentAction);
          if (success) {
            print('Successfully applied card overrides to unit ${chexxState.activeCardActionUnitId}');
          } else {
            print('WARNING: Failed to apply card overrides to unit ${chexxState.activeCardActionUnitId}');
          }
        }
        _advanceSubStep(actionIndex, 'unit_selection');

        // Check if this is a Dig-In action (has place_sandbag but no movement)
        final subSteps = currentAction['sub_steps'] as List?;
        if (subSteps != null) {
          final hasPlaceSandbag = subSteps.contains('place_sandbag');
          final hasMovement = subSteps.contains('before_combat_movement');

          if (hasPlaceSandbag && !hasMovement) {
            // This is Dig-In - unit doesn't move, just waits for combat or auto-places sandbag
            print('Dig-In action detected - unit selected, waiting for combat or will auto-place sandbag');
          }
        }
      };

      chexxState.onUnitMoved = () {
        // Check if movement was already completed
        final action = _getCurrentActions()![actionIndex];
        final subSteps = action['sub_steps'] as List?;
        if (subSteps != null) {
          final movementStepIndex = subSteps.indexWhere((step) => step == 'before_combat_movement');
          final completedSteps = actionCompletedSubSteps[actionIndex] ?? {};
          if (movementStepIndex != -1 && completedSteps.contains(movementStepIndex)) {
            print('Movement already completed - cannot move again before combat');
            return;
          }
        }

        // Check if unit moved onto barbwire
        final selectedUnit = chexxState.simpleUnits.firstWhere(
          (u) => u.isSelected,
          orElse: () => throw Exception('No selected unit'),
        );

        bool onBarbwire = false;
        GameStructure? barbwireStructure;
        for (final structure in chexxState.placedStructures) {
          if (structure.position.q == selectedUnit.position.q &&
              structure.position.r == selectedUnit.position.r &&
              structure.position.s == selectedUnit.position.s) {
            final structureType = structure.type.name.toLowerCase();
            if (structureType == 'barbwire' || structureType == 'barbed_wire') {
              onBarbwire = true;
              barbwireStructure = structure;
              break;
            }
          }
        }

        if (onBarbwire && barbwireStructure != null) {
          // Unit moved onto barbwire - set up decision callbacks
          chexxState.isWaitingForBarbwireDecision = true;
          chexxState.barbwireDecisionHex = selectedUnit.position;

          chexxState.onBarbwireRemove = () {
            _handleBarbwireRemove(actionIndex, selectedUnit, barbwireStructure!);
          };

          chexxState.onBarbwireKeep = () {
            _handleBarbwireKeep(actionIndex);
          };

          setState(() {}); // Refresh UI to show buttons
          print('Unit on barbwire - waiting for decision');
        } else {
          // Normal movement completion
          _advanceSubStep(actionIndex, 'before_combat_movement');

          // Check if this was a move-only movement (beyond move_and_fire range)
          if (chexxState.lastMoveWasMoveOnly) {
            // Unit moved beyond fire range - auto-complete combat and after-combat movement
            print('Move-only movement detected - auto-completing combat and after-combat movement');
            _advanceSubStep(actionIndex, 'combat');
            _advanceSubStep(actionIndex, 'after_combat_movement');
          } else {
            // Unit moved within fire range - check if there are any enemies in attack range
            chexxState.calculateAttackRange(selectedUnit);
            final hasEnemiesInRange = chexxState.attackRangeHexes.isNotEmpty;

            if (!hasEnemiesInRange) {
              // No enemies in range - auto-complete combat substep
              print('No enemies in attack range - auto-completing combat substep');
              _advanceSubStep(actionIndex, 'combat');

              // Check if we should auto-complete after-combat movement
              final moveAfterCombatBonus = action['move_after_combat'] as int? ?? 0;
              if (moveAfterCombatBonus == 0 && selectedUnit.moveAfterCombat == 0) {
                // No special movement values - auto-complete after-combat movement
                print('No after-combat movement - auto-completing after_combat_movement substep');
                _advanceSubStep(actionIndex, 'after_combat_movement');
              }
            } else {
              // Lock the unit after movement - combat must use same unit
              chexxState.isCardActionUnitLocked = true;
              // Clear wayfinding to prevent further movement before combat
              chexxState.moveAndFireHexes.clear();
              chexxState.moveOnlyHexes.clear();
              print('Unit locked after movement - combat must use same unit');
            }
          }
        }
      };

      chexxState.onCombatOccurred = () {
        // If unit didn't move before combat, auto-complete movement sub-step
        final action = _getCurrentActions()![actionIndex];
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

        // Check if there's a place_sandbag sub-step
        if (subSteps != null) {
          final sandbagStepIndex = subSteps.indexWhere((step) => step == 'place_sandbag');
          if (sandbagStepIndex != -1) {
            // Auto-place sandbag on the selected unit's hex
            final selectedUnit = chexxState.simpleUnits.firstWhere(
              (u) => u.isSelected,
              orElse: () => throw Exception('No selected unit'),
            );
            _placeSandbagOnUnit(selectedUnit);
            _advanceSubStep(actionIndex, 'place_sandbag');
            return; // Don't check for after-combat movement
          }
        }

        // Check if we should auto-complete after-combat movement
        final selectedUnit = chexxState.simpleUnits.firstWhere(
          (u) => u.isSelected,
          orElse: () => throw Exception('No selected unit'),
        );
        final moveAfterCombatBonus = action['move_after_combat'] as int? ?? 0;
        if (moveAfterCombatBonus == 0 && selectedUnit.moveAfterCombat == 0) {
          // No special movement values - auto-complete after-combat movement
          print('No after-combat movement available - auto-completing after_combat_movement substep');
          _advanceSubStep(actionIndex, 'after_combat_movement');
        }
      };

      chexxState.onAfterCombatMovement = () {
        _advanceSubStep(actionIndex, 'after_combat_movement');
      };

      // Don't auto-complete action - let player complete it manually or when all sub-steps are done

      // Extract hex_tiles restriction from action
      final hexTiles = action['hex_tiles'] as String?;
      chexxState.activeCardActionHexTiles = hexTiles;

      // Get allowed hexes based on hex_tiles restriction
      // If hex_tiles is "all", "none", or null, no filtering is applied
      Set<core_hex.HexCoordinate>? allowedHexes;
      if (hexTiles != null && hexTiles != 'none' && hexTiles != 'all') {
        // Handle special location restrictions
        if (hexTiles.toLowerCase() == 'not adjacent') {
          allowedHexes = chexxState.getHexesNotAdjacentToEnemyUnits();
          print('DEBUG HIGHLIGHT: Using not adjacent hexes: ${allowedHexes.length} hexes');
        } else if (hexTiles.toLowerCase() == 'adjacent to enemy units') {
          allowedHexes = chexxState.getHexesAdjacentToEnemyUnits();
          print('DEBUG HIGHLIGHT: Using adjacent to enemy hexes: ${allowedHexes.length} hexes');
        } else {
          // Handle board section restrictions (left third, middle third, right third)
          allowedHexes = chexxState.getHexesForThird(hexTiles);
          print('DEBUG HIGHLIGHT: Using third section "$hexTiles": ${allowedHexes.length} hexes');
        }
      }

      // Highlight hexes with current player's units (filtered by hex_tiles and unit_restrictions)
      final currentPlayer = chexxState.currentPlayer;
      final playerUnitHexes = <core_hex.HexCoordinate>{};

      print('DEBUG HIGHLIGHT: Current player: ${currentPlayer.name}');
      print('DEBUG HIGHLIGHT: Total units in game: ${chexxState.simpleUnits.length}');
      print('DEBUG HIGHLIGHT: Used unit IDs: $usedUnitIds');
      print('DEBUG HIGHLIGHT: hex_tiles restriction: $hexTiles');
      print('DEBUG HIGHLIGHT: Allowed hexes count: ${allowedHexes?.length ?? "null (no restriction)"}');

      // Check if this action was generated for a specific unit
      final generatedForUnitId = action['generated_for_unit_id'] as String?;
      if (generatedForUnitId != null) {
        print('DEBUG HIGHLIGHT: Action generated for specific unit: $generatedForUnitId');
        // Only highlight the specific unit this action was generated for
        final targetUnit = chexxState.simpleUnits.firstWhere(
          (u) => u.id == generatedForUnitId,
          orElse: () => throw Exception('Generated unit not found: $generatedForUnitId'),
        );
        if (targetUnit.owner == currentPlayer && !usedUnitIds.contains(targetUnit.id)) {
          playerUnitHexes.add(targetUnit.position);
          print('  - ADDED specific unit ${targetUnit.id} to highlights');
        } else {
          print('  - SKIPPED: Unit already used or not owned by current player');
        }
      } else {
        // Get unit_restrictions from action (can be String or List<String>)
        final unitRestriction = action['unit_restrictions']; // Can be String or List
        print('DEBUG HIGHLIGHT: unit_restrictions: ${unitRestriction ?? "none"}');

        int totalPlayerUnits = 0;
        int skippedBecauseUsed = 0;
        int skippedBecauseUnitRestriction = 0;
        int skippedBecauseHexTiles = 0;
        int added = 0;

        for (final unit in chexxState.simpleUnits) {
          if (unit.owner == currentPlayer) {
            totalPlayerUnits++;
            print('DEBUG HIGHLIGHT: Checking unit ${unit.id} (${unit.unitType}) at ${unit.position}, remainingMovement=${unit.remainingMovement}');

            // Skip units that have already been used for an action on this card
            if (usedUnitIds.contains(unit.id)) {
              skippedBecauseUsed++;
              print('  - SKIPPED: Already used');
              continue;
            }

            // Check unit_restrictions filter (supports both String and List<String>)
            bool passesUnitRestriction = true;
            if (unitRestriction != null) {
              if (unitRestriction is String) {
                // Handle String format
                if (unitRestriction.isNotEmpty && unitRestriction.toLowerCase() != 'all') {
                  final restrictionLower = unitRestriction.toLowerCase();
                  final unitTypeLower = unit.unitType.toLowerCase();

                  // Special case: "damaged" means health < maxHealth
                  if (restrictionLower == 'damaged') {
                    if (unit.health >= unit.maxHealth) {
                      passesUnitRestriction = false;
                    }
                  } else if (!unitTypeLower.contains(restrictionLower)) {
                    passesUnitRestriction = false;
                  }
                }
              } else if (unitRestriction is List) {
                // Handle List<String> format
                final restrictionList = unitRestriction.cast<String>();
                if (restrictionList.isNotEmpty) {
                  final restrictionsLower = restrictionList.map((r) => r.toLowerCase()).toList();
                  final unitTypeLower = unit.unitType.toLowerCase();
                  // Check if unit type matches ANY restriction in the list
                  if (!restrictionsLower.any((r) => r != 'all' && unitTypeLower.contains(r))) {
                    passesUnitRestriction = false;
                  }
                }
              }
            }

            if (!passesUnitRestriction) {
              skippedBecauseUnitRestriction++;
              print('  - SKIPPED: Unit type "${unit.unitType}" does not match restriction "$unitRestriction"');
              continue;
            }

            // If hex_tiles restriction exists, only add units in allowed hexes
            if (allowedHexes == null || allowedHexes.contains(unit.position)) {
              playerUnitHexes.add(unit.position);
              added++;
              print('  - ADDED to highlights');
            } else {
              skippedBecauseHexTiles++;
              print('  - SKIPPED: Not in allowed hex_tiles area');
            }
          }
        }

        print('DEBUG HIGHLIGHT SUMMARY:');
        print('  - Total ${currentPlayer.name} units: $totalPlayerUnits');
        print('  - Skipped (already used): $skippedBecauseUsed');
        print('  - Skipped (unit restriction): $skippedBecauseUnitRestriction');
        print('  - Skipped (hex_tiles): $skippedBecauseHexTiles');
        print('  - Added to highlights: $added');
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

  void _handleBarrageAction(int actionIndex, dynamic action) {
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
      chexxState.isCardActionActive = true;

      print('Barrage action activated - highlighting all enemy units');

      // Store barrage action metadata for combat system to use
      chexxState.activeBarrageAction = action;

      // Get the current player and enemy player
      final currentPlayer = chexxState.currentPlayer;
      final enemyPlayer = currentPlayer == Player.player1 ? Player.player2 : Player.player1;

      // Barrage doesn't require unit selection - skip that sub-step if it exists
      final subSteps = action['sub_steps'] as List?;
      if (subSteps != null) {
        final unitSelectionIndex = subSteps.indexWhere((step) => step == 'unit_selection');
        if (unitSelectionIndex != -1) {
          print('Auto-completing unit_selection sub-step for barrage (not required)');
          _advanceSubStep(actionIndex, 'unit_selection');
        }
      }

      // Highlight ALL enemy units (no range restriction for barrage)
      final enemyUnitHexes = chexxState.simpleUnits
          .where((u) => u.owner == enemyPlayer)
          .map((u) => u.position)
          .toSet();

      chexxState.highlightedHexes = enemyUnitHexes;
      print('Highlighted ${enemyUnitHexes.length} enemy hexes for barrage attack');

      // Set up combat callback for when enemy is clicked
      chexxState.onCombatOccurred = () {
        print('Barrage combat occurred - completing action');
        _advanceSubStep(actionIndex, 'combat');
      };

      _chexxGameEngine!.notifyListeners();
    }
  }

  void _handleHealAction(int actionIndex, dynamic action) {
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
      chexxState.isCardActionActive = true;
      chexxState.isCardActionUnitLocked = false;

      print('Heal action activated - highlighting damaged units');

      // Get hex_tiles restriction from action
      final hexTiles = action['hex_tiles'] as String?;
      chexxState.activeCardActionHexTiles = hexTiles;

      // Get allowed hexes based on hex_tiles restriction
      Set<core_hex.HexCoordinate>? allowedHexes;
      if (hexTiles != null && hexTiles != 'none' && hexTiles != 'all') {
        if (hexTiles.toLowerCase() == 'not adjacent') {
          allowedHexes = chexxState.getHexesNotAdjacentToEnemyUnits();
        } else if (hexTiles.toLowerCase() == 'adjacent to enemy units') {
          allowedHexes = chexxState.getHexesAdjacentToEnemyUnits();
        } else {
          allowedHexes = chexxState.getHexesForThird(hexTiles);
        }
      }

      // Highlight damaged units
      final currentPlayer = chexxState.currentPlayer;
      final damagedUnitHexes = <core_hex.HexCoordinate>{};

      for (final unit in chexxState.simpleUnits) {
        if (unit.owner == currentPlayer && unit.health < unit.maxHealth) {
          // Skip units already used
          if (usedUnitIds.contains(unit.id)) {
            continue;
          }

          // Check hex restriction
          if (allowedHexes == null || allowedHexes.contains(unit.position)) {
            damagedUnitHexes.add(unit.position);
          }
        }
      }

      chexxState.highlightedHexes = damagedUnitHexes;
      print('Highlighted ${damagedUnitHexes.length} damaged units for healing');

      // Set up unit selection callback
      chexxState.onUnitSelected = () {
        if (chexxState.activeCardActionUnitId != null) {
          usedUnitIds.add(chexxState.activeCardActionUnitId!);
          print('Unit ${chexxState.activeCardActionUnitId} selected for healing');

          // Complete unit_selection substep
          _advanceSubStep(actionIndex, 'unit_selection');

          // Perform healing
          _performHealing(actionIndex, action);
        }
      };

      _chexxGameEngine!.notifyListeners();
    }
  }

  void _performHealing(int actionIndex, dynamic action) {
    if (_chexxGameEngine == null) return;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
    final selectedUnitId = chexxState.activeCardActionUnitId;

    if (selectedUnitId == null) {
      print('ERROR: No unit selected for healing');
      return;
    }

    // Find the selected unit
    final selectedUnit = chexxState.simpleUnits.firstWhere(
      (u) => u.id == selectedUnitId,
      orElse: () => throw Exception('Selected unit not found: $selectedUnitId'),
    );

    print('Performing healing on unit ${selectedUnit.id} (${selectedUnit.unitType})');
    print('Current health: ${selectedUnit.health}/${selectedUnit.maxHealth}');

    // Get heal_dice_count from action
    final healDiceCount = action['heal_dice_count'] as String?;
    int diceToRoll = 4; // Default

    if (healDiceCount == 'hand_size') {
      // Roll 1 die per command card in hand (including the Medics & Mechanics card currently in play)
      final currentPlayer = cardGameState.cardCurrentPlayer;
      if (currentPlayer != null) {
        // Hand size + 1 for the card being played (it was moved to inPlay zone)
        diceToRoll = currentPlayer.hand.length + 1;
      }
    }

    print('Rolling $diceToRoll dice for healing (hand size: ${cardGameState.cardCurrentPlayer?.hand.length})');

    // Roll dice and count matching symbols/stars
    int healingAmount = 0;
    final diceResults = <String>[];

    // TODO: Implement dice rolling for healing
    // For now, use a placeholder healing amount
    healingAmount = (diceToRoll / 2).floor(); // Average healing
    print('TODO: Need to implement rollBattleDie() - using placeholder healing: $healingAmount');

    // for (int i = 0; i < diceToRoll; i++) {
    //   final result = chexxState.rollBattleDie();
    //   diceResults.add(result);
    //
    //   // Check if die matches unit's symbol or is a star
    //   final unitSymbol = selectedUnit.unitType.toLowerCase();
    //   if (result.toLowerCase() == unitSymbol || result.toLowerCase() == 'star') {
    //     healingAmount++;
    //   }
    // }

    print('Dice results: ${diceResults.join(", ")}');
    print('Healing amount: $healingAmount');

    // Apply healing (capped at maxHealth)
    final oldHealth = selectedUnit.health;
    final newHealth = (selectedUnit.health + healingAmount).clamp(0, selectedUnit.maxHealth);
    // TODO: SimpleGameUnit.health is read-only - need to implement a method to update health
    // selectedUnit.health = newHealth;
    final actualHealing = newHealth - oldHealth;
    print('TODO: Need to implement unit health modification - would heal from $oldHealth to $newHealth');

    print('Healed unit from $oldHealth to ${selectedUnit.health} HP (actual healing: $actualHealing)');

    // Complete healing substep
    _advanceSubStep(actionIndex, 'healing');

    // If at least 1 HP was restored, allow the unit to continue with remaining substeps
    // Otherwise, auto-complete remaining substeps
    if (actualHealing > 0) {
      print('Unit healed - can continue with remaining substeps');

      // Set up callbacks for movement and combat
      chexxState.onUnitMoved = () {
        _advanceSubStep(actionIndex, 'before_combat_movement');

        // Check if there are enemies in range
        chexxState.calculateAttackRange(selectedUnit);
        if (chexxState.attackRangeHexes.isEmpty) {
          print('No enemies in attack range - auto-completing combat substep');
          _advanceSubStep(actionIndex, 'combat');
          _advanceSubStep(actionIndex, 'after_combat_movement');
        } else {
          chexxState.isCardActionUnitLocked = true;
        }
      };

      chexxState.onCombatOccurred = () {
        _advanceSubStep(actionIndex, 'combat');

        // Auto-complete after-combat movement if no special movement
        final moveAfterCombatBonus = action['move_after_combat'] as int? ?? 0;
        if (moveAfterCombatBonus == 0 && selectedUnit.moveAfterCombat == 0) {
          _advanceSubStep(actionIndex, 'after_combat_movement');
        }
      };

      chexxState.onAfterCombatMovement = () {
        _advanceSubStep(actionIndex, 'after_combat_movement');
      };

      // Keep unit highlighted for movement/combat
      chexxState.highlightedHexes = {selectedUnit.position};
    } else {
      print('No healing occurred - auto-completing remaining substeps');
      _advanceSubStep(actionIndex, 'before_combat_movement');
      _advanceSubStep(actionIndex, 'combat');
      _advanceSubStep(actionIndex, 'after_combat_movement');
    }

    _chexxGameEngine!.notifyListeners();
    setState(() {});
  }

  void _handleTheirFinestHourAction(int actionIndex, dynamic action) {
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
      final currentPlayer = chexxState.currentPlayer;

      print('Their Finest Hour action activated');

      // Get dice count from action
      final diceCountStr = action['dice_count'] as String?;
      int diceToRoll = 4; // Default

      if (diceCountStr == 'hand_size') {
        // Roll 1 die per command card in hand (including the card being played)
        final cardPlayer = cardGameState.cardCurrentPlayer;
        if (cardPlayer != null) {
          // Hand size + 1 for the card being played (it was moved to inPlay zone)
          diceToRoll = cardPlayer.hand.length + 1;
        }
      }

      print('Rolling $diceToRoll dice for Their Finest Hour (hand size: ${cardGameState.cardCurrentPlayer?.hand.length})');

      // Roll dice and count results by unit type
      final Map<String, int> unitTypeCounts = {};
      int starCount = 0;
      final diceResults = <String>[];

      // TODO: Implement dice rolling - for now use placeholder
      print('TODO: Need to implement rollBattleDie() - using placeholder results');
      // Placeholder: assume average distribution
      starCount = (diceToRoll / 6).floor();
      unitTypeCounts['infantry'] = (diceToRoll / 6).floor();

      // for (int i = 0; i < diceToRoll; i++) {
      //   final result = chexxState.rollBattleDie();
      //   diceResults.add(result);
      //
      //   final resultLower = result.toLowerCase();
      //   if (resultLower == 'star') {
      //     starCount++;
      //   } else if (resultLower != 'grenade' && resultLower != 'flag') {
      //     // Unit symbol rolled (infantry, tank, artillery, etc.)
      //     unitTypeCounts[resultLower] = (unitTypeCounts[resultLower] ?? 0) + 1;
      //   }
      // }

      print('Dice results: ${diceResults.join(", ")}');
      print('Unit type counts: $unitTypeCounts');
      print('Star count: $starCount');

      // Check if reshuffle is needed
      final shouldReshuffle = action['reshuffle'] as bool? ?? false;
      if (shouldReshuffle) {
        print('Reshuffling deck and discard pile');
        // TODO: Implement deck reshuffle functionality in f_card_engine
        print('TODO: Need to implement reshuffleDiscardIntoDeck() in DeckManager');
        // cardGameState.cardGameState.deckManager.reshuffleDiscardIntoDeck();
      }

      // Generate actions based on dice results
      final List<Map<String, dynamic>> newActions = [];

      // Create actions for each unit type rolled
      for (final entry in unitTypeCounts.entries) {
        final unitType = entry.key;
        final count = entry.value;

        // Get matching units of this type
        final matchingUnits = chexxState.simpleUnits
            .where((u) => u.owner == currentPlayer &&
                         !usedUnitIds.contains(u.id) &&
                         u.unitType.toLowerCase().contains(unitType))
            .toList();

        print('Found ${matchingUnits.length} available $unitType units for $count dice rolls');

        // Create one action per die rolled of this type (up to available units)
        final unitsToOrder = count < matchingUnits.length ? count : matchingUnits.length;
        for (int i = 0; i < unitsToOrder; i++) {
          newActions.add({
            'action_type': 'order',
            'name': 'Order ${unitType.toUpperCase()}',
            'unit_restrictions': unitType,
            'hex_tiles': 'all',
            'battle_die': '+1',
            'generated_for_unit_id': matchingUnits[i].id,
            'sub_steps': ['unit_selection', 'before_combat_movement', 'combat', 'after_combat_movement'],
          });
        }
      }

      // Create actions for stars (player can choose any unit)
      for (int i = 0; i < starCount; i++) {
        newActions.add({
          'action_type': 'order',
          'name': 'Order ANY (Star $i)',
          'unit_restrictions': 'none',
          'hex_tiles': 'all',
          'battle_die': '+1',
          'sub_steps': ['unit_selection', 'before_combat_movement', 'combat', 'after_combat_movement'],
        });
      }

      print('Generated ${newActions.length} actions from Their Finest Hour dice rolls');

      if (newActions.isNotEmpty) {
        // Replace the current action with generated actions
        setState(() {
          generatedActions = newActions;
          // Mark the original action as complete since it's been replaced
          completedActions.add(actionIndex);
          activeActionIndex = null;
          // Reset sub-step tracking for the original action
          actionCurrentSubStep.remove(actionIndex);
          actionCompletedSubSteps.remove(actionIndex);
        });
      } else {
        // No valid actions - complete the original action
        print('No valid units to order - completing action');
        setState(() {
          completedActions.add(actionIndex);
          activeActionIndex = null;
          actionCurrentSubStep.remove(actionIndex);
          actionCompletedSubSteps.remove(actionIndex);
        });
      }

      _chexxGameEngine!.notifyListeners();
    }
  }

  void _handleAirStrikeAction(int actionIndex, dynamic action) {
    if (_chexxGameEngine != null) {
      final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
      chexxState.isCardActionActive = true;

      // Get the current player and enemy player
      final currentPlayer = chexxState.currentPlayer;
      final enemyPlayer = currentPlayer == Player.player1 ? Player.player2 : Player.player1;

      // Get cluster index from action (0 = first strike, can target any enemy)
      final clusterIndex = action['cluster_index'] as int? ?? 0;
      print('Air Strike ${clusterIndex + 1} activated');

      // Get dice per target from action (default 2 for Allied, could be 1 for Axis)
      final dicePerTarget = action['dice_per_target'] as int? ?? 2;

      // Store air strike action metadata for combat system to use
      chexxState.activeBarrageAction = action;

      // Get hex_tiles restriction
      final hexTiles = action['hex_tiles'] as String?;
      Set<core_hex.HexCoordinate> allowedHexes;

      if (clusterIndex == 0) {
        // First strike - can target ANY enemy unit
        allowedHexes = chexxState.simpleUnits
            .where((u) => u.owner == enemyPlayer)
            .map((u) => u.position)
            .toSet();
        print('First air strike - can target any of ${allowedHexes.length} enemy units');
      } else {
        // Subsequent strikes - must be adjacent to cluster
        if (hexTiles == 'adjacent_to_cluster' && airStrikeCluster.isNotEmpty) {
          // Find all enemy units adjacent to any unit in the cluster
          allowedHexes = {};
          for (final clusterHex in airStrikeCluster) {
            // Get neighbors of this hex (manually compute adjacent hexes)
            // TODO: Implement getNeighbors() method in ChexxGameState
            // For now, check all enemy units and see if they're adjacent
            for (final unit in chexxState.simpleUnits) {
              if (unit.owner == enemyPlayer) {
                // Check if this unit is adjacent to the cluster hex
                final dq = (unit.position.q - clusterHex.q).abs();
                final dr = (unit.position.r - clusterHex.r).abs();
                final ds = (unit.position.s - clusterHex.s).abs();
                // In cube coordinates, adjacent hexes have max distance of 1
                if (dq <= 1 && dr <= 1 && ds <= 1 && (dq + dr + ds) == 2) {
                  allowedHexes.add(unit.position);
                }
              }
            }
          }
          print('Air strike ${clusterIndex + 1} - ${allowedHexes.length} enemy units adjacent to cluster');
        } else {
          // No cluster yet or invalid hex_tiles - no valid targets
          allowedHexes = {};
          print('No valid targets for air strike ${clusterIndex + 1}');
        }
      }

      chexxState.highlightedHexes = allowedHexes;
      print('Highlighted ${allowedHexes.length} enemy hexes for air strike');
      print('Air strike will attack with $dicePerTarget dice');

      // Set up combat callback
      chexxState.onCombatOccurred = () {
        print('Air strike combat occurred');

        // TODO: Track last combat target position
        // For now, we can't add to cluster without this info
        // if (chexxState.lastCombatTargetPosition != null) {
        //   airStrikeCluster.add(chexxState.lastCombatTargetPosition!);
        //   print('Added ${chexxState.lastCombatTargetPosition} to air strike cluster (size: ${airStrikeCluster.length})');
        // }
        print('TODO: Need lastCombatTargetPosition to track air strike cluster properly');

        _advanceSubStep(actionIndex, 'combat');
      };

      _chexxGameEngine!.notifyListeners();
    }
  }

  void _placeSandbagOnUnit(SimpleGameUnit unit) {
    if (_chexxGameEngine == null) return;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;

    print('Placing sandbag on unit ${unit.id} at ${unit.position}');

    // Check if there's already a structure at this position
    final existingStructure = chexxState.placedStructures.firstWhere(
      (s) => s.position.q == unit.position.q &&
             s.position.r == unit.position.r &&
             s.position.s == unit.position.s,
      orElse: () => throw Exception('No structure'),
    );

    try {
      if (existingStructure.id.isNotEmpty) {
        print('Structure already exists at ${unit.position} - not placing sandbag');
        return;
      }
    } catch (e) {
      // No existing structure, proceed with placement
    }

    // Create a sandbag structure
    // Note: This assumes there's a sandbag structure type defined in the game
    // You may need to look up the proper StructureType enum value
    final sandbag = GameStructure(
      id: 'sandbag_${unit.position.q}_${unit.position.r}_${unit.position.s}',
      type: StructureType.sandbag,
      position: unit.position,
      // Note: GameStructure doesn't have an owner parameter
    );

    chexxState.placedStructures.add(sandbag);
    print('Sandbag placed at ${unit.position}');

    _chexxGameEngine!.notifyListeners();
  }

  void _advanceSubStep(int actionIndex, String subStepName) {
    if (!mounted) return;

    setState(() {
      final action = _getCurrentActions()![actionIndex];
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

  void _handleBarbwireRemove(int actionIndex, SimpleGameUnit unit, GameStructure barbwireStructure) {
    if (!mounted) return;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;

    // Remove the barbwire structure from the game
    chexxState.placedStructures.remove(barbwireStructure);
    print('Barbwire removed at position ${barbwireStructure.position}');

    // Clear barbwire decision state
    chexxState.isWaitingForBarbwireDecision = false;
    chexxState.barbwireDecisionHex = null;
    chexxState.onBarbwireRemove = null;
    chexxState.onBarbwireKeep = null;

    // Advance the before_combat_movement substep
    _advanceSubStep(actionIndex, 'before_combat_movement');

    // Check if unit is infantry
    if (unit.unitType.toLowerCase() == 'infantry') {
      // Infantry that removes barbwire ends its action immediately
      print('Infantry removed barbwire - cancelling remaining substeps');

      // Mark all remaining substeps as cancelled
      final action = _getCurrentActions()![actionIndex];
      final subSteps = action['sub_steps'] as List?;
      if (subSteps != null) {
        final completedSteps = actionCompletedSubSteps[actionIndex] ?? {};
        final cancelledSteps = actionCancelledSubSteps[actionIndex] ?? <int>{};

        for (int i = 0; i < subSteps.length; i++) {
          // Cancel substeps that haven't been completed yet
          if (!completedSteps.contains(i)) {
            cancelledSteps.add(i);
          }
        }

        actionCancelledSubSteps[actionIndex] = cancelledSteps;
      }

      // Complete the action
      _completeAction(actionIndex);
    } else {
      // Non-infantry units continue normally after removing barbwire
      final action = _getCurrentActions()![actionIndex];

      // Check if there are any enemies in attack range
      chexxState.calculateAttackRange(unit);
      final hasEnemiesInRange = chexxState.attackRangeHexes.isNotEmpty;

      if (!hasEnemiesInRange) {
        // No enemies in range - auto-complete combat substep
        print('No enemies in attack range after barbwire removal - auto-completing combat substep');
        _advanceSubStep(actionIndex, 'combat');

        // Check if we should auto-complete after-combat movement
        final moveAfterCombatBonus = action['move_after_combat'] as int? ?? 0;
        if (moveAfterCombatBonus == 0 && unit.moveAfterCombat == 0) {
          // No special movement values - auto-complete after-combat movement
          print('No after-combat movement - auto-completing after_combat_movement substep');
          _advanceSubStep(actionIndex, 'after_combat_movement');
        }
      } else {
        chexxState.isCardActionUnitLocked = true;
        chexxState.moveAndFireHexes.clear();
        chexxState.moveOnlyHexes.clear();
      }
    }

    _chexxGameEngine!.notifyListeners();
    setState(() {});
  }

  void _handleBarbwireKeep(int actionIndex) {
    if (!mounted) return;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;

    // Clear barbwire decision state
    chexxState.isWaitingForBarbwireDecision = false;
    chexxState.barbwireDecisionHex = null;
    chexxState.onBarbwireRemove = null;
    chexxState.onBarbwireKeep = null;

    // Continue with normal movement completion
    _advanceSubStep(actionIndex, 'before_combat_movement');

    // Get the selected unit
    final selectedUnit = chexxState.simpleUnits.firstWhere(
      (u) => u.isSelected,
      orElse: () => throw Exception('No selected unit'),
    );

    final action = _getCurrentActions()![actionIndex];

    // Check if there are any enemies in attack range
    chexxState.calculateAttackRange(selectedUnit);
    final hasEnemiesInRange = chexxState.attackRangeHexes.isNotEmpty;

    if (!hasEnemiesInRange) {
      // No enemies in range - auto-complete combat substep
      print('No enemies in attack range after keeping barbwire - auto-completing combat substep');
      _advanceSubStep(actionIndex, 'combat');

      // Check if we should auto-complete after-combat movement
      final moveAfterCombatBonus = action['move_after_combat'] as int? ?? 0;
      if (moveAfterCombatBonus == 0 && selectedUnit.moveAfterCombat == 0) {
        // No special movement values - auto-complete after-combat movement
        print('No after-combat movement - auto-completing after_combat_movement substep');
        _advanceSubStep(actionIndex, 'after_combat_movement');
      }
    } else {
      chexxState.isCardActionUnitLocked = true;
      chexxState.moveAndFireHexes.clear();
      chexxState.moveOnlyHexes.clear();
      print('Barbwire kept - continuing with action');
    }

    _chexxGameEngine!.notifyListeners();
    setState(() {});
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
        chexxState.isWaitingForBarbwireDecision = false;
        chexxState.barbwireDecisionHex = null;
        chexxState.lastMoveWasMoveOnly = false;
        // Clear sub-step callbacks
        chexxState.onUnitSelected = null;
        chexxState.onUnitMoved = null;
        chexxState.onCombatOccurred = null;
        chexxState.onAfterCombatMovement = null;
        chexxState.onBarbwireRemove = null;
        chexxState.onBarbwireKeep = null;
        _chexxGameEngine!.notifyListeners();
      }

      // Check if all actions are complete
      final totalActions = _getCurrentActions()?.length ?? 0;
      if (completedActions.length >= totalActions) {
        // All actions complete - mark as ready but keep card visible until END TURN
        allActionsComplete = true;
        print('All card actions complete - card will remain visible until END TURN');
      }
    });
  }

  /// Check if an action has any valid units available (excluding already used units)
  bool _actionHasValidUnits(int actionIndex) {
    if (_chexxGameEngine == null) return false;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
    final currentPlayer = chexxState.currentPlayer;
    final action = _getCurrentActions()![actionIndex];

    return _checkActionHasValidUnits(action, chexxState, currentPlayer);
  }

  /// Check if a specific action object has valid units (used when checking before card is played)
  bool _actionHasValidUnitsForNewCard(dynamic action) {
    if (_chexxGameEngine == null) return false;

    final chexxState = _chexxGameEngine!.gameState as ChexxGameState;
    final currentPlayer = chexxState.currentPlayer;

    return _checkActionHasValidUnits(action, chexxState, currentPlayer);
  }

  /// Helper method to check if an action has valid units
  bool _checkActionHasValidUnits(dynamic action, ChexxGameState chexxState, Player currentPlayer) {
    // Get hex_tiles restriction for this action
    final hexTiles = action['hex_tiles'] as String?;
    Set<core_hex.HexCoordinate>? allowedHexes;
    if (hexTiles != null && hexTiles != 'none' && hexTiles != 'all') {
      // Handle special location restrictions
      if (hexTiles.toLowerCase() == 'not adjacent') {
        allowedHexes = chexxState.getHexesNotAdjacentToEnemyUnits();
      } else if (hexTiles.toLowerCase() == 'adjacent to enemy units') {
        allowedHexes = chexxState.getHexesAdjacentToEnemyUnits();
      } else {
        // Handle board section restrictions (left third, middle third, right third)
        allowedHexes = chexxState.getHexesForThird(hexTiles);
      }
    }

    // Get unit_restrictions from action (can be String or List<String>)
    final unitRestriction = action['unit_restrictions'];

    // Check if any units are available for this action
    for (final unit in chexxState.simpleUnits) {
      if (unit.owner == currentPlayer) {
        // Skip units that have already been used
        if (usedUnitIds.contains(unit.id)) {
          continue;
        }

        // Check unit_restrictions filter (supports both String and List<String>)
        bool passesUnitRestriction = true;
        if (unitRestriction != null) {
          if (unitRestriction is String) {
            // Handle String format
            if (unitRestriction.isNotEmpty && unitRestriction.toLowerCase() != 'all' && unitRestriction.toLowerCase() != 'none') {
              final restrictionLower = unitRestriction.toLowerCase();
              final unitTypeLower = unit.unitType.toLowerCase();

              // Special case: "damaged" means health < maxHealth
              if (restrictionLower == 'damaged') {
                if (unit.health >= unit.maxHealth) {
                  passesUnitRestriction = false;
                }
              } else if (!unitTypeLower.contains(restrictionLower)) {
                passesUnitRestriction = false;
              }
            }
          } else if (unitRestriction is List) {
            // Handle List<String> format
            final restrictionList = unitRestriction.cast<String>();
            if (restrictionList.isNotEmpty) {
              final restrictionsLower = restrictionList.map((r) => r.toLowerCase()).toList();
              final unitTypeLower = unit.unitType.toLowerCase();
              // Check if unit type matches ANY restriction in the list
              if (!restrictionsLower.any((r) => r == 'all' || r == 'none' || unitTypeLower.contains(r))) {
                passesUnitRestriction = false;
              }
            }
          }
        }

        if (!passesUnitRestriction) {
          continue;
        }

        // Check if unit is in allowed hexes
        if (allowedHexes == null || allowedHexes.contains(unit.position)) {
          return true; // Found a valid unit
        }
      }
    }

    return false; // No valid units found
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
                        '${action['name'] ?? action['action_type']}: ${action['unit_restrictions'] ?? 'all'} (${action['hex_tiles'] ?? 'all'})',
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

  /// Build the card choice dialog for Recon card effect
  /// Shows two cards and lets player choose one
  Widget _buildCardChoiceDialog() {
    return Container(
      color: Colors.black.withOpacity(0.7), // Dark overlay
      child: Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a3e),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Recon: Choose One Card',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select one card to add to your hand. The other will be discarded.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Two card choices side by side
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < cardChoices.length; i++) ...[
                    _buildCardChoiceOption(cardChoices[i], i),
                    if (i < cardChoices.length - 1) const SizedBox(width: 32),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a single card choice option
  Widget _buildCardChoiceOption(dynamic cardInstance, int choiceIndex) {
    final card = cardInstance.card;
    return GestureDetector(
      onTap: () => _selectReconCard(choiceIndex),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card name
              Text(
                card.name,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Card type
              Text(
                card.customData['type']?.toString().toUpperCase() ?? 'CARD',
                style: TextStyle(
                  color: _getCardTypeColor(card.customData['type'] as String?),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Card description
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  card.customData['description']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),

              // Choose button
              ElevatedButton(
                onPressed: () => _selectReconCard(choiceIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('CHOOSE THIS CARD'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCardTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'attack':
        return Colors.red;
      case 'defense':
        return Colors.blue;
      case 'support':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _endTurn() {
    // Check if Recon card (card_23) was played - need to handle special card draw
    bool reconCardPlayed = false;
    if (playedCard != null) {
      final endOfTurn = playedCard.card.endOfTurn;
      if (endOfTurn == 'draw two and discard one') {
        reconCardPlayed = true;
        print('Recon card was played - will draw two cards for player to choose');
      }
    }

    // If there's a played card with incomplete actions, check if they can be auto-completed
    if (playedCard != null) {
      final totalActions = _getCurrentActions()?.length ?? 0;
      if (completedActions.length < totalActions) {
        // Get remaining action indices
        final remainingActionIndices = List.generate(totalActions, (i) => i)
            .where((i) => !completedActions.contains(i))
            .toList();

        // Auto-complete actions that have no valid units
        final actionsToAutoComplete = <int>[];
        for (final i in remainingActionIndices) {
          if (!_actionHasValidUnits(i)) {
            actionsToAutoComplete.add(i);
          }
        }

        if (actionsToAutoComplete.isNotEmpty) {
          print('Auto-completing ${actionsToAutoComplete.length} actions with no valid units at end of turn');
          setState(() {
            for (final i in actionsToAutoComplete) {
              completedActions.add(i);
              // Mark all substeps as cancelled for these actions
              final action = _getCurrentActions()![i];
              final subSteps = action['sub_steps'] as List?;
              if (subSteps != null) {
                final cancelledSteps = actionCancelledSubSteps[i] ?? <int>{};
                for (int j = 0; j < subSteps.length; j++) {
                  cancelledSteps.add(j);
                }
                actionCancelledSubSteps[i] = cancelledSteps;
              }
            }

            // Check if all actions are now complete
            if (completedActions.length >= totalActions) {
              allActionsComplete = true;
            }
          });
        }

        // If there are still incomplete actions that COULD be done, show error
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
      }

      // Discard the completed card now
      cardGameState.moveCardFromPlay(playedCard, f_card.CardZone.discard);
      print('Card discarded: ${playedCard.card.name}');
    }

    // End turn in f-card engine (checks if card was played)
    // Note: We can't disable auto-draw, so we'll need to handle Recon differently
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

    // Handle Recon card special draw
    if (reconCardPlayed) {
      _handleReconCardDraw();
      return; // Don't clear state yet - wait for card selection
    }

    setState(() {
      selectedCard = null; // Clear selected card for next turn
      playedCard = null;
      completedActions.clear();
      actionCurrentSubStep.clear();
      actionCompletedSubSteps.clear();
      actionCancelledSubSteps.clear();
      usedUnitIds.clear(); // Clear unit usage tracking for next turn
      airStrikeCluster.clear(); // Clear air strike cluster for next turn
      allActionsComplete = false; // Reset button color for next turn
      activeActionIndex = null;
    });
  }

  /// Handle the special card draw for Recon card (card_23)
  /// Draw two cards and let player choose one, discard the other
  /// Note: endTurn() already drew 1 card automatically, so we need to draw 1 more
  void _handleReconCardDraw() {
    final deckManager = widget.gamePlugin.deckManager;
    final currentPlayer = cardGameState.cardCurrentPlayer;

    if (currentPlayer == null) {
      print('ERROR: No current player for Recon card draw');
      return;
    }

    // endTurn() already drew 1 card for us, we need 1 more for Recon
    // Check if deck has at least 1 more card
    if (deckManager.cardsRemaining < 1) {
      print('Not enough cards in deck for Recon draw (need 1 more, have ${deckManager.cardsRemaining})');
      _finishTurn();
      return;
    }

    // The last card in hand was auto-drawn by endTurn()
    if (currentPlayer.hand.isEmpty) {
      print('ERROR: No cards in hand after endTurn');
      _finishTurn();
      return;
    }

    final autoDrawnCard = currentPlayer.hand.last;

    // Draw one more card manually
    final secondCard = deckManager.drawCard();
    if (secondCard == null) {
      print('ERROR: Failed to draw second card for Recon effect');
      _finishTurn();
      return;
    }

    // Add second card to hand temporarily
    secondCard.moveToZone(f_card.CardZone.hand);
    currentPlayer.addToHand(secondCard);

    // Now remove both cards from hand temporarily (for the choice UI)
    currentPlayer.removeFromHand(autoDrawnCard);
    currentPlayer.removeFromHand(secondCard);

    // Show card choice UI
    setState(() {
      isWaitingForCardChoice = true;
      cardChoices = [autoDrawnCard, secondCard];
    });

    print('Recon: Showing player two cards to choose from');
    print('Card 1: ${autoDrawnCard.card.name}');
    print('Card 2: ${secondCard.card.name}');
  }

  /// Called when player selects one of the two cards from Recon draw
  void _selectReconCard(int choiceIndex) {
    if (choiceIndex < 0 || choiceIndex >= cardChoices.length) {
      print('ERROR: Invalid card choice index: $choiceIndex');
      return;
    }

    final selectedCard = cardChoices[choiceIndex];
    final discardedCard = cardChoices[1 - choiceIndex]; // Get the other card
    final currentPlayer = cardGameState.cardCurrentPlayer;

    if (currentPlayer == null) {
      print('ERROR: No current player when selecting Recon card');
      return;
    }

    // Add selected card to player's hand
    selectedCard.moveToZone(f_card.CardZone.hand);
    currentPlayer.addToHand(selectedCard);
    print('Recon: Player chose ${selectedCard.card.name}');

    // Discard the other card using the card game state adapter
    discardedCard.moveToZone(f_card.CardZone.discard);
    cardGameState.moveCardFromPlay(discardedCard, f_card.CardZone.discard);
    print('Recon: Discarded ${discardedCard.card.name}');

    // Clear card choice state and finish turn
    setState(() {
      isWaitingForCardChoice = false;
      cardChoices.clear();
    });

    _finishTurn();
  }

  /// Finish the turn after all end-of-turn effects are complete
  void _finishTurn() {
    setState(() {
      selectedCard = null; // Clear selected card for next turn
      playedCard = null;
      completedActions.clear();
      actionCurrentSubStep.clear();
      actionCompletedSubSteps.clear();
      actionCancelledSubSteps.clear();
      usedUnitIds.clear(); // Clear unit usage tracking for next turn
      airStrikeCluster.clear(); // Clear air strike cluster for next turn
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
    // Ensure game_type is set to 'card' for card game mode
    final cardScenarioConfig = widget.scenarioConfig != null
        ? Map<String, dynamic>.from(widget.scenarioConfig!)
        : <String, dynamic>{};
    cardScenarioConfig['game_type'] = 'card'; // Override to ensure dice rolls persist

    gameEngine = ChexxGameEngine(
      gamePlugin: ChexxPlugin(),
      scenarioConfig: cardScenarioConfig,
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

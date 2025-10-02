import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// Types of action cards
enum ActionCardType {
  attack,
  movement,
  combined,
  defensive,
}

/// Rarity levels for action cards
enum ActionCardRarity {
  common,
  uncommon,
  rare,
  epic,
}

/// Represents a single action card in the WWII game
class ActionCard {
  final String id;
  final String name;
  final String description;
  final int unitsCanOrder;
  final ActionCardType type;
  final ActionCardRarity rarity;

  const ActionCard({
    required this.id,
    required this.name,
    required this.description,
    required this.unitsCanOrder,
    required this.type,
    required this.rarity,
  });

  /// Create ActionCard from JSON
  factory ActionCard.fromJson(Map<String, dynamic> json) {
    return ActionCard(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      unitsCanOrder: json['units_can_order'] as int,
      type: _parseActionCardType(json['type'] as String),
      rarity: _parseActionCardRarity(json['rarity'] as String),
    );
  }

  /// Convert ActionCard to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'units_can_order': unitsCanOrder,
      'type': type.name,
      'rarity': rarity.name,
    };
  }

  /// Parse string to ActionCardType
  static ActionCardType _parseActionCardType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'attack':
        return ActionCardType.attack;
      case 'movement':
        return ActionCardType.movement;
      case 'combined':
        return ActionCardType.combined;
      case 'defensive':
        return ActionCardType.defensive;
      default:
        return ActionCardType.combined;
    }
  }

  /// Parse string to ActionCardRarity
  static ActionCardRarity _parseActionCardRarity(String rarityString) {
    switch (rarityString.toLowerCase()) {
      case 'common':
        return ActionCardRarity.common;
      case 'uncommon':
        return ActionCardRarity.uncommon;
      case 'rare':
        return ActionCardRarity.rare;
      case 'epic':
        return ActionCardRarity.epic;
      default:
        return ActionCardRarity.common;
    }
  }

  @override
  String toString() => 'ActionCard($id: $name, $unitsCanOrder units)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActionCard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Represents a deck of action cards
class ActionCardDeck {
  final String name;
  final String description;
  final String version;
  final List<ActionCard> cards;

  const ActionCardDeck({
    required this.name,
    required this.description,
    required this.version,
    required this.cards,
  });

  /// Total number of cards in deck
  int get totalCards => cards.length;

  /// Create ActionCardDeck from JSON
  factory ActionCardDeck.fromJson(Map<String, dynamic> json) {
    final cardsList = json['cards'] as List<dynamic>;
    final cards = cardsList
        .map((cardJson) => ActionCard.fromJson(cardJson as Map<String, dynamic>))
        .toList();

    return ActionCardDeck(
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      cards: cards,
    );
  }

  /// Load deck from asset file
  static Future<ActionCardDeck> loadFromAsset(String assetPath) async {
    final String jsonString = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return ActionCardDeck.fromJson(json);
  }

  /// Create a shuffled copy of the deck
  ActionCardDeck shuffle({Random? random}) {
    final shuffledCards = List<ActionCard>.from(cards);
    shuffledCards.shuffle(random);
    return ActionCardDeck(
      name: name,
      description: description,
      version: version,
      cards: shuffledCards,
    );
  }

  /// Draw a hand of cards from the deck
  List<ActionCard> drawHand(int handSize, {Random? random}) {
    if (handSize > cards.length) {
      throw ArgumentError('Cannot draw $handSize cards from deck of ${cards.length}');
    }

    final shuffledDeck = shuffle(random: random);
    return shuffledDeck.cards.take(handSize).toList();
  }

  /// Get cards by type
  List<ActionCard> getCardsByType(ActionCardType type) {
    return cards.where((card) => card.type == type).toList();
  }

  /// Get cards by rarity
  List<ActionCard> getCardsByRarity(ActionCardRarity rarity) {
    return cards.where((card) => card.rarity == rarity).toList();
  }

  /// Get cards that can order specific number of units
  List<ActionCard> getCardsByUnits(int units) {
    return cards.where((card) => card.unitsCanOrder == units).toList();
  }

  @override
  String toString() => 'ActionCardDeck($name: ${cards.length} cards)';
}

/// Manages a player's hand of action cards
class PlayerHand {
  final List<ActionCard> _cards;
  ActionCard? _playedCard;

  PlayerHand(this._cards);

  /// Cards currently in hand
  List<ActionCard> get cards => List.unmodifiable(_cards);

  /// Number of cards in hand
  int get size => _cards.length;

  /// Card played this turn (if any)
  ActionCard? get playedCard => _playedCard;

  /// Check if hand is empty
  bool get isEmpty => _cards.isEmpty;

  /// Check if a card has been played this turn
  bool get hasPlayedCard => _playedCard != null;

  /// Play a card from hand
  bool playCard(ActionCard card) {
    if (_playedCard != null) {
      return false; // Already played a card this turn
    }

    if (!_cards.contains(card)) {
      return false; // Card not in hand
    }

    _cards.remove(card);
    _playedCard = card;
    return true;
  }

  /// Add a card to hand
  void addCard(ActionCard card) {
    _cards.add(card);
  }

  /// Remove a card from hand
  bool removeCard(ActionCard card) {
    return _cards.remove(card);
  }

  /// Clear the played card (usually at end of turn)
  void clearPlayedCard() {
    _playedCard = null;
  }

  /// End turn - clear played card and return it
  ActionCard? endTurn() {
    final played = _playedCard;
    _playedCard = null;
    return played;
  }

  /// Get number of units that can be ordered this turn
  int get unitsCanOrder => _playedCard?.unitsCanOrder ?? 0;

  @override
  String toString() => 'PlayerHand(${_cards.length} cards, played: $_playedCard)';
}

/// Factory for loading action card decks
class ActionCardDeckLoader {
  static ActionCardDeck? _cachedDeck;

  /// Load the WWII action cards deck
  static Future<ActionCardDeck> loadWWIIDeck() async {
    _cachedDeck ??= await ActionCardDeck.loadFromAsset(
      'lib/configs/cards/wwii_action_cards.json'
    );
    return _cachedDeck!;
  }

  /// Clear cached deck (for testing)
  static void clearCache() {
    _cachedDeck = null;
  }
}
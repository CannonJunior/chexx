import 'package:test/test.dart';
import 'package:chexx_shared_models/chexx_shared_models.dart';

void main() {
  group('NetworkMessage', () {
    test('serializes to JSON correctly', () {
      final message = NetworkMessage(
        type: MessageType.gameAction,
        payload: {'test': 'data'},
        messageId: 'msg123',
        clientId: 'client456',
      );

      final json = message.toJson();

      expect(json['type'], MessageType.gameAction);
      expect(json['payload'], {'test': 'data'});
      expect(json['messageId'], 'msg123');
      expect(json['clientId'], 'client456');
      expect(json['timestamp'], isNotNull);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': MessageType.ping,
        'payload': {'data': 123},
        'timestamp': 1234567890,
        'messageId': 'test',
        'clientId': 'client1',
      };

      final message = NetworkMessage.fromJson(json);

      expect(message.type, MessageType.ping);
      expect(message.payload, {'data': 123});
      expect(message.timestamp, 1234567890);
      expect(message.messageId, 'test');
      expect(message.clientId, 'client1');
    });

    test('converts to and from JSON string', () {
      final original = NetworkMessage(
        type: MessageType.connected,
        payload: {'welcome': true},
      );

      final jsonString = original.toJsonString();
      final restored = NetworkMessage.fromJsonString(jsonString);

      expect(restored.type, original.type);
      expect(restored.payload, original.payload);
    });

    test('creates response messages with preserved correlation ID', () {
      final request = NetworkMessage(
        type: MessageType.createGame,
        messageId: 'req123',
        clientId: 'client1',
      );

      final response = request.respond(
        type: MessageType.gameCreated,
        payload: {'gameId': 'game456'},
      );

      expect(response.messageId, 'req123');
      expect(response.clientId, 'client1');
      expect(response.type, MessageType.gameCreated);
      expect(response.payload, {'gameId': 'game456'});
    });
  });

  group('GameAction', () {
    test('serializes move action correctly', () {
      final action = GameAction(
        actionType: GameActionType.move,
        playerId: 1,
        unitId: 'unit123',
        fromPosition: HexCoordinateData(0, 0, 0),
        toPosition: HexCoordinateData(1, 0, -1),
      );

      final json = action.toJson();

      expect(json['actionType'], GameActionType.move);
      expect(json['playerId'], 1);
      expect(json['unitId'], 'unit123');
      expect(json['fromPosition'], isNotNull);
      expect(json['toPosition'], isNotNull);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'actionType': GameActionType.attack,
        'playerId': 2,
        'unitId': 'unit456',
        'toPosition': {'q': 1, 'r': 1, 's': -2},
        'timestamp': 9999,
      };

      final action = GameAction.fromJson(json);

      expect(action.actionType, GameActionType.attack);
      expect(action.playerId, 2);
      expect(action.unitId, 'unit456');
      expect(action.toPosition?.q, 1);
      expect(action.timestamp, 9999);
    });
  });

  group('GameStateSnapshot', () {
    test('serializes complete game state correctly', () {
      final snapshot = GameStateSnapshot(
        gameId: 'game123',
        turnNumber: 5,
        currentPlayer: 1,
        players: [
          PlayerInfo(playerId: 'p1', displayName: 'Alice', playerNumber: 1),
          PlayerInfo(playerId: 'p2', displayName: 'Bob', playerNumber: 2),
        ],
        units: [
          UnitData(
            unitId: 'u1',
            unitType: 'infantry',
            owner: 1,
            position: HexCoordinateData(0, 0, 0),
            health: 3,
            maxHealth: 4,
          ),
        ],
        player1Points: 5,
        player2Points: 3,
        player1WinPoints: 10,
        player2WinPoints: 10,
      );

      final json = snapshot.toJson();

      expect(json['gameId'], 'game123');
      expect(json['turnNumber'], 5);
      expect(json['players'], hasLength(2));
      expect(json['units'], hasLength(1));
      expect(json['player1Points'], 5);
    });

    test('round-trips through JSON correctly', () {
      final original = GameStateSnapshot(
        gameId: 'test',
        turnNumber: 1,
        currentPlayer: 1,
        players: [],
        units: [],
        player1Points: 0,
        player2Points: 0,
        player1WinPoints: 10,
        player2WinPoints: 10,
        gameStatus: 'playing',
      );

      final json = original.toJson();
      final restored = GameStateSnapshot.fromJson(json);

      expect(restored.gameId, original.gameId);
      expect(restored.turnNumber, original.turnNumber);
      expect(restored.gameStatus, original.gameStatus);
    });
  });

  group('HexCoordinateData', () {
    test('validates cube coordinate constraint', () {
      final valid = HexCoordinateData(1, -1, 0);
      final invalid = HexCoordinateData(1, 1, 1);

      expect(valid.isValid, true);
      expect(invalid.isValid, false);
    });

    test('equality works correctly', () {
      final coord1 = HexCoordinateData(1, 2, -3);
      final coord2 = HexCoordinateData(1, 2, -3);
      final coord3 = HexCoordinateData(2, 1, -3);

      expect(coord1, equals(coord2));
      expect(coord1, isNot(equals(coord3)));
    });
  });

  group('UnitData', () {
    test('copyWith creates modified copy', () {
      final original = UnitData(
        unitId: 'u1',
        unitType: 'infantry',
        owner: 1,
        position: HexCoordinateData(0, 0, 0),
        health: 3,
        maxHealth: 4,
      );

      final modified = original.copyWith(health: 2, hasMoved: true);

      expect(modified.health, 2);
      expect(modified.hasMoved, true);
      expect(modified.unitId, original.unitId);
      expect(modified.unitType, original.unitType);
    });
  });

  group('PlayerInfo', () {
    test('copyWith updates ready state', () {
      final player = PlayerInfo(
        playerId: 'p1',
        displayName: 'Alice',
        playerNumber: 1,
        isReady: false,
      );

      final ready = player.copyWith(isReady: true);

      expect(ready.isReady, true);
      expect(ready.playerId, player.playerId);
    });
  });
}

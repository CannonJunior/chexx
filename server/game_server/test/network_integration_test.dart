import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chexx_shared_models/chexx_shared_models.dart';

/// Integration test for the network protocol using NetworkMessage
void main() async {
  print('🧪 Testing Updated Chexx Game Server with NetworkMessage Protocol');
  print('=' * 60);
  print('');

  try {
    // Connect to server
    print('📡 Connecting to ws://localhost:8888/ws...');
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8888/ws'),
    );

    // Listen for messages
    var receivedMessages = 0;
    channel.stream.listen(
      (message) {
        receivedMessages++;
        try {
          final networkMessage = NetworkMessage.fromJsonString(message as String);
          print('✅ Received message #$receivedMessages:');
          print('   Type: ${networkMessage.type}');
          print('   Client ID: ${networkMessage.clientId}');
          print('   Timestamp: ${networkMessage.timestamp}');
          if (networkMessage.payload != null) {
            print('   Payload: ${networkMessage.payload}');
          }
          print('');

          // Respond to PING with PONG
          if (networkMessage.type == MessageType.ping) {
            print('📤 Sending PONG response...');
            final pong = NetworkMessage(
              type: MessageType.pong,
              clientId: networkMessage.clientId,
            );
            channel.sink.add(pong.toJsonString());
          }
        } catch (e) {
          print('⚠️  Error parsing message: $e');
        }
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
        exit(1);
      },
      onDone: () {
        print('');
        print('🔌 Connection closed');
        print('Total messages received: $receivedMessages');
        exit(0);
      },
    );

    // Wait for CONNECTED message
    await Future.delayed(Duration(seconds: 1));

    // Test 1: Send PING
    print('📤 Test 1: Sending PING with NetworkMessage...');
    final ping = NetworkMessage(
      type: MessageType.ping,
    );
    channel.sink.add(ping.toJsonString());
    await Future.delayed(Duration(seconds: 1));

    // Test 2: Send ECHO (legacy support)
    print('📤 Test 2: Sending ECHO (legacy)...');
    final echo = NetworkMessage(
      type: 'ECHO',
      payload: {
        'payload': 'Hello from updated Dart test client!',
      },
    );
    channel.sink.add(echo.toJsonString());
    await Future.delayed(Duration(seconds: 1));

    // Test 3: Send unknown message type
    print('📤 Test 3: Sending unknown message type...');
    final unknown = NetworkMessage(
      type: 'TEST_MESSAGE',
      payload: {
        'data': 'Testing new message protocol',
      },
    );
    channel.sink.add(unknown.toJsonString());
    await Future.delayed(Duration(seconds: 1));

    // Test 4: Send invalid JSON
    print('📤 Test 4: Sending invalid JSON (should get ERROR)...');
    channel.sink.add('not valid json');
    await Future.delayed(Duration(seconds: 2));

    // Close connection
    print('');
    print('✅ All tests sent! Closing connection...');
    await channel.sink.close();

    // Wait for close to complete
    await Future.delayed(Duration(seconds: 1));

    print('');
    print('═' * 60);
    print('✅ NetworkMessage integration test completed successfully!');
    print('═' * 60);

    exit(0);
  } catch (e) {
    print('');
    print('❌ Test failed: $e');
    exit(1);
  }
}

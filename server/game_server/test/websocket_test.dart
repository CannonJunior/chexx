import 'dart:io';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Simple WebSocket test client for Chexx game server
void main() async {
  print('🧪 Testing Chexx Game Server WebSocket Connection');
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
          final data = jsonDecode(message as String);
          print('✅ Received message #$receivedMessages:');
          print('   Type: ${data['type']}');
          print('   Data: ${jsonEncode(data)}');
          print('');

          // Respond to PING with PONG
          if (data['type'] == 'PING') {
            print('📤 Sending PONG response...');
            channel.sink.add(jsonEncode({
              'type': 'PONG',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }));
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
    print('📤 Test 1: Sending PING...');
    channel.sink.add(jsonEncode({
      'type': 'PING',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));
    await Future.delayed(Duration(seconds: 1));

    // Test 2: Send ECHO
    print('📤 Test 2: Sending ECHO...');
    channel.sink.add(jsonEncode({
      'type': 'ECHO',
      'payload': 'Hello from Dart test client!',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));
    await Future.delayed(Duration(seconds: 1));

    // Test 3: Send custom message
    print('📤 Test 3: Sending custom message...');
    channel.sink.add(jsonEncode({
      'type': 'TEST_MESSAGE',
      'data': 'Testing server message routing',
    }));
    await Future.delayed(Duration(seconds: 1));

    // Test 4: Send invalid JSON
    print('📤 Test 4: Sending invalid message (should get ERROR)...');
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
    print('✅ WebSocket test completed successfully!');
    print('═' * 60);

    exit(0);
  } catch (e) {
    print('');
    print('❌ Test failed: $e');
    exit(1);
  }
}

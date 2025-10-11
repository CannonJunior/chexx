import 'dart:convert';

/// Base class for all network messages between client and server
class NetworkMessage {
  /// Message type (from MessageType constants)
  final String type;

  /// Message payload (JSON-serializable data)
  final Map<String, dynamic>? payload;

  /// Timestamp when message was created (milliseconds since epoch)
  final int timestamp;

  /// Optional message ID for request-response correlation
  final String? messageId;

  /// Optional client ID (set by server)
  final String? clientId;

  NetworkMessage({
    required this.type,
    this.payload,
    int? timestamp,
    this.messageId,
    this.clientId,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert message to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (payload != null) 'payload': payload,
      'timestamp': timestamp,
      if (messageId != null) 'messageId': messageId,
      if (clientId != null) 'clientId': clientId,
    };
  }

  /// Create message from JSON received over network
  factory NetworkMessage.fromJson(Map<String, dynamic> json) {
    return NetworkMessage(
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      messageId: json['messageId'] as String?,
      clientId: json['clientId'] as String?,
    );
  }

  /// Convert message to JSON string for WebSocket transmission
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Create message from JSON string received from WebSocket
  factory NetworkMessage.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return NetworkMessage.fromJson(json);
  }

  /// Create a response message to this message
  NetworkMessage respond({
    required String type,
    Map<String, dynamic>? payload,
  }) {
    return NetworkMessage(
      type: type,
      payload: payload,
      messageId: messageId, // Preserve message ID for correlation
      clientId: clientId,
    );
  }

  @override
  String toString() {
    return 'NetworkMessage(type: $type, messageId: $messageId, clientId: $clientId, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkMessage &&
        other.type == type &&
        other.messageId == messageId &&
        other.clientId == clientId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(type, messageId, clientId, timestamp);
  }
}

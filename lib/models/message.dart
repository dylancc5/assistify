/// Enum to identify the sender of a message
enum MessageSender { user, agent }

/// Model representing a single message/speech segment in a conversation
class Message {
  final String id;
  final String text;
  final DateTime timestamp;
  final MessageSender sender;

  Message({
    required this.id,
    required this.text,
    required this.timestamp,
    this.sender = MessageSender.user,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'sender': sender.name,
    };
  }

  /// Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sender: json['sender'] == 'agent' ? MessageSender.agent : MessageSender.user,
    );
  }
}

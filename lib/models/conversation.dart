import 'message.dart';

/// Model representing a conversation in the history
class Conversation {
  final String id;
  final DateTime timestamp;
  final String previewText;
  final Duration duration;
  final String? fullTranscript; // For future implementation
  final List<Message> messages; // Individual speech segments

  Conversation({
    required this.id,
    required this.timestamp,
    required this.previewText,
    required this.duration,
    this.fullTranscript,
    this.messages = const [],
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'previewText': previewText,
      'duration': duration.inSeconds,
      'fullTranscript': fullTranscript,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  /// Create from JSON
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      previewText: json['previewText'] as String,
      duration: Duration(seconds: json['duration'] as int),
      fullTranscript: json['fullTranscript'] as String?,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => Message.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Get formatted date/time string
  String get formattedDateTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(timestamp)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${_formatTime(timestamp)}';
    } else if (difference.inDays < 7) {
      return '${_getWeekday(timestamp)}, ${_formatTime(timestamp)}';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}, ${_formatTime(timestamp)}';
    }
  }

  /// Get formatted duration string
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes min $seconds sec';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getWeekday(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[date.weekday - 1];
  }
}

/// Model for screen recording metadata
class ScreenRecording {
  final String id;
  final String filePath;
  final DateTime timestamp;
  final Duration duration;
  final int fileSize; // in bytes

  const ScreenRecording({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.duration,
    required this.fileSize,
  });

  /// Create from JSON
  factory ScreenRecording.fromJson(Map<String, dynamic> json) {
    return ScreenRecording(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: Duration(milliseconds: json['durationMs'] as int),
      fileSize: json['fileSize'] as int,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
      'durationMs': duration.inMilliseconds,
      'fileSize': fileSize,
    };
  }

  /// Get formatted file size
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get formatted duration
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

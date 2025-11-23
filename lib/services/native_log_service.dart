import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to receive and display native iOS logs in Flutter terminal
class NativeLogService {
  static const _eventChannel = EventChannel('com.assistify/native_logs');
  StreamSubscription<dynamic>? _logSubscription;

  /// Start listening to native logs and print them to Flutter terminal
  void startListening() {
    _logSubscription?.cancel();
    _logSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic logData) {
        if (logData is Map) {
          final message = logData['message'] as String? ?? '';
          final category = logData['category'] as String? ?? '';
          final timestamp = logData['timestamp'] as double?;
          
          // Format log message for Flutter terminal
          final categoryPrefix = category.isNotEmpty ? '[$category]' : '';
          final timePrefix = timestamp != null 
              ? '[${DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt()).toString().substring(11, 19)}]'
              : '';
          
          final formattedMessage = '📱 Native$categoryPrefix$timePrefix $message';
          debugPrint(formattedMessage);
        }
      },
      onError: (error) {
        debugPrint('Error receiving native logs: $error');
      },
    );
    
    debugPrint('📱 Native log listener started');
  }

  /// Stop listening to native logs
  void stopListening() {
    _logSubscription?.cancel();
    _logSubscription = null;
    debugPrint('📱 Native log listener stopped');
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }
}


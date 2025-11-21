import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for handling speech recognition via iOS SFSpeechRecognizer
class SpeechService {
  static const _methodChannel = MethodChannel(
    'com.assistify/speech_recognition',
  );
  static const _audioLevelEventChannel = EventChannel(
    'com.assistify/audio_levels',
  );
  static const _speechEventChannel = EventChannel(
    'com.assistify/speech_events',
  );

  // Cache the broadcast streams so we don't create new ones each time
  Stream<double>? _audioLevelStream;
  Stream<Map<String, dynamic>>? _speechEventStream;

  /// Stream of audio levels (0.0 - 1.0)
  Stream<double> get audioLevelStream {
    _audioLevelStream ??= _audioLevelEventChannel.receiveBroadcastStream().map((
      level,
    ) {
      if (level is num) {
        return level.toDouble();
      }
      return 0.0;
    }).asBroadcastStream();
    return _audioLevelStream!;
  }

  /// Stream of speech events (segment complete, etc.)
  Stream<Map<String, dynamic>> get speechEventStream {
    _speechEventStream ??= _speechEventChannel.receiveBroadcastStream().map((
      event,
    ) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    }).asBroadcastStream();
    return _speechEventStream!;
  }

  /// Check speech recognition permission status
  Future<String> checkPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'checkPermission',
      );
      return result ?? 'notDetermined';
    } catch (e) {
      debugPrint('Error checking speech permission: $e');
      return 'notDetermined';
    }
  }

  /// Request speech recognition permission
  Future<String> requestPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'requestPermission',
      );
      return result ?? 'denied';
    } catch (e) {
      debugPrint('Error requesting speech permission: $e');
      return 'denied';
    }
  }

  /// Start speech recognition
  Future<bool> startListening({String? languageCode}) async {
    try {
      final langCode = languageCode ?? 'en-US';
      final result = await _methodChannel.invokeMethod<bool>('startListening', {
        'languageCode': langCode,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      return false;
    }
  }

  /// Stop speech recognition and return current transcript
  Future<String> stopListening() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('stopListening');
      return result ?? '';
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
      return '';
    }
  }

  /// End chat and get full transcript
  Future<String> endChat() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('endChat');
      return result ?? '';
    } catch (e) {
      debugPrint('Error ending chat: $e');
      return '';
    }
  }

  /// Get current transcript
  Future<String> getTranscript() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('getTranscript');
      return result ?? '';
    } catch (e) {
      debugPrint('Error getting transcript: $e');
      return '';
    }
  }

  void dispose() {
    // Clean up if needed
  }
}

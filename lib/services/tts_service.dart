import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for text-to-speech using iOS AVSpeechSynthesizer
class TTSService {
  static const _methodChannel = MethodChannel('com.assistify/tts');
  static const _audioLevelEventChannel = EventChannel('com.assistify/tts_audio_levels');

  // Cache the broadcast stream
  Stream<double>? _audioLevelStream;

  /// Stream of TTS audio levels (0.0 - 1.0)
  Stream<double> get audioLevelStream {
    _audioLevelStream ??= _audioLevelEventChannel.receiveBroadcastStream().map((level) {
      if (level is num) {
        return level.toDouble();
      }
      return 0.0;
    }).asBroadcastStream();
    return _audioLevelStream!;
  }

  /// Speak the given text
  /// [languageCode] should be 'en-US' or 'zh-Hans'
  /// [slowerSpeech] sets a slower speech rate if true
  /// [voiceId] optional voice identifier to use a specific voice
  Future<bool> speak({
    required String text,
    required String languageCode,
    bool slowerSpeech = false,
    String? voiceId,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('speak', {
        'text': text,
        'languageCode': languageCode,
        'slowerSpeech': slowerSpeech,
        'voiceId': voiceId,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error speaking text: $e');
      return false;
    }
  }

  /// Stop any current speech
  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod('stop');
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }

  /// Check if currently speaking
  Future<bool> isSpeaking() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isSpeaking');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking speech status: $e');
      return false;
    }
  }

  /// Check if enhanced voice is available for the given language
  /// Returns a map with 'hasEnhanced' (bool) and 'voiceName' (String)
  Future<Map<String, dynamic>> checkEnhancedVoice(String languageCode) async {
    // Determine voice name based on language
    final voiceName = languageCode == 'zh-Hans' ? 'Ting-Ting' : 'Siri Voice 4';

    try {
      final result = await _methodChannel.invokeMethod(
        'checkEnhancedVoice',
        {'languageCode': languageCode},
      );
      debugPrint('checkEnhancedVoice result: $result (type: ${result.runtimeType})');

      bool hasEnhanced = false;
      if (result is Map) {
        hasEnhanced = result['hasEnhanced'] == true;
      }

      return {
        'hasEnhanced': hasEnhanced,
        'voiceName': voiceName,
      };
    } catch (e) {
      debugPrint('Error checking enhanced voice: $e');
      return {'hasEnhanced': false, 'voiceName': voiceName};
    }
  }

  /// Open iOS Settings to the Spoken Content page where users can download voices
  Future<bool> openVoiceSettings() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('openVoiceSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening voice settings: $e');
      return false;
    }
  }

  /// Get all available (downloaded) voices for English and Chinese
  /// Returns a map with 'english' and 'chinese' lists of voice objects
  Future<Map<String, List<Map<String, String>>>> getAvailableVoices() async {
    try {
      final result = await _methodChannel.invokeMethod('getAvailableVoices');
      if (result is Map) {
        final englishVoices = (result['english'] as List?)
            ?.map((v) => Map<String, String>.from({
                  'id': v['id']?.toString() ?? '',
                  'name': v['name']?.toString() ?? '',
                  'quality': v['quality']?.toString() ?? 'default',
                }))
            .toList() ?? [];

        final chineseVoices = (result['chinese'] as List?)
            ?.map((v) => Map<String, String>.from({
                  'id': v['id']?.toString() ?? '',
                  'name': v['name']?.toString() ?? '',
                  'quality': v['quality']?.toString() ?? 'default',
                }))
            .toList() ?? [];

        return {
          'english': englishVoices,
          'chinese': chineseVoices,
        };
      }
      return {'english': [], 'chinese': []};
    } catch (e) {
      debugPrint('Error getting available voices: $e');
      return {'english': [], 'chinese': []};
    }
  }

  void dispose() {
    // Clean up if needed
  }
}

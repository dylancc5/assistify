import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for continuous screen capture streaming to provide visual context for Gemini
/// Captures screenshots at regular intervals and provides evenly-sampled frames for queries
class ScreenStreamService {
  static const platform = MethodChannel('com.assistify/screen_recording');

  bool _isCapturing = false;

  /// Callback when broadcast stops externally (e.g., from Control Center)
  Function? onBroadcastStopped;

  ScreenStreamService() {
    // Set up method call handler for native callbacks
    platform.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'broadcastStopped':
        debugPrint('📺 [ScreenCapture] Received broadcastStopped callback from native');
        _isCapturing = false;
        onBroadcastStopped?.call();
        break;
      default:
        debugPrint('Unknown method call: ${call.method}');
    }
  }

  /// Check if currently capturing frames
  /// Note: This only reflects the local flag. Use refreshCaptureStatus() to sync with native.
  bool get isCapturing => _isCapturing;

  /// Check if screen capture is available on this device
  Future<bool> isAvailable() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }

    try {
      final bool available = await platform.invokeMethod('isAvailable');
      return available;
    } catch (e) {
      debugPrint('Error checking capture availability: $e');
      return false;
    }
  }

  /// Show system broadcast picker for user to start system-wide screen recording
  Future<bool> showBroadcastPicker() async {
    try {
      final bool success = await platform.invokeMethod('showBroadcastPicker');
      debugPrint('📺 [ScreenCapture] Broadcast picker shown: $success');
      return success;
    } catch (e) {
      debugPrint('Error showing broadcast picker: $e');
      return false;
    }
  }

  /// Check if broadcast extension is currently active
  Future<bool> isBroadcasting() async {
    try {
      final bool broadcasting = await platform.invokeMethod('isBroadcasting');
      return broadcasting;
    } catch (e) {
      debugPrint('Error checking broadcast status: $e');
      return false;
    }
  }

  /// Start capturing screen frames
  /// Frames are captured every 500ms and stored in a buffer
  Future<bool> startCapture() async {
    try {
      if (_isCapturing) {
        debugPrint('Frame capture is already active');
        return true;
      }

      // Check if capture is available
      final available = await isAvailable();
      if (!available) {
        debugPrint('Screen capture is not available on this device');
        return false;
      }

      // Check if broadcast extension is already running
      final bool alreadyBroadcasting = await isBroadcasting();

      if (alreadyBroadcasting) {
        // Broadcast already active, just mark as capturing
        debugPrint('📺 [ScreenCapture] Broadcast extension already active');
        _isCapturing = true;
        return true;
      }

      // Call startFrameCapture which will show the broadcast picker
      // It returns false because user needs to select the broadcast extension
      await platform.invokeMethod('startFrameCapture');

      // Return true to indicate picker was shown - the app should check isBroadcasting()
      // periodically to see when user actually starts it
      debugPrint('📺 [ScreenCapture] Broadcast picker shown - waiting for user to start broadcast');
      return true;
    } on PlatformException catch (e) {
      debugPrint('Platform error starting capture: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error starting capture: $e');
      return false;
    }
  }

  /// Stop capturing screen frames
  Future<bool> stopCapture() async {
    try {
      // Check actual broadcast status from native, not just local flag
      final bool isBroadcastingNow = await isBroadcasting();

      if (!_isCapturing && !isBroadcastingNow) {
        debugPrint('Frame capture is not active');
        return true;
      }

      // Stop capture via platform channel
      final bool success = await platform.invokeMethod('stopFrameCapture');

      if (success) {
        _isCapturing = false;
      }

      return success;
    } on PlatformException catch (e) {
      debugPrint('Platform error stopping capture: ${e.code} - ${e.message}');
      _isCapturing = false;
      return false;
    } catch (e) {
      debugPrint('Error stopping capture: $e');
      _isCapturing = false;
      return false;
    }
  }

  /// Get evenly-sampled screenshots from the buffer
  /// Returns up to [maxSamples] frames distributed evenly across the buffer
  /// Automatically clears the buffer after sampling
  Future<List<Uint8List>> sampleScreenshots({int maxSamples = 10}) async {
    try {
      final List<dynamic>? result = await platform.invokeMethod(
        'sampleScreenshots',
        {'maxSamples': maxSamples},
      );

      if (result == null || result.isEmpty) {
        return [];
      }

      // Convert to List<Uint8List>
      final screenshots = result.map((data) {
        if (data is Uint8List) {
          return data;
        } else if (data is List<int>) {
          return Uint8List.fromList(data);
        }
        return Uint8List(0);
      }).where((data) => data.isNotEmpty).toList();

      // Log which mode provided the frames
      final bool isBroadcasting = await platform.invokeMethod('isBroadcasting');
      if (isBroadcasting) {
        debugPrint('📺 [ScreenCapture] Sampled ${screenshots.length} frames from BROADCAST EXTENSION');
      } else {
        debugPrint('📱 [ScreenCapture] Sampled ${screenshots.length} frames from IN-APP buffer');
      }

      // Clear buffer after sampling
      await clearBuffer();

      return screenshots;
    } on PlatformException catch (e) {
      debugPrint('Platform error sampling screenshots: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error sampling screenshots: $e');
      return [];
    }
  }

  /// Clear all screenshots from the buffer
  Future<bool> clearBuffer() async {
    try {
      final bool success = await platform.invokeMethod('clearBuffer');
      return success;
    } on PlatformException catch (e) {
      debugPrint('Platform error clearing buffer: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error clearing buffer: $e');
      return false;
    }
  }

  /// Get the current number of screenshots in the buffer
  Future<int> getBufferCount() async {
    try {
      final int count = await platform.invokeMethod('getBufferCount');
      return count;
    } catch (e) {
      debugPrint('Error getting buffer count: $e');
      return 0;
    }
  }

  /// Check capture status from platform
  Future<void> refreshCaptureStatus() async {
    try {
      final bool isCapturingNative = await platform.invokeMethod('isCapturing');
      _isCapturing = isCapturingNative;
    } catch (e) {
      debugPrint('Error refreshing capture status: $e');
    }
  }

  /// Toggle capture state
  Future<bool> toggleCapture() async {
    if (_isCapturing) {
      return await stopCapture();
    } else {
      return await startCapture();
    }
  }

  /// Set broadcast context for background Gemini processing
  /// This includes chat history, conversation IDs, and API credentials
  Future<bool> setBroadcastContext({
    required List<Map<String, String>> chatHistory,
    required List<String> conversationIds,
    required String geminiApiKey,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    try {
      final bool success = await platform.invokeMethod('setBroadcastContext', {
        'chatHistory': chatHistory,
        'conversationIds': conversationIds,
        'geminiApiKey': geminiApiKey,
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
      });
      debugPrint('📺 [ScreenCapture] Broadcast context set: $success');
      return success;
    } catch (e) {
      debugPrint('Error setting broadcast context: $e');
      return false;
    }
  }

  /// Check if there's a Gemini response ready from background processing
  Future<Map<String, dynamic>?> checkGeminiResponse() async {
    try {
      final result = await platform.invokeMethod('checkGeminiResponse');
      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      debugPrint('Error checking Gemini response: $e');
      return null;
    }
  }

  /// Clear the Gemini response after processing
  Future<bool> clearGeminiResponse() async {
    try {
      final bool success = await platform.invokeMethod('clearGeminiResponse');
      return success;
    } catch (e) {
      debugPrint('Error clearing Gemini response: $e');
      return false;
    }
  }

  /// Cleanup resources
  void dispose() {
    if (_isCapturing) {
      stopCapture();
    }
  }
}

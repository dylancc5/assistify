import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for continuous screen capture streaming to provide visual context for Gemini
/// Captures screenshots at regular intervals and provides evenly-sampled frames for queries
class ScreenStreamService {
  static const platform = MethodChannel('com.assistify/screen_recording');

  bool _isCapturing = false;

  /// Check if currently capturing frames
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

      // Start frame capture via platform channel
      final bool success = await platform.invokeMethod('startFrameCapture');

      if (success) {
        _isCapturing = true;
      }

      return success;
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
      if (!_isCapturing) {
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

  /// Cleanup resources
  void dispose() {
    if (_isCapturing) {
      stopCapture();
    }
  }
}

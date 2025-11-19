import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Service for handling screen recording using platform channels
/// iOS: ReplayKit
/// Android: MediaProjection (to be implemented)
class RecordingService {
  static const platform = MethodChannel('com.assistify/screen_recording');

  bool _isRecording = false;
  DateTime? _recordingStartTime;

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get recording duration
  Duration? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Check if screen recording is available on this device
  Future<bool> isAvailable() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }

    try {
      final bool available = await platform.invokeMethod('isAvailable');
      return available;
    } catch (e) {
      print('Error checking recording availability: $e');
      return false;
    }
  }

  /// Start screen recording
  /// On iOS, this will trigger the ReplayKit permission dialog if not already granted
  Future<bool> startRecording() async {
    try {
      if (_isRecording) {
        print('Screen recording is already active');
        return true;
      }

      // Check if recording is available
      final available = await isAvailable();
      if (!available) {
        print('Screen recording is not available on this device');
        return false;
      }

      // Start recording via platform channel
      final bool success = await platform.invokeMethod('startRecording');

      if (success) {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        print('Screen recording started successfully');
      }

      return success;
    } on PlatformException catch (e) {
      print('Platform error starting recording: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  /// Stop screen recording and return recording info
  Future<Map<String, dynamic>?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('Screen recording is not active');
        return null;
      }

      // Stop recording via platform channel
      final dynamic result = await platform.invokeMethod('stopRecording');

      _isRecording = false;
      _recordingStartTime = null;
      print('Screen recording stopped successfully');

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      return null;
    } on PlatformException catch (e) {
      print('Platform error stopping recording: ${e.code} - ${e.message}');
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    }
  }

  /// Check recording status from platform
  Future<void> refreshRecordingStatus() async {
    try {
      final bool isRecordingNative = await platform.invokeMethod('isRecording');
      _isRecording = isRecordingNative;

      if (!_isRecording) {
        _recordingStartTime = null;
      }
    } catch (e) {
      print('Error refreshing recording status: $e');
    }
  }

  /// Toggle recording state
  Future<Map<String, dynamic>?> toggleRecording() async {
    if (_isRecording) {
      return await stopRecording();
    } else {
      final success = await startRecording();
      return success ? {} : null;
    }
  }

  /// Show system broadcast picker for system-wide screen recording
  /// This allows recording outside the app (like Discord screen share)
  Future<bool> showBroadcastPicker() async {
    try {
      final bool success = await platform.invokeMethod('showBroadcastPicker');
      return success;
    } on PlatformException catch (e) {
      print('Platform error showing broadcast picker: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Error showing broadcast picker: $e');
      return false;
    }
  }

  /// Check if broadcast extension is currently active
  Future<bool> isBroadcasting() async {
    try {
      final bool broadcasting = await platform.invokeMethod('isBroadcasting');
      return broadcasting;
    } catch (e) {
      print('Error checking broadcast status: $e');
      return false;
    }
  }

  /// Cleanup resources
  void dispose() {
    if (_isRecording) {
      stopRecording();
    }
  }
}

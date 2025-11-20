import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../services/recording_service.dart';
import '../services/storage_service.dart';
import '../models/preferences.dart';
import '../models/conversation.dart';
import '../models/screen_recording.dart';
import '../constants/colors.dart';
import '../widgets/permission_modal.dart';

/// Voice agent states
enum VoiceAgentState { resting, listening, thinking, speaking }

/// Main app state provider
class AppStateProvider extends ChangeNotifier {
  final PermissionService _permissionService;
  final RecordingService _recordingService;
  final StorageService _storageService;

  // Permission states
  PermissionState _screenRecordingPermission = PermissionState.notDetermined;
  PermissionState _microphonePermission = PermissionState.notDetermined;
  bool _hasCompletedOnboarding = false;

  // UI states
  bool _isScreenRecordingActive = false;
  bool _isMicrophoneMuted = false;
  final VoiceAgentState _voiceAgentState = VoiceAgentState.resting;

  // User preferences
  UserPreferences _preferences = const UserPreferences();

  // Conversation history
  List<Conversation> _conversations = [];

  // Screen recording history
  List<ScreenRecording> _screenRecordings = [];

  AppStateProvider({
    PermissionService? permissionService,
    RecordingService? recordingService,
    StorageService? storageService,
  }) : _permissionService = permissionService ?? PermissionService(),
       _recordingService = recordingService ?? RecordingService(),
       _storageService = storageService ?? StorageService();

  // Getters
  PermissionState get screenRecordingPermission => _screenRecordingPermission;
  PermissionState get microphonePermission => _microphonePermission;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isScreenRecordingActive => _isScreenRecordingActive;
  bool get isMicrophoneMuted => _isMicrophoneMuted;
  VoiceAgentState get voiceAgentState => _voiceAgentState;
  UserPreferences get preferences => _preferences;
  List<Conversation> get conversations => _conversations;
  List<ScreenRecording> get screenRecordings => _screenRecordings;

  /// Initialize app state from storage
  Future<void> initialize() async {
    _hasCompletedOnboarding = await _storageService.hasCompletedOnboarding();
    _preferences = await _storageService.loadPreferences();
    _conversations = await _storageService.loadConversations();
    _screenRecordings = await _storageService.loadScreenRecordings();

    // Check permissions
    _microphonePermission = await _permissionService
        .checkMicrophonePermission();

    // Load screen recording permission from storage
    final screenRecordingGranted = await _storageService
        .getScreenRecordingPermission();
    if (screenRecordingGranted != null) {
      _screenRecordingPermission = screenRecordingGranted
          ? PermissionState.granted
          : PermissionState.denied;
    }

    notifyListeners();
  }

  /// Request screen recording permission
  /// Note: For iOS ReplayKit, the actual permission dialog appears when you
  /// call startRecording() for the first time. This method just marks the
  /// permission as granted in storage for UI purposes.
  Future<bool> requestScreenRecordingPermission() async {
    // Mark as granted - the real permission will be requested by ReplayKit
    // when startRecording() is called in RecordingService
    _screenRecordingPermission = PermissionState.granted;
    await _storageService.saveScreenRecordingPermission(true);
    notifyListeners();
    return true;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    _microphonePermission = await _permissionService
        .requestMicrophonePermission();
    await _storageService.saveMicrophonePermission(
      _microphonePermission == PermissionState.granted,
    );
    notifyListeners();
    return _microphonePermission == PermissionState.granted;
  }

  /// Refresh microphone permission status
  Future<void> refreshMicrophonePermission() async {
    _microphonePermission = await _permissionService
        .checkMicrophonePermission();
    notifyListeners();
  }

  /// Check if microphone permission is permanently denied
  Future<bool> isMicrophonePermanentlyDenied() async {
    return await _permissionService.isMicrophonePermanentlyDenied();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await _permissionService.openAppSettings();
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    await _storageService.setOnboardingComplete(true);
    notifyListeners();
  }

  /// Toggle screen recording
  Future<void> toggleScreenRecording(BuildContext? context) async {
    if (_isScreenRecordingActive) {
      final recordingInfo = await _recordingService.stopRecording();
      _isScreenRecordingActive = false;

      // Save the recording to history if we got valid info
      if (recordingInfo != null && recordingInfo['filePath'] != null) {
        final recording = ScreenRecording(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: recordingInfo['filePath'] as String,
          timestamp: DateTime.now(),
          duration: Duration(milliseconds: recordingInfo['durationMs'] as int? ?? 0),
          fileSize: recordingInfo['fileSize'] as int? ?? 0,
        );
        await _storageService.addScreenRecording(recording);
        _screenRecordings = await _storageService.loadScreenRecordings();
      }

      notifyListeners();
      return;
    }

    // Check if we have permission before starting
    // Refresh permission status from storage
    final screenRecordingGranted = await _storageService
        .getScreenRecordingPermission();
    if (screenRecordingGranted != null) {
      _screenRecordingPermission = screenRecordingGranted
          ? PermissionState.granted
          : PermissionState.denied;
    }

    if (_screenRecordingPermission != PermissionState.granted) {
      if (context != null && context.mounted) {
        await _showScreenRecordingPermissionModal(context);
        // Re-check permission after modal
        final screenRecordingGrantedAfter = await _storageService
            .getScreenRecordingPermission();
        if (screenRecordingGrantedAfter != null) {
          _screenRecordingPermission = screenRecordingGrantedAfter
              ? PermissionState.granted
              : PermissionState.denied;
        }
      }
      
      // If still not granted, don't start recording
      if (_screenRecordingPermission != PermissionState.granted) {
        return;
      }
    }

    final success = await _recordingService.startRecording();
    _isScreenRecordingActive = success;
    notifyListeners();
  }

  /// Toggle microphone mute
  Future<void> toggleMicrophoneMute(BuildContext? context) async {
    // If trying to unmute, check permission first
    if (_isMicrophoneMuted) {
      // Refresh permission status first
      await refreshMicrophonePermission();
      
      if (_microphonePermission != PermissionState.granted) {
        if (context != null && context.mounted) {
          await _showMicrophonePermissionModal(context);
          // Permission status is already refreshed in the modal
        }
        
        // If still not granted, don't unmute
        if (_microphonePermission != PermissionState.granted) {
          return;
        }
      }
    }

    _isMicrophoneMuted = !_isMicrophoneMuted;
    notifyListeners();
  }

  /// Show screen recording permission modal
  Future<void> _showScreenRecordingPermissionModal(BuildContext context) async {
    final completer = Completer<void>();
    bool permissionRequested = false;

    await PermissionModal.show(
      context: context,
      icon: Icons.screen_share,
      iconColor: AppColors.primaryBlue,
      title: 'Assistify needs to see your screen',
      description:
          'This helps me understand what you\'re looking at and provide better assistance',
      buttonText: 'Allow Screen Recording',
      buttonColor: AppColors.primaryBlue,
      onButtonPressed: () async {
        if (permissionRequested) return;
        permissionRequested = true;

        // Dismiss our modal first
        if (context.mounted) {
          PermissionModal.dismiss(context);
        }

        // Wait a brief moment for modal to dismiss
        await Future.delayed(const Duration(milliseconds: 200));

        // Request permission
        await requestScreenRecordingPermission();

        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await completer.future;
  }

  /// Show microphone permission modal
  Future<void> _showMicrophonePermissionModal(BuildContext context) async {
    final completer = Completer<void>();
    bool permissionRequested = false;

    // Check if permission is permanently denied
    final isPermanentlyDenied = await isMicrophonePermanentlyDenied();

    await PermissionModal.show(
      context: context,
      icon: Icons.mic,
      iconColor: AppColors.primaryBlue,
      title: 'Assistify needs microphone access',
      description: isPermanentlyDenied
          ? 'Microphone permission is permanently denied.\nPlease enable in settings.'
          : 'This allows me to hear your questions and respond to you',
      buttonText: isPermanentlyDenied ? 'OPEN SETTINGS' : 'Allow Microphone',
      buttonColor: AppColors.primaryBlue,
      onButtonPressed: () async {
        if (permissionRequested) return;
        permissionRequested = true;

        if (isPermanentlyDenied) {
          // Open app settings
          await openAppSettings();
          if (context.mounted) {
            PermissionModal.dismiss(context);
          }
        } else {
          // Request permission FIRST - this will show the system dialog on iOS
          // The system dialog will appear on top of our modal
          await requestMicrophonePermission();
          
          // Wait a moment for the system dialog to appear
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Now dismiss our modal (system dialog is already showing on top)
          if (context.mounted) {
            PermissionModal.dismiss(context);
          }
          
          // Wait for user to respond to system dialog
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // Refresh permission status after request
          await refreshMicrophonePermission();
        }

        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await completer.future;
  }

  /// Update user preferences
  Future<void> updatePreferences(UserPreferences preferences) async {
    _preferences = preferences;
    await _storageService.savePreferences(preferences);
    notifyListeners();
  }

  /// Add conversation to history
  Future<void> addConversation(Conversation conversation) async {
    await _storageService.addConversation(conversation);
    _conversations = await _storageService.loadConversations();
    notifyListeners();
  }

  /// Delete conversation from history
  Future<void> deleteConversation(String id) async {
    await _storageService.deleteConversation(id);
    _conversations = await _storageService.loadConversations();
    notifyListeners();
  }

  /// Delete screen recording from history
  Future<void> deleteScreenRecording(String id) async {
    // First, find the recording to get the file path
    final recording = _screenRecordings.firstWhere(
      (r) => r.id == id,
      orElse: () => ScreenRecording(
        id: '',
        filePath: '',
        timestamp: DateTime.now(),
        duration: Duration.zero,
        fileSize: 0,
      ),
    );

    // Delete the file from storage
    if (recording.filePath.isNotEmpty) {
      try {
        final file = File(recording.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting recording file: $e');
      }
    }

    // Remove from database
    await _storageService.deleteScreenRecording(id);
    _screenRecordings = await _storageService.loadScreenRecordings();
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingService.dispose();
    super.dispose();
  }
}

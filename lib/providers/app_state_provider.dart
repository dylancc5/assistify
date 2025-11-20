import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../services/recording_service.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';
import '../models/preferences.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/screen_recording.dart';
import '../constants/colors.dart';
import '../utils/localization_helper.dart';
import '../widgets/permission_modal.dart';

/// Voice agent states
enum VoiceAgentState { resting, listening, thinking, speaking }

/// Main app state provider
class AppStateProvider extends ChangeNotifier {
  final PermissionService _permissionService;
  final RecordingService _recordingService;
  final StorageService _storageService;
  final SpeechService _speechService;
  final GeminiService _geminiService;
  final TTSService _ttsService;

  // Permission states
  PermissionState _screenRecordingPermission = PermissionState.notDetermined;
  PermissionState _microphonePermission = PermissionState.notDetermined;
  PermissionState _speechPermission = PermissionState.notDetermined;
  bool _hasCompletedOnboarding = false;

  // UI states
  bool _isScreenRecordingActive = false;
  bool _isMicrophoneMuted = false; // Start unmuted by default
  bool _isChatActive = false;
  double _audioLevel = 0.0;
  final VoiceAgentState _voiceAgentState = VoiceAgentState.resting;

  // User preferences
  UserPreferences _preferences = const UserPreferences();

  // Conversation history
  List<Conversation> _conversations = [];

  // Screen recording history
  List<ScreenRecording> _screenRecordings = [];

  // Audio level stream subscription
  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<Map<String, dynamic>>? _speechEventSubscription;
  DateTime? _chatStartTime;

  // Message tracking
  List<Message> _currentMessages = [];
  DateTime? _currentMessageStartTime;

  // Gemini response tracking
  String? _geminiResponse;
  bool _isGeminiLoading = false;

  // Typewriter animation
  Timer? _typewriterTimer;
  int _displayedResponseLength = 0;

  // Enhanced voice prompt tracking
  bool _shouldPromptForEnhancedVoice = false;
  String _missingVoiceName = '';

  // Getters for enhanced voice prompt
  bool get shouldPromptForEnhancedVoice => _shouldPromptForEnhancedVoice;
  String get missingVoiceName => _missingVoiceName;

  AppStateProvider({
    PermissionService? permissionService,
    RecordingService? recordingService,
    StorageService? storageService,
    SpeechService? speechService,
    GeminiService? geminiService,
    TTSService? ttsService,
  }) : _permissionService = permissionService ?? PermissionService(),
       _recordingService = recordingService ?? RecordingService(),
       _storageService = storageService ?? StorageService(),
       _speechService = speechService ?? SpeechService(),
       _geminiService = geminiService ?? GeminiService(),
       _ttsService = ttsService ?? TTSService();

  // Getters
  PermissionState get screenRecordingPermission => _screenRecordingPermission;
  PermissionState get microphonePermission => _microphonePermission;
  PermissionState get speechPermission => _speechPermission;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isScreenRecordingActive => _isScreenRecordingActive;
  bool get isMicrophoneMuted => _isMicrophoneMuted;
  bool get isChatActive => _isChatActive;
  double get audioLevel => _audioLevel;
  VoiceAgentState get voiceAgentState => _voiceAgentState;
  UserPreferences get preferences => _preferences;
  List<Conversation> get conversations => _conversations;
  List<ScreenRecording> get screenRecordings => _screenRecordings;
  String? get geminiResponse => _geminiResponse;
  bool get isGeminiLoading => _isGeminiLoading;

  /// Get the displayed portion of the response (for typewriter effect)
  String? get displayedGeminiResponse {
    if (_geminiResponse == null) return null;
    if (_displayedResponseLength >= _geminiResponse!.length) {
      return _geminiResponse;
    }
    return _geminiResponse!.substring(0, _displayedResponseLength);
  }

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

    // Initialize Gemini service
    await _geminiService.initialize();

    // Show voice recommendation on first launch
    final hasSeenVoicePrompt = await _storageService.hasSeenVoiceRecommendation();
    if (!hasSeenVoicePrompt) {
      _shouldPromptForEnhancedVoice = true;
      _missingVoiceName = _preferences.languageCode == 'zh-Hans'
          ? 'Lilian (Premium)'
          : 'Siri Voice 4';
    }

    notifyListeners();
  }

  /// Clear the enhanced voice prompt flag
  Future<void> dismissEnhancedVoicePrompt() async {
    _shouldPromptForEnhancedVoice = false;
    await _storageService.setVoiceRecommendationSeen(true);
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
  /// Note: Screen recording can only be started when chat is active
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
          duration: Duration(
            milliseconds: recordingInfo['durationMs'] as int? ?? 0,
          ),
          fileSize: recordingInfo['fileSize'] as int? ?? 0,
        );
        await _storageService.addScreenRecording(recording);
        _screenRecordings = await _storageService.loadScreenRecordings();
      }

      notifyListeners();
      return;
    }

    // Screen recording can only be started when chat is active
    if (!_isChatActive) {
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

  /// Toggle microphone mute (only works when chat is active)
  Future<void> toggleMicrophoneMute(BuildContext? context) async {
    // Only allow mute toggle when chat is active
    if (!_isChatActive) {
      return;
    }

    if (_isMicrophoneMuted) {
      // Unmuting - restart speech recognition
      final started = await _speechService.startListening(
        languageCode: _preferences.languageCode,
      );
      if (started) {
        _isMicrophoneMuted = false;
        _currentMessageStartTime = DateTime.now();

        // Listen to audio level stream
        _audioLevelSubscription?.cancel();
        _audioLevelSubscription = _speechService.audioLevelStream.listen((
          level,
        ) {
          _audioLevel = level;
          notifyListeners();
        });
      }
    } else {
      // Muting - just stop speech recognition, workflow handles silence
      await _speechService.stopListening();

      _isMicrophoneMuted = true;
      _audioLevel = 0.0;
      _audioLevelSubscription?.cancel();
      _audioLevelSubscription = null;
    }

    notifyListeners();
  }

  /// Start a new chat session
  Future<void> startChat(BuildContext? context) async {
    if (_isChatActive) return;

    // Check microphone permission
    await refreshMicrophonePermission();
    if (_microphonePermission != PermissionState.granted) {
      if (context != null && context.mounted) {
        await _showMicrophonePermissionModal(context);
      }
      if (_microphonePermission != PermissionState.granted) {
        return;
      }
    }

    // Check speech recognition permission
    final speechStatus = await _speechService.checkPermission();
    if (speechStatus != 'granted') {
      final result = await _speechService.requestPermission();
      if (result != 'granted') {
        return;
      }
    }
    _speechPermission = PermissionState.granted;

    // Start speech recognition
    final started = await _speechService.startListening(
      languageCode: _preferences.languageCode,
    );
    if (started) {
      _isChatActive = true;
      _chatStartTime = DateTime.now();
      _isMicrophoneMuted = false;

      // Initialize message tracking
      _currentMessages = [];
      _currentMessageStartTime = DateTime.now();

      // Listen to audio level stream
      _audioLevelSubscription?.cancel();
      _audioLevelSubscription = _speechService.audioLevelStream.listen((level) {
        _audioLevel = level;
        notifyListeners();
      });

      // Listen to speech events (segment complete on silence)
      _speechEventSubscription?.cancel();
      _speechEventSubscription = _speechService.speechEventStream.listen((event) {
        _handleSpeechEvent(event);
      });
    }

    notifyListeners();
  }

  /// Handle speech events from native side
  void _handleSpeechEvent(Map<String, dynamic> event) {
    final eventType = event['event'] as String?;

    if (eventType == 'segmentComplete') {
      final text = event['text'] as String?;
      if (text != null && text.isNotEmpty) {
        // Stop any TTS playback when user starts speaking
        _ttsService.stop();
        // Create a message for this completed segment
        final message = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          timestamp: _currentMessageStartTime ?? DateTime.now(),
        );
        _currentMessages.add(message);

        // Reset message start time for next segment
        _currentMessageStartTime = DateTime.now();

        // Send to Gemini and get response
        _sendToGemini(text);

        // Restart speech recognition for next message
        if (_isChatActive && !_isMicrophoneMuted) {
          // Stop current session first, then restart
          _speechService.stopListening().then((_) {
            if (_isChatActive && !_isMicrophoneMuted) {
              _speechService.startListening(
                languageCode: _preferences.languageCode,
              );
            }
          });
        }

        notifyListeners();
      }
    } else if (eventType == 'recognitionStopped') {
      // Recognition stopped unexpectedly, try to restart if chat is still active
      if (_isChatActive && !_isMicrophoneMuted) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (_isChatActive && !_isMicrophoneMuted) {
            await _speechService.startListening(
              languageCode: _preferences.languageCode,
            );
          }
        });
      }
    }
  }

  /// Start typewriter animation for response
  void _startTypewriterAnimation() {
    _typewriterTimer?.cancel();
    _displayedResponseLength = 0;

    if (_geminiResponse == null || _geminiResponse!.isEmpty) return;

    // Animate at ~40 characters per second
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (_geminiResponse == null || _displayedResponseLength >= _geminiResponse!.length) {
        timer.cancel();
        return;
      }
      _displayedResponseLength += 1;
      notifyListeners();
    });
  }

  /// Send message to Gemini and update response
  /// This runs asynchronously without blocking the speech recognition
  void _sendToGemini(String message) {
    if (!_geminiService.isInitialized) return;

    _isGeminiLoading = true;
    _typewriterTimer?.cancel();
    _displayedResponseLength = 0;
    notifyListeners();

    // Run async without awaiting - allows speech recognition to continue
    _geminiService.sendMessage(message).then((response) async {
      _geminiResponse = response;
      _isGeminiLoading = false;

      // Start typewriter animation
      _startTypewriterAnimation();

      // Add Gemini response as a message in the conversation
      if (response != null && response.isNotEmpty) {
        final agentMessage = Message(
          id: '${DateTime.now().millisecondsSinceEpoch}_agent',
          text: response,
          timestamp: DateTime.now(),
          sender: MessageSender.agent,
        );
        _currentMessages.add(agentMessage);

        // Stop speech recognition while TTS is speaking to avoid self-listening
        if (_isChatActive && !_isMicrophoneMuted) {
          await _speechService.stopListening();
          _audioLevelSubscription?.cancel();
          _audioLevel = 0.0;
          notifyListeners();
        }

        // Speak the response using TTS
        await _ttsService.speak(
          text: response,
          languageCode: _preferences.languageCode,
          slowerSpeech: _preferences.slowerSpeechEnabled,
        );

        // Restart speech recognition after TTS finishes
        if (_isChatActive && !_isMicrophoneMuted) {
          final started = await _speechService.startListening(
            languageCode: _preferences.languageCode,
          );
          if (started) {
            _audioLevelSubscription?.cancel();
            _audioLevelSubscription = _speechService.audioLevelStream.listen((level) {
              _audioLevel = level;
              notifyListeners();
            });
          }
        }
      }

      notifyListeners();
    }).catchError((error) {
      _isGeminiLoading = false;
      notifyListeners();
    });
  }

  /// End chat and save conversation to history
  Future<void> endChat() async {
    // Stop any TTS playback
    _ttsService.stop();

    // Stop screen recording if active (screen recording only works during chat)
    if (_isScreenRecordingActive) {
      final recordingInfo = await _recordingService.stopRecording();
      _isScreenRecordingActive = false;

      // Save the recording to history if we got valid info
      if (recordingInfo != null && recordingInfo['filePath'] != null) {
        final recording = ScreenRecording(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filePath: recordingInfo['filePath'] as String,
          timestamp: DateTime.now(),
          duration: Duration(
            milliseconds: recordingInfo['durationMs'] as int? ?? 0,
          ),
          fileSize: recordingInfo['fileSize'] as int? ?? 0,
        );
        await _storageService.addScreenRecording(recording);
        _screenRecordings = await _storageService.loadScreenRecordings();
      }
    }

    // Stop listening and get final transcript
    final transcript = await _speechService.endChat();

    // Save the final transcript as a message
    if (transcript.isNotEmpty) {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: transcript,
        timestamp: _currentMessageStartTime ?? DateTime.now(),
      );
      _currentMessages.add(message);
    }

    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;
    _speechEventSubscription?.cancel();
    _speechEventSubscription = null;
    _audioLevel = 0.0;
    _isMicrophoneMuted = true;

    // Save conversation if there are messages
    if (_currentMessages.isNotEmpty && _chatStartTime != null) {
      final duration = DateTime.now().difference(_chatStartTime!);
      // Build full transcript from all messages
      final fullTranscript = _currentMessages.map((m) => m.text).join(' ');
      final conversation = Conversation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: _chatStartTime!,
        previewText: fullTranscript.length > 100
            ? '${fullTranscript.substring(0, 100)}...'
            : fullTranscript,
        duration: duration,
        fullTranscript: fullTranscript,
        messages: List.from(_currentMessages),
      );
      await addConversation(conversation);
    }

    // Reset message tracking
    _currentMessages = [];
    _currentMessageStartTime = null;

    // Reset Gemini response and chat session
    _geminiResponse = null;
    _isGeminiLoading = false;
    _typewriterTimer?.cancel();
    _displayedResponseLength = 0;
    _geminiService.resetChat();

    _isChatActive = false;
    _chatStartTime = null;
    notifyListeners();
  }

  /// Show screen recording permission modal
  Future<void> _showScreenRecordingPermissionModal(BuildContext context) async {
    final completer = Completer<void>();
    bool permissionRequested = false;
    final l10n = LocalizationHelper.of(context);

    await PermissionModal.show(
      context: context,
      icon: Icons.screen_share,
      iconColor: AppColors.primaryBlue,
      title: l10n.assistifyNeedsToSeeYourScreen,
      description: l10n.thisHelpsMeUnderstandWhatYouAreLookingAt,
      buttonText: l10n.allowScreenSharing,
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
    if (!context.mounted) return;
    final completer = Completer<void>();
    bool permissionRequested = false;
    final l10n = LocalizationHelper.of(context);

    // Check if permission is permanently denied
    final isPermanentlyDenied = await isMicrophonePermanentlyDenied();

    if (!context.mounted) return;

    await PermissionModal.show(
      context: context,
      icon: Icons.mic,
      iconColor: AppColors.primaryBlue,
      title: l10n.assistifyNeedsMicrophoneAccess,
      description: isPermanentlyDenied
          ? l10n.microphonePermissionIsPermanentlyDenied
          : l10n.thisAllowsMeToHearYourQuestionsAndRespondToYou,
      buttonText: isPermanentlyDenied
          ? l10n.openSettings
          : l10n.allowMicrophone,
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
    final languageChanged =
        _preferences.useSimplifiedChinese != preferences.useSimplifiedChinese;
    _preferences = preferences;
    await _storageService.savePreferences(preferences);

    // If language changed and chat is active, restart speech recognition with new language
    if (languageChanged && _isChatActive && !_isMicrophoneMuted) {
      debugPrint(
        'Language changed to: ${_preferences.languageCode}, restarting speech recognition',
      );
      // Stop current recognition
      await _speechService.stopListening();

      // Small delay to ensure stop completes
      await Future.delayed(const Duration(milliseconds: 100));

      // Restart with new language
      final started = await _speechService.startListening(
        languageCode: _preferences.languageCode,
      );
      if (!started) {
        debugPrint(
          'Warning: Failed to restart speech recognition with new language',
        );
      } else {
        debugPrint(
          'Successfully restarted speech recognition with language: ${_preferences.languageCode}',
        );
      }
    }

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

  /// Clear all conversations from history
  Future<void> clearAllConversations() async {
    await _storageService.saveConversations([]);
    _conversations = [];
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
        debugPrint('Error deleting recording file: $e');
      }
    }

    // Remove from database
    await _storageService.deleteScreenRecording(id);
    _screenRecordings = await _storageService.loadScreenRecordings();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioLevelSubscription?.cancel();
    _speechEventSubscription?.cancel();
    _typewriterTimer?.cancel();
    _recordingService.dispose();
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}

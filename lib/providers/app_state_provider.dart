import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';
import '../services/screen_stream_service.dart';
import '../services/embedding_service.dart';
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
class AppStateProvider extends ChangeNotifier with WidgetsBindingObserver {
  final PermissionService _permissionService;
  final StorageService _storageService;
  final SpeechService _speechService;
  final GeminiService _geminiService;
  final TTSService _ttsService;
  final ScreenStreamService _screenStreamService;
  final EmbeddingService _embeddingService;

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
  VoiceAgentState _voiceAgentState = VoiceAgentState.resting;

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

  // Audio level tracking for stats
  List<double> _audioLevelSamples = [];
  List<double> _ttsAudioLevelSamples = [];
  StreamSubscription<double>? _ttsAudioLevelSubscription;

  // Flag to ignore STT input while agent is speaking
  bool _ignoringSTT = false;

  // Getters for enhanced voice prompt
  bool get shouldPromptForEnhancedVoice => _shouldPromptForEnhancedVoice;
  String get missingVoiceName => _missingVoiceName;

  AppStateProvider({
    PermissionService? permissionService,
    StorageService? storageService,
    SpeechService? speechService,
    GeminiService? geminiService,
    TTSService? ttsService,
    ScreenStreamService? screenStreamService,
    EmbeddingService? embeddingService,
  }) : _permissionService = permissionService ?? PermissionService(),
       _storageService = storageService ?? StorageService(),
       _speechService = speechService ?? SpeechService(),
       _geminiService = geminiService ?? GeminiService(),
       _ttsService = ttsService ?? TTSService(),
       _screenStreamService = screenStreamService ?? ScreenStreamService(),
       _embeddingService = embeddingService ?? EmbeddingService() {
    // Set up callback for when broadcast stops externally
    _screenStreamService.onBroadcastStopped = _onBroadcastStopped;
  }

  /// Called when broadcast extension stops externally (e.g., from Control Center)
  void _onBroadcastStopped() {
    debugPrint('📺 [AppState] Broadcast stopped externally, updating UI state');
    _isScreenRecordingActive = false;
    notifyListeners();
  }

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
    // Register lifecycle observer for background handling
    WidgetsBinding.instance.addObserver(this);

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

    // Initialize embedding service for RAG
    await _embeddingService.initialize();

    // Show voice recommendation on first launch
    final hasSeenVoicePrompt = await _storageService
        .hasSeenVoiceRecommendation();
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

  /// Toggle screen recording/capture
  /// Note: Screen capture can only be started when chat is active
  Future<void> toggleScreenRecording(BuildContext? context) async {
    if (_isScreenRecordingActive) {
      // Stop frame capture for Gemini context
      await _screenStreamService.stopCapture();
      _isScreenRecordingActive = false;
      notifyListeners();
      return;
    }

    // Screen capture can only be started when chat is active
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

      // If still not granted, don't start capture
      if (_screenRecordingPermission != PermissionState.granted) {
        return;
      }
    }

    // Start frame capture for Gemini context
    final success = await _screenStreamService.startCapture();
    _isScreenRecordingActive = success;

    // Set broadcast context for background Gemini processing
    if (success) {
      await _updateBroadcastContext();
    }

    notifyListeners();
  }

  /// Update the broadcast context with current chat history and credentials
  Future<void> _updateBroadcastContext() async {
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      debugPrint('⚠️ [BroadcastContext] Cannot set context - missing Gemini API key');
      return;
    }

    // Get chat history from current session messages (last 10)
    final fullHistory = _currentMessages.map((msg) => {
      'role': msg.sender == MessageSender.user ? 'user' : 'assistant',
      'content': msg.text,
    }).toList();
    final chatHistory = fullHistory.length > 10
        ? fullHistory.sublist(fullHistory.length - 10)
        : fullHistory;

    // Get conversation IDs for RAG
    final conversationIds = _conversations.map((c) => c.id).toList();

    debugPrint('🤖 [BroadcastContext] Setting context for background Gemini:');
    debugPrint('   - Chat history: ${chatHistory.length} messages');
    debugPrint('   - Conversation IDs: ${conversationIds.length} for RAG');
    debugPrint('   - Supabase URL: ${supabaseUrl != null && supabaseUrl.isNotEmpty ? "✓" : "✗"}');

    await _screenStreamService.setBroadcastContext(
      chatHistory: chatHistory,
      conversationIds: conversationIds,
      geminiApiKey: geminiApiKey,
      supabaseUrl: supabaseUrl ?? '',
      supabaseAnonKey: supabaseAnonKey ?? '',
    );
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

    // Start speech recognition first (higher priority)
    final started = await _speechService.startListening(
      languageCode: _preferences.languageCode,
    );
    if (!started) {
      notifyListeners();
      return;
    }

    _isChatActive = true;
    _chatStartTime = DateTime.now();
    _isMicrophoneMuted = false;
    _voiceAgentState = VoiceAgentState.listening;

    // Initialize message tracking
    _currentMessages = [];
    _currentMessageStartTime = DateTime.now();

    // Reset Gemini chat session for fresh conversation
    _geminiService.resetChat();
    _geminiResponse = null;
    _displayedResponseLength = 0;

    // Listen to audio level stream
    _audioLevelSubscription?.cancel();
    _audioLevelSamples = [];
    _audioLevelSubscription = _speechService.audioLevelStream.listen((level) {
      _audioLevel = level;
      _audioLevelSamples.add(level);
      notifyListeners();
    });

    // Listen to speech events (segment complete on silence)
    _speechEventSubscription?.cancel();
    _speechEventSubscription = _speechService.speechEventStream.listen((event) {
      _handleSpeechEvent(event);
    });

    notifyListeners();
  }

  /// Handle speech events from native side
  void _handleSpeechEvent(Map<String, dynamic> event) {
    final eventType = event['event'] as String?;

    if (eventType == 'segmentComplete') {
      // Ignore STT input while agent is speaking (it's just picking up TTS output)
      if (_ignoringSTT) {
        return;
      }

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
      // But don't restart while agent is speaking (we'll restart after TTS finishes)
      if (_isChatActive && !_isMicrophoneMuted && !_ignoringSTT) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (_isChatActive && !_isMicrophoneMuted && !_ignoringSTT) {
            await _speechService.startListening(
              languageCode: _preferences.languageCode,
            );
          }
        });
      }
    } else if (eventType == 'interruptionEnded') {
      // Audio interruption ended (e.g., phone call ended), restart listening
      // But don't restart while agent is speaking
      if (_isChatActive && !_isMicrophoneMuted && !_ignoringSTT) {
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (_isChatActive && !_isMicrophoneMuted && !_ignoringSTT) {
            final started = await _speechService.startListening(
              languageCode: _preferences.languageCode,
            );
            if (started) {
              _voiceAgentState = VoiceAgentState.listening;
              _audioLevelSubscription?.cancel();
              _audioLevelSubscription = _speechService.audioLevelStream.listen((
                level,
              ) {
                _audioLevel = level;
                notifyListeners();
              });
              notifyListeners();
            }
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
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 25), (
      timer,
    ) {
      if (_geminiResponse == null ||
          _displayedResponseLength >= _geminiResponse!.length) {
        timer.cancel();
        return;
      }
      _displayedResponseLength += 1;
      notifyListeners();
    });
  }

  /// Print audio level stats for the current segment
  void _printAudioStats() {
    _audioLevelSamples = [];
  }

  void _printTTSAudioStats() {
    _ttsAudioLevelSamples = [];
  }

  /// Send message to Gemini and update response
  /// This runs asynchronously without blocking the speech recognition
  void _sendToGemini(String message) {
    if (!_geminiService.isInitialized) return;

    // Print audio stats for this segment
    _printAudioStats();

    _isGeminiLoading = true;
    _voiceAgentState = VoiceAgentState.thinking;
    _typewriterTimer?.cancel();
    _displayedResponseLength = 0;
    notifyListeners();

    // Run async without awaiting - allows speech recognition to continue
    _sampleAndSendToGemini(message);
  }

  /// Sample screenshots and send message to Gemini
  Future<void> _sampleAndSendToGemini(String message) async {
    try {
      // Sample screenshots from buffer (clears buffer after sampling)
      final screenshots = await _screenStreamService.sampleScreenshots(
        maxSamples: 10,
      );

      // Retrieve relevant context from past conversations (RAG)
      String augmentedMessage = message;
      if (_embeddingService.isReady && _conversations.isNotEmpty) {
        final conversationIds = _conversations.map((c) => c.id).toList();
        final relevantContext = await _embeddingService.retrieveSimilarMessages(
          query: message,
          conversationIds: conversationIds,
          limit: 5,
        );

        if (relevantContext.isNotEmpty) {
          final contextText = relevantContext.join('\n---\n');
          augmentedMessage = '''Here is some relevant context from our past conversations:
$contextText

Current question/message: $message''';
        }
      }

      // Send to Gemini with or without screenshots
      final String? response;
      if (screenshots.isNotEmpty) {
        response = await _geminiService.sendMessageWithScreenshots(
          augmentedMessage,
          screenshots,
        );
      } else {
        response = await _geminiService.sendMessage(augmentedMessage);
      }

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

        // Set flag to block any STT events while agent is speaking
        _ignoringSTT = true;

        // Stop STT before speaking to clear cache and prevent garbage collection
        if (_isChatActive && !_isMicrophoneMuted) {
          await _speechService.stopListening();
        }

        // Set speaking state
        _voiceAgentState = VoiceAgentState.speaking;
        notifyListeners();

        // Start collecting TTS audio levels and update audioLevel for voice agent pulsing
        _ttsAudioLevelSamples = [];
        _ttsAudioLevelSubscription?.cancel();
        _ttsAudioLevelSubscription = _ttsService.audioLevelStream.listen((
          level,
        ) {
          _ttsAudioLevelSamples.add(level);
          // Update audioLevel so voice agent circle pulses during speech
          _audioLevel = level;
          notifyListeners();
        });

        await _ttsService.speak(
          text: response,
          languageCode: _preferences.languageCode,
          slowerSpeech: _preferences.slowerSpeechEnabled,
        );

        // Stop collecting and print TTS stats
        _ttsAudioLevelSubscription?.cancel();
        _ttsAudioLevelSubscription = null;
        _audioLevel = 0.0;
        _printTTSAudioStats();

        // Restart STT with clean state after agent finishes speaking
        if (_isChatActive && !_isMicrophoneMuted) {
          // Small delay to ensure clean state before accepting input again
          await Future.delayed(const Duration(milliseconds: 100));
          // Clear audio samples collected during agent speech (it's just TTS noise)
          _audioLevelSamples = [];
          await _speechService.startListening(
            languageCode: _preferences.languageCode,
          );
          _voiceAgentState = VoiceAgentState.listening;
          // Additional delay to let STT fully initialize before accepting input
          await Future.delayed(const Duration(milliseconds: 50));
          _ignoringSTT = false;
        } else {
          _ignoringSTT = false;
        }
      }

      notifyListeners();
    } catch (error) {
      _isGeminiLoading = false;
      notifyListeners();
    }
  }

  /// End chat and save conversation to history
  Future<void> endChat() async {
    // Stop any TTS playback
    _ttsService.stop();

    // Stop screen frame capture if active
    if (_isScreenRecordingActive) {
      await _screenStreamService.stopCapture();
      _isScreenRecordingActive = false;
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
        id: const Uuid().v4(),
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

    // Clear any pending background Gemini requests
    await _screenStreamService.clearGeminiResponse();

    _isChatActive = false;
    _voiceAgentState = VoiceAgentState.resting;
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

    // Store embeddings for all messages in the conversation
    if (_embeddingService.isReady) {
      for (final message in conversation.messages) {
        await _embeddingService.storeMessageEmbedding(
          conversationId: conversation.id,
          messageText: message.text,
        );
      }
    }

    notifyListeners();
  }

  /// Delete conversation from history
  Future<void> deleteConversation(String id) async {
    await _storageService.deleteConversation(id);

    // Delete embeddings from Supabase
    if (_embeddingService.isReady) {
      await _embeddingService.deleteConversationEmbeddings(id);
    }

    _conversations = await _storageService.loadConversations();
    notifyListeners();
  }

  /// Clear all conversations from history
  Future<void> clearAllConversations() async {
    // Get conversation IDs before clearing
    final conversationIds = _conversations.map((c) => c.id).toList();

    await _storageService.saveConversations([]);

    // Delete all embeddings from Supabase
    if (_embeddingService.isReady && conversationIds.isNotEmpty) {
      await _embeddingService.deleteAllEmbeddings(conversationIds);
    }

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

  /// Handle app lifecycle changes for background audio
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background - update context with latest messages
      if (_isChatActive && _isScreenRecordingActive) {
        debugPrint('📱 [AppLifecycle] App backgrounding - updating broadcast context with ${_currentMessages.length} messages');
        _updateBroadcastContext();
      }
    }

    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 [AppLifecycle] App resumed from background');

      // App returned to foreground - check for background Gemini responses
      if (_isChatActive && _isScreenRecordingActive) {
        debugPrint('🤖 [AppLifecycle] Chat + broadcast active - checking for background Gemini response...');
        _checkBackgroundGeminiResponse();
      }

      // Restart speech recognition
      // iOS may have interrupted the audio session while backgrounded
      if (_isChatActive && !_isMicrophoneMuted) {
        debugPrint('🎙️ [AppLifecycle] Restarting speech recognition after resume');
        _restartSpeechRecognition();
      }
    }

    // Note: We intentionally do NOT stop speech recognition on pause/inactive
    // This allows the voice agent to attempt to continue in the background
  }

  /// Check for and process any Gemini responses from background processing
  Future<void> _checkBackgroundGeminiResponse() async {
    final response = await _screenStreamService.checkGeminiResponse();
    if (response == null) {
      debugPrint('🤖 [BackgroundSync] No pending Gemini response found');
      return;
    }

    final geminiResponse = response['response'] as String?;
    final transcript = response['transcript'] as String?;

    if (geminiResponse == null || transcript == null) {
      debugPrint('⚠️ [BackgroundSync] Response data incomplete');
      return;
    }

    debugPrint('🤖 [BackgroundSync] ✓ Found background Gemini response - syncing to chat session');
    debugPrint('   - User transcript: "${transcript.substring(0, transcript.length.clamp(0, 50))}..."');
    debugPrint('   - Response length: ${geminiResponse.length} chars');

    // Clear the response flag
    await _screenStreamService.clearGeminiResponse();

    // Add user message to current messages
    final userMessage = Message(
      id: const Uuid().v4(),
      text: transcript,
      timestamp: DateTime.now(),
      sender: MessageSender.user,
    );
    _currentMessages.add(userMessage);

    // Add assistant response to current messages
    final agentMessage = Message(
      id: const Uuid().v4(),
      text: geminiResponse,
      timestamp: DateTime.now(),
      sender: MessageSender.agent,
    );
    _currentMessages.add(agentMessage);

    // Inject into Gemini chat session for continuity
    _geminiService.injectHistoryEntry(transcript, geminiResponse);
    debugPrint('🤖 [BackgroundSync] Injected into chat session for continuity');

    // Update UI
    _geminiResponse = geminiResponse;
    _displayedResponseLength = geminiResponse.length;
    notifyListeners();

    // Update broadcast context with new history
    await _updateBroadcastContext();
    debugPrint('🤖 [BackgroundSync] Sync complete - UI updated');
  }

  /// Restart speech recognition after coming back from background
  Future<void> _restartSpeechRecognition() async {
    // Stop current recognition first to get a clean state
    await _speechService.stopListening();
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;

    // Brief delay to allow audio session to reset
    await Future.delayed(const Duration(milliseconds: 200));

    // Restart listening
    final started = await _speechService.startListening(
      languageCode: _preferences.languageCode,
    );

    if (started) {
      _voiceAgentState = VoiceAgentState.listening;
      _audioLevelSubscription = _speechService.audioLevelStream.listen((level) {
        _audioLevel = level;
        notifyListeners();
      });
      notifyListeners();
    } else {
      debugPrint('Failed to restart speech recognition after resume');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioLevelSubscription?.cancel();
    _speechEventSubscription?.cancel();
    _ttsAudioLevelSubscription?.cancel();
    _typewriterTimer?.cancel();
    _speechService.dispose();
    _ttsService.dispose();
    _screenStreamService.dispose();
    super.dispose();
  }
}

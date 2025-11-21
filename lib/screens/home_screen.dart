import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../services/tts_service.dart';
import '../widgets/voice_agent_circle.dart';
import '../widgets/control_button.dart';
import '../utils/localization_helper.dart';
import 'settings_screen.dart';

/// Main home screen with voice agent and controls
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasShownVoicePrompt = false;
  final ScrollController _responseScrollController = ScrollController();
  String? _lastResponse;
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _responseScrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_responseScrollController.hasClients) return;

    final position = _responseScrollController.position;
    final isAtBottom = position.pixels >= position.maxScrollExtent - 20;

    if (isAtBottom && !_autoScrollEnabled) {
      setState(() {
        _autoScrollEnabled = true;
      });
    }
  }

  void _scrollToBottom() {
    if (_responseScrollController.hasClients) {
      _responseScrollController.animateTo(
        _responseScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _autoScrollEnabled = true;
      });
    }
  }

  @override
  void dispose() {
    _responseScrollController.removeListener(_onScroll);
    _responseScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkEnhancedVoicePrompt();
  }

  void _checkEnhancedVoicePrompt() {
    if (_hasShownVoicePrompt) return;

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.shouldPromptForEnhancedVoice) {
      _hasShownVoicePrompt = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEnhancedVoiceDialog(appState);
      });
    }
  }

  void _showEnhancedVoiceDialog(AppStateProvider appState) {
    final l10n = LocalizationHelper.of(context);
    final colors = AppColorScheme(
      isHighContrast: appState.preferences.highContrastEnabled,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          'Enhanced Voice Available',
          style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'For a more natural voice experience, download the enhanced "${appState.missingVoiceName}" voice.\n\nGo to: Settings > Accessibility > Read and Speak > Voices > English > ${appState.missingVoiceName}',
          style: AppTextStyles.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              appState.dismissEnhancedVoicePrompt();
            },
            child: Text(
              l10n.cancel,
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              appState.dismissEnhancedVoicePrompt();
              final ttsService = TTSService();
              await ttsService.openVoiceSettings();
            },
            child: Text(
              l10n.openSettings,
              style: TextStyle(color: colors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingMultiplier = AppDimensions.getPaddingMultiplier(screenWidth);
    final appState = Provider.of<AppStateProvider>(context);
    final colors = AppColorScheme(
      isHighContrast: appState.preferences.highContrastEnabled,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Bar
            _buildAppBar(context, colors),

            // Voice Agent Section (upper portion)
            Expanded(
              flex: 75,
              child: _buildVoiceAgentSection(context, screenWidth, colors),
            ),

            // Control Buttons Section (lower portion - reduced size)
            Expanded(
              flex: 28,
              child: _buildControlSection(
                context,
                screenWidth,
                paddingMultiplier,
                colors,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build app bar
  Widget _buildAppBar(BuildContext context, AppColorScheme colors) {
    return SizedBox(
      height: AppDimensions.appBarHeight,
      child: Stack(
        children: [
          // Centered title
          Center(
            child: Text(
              'Assistify',
              style: AppTextStyles.appTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          // Settings button on the right
          Positioned(
            right: AppDimensions.md,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: Icon(
                  Icons.settings,
                  color: colors.textSecondary,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build voice agent section
  Widget _buildVoiceAgentSection(
    BuildContext context,
    double screenWidth,
    AppColorScheme colors,
  ) {
    final circleSize = AppDimensions.getVoiceAgentCircleSize(screenWidth);

    return Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          final hasResponse = appState.isGeminiLoading ||
              appState.displayedGeminiResponse != null;

          return LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final topPadding = hasResponse
                  ? AppDimensions.xl
                  : (availableHeight - circleSize) / 2;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    top: topPadding,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: VoiceAgentCircle(
                        size: circleSize,
                        audioLevel: appState.audioLevel,
                        isActive: appState.isChatActive,
                        colors: colors,
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    top: topPadding + circleSize + AppDimensions.lg,
                    left: 0,
                    right: 0,
                    bottom: AppDimensions.md,
                    child: Column(
                      children: [
                        // Gemini response display with smooth animated size transition
                        if (appState.isGeminiLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.lg,
                            ),
                            child: Text(
                              '...',
                              style: AppTextStyles.body.copyWith(
                                color: colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else if (appState.displayedGeminiResponse != null)
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                // Auto-scroll when response updates (only if enabled)
                                if (_lastResponse != appState.displayedGeminiResponse) {
                                  _lastResponse = appState.displayedGeminiResponse;
                                  if (_autoScrollEnabled) {
                                    Future.delayed(const Duration(milliseconds: 50), () {
                                      if (_responseScrollController.hasClients && _autoScrollEnabled) {
                                        _responseScrollController.animateTo(
                                          _responseScrollController.position.maxScrollExtent,
                                          duration: const Duration(milliseconds: 150),
                                          curve: Curves.easeOut,
                                        );
                                      }
                                    });
                                  }
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.lg,
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: colors.cardBackground.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(
                                            AppDimensions.borderRadiusMedium,
                                          ),
                                          border: colors.isHighContrast
                                              ? Border.all(color: colors.border, width: 2)
                                              : null,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            AppDimensions.borderRadiusMedium,
                                          ),
                                          child: NotificationListener<ScrollNotification>(
                                            onNotification: (notification) {
                                              if (notification is ScrollUpdateNotification) {
                                                if (notification.dragDetails != null) {
                                                  // User is manually scrolling
                                                  final position = _responseScrollController.position;
                                                  final isAtBottom = position.pixels >= position.maxScrollExtent - 20;
                                                  if (!isAtBottom && _autoScrollEnabled) {
                                                    setState(() {
                                                      _autoScrollEnabled = false;
                                                    });
                                                  }
                                                }
                                              }
                                              return false;
                                            },
                                            child: SingleChildScrollView(
                                              controller: _responseScrollController,
                                              padding: const EdgeInsets.all(AppDimensions.md),
                                              child: Text(
                                                appState.displayedGeminiResponse!,
                                                style: AppTextStyles.body.copyWith(
                                                  color: colors.textPrimary,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Scroll to bottom button
                                      if (!_autoScrollEnabled)
                                        Positioned(
                                          bottom: AppDimensions.sm,
                                          right: AppDimensions.sm,
                                          child: GestureDetector(
                                            onTap: _scrollToBottom,
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.primaryBlue,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.2),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
    );
  }

  /// Build control buttons section
  Widget _buildControlSection(
    BuildContext context,
    double screenWidth,
    double paddingMultiplier,
    AppColorScheme colors,
  ) {
    final buttonSize = AppDimensions.getControlButtonSize(screenWidth);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.borderRadiusXLarge),
          topRight: Radius.circular(AppDimensions.borderRadiusXLarge),
        ),
        border: colors.isHighContrast
            ? Border.all(color: colors.border, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.lg * paddingMultiplier,
            vertical: AppDimensions.lg * paddingMultiplier,
          ),
          child: Consumer<AppStateProvider>(
            builder: (context, appState, child) {
              final l10n = LocalizationHelper.of(context);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Start/End Chat Button
                ControlButton(
                  icon: appState.isChatActive
                      ? Icons.stop_circle_outlined
                      : Icons.chat_bubble_outline,
                  label: appState.isChatActive ? l10n.endChat : l10n.startChat,
                  backgroundColor: appState.isChatActive
                      ? colors.accentCoral
                      : colors.successGreen,
                  labelColor: appState.isChatActive
                      ? colors.accentCoral
                      : colors.successGreen,
                  onTap: () {
                    if (appState.isChatActive) {
                      appState.endChat();
                    } else {
                      appState.startChat(context);
                    }
                  },
                  size: buttonSize,
                ),

                // Microphone Mute Button
                ControlButton(
                  icon: appState.isMicrophoneMuted ? Icons.mic_off : Icons.mic,
                  label: l10n.microphone,
                  backgroundColor: appState.isMicrophoneMuted
                      ? colors.accentCoral
                      : colors.primaryBlue,
                  labelColor: appState.isMicrophoneMuted
                      ? colors.accentCoral
                      : colors.primaryBlue,
                  onTap: () => appState.toggleMicrophoneMute(context),
                  size: buttonSize,
                ),

                // Screen Recording Button (only enabled when chat is active)
                ControlButton(
                  icon: appState.isScreenRecordingActive
                      ? Icons.videocam
                      : Icons.videocam_outlined,
                  label: l10n.shareScreen,
                  backgroundColor: appState.isScreenRecordingActive
                      ? colors.successGreen
                      : (appState.isChatActive
                          ? colors.buttonGray
                          : colors.disabled),
                  labelColor: appState.isScreenRecordingActive
                      ? colors.successGreen
                      : (appState.isChatActive
                          ? colors.textSecondary
                          : colors.textSecondary.withValues(alpha: 0.5)),
                  onTap: appState.isChatActive
                      ? () => appState.toggleScreenRecording(context)
                      : null,
                  showPulse: appState.isScreenRecordingActive,
                  size: buttonSize,
                ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }
}

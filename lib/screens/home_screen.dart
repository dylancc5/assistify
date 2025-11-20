import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../widgets/voice_agent_circle.dart';
import '../widgets/control_button.dart';
import '../utils/localization_helper.dart';
import 'settings_screen.dart';

/// Main home screen with voice agent and controls
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final paddingMultiplier = AppDimensions.getPaddingMultiplier(screenWidth);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(context),

            // Voice Agent Section (upper portion)
            Expanded(
              flex: 75,
              child: _buildVoiceAgentSection(context, screenWidth),
            ),

            // Control Buttons Section (lower portion - reduced size)
            Expanded(
              flex: 25,
              child: _buildControlSection(context, screenWidth, paddingMultiplier),
            ),
          ],
        ),
      ),
    );
  }

  /// Build app bar
  Widget _buildAppBar(BuildContext context) {
    return SizedBox(
      height: AppDimensions.appBarHeight,
      child: Stack(
        children: [
          // Centered title
          Center(
            child: Text(
              'Assistify',
              style: AppTextStyles.appTitle,
            ),
          ),
          // Settings button on the right
          Positioned(
            right: AppDimensions.md,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: AppColors.textSecondary,
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
  Widget _buildVoiceAgentSection(BuildContext context, double screenWidth) {
    final circleSize = AppDimensions.getVoiceAgentCircleSize(screenWidth);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gradientStart,
            AppColors.gradientEnd,
          ],
        ),
      ),
      child: Center(
        child: Consumer<AppStateProvider>(
          builder: (context, appState, child) {
            return VoiceAgentCircle(
              size: circleSize,
              audioLevel: appState.audioLevel,
              isActive: appState.isChatActive,
            );
          },
        ),
      ),
    );
  }

  /// Build control buttons section
  Widget _buildControlSection(
    BuildContext context,
    double screenWidth,
    double paddingMultiplier,
  ) {
    final buttonSize = AppDimensions.getControlButtonSize(screenWidth);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.borderRadiusXLarge),
          topRight: Radius.circular(AppDimensions.borderRadiusXLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
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
                      ? AppColors.accentCoral
                      : AppColors.successGreen,
                  labelColor: appState.isChatActive
                      ? AppColors.accentCoral
                      : AppColors.successGreen,
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
                      ? AppColors.accentCoral
                      : AppColors.primaryBlue,
                  labelColor: appState.isMicrophoneMuted
                      ? AppColors.accentCoral
                      : AppColors.primaryBlue,
                  onTap: () => appState.toggleMicrophoneMute(context),
                  size: buttonSize,
                ),

                // Screen Recording Button
                ControlButton(
                  icon: appState.isScreenRecordingActive
                      ? Icons.videocam
                      : Icons.videocam_outlined,
                  label: l10n.shareScreen,
                  backgroundColor: appState.isScreenRecordingActive
                      ? AppColors.successGreen
                      : AppColors.buttonGray,
                  labelColor: appState.isScreenRecordingActive
                      ? AppColors.successGreen
                      : AppColors.textSecondary,
                  onTap: () => appState.toggleScreenRecording(context),
                  showPulse: appState.isScreenRecordingActive,
                  size: buttonSize,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

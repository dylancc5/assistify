import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../widgets/voice_agent_circle.dart';
import '../widgets/control_button.dart';
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
            _buildAppBar(),

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
  Widget _buildAppBar() {
    return SizedBox(
      height: AppDimensions.appBarHeight,
      child: Center(
        child: Text(
          'Assistify',
          style: AppTextStyles.appTitle,
        ),
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
        child: VoiceAgentCircle(size: circleSize),
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
            color: Colors.black.withOpacity(0.1),
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
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Microphone Mute Button
                ControlButton(
                  icon: appState.isMicrophoneMuted ? Icons.mic_off : Icons.mic,
                  label: 'Microphone',
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
                  label: 'Screen Recording',
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

                // Settings Button
                ControlButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  backgroundColor: AppColors.buttonGray,
                  labelColor: AppColors.textSecondary,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
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

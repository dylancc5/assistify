import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import 'history_screen.dart';
import 'screen_recording_history_screen.dart';

/// Settings screen with preferences and options
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings', style: AppTextStyles.heading),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.md),

            // Conversation History Card
            _buildHistoryCard(context),

            const SizedBox(height: AppDimensions.md),

            // Screen Recording History Card
            _buildScreenRecordingHistorySection(context),

            const SizedBox(height: AppDimensions.md),

            // Preferences Card
            _buildPreferencesCard(context),

            const SizedBox(height: AppDimensions.md),

            // About Card
            _buildAboutCard(context),

            const SizedBox(height: AppDimensions.lg),
          ],
        ),
      ),
    );
  }

  /// Build history card
  Widget _buildHistoryCard(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conversation History', style: AppTextStyles.bodyLarge),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'View your past conversations with Assistify',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.mediumButtonHeight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  foregroundColor: AppColors.primaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusSmall,
                    ),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('View History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build screen recording history section
  Widget _buildScreenRecordingHistorySection(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Screen History', style: AppTextStyles.bodyLarge),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'View and manage your past screen recordings',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.mediumButtonHeight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ScreenRecordingHistoryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  foregroundColor: AppColors.primaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusSmall,
                    ),
                  ),
                ),
                icon: const Icon(Icons.videocam),
                label: const Text('View Screen History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build preferences card
  Widget _buildPreferencesCard(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Consumer<AppStateProvider>(
          builder: (context, appState, child) {
            final prefs = appState.preferences;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preferences', style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppDimensions.sm),

                // Large Text Toggle
                _buildPreferenceItem(
                  icon: Icons.text_fields,
                  title: 'Large Text',
                  subtitle: 'Increase text size for better readability',
                  value: prefs.largeTextEnabled,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(largeTextEnabled: value),
                    );
                  },
                ),

                const Divider(color: AppColors.divider, height: 1),

                // Slower Speech Toggle
                _buildPreferenceItem(
                  icon: Icons.speed,
                  title: 'Slower Speech',
                  subtitle: 'Reduce voice assistant speaking speed',
                  value: prefs.slowerSpeechEnabled,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(slowerSpeechEnabled: value),
                    );
                  },
                ),

                const Divider(color: AppColors.divider, height: 1),

                // High Contrast Toggle
                _buildPreferenceItem(
                  icon: Icons.contrast,
                  title: 'High Contrast Mode',
                  subtitle: 'Increase contrast for better visibility',
                  value: prefs.highContrastEnabled,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(highContrastEnabled: value),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build preference item
  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: AppColors.textSecondary, size: 24),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  /// Build about card
  Widget _buildAboutCard(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('About Assistify', style: AppTextStyles.bodyLarge),
            const SizedBox(height: AppDimensions.xs),
            Text('Version 1.0.0', style: AppTextStyles.caption),
            const SizedBox(height: AppDimensions.md),

            // Privacy Policy
            _buildLinkItem(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              onTap: () {
                // TODO: Open privacy policy
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy Policy - Coming soon')),
                );
              },
            ),

            const Divider(color: AppColors.divider, height: 1),

            // Terms of Service
            _buildLinkItem(
              icon: Icons.description,
              title: 'Terms of Service',
              onTap: () {
                // TODO: Open terms of service
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Terms of Service - Coming soon'),
                  ),
                );
              },
            ),

            const Divider(color: AppColors.divider, height: 1),

            // Send Feedback
            _buildLinkItem(
              icon: Icons.feedback,
              title: 'Send Feedback',
              onTap: () {
                // TODO: Open feedback form
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Send Feedback - Coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build link item
  Widget _buildLinkItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 24),
            const SizedBox(width: AppDimensions.md),
            Expanded(child: Text(title, style: AppTextStyles.body)),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

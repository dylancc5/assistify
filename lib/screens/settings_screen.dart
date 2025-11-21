import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../utils/localization_helper.dart';
import 'history_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

/// Settings screen with preferences and options
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final colors = AppColorScheme(
      isHighContrast: appState.preferences.highContrastEnabled,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          LocalizationHelper.of(context).settings,
          style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.md),

            // Conversation History Card
            _buildHistoryCard(context, colors),

            const SizedBox(height: AppDimensions.md),

            // Preferences Card
            _buildPreferencesCard(context, colors),

            const SizedBox(height: AppDimensions.md),

            // About Card
            _buildAboutCard(context, colors),

            const SizedBox(height: AppDimensions.lg),
          ],
        ),
      ),
    );
  }

  /// Build history card
  Widget _buildHistoryCard(BuildContext context, AppColorScheme colors) {
    final l10n = LocalizationHelper.of(context);
    return Card(
      elevation: AppDimensions.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        side: colors.isHighContrast
            ? BorderSide(color: colors.border, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.conversationHistory,
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              l10n.viewYourPastConversations,
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
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
                  backgroundColor: colors.primaryBlue.withValues(
                    alpha: colors.isHighContrast ? 0.2 : 0.1,
                  ),
                  foregroundColor: colors.primaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusSmall,
                    ),
                    side: colors.isHighContrast
                        ? BorderSide(color: colors.primaryBlue, width: 2)
                        : BorderSide.none,
                  ),
                ),
                icon: const Icon(Icons.history),
                label: Text(l10n.viewHistory),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build preferences card
  Widget _buildPreferencesCard(BuildContext context, AppColorScheme colors) {
    return Card(
      elevation: AppDimensions.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        side: colors.isHighContrast
            ? BorderSide(color: colors.border, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Consumer<AppStateProvider>(
          builder: (context, appState, child) {
            final prefs = appState.preferences;
            final l10n = LocalizationHelper.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.preferences,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),

                // Large Text Toggle
                _buildPreferenceItem(
                  icon: Icons.text_fields,
                  title: l10n.largeText,
                  subtitle: l10n.increaseTextSizeForBetterReadability,
                  value: prefs.largeTextEnabled,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(largeTextEnabled: value),
                    );
                  },
                  colors: colors,
                ),

                Divider(color: colors.divider, height: 1),

                // Slower Speech Toggle
                _buildPreferenceItem(
                  icon: Icons.speed,
                  title: l10n.slowerSpeech,
                  subtitle: l10n.reduceVoiceAssistantSpeakingSpeed,
                  value: prefs.slowerSpeechEnabled,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(slowerSpeechEnabled: value),
                    );
                  },
                  colors: colors,
                ),

                Divider(color: colors.divider, height: 1),

                // High Contrast Toggle
                _buildPreferenceItem(
                  icon: Icons.contrast,
                  title: l10n.highContrastMode,
                  subtitle: l10n.increaseContrastForBetterVisibility,
                  value: prefs.highContrastEnabled,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(highContrastEnabled: value),
                    );
                  },
                  colors: colors,
                ),

                Divider(color: colors.divider, height: 1),

                // Simplified Chinese Toggle
                _buildPreferenceItem(
                  icon: Icons.language,
                  title: l10n.simplifiedChinese,
                  subtitle: l10n.changeAppLanguageToSimplifiedChinese,
                  value: prefs.useSimplifiedChinese,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(useSimplifiedChinese: value),
                    );
                  },
                  colors: colors,
                ),

                Divider(color: colors.divider, height: 1),

                // Show Transcribed Text Toggle
                _buildPreferenceItem(
                  icon: Icons.subtitles,
                  title: l10n.showResponseText,
                  subtitle: l10n.displayTranscribedAIResponsesOnScreen,
                  value: prefs.showTranscribedText,
                  onChanged: (value) {
                    appState.updatePreferences(
                      prefs.copyWith(showTranscribedText: value),
                    );
                  },
                  colors: colors,
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
    required AppColorScheme colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: colors.textSecondary, size: 24),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
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
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  /// Build about card
  Widget _buildAboutCard(BuildContext context, AppColorScheme colors) {
    final l10n = LocalizationHelper.of(context);
    return Card(
      elevation: AppDimensions.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        side: colors.isHighContrast
            ? BorderSide(color: colors.border, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aboutAssistify,
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              l10n.version('1.0.0'),
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // Privacy Policy
            _buildLinkItem(
              icon: Icons.privacy_tip,
              title: l10n.privacyPolicy,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
              colors: colors,
            ),

            Divider(color: colors.divider, height: 1),

            // Terms of Service
            _buildLinkItem(
              icon: Icons.description,
              title: l10n.termsOfService,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServiceScreen(),
                  ),
                );
              },
              colors: colors,
            ),

            Divider(color: colors.divider, height: 1),

            // Send Feedback
            _buildLinkItem(
              icon: Icons.feedback,
              title: l10n.sendFeedback,
              onTap: () {
                _showFeedbackDialog(context, colors);
              },
              colors: colors,
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
    required AppColorScheme colors,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        child: Row(
          children: [
            Icon(icon, color: colors.textSecondary, size: 24),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(color: colors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  /// Show feedback dialog
  void _showFeedbackDialog(BuildContext context, AppColorScheme colors) {
    final l10n = LocalizationHelper.of(context);
    final issueController = TextEditingController();
    int selectedRating = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
                side: colors.isHighContrast
                    ? BorderSide(color: colors.border, width: 2)
                    : BorderSide.none,
              ),
              title: Text(
                l10n.feedbackTitle,
                style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.feedbackIssueLabel,
                      style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    TextField(
                      controller: issueController,
                      maxLines: 4,
                      style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: l10n.feedbackIssueHint,
                        hintStyle: AppTextStyles.body.copyWith(color: colors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
                          borderSide: BorderSide(
                            color: colors.isHighContrast ? colors.border : colors.divider,
                            width: colors.isHighContrast ? 2 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
                          borderSide: BorderSide(color: colors.primaryBlue, width: 2),
                        ),
                        filled: true,
                        fillColor: colors.background,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      l10n.feedbackRatingLabel,
                      style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        return IconButton(
                          icon: Icon(
                            starIndex <= selectedRating ? Icons.star : Icons.star_border,
                            color: starIndex <= selectedRating
                                ? Colors.amber
                                : colors.textSecondary,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedRating = starIndex;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l10n.cancel,
                    style: AppTextStyles.body.copyWith(color: colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.feedbackSent),
                        backgroundColor: colors.primaryBlue,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
                    ),
                  ),
                  child: Text(l10n.feedbackSubmit),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

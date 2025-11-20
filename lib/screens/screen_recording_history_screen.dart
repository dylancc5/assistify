import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';
import '../providers/app_state_provider.dart';
import '../widgets/screen_recording_card.dart';
import '../utils/localization_helper.dart';

/// Screen for viewing screen recording history
class ScreenRecordingHistoryScreen extends StatelessWidget {
  const ScreenRecordingHistoryScreen({super.key});

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
          LocalizationHelper.of(context).screenHistory,
          style: AppTextStyles.heading.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          final recordings = appState.screenRecordings;

          if (recordings.isEmpty) {
            return _buildEmptyState(colors);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.md),
            itemCount: recordings.length,
            itemBuilder: (context, index) {
              final recording = recordings[index];
              return ScreenRecordingCard(
                recording: recording,
                onDelete: () => appState.deleteScreenRecording(recording.id),
              );
            },
          );
        },
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(AppColorScheme colors) {
    return Builder(
      builder: (context) {
        final l10n = LocalizationHelper.of(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off,
                  size: 80,
                  color: colors.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppDimensions.lg),
                Text(
                  l10n.noSharedScreensYet,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  l10n.shareYourScreenFromTheHomeScreenToSeeItHere,
                  style: AppTextStyles.body.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

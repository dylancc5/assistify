import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state_provider.dart';
import '../services/permission_service.dart';
import '../utils/localization_helper.dart';
import 'permission_modal.dart';

/// Onboarding flow manager for permission requests
class OnboardingFlow {
  /// Show the complete onboarding flow
  static Future<void> show(BuildContext context) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    // Check if onboarding is already complete
    if (appState.hasCompletedOnboarding) {
      return;
    }

    // Step 1: Screen Recording Permission
    if (appState.screenRecordingPermission != PermissionState.granted) {
      if (!context.mounted) return;
      await _showScreenRecordingPermission(context);
    }

    // Check if user granted screen recording permission
    if (!context.mounted) return;
    final appStateAfterScreen = Provider.of<AppStateProvider>(
      context,
      listen: false,
    );
    if (appStateAfterScreen.screenRecordingPermission !=
        PermissionState.granted) {
      // User denied, show error and stop onboarding
      if (!context.mounted) return;
      final l10n = LocalizationHelper.of(context);
      await _showPermissionDeniedError(
        context,
        l10n.screenRecordingPermissionIsRequired,
      );
      return;
    }

    // Step 2: Microphone Permission
    if (appStateAfterScreen.microphonePermission != PermissionState.granted) {
      if (!context.mounted) return;
      await _showMicrophonePermission(context);
    }

    // Check if user granted microphone permission
    if (!context.mounted) return;
    final appStateAfterMic = Provider.of<AppStateProvider>(
      context,
      listen: false,
    );
    if (appStateAfterMic.microphonePermission != PermissionState.granted) {
      // User denied, show error and stop onboarding
      if (!context.mounted) return;
      final l10n = LocalizationHelper.of(context);
      await _showPermissionDeniedError(
        context,
        l10n.microphonePermissionIsRequired,
      );
      return;
    }

    // Step 3: Success confirmation
    if (!context.mounted) return;
    await _showSuccessConfirmation(context);

    // Mark onboarding as complete
    await appStateAfterMic.completeOnboarding();
  }

  /// Show screen recording permission modal
  static Future<void> _showScreenRecordingPermission(
    BuildContext context,
  ) async {
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
        if (!context.mounted) return;
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        await appState.requestScreenRecordingPermission();
        if (context.mounted) {
          PermissionModal.dismiss(context);
        }
      },
    );
  }

  /// Show microphone permission modal
  static Future<void> _showMicrophonePermission(BuildContext context) async {
    final completer = Completer<void>();
    bool permissionRequested = false;

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final l10n = LocalizationHelper.of(context);

    // Check if permission is permanently denied
    final isPermanentlyDenied = await appState.isMicrophonePermanentlyDenied();

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
          await appState.openAppSettings();
          if (context.mounted) {
            PermissionModal.dismiss(context);
          }
        } else {
          // Request permission FIRST - this will show the system dialog on iOS
          // The system dialog will appear on top of our modal
          await appState.requestMicrophonePermission();

          // Wait a moment for the system dialog to appear
          await Future.delayed(const Duration(milliseconds: 100));

          // Now dismiss our modal (system dialog is already showing on top)
          if (context.mounted) {
            PermissionModal.dismiss(context);
          }

          // Wait for user to respond to system dialog
          await Future.delayed(const Duration(milliseconds: 1000));
        }

        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await completer.future;
  }

  /// Show success confirmation
  static Future<void> _showSuccessConfirmation(BuildContext context) async {
    final l10n = LocalizationHelper.of(context);
    await PermissionModal.show(
      context: context,
      icon: Icons.check_circle,
      iconColor: AppColors.successGreen,
      title: l10n.perfectYouAreReadyToGo,
      description: l10n.tapTheMicrophoneAnytimeToStartTalkingWithMe,
      buttonText: l10n.getStarted,
      buttonColor: AppColors.successGreen,
      onButtonPressed: () {
        PermissionModal.dismiss(context);
      },
    );
  }

  /// Show permission denied error
  static Future<void> _showPermissionDeniedError(
    BuildContext context,
    String message,
  ) async {
    final l10n = LocalizationHelper.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.permissionRequired),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}

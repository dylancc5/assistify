import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/app_state_provider.dart';
import '../services/permission_service.dart';
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
      await _showScreenRecordingPermission(context);
    }

    // Check if user granted screen recording permission
    final appStateAfterScreen =
        Provider.of<AppStateProvider>(context, listen: false);
    if (appStateAfterScreen.screenRecordingPermission !=
        PermissionState.granted) {
      // User denied, show error and stop onboarding
      await _showPermissionDeniedError(
        context,
        'Screen recording permission is required for Assistify to work properly.',
      );
      return;
    }

    // Step 2: Microphone Permission
    if (appStateAfterScreen.microphonePermission != PermissionState.granted) {
      await _showMicrophonePermission(context);
    }

    // Check if user granted microphone permission
    final appStateAfterMic =
        Provider.of<AppStateProvider>(context, listen: false);
    if (appStateAfterMic.microphonePermission != PermissionState.granted) {
      // User denied, show error and stop onboarding
      await _showPermissionDeniedError(
        context,
        'Microphone permission is required for Assistify to work properly.',
      );
      return;
    }

    // Step 3: Success confirmation
    await _showSuccessConfirmation(context);

    // Mark onboarding as complete
    await appStateAfterMic.completeOnboarding();
  }

  /// Show screen recording permission modal
  static Future<void> _showScreenRecordingPermission(
      BuildContext context) async {
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
        final appState =
            Provider.of<AppStateProvider>(context, listen: false);
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
    
    // Check if permission is permanently denied
    final isPermanentlyDenied = await appState.isMicrophonePermanentlyDenied();
    
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
    await PermissionModal.show(
      context: context,
      icon: Icons.check_circle,
      iconColor: AppColors.successGreen,
      title: 'Perfect! You\'re ready to go.',
      description: 'Tap the microphone anytime to start talking with me',
      buttonText: 'Get Started',
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
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

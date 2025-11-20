import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/text_styles.dart';

/// Permission request modal
class PermissionModal extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onButtonPressed;

  const PermissionModal({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonColor,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Material(
      color: AppColors.background.withValues(alpha: 0.95),
      child: Center(
        child: Container(
          width: screenWidth * AppDimensions.modalCardWidthPercent,
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Icon(
                icon,
                size: 64,
                color: iconColor,
              ),

              const SizedBox(height: AppDimensions.md),

              // Title
              Text(
                title,
                style: AppTextStyles.heading,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.sm + AppDimensions.xs),

              // Description
              Text(
                description,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
              ),

              const SizedBox(height: AppDimensions.lg),

              // Button
              SizedBox(
                width: double.infinity,
                height: AppDimensions.largeButtonHeight,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show permission modal with animation
  static Future<T?> show<T>({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onButtonPressed,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: PermissionModal(
                icon: icon,
                iconColor: iconColor,
                title: title,
                description: description,
                buttonText: buttonText,
                buttonColor: buttonColor,
                onButtonPressed: onButtonPressed,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Dismiss modal with animation
  static void dismiss(BuildContext context) {
    Navigator.of(context).pop();
  }
}

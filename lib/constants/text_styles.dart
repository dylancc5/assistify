import 'package:flutter/material.dart';
import 'colors.dart';

/// Design system text styles for Assistify app
class AppTextStyles {
  // Base font family
  static const String fontFamily = 'Roboto';

  // App Title
  static const TextStyle appTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    height: 1.5,
  );

  // Heading
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    height: 1.5,
  );

  // Body Large
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    height: 1.6,
  );

  // Body
  static const TextStyle body = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    height: 1.6,
  );

  // Button Label
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
    height: 1.5,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontFamily: fontFamily,
    height: 1.4,
  );

  /// Apply text scaling based on user preferences
  static TextStyle applyScaling(TextStyle style, double scaleFactor) {
    return style.copyWith(fontSize: (style.fontSize ?? 14) * scaleFactor);
  }
}

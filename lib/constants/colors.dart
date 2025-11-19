import 'package:flutter/material.dart';

/// Design system colors for Assistify app
class AppColors {
  // Primary Colors (Softened Baidu ERNIE brand colors)
  static const Color primaryBlue = Color(0xFF5B8FDB);
  static const Color accentCoral = Color(0xFFFF8B7B);
  static const Color thinkingGray = Color(0xFFB8C5D6);
  static const Color successGreen = Color(0xFF7EC699);

  // Neutral Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color divider = Color(0xFFE9ECEF);

  // Interactive States
  static const Color buttonGray = Color(0xFFADB5BD);
  static const Color buttonHover = Color(0x335B8FDB); // 20% opacity primary blue
  static const Color disabled = Color(0xFFDEE2E6);

  // Gradient Background for Voice Agent Section
  static const Color gradientStart = Color(0xFFF8F9FA);
  static const Color gradientEnd = Color(0xFFF0F2F5);

  // Voice Agent Circle Colors
  static const Color voiceAgentGradientStart = Color(0x1A5B8FDB); // 10% opacity
  static const Color voiceAgentGradientEnd = Color(0x0D5B8FDB); // 5% opacity
  static const Color voiceAgentBorder = Color(0x4D5B8FDB); // 30% opacity
  static const Color voiceAgentIcon = Color(0x995B8FDB); // 60% opacity
}

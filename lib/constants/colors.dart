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

  // Voice Agent Circle Colors (Listening - Blue)
  static const Color voiceAgentGradientStart = Color(0x1A5B8FDB); // 10% opacity
  static const Color voiceAgentGradientEnd = Color(0x0D5B8FDB); // 5% opacity
  static const Color voiceAgentBorder = Color(0x4D5B8FDB); // 30% opacity
  static const Color voiceAgentIcon = Color(0x995B8FDB); // 60% opacity

  // Voice Agent Circle Colors (Thinking - Red)
  static const Color voiceAgentThinkingGradientStart = Color(0x1AFF6B6B); // 10% opacity red
  static const Color voiceAgentThinkingGradientEnd = Color(0x0DFF6B6B); // 5% opacity red
  static const Color voiceAgentThinkingBorder = Color(0x4DFF6B6B); // 30% opacity red
  static const Color voiceAgentThinkingIcon = Color(0x99FF6B6B); // 60% opacity red
  static const Color primaryRed = Color(0xFFFF6B6B);

  // Voice Agent Circle Colors (Speaking - Green)
  static const Color voiceAgentSpeakingGradientStart = Color(0x1A7EC699); // 10% opacity green
  static const Color voiceAgentSpeakingGradientEnd = Color(0x0D7EC699); // 5% opacity green
  static const Color voiceAgentSpeakingBorder = Color(0x4D7EC699); // 30% opacity green
  static const Color voiceAgentSpeakingIcon = Color(0x997EC699); // 60% opacity green

  // Voice Agent Circle Colors (Inactive - Grey)
  static const Color voiceAgentGradientStartInactive = Color(0x1AADB5BD); // 10% opacity grey
  static const Color voiceAgentGradientEndInactive = Color(0x0DADB5BD); // 5% opacity grey
  static const Color voiceAgentBorderInactive = Color(0x4DADB5BD); // 30% opacity grey
  static const Color voiceAgentIconInactive = Color(0x99ADB5BD); // 60% opacity grey
}

/// High contrast colors for accessibility (WCAG AAA 7:1 ratio)
class AppColorsHighContrast {
  // Primary Colors (More saturated and contrasted)
  static const Color primaryBlue = Color(0xFF1E5BB8);
  static const Color accentCoral = Color(0xFFE63B2E);
  static const Color thinkingGray = Color(0xFF4A5568);
  static const Color successGreen = Color(0xFF1E7B3C);

  // Neutral Colors (Maximum contrast)
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF1A1A1A);
  static const Color divider = Color(0xFF000000);

  // Interactive States
  static const Color buttonGray = Color(0xFF3D3D3D);
  static const Color buttonHover = Color(0x661E5BB8); // 40% opacity primary blue
  static const Color disabled = Color(0xFF6B6B6B);

  // Gradient Background for Voice Agent Section
  static const Color gradientStart = Color(0xFFFFFFFF);
  static const Color gradientEnd = Color(0xFFE8E8E8);

  // Voice Agent Circle Colors (Listening - Blue)
  static const Color voiceAgentGradientStart = Color(0x4D1E5BB8); // 30% opacity
  static const Color voiceAgentGradientEnd = Color(0x261E5BB8); // 15% opacity
  static const Color voiceAgentBorder = Color(0xFF1E5BB8); // Full opacity
  static const Color voiceAgentIcon = Color(0xFF1E5BB8); // Full opacity

  // Voice Agent Circle Colors (Thinking - Red)
  static const Color voiceAgentThinkingGradientStart = Color(0x4DC53030); // 30% opacity red
  static const Color voiceAgentThinkingGradientEnd = Color(0x26C53030); // 15% opacity red
  static const Color voiceAgentThinkingBorder = Color(0xFFC53030); // Full opacity red
  static const Color voiceAgentThinkingIcon = Color(0xFFC53030); // Full opacity red
  static const Color primaryRed = Color(0xFFC53030);

  // Voice Agent Circle Colors (Speaking - Green)
  static const Color voiceAgentSpeakingGradientStart = Color(0x4D1E7B3C); // 30% opacity green
  static const Color voiceAgentSpeakingGradientEnd = Color(0x261E7B3C); // 15% opacity green
  static const Color voiceAgentSpeakingBorder = Color(0xFF1E7B3C); // Full opacity green
  static const Color voiceAgentSpeakingIcon = Color(0xFF1E7B3C); // Full opacity green

  // Voice Agent Circle Colors (Inactive - Grey)
  static const Color voiceAgentGradientStartInactive = Color(0x4D3D3D3D); // 30% opacity grey
  static const Color voiceAgentGradientEndInactive = Color(0x263D3D3D); // 15% opacity grey
  static const Color voiceAgentBorderInactive = Color(0xFF3D3D3D); // Full opacity grey
  static const Color voiceAgentIconInactive = Color(0xFF3D3D3D); // Full opacity grey

  // High contrast specific - borders for interactive elements
  static const Color border = Color(0xFF000000);
}

/// Helper to get colors based on high contrast mode
class AppColorScheme {
  final bool isHighContrast;

  const AppColorScheme({this.isHighContrast = false});

  Color get primaryBlue =>
      isHighContrast ? AppColorsHighContrast.primaryBlue : AppColors.primaryBlue;
  Color get accentCoral =>
      isHighContrast ? AppColorsHighContrast.accentCoral : AppColors.accentCoral;
  Color get thinkingGray =>
      isHighContrast ? AppColorsHighContrast.thinkingGray : AppColors.thinkingGray;
  Color get successGreen =>
      isHighContrast ? AppColorsHighContrast.successGreen : AppColors.successGreen;
  Color get background =>
      isHighContrast ? AppColorsHighContrast.background : AppColors.background;
  Color get cardBackground =>
      isHighContrast ? AppColorsHighContrast.cardBackground : AppColors.cardBackground;
  Color get textPrimary =>
      isHighContrast ? AppColorsHighContrast.textPrimary : AppColors.textPrimary;
  Color get textSecondary =>
      isHighContrast ? AppColorsHighContrast.textSecondary : AppColors.textSecondary;
  Color get divider =>
      isHighContrast ? AppColorsHighContrast.divider : AppColors.divider;
  Color get buttonGray =>
      isHighContrast ? AppColorsHighContrast.buttonGray : AppColors.buttonGray;
  Color get disabled =>
      isHighContrast ? AppColorsHighContrast.disabled : AppColors.disabled;
  Color get gradientStart =>
      isHighContrast ? AppColorsHighContrast.gradientStart : AppColors.gradientStart;
  Color get gradientEnd =>
      isHighContrast ? AppColorsHighContrast.gradientEnd : AppColors.gradientEnd;
  Color get voiceAgentGradientStart => isHighContrast
      ? AppColorsHighContrast.voiceAgentGradientStart
      : AppColors.voiceAgentGradientStart;
  Color get voiceAgentGradientEnd => isHighContrast
      ? AppColorsHighContrast.voiceAgentGradientEnd
      : AppColors.voiceAgentGradientEnd;
  Color get voiceAgentBorder =>
      isHighContrast ? AppColorsHighContrast.voiceAgentBorder : AppColors.voiceAgentBorder;
  Color get voiceAgentIcon =>
      isHighContrast ? AppColorsHighContrast.voiceAgentIcon : AppColors.voiceAgentIcon;

  // Thinking state colors
  Color get voiceAgentThinkingGradientStart => isHighContrast
      ? AppColorsHighContrast.voiceAgentThinkingGradientStart
      : AppColors.voiceAgentThinkingGradientStart;
  Color get voiceAgentThinkingGradientEnd => isHighContrast
      ? AppColorsHighContrast.voiceAgentThinkingGradientEnd
      : AppColors.voiceAgentThinkingGradientEnd;
  Color get voiceAgentThinkingBorder =>
      isHighContrast ? AppColorsHighContrast.voiceAgentThinkingBorder : AppColors.voiceAgentThinkingBorder;
  Color get voiceAgentThinkingIcon =>
      isHighContrast ? AppColorsHighContrast.voiceAgentThinkingIcon : AppColors.voiceAgentThinkingIcon;
  Color get primaryRed =>
      isHighContrast ? AppColorsHighContrast.primaryRed : AppColors.primaryRed;

  // Speaking state colors
  Color get voiceAgentSpeakingGradientStart => isHighContrast
      ? AppColorsHighContrast.voiceAgentSpeakingGradientStart
      : AppColors.voiceAgentSpeakingGradientStart;
  Color get voiceAgentSpeakingGradientEnd => isHighContrast
      ? AppColorsHighContrast.voiceAgentSpeakingGradientEnd
      : AppColors.voiceAgentSpeakingGradientEnd;
  Color get voiceAgentSpeakingBorder =>
      isHighContrast ? AppColorsHighContrast.voiceAgentSpeakingBorder : AppColors.voiceAgentSpeakingBorder;
  Color get voiceAgentSpeakingIcon =>
      isHighContrast ? AppColorsHighContrast.voiceAgentSpeakingIcon : AppColors.voiceAgentSpeakingIcon;

  Color get voiceAgentGradientStartInactive => isHighContrast
      ? AppColorsHighContrast.voiceAgentGradientStartInactive
      : AppColors.voiceAgentGradientStartInactive;
  Color get voiceAgentGradientEndInactive => isHighContrast
      ? AppColorsHighContrast.voiceAgentGradientEndInactive
      : AppColors.voiceAgentGradientEndInactive;
  Color get voiceAgentBorderInactive => isHighContrast
      ? AppColorsHighContrast.voiceAgentBorderInactive
      : AppColors.voiceAgentBorderInactive;
  Color get voiceAgentIconInactive => isHighContrast
      ? AppColorsHighContrast.voiceAgentIconInactive
      : AppColors.voiceAgentIconInactive;
  Color get border =>
      isHighContrast ? AppColorsHighContrast.border : Colors.transparent;
}

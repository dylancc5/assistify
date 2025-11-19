/// Design system spacing and dimensions for Assistify app
class AppDimensions {
  // Spacing system (multiples of 8)
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Border radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 24.0;

  // Voice Agent Circle
  static const double voiceAgentCircleSize = 180.0;
  static const double voiceAgentCircleSizeSmall = 160.0;
  static const double voiceAgentCircleSizeLarge = 200.0;
  static const double voiceAgentIconSize = 48.0;
  static const double voiceAgentBorderWidth = 3.0;

  // Control Buttons
  static const double controlButtonSize = 72.0;
  static const double controlButtonSizeSmall = 64.0;
  static const double controlButtonSizeLarge = 80.0;
  static const double controlButtonIconSize = 32.0;

  // App Bar
  static const double appBarHeight = 64.0;

  // Card elevation
  static const double cardElevation = 1.0;
  static const double modalElevation = 8.0;

  // Modal card width
  static const double modalCardWidthPercent = 0.9;

  // Touch target minimum size
  static const double minTouchTarget = 44.0;

  // Button heights
  static const double largeButtonHeight = 56.0;
  static const double mediumButtonHeight = 48.0;

  // List item height
  static const double listItemHeight = 56.0;

  /// Get responsive voice agent circle size based on screen width
  static double getVoiceAgentCircleSize(double screenWidth) {
    if (screenWidth < 375) {
      return voiceAgentCircleSizeSmall;
    } else if (screenWidth > 414) {
      return voiceAgentCircleSizeLarge;
    }
    return voiceAgentCircleSize;
  }

  /// Get responsive control button size based on screen width
  static double getControlButtonSize(double screenWidth) {
    if (screenWidth < 375) {
      return controlButtonSizeSmall;
    } else if (screenWidth > 414) {
      return controlButtonSizeLarge;
    }
    return controlButtonSize;
  }

  /// Get responsive padding multiplier based on screen width
  static double getPaddingMultiplier(double screenWidth) {
    if (screenWidth < 375) {
      return 0.8;
    } else if (screenWidth > 414) {
      return 1.2;
    }
    return 1.0;
  }
}

import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

/// Theme configuration for Assistify app
class AppTheme {
  /// Standard theme
  static ThemeData get standard => _buildTheme(
        primaryBlue: AppColors.primaryBlue,
        accentCoral: AppColors.accentCoral,
        background: AppColors.background,
        cardBackground: AppColors.cardBackground,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        divider: AppColors.divider,
        isHighContrast: false,
      );

  /// High contrast theme for accessibility
  static ThemeData get highContrast => _buildTheme(
        primaryBlue: AppColorsHighContrast.primaryBlue,
        accentCoral: AppColorsHighContrast.accentCoral,
        background: AppColorsHighContrast.background,
        cardBackground: AppColorsHighContrast.cardBackground,
        textPrimary: AppColorsHighContrast.textPrimary,
        textSecondary: AppColorsHighContrast.textSecondary,
        divider: AppColorsHighContrast.divider,
        isHighContrast: true,
      );

  static ThemeData _buildTheme({
    required Color primaryBlue,
    required Color accentCoral,
    required Color background,
    required Color cardBackground,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
    required bool isHighContrast,
  }) {
    final fontWeight = isHighContrast ? FontWeight.w600 : FontWeight.w400;
    final headingWeight = isHighContrast ? FontWeight.w700 : FontWeight.w600;
    final borderWidth = isHighContrast ? 2.0 : 0.0;
    final borderColor = isHighContrast ? AppColorsHighContrast.border : Colors.transparent;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentCoral,
        surface: cardBackground,
        error: accentCoral,
        onSurface: textPrimary,
        onPrimary: isHighContrast ? Colors.white : null,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: AppTextStyles.fontFamily,
      dividerColor: divider,

      // Text theme with bolder weights for high contrast
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontWeight: headingWeight,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontWeight: headingWeight,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontWeight: headingWeight,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontWeight: headingWeight,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontWeight: headingWeight,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontWeight: headingWeight,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontWeight: headingWeight,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontWeight: isHighContrast ? FontWeight.w600 : FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontWeight: isHighContrast ? FontWeight.w600 : FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontWeight: fontWeight,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontWeight: fontWeight,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontWeight: fontWeight,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontWeight: isHighContrast ? FontWeight.w600 : FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontWeight: isHighContrast ? FontWeight.w600 : FontWeight.w500,
          color: textPrimary,
        ),
        labelSmall: TextStyle(
          fontWeight: isHighContrast ? FontWeight.w600 : FontWeight.w500,
          color: textSecondary,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),

      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: isHighContrast ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: borderColor,
            width: borderWidth,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: AppTextStyles.buttonLabel.copyWith(
            fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: borderWidth,
            ),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AppTextStyles.buttonLabel.copyWith(
            fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(
            color: isHighContrast ? borderColor : primaryBlue,
            width: isHighContrast ? borderWidth : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppTextStyles.buttonLabel.copyWith(
            fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          side: isHighContrast
              ? BorderSide(color: borderColor, width: borderWidth)
              : null,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            // White thumb on colored track for better contrast
            return isHighContrast ? Colors.white : primaryBlue;
          }
          return isHighContrast ? Colors.white : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            // Full opacity track color in high contrast for visibility
            return isHighContrast ? primaryBlue : primaryBlue.withValues(alpha: 0.3);
          }
          // Dark track when off in high contrast mode
          return isHighContrast ? const Color(0xFF4A4A4A) : null;
        }),
        trackOutlineColor: isHighContrast
            ? WidgetStateProperty.all(borderColor)
            : null,
        trackOutlineWidth: isHighContrast
            ? WidgetStateProperty.all(borderWidth)
            : null,
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isHighContrast ? borderColor : divider,
            width: isHighContrast ? borderWidth : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isHighContrast ? borderColor : divider,
            width: isHighContrast ? borderWidth : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryBlue,
            width: isHighContrast ? borderWidth : 2,
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textPrimary,
        shape: isHighContrast
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: borderColor, width: borderWidth),
              )
            : null,
      ),

      // Extension for custom high contrast flag
      extensions: [
        AppThemeExtension(isHighContrast: isHighContrast),
      ],
    );
  }
}

/// Theme extension to track high contrast mode
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final bool isHighContrast;

  AppThemeExtension({required this.isHighContrast});

  @override
  ThemeExtension<AppThemeExtension> copyWith({bool? isHighContrast}) {
    return AppThemeExtension(
      isHighContrast: isHighContrast ?? this.isHighContrast,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

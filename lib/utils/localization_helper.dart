import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../models/preferences.dart';
import '../l10n/app_localizations.dart';

/// Helper class for localization based on user preferences
class LocalizationHelper {
  /// Get supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
  ];

  /// Get localization delegates
  static List<LocalizationsDelegate> get localizationDelegates => [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Get locale based on user preferences
  static Locale getLocaleFromPreferences(UserPreferences preferences) {
    return preferences.useSimplifiedChinese
        ? const Locale('zh')
        : const Locale('en');
  }

  /// Get AppLocalizations from context
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context)!;
  }
}


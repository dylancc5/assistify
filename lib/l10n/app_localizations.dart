import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Conversation history section title
  ///
  /// In en, this message translates to:
  /// **'Conversation History'**
  String get conversationHistory;

  /// Conversation history description
  ///
  /// In en, this message translates to:
  /// **'View your past conversations with Assistify'**
  String get viewYourPastConversations;

  /// Button to view conversation history
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get viewHistory;

  /// Screen recording history section title
  ///
  /// In en, this message translates to:
  /// **'Screen History'**
  String get screenHistory;

  /// Screen history description
  ///
  /// In en, this message translates to:
  /// **'View and manage your shared screens'**
  String get viewAndManageYourSharedScreens;

  /// Button to view screen recording history
  ///
  /// In en, this message translates to:
  /// **'View Screen History'**
  String get viewScreenHistory;

  /// Preferences section title
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Large text preference title
  ///
  /// In en, this message translates to:
  /// **'Large Text'**
  String get largeText;

  /// Large text preference description
  ///
  /// In en, this message translates to:
  /// **'Increase text size for better readability'**
  String get increaseTextSizeForBetterReadability;

  /// Slower speech preference title
  ///
  /// In en, this message translates to:
  /// **'Slower Speech'**
  String get slowerSpeech;

  /// Slower speech preference description
  ///
  /// In en, this message translates to:
  /// **'Reduce voice assistant speaking speed'**
  String get reduceVoiceAssistantSpeakingSpeed;

  /// High contrast mode preference title
  ///
  /// In en, this message translates to:
  /// **'High Contrast Mode'**
  String get highContrastMode;

  /// High contrast mode preference description
  ///
  /// In en, this message translates to:
  /// **'Increase contrast for better visibility'**
  String get increaseContrastForBetterVisibility;

  /// Simplified Chinese language preference title
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get simplifiedChinese;

  /// Simplified Chinese language preference description
  ///
  /// In en, this message translates to:
  /// **'Change app language to Simplified Chinese'**
  String get changeAppLanguageToSimplifiedChinese;

  /// About section title
  ///
  /// In en, this message translates to:
  /// **'About Assistify'**
  String get aboutAssistify;

  /// App version text
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// Privacy policy link
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Terms of service link
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Send feedback link
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// Coming soon message
  ///
  /// In en, this message translates to:
  /// **'{feature} - Coming soon'**
  String comingSoon(String feature);

  /// History screen title
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Empty state message for conversation history
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// Empty state description for conversation history
  ///
  /// In en, this message translates to:
  /// **'Your conversations with Assistify will appear here'**
  String get yourConversationsWithAssistifyWillAppearHere;

  /// Delete conversation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Conversation'**
  String get deleteConversation;

  /// Delete conversation confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this conversation? This action cannot be undone.'**
  String get areYouSureYouWantToDeleteThisConversation;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Conversation deleted confirmation message
  ///
  /// In en, this message translates to:
  /// **'Conversation deleted'**
  String get conversationDeleted;

  /// Empty state message for screen recordings
  ///
  /// In en, this message translates to:
  /// **'No Shared Screens Yet'**
  String get noSharedScreensYet;

  /// Empty state description for screen recordings
  ///
  /// In en, this message translates to:
  /// **'Share your screen from the home screen to see it here'**
  String get shareYourScreenFromTheHomeScreenToSeeItHere;

  /// Start chat button label
  ///
  /// In en, this message translates to:
  /// **'Start Chat'**
  String get startChat;

  /// End chat button label
  ///
  /// In en, this message translates to:
  /// **'End Chat'**
  String get endChat;

  /// Microphone button label
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get microphone;

  /// Share screen button label
  ///
  /// In en, this message translates to:
  /// **'Share Screen'**
  String get shareScreen;

  /// Screen recording permission modal title
  ///
  /// In en, this message translates to:
  /// **'Assistify needs to see your screen'**
  String get assistifyNeedsToSeeYourScreen;

  /// Screen recording permission modal description
  ///
  /// In en, this message translates to:
  /// **'This helps me understand what you\'re looking at and provide better assistance'**
  String get thisHelpsMeUnderstandWhatYouAreLookingAt;

  /// Screen recording permission button
  ///
  /// In en, this message translates to:
  /// **'Allow Screen Sharing'**
  String get allowScreenSharing;

  /// Microphone permission modal title
  ///
  /// In en, this message translates to:
  /// **'Assistify needs microphone access'**
  String get assistifyNeedsMicrophoneAccess;

  /// Microphone permission permanently denied message
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is permanently denied.\nPlease enable in settings.'**
  String get microphonePermissionIsPermanentlyDenied;

  /// Microphone permission modal description
  ///
  /// In en, this message translates to:
  /// **'This allows me to hear your questions and respond to you'**
  String get thisAllowsMeToHearYourQuestionsAndRespondToYou;

  /// Open settings button
  ///
  /// In en, this message translates to:
  /// **'OPEN SETTINGS'**
  String get openSettings;

  /// Allow microphone button
  ///
  /// In en, this message translates to:
  /// **'Allow Microphone'**
  String get allowMicrophone;

  /// Onboarding success title
  ///
  /// In en, this message translates to:
  /// **'Perfect! You\'re ready to go.'**
  String get perfectYouAreReadyToGo;

  /// Onboarding success description
  ///
  /// In en, this message translates to:
  /// **'Press \"Start Chat\" to start talking with me'**
  String get tapTheMicrophoneAnytimeToStartTalkingWithMe;

  /// Get started button
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Permission required dialog title
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// Screen recording permission required message
  ///
  /// In en, this message translates to:
  /// **'Screen recording permission is required for Assistify to work properly.'**
  String get screenRecordingPermissionIsRequired;

  /// Microphone permission required message
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for Assistify to work properly.'**
  String get microphonePermissionIsRequired;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Today label for dates
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Yesterday label for dates
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// Duration format
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} sec'**
  String durationFormat(int minutes, int seconds);

  /// Clear all button
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// Clear all conversations dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear All Conversations'**
  String get clearAllConversations;

  /// Clear all conversations confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all conversations? This action cannot be undone.'**
  String get areYouSureYouWantToClearAllConversations;

  /// All conversations cleared confirmation message
  ///
  /// In en, this message translates to:
  /// **'All conversations cleared'**
  String get allConversationsCleared;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

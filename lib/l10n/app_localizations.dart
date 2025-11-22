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

  /// Microphone button label when mic is on
  ///
  /// In en, this message translates to:
  /// **'Mic: ON'**
  String get micOn;

  /// Microphone button label when mic is off
  ///
  /// In en, this message translates to:
  /// **'Mic: OFF'**
  String get micOff;

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

  /// Show response text preference title
  ///
  /// In en, this message translates to:
  /// **'Show Response Text'**
  String get showResponseText;

  /// Show response text preference description
  ///
  /// In en, this message translates to:
  /// **'Display transcribed AI responses on screen'**
  String get displayTranscribedAIResponsesOnScreen;

  /// Label for last updated date on legal screens
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String legalLastUpdated(String date);

  /// Heading for legal contact card
  ///
  /// In en, this message translates to:
  /// **'Need help or have a question?'**
  String get legalContactHeading;

  /// Body text for legal contact card
  ///
  /// In en, this message translates to:
  /// **'Reach out to our team any time if you want to exercise your privacy rights, report a safety concern, or ask about these terms.'**
  String get legalContactBody;

  /// Support email address
  ///
  /// In en, this message translates to:
  /// **'support@assistify.ai'**
  String get legalContactEmail;

  /// Date shown in last-updated label for legal screens
  ///
  /// In en, this message translates to:
  /// **'November 21, 2025'**
  String get legalLastUpdatedDate;

  /// Privacy policy intro first paragraph
  ///
  /// In en, this message translates to:
  /// **'Assistify is a multimodal assistant built to keep seniors safe and confident while navigating smartphones.'**
  String get privacyPolicyIntroParagraph1;

  /// Privacy policy intro second paragraph
  ///
  /// In en, this message translates to:
  /// **'This privacy policy explains what information we process, why we need it, and the choices you have when using Assistify.'**
  String get privacyPolicyIntroParagraph2;

  /// Privacy policy data collection section title
  ///
  /// In en, this message translates to:
  /// **'Information we collect'**
  String get privacySectionDataWeCollectTitle;

  /// Privacy policy data collection section body
  ///
  /// In en, this message translates to:
  /// **'We only process information that helps deliver context-aware guidance, personalize accessibility, and protect you from scams.'**
  String get privacySectionDataWeCollectBody1;

  /// Bullet describing screen data
  ///
  /// In en, this message translates to:
  /// **'Screen understanding signals such as temporary captures, recognized UI elements, and safety flags generated while Assistify is guiding you.'**
  String get privacyDataWeCollectBulletScreen;

  /// Bullet describing audio data
  ///
  /// In en, this message translates to:
  /// **'Voice interactions, transcripts, and audio-level indicators required to understand your questions and respond through speech.'**
  String get privacyDataWeCollectBulletAudio;

  /// Bullet describing preference data
  ///
  /// In en, this message translates to:
  /// **'Accessibility preferences, language selections, and onboarding completion status stored on-device to keep your experience consistent.'**
  String get privacyDataWeCollectBulletPreferences;

  /// Bullet describing diagnostics data
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logs, performance metrics, and crash reports that help us maintain reliability. These never include full screen recordings unless you choose to share them with support.'**
  String get privacyDataWeCollectBulletDiagnostics;

  /// Section title for how information is used
  ///
  /// In en, this message translates to:
  /// **'How we use information'**
  String get privacyHowWeUseTitle;

  /// How we use information paragraph 1
  ///
  /// In en, this message translates to:
  /// **'We use the data above to provide real-time guidance, adapt recommendations to your preferences, detect scams, and keep the service running smoothly.'**
  String get privacyHowWeUseBody1;

  /// How we use information paragraph 2
  ///
  /// In en, this message translates to:
  /// **'Aggregated and de-identified analytics help us prioritize new accessibility features without identifying you personally.'**
  String get privacyHowWeUseBody2;

  /// Section title for information sharing
  ///
  /// In en, this message translates to:
  /// **'When we share information'**
  String get privacySharingTitle;

  /// Information sharing paragraph
  ///
  /// In en, this message translates to:
  /// **'We do not sell your personal data. We only share limited information when necessary to operate the service or comply with the law.'**
  String get privacySharingBody1;

  /// Vendors bullet
  ///
  /// In en, this message translates to:
  /// **'Trusted infrastructure and processing partners who host storage, speech, or safety services under strict contractual safeguards.'**
  String get privacySharingBulletVendors;

  /// Compliance bullet
  ///
  /// In en, this message translates to:
  /// **'Public authorities when legally required to respond to valid law-enforcement or safety requests.'**
  String get privacySharingBulletCompliance;

  /// Consent bullet
  ///
  /// In en, this message translates to:
  /// **'Third parties you explicitly authorize, such as caregivers you invite to review a conversation or recording.'**
  String get privacySharingBulletConsent;

  /// Safety section title
  ///
  /// In en, this message translates to:
  /// **'Safety and scam protection'**
  String get privacySafetyTitle;

  /// Safety paragraph 1
  ///
  /// In en, this message translates to:
  /// **'Assistify analyzes screen content to warn you about suspicious links, deceptive prompts, or potentially harmful actions before you tap.'**
  String get privacySafetyBody1;

  /// Safety paragraph 2
  ///
  /// In en, this message translates to:
  /// **'When we detect high-risk activity we may temporarily store relevant snippets so our trust team can investigate patterns of abuse.'**
  String get privacySafetyBody2;

  /// Storage section title
  ///
  /// In en, this message translates to:
  /// **'Storage and retention'**
  String get privacyStorageTitle;

  /// Storage paragraph 1
  ///
  /// In en, this message translates to:
  /// **'Most information, including preferences and histories, is stored locally on your device. Cloud backups are encrypted in transit and at rest.'**
  String get privacyStorageBody1;

  /// Storage paragraph 2
  ///
  /// In en, this message translates to:
  /// **'We retain transcripts, recordings, and diagnostics only as long as needed to provide the service or as required by law. You can delete them at any time from the history screens.'**
  String get privacyStorageBody2;

  /// Choices section title
  ///
  /// In en, this message translates to:
  /// **'Your choices and controls'**
  String get privacyChoicesTitle;

  /// Choices paragraph
  ///
  /// In en, this message translates to:
  /// **'Assistify was built to give you clear controls over your information.'**
  String get privacyChoicesBody1;

  /// Permissions choice bullet
  ///
  /// In en, this message translates to:
  /// **'Adjust microphone and screen permissions directly in system settings. Assistify will always explain why a permission is required.'**
  String get privacyChoicesBulletPermissions;

  /// History choice bullet
  ///
  /// In en, this message translates to:
  /// **'Review, export, or delete individual conversations and screen recordings from their respective history pages.'**
  String get privacyChoicesBulletHistory;

  /// Preferences choice bullet
  ///
  /// In en, this message translates to:
  /// **'Update accessibility preferences—such as large text, slower speech, or high contrast—without affecting stored data.'**
  String get privacyChoicesBulletPreferences;

  /// Contact choice bullet
  ///
  /// In en, this message translates to:
  /// **'Contact us if you need help accessing, correcting, or limiting any information we hold about you.'**
  String get privacyChoicesBulletContact;

  /// Children section title
  ///
  /// In en, this message translates to:
  /// **'Children’s privacy'**
  String get privacyChildrenTitle;

  /// Children paragraph
  ///
  /// In en, this message translates to:
  /// **'Assistify is intended for individuals 13 years and older. We do not knowingly collect personal data from children and will delete any such data if we learn a minor is using the service without guardian consent.'**
  String get privacyChildrenBody1;

  /// International transfers title
  ///
  /// In en, this message translates to:
  /// **'International data transfers'**
  String get privacyInternationalTitle;

  /// International transfers paragraph
  ///
  /// In en, this message translates to:
  /// **'Assistify may process data in the United States and other locations where our partners operate. We apply comparable safeguards regardless of where data is stored.'**
  String get privacyInternationalBody1;

  /// Changes section title
  ///
  /// In en, this message translates to:
  /// **'How we’ll notify you about changes'**
  String get privacyChangesTitle;

  /// Changes paragraph 1
  ///
  /// In en, this message translates to:
  /// **'We may update this policy to reflect new features or regulatory requirements. Material updates will be highlighted inside the app and through release notes.'**
  String get privacyChangesBody1;

  /// Changes paragraph 2
  ///
  /// In en, this message translates to:
  /// **'If you continue using Assistify after a revision becomes effective, you agree to the updated policy.'**
  String get privacyChangesBody2;

  /// Terms acceptance section title
  ///
  /// In en, this message translates to:
  /// **'Acceptance of these terms'**
  String get legalAcceptanceTitle;

  /// Terms intro first paragraph
  ///
  /// In en, this message translates to:
  /// **'These Terms of Service govern your use of the Assistify mobile application and any related services.'**
  String get termsIntroParagraph1;

  /// Terms intro second paragraph
  ///
  /// In en, this message translates to:
  /// **'By installing, accessing, or using Assistify you agree to be bound by these Terms and our Privacy Policy.'**
  String get termsIntroParagraph2;

  /// Terms acceptance body text
  ///
  /// In en, this message translates to:
  /// **'If you do not agree with these Terms, do not use the service. We may update the Terms as the product evolves, and your continued use means you accept the revised version.'**
  String get termsAcceptanceBody1;

  /// Service section title
  ///
  /// In en, this message translates to:
  /// **'Description of the service'**
  String get termsSectionServiceTitle;

  /// Service body paragraph 1
  ///
  /// In en, this message translates to:
  /// **'Assistify provides context-aware guidance by combining screen understanding, speech recognition, and conversational AI to help seniors complete tasks safely.'**
  String get termsSectionServiceBody1;

  /// Service body paragraph 2
  ///
  /// In en, this message translates to:
  /// **'Assistify does not replace professional caregivers, medical providers, or financial advisors. You remain responsible for decisions you make based on the guidance provided.'**
  String get termsSectionServiceBody2;

  /// Eligibility section title
  ///
  /// In en, this message translates to:
  /// **'Eligibility and onboarding'**
  String get termsSectionEligibilityTitle;

  /// Eligibility paragraph 1
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13 years old, reside in a region where Assistify is available, and have the legal capacity to enter these Terms.'**
  String get termsSectionEligibilityBody1;

  /// Eligibility paragraph 2
  ///
  /// In en, this message translates to:
  /// **'To unlock full functionality you must complete onboarding, grant required permissions, and ensure device compatibility.'**
  String get termsSectionEligibilityBody2;

  /// Permissions section title
  ///
  /// In en, this message translates to:
  /// **'Permissions and user responsibilities'**
  String get termsSectionPermissionsTitle;

  /// Permissions paragraph
  ///
  /// In en, this message translates to:
  /// **'Assistify requires microphone access, screen recording access, and stable connectivity to deliver guidance. You agree to:'**
  String get termsSectionPermissionsBody1;

  /// Permissions bullet accurate info
  ///
  /// In en, this message translates to:
  /// **'Provide accurate information when asked about your device, goals, or safety concerns.'**
  String get termsSectionPermissionsBulletAccurateInfo;

  /// Permissions bullet environment
  ///
  /// In en, this message translates to:
  /// **'Use the app in environments where screen sharing is permitted and does not expose confidential data without consent.'**
  String get termsSectionPermissionsBulletEnvironment;

  /// Permissions bullet notifications
  ///
  /// In en, this message translates to:
  /// **'Review and follow the safety prompts Assistify surfaces before acting on them.'**
  String get termsSectionPermissionsBulletNotifications;

  /// Acceptable use section title
  ///
  /// In en, this message translates to:
  /// **'Acceptable use'**
  String get termsSectionAcceptableUseTitle;

  /// Acceptable use paragraph
  ///
  /// In en, this message translates to:
  /// **'You agree not to misuse Assistify or help others do so. Prohibited conduct includes:'**
  String get termsSectionAcceptableUseBody1;

  /// Acceptable use bullet malicious
  ///
  /// In en, this message translates to:
  /// **'Reverse engineering, probing, or interfering with Assistify’s infrastructure or security safeguards.'**
  String get termsAcceptableUseBulletMalicious;

  /// Acceptable use bullet scams
  ///
  /// In en, this message translates to:
  /// **'Using the service to plan, execute, or amplify scams, fraud, or other deceptive practices.'**
  String get termsAcceptableUseBulletScams;

  /// Acceptable use bullet unlawful
  ///
  /// In en, this message translates to:
  /// **'Uploading or sharing content that infringes intellectual property rights or violates applicable laws.'**
  String get termsAcceptableUseBulletUnlawful;

  /// Acceptable use bullet interfere
  ///
  /// In en, this message translates to:
  /// **'Attempting to overload networks, harvest data, or disrupt other users’ experience.'**
  String get termsAcceptableUseBulletInterfere;

  /// AI guidance section title
  ///
  /// In en, this message translates to:
  /// **'AI guidance and limitations'**
  String get termsSectionAIGuidanceTitle;

  /// AI guidance paragraph
  ///
  /// In en, this message translates to:
  /// **'Assistify relies on AI models and real-time screen understanding. While we strive for accuracy, AI-generated guidance may occasionally be incorrect or outdated.'**
  String get termsSectionAIGuidanceBody1;

  /// AI guidance bullet accuracy
  ///
  /// In en, this message translates to:
  /// **'Information provided is for assistance only and may not reflect the latest user interface changes.'**
  String get termsSectionAIGuidanceBulletAccuracy;

  /// AI guidance bullet verification
  ///
  /// In en, this message translates to:
  /// **'You remain responsible for reviewing instructions before acting, especially when sending money or sharing personal data.'**
  String get termsSectionAIGuidanceBulletVerification;

  /// AI guidance bullet emergencies
  ///
  /// In en, this message translates to:
  /// **'Assistify is not an emergency service. Call your local authorities in case of urgent medical, safety, or financial threats.'**
  String get termsSectionAIGuidanceBulletEmergencies;

  /// Privacy section title
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get termsSectionPrivacyTitle;

  /// Privacy section body
  ///
  /// In en, this message translates to:
  /// **'Use of Assistify is also governed by our Privacy Policy, which explains how we collect and protect personal data.'**
  String get termsSectionPrivacyBody1;

  /// Third-party section title
  ///
  /// In en, this message translates to:
  /// **'Third-party services and links'**
  String get termsSectionThirdPartyTitle;

  /// Third-party section body
  ///
  /// In en, this message translates to:
  /// **'Assistify may guide you through third-party apps or websites. Those services are governed by their own terms and privacy policies.'**
  String get termsSectionThirdPartyBody1;

  /// Availability section title
  ///
  /// In en, this message translates to:
  /// **'Service availability and changes'**
  String get termsSectionAvailabilityTitle;

  /// Availability paragraph 1
  ///
  /// In en, this message translates to:
  /// **'We may add, remove, or change features, and we may suspend the service to address maintenance or security issues.'**
  String get termsSectionAvailabilityBody1;

  /// Availability paragraph 2
  ///
  /// In en, this message translates to:
  /// **'Assistify is provided on an as-available basis. We are not liable for delays or failures caused by events outside our control.'**
  String get termsSectionAvailabilityBody2;

  /// Termination section title
  ///
  /// In en, this message translates to:
  /// **'Termination'**
  String get termsSectionTerminationTitle;

  /// Termination paragraph 1
  ///
  /// In en, this message translates to:
  /// **'You may stop using Assistify at any time. Delete the app to revoke its permissions and remove local data.'**
  String get termsSectionTerminationBody1;

  /// Termination paragraph 2
  ///
  /// In en, this message translates to:
  /// **'We may suspend or terminate access if you violate these Terms, misuse permissions, or compromise the safety of others.'**
  String get termsSectionTerminationBody2;

  /// Disclaimers section title
  ///
  /// In en, this message translates to:
  /// **'Disclaimers and limitation of liability'**
  String get termsSectionDisclaimersTitle;

  /// Disclaimers paragraph 1
  ///
  /// In en, this message translates to:
  /// **'Assistify is provided “as is” without warranties of accuracy, reliability, or fitness for a particular purpose.'**
  String get termsSectionDisclaimersBody1;

  /// Disclaimers paragraph 2
  ///
  /// In en, this message translates to:
  /// **'To the extent permitted by law, Assistify and its partners will not be liable for indirect, incidental, or consequential damages arising from your use of the service.'**
  String get termsSectionDisclaimersBody2;

  /// Governing law section title
  ///
  /// In en, this message translates to:
  /// **'Governing law'**
  String get termsSectionGoverningLawTitle;

  /// Governing law paragraph
  ///
  /// In en, this message translates to:
  /// **'These Terms are governed by the laws of the State of California, excluding its conflict-of-law rules, unless the laws of your jurisdiction require otherwise.'**
  String get termsSectionGoverningLawBody1;

  /// Feedback dialog title
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get feedbackTitle;

  /// Label for feedback text field
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get feedbackIssueLabel;

  /// Hint text for feedback field
  ///
  /// In en, this message translates to:
  /// **'Describe your issue or suggestion...'**
  String get feedbackIssueHint;

  /// Label for optional rating
  ///
  /// In en, this message translates to:
  /// **'Rating (optional)'**
  String get feedbackRatingLabel;

  /// Submit feedback button
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get feedbackSubmit;

  /// Feedback sent confirmation
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get feedbackSent;
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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get conversationHistory => 'Conversation History';

  @override
  String get viewYourPastConversations =>
      'View your past conversations with Assistify';

  @override
  String get viewHistory => 'View History';

  @override
  String get screenHistory => 'Screen History';

  @override
  String get viewAndManageYourSharedScreens =>
      'View and manage your shared screens';

  @override
  String get viewScreenHistory => 'View Screen History';

  @override
  String get preferences => 'Preferences';

  @override
  String get largeText => 'Large Text';

  @override
  String get increaseTextSizeForBetterReadability =>
      'Increase text size for better readability';

  @override
  String get slowerSpeech => 'Slower Speech';

  @override
  String get reduceVoiceAssistantSpeakingSpeed =>
      'Reduce voice assistant speaking speed';

  @override
  String get highContrastMode => 'High Contrast Mode';

  @override
  String get increaseContrastForBetterVisibility =>
      'Increase contrast for better visibility';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get changeAppLanguageToSimplifiedChinese =>
      'Change app language to Simplified Chinese';

  @override
  String get aboutAssistify => 'About Assistify';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get sendFeedback => 'Send Feedback';

  @override
  String comingSoon(String feature) {
    return '$feature - Coming soon';
  }

  @override
  String get history => 'History';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get yourConversationsWithAssistifyWillAppearHere =>
      'Your conversations with Assistify will appear here';

  @override
  String get deleteConversation => 'Delete Conversation';

  @override
  String get areYouSureYouWantToDeleteThisConversation =>
      'Are you sure you want to delete this conversation? This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get conversationDeleted => 'Conversation deleted';

  @override
  String get noSharedScreensYet => 'No Shared Screens Yet';

  @override
  String get shareYourScreenFromTheHomeScreenToSeeItHere =>
      'Share your screen from the home screen to see it here';

  @override
  String get startChat => 'Start Chat';

  @override
  String get endChat => 'End Chat';

  @override
  String get microphone => 'Microphone';

  @override
  String get shareScreen => 'Share Screen';

  @override
  String get assistifyNeedsToSeeYourScreen =>
      'Assistify needs to see your screen';

  @override
  String get thisHelpsMeUnderstandWhatYouAreLookingAt =>
      'This helps me understand what you\'re looking at and provide better assistance';

  @override
  String get allowScreenSharing => 'Allow Screen Sharing';

  @override
  String get assistifyNeedsMicrophoneAccess =>
      'Assistify needs microphone access';

  @override
  String get microphonePermissionIsPermanentlyDenied =>
      'Microphone permission is permanently denied.\nPlease enable in settings.';

  @override
  String get thisAllowsMeToHearYourQuestionsAndRespondToYou =>
      'This allows me to hear your questions and respond to you';

  @override
  String get openSettings => 'OPEN SETTINGS';

  @override
  String get allowMicrophone => 'Allow Microphone';

  @override
  String get perfectYouAreReadyToGo => 'Perfect! You\'re ready to go.';

  @override
  String get tapTheMicrophoneAnytimeToStartTalkingWithMe =>
      'Press \"Start Chat\" to start talking with me';

  @override
  String get getStarted => 'Get Started';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get screenRecordingPermissionIsRequired =>
      'Screen recording permission is required for Assistify to work properly.';

  @override
  String get microphonePermissionIsRequired =>
      'Microphone permission is required for Assistify to work properly.';

  @override
  String get ok => 'OK';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String durationFormat(int minutes, int seconds) {
    return '$minutes min $seconds sec';
  }

  @override
  String get clearAll => 'Clear All';

  @override
  String get clearAllConversations => 'Clear All Conversations';

  @override
  String get areYouSureYouWantToClearAllConversations =>
      'Are you sure you want to clear all conversations? This action cannot be undone.';

  @override
  String get allConversationsCleared => 'All conversations cleared';
}

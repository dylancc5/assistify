// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settings => '设置';

  @override
  String get conversationHistory => '对话历史';

  @override
  String get viewYourPastConversations => '查看您与 Assistify 的过往对话';

  @override
  String get viewHistory => '查看历史';

  @override
  String get screenHistory => '屏幕历史';

  @override
  String get viewAndManageYourSharedScreens => '查看和管理您共享的屏幕';

  @override
  String get viewScreenHistory => '查看屏幕历史';

  @override
  String get preferences => '偏好设置';

  @override
  String get largeText => '大字体';

  @override
  String get increaseTextSizeForBetterReadability => '增大字体以提高可读性';

  @override
  String get slowerSpeech => '慢速语音';

  @override
  String get reduceVoiceAssistantSpeakingSpeed => '降低语音助手的语速';

  @override
  String get highContrastMode => '高对比度模式';

  @override
  String get increaseContrastForBetterVisibility => '增加对比度以提高可见性';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get changeAppLanguageToSimplifiedChinese => '将应用语言更改为简体中文';

  @override
  String get aboutAssistify => '关于 Assistify';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '服务条款';

  @override
  String get sendFeedback => '发送反馈';

  @override
  String comingSoon(String feature) {
    return '$feature - 即将推出';
  }

  @override
  String get history => '历史';

  @override
  String get noConversationsYet => '还没有对话';

  @override
  String get yourConversationsWithAssistifyWillAppearHere =>
      '您与 Assistify 的对话将显示在这里';

  @override
  String get deleteConversation => '删除对话';

  @override
  String get areYouSureYouWantToDeleteThisConversation => '您确定要删除此对话吗？此操作无法撤销。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get conversationDeleted => '对话已删除';

  @override
  String get noSharedScreensYet => '还没有共享屏幕';

  @override
  String get shareYourScreenFromTheHomeScreenToSeeItHere => '从主屏幕共享您的屏幕即可在此处查看';

  @override
  String get startChat => '开始对话';

  @override
  String get endChat => '结束对话';

  @override
  String get microphone => '麦克风';

  @override
  String get shareScreen => '共享屏幕';

  @override
  String get assistifyNeedsToSeeYourScreen => 'Assistify 需要查看您的屏幕';

  @override
  String get thisHelpsMeUnderstandWhatYouAreLookingAt =>
      '这有助于我了解您正在查看的内容并提供更好的帮助';

  @override
  String get allowScreenSharing => '允许屏幕共享';

  @override
  String get assistifyNeedsMicrophoneAccess => 'Assistify 需要麦克风权限';

  @override
  String get microphonePermissionIsPermanentlyDenied =>
      '麦克风权限已被永久拒绝。\n请在设置中启用。';

  @override
  String get thisAllowsMeToHearYourQuestionsAndRespondToYou => '这允许我听到您的问题并回复您';

  @override
  String get openSettings => '打开设置';

  @override
  String get allowMicrophone => '允许麦克风';

  @override
  String get perfectYouAreReadyToGo => '完美！您已准备就绪。';

  @override
  String get tapTheMicrophoneAnytimeToStartTalkingWithMe => '按\"开始对话\"开始与我对话';

  @override
  String get getStarted => '开始使用';

  @override
  String get permissionRequired => '需要权限';

  @override
  String get screenRecordingPermissionIsRequired => 'Assistify 需要屏幕录制权限才能正常工作。';

  @override
  String get microphonePermissionIsRequired => 'Assistify 需要麦克风权限才能正常工作。';

  @override
  String get ok => '确定';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get monday => '星期一';

  @override
  String get tuesday => '星期二';

  @override
  String get wednesday => '星期三';

  @override
  String get thursday => '星期四';

  @override
  String get friday => '星期五';

  @override
  String get saturday => '星期六';

  @override
  String get sunday => '星期日';

  @override
  String get am => '上午';

  @override
  String get pm => '下午';

  @override
  String durationFormat(int minutes, int seconds) {
    return '$minutes 分 $seconds 秒';
  }

  @override
  String get clearAll => '清除全部';

  @override
  String get clearAllConversations => '清除所有对话';

  @override
  String get areYouSureYouWantToClearAllConversations => '您确定要清除所有对话吗？此操作无法撤销。';

  @override
  String get allConversationsCleared => '所有对话已清除';

  @override
  String get showResponseText => '显示回复文本';

  @override
  String get displayTranscribedAIResponsesOnScreen => '在屏幕上显示AI回复文本';
}

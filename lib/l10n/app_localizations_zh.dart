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

  @override
  String legalLastUpdated(String date) {
    return '最近更新：$date';
  }

  @override
  String get legalContactHeading => '需要帮助或有疑问？';

  @override
  String get legalContactBody => '如果您希望行使隐私权、报告安全问题或了解这些条款，请随时与我们联系。';

  @override
  String get legalContactEmail => 'support@assistify.ai';

  @override
  String get legalLastUpdatedDate => '2025年11月21日';

  @override
  String get privacyPolicyIntroParagraph1 =>
      'Assistify 是为帮助老年用户安心使用智能手机而打造的多模态助手。';

  @override
  String get privacyPolicyIntroParagraph2 =>
      '本隐私政策说明我们处理哪些信息、处理目的以及您使用 Assistify 时拥有的选择。';

  @override
  String get privacySectionDataWeCollectTitle => '我们收集的信息';

  @override
  String get privacySectionDataWeCollectBody1 =>
      '我们只处理能够提供上下文指导、个性化辅助功能并保护您免受诈骗所必需的数据。';

  @override
  String get privacyDataWeCollectBulletScreen =>
      '屏幕理解信号，例如临时截图、识别到的界面元素以及在引导过程中生成的安全标记。';

  @override
  String get privacyDataWeCollectBulletAudio =>
      '语音交互、文字转写以及音量指标，用于理解您的问题并提供语音回复。';

  @override
  String get privacyDataWeCollectBulletPreferences =>
      '无障碍偏好、语言选择以及引导完成状态会保存在设备上，以保持体验一致。';

  @override
  String get privacyDataWeCollectBulletDiagnostics =>
      '诊断日志、性能指标与崩溃报告，帮助我们维持稳定。除非您主动共享，否则这些信息不会包含完整的屏幕录制。';

  @override
  String get privacyHowWeUseTitle => '我们如何使用信息';

  @override
  String get privacyHowWeUseBody1 => '我们利用上述数据提供实时指引、根据您的偏好调整建议、检测诈骗并保证服务顺畅运行。';

  @override
  String get privacyHowWeUseBody2 =>
      '我们对数据进行汇总和去标识化处理，用于规划新的无障碍功能，而不会识别您的个人身份。';

  @override
  String get privacySharingTitle => '在何种情况下共享信息';

  @override
  String get privacySharingBody1 => '我们不会出售您的个人数据。只有在运营服务或法律要求时才会有限共享。';

  @override
  String get privacySharingBulletVendors =>
      '值得信赖的基础设施与处理合作伙伴，他们在严格的合同保障下托管存储、语音或安全服务。';

  @override
  String get privacySharingBulletCompliance => '在法律要求时响应有效的执法或安全请求。';

  @override
  String get privacySharingBulletConsent => '您明确授权的第三方，例如被邀请查看对话或录屏的照护者。';

  @override
  String get privacySafetyTitle => '安全与诈骗防护';

  @override
  String get privacySafetyBody1 =>
      'Assistify 会分析屏幕内容，在您点击前提醒可疑链接、误导性提示或潜在危险操作。';

  @override
  String get privacySafetyBody2 => '当检测到高风险活动时，我们可能临时保存相关片段，以便信任与安全团队调查滥用模式。';

  @override
  String get privacyStorageTitle => '存储与保留';

  @override
  String get privacyStorageBody1 => '大多数信息（包括偏好和历史记录）保存在设备本地。云备份在传输和存储时均经过加密。';

  @override
  String get privacyStorageBody2 =>
      '我们只在提供服务或符合法律要求的期限内保留转写、录制和诊断数据。您可以随时在历史页面删除它们。';

  @override
  String get privacyChoicesTitle => '您的选择与控制';

  @override
  String get privacyChoicesBody1 => 'Assistify 让您可以清晰地掌控个人信息。';

  @override
  String get privacyChoicesBulletPermissions =>
      '可在系统设置中调整麦克风和屏幕权限，Assistify 始终会说明权限用途。';

  @override
  String get privacyChoicesBulletHistory => '在各自的历史页面查看、导出或删除单独的对话和屏幕录制。';

  @override
  String get privacyChoicesBulletPreferences =>
      '随时更新无障碍偏好（如大字体、慢速语音或高对比度），不会影响已存储的数据。';

  @override
  String get privacyChoicesBulletContact => '若需访问、纠正或限制我们持有的任何信息，请与我们联系。';

  @override
  String get privacyChildrenTitle => '未成年人隐私';

  @override
  String get privacyChildrenBody1 =>
      'Assistify 面向 13 岁及以上用户。我们不会主动收集儿童数据，如发现未成年人在未获监护人同意的情况下使用，我们将删除相关信息。';

  @override
  String get privacyInternationalTitle => '跨境数据传输';

  @override
  String get privacyInternationalBody1 =>
      'Assistify 可能在美国或合作伙伴所在地区处理数据。无论数据存储地点如何，我们都会施加相同的保护措施。';

  @override
  String get privacyChangesTitle => '政策变更通知';

  @override
  String get privacyChangesBody1 => '我们可能因新增功能或法规要求而更新本政策。重大更新会在应用内和发行说明中突出显示。';

  @override
  String get privacyChangesBody2 => '在修订生效后继续使用 Assistify，即表示您同意更新后的政策。';

  @override
  String get legalAcceptanceTitle => '接受条款';

  @override
  String get termsIntroParagraph1 => '本服务条款约束您对 Assistify 移动应用及相关服务的使用。';

  @override
  String get termsIntroParagraph2 => '安装、访问或使用 Assistify 即表示您同意遵守本条款及我们的隐私政策。';

  @override
  String get termsAcceptanceBody1 =>
      '如果您不同意这些条款，请勿使用本服务。随着产品迭代，我们可能更新条款，继续使用即表示您接受更新内容。';

  @override
  String get termsSectionServiceTitle => '服务说明';

  @override
  String get termsSectionServiceBody1 =>
      'Assistify 结合屏幕理解、语音识别与对话式 AI，为老年用户提供具备情境感知的安全指导。';

  @override
  String get termsSectionServiceBody2 =>
      'Assistify 不能替代专业护理人员、医疗机构或理财顾问。您仍需对依据指引所做的决定负责。';

  @override
  String get termsSectionEligibilityTitle => '适用对象与引导';

  @override
  String get termsSectionEligibilityBody1 =>
      '您必须年满 13 岁，位于 Assistify 提供服务的地区，并具备签署本条款的法律能力。';

  @override
  String get termsSectionEligibilityBody2 => '为获得完整体验，您需要完成引导、授予必要权限并确保设备兼容。';

  @override
  String get termsSectionPermissionsTitle => '权限与用户责任';

  @override
  String get termsSectionPermissionsBody1 =>
      'Assistify 需要麦克风、屏幕录制权限以及稳定的网络连接。您同意：';

  @override
  String get termsSectionPermissionsBulletAccurateInfo =>
      '在被询问设备、目标或安全问题时提供准确信息。';

  @override
  String get termsSectionPermissionsBulletEnvironment =>
      '仅在允许屏幕共享的环境中使用应用，并在分享他人数据前取得同意。';

  @override
  String get termsSectionPermissionsBulletNotifications =>
      '在采取行动前仔细阅读并遵循 Assistify 显示的安全提示。';

  @override
  String get termsSectionAcceptableUseTitle => '可接受的使用方式';

  @override
  String get termsSectionAcceptableUseBody1 =>
      '您同意不滥用 Assistify，也不会协助他人如此。禁止行为包括：';

  @override
  String get termsAcceptableUseBulletMalicious =>
      '对 Assistify 的基础设施或安全防护进行逆向、探测或破坏。';

  @override
  String get termsAcceptableUseBulletScams => '利用本服务策划、实施或传播诈骗、欺诈或其他欺骗行为。';

  @override
  String get termsAcceptableUseBulletUnlawful => '上传或分享侵犯知识产权或违反法律的内容。';

  @override
  String get termsAcceptableUseBulletInterfere => '试图过载网络、收集他人数据或干扰其他用户体验。';

  @override
  String get termsSectionAIGuidanceTitle => 'AI 指引及其限制';

  @override
  String get termsSectionAIGuidanceBody1 =>
      'Assistify 依赖 AI 模型与实时屏幕理解。尽管我们追求准确，AI 生成的指引有时可能不完整或已过时。';

  @override
  String get termsSectionAIGuidanceBulletAccuracy => '提供的信息仅供辅助，可能无法反映最新的界面变化。';

  @override
  String get termsSectionAIGuidanceBulletVerification =>
      '在转账或分享个人数据前，您有责任再次确认指导内容。';

  @override
  String get termsSectionAIGuidanceBulletEmergencies =>
      'Assistify 不是紧急服务。如遇紧急医疗、安全或财务威胁，请联系当地相关机构。';

  @override
  String get termsSectionPrivacyTitle => '隐私与安全';

  @override
  String get termsSectionPrivacyBody1 =>
      '使用 Assistify 亦受到我们的隐私政策约束，该政策说明我们如何收集并保护个人数据。';

  @override
  String get termsSectionThirdPartyTitle => '第三方服务与链接';

  @override
  String get termsSectionThirdPartyBody1 =>
      'Assistify 可能引导您使用第三方应用或网站，这些服务受其各自的条款与隐私政策约束。';

  @override
  String get termsSectionAvailabilityTitle => '服务可用性与变更';

  @override
  String get termsSectionAvailabilityBody1 => '我们可能新增、移除或修改功能，并可为维护或安全需要而暂停服务。';

  @override
  String get termsSectionAvailabilityBody2 =>
      'Assistify 以“按现状”和“视可用性”方式提供。对于不可抗力造成的延迟或故障，我们不承担责任。';

  @override
  String get termsSectionTerminationTitle => '终止';

  @override
  String get termsSectionTerminationBody1 =>
      '您可随时停止使用 Assistify。删除应用即可撤销权限并移除本地数据。';

  @override
  String get termsSectionTerminationBody2 => '如您违反条款、滥用权限或危害他人安全，我们可暂停或终止您的访问。';

  @override
  String get termsSectionDisclaimersTitle => '免责声明与责任限制';

  @override
  String get termsSectionDisclaimersBody1 =>
      'Assistify 按“现状”提供，不对准确性、可靠性或特定用途适用性作出任何担保。';

  @override
  String get termsSectionDisclaimersBody2 =>
      '在法律允许范围内，Assistify 及其合作伙伴不对因使用本服务而产生的间接、附带或后果性损失负责。';

  @override
  String get termsSectionGoverningLawTitle => '适用法律';

  @override
  String get termsSectionGoverningLawBody1 =>
      '除非您所在司法辖区另有强制规定，本条款受美国加利福尼亚州法律管辖，并排除其法律冲突规则。';

  @override
  String get feedbackTitle => '发送反馈';

  @override
  String get feedbackIssueLabel => '您想告诉我们什么？';

  @override
  String get feedbackIssueHint => '描述您的问题或建议...';

  @override
  String get feedbackRatingLabel => '评分（可选）';

  @override
  String get feedbackSubmit => '提交';

  @override
  String get feedbackSent => '感谢您的反馈！';
}

/// User preferences model
class UserPreferences {
  final bool largeTextEnabled;
  final bool slowerSpeechEnabled;
  final bool highContrastEnabled;
  final bool useSimplifiedChinese;
  final bool showTranscribedText;

  const UserPreferences({
    this.largeTextEnabled = false,
    this.slowerSpeechEnabled = false,
    this.highContrastEnabled = false,
    this.useSimplifiedChinese = false,
    this.showTranscribedText = true,
  });

  /// Create copy with updated values
  UserPreferences copyWith({
    bool? largeTextEnabled,
    bool? slowerSpeechEnabled,
    bool? highContrastEnabled,
    bool? useSimplifiedChinese,
    bool? showTranscribedText,
  }) {
    return UserPreferences(
      largeTextEnabled: largeTextEnabled ?? this.largeTextEnabled,
      slowerSpeechEnabled: slowerSpeechEnabled ?? this.slowerSpeechEnabled,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      useSimplifiedChinese: useSimplifiedChinese ?? this.useSimplifiedChinese,
      showTranscribedText: showTranscribedText ?? this.showTranscribedText,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'largeTextEnabled': largeTextEnabled,
      'slowerSpeechEnabled': slowerSpeechEnabled,
      'highContrastEnabled': highContrastEnabled,
      'useSimplifiedChinese': useSimplifiedChinese,
      'showTranscribedText': showTranscribedText,
    };
  }

  /// Create from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      largeTextEnabled: json['largeTextEnabled'] as bool? ?? false,
      slowerSpeechEnabled: json['slowerSpeechEnabled'] as bool? ?? false,
      highContrastEnabled: json['highContrastEnabled'] as bool? ?? false,
      useSimplifiedChinese: json['useSimplifiedChinese'] as bool? ?? false,
      showTranscribedText: json['showTranscribedText'] as bool? ?? true,
    );
  }

  /// Get text scale factor based on preferences
  double get textScaleFactor => largeTextEnabled ? 1.2 : 1.0;

  /// Get language code for speech recognition
  /// iOS uses "zh-Hans" for Simplified Chinese
  String get languageCode => useSimplifiedChinese ? 'zh-Hans' : 'en-US';
}

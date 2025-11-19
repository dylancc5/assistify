/// User preferences model
class UserPreferences {
  final bool largeTextEnabled;
  final bool slowerSpeechEnabled;
  final bool highContrastEnabled;

  const UserPreferences({
    this.largeTextEnabled = false,
    this.slowerSpeechEnabled = false,
    this.highContrastEnabled = false,
  });

  /// Create copy with updated values
  UserPreferences copyWith({
    bool? largeTextEnabled,
    bool? slowerSpeechEnabled,
    bool? highContrastEnabled,
  }) {
    return UserPreferences(
      largeTextEnabled: largeTextEnabled ?? this.largeTextEnabled,
      slowerSpeechEnabled: slowerSpeechEnabled ?? this.slowerSpeechEnabled,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'largeTextEnabled': largeTextEnabled,
      'slowerSpeechEnabled': slowerSpeechEnabled,
      'highContrastEnabled': highContrastEnabled,
    };
  }

  /// Create from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      largeTextEnabled: json['largeTextEnabled'] as bool? ?? false,
      slowerSpeechEnabled: json['slowerSpeechEnabled'] as bool? ?? false,
      highContrastEnabled: json['highContrastEnabled'] as bool? ?? false,
    );
  }

  /// Get text scale factor based on preferences
  double get textScaleFactor => largeTextEnabled ? 1.2 : 1.0;
}

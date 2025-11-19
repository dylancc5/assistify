import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/preferences.dart';
import '../models/conversation.dart';
import '../models/screen_recording.dart';

/// Service for local data persistence
class StorageService {
  static const String _keyOnboardingComplete = 'onboarding_complete';
  static const String _keyScreenRecordingPermission = 'screen_recording_permission';
  static const String _keyMicrophonePermission = 'microphone_permission';
  static const String _keyUserPreferences = 'user_preferences';
  static const String _keyConversations = 'conversations';
  static const String _keyScreenRecordings = 'screen_recordings';

  /// Check if onboarding is complete
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  /// Set onboarding complete
  Future<void> setOnboardingComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, complete);
  }

  /// Save screen recording permission state
  Future<void> saveScreenRecordingPermission(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyScreenRecordingPermission, granted);
  }

  /// Get screen recording permission state
  Future<bool?> getScreenRecordingPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyScreenRecordingPermission);
  }

  /// Save microphone permission state
  Future<void> saveMicrophonePermission(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMicrophonePermission, granted);
  }

  /// Get microphone permission state
  Future<bool?> getMicrophonePermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMicrophonePermission);
  }

  /// Save user preferences
  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(preferences.toJson());
    await prefs.setString(_keyUserPreferences, json);
  }

  /// Load user preferences
  Future<UserPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyUserPreferences);

    if (json == null) {
      return const UserPreferences();
    }

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return UserPreferences.fromJson(map);
    } catch (e) {
      print('Error loading preferences: $e');
      return const UserPreferences();
    }
  }

  /// Save conversations list
  Future<void> saveConversations(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await prefs.setString(_keyConversations, json);
  }

  /// Load conversations list
  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyConversations);

    if (json == null) {
      return [];
    }

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((item) => Conversation.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading conversations: $e');
      return [];
    }
  }

  /// Add a conversation
  Future<void> addConversation(Conversation conversation) async {
    final conversations = await loadConversations();
    conversations.insert(0, conversation); // Add to beginning
    await saveConversations(conversations);
  }

  /// Delete a conversation
  Future<void> deleteConversation(String id) async {
    final conversations = await loadConversations();
    conversations.removeWhere((c) => c.id == id);
    await saveConversations(conversations);
  }

  /// Save screen recordings list
  Future<void> saveScreenRecordings(List<ScreenRecording> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(recordings.map((r) => r.toJson()).toList());
    await prefs.setString(_keyScreenRecordings, json);
  }

  /// Load screen recordings list
  Future<List<ScreenRecording>> loadScreenRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyScreenRecordings);

    if (json == null) {
      return [];
    }

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((item) => ScreenRecording.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading screen recordings: $e');
      return [];
    }
  }

  /// Add a screen recording
  Future<void> addScreenRecording(ScreenRecording recording) async {
    final recordings = await loadScreenRecordings();
    recordings.insert(0, recording); // Add to beginning
    await saveScreenRecordings(recordings);
  }

  /// Delete a screen recording
  Future<void> deleteScreenRecording(String id) async {
    final recordings = await loadScreenRecordings();
    recordings.removeWhere((r) => r.id == id);
    await saveScreenRecordings(recordings);
  }

  /// Clear all data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

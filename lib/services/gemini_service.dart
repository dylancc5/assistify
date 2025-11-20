import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Service for communicating with Google Gemini AI
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool _isInitialized = false;

  /// Initialize the Gemini service with API key from environment
  Future<bool> initialize() async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('Gemini API key not found in .env file');
        return false;
      }

      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
        systemInstruction: Content.text(
          'You are Assistify, a helpful and friendly voice assistant. '
          'Keep your responses concise and conversational, as they will be '
          'displayed on a mobile screen. Be helpful, clear, and friendly.',
        ),
      );

      // Start a new chat session
      _chatSession = _model!.startChat();
      _isInitialized = true;

      debugPrint('Gemini service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing Gemini service: $e');
      return false;
    }
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Send a message to Gemini and get a response
  Future<String?> sendMessage(String message) async {
    if (!_isInitialized || _chatSession == null) {
      debugPrint('Gemini service not initialized');
      return null;
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));

      final responseText = response.text;
      if (responseText != null && responseText.isNotEmpty) {
        return responseText;
      }

      return null;
    } catch (e) {
      debugPrint('Error sending message to Gemini: $e');
      return 'Error: Unable to get response from Gemini';
    }
  }

  /// Reset the chat session (start fresh conversation)
  void resetChat() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }

  /// Dispose of resources
  void dispose() {
    _chatSession = null;
    _model = null;
    _isInitialized = false;
  }
}

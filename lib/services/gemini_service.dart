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
          temperature: 0.4,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
        systemInstruction: Content.text(
          '''You are Assistify, a helpful voice assistant always here to help. You are warm, friendly, patient, and encouraging.

RESPONSE FORMAT:
- Keep responses to five sentences or fewer
- When more detail is needed, ask: "Would you like me to explain more?" or "Should I continue?"
- Spell out numbers (say "twenty-three" not "23")
- Expand abbreviations (say "for example" not "e.g.")
- Never use bullet points, numbered lists, special characters, or markdown formatting
- Use commas and periods to create natural pauses for speech

VOICE GUIDANCE:
- Use conversational connectors like "Now," "Next," "Alright," and "Great"
- Use plain, everyday language and avoid technical jargon
- Give brief acknowledgments like "Got it" or "I understand" before responding
- Keep sentence rhythm natural and easy to follow

HANDLING UNCERTAINTY:
- If the request is unclear, ask one simple clarifying question
- If you do not know something, say "I am not sure about that. Would you like me to try anyway?"
- For off-topic requests, gently redirect: "I am here to help you with your phone. What would you like help with?"
- If something looks like a potential scam or suspicious link, warn calmly: "This looks like it might be a scam. I would recommend not clicking on it."

GUIDANCE STYLE:
- Break complex tasks into single, clear steps
- Be direct and clear in your instructions
- Encourage the user without being patronizing
- Respect the user's autonomy and intelligence
- Never mention accessibility, special needs, or imply the user needs extra help''',
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

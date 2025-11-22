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

  /// Send a message to Gemini with screenshots for visual context
  /// Screenshots are JPEG images captured from the user's screen
  Future<String?> sendMessageWithScreenshots(
    String message,
    List<Uint8List> screenshots,
  ) async {
    if (!_isInitialized || _chatSession == null) {
      debugPrint('Gemini service not initialized');
      return null;
    }

    try {
      // Build content parts: text message + images
      final List<Part> parts = [];

      // Add screenshots as image parts
      if (screenshots.isNotEmpty) {
        for (final screenshot in screenshots) {
          parts.add(DataPart('image/jpeg', screenshot));
        }
        // Add context about the images
        parts.add(TextPart(
          'The above images are screenshots from the user\'s screen captured over time, shown in chronological order. '
          'Use them to understand what the user is looking at and provide relevant assistance.\n\n'
          'User message: $message',
        ));
      } else {
        parts.add(TextPart(message));
      }

      final response = await _chatSession!.sendMessage(Content.multi(parts));

      final responseText = response.text;
      if (responseText != null && responseText.isNotEmpty) {
        return responseText;
      }

      return null;
    } catch (e) {
      debugPrint('Error sending message with screenshots to Gemini: $e');
      return 'Error: Unable to get response from Gemini';
    }
  }

  /// Reset the chat session (start fresh conversation)
  void resetChat() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }

  /// Get the current chat history as a list of maps
  /// Used for passing context to native background processing
  List<Map<String, String>> getChatHistory() {
    if (_chatSession == null) return [];

    final history = _chatSession!.history.toList();
    return history.map((content) {
      final role = content.role == 'user' ? 'user' : 'assistant';
      final text = content.parts
          .whereType<TextPart>()
          .map((p) => p.text)
          .join(' ');
      return {'role': role, 'content': text};
    }).toList();
  }

  /// Inject a history entry into the chat session
  /// Used to sync background-processed messages back into the session
  void injectHistoryEntry(String userMessage, String assistantResponse) {
    if (_chatSession == null || _model == null) {
      debugPrint('Cannot inject history - chat session not initialized');
      return;
    }

    // Get current history and add new entries
    final currentHistory = _chatSession!.history.toList();
    currentHistory.add(Content.text(userMessage));
    currentHistory.add(Content.model([TextPart(assistantResponse)]));

    // Create new chat session with updated history
    _chatSession = _model!.startChat(history: currentHistory);

    debugPrint('Injected history entry - user: "${userMessage.substring(0, userMessage.length.clamp(0, 50))}..."');
  }

  /// Dispose of resources
  void dispose() {
    _chatSession = null;
    _model = null;
    _isInitialized = false;
  }
}

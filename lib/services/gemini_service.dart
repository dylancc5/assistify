import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Service for communicating with Google Gemini AI
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool _isInitialized = false;
  
  // Request tracking for duplicate prevention
  String? _activeRequestId;
  int _consecutiveFailures = 0;

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

    // Generate request ID at start
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeRequestId = requestId;

    int retries = 2; // Reduced from 3 to avoid long delays
    Duration delay = const Duration(seconds: 1);

    while (retries >= 0) {
      try {
        final response = await _chatSession!.sendMessage(Content.text(message))
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Gemini API request timed out');
              },
            );

        // Check if this request is still active before processing response
        if (_activeRequestId != requestId) {
          debugPrint('Request was superseded - ignoring response');
          return null;
        }

        _activeRequestId = null;
        final responseText = response.text;

        // Log token usage for cost estimation
        try {
          final usage = response.usageMetadata;
          if (usage != null) {
            final promptTokens = usage.promptTokenCount ?? 0;
            final candidatesTokens = usage.candidatesTokenCount ?? 0;
            final totalTokens = usage.totalTokenCount ?? 0;
            debugPrint('💰 [Token Usage] Prompt: $promptTokens | Response: $candidatesTokens | Total: $totalTokens');
          }
        } catch (e) {
          debugPrint('⚠️ [Token Usage] Could not read usage metadata: $e');
        }

        // Reset failure counter on success
        _consecutiveFailures = 0;

        if (responseText != null && responseText.isNotEmpty) {
          return responseText;
        }

        return null;
      } on TimeoutException {
        debugPrint('Gemini API timeout - ${retries > 0 ? "retrying" : "giving up"}...');
        if (retries > 0) {
          retries--;
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        } else {
          _activeRequestId = null;
          _consecutiveFailures++;
          return 'I apologize, but the request took too long. Please try again.';
        }
      } on SocketException catch (e) {
        debugPrint('Network unavailable: $e');
        _activeRequestId = null;
        _consecutiveFailures++;
        return 'I cannot connect to the internet right now. Please check your connection and try again.';
      } catch (e) {
        debugPrint('Error sending message to Gemini: $e');
        
        // Check if it's a retryable error
        final errorStr = e.toString().toLowerCase();
        final isRetryable = errorStr.contains('timeout') ||
            errorStr.contains('network') ||
            errorStr.contains('socket') ||
            errorStr.contains('connection');
        
        // Check for rate limit errors (429)
        final isRateLimit = errorStr.contains('rate limit') ||
            errorStr.contains('429') ||
            errorStr.contains('quota');
        
        if (isRateLimit) {
          _consecutiveFailures++;
          if (_consecutiveFailures >= 3) {
            _activeRequestId = null;
            return 'I am experiencing high demand. Please wait a moment and try again.';
          }
        }

        if (isRetryable && retries > 0) {
          retries--;
          await Future.delayed(delay);
          delay *= 2;
          continue;
        } else {
          _activeRequestId = null;
          if (retries == 0) {
            _consecutiveFailures++;
          }
          return 'I encountered an error. Please try again.';
        }
      }
    }

    _activeRequestId = null;
    return 'I encountered an error. Please try again.';
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

    // Generate request ID at start
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeRequestId = requestId;

    int retries = 2; // Reduced from 3 to avoid long delays
    Duration delay = const Duration(seconds: 1);

    while (retries >= 0) {
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

        final response = await _chatSession!.sendMessage(Content.multi(parts))
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Gemini API request timed out');
              },
            );

        // Check if this request is still active before processing response
        if (_activeRequestId != requestId) {
          debugPrint('Request was superseded - ignoring response');
          return null;
        }

        _activeRequestId = null;
        final responseText = response.text;

        // Log token usage for cost estimation
        try {
          final usage = response.usageMetadata;
          if (usage != null) {
            final promptTokens = usage.promptTokenCount ?? 0;
            final candidatesTokens = usage.candidatesTokenCount ?? 0;
            final totalTokens = usage.totalTokenCount ?? 0;
            final imageCount = screenshots.length;
            debugPrint('💰 [Token Usage] Prompt: $promptTokens | Response: $candidatesTokens | Total: $totalTokens | Images: $imageCount');
          }
        } catch (e) {
          debugPrint('⚠️ [Token Usage] Could not read usage metadata: $e');
        }

        // Reset failure counter on success
        _consecutiveFailures = 0;

        if (responseText != null && responseText.isNotEmpty) {
          return responseText;
        }

        return null;
      } on TimeoutException {
        debugPrint('Gemini API timeout with screenshots - ${retries > 0 ? "retrying" : "giving up"}...');
        if (retries > 0) {
          retries--;
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        } else {
          _activeRequestId = null;
          _consecutiveFailures++;
          return 'I apologize, but the request took too long. Please try again.';
        }
      } on SocketException catch (e) {
        debugPrint('Network unavailable: $e');
        _activeRequestId = null;
        _consecutiveFailures++;
        return 'I cannot connect to the internet right now. Please check your connection and try again.';
      } catch (e) {
        debugPrint('Error sending message with screenshots to Gemini: $e');
        
        // Check if it's a retryable error
        final errorStr = e.toString().toLowerCase();
        final isRetryable = errorStr.contains('timeout') ||
            errorStr.contains('network') ||
            errorStr.contains('socket') ||
            errorStr.contains('connection');
        
        // Check for rate limit errors (429)
        final isRateLimit = errorStr.contains('rate limit') ||
            errorStr.contains('429') ||
            errorStr.contains('quota');
        
        if (isRateLimit) {
          _consecutiveFailures++;
          if (_consecutiveFailures >= 3) {
            _activeRequestId = null;
            return 'I am experiencing high demand. Please wait a moment and try again.';
          }
        }

        if (isRetryable && retries > 0) {
          retries--;
          await Future.delayed(delay);
          delay *= 2;
          continue;
        } else {
          _activeRequestId = null;
          if (retries == 0) {
            _consecutiveFailures++;
          }
          return 'I encountered an error. Please try again.';
        }
      }
    }

    _activeRequestId = null;
    return 'I encountered an error. Please try again.';
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

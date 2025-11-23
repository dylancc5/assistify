import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for communicating with Baidu ERNIE Bot AI
class BaiduService {
  String? _apiKey;
  String? _secretKey;
  String? _accessToken;
  DateTime? _tokenExpiry;
  bool _isInitialized = false;
  
  // Request tracking for duplicate prevention
  String? _activeRequestId;
  int _consecutiveFailures = 0;
  
  // Chat history for conversation context
  List<Map<String, String>> _chatHistory = [];

  /// Initialize the Baidu service with API credentials from environment
  Future<bool> initialize() async {
    try {
      _apiKey = dotenv.env['BAIDU_API_KEY'];
      _secretKey = dotenv.env['BAIDU_SECRET_KEY'];

      if (_apiKey == null || _apiKey!.isEmpty || _secretKey == null || _secretKey!.isEmpty) {
        debugPrint('Baidu API credentials not found in .env file');
        return false;
      }

      // Get access token
      await _refreshAccessToken();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing Baidu service: $e');
      return false;
    }
  }

  /// Get access token from Baidu OAuth API
  Future<void> _refreshAccessToken() async {
    try {
      final url = Uri.parse('https://aip.baidubce.com/oauth/2.0/token');
      final response = await http.post(
        url,
        body: {
          'grant_type': 'client_credentials',
          'client_id': _apiKey!,
          'client_secret': _secretKey!,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        // Baidu tokens typically expire in 30 days, but we'll refresh after 25 days to be safe
        _tokenExpiry = DateTime.now().add(const Duration(days: 25));
        debugPrint('Baidu access token obtained successfully');
      } else {
        throw Exception('Failed to get access token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error refreshing Baidu access token: $e');
      rethrow;
    }
  }

  /// Ensure access token is valid
  Future<void> _ensureValidToken() async {
    if (_accessToken == null || 
        _tokenExpiry == null || 
        DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(hours: 1)))) {
      await _refreshAccessToken();
    }
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized && _accessToken != null;

  /// Send a message to Baidu ERNIE Bot and get a response
  Future<String?> sendMessage(String message) async {
    if (!isInitialized) {
      debugPrint('Baidu service not initialized');
      return null;
    }

    // Generate request ID at start
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeRequestId = requestId;

    int retries = 2;
    Duration delay = const Duration(seconds: 1);

    while (retries >= 0) {
      try {
        await _ensureValidToken();

        final url = Uri.parse(
          'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions?access_token=$_accessToken'
        );

        // Build messages array with history and current message
        final messages = <Map<String, String>>[];
        
        // Add chat history (last 10 messages to avoid token limits)
        final historyToUse = _chatHistory.length > 10
            ? _chatHistory.sublist(_chatHistory.length - 10)
            : _chatHistory;
        
        for (final historyItem in historyToUse) {
          messages.add({
            'role': historyItem['role'] ?? 'user',
            'content': historyItem['content'] ?? '',
          });
        }
        
        // Add current message with system instruction prepended if this is the first message
        final systemInstruction = _chatHistory.isEmpty
            ? '''You are Assistify, a helpful voice assistant always here to help. You are warm, friendly, patient, and encouraging.

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
- Never mention accessibility, special needs, or imply the user needs extra help

User message: $message'''
            : message;
        
        messages.add({
          'role': 'user',
          'content': systemInstruction,
        });

        final body = {
          'messages': messages,
          'temperature': 0.4,
          'max_output_tokens': 1024,
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Baidu API request timed out');
          },
        );

        // Check if this request is still active before processing response
        if (_activeRequestId != requestId) {
          debugPrint('Request was superseded - ignoring response');
          return null;
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Handle Baidu API response format
          String? responseText;
          if (data['result'] != null) {
            responseText = data['result'] as String;
          } else if (data['error_code'] != null) {
            final errorCode = data['error_code'];
            final errorMsg = data['error_msg'] ?? 'Unknown error';
            
            // Handle token expiry
            if (errorCode == 110 || errorCode == 111) {
              await _refreshAccessToken();
              if (retries > 0) {
                retries--;
                await Future.delayed(delay);
                delay *= 2;
                continue;
              }
            }
            
            debugPrint('Baidu API error: $errorCode - $errorMsg');
            _activeRequestId = null;
            return 'I encountered an error. Please try again.';
          }

          _activeRequestId = null;

          // Log token usage if available
          try {
            if (data['usage'] != null) {
              final usage = data['usage'];
              final promptTokens = usage['prompt_tokens'] ?? 0;
              final completionTokens = usage['completion_tokens'] ?? 0;
              final totalTokens = usage['total_tokens'] ?? 0;
              debugPrint('💰 [Token Usage] Prompt: $promptTokens | Response: $completionTokens | Total: $totalTokens');
            }
          } catch (e) {
            debugPrint('⚠️ [Token Usage] Could not read usage metadata: $e');
          }

          // Reset failure counter on success
          _consecutiveFailures = 0;

          // Update chat history
          if (responseText != null && responseText.isNotEmpty) {
            _chatHistory.add({'role': 'user', 'content': message});
            _chatHistory.add({'role': 'assistant', 'content': responseText});
            // Keep only last 20 messages
            if (_chatHistory.length > 20) {
              _chatHistory = _chatHistory.sublist(_chatHistory.length - 20);
            }
            return responseText;
          }

          return null;
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } on TimeoutException {
        debugPrint('Baidu API timeout - ${retries > 0 ? "retrying" : "giving up"}...');
        if (retries > 0) {
          retries--;
          await Future.delayed(delay);
          delay *= 2;
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
        debugPrint('Error sending message to Baidu: $e');
        
        // Check if it's a retryable error
        final errorStr = e.toString().toLowerCase();
        final isRetryable = errorStr.contains('timeout') ||
            errorStr.contains('network') ||
            errorStr.contains('socket') ||
            errorStr.contains('connection');
        
        // Check for rate limit errors
        final isRateLimit = errorStr.contains('rate limit') ||
            errorStr.contains('429') ||
            errorStr.contains('quota') ||
            errorStr.contains('qps');
        
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

  /// Send a message to Baidu ERNIE Bot with screenshots for visual context
  /// Screenshots are JPEG images captured from the user's screen
  Future<String?> sendMessageWithScreenshots(
    String message,
    List<Uint8List> screenshots,
  ) async {
    if (!isInitialized) {
      debugPrint('Baidu service not initialized');
      return null;
    }

    // Generate request ID at start
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeRequestId = requestId;

    int retries = 2;
    Duration delay = const Duration(seconds: 1);

    while (retries >= 0) {
      try {
        await _ensureValidToken();

        // Baidu ERNIE Bot supports vision models - use ERNIE-VilG or similar vision endpoint
        // For now, we'll encode images as base64 and include them in the message
        final url = Uri.parse(
          'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions?access_token=$_accessToken'
        );

        // Build messages array with images
        final messages = <Map<String, dynamic>>[];
        
        // Prepare image content
        final contentParts = <Map<String, dynamic>>[];
        
        // Add images as base64
        for (final screenshot in screenshots) {
          final base64Image = base64Encode(screenshot);
          contentParts.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$base64Image'
            }
          });
        }
        
        // Add text content
        final imageContext = screenshots.isNotEmpty
            ? 'The above images are screenshots from the user\'s screen captured over time, shown in chronological order. Use them to understand what the user is looking at and provide relevant assistance.\n\n'
            : '';
        
        contentParts.add({
          'type': 'text',
          'text': '$imageContext User message: $message'
        });
        
        messages.add({
          'role': 'user',
          'content': contentParts,
        });

        final body = {
          'messages': messages,
          'temperature': 0.4,
          'max_output_tokens': 1024,
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Baidu API request timed out');
          },
        );

        // Check if this request is still active before processing response
        if (_activeRequestId != requestId) {
          debugPrint('Request was superseded - ignoring response');
          return null;
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Handle Baidu API response format
          String? responseText;
          if (data['result'] != null) {
            responseText = data['result'] as String;
          } else if (data['error_code'] != null) {
            final errorCode = data['error_code'];
            final errorMsg = data['error_msg'] ?? 'Unknown error';
            
            // Handle token expiry
            if (errorCode == 110 || errorCode == 111) {
              await _refreshAccessToken();
              if (retries > 0) {
                retries--;
                await Future.delayed(delay);
                delay *= 2;
                continue;
              }
            }
            
            debugPrint('Baidu API error: $errorCode - $errorMsg');
            _activeRequestId = null;
            return 'I encountered an error. Please try again.';
          }

          _activeRequestId = null;

          // Log token usage if available
          try {
            if (data['usage'] != null) {
              final usage = data['usage'];
              final promptTokens = usage['prompt_tokens'] ?? 0;
              final completionTokens = usage['completion_tokens'] ?? 0;
              final totalTokens = usage['total_tokens'] ?? 0;
              final imageCount = screenshots.length;
              debugPrint('💰 [Token Usage] Prompt: $promptTokens | Response: $completionTokens | Total: $totalTokens | Images: $imageCount');
            }
          } catch (e) {
            debugPrint('⚠️ [Token Usage] Could not read usage metadata: $e');
          }

          // Reset failure counter on success
          _consecutiveFailures = 0;

          // Update chat history
          if (responseText != null && responseText.isNotEmpty) {
            _chatHistory.add({'role': 'user', 'content': message});
            _chatHistory.add({'role': 'assistant', 'content': responseText});
            // Keep only last 20 messages
            if (_chatHistory.length > 20) {
              _chatHistory = _chatHistory.sublist(_chatHistory.length - 20);
            }
            return responseText;
          }

          return null;
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } on TimeoutException {
        debugPrint('Baidu API timeout with screenshots - ${retries > 0 ? "retrying" : "giving up"}...');
        if (retries > 0) {
          retries--;
          await Future.delayed(delay);
          delay *= 2;
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
        debugPrint('Error sending message with screenshots to Baidu: $e');
        
        // Check if it's a retryable error
        final errorStr = e.toString().toLowerCase();
        final isRetryable = errorStr.contains('timeout') ||
            errorStr.contains('network') ||
            errorStr.contains('socket') ||
            errorStr.contains('connection');
        
        // Check for rate limit errors
        final isRateLimit = errorStr.contains('rate limit') ||
            errorStr.contains('429') ||
            errorStr.contains('quota') ||
            errorStr.contains('qps');
        
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
    _chatHistory.clear();
  }

  /// Get the current chat history as a list of maps
  /// Used for passing context to native background processing
  List<Map<String, String>> getChatHistory() {
    return List.from(_chatHistory);
  }

  /// Inject a history entry into the chat session
  /// Used to sync background-processed messages back into the session
  void injectHistoryEntry(String userMessage, String assistantResponse) {
    _chatHistory.add({'role': 'user', 'content': userMessage});
    _chatHistory.add({'role': 'assistant', 'content': assistantResponse});
    // Keep only last 20 messages
    if (_chatHistory.length > 20) {
      _chatHistory = _chatHistory.sublist(_chatHistory.length - 20);
    }
    debugPrint('Injected history entry - user: "${userMessage.substring(0, userMessage.length.clamp(0, 50))}..."');
  }

  /// Dispose of resources
  void dispose() {
    _chatHistory.clear();
    _accessToken = null;
    _tokenExpiry = null;
    _isInitialized = false;
  }
}


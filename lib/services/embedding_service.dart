import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for generating embeddings and storing/retrieving from Supabase
class EmbeddingService {
  GenerativeModel? _embeddingModel;
  SupabaseClient? _supabase;
  bool _isInitialized = false;

  /// Initialize the embedding service
  Future<void> initialize() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('EmbeddingService: No Gemini API key found');
      return;
    }

    // Check if Supabase is initialized
    try {
      _supabase = Supabase.instance.client;
    } catch (e) {
      debugPrint('EmbeddingService: Supabase not initialized - $e');
      return;
    }

    _embeddingModel = GenerativeModel(
      model: 'text-embedding-004',
      apiKey: apiKey,
    );

    _isInitialized = true;
    debugPrint('EmbeddingService: Initialized successfully');
  }

  /// Check if service is ready
  bool get isReady => _isInitialized && _embeddingModel != null && _supabase != null;

  /// Generate embedding for text
  Future<List<double>?> generateEmbedding(String text) async {
    if (!isReady) {
      debugPrint('EmbeddingService: Not initialized');
      return null;
    }

    try {
      final content = Content.text(text);
      final result = await _embeddingModel!.embedContent(content);
      return result.embedding.values;
    } catch (e) {
      debugPrint('EmbeddingService: Error generating embedding - $e');
      return null;
    }
  }

  /// Store a message embedding in Supabase
  Future<bool> storeMessageEmbedding({
    required String conversationId,
    required String messageText,
  }) async {
    if (!isReady) return false;

    try {
      final embedding = await generateEmbedding(messageText);
      if (embedding == null) return false;

      await _supabase!.from('message_embeddings').insert({
        'conversation_id': conversationId,
        'chunk_text': messageText,
        'embedding': embedding,
      });

      debugPrint('EmbeddingService: Stored embedding for conversation $conversationId');
      return true;
    } catch (e) {
      debugPrint('EmbeddingService: Error storing embedding - $e');
      return false;
    }
  }

  /// Retrieve similar messages based on query
  /// Returns list of relevant message texts
  Future<List<String>> retrieveSimilarMessages({
    required String query,
    required List<String> conversationIds,
    int limit = 5,
  }) async {
    if (!isReady || conversationIds.isEmpty) return [];

    try {
      final queryEmbedding = await generateEmbedding(query);
      if (queryEmbedding == null) return [];

      // Use Supabase RPC for vector similarity search
      final results = await _supabase!.rpc(
        'match_message_embeddings',
        params: {
          'query_embedding': queryEmbedding,
          'match_count': limit,
          'filter_conversation_ids': conversationIds,
        },
      );

      if (results == null) return [];

      return (results as List)
          .map((row) => row['chunk_text'] as String)
          .toList();
    } catch (e) {
      debugPrint('EmbeddingService: Error retrieving similar messages - $e');
      return [];
    }
  }

  /// Delete all embeddings for a conversation
  Future<bool> deleteConversationEmbeddings(String conversationId) async {
    if (!isReady) return false;

    try {
      await _supabase!
          .from('message_embeddings')
          .delete()
          .eq('conversation_id', conversationId);

      debugPrint('EmbeddingService: Deleted embeddings for conversation $conversationId');
      return true;
    } catch (e) {
      debugPrint('EmbeddingService: Error deleting embeddings - $e');
      return false;
    }
  }

  /// Delete all embeddings (for clear all conversations)
  Future<bool> deleteAllEmbeddings(List<String> conversationIds) async {
    if (!isReady || conversationIds.isEmpty) return false;

    try {
      await _supabase!
          .from('message_embeddings')
          .delete()
          .inFilter('conversation_id', conversationIds);

      debugPrint('EmbeddingService: Deleted all embeddings');
      return true;
    } catch (e) {
      debugPrint('EmbeddingService: Error deleting all embeddings - $e');
      return false;
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Benchmark evaluation script for Assistify AI quality
///
/// Usage: dart run test/run_benchmark.dart [output_file]
/// Example: dart run test/run_benchmark.dart benchmark_results_baseline.json

void main(List<String> args) async {
  print('🚀 Assistify Benchmark Runner\n');

  // Parse arguments
  final outputFile = args.isNotEmpty
      ? args[0]
      : 'test/benchmark_results_${DateTime.now().millisecondsSinceEpoch}.json';

  // Load environment variables
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['GEMINI_API_KEY'];

  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: GEMINI_API_KEY not found in .env file');
    exit(1);
  }

  // Initialize Gemini
  final model = GenerativeModel(
    model: 'gemini-2.0-flash-exp',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.4,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 1024,
    ),
    systemInstruction: Content.text(
      '''You are Assistify, a helpful voice assistant for elderly users. You are warm, friendly, patient, and encouraging.

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

SAFETY AWARENESS:
- If something looks like a potential scam or suspicious link, warn calmly: "This looks like it might be a scam. I would recommend not clicking on it."
- Never encourage clicking suspicious links or sharing personal information
- For requests to verify identity or send money, suggest calling the person directly''',
    ),
  );

  // Load test cases
  print('📂 Loading test cases from benchmark_dataset.json...');
  final datasetFile = File('test/benchmark_dataset.json');
  if (!await datasetFile.exists()) {
    print('❌ Error: benchmark_dataset.json not found');
    exit(1);
  }

  final datasetJson = jsonDecode(await datasetFile.readAsString());
  final testCases = datasetJson['test_cases'] as List;
  print('✅ Loaded ${testCases.length} test cases\n');

  // Run benchmark
  final results = <Map<String, dynamic>>[];
  var testNum = 0;

  for (final testCase in testCases) {
    testNum++;
    final id = testCase['id'];
    final category = testCase['category'];
    final query = testCase['query'];
    final screenContext = testCase['screen_context'];
    final criteria = testCase['evaluation_criteria'];

    print('[$testNum/${testCases.length}] Running test: $id ($category)');
    print('  Query: "$query"');

    try {
      // Generate response
      final prompt = '''Screen Context: $screenContext

User Query: "$query"

Provide a helpful response to the user.''';

      final chat = model.startChat();
      final response = await chat.sendMessage(Content.text(prompt));
      final responseText = response.text ?? '';

      print(
        '  Response: "${responseText.substring(0, responseText.length > 80 ? 80 : responseText.length)}..."',
      );

      // Evaluate response using LLM-as-Judge
      final evaluation = await evaluateResponse(
        model: model,
        query: query,
        screenContext: screenContext,
        response: responseText,
        criteria: criteria,
      );

      results.add({
        'test_id': id,
        'category': category,
        'query': query,
        'screen_context': screenContext,
        'response': responseText,
        'evaluation': evaluation,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print(
        '  Evaluation: ${evaluation['overall_score']}/5 - ${evaluation['pass'] ? "✅ PASS" : "❌ FAIL"}',
      );
      print('');

      // Small delay to avoid rate limiting
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      print('  ❌ Error: $e\n');
      results.add({
        'test_id': id,
        'category': category,
        'query': query,
        'screen_context': screenContext,
        'response': null,
        'evaluation': {
          'error': e.toString(),
          'overall_score': 0,
          'pass': false,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Calculate aggregate metrics
  final metrics = calculateMetrics(results);

  // Save results
  final output = {
    'metadata': {
      'timestamp': DateTime.now().toIso8601String(),
      'total_tests': testCases.length,
      'model': 'gemini-2.0-flash-exp',
    },
    'metrics': metrics,
    'results': results,
  };

  final outputFileObj = File(outputFile);
  await outputFileObj.writeAsString(
    JsonEncoder.withIndent('  ').convert(output),
  );

  print('📊 Benchmark Complete!\n');
  print('Results Summary:');
  print('  Total Tests: ${metrics['total_tests']}');
  print('  Pass Rate: ${metrics['pass_rate'].toStringAsFixed(1)}%');
  print('  Avg Score: ${metrics['avg_score'].toStringAsFixed(2)}/5');
  print('  Avg Relevance: ${metrics['avg_relevance'].toStringAsFixed(2)}/5');
  print(
    '  Avg Completeness: ${metrics['avg_completeness'].toStringAsFixed(2)}/5',
  );
  print(
    '  Screen Context Usage: ${metrics['screen_context_usage'].toStringAsFixed(1)}%',
  );
  print(
    '  Format Compliance: ${metrics['format_compliance'].toStringAsFixed(1)}%',
  );
  print('\n💾 Results saved to: $outputFile');
}

/// Evaluate a response using LLM-as-Judge approach
Future<Map<String, dynamic>> evaluateResponse({
  required GenerativeModel model,
  required String query,
  required String screenContext,
  required String response,
  required Map<String, dynamic> criteria,
}) async {
  final mustInclude = (criteria['must_include'] as List).cast<String>();
  final mustNotInclude = (criteria['must_not_include'] as List).cast<String>();
  final shouldReferenceScreen = criteria['should_reference_screen'] as bool;
  final maxSentences = criteria['max_sentences'] as int;

  // Create evaluation prompt
  final evalPrompt = '''You are evaluating an AI assistant's response for quality. Analyze the following:

USER QUERY: "$query"

SCREEN CONTEXT: "$screenContext"

AI RESPONSE: "$response"

EVALUATION CRITERIA:
1. Must include these concepts: ${mustInclude.join(', ')}
2. Must NOT include these: ${mustNotInclude.join(', ')}
3. Should reference screen context: $shouldReferenceScreen
4. Maximum sentences: $maxSentences

Evaluate the response on these dimensions (1-5 scale):
- RELEVANCE: Does it address the user's question? (1=off-topic, 5=perfectly relevant)
- COMPLETENESS: Does it include all required concepts? (1=missing all, 5=includes all)
- FORMAT: Does it follow format rules (no markdown, spelling out numbers, conversational)? (1=many violations, 5=perfect)
- SCREEN_USAGE: Does it appropriately reference the screen context when needed? (1=ignores context, 5=uses context well)
- CLARITY: Is it clear and understandable for elderly users? (1=confusing, 5=very clear)

Respond ONLY with valid JSON in this exact format:
{
  "relevance": <1-5>,
  "completeness": <1-5>,
  "format": <1-5>,
  "screen_usage": <1-5>,
  "clarity": <1-5>,
  "reasoning": "<brief explanation>"
}''';

  try {
    final evalChat = model.startChat();
    final evalResponse = await evalChat.sendMessage(Content.text(evalPrompt));
    final evalText = evalResponse.text ?? '{}';

    // Extract JSON from response (handle markdown code blocks)
    var jsonText = evalText.trim();
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.substring(7);
    }
    if (jsonText.startsWith('```')) {
      jsonText = jsonText.substring(3);
    }
    if (jsonText.endsWith('```')) {
      jsonText = jsonText.substring(0, jsonText.length - 3);
    }
    jsonText = jsonText.trim();

    final evalJson = jsonDecode(jsonText);

    // Calculate overall score
    final relevance = (evalJson['relevance'] ?? 0).toDouble();
    final completeness = (evalJson['completeness'] ?? 0).toDouble();
    final format = (evalJson['format'] ?? 0).toDouble();
    final screenUsage = (evalJson['screen_usage'] ?? 0).toDouble();
    final clarity = (evalJson['clarity'] ?? 0).toDouble();

    final overallScore =
        (relevance + completeness + format + screenUsage + clarity) / 5;
    final pass = overallScore >= 3.5; // Pass threshold

    return {
      'relevance': relevance,
      'completeness': completeness,
      'format': format,
      'screen_usage': screenUsage,
      'clarity': clarity,
      'overall_score': overallScore,
      'pass': pass,
      'reasoning': evalJson['reasoning'] ?? '',
    };
  } catch (e) {
    print('  ⚠️  Evaluation error: $e');
    return {
      'relevance': 0.0,
      'completeness': 0.0,
      'format': 0.0,
      'screen_usage': 0.0,
      'clarity': 0.0,
      'overall_score': 0.0,
      'pass': false,
      'reasoning': 'Evaluation failed: $e',
    };
  }
}

/// Calculate aggregate metrics from results
Map<String, dynamic> calculateMetrics(List<Map<String, dynamic>> results) {
  if (results.isEmpty) {
    return {
      'total_tests': 0,
      'pass_rate': 0.0,
      'avg_score': 0.0,
      'avg_relevance': 0.0,
      'avg_completeness': 0.0,
      'avg_format': 0.0,
      'avg_screen_usage': 0.0,
      'avg_clarity': 0.0,
      'screen_context_usage': 0.0,
      'format_compliance': 0.0,
    };
  }

  var totalScore = 0.0;
  var totalRelevance = 0.0;
  var totalCompleteness = 0.0;
  var totalFormat = 0.0;
  var totalScreenUsage = 0.0;
  var totalClarity = 0.0;
  var passCount = 0;

  for (final result in results) {
    final eval = result['evaluation'] as Map<String, dynamic>;
    if (eval['overall_score'] != null) {
      totalScore += (eval['overall_score'] as num).toDouble();
      totalRelevance += (eval['relevance'] as num).toDouble();
      totalCompleteness += (eval['completeness'] as num).toDouble();
      totalFormat += (eval['format'] as num).toDouble();
      totalScreenUsage += (eval['screen_usage'] as num).toDouble();
      totalClarity += (eval['clarity'] as num).toDouble();
      if (eval['pass'] == true) passCount++;
    }
  }

  final count = results.length;

  return {
    'total_tests': count,
    'pass_rate': (passCount / count) * 100,
    'avg_score': totalScore / count,
    'avg_relevance': totalRelevance / count,
    'avg_completeness': totalCompleteness / count,
    'avg_format': totalFormat / count,
    'avg_screen_usage': totalScreenUsage / count,
    'avg_clarity': totalClarity / count,
    'screen_context_usage': (totalScreenUsage / count / 5) * 100,
    'format_compliance': (totalFormat / count / 5) * 100,
  };
}

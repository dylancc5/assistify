import 'dart:convert';
import 'dart:io';

/// Compare two benchmark results and generate improvement report
///
/// Usage: dart run test/compare_results.dart <baseline_file> <improved_file> [output_file]
/// Example: dart run test/compare_results.dart test/benchmark_results_baseline.json test/benchmark_results_improved.json

void main(List<String> args) async {
  print('📊 Assistify Benchmark Comparison Tool\n');

  if (args.length < 2) {
    print('❌ Error: Please provide baseline and improved result files');
    print(
      'Usage: dart run test/compare_results.dart <baseline_file> <improved_file> [output_file]',
    );
    exit(1);
  }

  final baselineFile = args[0];
  final improvedFile = args[1];
  final outputFile = args.length > 2 ? args[2] : 'BENCHMARK_RESULTS.md';

  // Load result files
  print('📂 Loading baseline results from $baselineFile...');
  final baselineJson = jsonDecode(await File(baselineFile).readAsString());
  final baselineMetrics = baselineJson['metrics'] as Map<String, dynamic>;

  print('📂 Loading improved results from $improvedFile...');
  final improvedJson = jsonDecode(await File(improvedFile).readAsString());
  final improvedMetrics = improvedJson['metrics'] as Map<String, dynamic>;

  // Calculate improvements
  final comparison = compareMetrics(baselineMetrics, improvedMetrics);

  // Generate detailed comparison by category
  final categoryComparison = compareByCat(
    baselineJson['results'] as List,
    improvedJson['results'] as List,
  );

  // Generate markdown report
  final report = generateMarkdownReport(
    baselineMetrics: baselineMetrics,
    improvedMetrics: improvedMetrics,
    comparison: comparison,
    categoryComparison: categoryComparison,
    baselineTimestamp: baselineJson['metadata']['timestamp'],
    improvedTimestamp: improvedJson['metadata']['timestamp'],
  );

  // Save report
  await File(outputFile).writeAsString(report);

  print('\n✅ Comparison complete!');
  print('📄 Report saved to: $outputFile\n');

  // Print summary
  print('Summary:');
  print(
    '  Pass Rate: ${comparison['pass_rate']['baseline'].toStringAsFixed(1)}% → ${comparison['pass_rate']['improved'].toStringAsFixed(1)}% (${comparison['pass_rate']['change'] >= 0 ? '+' : ''}${comparison['pass_rate']['change'].toStringAsFixed(1)}%)',
  );
  print(
    '  Avg Score: ${comparison['avg_score']['baseline'].toStringAsFixed(2)} → ${comparison['avg_score']['improved'].toStringAsFixed(2)} (${comparison['avg_score']['change'] >= 0 ? '+' : ''}${comparison['avg_score']['change'].toStringAsFixed(2)})',
  );
  print(
    '  Relevance: ${comparison['avg_relevance']['baseline'].toStringAsFixed(2)} → ${comparison['avg_relevance']['improved'].toStringAsFixed(2)} (${comparison['avg_relevance']['change'] >= 0 ? '+' : ''}${comparison['avg_relevance']['change'].toStringAsFixed(2)})',
  );
}

/// Compare metrics between baseline and improved
Map<String, Map<String, double>> compareMetrics(
  Map<String, dynamic> baseline,
  Map<String, dynamic> improved,
) {
  final metrics = [
    'pass_rate',
    'avg_score',
    'avg_relevance',
    'avg_completeness',
    'avg_format',
    'avg_screen_usage',
    'avg_clarity',
    'screen_context_usage',
    'format_compliance',
  ];

  final comparison = <String, Map<String, double>>{};

  for (final metric in metrics) {
    final baselineValue = (baseline[metric] as num).toDouble();
    final improvedValue = (improved[metric] as num).toDouble();
    final change = improvedValue - baselineValue;
    final percentChange = baselineValue != 0
        ? (change / baselineValue) * 100
        : 0;

    comparison[metric] = {
      'baseline': baselineValue,
      'improved': improvedValue,
      'change': change,
      'percent_change': percentChange,
    };
  }

  return comparison;
}

/// Compare results by category
Map<String, Map<String, dynamic>> compareByCat(
  List baselineResults,
  List improvedResults,
) {
  final categories = <String, Map<String, dynamic>>{};

  // Group by category
  for (final result in baselineResults) {
    final category = result['category'];
    if (!categories.containsKey(category)) {
      categories[category] = {
        'baseline_scores': <double>[],
        'improved_scores': <double>[],
      };
    }
    final score = (result['evaluation']['overall_score'] as num).toDouble();
    categories[category]!['baseline_scores'].add(score);
  }

  for (final result in improvedResults) {
    final category = result['category'];
    if (!categories.containsKey(category)) continue;
    final score = (result['evaluation']['overall_score'] as num).toDouble();
    categories[category]!['improved_scores'].add(score);
  }

  // Calculate averages
  for (final category in categories.keys) {
    final baselineScores =
        categories[category]!['baseline_scores'] as List<double>;
    final improvedScores =
        categories[category]!['improved_scores'] as List<double>;

    final baselineAvg = baselineScores.isEmpty
        ? 0.0
        : baselineScores.reduce((a, b) => a + b) / baselineScores.length;
    final improvedAvg = improvedScores.isEmpty
        ? 0.0
        : improvedScores.reduce((a, b) => a + b) / improvedScores.length;

    categories[category]!['baseline_avg'] = baselineAvg;
    categories[category]!['improved_avg'] = improvedAvg;
    categories[category]!['change'] = improvedAvg - baselineAvg;
  }

  return categories;
}

/// Generate markdown report
String generateMarkdownReport({
  required Map<String, dynamic> baselineMetrics,
  required Map<String, dynamic> improvedMetrics,
  required Map<String, Map<String, double>> comparison,
  required Map<String, Map<String, dynamic>> categoryComparison,
  required String baselineTimestamp,
  required String improvedTimestamp,
}) {
  final buffer = StringBuffer();

  buffer.writeln('# Assistify Benchmark Results');
  buffer.writeln('');
  buffer.writeln('## Overview');
  buffer.writeln('');
  buffer.writeln('**Baseline Run:** $baselineTimestamp');
  buffer.writeln('**Improved Run:** $improvedTimestamp');
  buffer.writeln('');

  // Overall metrics table
  buffer.writeln('## Overall Performance');
  buffer.writeln('');
  buffer.writeln('| Metric | Baseline | Improved | Change | % Change |');
  buffer.writeln('|--------|----------|----------|--------|----------|');

  final metricLabels = {
    'pass_rate': 'Pass Rate (%)',
    'avg_score': 'Average Score',
    'avg_relevance': 'Relevance',
    'avg_completeness': 'Completeness',
    'avg_format': 'Format Compliance',
    'avg_screen_usage': 'Screen Context Usage',
    'avg_clarity': 'Clarity',
  };

  for (final entry in metricLabels.entries) {
    final metric = entry.key;
    final label = entry.value;
    final data = comparison[metric]!;

    final baseline = data['baseline']!;
    final improved = data['improved']!;
    final change = data['change']!;
    final percentChange = data['percent_change']!;

    final changeSign = change >= 0 ? '+' : '';
    final emoji = change > 0 ? '📈' : (change < 0 ? '📉' : '➡️');

    buffer.writeln(
      '| $label | ${baseline.toStringAsFixed(2)} | ${improved.toStringAsFixed(2)} | $changeSign${change.toStringAsFixed(2)} $emoji | $changeSign${percentChange.toStringAsFixed(1)}% |',
    );
  }

  buffer.writeln('');

  // Key improvements section
  buffer.writeln('## Key Improvements');
  buffer.writeln('');

  final improvements = <String>[];
  comparison.forEach((metric, data) {
    if (data['change']! > 0) {
      final label = metricLabels[metric] ?? metric;
      final change = data['percent_change']!;
      improvements.add('- **$label**: +${change.toStringAsFixed(1)}%');
    }
  });

  if (improvements.isEmpty) {
    buffer.writeln(
      '_No improvements detected. Consider refining prompts or system instructions._',
    );
  } else {
    buffer.writeAll(improvements, '\n');
  }

  buffer.writeln('');

  // Performance by category
  buffer.writeln('## Performance by Category');
  buffer.writeln('');
  buffer.writeln('| Category | Baseline Avg | Improved Avg | Change |');
  buffer.writeln('|----------|--------------|--------------|--------|');

  categoryComparison.forEach((category, data) {
    final baselineAvg = data['baseline_avg'] as double;
    final improvedAvg = data['improved_avg'] as double;
    final change = data['change'] as double;

    final changeSign = change >= 0 ? '+' : '';
    final emoji = change > 0 ? '✅' : (change < 0 ? '⚠️' : '➡️');

    buffer.writeln(
      '| $category | ${baselineAvg.toStringAsFixed(2)} | ${improvedAvg.toStringAsFixed(2)} | $changeSign${change.toStringAsFixed(2)} $emoji |',
    );
  });

  buffer.writeln('');

  // Recommendations
  buffer.writeln('## Recommendations');
  buffer.writeln('');

  if (comparison['pass_rate']!['improved']! < 80) {
    buffer.writeln(
      '- **Pass rate below 80%**: Review failing test cases and adjust system instructions or prompts.',
    );
  }

  if (comparison['avg_relevance']!['improved']! < 4.0) {
    buffer.writeln(
      '- **Low relevance scores**: Ensure AI is addressing user queries directly. Consider refining context understanding.',
    );
  }

  if (comparison['avg_format']!['improved']! < 4.0) {
    buffer.writeln(
      '- **Format compliance issues**: AI may be using markdown or bullet points. Strengthen system instruction formatting rules.',
    );
  }

  if (comparison['avg_screen_usage']!['improved']! < 4.0) {
    buffer.writeln(
      '- **Screen context underutilized**: AI may not be referencing visual context effectively. Add examples to system prompt.',
    );
  }

  // Find worst performing category
  var worstCategory = '';
  var worstScore = 5.0;
  categoryComparison.forEach((category, data) {
    final improvedAvg = data['improved_avg'] as double;
    if (improvedAvg < worstScore) {
      worstScore = improvedAvg;
      worstCategory = category;
    }
  });

  if (worstScore < 3.5) {
    buffer.writeln(
      '- **$worstCategory category struggling**: Average score of ${worstScore.toStringAsFixed(2)}. Review test cases in this category.',
    );
  }

  buffer.writeln('');
  buffer.writeln('---');
  buffer.writeln('');
  buffer.writeln('_Generated by Assistify Benchmark Comparison Tool_');

  return buffer.toString();
}

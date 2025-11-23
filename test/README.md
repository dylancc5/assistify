# Assistify Benchmark Suite

Automated benchmarking system for evaluating AI response quality and screen understanding in Assistify.

## Quick Start (Hackathon Demo)

### 1. Run Baseline Benchmark

```bash
# Make sure you have your .env file with GEMINI_API_KEY set
dart run test/run_benchmark.dart test/benchmark_results_baseline.json
```

This will:
- Load 15 test cases from `benchmark_dataset.json`
- Run each through your Gemini AI system
- Evaluate responses using LLM-as-Judge
- Save results to `benchmark_results_baseline.json`
- Takes ~5-8 minutes (with API delays)

### 2. Make Your Improvements

Make changes to your system, such as:
- Refining system instructions in `lib/services/gemini_service.dart`
- Adjusting prompt engineering
- Improving screen context handling
- Updating response formatting logic

### 3. Run Improved Benchmark

```bash
dart run test/run_benchmark.dart test/benchmark_results_improved.json
```

### 4. Generate Comparison Report

```bash
dart run test/compare_results.dart test/benchmark_results_baseline.json test/benchmark_results_improved.json
```

This creates `BENCHMARK_RESULTS.md` showing:
- Overall performance metrics (pass rate, average scores)
- Before/after comparison with % improvement
- Category-by-category breakdown
- Specific recommendations

### 5. Present Results

Use `BENCHMARK_RESULTS.md` in your hackathon presentation to show quantifiable improvements!

## Understanding the Metrics

### Overall Score (1-5 scale)
- **5**: Excellent - Perfect response
- **4**: Good - Minor issues
- **3.5**: Pass threshold
- **3**: Fair - Notable issues
- **2**: Poor - Major problems
- **1**: Failed - Unusable response

### Evaluation Dimensions

1. **Relevance** - Does the response address the user's question?
2. **Completeness** - Are all required concepts included?
3. **Format** - Does it follow voice-friendly format rules?
4. **Screen Usage** - Does it appropriately reference screen context?
5. **Clarity** - Is it understandable for elderly users?

### Pass Rate
Percentage of tests scoring ≥3.5 overall. Target: 80%+

## Test Case Categories

- **Communication** (4 tests) - Messaging, calls, understanding text
- **Navigation** (3 tests) - Finding settings, explaining icons
- **Safety** (3 tests) - Scam detection, suspicious link warnings
- **Task Guidance** (3 tests) - Step-by-step instructions
- **Screen Understanding** (2 tests) - Visual context interpretation

## File Structure

```
test/
├── benchmark_dataset.json          # 15 test cases
├── run_benchmark.dart              # Evaluation script
├── compare_results.dart            # Comparison script
├── README.md                       # This file
├── SCREENSHOT_GUIDE.md             # Optional: Adding real screenshots
├── benchmark_results_baseline.json # Your first run
├── benchmark_results_improved.json # After improvements
└── BENCHMARK_RESULTS.md            # Generated comparison report
```

## Customizing Test Cases

Edit `benchmark_dataset.json` to add/modify test cases:

```json
{
  "id": "your_test_id",
  "category": "Communication",
  "query": "How do I do X?",
  "screen_context": "Detailed description of what's on screen",
  "evaluation_criteria": {
    "must_include": ["keyword1", "keyword2"],
    "must_not_include": ["markdown", "bullet points"],
    "should_reference_screen": true,
    "max_sentences": 5
  }
}
```

## Adding Real Screenshots (Optional)

Currently, test cases use text descriptions of screen context. To use real screenshots:

1. Capture screenshots and save to `test/screenshots/`
2. Modify `run_benchmark.dart` to load images
3. Send images to Gemini as `Content.data()` with mime type
4. See `SCREENSHOT_GUIDE.md` for detailed instructions

## Troubleshooting

### API Key Issues
```
❌ Error: GEMINI_API_KEY not found in .env file
```
**Solution:** Ensure `.env` file exists in project root with `GEMINI_API_KEY=your_key_here`

### Rate Limiting
```
❌ Error: 429 Too Many Requests
```
**Solution:** Increase delay between requests in `run_benchmark.dart` (line with `Future.delayed`)

### Low Scores
**Solution:** Review failed test cases in results JSON, identify patterns, adjust system instructions

### JSON Parse Errors
```
❌ Error: FormatException: Unexpected character
```
**Solution:** LLM-as-Judge may have returned invalid JSON. Script has fallback handling, but may need retry.

## Advanced Usage

### Running Specific Test Categories

Modify `run_benchmark.dart` to filter by category:

```dart
final testCases = (datasetJson['test_cases'] as List)
    .where((tc) => tc['category'] == 'Safety')
    .toList();
```

### Custom Evaluation Criteria

Add new criteria in test cases and update `evaluateResponse()` function.

### A/B Testing System Prompts

1. Create two variants of system instructions
2. Run benchmark with each variant
3. Compare results to see which performs better

### Continuous Benchmarking

Set up in CI/CD to run on every commit:
```bash
dart run test/run_benchmark.dart test/benchmark_results_latest.json
# Alert if pass rate drops below threshold
```

## Performance Expectations

- **Baseline (no optimizations):** 60-70% pass rate
- **Good performance:** 80-85% pass rate
- **Excellent performance:** 90%+ pass rate

## Tips for Improving Scores

1. **Low Relevance:** Make system instructions more specific about understanding context
2. **Low Completeness:** Ensure AI covers all key points in its responses
3. **Low Format:** Strengthen formatting rules (no markdown, spell out numbers, etc.)
4. **Low Screen Usage:** Add examples of how to reference screen context
5. **Low Clarity:** Simplify language, avoid jargon, use conversational tone

## Cost Estimates

- ~30 API calls per benchmark run (15 tests + 15 evaluations)
- Gemini 2.0 Flash: Free tier should cover several runs
- Full benchmarking workflow (baseline + improved + comparison): ~60 API calls

## Questions?

Check the main README or system prompt in `lib/services/gemini_service.dart` for reference on how the AI is configured.

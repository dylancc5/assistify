# Screenshot Guide for Enhanced Benchmarking

This guide explains how to add real screenshots to your benchmark tests for more realistic visual context evaluation.

## Why Add Screenshots?

- **More realistic testing:** Tests how AI interprets actual UI elements
- **Catches visual understanding issues:** Text descriptions may miss visual nuances
- **Better demonstration:** Shows real multimodal capabilities in hackathon presentation
- **Identifies OCR problems:** Tests if AI can read text in images correctly

## Quick Start: 7 Essential Screenshots

For maximum impact with minimal time, capture these 7 key screens:

### 1. Messages App - Send Photo
**Filename:** `screenshots/messages_send_photo.png`
- Open Messages app
- Navigate to any conversation
- Show the text input field with camera icon visible
- Captures: test cases `comm_001`, `comm_004`

### 2. FaceTime Contact
**Filename:** `screenshots/facetime_contact.png`
- Open Contacts app
- Select any contact with FaceTime enabled
- Show the FaceTime video call button
- Captures: test case `comm_002`

### 3. Slang in Message
**Filename:** `screenshots/message_slang.png`
- Create or screenshot a message containing "LOL"
- Keep it simple and readable
- Captures: test case `comm_003`

### 4. Home Screen
**Filename:** `screenshots/home_screen.png`
- Standard iOS home screen
- Make sure Settings app (gear icon) is visible
- Captures: test cases `nav_001`, `nav_002`, `screen_001`

### 5. Navigation with Back Button
**Filename:** `screenshots/back_button.png`
- Open any app (Settings works well)
- Navigate one level deep to show back arrow
- Captures: test case `nav_003`

### 6. Phishing Text
**Filename:** `screenshots/phishing_text.png`
- Create a fake text message with suspicious content
- Example: "Your bank account locked! Click here: http://fake-bank.xyz"
- Use screenshot tools or simulator
- Captures: test cases `safety_001`, `safety_002`, `safety_003`

### 7. Incoming Call
**Filename:** `screenshots/incoming_call.png`
- Simulate incoming call screen
- Show "Unknown Caller" or similar
- Show accept/decline buttons
- Captures: test case `screen_002`

## How to Capture Screenshots on iOS

### Using iOS Simulator
```bash
# Start simulator
open -a Simulator

# Take screenshot (saves to Desktop)
# Press: Cmd + S
# Or: Device > Screenshot
```

### Using Real iPhone
- Press Side Button + Volume Up (iPhone X and newer)
- Press Home Button + Power Button (older iPhones)
- Photos appear in Photos app

### Using Xcode
```bash
# With device connected
xcrun simctl io booted screenshot screenshot_name.png
```

## Integrating Screenshots into Benchmark

### Step 1: Save Screenshots

Create directory and save files:
```bash
mkdir -p test/screenshots
# Save your 7 screenshots there
```

### Step 2: Update Test Cases

Modify `benchmark_dataset.json` to reference images:

```json
{
  "id": "comm_001",
  "category": "Communication",
  "query": "How do I send a photo to my daughter?",
  "screen_context": "text description...",
  "screenshot_path": "test/screenshots/messages_send_photo.png",
  "evaluation_criteria": { ... }
}
```

### Step 3: Update run_benchmark.dart

Add image loading logic (insert after line where prompt is created):

```dart
import 'dart:typed_data';

// Inside the benchmark loop, after loading test case:
Content? imageContent;
if (testCase.containsKey('screenshot_path')) {
  final screenshotPath = testCase['screenshot_path'];
  final imageFile = File(screenshotPath);

  if (await imageFile.exists()) {
    final imageBytes = await imageFile.readAsBytes();
    imageContent = Content.multi([
      TextPart(prompt),
      DataPart('image/png', Uint8List.fromList(imageBytes)),
    ]);
  }
}

// Modify the sendMessage call:
final response = imageContent != null
    ? await chat.sendMessage(imageContent)
    : await chat.sendMessage(Content.text(prompt));
```

## Screenshot Checklist

- [ ] Messages app with camera icon
- [ ] Contact with FaceTime button
- [ ] Message with slang/abbreviation
- [ ] Home screen with Settings app visible
- [ ] App screen with back button
- [ ] Phishing/scam text message
- [ ] Incoming call screen

## Tips for Good Screenshots

### Do:
- ✅ Use clear, high-resolution images
- ✅ Show relevant UI elements prominently
- ✅ Use realistic but safe content (no real phone numbers/addresses)
- ✅ Keep consistent device/iOS version for all screenshots
- ✅ Ensure text is readable

### Don't:
- ❌ Include personal information (real phone numbers, names, addresses)
- ❌ Use blurry or low-quality images
- ❌ Crop too tightly (show some context)
- ❌ Use dark mode if test assumes light mode (or vice versa)

## Creating Synthetic Screenshots (Advanced)

If you can't access iOS devices, you can create mockups:

### Using Figma
1. Use iOS UI kit templates
2. Create realistic app screens
3. Export as PNG

### Using Online Tools
- **Mockuphone:** https://mockuphone.com
- **Previewed:** https://previewed.app
- **Screely:** https://screely.com

## Image Optimization

Reduce file size for faster benchmarks:

```bash
# Install ImageMagick
brew install imagemagick

# Resize to 1024px width (Gemini's max)
magick convert input.png -resize 1024x output.png

# Compress
magick convert input.png -quality 70 output.png
```

Or use built-in macOS tools:
```bash
sips -Z 1024 input.png --out output.png
```

## Troubleshooting

### Image Not Loading
- Check file path is correct relative to project root
- Ensure file extension matches actual format (.png, .jpg)
- Verify file isn't corrupted

### Gemini Not Understanding Image
- Ensure image resolution is at least 512px
- Check image isn't too dark or low contrast
- Verify text in image is readable
- Try more detailed text description alongside image

### File Size Too Large
- Resize to 1024px max dimension
- Compress to 70% quality
- Convert to JPEG if PNG is too large

## Performance Impact

- **Text-only:** ~2-3 seconds per test
- **With images:** ~4-6 seconds per test
- **Storage:** ~5-10MB for 7 screenshots

## Example: Before and After

### Before (Text-only)
```json
"screen_context": "iOS Messages app showing conversation..."
```

### After (With Image)
```json
"screen_context": "iOS Messages app showing conversation...",
"screenshot_path": "test/screenshots/messages_send_photo.png"
```

**Result:** AI can now see the exact placement of buttons, read actual text, identify colors, and understand spatial relationships.

## Next Steps

1. Capture 7 essential screenshots (~15 minutes)
2. Update `benchmark_dataset.json` with paths
3. Modify `run_benchmark.dart` to load images
4. Run benchmark and compare text-only vs. with-images results
5. Demonstrate improved visual understanding in hackathon presentation

## Cost Considerations

- Images count toward Gemini API token usage
- Each image ≈ 258 tokens (at 1024px)
- 15 tests × 258 tokens ≈ 3,870 tokens per benchmark run
- Still within free tier limits

## Questions?

See main `test/README.md` or check Gemini API documentation for image formats:
https://ai.google.dev/gemini-api/docs/vision

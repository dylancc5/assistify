import Flutter
import UIKit
import ReplayKit
import AVFoundation
import Speech

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenRecorder: RPScreenRecorder?
  private var methodChannel: FlutterMethodChannel?
  private var speechMethodChannel: FlutterMethodChannel?
  private var audioLevelEventChannel: FlutterEventChannel?
  private var audioLevelEventSink: FlutterEventSink?
  private var assetWriter: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var audioInput: AVAssetWriterInput?
  private var outputURL: URL?
  private var recordingStartTime: Date?

  // App Group identifier for broadcast extension communication
  private let appGroupIdentifier = "group.com.dylancc5.assistify.broadcast"

  // Screen capture frame buffer properties
  private var frameBuffer: [Data] = []
  private var frameBufferLock = NSLock()
  private var lastFrameCaptureTime: Date?
  private var isCapturingFrames: Bool = false
  private let frameCaptureInterval: TimeInterval = 0.5  // 500ms between frames
  private var isUsingBroadcastExtension: Bool = false
  private var useRawAudioSTT: Bool = false  // Use raw audio recording for STT when broadcasting

  // Speech recognition properties
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var audioEngine: AVAudioEngine?
  private var currentTranscript: String = ""
  private var isListening: Bool = false
  private var shouldBeListening: Bool = false  // Track if user wants to be listening

  // Background audio recording properties
  private var isAppInForeground: Bool = true
  private var isRecordingRawAudio: Bool = false
  private var audioRecorder: AVAudioRecorder?
  private var rawAudioURL: URL?
  private var rawAudioSilenceTimer: Timer?
  private var lastAudioLevel: Float = 0.0
  private let rawAudioSilenceThreshold: TimeInterval = 1.5

  // Silence detection properties
  private var silenceTimer: Timer?
  private var lastTranscriptLength: Int = 0
  private var currentLanguageCode: String = "en-US"  // Track current language for restart
  private var speechEventChannel: FlutterEventChannel?
  private var speechEventSink: FlutterEventSink?
  private let silenceThreshold: TimeInterval = 1.5  // seconds of silence to trigger segment end

  // TTS properties
  private var ttsMethodChannel: FlutterMethodChannel?
  private var speechSynthesizer: AVSpeechSynthesizer?
  private var ttsDelegate: TTSDelegate?
  private var ttsCompletionHandler: ((Bool) -> Void)?
  private var ttsAudioLevelEventChannel: FlutterEventChannel?
  private var ttsAudioLevelEventSink: FlutterEventSink?

  // Native log forwarding properties
  private var nativeLogEventChannel: FlutterEventChannel?
  private var nativeLogEventSink: FlutterEventSink?

  // Background Baidu processing properties
  private var backgroundBaiduTask: UIBackgroundTaskIdentifier = .invalid
  private var baiduApiKey: String?
  private var baiduSecretKey: String?
  private var baiduAccessToken: String?
  private var baiduTokenExpiry: Date?
  private var supabaseUrl: String?
  private var supabaseAnonKey: String?
  private var chatHistory: [[String: String]] = []
  private var conversationIds: [String] = []
  private var lastProcessedRequestTime: TimeInterval = 0  // Track last processed request to avoid duplicates
  private var activeRequestId: String?
  
  // Memory warning safety flags
  private var isProcessingBaiduRequest = false
  private var isSamplingFrames = false
  
  // Concurrent queue for UserDefaults operations
  private let userDefaultsQueue = DispatchQueue(label: "com.assistify.userDefaults", qos: .utility, attributes: .concurrent)
  
  // Audio session transition state
  private var isTransitioningAudioSession = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up method channel for screen recording
    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(
      name: "com.assistify/screen_recording",
      binaryMessenger: controller.binaryMessenger
    )

    screenRecorder = RPScreenRecorder.shared()

    // Set up broadcast extension monitoring
    setupBroadcastExtensionMonitoring()
    
    // Check if broadcast extension is already active on app launch
    if isBroadcastExtensionActive() {
      print("[AppDelegate] Broadcast extension is already active on app launch")
      isUsingBroadcastExtension = true
      isCapturingFrames = true
    }

    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "isAvailable":
        self.checkAvailability(result: result)
      case "startRecording":
        self.startRecording(result: result)
      case "stopRecording":
        self.stopRecording(result: result)
      case "isRecording":
        self.isRecording(result: result)
      case "showBroadcastPicker":
        self.showBroadcastPicker(result: result)
      case "isBroadcasting":
        self.checkBroadcastStatus(result: result)
      case "startFrameCapture":
        self.startFrameCapture(result: result)
      case "stopFrameCapture":
        self.stopFrameCapture(result: result)
      case "isCapturing":
        // Check both broadcast extension and in-app recording
        let isBroadcasting = self.isBroadcastExtensionActive()
        result(self.isCapturingFrames || isBroadcasting)
      case "sampleScreenshots":
        let maxSamples = (call.arguments as? [String: Any])?["maxSamples"] as? Int ?? 10
        self.sampleScreenshots(maxSamples: maxSamples, result: result)
      case "clearBuffer":
        self.clearFrameBuffer(result: result)
      case "getBufferCount":
        self.frameBufferLock.lock()
        let count = self.frameBuffer.count
        self.frameBufferLock.unlock()
        result(count)
      case "setBroadcastContext":
        if let args = call.arguments as? [String: Any] {
          self.baiduApiKey = args["baiduApiKey"] as? String
          self.baiduSecretKey = args["baiduSecretKey"] as? String
          self.supabaseUrl = args["supabaseUrl"] as? String
          self.supabaseAnonKey = args["supabaseAnonKey"] as? String
          self.conversationIds = args["conversationIds"] as? [String] ?? []
          if let historyData = args["chatHistory"] as? [[String: String]] {
            self.chatHistory = historyData
          }
          print("📱 [BackgroundBaidu] Broadcast context set - \(self.chatHistory.count) messages, \(self.conversationIds.count) conversations")
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for setBroadcastContext", details: nil))
        }
      case "checkGeminiResponse":
        self.checkGeminiResponse(result: result)
      case "clearGeminiResponse":
        self.clearGeminiResponse(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Set up method channel for speech recognition
    speechMethodChannel = FlutterMethodChannel(
      name: "com.assistify/speech_recognition",
      binaryMessenger: controller.binaryMessenger
    )

    // Set up event channel for audio levels
    audioLevelEventChannel = FlutterEventChannel(
      name: "com.assistify/audio_levels",
      binaryMessenger: controller.binaryMessenger
    )
    audioLevelEventChannel?.setStreamHandler(AudioLevelStreamHandler(appDelegate: self))

    // Set up event channel for speech events (segment complete)
    speechEventChannel = FlutterEventChannel(
      name: "com.assistify/speech_events",
      binaryMessenger: controller.binaryMessenger
    )
    speechEventChannel?.setStreamHandler(SpeechEventStreamHandler(appDelegate: self))

    // Initialize audio engine (speech recognizer will be created dynamically with language)
    audioEngine = AVAudioEngine()

    // Set up method channel for TTS
    ttsMethodChannel = FlutterMethodChannel(
      name: "com.assistify/tts",
      binaryMessenger: controller.binaryMessenger
    )

    // Initialize speech synthesizer with delegate
    speechSynthesizer = AVSpeechSynthesizer()
    ttsDelegate = TTSDelegate(appDelegate: self)
    speechSynthesizer?.delegate = ttsDelegate

    // Set up event channel for TTS audio levels
    ttsAudioLevelEventChannel = FlutterEventChannel(
      name: "com.assistify/tts_audio_levels",
      binaryMessenger: controller.binaryMessenger
    )
    ttsAudioLevelEventChannel?.setStreamHandler(TTSAudioLevelStreamHandler(appDelegate: self))

    // Set up event channel for native logs
    nativeLogEventChannel = FlutterEventChannel(
      name: "com.assistify/native_logs",
      binaryMessenger: controller.binaryMessenger
    )
    nativeLogEventChannel?.setStreamHandler(NativeLogStreamHandler(appDelegate: self))

    // Set up audio interruption handling for background operation
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )

    // Set up app lifecycle observers for foreground/background detection
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )

    ttsMethodChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "speak":
        if let args = call.arguments as? [String: Any],
           let text = args["text"] as? String,
           let languageCode = args["languageCode"] as? String {
          let slowerSpeech = args["slowerSpeech"] as? Bool ?? false
          let voiceId = args["voiceId"] as? String
          self.speakText(text: text, languageCode: languageCode, slowerSpeech: slowerSpeech, voiceId: voiceId, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
        }
      case "stop":
        self.stopSpeaking(result: result)
      case "isSpeaking":
        result(self.speechSynthesizer?.isSpeaking ?? false)
      case "checkEnhancedVoice":
        if let args = call.arguments as? [String: Any],
           let languageCode = args["languageCode"] as? String {
          self.checkEnhancedVoiceAvailable(languageCode: languageCode, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing languageCode", details: nil))
        }
      case "openVoiceSettings":
        self.openVoiceSettings(result: result)
      case "getAvailableVoices":
        self.getAvailableVoices(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    speechMethodChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "checkPermission":
        self.checkSpeechPermission(result: result)
      case "requestPermission":
        self.requestSpeechPermission(result: result)
      case "startListening":
        let languageCode = (call.arguments as? [String: Any])?["languageCode"] as? String ?? "en-US"
        self.startSpeechRecognition(languageCode: languageCode, result: result)
      case "stopListening":
        self.stopSpeechRecognition(result: result)
      case "endChat":
        self.endChat(result: result)
      case "getTranscript":
        // Return current transcript (the segment being recorded)
        let transcript = self.currentTranscript
        result(transcript)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    print("⚠️ [Memory] Memory warning received - cleaning up")
    
    // Only cleanup if not processing/sampling
    guard !isProcessingBaiduRequest && !isSamplingFrames else {
      print("⚠️ [Memory] Skipping cleanup - active operations in progress")
      return
    }
    
    // Clear frame buffer (if not using broadcast extension)
    if !isUsingBroadcastExtension {
      frameBufferLock.lock()
      let bufferCount = frameBuffer.count
      if bufferCount > 20 {
        // Keep only most recent 20 frames
        frameBuffer = Array(frameBuffer.suffix(20))
        print("⚠️ [Memory] Reduced frame buffer from \(bufferCount) to 20 frames")
      }
      frameBufferLock.unlock()
    }
    
    // Clear broadcast audio chunks if not actively using
    if !useRawAudioSTT {
      clearBroadcastAudioChunks()
    }
    
    // Cancel any pending recognition if not actively listening
    if !shouldBeListening {
      recognitionTask?.cancel()
      recognitionRequest?.endAudio()
    }
    
    // Force autorelease pool cleanup
    autoreleasepool {
      // Any temporary objects will be released
    }
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    print("📱 [AppLifecycle] App terminating - cleaning up")
    
    let cleanupGroup = DispatchGroup()
    var cleanupCompleted = false
    
    // Set timeout for cleanup
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      if !cleanupCompleted {
        print("⚠️ Cleanup timeout - forcing completion")
        cleanupCompleted = true
      }
    }
    
    // Critical cleanup (synchronous)
    cleanupGroup.enter()
    endBackgroundBaiduTask()
    stopBackgroundGeminiPolling()
    
    // Invalidate all timers
    geminiPollingTimer?.invalidate()
    geminiPollingTimer = nil
    silenceTimer?.invalidate()
    silenceTimer = nil
    rawAudioSilenceTimer?.invalidate()
    rawAudioSilenceTimer = nil
    rawAudioSilenceEndTimer?.invalidate()
    rawAudioSilenceEndTimer = nil
    broadcastAudioMonitorTimer?.invalidate()
    broadcastAudioMonitorTimer = nil
    extensionTranscriptMonitorTimer?.invalidate()
    extensionTranscriptMonitorTimer = nil
    
    cleanupGroup.leave()
    
    // Non-critical cleanup (async with timeout)
    cleanupGroup.enter()
    DispatchQueue.global().async {
      // Stop recording if active (may not complete)
      if let recorder = self.screenRecorder, recorder.isRecording {
        recorder.stopCapture { error in
          if let error = error {
            print("⚠️ Failed to save recording on termination: \(error)")
          }
        }
      }
      
      // Stop speech recognition
      self.stopSpeechRecognition(result: { _ in })
      self.stopAudioEngine()
      
      // Save state to UserDefaults
      if let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) {
        userDefaults.set(false, forKey: "isBroadcasting")
        userDefaults.synchronize()
      }
      
      cleanupGroup.leave()
    }
    
    // Wait with timeout
    _ = cleanupGroup.wait(timeout: .now() + 1.5)
    cleanupCompleted = true
  }

  // MARK: - Screen Recording Methods

  private func checkAvailability(result: @escaping FlutterResult) {
    // ReplayKit is available on iOS 9+, but we check just in case
    let available = RPScreenRecorder.shared().isAvailable
    result(available)
  }

  private func startRecording(result: @escaping FlutterResult) {
    guard let recorder = screenRecorder else {
      result(FlutterError(code: "RECORDER_UNAVAILABLE",
                         message: "Screen recorder is not available",
                         details: nil))
      return
    }

    // Check if already recording
    if recorder.isRecording {
      result(FlutterError(code: "ALREADY_RECORDING",
                         message: "Screen recording is already in progress",
                         details: nil))
      return
    }

    // Create output file path in documents directory
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    outputURL = documentsPath.appendingPathComponent("recording_\(timestamp).mp4")
    recordingStartTime = Date()

    guard let url = outputURL else {
      result(FlutterError(code: "FILE_ERROR",
                         message: "Could not create output file",
                         details: nil))
      return
    }

    // Set up AVAssetWriter to save video to file
    do {
      assetWriter = try AVAssetWriter(url: url, fileType: .mp4)
    } catch {
      result(FlutterError(code: "WRITER_ERROR",
                         message: "Could not create asset writer: \(error.localizedDescription)",
                         details: nil))
      return
    }

    // Start capture handler for live frames
    recorder.startCapture(handler: { [weak self] (sampleBuffer, bufferType, error) in
      guard let self = self else { return }

      if let error = error {
        print("Screen recording error: \(error.localizedDescription)")
        return
      }

      guard let writer = self.assetWriter else { return }

      // Process the sample buffer based on type
      switch bufferType {
      case .video:
        // Set up video input if needed
        if self.videoInput == nil {
          guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
          let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

          let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: dimensions.width,
            AVVideoHeightKey: dimensions.height
          ]

          self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
          self.videoInput?.expectsMediaDataInRealTime = true

          if writer.canAdd(self.videoInput!) {
            writer.add(self.videoInput!)
          }

          if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
          }
        }

        // Write video frame
        if writer.status == .writing, let input = self.videoInput, input.isReadyForMoreMediaData {
          input.append(sampleBuffer)
        }

      case .audioApp, .audioMic:
        // Set up audio input if needed
        if self.audioInput == nil {
          guard CMSampleBufferGetFormatDescription(sampleBuffer) != nil else { return }

          let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2
          ]

          self.audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
          self.audioInput?.expectsMediaDataInRealTime = true

          if writer.canAdd(self.audioInput!) {
            writer.add(self.audioInput!)
          }
        }

        // Write audio frame
        if writer.status == .writing, let input = self.audioInput, input.isReadyForMoreMediaData {
          input.append(sampleBuffer)
        }

      @unknown default:
        break
      }
    }) { error in
      if let error = error {
        result(FlutterError(code: "START_FAILED",
                           message: "Failed to start screen recording: \(error.localizedDescription)",
                           details: nil))
      } else {
        result(true)
      }
    }
  }

  private func stopRecording(result: @escaping FlutterResult) {
    guard let recorder = screenRecorder else {
      result(FlutterError(code: "RECORDER_UNAVAILABLE",
                         message: "Screen recorder is not available",
                         details: nil))
      return
    }

    if !recorder.isRecording {
      result(FlutterError(code: "NOT_RECORDING",
                         message: "Screen recording is not in progress",
                         details: nil))
      return
    }

    let startTime = recordingStartTime
    let url = outputURL

    recorder.stopCapture { [weak self] error in
      guard let self = self else { return }

      if let error = error {
        result(FlutterError(code: "STOP_FAILED",
                           message: "Failed to stop screen recording: \(error.localizedDescription)",
                           details: nil))
        return
      }

      // Finalize the asset writer
      if let writer = self.assetWriter {
        self.videoInput?.markAsFinished()
        self.audioInput?.markAsFinished()

        writer.finishWriting { [weak self] in
          guard let self = self else { return }

          // Calculate duration and file size
          var duration: TimeInterval = 0
          var fileSize: Int64 = 0

          if let startTime = startTime {
            duration = Date().timeIntervalSince(startTime)
          }

          if let url = url, FileManager.default.fileExists(atPath: url.path) {
            do {
              let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
              fileSize = attributes[.size] as? Int64 ?? 0
            } catch {
              print("Error getting file size: \(error)")
            }
          }

          // Return file info to Flutter
          let resultData: [String: Any] = [
            "filePath": url?.path ?? "",
            "durationMs": Int(duration * 1000),
            "fileSize": fileSize
          ]

          result(resultData)

          // Clean up
          self.assetWriter = nil
          self.videoInput = nil
          self.audioInput = nil
          self.outputURL = nil
          self.recordingStartTime = nil
        }
      } else {
        result(FlutterError(code: "WRITER_ERROR",
                           message: "Asset writer was not initialized",
                           details: nil))
      }
    }
  }

  private func isRecording(result: @escaping FlutterResult) {
    result(screenRecorder?.isRecording ?? false)
  }

  // MARK: - Broadcast Extension Methods

  private func showBroadcastPicker(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let rootVC = self?.window?.rootViewController else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER",
                           message: "Could not get root view controller",
                           details: nil))
        return
      }

      // Create broadcast picker view
      let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
      // Don't set preferredExtension to allow user to choose from list
      // broadcastPicker.preferredExtension = "com.dylancc5.assistify.Asstify-Screenshare"
      broadcastPicker.showsMicrophoneButton = false

      // Add to view hierarchy temporarily so it can present the picker
      broadcastPicker.alpha = 0
      rootVC.view.addSubview(broadcastPicker)

      // Find and tap the button to show the picker
      for subview in broadcastPicker.subviews {
        if let button = subview as? UIButton {
          button.sendActions(for: .touchUpInside)
          break
        }
      }

      // Remove after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        broadcastPicker.removeFromSuperview()
      }

      result(true)
    }
  }

  private func checkBroadcastStatus(result: @escaping FlutterResult) {
    // Check if broadcast extension is currently active via App Group
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      result(false)
      return
    }
    let isBroadcasting = userDefaults.bool(forKey: "isBroadcasting")
    result(isBroadcasting)
  }

  // MARK: - Frame Capture Methods

  private func startFrameCapture(result: @escaping FlutterResult) {
    // First, check if broadcast extension is already active (user started it manually)
    if isBroadcastExtensionActive() {
      print("📺 [ScreenCapture] Using BROADCAST EXTENSION - system-wide screen recording active")
      isUsingBroadcastExtension = true
      isCapturingFrames = true

      // Reconfigure audio session to ensure speech recognition continues working
      reconfigureAudioSessionForSpeech()

      result(true)
      return
    }

    // Broadcast extension not active - show the picker for user to start it
    print("📺 [ScreenCapture] Broadcast extension not active - showing picker for user to start it")
    isUsingBroadcastExtension = false
    isCapturingFrames = false

    // Show the broadcast picker
    DispatchQueue.main.async { [weak self] in
      guard let rootVC = self?.window?.rootViewController else {
        print("❌ [ScreenCapture] No root view controller")
        result(false)
        return
      }

      // Create broadcast picker view
      let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
      broadcastPicker.preferredExtension = "com.dylancc5.assistify.Asstify-Screenshare"
      broadcastPicker.showsMicrophoneButton = true  // Enable mic for raw audio STT

      // Add to view hierarchy temporarily so it can present the picker
      broadcastPicker.alpha = 0
      rootVC.view.addSubview(broadcastPicker)

      // Find and tap the button recursively
      func findButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton {
          return button
        }
        for subview in view.subviews {
          if let button = findButton(in: subview) {
            return button
          }
        }
        return nil
      }

      if let button = findButton(in: broadcastPicker) {
        print("📺 [ScreenCapture] Found broadcast picker button, triggering...")
        button.sendActions(for: .touchUpInside)
      } else {
        print("❌ [ScreenCapture] Could not find button in broadcast picker")
      }

      // Remove after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        broadcastPicker.removeFromSuperview()
      }

      // Return true since picker was shown successfully - user will start broadcast from picker
      result(true)
    }
    return

    // FALLBACK CODE - kept for future use but disabled
    /*
    // Fallback to in-app recording
    print("📱 [ScreenCapture] Using IN-APP RECORDING (fallback) - only captures this app")
    isUsingBroadcastExtension = false

    guard let recorder = screenRecorder else {
      result(FlutterError(code: "RECORDER_UNAVAILABLE",
                         message: "Screen recorder is not available",
                         details: nil))
      return
    }

    if isCapturingFrames {
      result(FlutterError(code: "ALREADY_CAPTURING",
                         message: "Frame capture is already in progress",
                         details: nil))
      return
    }

    // Clear any existing frames
    frameBufferLock.lock()
    frameBuffer.removeAll()
    frameBufferLock.unlock()
    lastFrameCaptureTime = nil

    // Disable microphone for screen capture to avoid conflict with speech recognition
    recorder.isMicrophoneEnabled = false

    // Start capture handler for live frames
    recorder.startCapture(handler: { [weak self] (sampleBuffer, bufferType, error) in
      guard let self = self else { return }

      if let error = error {
        print("Frame capture error: \(error.localizedDescription)")
        return
      }

      // Only process video frames
      guard bufferType == .video else { return }

      // Check if enough time has passed since last capture
      let now = Date()
      if let lastCapture = self.lastFrameCaptureTime,
         now.timeIntervalSince(lastCapture) < self.frameCaptureInterval {
        return
      }
      self.lastFrameCaptureTime = now

      // Convert CMSampleBuffer to JPEG
      guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
      let ciImage = CIImage(cvPixelBuffer: imageBuffer)
      let context = CIContext()

      // Get dimensions and calculate scaled size (max 1024px on longest side for Gemini)
      let extent = ciImage.extent
      let maxDimension: CGFloat = 1024
      let scale = min(maxDimension / extent.width, maxDimension / extent.height, 1.0)
      let scaledWidth = Int(extent.width * scale)
      let scaledHeight = Int(extent.height * scale)

      guard let cgImage = context.createCGImage(ciImage, from: extent) else { return }

      // Create scaled image
      UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), true, 1.0)
      UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
      let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()

      // Convert to JPEG with compression
      guard let jpegData = scaledImage?.jpegData(compressionQuality: 0.7) else { return }

      // Add to buffer
      self.frameBufferLock.lock()
      self.frameBuffer.append(jpegData)
      self.frameBufferLock.unlock()

    }) { error in
      if let error = error {
        result(FlutterError(code: "START_FAILED",
                           message: "Failed to start frame capture: \(error.localizedDescription)",
                           details: nil))
      } else {
        self.isCapturingFrames = true
        result(true)
      }
    }
    */
  }

  private func stopFrameCapture(result: @escaping FlutterResult) {
    // Check if broadcast extension is active
    let isBroadcasting = isBroadcastExtensionActive()

    if isUsingBroadcastExtension || isBroadcasting {
      // For broadcast extension, update flags and clear buffer
      // Note: The broadcast extension itself cannot be stopped programmatically
      // User must stop it via Control Center, but we'll stop using its frames
      print("📺 [ScreenCapture] Stopping broadcast extension frame capture")

      // Clear our tracking flags
      isUsingBroadcastExtension = false
      isCapturingFrames = false

      // Clear the shared container frames
      clearSharedContainerFrames()

      // Note: The broadcast will continue running until user stops it via Control Center
      // but we will no longer use the frames
      if isBroadcasting {
        print("📺 [ScreenCapture] Note: Broadcast extension is still running. Stop it via Control Center if needed.")
      }

      result(true)
      return
    }

    // Fallback: stop in-app recording
    guard let recorder = screenRecorder else {
      result(FlutterError(code: "RECORDER_UNAVAILABLE",
                         message: "Screen recorder is not available",
                         details: nil))
      return
    }

    if !isCapturingFrames {
      result(true)
      return
    }

    recorder.stopCapture { [weak self] error in
      if let error = error {
        result(FlutterError(code: "STOP_FAILED",
                           message: "Failed to stop frame capture: \(error.localizedDescription)",
                           details: nil))
      } else {
        self?.isCapturingFrames = false
        result(true)
      }
    }
  }

  private func sampleScreenshots(maxSamples: Int, result: @escaping FlutterResult) {
    // Check if we're using broadcast extension
    if isUsingBroadcastExtension && isBroadcastExtensionActive() {
      let frames = readFramesFromSharedContainer(maxSamples: maxSamples)
      print("📺 [ScreenCapture] Sampled \(frames.count) frames from BROADCAST EXTENSION")
      let flutterData = frames.map { FlutterStandardTypedData(bytes: $0) }
      result(flutterData as [Any])
      return
    }

    // Fallback: use in-memory buffer
    print("📱 [ScreenCapture] Sampling from IN-APP buffer")
    frameBufferLock.lock()
    let bufferCount = frameBuffer.count

    if bufferCount == 0 {
      frameBufferLock.unlock()
      result([FlutterStandardTypedData]())
      return
    }

    // Calculate evenly distributed indices
    var indices: [Int] = []
    if bufferCount <= maxSamples {
      // Return all frames if we have fewer than maxSamples
      indices = Array(0..<bufferCount)
    } else {
      // Select evenly distributed frames
      for i in 0..<maxSamples {
        let index = (i * bufferCount) / maxSamples
        indices.append(index)
      }
    }

    // Get the sampled frames
    let sampledFrames = indices.map { frameBuffer[$0] }
    frameBufferLock.unlock()

    // Return as array of FlutterStandardTypedData for transfer to Dart
    let flutterData = sampledFrames.map { FlutterStandardTypedData(bytes: $0) }
    result(flutterData as [Any])
  }

  private func clearFrameBuffer(result: @escaping FlutterResult) {
    // Clear broadcast extension frames if active
    if isUsingBroadcastExtension && isBroadcastExtensionActive() {
      clearSharedContainerFrames()
    }
    
    // Clear in-memory buffer
    frameBufferLock.lock()
    frameBuffer.removeAll()
    frameBufferLock.unlock()
    result(true)
  }

  // MARK: - Broadcast Extension Helper Methods

  private func isBroadcastExtensionActive() -> Bool {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      print("📺 [ScreenCapture] ERROR: Could not access App Group UserDefaults")
      return false
    }
    userDefaults.synchronize() // Force sync to get latest value
    return userDefaults.bool(forKey: "isBroadcasting")
  }

  private func readFramesFromSharedContainer(maxSamples: Int) -> [Data] {
    // Set flag to prevent cleanup during sampling
    isSamplingFrames = true
    defer { isSamplingFrames = false }
    
    // Also set in UserDefaults for extension to check
    if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
      userDefaults.set(true, forKey: "isSamplingFrames")
      userDefaults.synchronize()
    }
    defer {
      if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
        userDefaults.set(false, forKey: "isSamplingFrames")
        userDefaults.synchronize()
      }
    }
    
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      print("[AppDelegate] ERROR: Could not access App Group container")
      return []
    }

    let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: framesDirectory.path) else {
      return []
    }

    // Filter and sort frame files by name (which includes timestamp)
    let frameFiles = files.filter { $0.hasSuffix(".jpg") }.sorted()

    if frameFiles.isEmpty {
      return []
    }

    // Calculate evenly distributed indices
    var indices: [Int] = []
    if frameFiles.count <= maxSamples {
      // Return all frames if we have fewer than maxSamples
      indices = Array(0..<frameFiles.count)
    } else {
      // Select evenly distributed frames
      for i in 0..<maxSamples {
        let index = (i * frameFiles.count) / maxSamples
        indices.append(index)
      }
    }

    // Read the sampled frames
    var frames: [Data] = []
    for index in indices {
      let filename = frameFiles[index]
      let fileURL = framesDirectory.appendingPathComponent(filename)
      if let data = try? Data(contentsOf: fileURL) {
        frames.append(data)
      }
    }

    // Clean up sampled frames from shared container
    for index in indices {
      let filename = frameFiles[index]
      let fileURL = framesDirectory.appendingPathComponent(filename)
      try? FileManager.default.removeItem(at: fileURL)
    }

    // Update frame count in UserDefaults
    if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
      let remainingCount = frameFiles.count - indices.count
      userDefaults.set(remainingCount, forKey: "frameCount")
      userDefaults.synchronize()
    }

    return frames
  }

  private func clearSharedContainerFrames() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      return
    }

    let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: framesDirectory.path) else {
      return
    }

    // Delete all frame files
    for filename in files.filter({ $0.hasSuffix(".jpg") }) {
      let fileURL = framesDirectory.appendingPathComponent(filename)
      try? FileManager.default.removeItem(at: fileURL)
    }

    // Update frame count in UserDefaults
    if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
      userDefaults.set(0, forKey: "frameCount")
      userDefaults.synchronize()
    }
  }

  private func setupBroadcastExtensionMonitoring() {
    // Monitor broadcast extension status periodically
    // Check every 1 second if broadcast status has changed
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self = self else { return }

      let wasBroadcasting = self.isUsingBroadcastExtension
      let isNowBroadcasting = self.isBroadcastExtensionActive()

      // Debug log to see what's happening
      if isNowBroadcasting != wasBroadcasting {
        logToFlutter("Status change detected: was=\(wasBroadcasting), now=\(isNowBroadcasting)", category: "ScreenCapture")
      }

      // If broadcast extension stopped while we were using it
      if wasBroadcasting && !isNowBroadcasting {
        logToFlutter("Broadcast extension stopped", category: "ScreenCapture")
        self.isUsingBroadcastExtension = false
        self.isCapturingFrames = false
        self.useRawAudioSTT = false  // Switch back to normal STT

        // Stop broadcast audio monitoring and extension transcript monitoring
        self.stopBroadcastAudioMonitoring()
        self.stopExtensionTranscriptMonitoring()
        self.isRecordingRawAudio = false

        // Clear any remaining audio chunks
        self.clearBroadcastAudioChunks()

        // Notify Flutter that broadcast stopped so UI can update
        DispatchQueue.main.async {
          self.methodChannel?.invokeMethod("broadcastStopped", arguments: nil)
        }

        // Restart normal speech recognition if user was listening
        if self.shouldBeListening && self.isAppInForeground {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.logToFlutter("Restarting normal speech recognition after broadcast stopped", category: "Speech")
            self.startFreshRecognition()
          }
        }
      } else if !wasBroadcasting && isNowBroadcasting {
        // Broadcast extension just started
        logToFlutter("Broadcast extension started - switching to SYSTEM-WIDE capture + raw audio STT", category: "ScreenCapture")
        self.isUsingBroadcastExtension = true
        self.isCapturingFrames = true
        self.useRawAudioSTT = true  // Use raw audio recording for STT

        // Reconfigure audio session and switch to raw audio STT after a delay
        // to allow the broadcast extension to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
          guard let self = self else { return }

          // Reconfigure audio session to ensure audio continues working
          self.reconfigureAudioSessionForSpeech()

          // If we were listening before, stop normal recognition and switch to extension STT or raw audio
          if self.shouldBeListening {
            self.logToFlutter("Switching to broadcast STT mode...", category: "BroadcastSTT")
            // Stop normal speech recognition if running
            if self.isListening {
              self.stopAudioEngine()
            }
            // Set language code for extension
            if let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) {
              userDefaults.set(self.currentLanguageCode, forKey: "speechLanguageCode")
              userDefaults.synchronize()
            }
            // Wait a moment for extension to initialize, then check if it's doing STT
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
              // Check if extension STT is active
              if let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) {
                userDefaults.synchronize()
                let extensionSTTActive = userDefaults.bool(forKey: "extensionSTTActive")
                if extensionSTTActive {
                  self.logToFlutter("Using EXTENSION STT (native Speech Recognition in broadcast extension)", category: "STT Mode")
                  self.logToFlutter("✓ Reliable, uses Apple's Speech framework directly", category: "STT Mode")
                  self.startExtensionTranscriptMonitoring()
                } else {
                  self.logToFlutter("Using RAW AUDIO STT (fallback file-based method)", category: "STT Mode")
                  self.logToFlutter("⚠️ Less reliable - audio chunks passed to main app for transcription", category: "STT Mode")
                  self.startRawAudioRecording()
                }
              } else {
                // Fallback to raw audio
                self.startRawAudioRecording()
              }
            }
          }
        }
      }
    }
  }

  /// Reconfigure audio session to work alongside broadcast extension
  private func reconfigureAudioSessionForSpeech() {
    // Run on background thread to avoid blocking main thread
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let audioSession = AVAudioSession.sharedInstance()

        // Configure with duckOthers to allow TTS to play in background over other audio
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers, .duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        print("🎤 [Audio] Audio session reconfigured for speech recognition (with duckOthers)")
      } catch {
        print("🎤 [Audio] Error reconfiguring audio session: \(error.localizedDescription)")
      }
    }
  }
  
  private func configureAudioSessionForTTS() {
    guard !isTransitioningAudioSession else { return }
    isTransitioningAudioSession = true
    
    let audioSession = AVAudioSession.sharedInstance()
    do {
      // Deactivate first, then activate with new category
      try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      // Use playback category for TTS (allows mixing with other audio)
      try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
      try audioSession.setActive(true)
      print("🔊 [Audio] Audio session configured for TTS")
    } catch {
      print("❌ [Audio] Failed to configure for TTS: \(error)")
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.isTransitioningAudioSession = false
    }
  }
  
  private func configureAudioSessionForSTT() {
    guard !isTransitioningAudioSession else { return }
    isTransitioningAudioSession = true
    
    let audioSession = AVAudioSession.sharedInstance()
    do {
      // Deactivate first, then activate with new category
      try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
      // Use playAndRecord for STT
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
      try audioSession.setActive(true)
      print("🎤 [Audio] Audio session configured for STT")
    } catch {
      print("❌ [Audio] Failed to configure for STT: \(error)")
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.isTransitioningAudioSession = false
    }
  }

  // MARK: - Speech Recognition Methods

  private func checkSpeechPermission(result: @escaping FlutterResult) {
    let status = SFSpeechRecognizer.authorizationStatus()
    switch status {
    case .authorized:
      result("granted")
    case .denied, .restricted:
      result("denied")
    case .notDetermined:
      result("notDetermined")
    @unknown default:
      result("notDetermined")
    }
  }

  private func requestSpeechPermission(result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        switch status {
        case .authorized:
          result("granted")
        case .denied, .restricted:
          result("denied")
        case .notDetermined:
          result("notDetermined")
        @unknown default:
          result("notDetermined")
        }
      }
    }
  }

  private func startSpeechRecognition(languageCode: String, result: @escaping FlutterResult) {
    // Save language code for potential restart
    currentLanguageCode = languageCode

    // Mark that user wants to be listening
    shouldBeListening = true

    // If we're in broadcast mode, check if extension STT is active
    if useRawAudioSTT && isBroadcastExtensionActive() {
      // Set language code in shared UserDefaults for extension to use
      if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
        userDefaults.set(languageCode, forKey: "speechLanguageCode")
        userDefaults.synchronize()
      }
      
      // Check if extension STT is active (extension handles STT directly)
      if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
        let extensionSTTActive = userDefaults.bool(forKey: "extensionSTTActive")
        if extensionSTTActive {
          logToFlutter("Extension is handling STT - monitoring for transcripts", category: "ExtensionSTT")
          startExtensionTranscriptMonitoring()
          result(true)
          return
        }
      }
      
      // Fallback to file-based audio chunk processing
      logToFlutter("Starting raw audio STT (broadcast mode active, extension STT not available)", category: "RawAudio")
      startRawAudioRecording()
      result(true)
      return
    }

    // Create or update speech recognizer with the specified language
    let locale = Locale(identifier: languageCode)
    let newRecognizer = SFSpeechRecognizer(locale: locale)

    logToFlutter("Starting speech recognition with language: \(languageCode)", category: "Speech")
    
    guard let recognizer = newRecognizer, recognizer.isAvailable else {
      logToFlutter("Speech recognition not available for language: \(languageCode)", category: "Speech")
      result(FlutterError(code: "SPEECH_UNAVAILABLE",
                         message: "Speech recognition is not available for language: \(languageCode)",
                         details: nil))
      return
    }

    guard audioEngine != nil else {
      result(FlutterError(code: "AUDIO_ENGINE_ERROR",
                         message: "Audio engine is not available",
                         details: nil))
      return
    }

    // If already listening, stop first to restart with new language
    if isListening {
      logToFlutter("Stopping current recognition to restart with new language", category: "Speech")
      stopAudioEngine()
      recognitionTask?.cancel()
      recognitionTask = nil
      recognitionRequest = nil
      isListening = false
    }

    // Update speech recognizer with new language
    speechRecognizer = recognizer

    // Configure audio session with retry logic for background recovery
    do {
      let audioSession = AVAudioSession.sharedInstance()

      // First try to deactivate to reset any interrupted state
      try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

      // Use playAndRecord to allow both TTS and speech recognition
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      // Retry once after a brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        do {
          let audioSession = AVAudioSession.sharedInstance()
          try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
          try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
          // Continue with recognition setup after retry
          self?.continueRecognitionSetup(languageCode: languageCode, result: result)
        } catch {
          result(FlutterError(code: "AUDIO_SESSION_ERROR",
                             message: "Failed to configure audio session: \(error.localizedDescription)",
                             details: nil))
        }
      }
      return
    }

    // Continue with recognition setup
    continueRecognitionSetup(languageCode: languageCode, result: result)
  }

  private func continueRecognitionSetup(languageCode: String, result: @escaping FlutterResult) {
    guard let engine = audioEngine, let recognizer = speechRecognizer else {
      result(FlutterError(code: "SETUP_ERROR", message: "Audio engine or recognizer not available", details: nil))
      return
    }

    // Create recognition request
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let request = recognitionRequest else {
      result(FlutterError(code: "REQUEST_ERROR",
                         message: "Failed to create recognition request",
                         details: nil))
      return
    }

    request.shouldReportPartialResults = true

    // Start recognition task
    // Each new recognition task starts fresh, so currentTranscript will only contain
    // words spoken since this task started.
    lastTranscriptLength = 0
    currentTranscript = ""
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
      guard let self = self else { return }

      if let recognitionResult = recognitionResult {
        // The recognition task starts fresh, so this only contains new words
        self.currentTranscript = recognitionResult.bestTranscription.formattedString

        // Check if transcript has new content (speech detected)
        let newLength = self.currentTranscript.count
        if newLength > self.lastTranscriptLength {
          self.lastTranscriptLength = newLength
          self.resetSilenceTimer()
        }

        // If this is the final result, we have the complete transcription for this segment
        if recognitionResult.isFinal {
          // Final result received - this is the complete transcription for this listening session
        }
      }

      if let error = error {
        // If there's an error, stop the audio engine
        self.stopAudioEngine()

        let errorCode = (error as NSError).code
        // Error codes: 203 = no speech detected (normal end), 216 = cancelled, 1110 = audio engine error

        // Only log and retry for actual errors, not normal endings
        if errorCode != 203 && errorCode != 216 {
          print("🎤 [Speech] Recognition error: \(error.localizedDescription)")

          // Notify Flutter that recognition stopped so it can restart
          if let sink = self.speechEventSink {
            DispatchQueue.main.async {
              sink(["event": "recognitionStopped", "error": error.localizedDescription])
            }
          }

          // Auto-retry after 500ms for audio errors (not cancellation or normal end)
          // Only retry if user still wants to be listening
          if self.shouldBeListening {
            print("🎤 [Speech] Will auto-retry in 500ms...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
              guard let self = self, !self.isListening, self.shouldBeListening else { return }

              // If app is in background, use raw audio recording fallback
              if !self.isAppInForeground {
                print("🎤 [Speech] App in background - switching to raw audio recording")
                self.startRawAudioRecording()
              } else {
                print("🎤 [Speech] Auto-retrying speech recognition...")
                self.startFreshRecognition()
              }
            }
          }
        }
      }
    }

    // Install tap on audio input
    let inputNode = engine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
      guard let self = self else { return }

      // Send audio buffer to speech recognizer
      self.recognitionRequest?.append(buffer)

      // Calculate and send audio level
      let level = self.calculateAudioLevel(buffer: buffer)
      DispatchQueue.main.async {
        self.audioLevelEventSink?(level)
      }
    }

    // Start audio engine
    do {
      engine.prepare()
      try engine.start()
      isListening = true
      result(true)
    } catch {
      result(FlutterError(code: "ENGINE_START_ERROR",
                         message: "Failed to start audio engine: \(error.localizedDescription)",
                         details: nil))
    }
  }

  private func stopSpeechRecognition(result: @escaping FlutterResult) {
    // Mark that user no longer wants to be listening
    shouldBeListening = false

    // Stop extension transcript monitoring if active
    stopExtensionTranscriptMonitoring()

    // First, finalize the current recognition task to get the final transcription
    recognitionRequest?.endAudio()

    // Wait a moment for the recognition task to process the final audio
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self = self else {
        result("")
        return
      }

      // Get the current transcript (this is just for this segment since we restart on pause)
      let transcript = self.currentTranscript.trimmingCharacters(in: .whitespaces)

      // Now stop the audio engine and reset
      self.stopAudioEngine()
      self.currentTranscript = ""
      self.lastTranscriptLength = 0

      result(transcript)
    }
  }

  private func endChat(result: @escaping FlutterResult) {
    // Mark that user no longer wants to be listening
    shouldBeListening = false

    // Stop TTS if speaking (immediate stop for privacy)
    if let synthesizer = speechSynthesizer, synthesizer.isSpeaking {
      print("🔊 [TTS] Stopping TTS playback on end chat")
      synthesizer.stopSpeaking(at: .immediate)
    }

    // Stop extension transcript monitoring if active
    stopExtensionTranscriptMonitoring()

    // Stop raw audio recording if active
    if isRecordingRawAudio {
      print("🎙️ [RawAudio] Stopping raw audio recording on end chat")
      rawAudioSilenceTimer?.invalidate()
      rawAudioSilenceTimer = nil
      rawAudioSilenceEndTimer?.invalidate()
      rawAudioSilenceEndTimer = nil
      audioRecorder?.stop()
      isRecordingRawAudio = false
      rawAudioURL = nil
    }

    // Stop broadcast audio monitoring if active
    broadcastAudioMonitorTimer?.invalidate()
    broadcastAudioMonitorTimer = nil

    // First, finalize the current recognition task to get the final transcription
    recognitionRequest?.endAudio()

    // Wait a moment for the recognition task to process the final audio
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self = self else {
        result("")
        return
      }

      // Get the current transcript (this is just for this segment since we restart on pause)
      let mainAppTranscript = self.currentTranscript.trimmingCharacters(in: .whitespaces)
      
      // Debug: Log STT cache information
      self.logSTTCacheDebug(mainAppTranscript: mainAppTranscript)

      // Now stop the audio engine and reset
      self.stopAudioEngine()
      self.currentTranscript = ""
      self.lastTranscriptLength = 0

      // Deactivate audio session to release all audio resources
      // This ensures no audio sessions remain active after ending chat
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        do {
          let audioSession = AVAudioSession.sharedInstance()
          try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
          print("🔇 [Audio] Audio session deactivated on end chat")
        } catch {
          print("⚠️ [Audio] Error deactivating audio session: \(error.localizedDescription)")
        }
      }

      result(mainAppTranscript)
    }
  }
  
  /// Log STT cache debug information when ending session
  private func logSTTCacheDebug(mainAppTranscript: String) {
    logToFlutter("=== STT Cache Debug (Session End) ===", category: "Debug")
    logToFlutter("Main App STT Cache: '\(mainAppTranscript.isEmpty ? "(empty)" : mainAppTranscript)'", category: "Debug")
    
    // Check if broadcast extension is active
    if isBroadcastExtensionActive() {
      logToFlutter("Broadcast extension is ACTIVE", category: "Debug")
      
      // Check for extension STT transcript
      if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
        userDefaults.synchronize()
        
        // Get latest extension transcript
        if let extensionTranscript = userDefaults.string(forKey: "extensionTranscript"), !extensionTranscript.isEmpty {
          let transcriptTime = userDefaults.double(forKey: "extensionTranscriptTime")
          let timeString = Date(timeIntervalSince1970: transcriptTime).description
          logToFlutter("Extension STT Latest Transcript: '\(extensionTranscript)' (saved at: \(timeString))", category: "Debug")
        } else {
          logToFlutter("Extension STT Latest Transcript: (none)", category: "Debug")
        }
        
        // Check extension STT status
        let extensionSTTActive = userDefaults.bool(forKey: "extensionSTTActive")
        logToFlutter("Extension STT Active: \(extensionSTTActive)", category: "Debug")
        
        // Process any pending audio chunks
        processPendingAudioChunksForDebug()
      }
    } else {
      logToFlutter("Broadcast extension is NOT active", category: "Debug")
    }
    
    logToFlutter("=== End STT Cache Debug ===", category: "Debug")
  }
  
  /// Process and transcribe any pending audio chunks from extension for debug
  private func processPendingAudioChunksForDebug() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      logToFlutter("Could not access App Group container for audio chunks", category: "Debug")
      return
    }

    let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDirectory.path) else {
      logToFlutter("No audio directory found or could not read", category: "Debug")
      return
    }

    // Get all PCM files, sorted by name (which includes timestamp)
    let audioFiles = files.filter { $0.hasSuffix(".pcm") }.sorted()

    if audioFiles.isEmpty {
      logToFlutter("No pending audio chunks found", category: "Debug")
      return
    }

    logToFlutter("Found \(audioFiles.count) pending audio chunks", category: "Debug")

    // Aggregate all audio data
    var aggregatedData = Data()
    for filename in audioFiles {
      let fileURL = audioDirectory.appendingPathComponent(filename)
      if let chunkData = try? Data(contentsOf: fileURL) {
        aggregatedData.append(chunkData)
        logToFlutter("  - \(filename): \(chunkData.count) bytes", category: "Debug")
      }
    }

    guard !aggregatedData.isEmpty else {
      logToFlutter("Aggregated audio data is empty", category: "Debug")
      return
    }

    logToFlutter("Total aggregated audio: \(aggregatedData.count) bytes", category: "Debug")

    // Convert PCM to WAV and save to file for transcription
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let wavURL = documentsPath.appendingPathComponent("debug_audio_\(timestamp).wav")

    // Write WAV file with header
    if writeWAVFile(pcmData: aggregatedData, to: wavURL) {
      logToFlutter("Created WAV file for transcription: \(wavURL.lastPathComponent)", category: "Debug")
      
      // Transcribe the audio
      transcribeDebugAudio(url: wavURL)
    } else {
      logToFlutter("Failed to create WAV file for transcription", category: "Debug")
    }
  }
  
  /// Transcribe audio file for debug purposes
  private func transcribeDebugAudio(url: URL) {
    logToFlutter("Transcribing debug audio file: \(url.lastPathComponent)", category: "Debug")

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguageCode)) else {
      logToFlutter("Speech recognizer not available for \(currentLanguageCode)", category: "Debug")
      return
    }

    guard recognizer.isAvailable else {
      logToFlutter("Speech recognizer not available", category: "Debug")
      return
    }

    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }

      if let error = error {
        self.logToFlutter("Debug audio transcription error: \(error.localizedDescription)", category: "Debug")
        self.cleanupRawAudioFile(url: url)
        return
      }

      guard let result = result, result.isFinal else { return }

      let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespaces)

      if transcript.isEmpty {
        self.logToFlutter("Debug audio transcription was empty", category: "Debug")
      } else {
        self.logToFlutter("Debug Audio Transcription Result: '\(transcript)'", category: "Debug")

        // Send transcription to Flutter as a segment complete event
        if let sink = self.speechEventSink {
          DispatchQueue.main.async {
            self.logToFlutter("Sending segmentComplete event to Flutter with debug audio transcript", category: "Debug")
            sink(["event": "segmentComplete", "text": transcript, "source": "debugAudio"])
          }
        } else {
          self.logToFlutter("⚠️ speechEventSink is nil - cannot send debug audio transcript to Flutter!", category: "Debug")
        }
      }

      self.cleanupRawAudioFile(url: url)
    }
  }

  private func stopAudioEngine() {
    guard let engine = audioEngine else { return }

    // Cancel silence timer
    cancelSilenceTimer()

    if engine.isRunning {
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
    }

    recognitionRequest?.endAudio()
    recognitionRequest = nil
    recognitionTask?.cancel()
    recognitionTask = nil
    isListening = false

    // Send zero level when stopped
    DispatchQueue.main.async { [weak self] in
      self?.audioLevelEventSink?(0.0)
    }
  }

  private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData else { return 0.0 }

    let channelDataValue = channelData.pointee
    let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }

    let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
    let avgPower = 20 * log10(rms)

    // Normalize to 0.0 - 1.0 range
    // -160 dB is silence, 0 dB is max
    let minDb: Float = -60
    let maxDb: Float = 0
    let normalizedLevel = max(0, min(1, (avgPower - minDb) / (maxDb - minDb)))

    return normalizedLevel
  }

  // MARK: - Silence Detection Methods

  private func resetSilenceTimer() {
    // Capture the current transcript value before dispatching to main thread
    let transcript = self.currentTranscript

    // Must run on main thread for timer to work
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      // Cancel existing timer
      self.silenceTimer?.invalidate()

      // Only start timer if we have content to save
      guard !transcript.isEmpty else { return }

      // Start new timer on main run loop
      self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceThreshold, repeats: false) { [weak self] _ in
        self?.onSilenceDetected()
      }
    }
  }

  private func onSilenceDetected() {
    // Only trigger if we have content and are listening
    guard isListening, !currentTranscript.isEmpty else { return }

    let segment = currentTranscript.trimmingCharacters(in: .whitespaces)
    guard !segment.isEmpty else { return }

    // Notify Flutter that a segment is complete
    if let sink = speechEventSink {
      DispatchQueue.main.async {
        sink(["event": "segmentComplete", "text": segment])
      }
    }

    // Fully stop and restart recognition
    fullyRestartRecognition()
  }

  private func fullyRestartRecognition() {
    // Fully stop everything
    guard let engine = audioEngine else { return }

    // Cancel silence timer first
    cancelSilenceTimer()

    // Cancel any pending recognition
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionRequest = nil
    recognitionTask = nil

    // Stop and remove tap only if running
    if engine.isRunning {
      engine.stop()
    }
    engine.inputNode.removeTap(onBus: 0)

    // Clear transcript for fresh start
    currentTranscript = ""
    lastTranscriptLength = 0

    // Small delay to ensure clean restart
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
      guard let self = self else { return }
      self.startFreshRecognition()
    }
  }

  private func startFreshRecognition() {
    guard let engine = audioEngine else {
      isListening = false
      return
    }

    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
      isListening = false
      return
    }

    // Configure audio session for STT
    configureAudioSessionForSTT()

    // Create new recognition request
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let request = recognitionRequest else {
      print("startFreshRecognition: failed to create request")
      isListening = false
      return
    }
    request.shouldReportPartialResults = true

    // Start new recognition task
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
      guard let self = self else { return }

      if let recognitionResult = recognitionResult {
        self.currentTranscript = recognitionResult.bestTranscription.formattedString

        let newLength = self.currentTranscript.count
        if newLength > self.lastTranscriptLength {
          self.lastTranscriptLength = newLength
          self.resetSilenceTimer()
        }
      }

      if error != nil {
        // Ignore expected errors during restart (cancellation 216, end of utterance 203)
      }
    }

    // Install tap on audio input
    let inputNode = engine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
      guard let self = self else { return }

      // Send audio buffer to speech recognizer
      self.recognitionRequest?.append(buffer)

      // Calculate and send audio level
      let level = self.calculateAudioLevel(buffer: buffer)
      DispatchQueue.main.async {
        self.audioLevelEventSink?(level)
      }
    }

    // Start audio engine
    do {
      engine.prepare()
      try engine.start()
      isListening = true
      print("🎤 [Speech] Recognition started successfully")
    } catch {
      isListening = false
      print("🎤 [Speech] Failed to start audio engine: \(error.localizedDescription)")

      // Notify Flutter that recognition stopped unexpectedly
      if let sink = speechEventSink {
        DispatchQueue.main.async {
          sink(["event": "recognitionStopped", "error": error.localizedDescription])
        }
      }

      // Auto-retry after 500ms only if user still wants to be listening
      if shouldBeListening {
        print("🎤 [Speech] Will auto-retry in 500ms...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
          guard let self = self, !self.isListening, self.shouldBeListening else { return }

          // If app is in background, use raw audio recording fallback
          if !self.isAppInForeground {
            print("🎤 [Speech] App in background - switching to raw audio recording")
            self.startRawAudioRecording()
          } else {
            print("🎤 [Speech] Auto-retrying speech recognition...")
            self.startFreshRecognition()
          }
        }
      }
    }
  }

  private func cancelSilenceTimer() {
    silenceTimer?.invalidate()
    silenceTimer = nil
  }

  // MARK: - App Lifecycle Methods

  @objc private func appDidBecomeActive() {
    print("📱 [AppLifecycle] App became active (foreground)")
    isAppInForeground = true

    // Stop background Gemini polling if it was running
    stopBackgroundGeminiPolling()
    endBackgroundBaiduTask()

    // DON'T clear geminiRequestPending here - let Dart's _checkBackgroundGeminiResponse() read it first
    // The timestamp-based deduplication (lastProcessedRequestTime) prevents re-processing
    print("🤖 [BackgroundGemini] App foregrounded - Dart will check for pending responses")
    
    // Check for timeout and retry
    checkForGeminiTimeout()

    // If we were recording raw audio with AVAudioRecorder, stop and transcribe it
    if isRecordingRawAudio && audioRecorder != nil {
      stopRawAudioAndTranscribe()
    }

    // If in broadcast mode, check for extension STT or accumulated audio chunks
    if useRawAudioSTT && isBroadcastExtensionActive() {
      print("🎙️ [BroadcastSTT] App returned to foreground - checking STT status")

      // Check if extension STT is active
      if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
        userDefaults.synchronize()
        let extensionSTTActive = userDefaults.bool(forKey: "extensionSTTActive")
        
        if extensionSTTActive {
          // Extension is handling STT - restart transcript monitoring
          if extensionTranscriptMonitorTimer == nil {
            startExtensionTranscriptMonitoring()
          }
        } else {
          // Fallback to file-based audio chunks
          if broadcastAudioMonitorTimer == nil {
            startBroadcastAudioMonitoring()
          }
          
          // Process any chunks that accumulated while in background
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.processAccumulatedBroadcastAudio()
          }
        }
      }
    }
  }

  /// Process any audio chunks that accumulated while app was in background
  private func processAccumulatedBroadcastAudio() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      return
    }

    let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDirectory.path) else {
      return
    }

    let audioFiles = files.filter { $0.hasSuffix(".pcm") }

    if audioFiles.count > 0 {
      print("🎙️ [BroadcastAudio] Found \(audioFiles.count) accumulated chunks from background - processing")
      aggregateAndTranscribeAudioChunks()
    }
  }

  @objc private func appWillResignActive() {
    print("📱 [AppLifecycle] App will resign active (background)")
    isAppInForeground = false

    // Start background task to poll for Gemini requests from broadcast extension
    if isBroadcastExtensionActive() {
      print("🤖 [BackgroundGemini] Broadcast active - starting background polling for Gemini request...")
      startBackgroundGeminiPolling()
    } else {
      print("📱 [AppLifecycle] No broadcast active - skipping background Gemini polling")
    }
  }

  private var geminiPollingTimer: Timer?

  private func startBackgroundGeminiPolling() {
    // Record the timestamp when polling starts - we'll only process requests newer than this
    let pollingStartTime = Date().timeIntervalSince1970

    // DON'T clear flags here - the extension may have just set them
    // Instead, we'll use timestamp comparison to detect stale vs new requests
    print("🤖 [BackgroundGemini] Starting polling (will process requests after \(pollingStartTime))")

    // Start background task
    backgroundBaiduTask = UIApplication.shared.beginBackgroundTask(withName: "BaiduAPICall") { [weak self] in
      print("🤖 [BackgroundBaidu] Background task expiring - stopping polling")
      self?.stopBackgroundGeminiPolling()
      self?.endBackgroundBaiduTask()
    }

    print("🤖 [BackgroundGemini] Background task started - polling for pending request (every 500ms)")

    // Poll every 500ms for a pending request
    geminiPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self = self else { return }

      guard let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else { return }
      userDefaults.synchronize()

      let isPending = userDefaults.bool(forKey: "geminiRequestPending")
      let requestTime = userDefaults.double(forKey: "geminiRequestTime")

      // Only process if pending AND newer than last processed request
      if isPending && requestTime > self.lastProcessedRequestTime {
        print("🤖 [BackgroundGemini] ✓ Detected pending request from extension (time: \(requestTime)) - processing...")
        self.stopBackgroundGeminiPolling()
        self.checkAndProcessGeminiRequest()
      }
    }
  }

  private func stopBackgroundGeminiPolling() {
    geminiPollingTimer?.invalidate()
    geminiPollingTimer = nil
  }

  // MARK: - Background Gemini Processing

  private func checkAndProcessGeminiRequest() {
    // Skip processing if app is in foreground - Flutter handles it via segmentComplete event
    guard !isAppInForeground else {
      print("🤖 [BackgroundGemini] Skipping - app is in foreground, Flutter will handle via segmentComplete")
      return
    }

    // Use serial queue for reading (ensures we see latest synchronized values)
    userDefaultsQueue.async { [weak self] in
      guard let self = self else { return }
      
      guard let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
        print("⚠️ [BackgroundGemini] Failed to access UserDefaults")
        return
      }
      userDefaults.synchronize()

      let isPending = userDefaults.bool(forKey: "geminiRequestPending")
      let requestTime = userDefaults.double(forKey: "geminiRequestTime")

      guard isPending else {
        print("🤖 [BackgroundGemini] No pending request found")
        return
      }

      // Check if this is a new request (newer than last processed)
      guard requestTime > self.lastProcessedRequestTime else {
        print("🤖 [BackgroundGemini] Request already processed (time: \(requestTime) <= \(self.lastProcessedRequestTime))")
        return
      }

      // Mark as processed immediately (atomic)
      self.lastProcessedRequestTime = requestTime
      print("🤖 [BackgroundGemini] Marked request as processed (time: \(requestTime))")

      // Get request data
      guard let transcript = userDefaults.string(forKey: "extensionTranscript"),
            let framePathsString = userDefaults.string(forKey: "geminiFramePaths"),
            let framePathsData = framePathsString.data(using: .utf8),
            let framePaths = try? JSONSerialization.jsonObject(with: framePathsData) as? [String] else {
        print("⚠️ [BackgroundGemini] Failed to read request data from UserDefaults")
        return
      }

      // Validate transcript is not empty or just whitespace
      let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTranscript.isEmpty else {
        print("⚠️ [BackgroundGemini] Empty transcript - ignoring request")
        userDefaults.set(false, forKey: "geminiRequestPending")
        userDefaults.synchronize()
        return
      }

      print("🤖 [BackgroundGemini] Transcript: \"\(trimmedTranscript.prefix(50))...\" with \(framePaths.count) frames")
      print("🤖 [BackgroundGemini] ✓ Found pending Gemini request (time: \(requestTime)) - starting background task")

      // Start background task
      self.backgroundBaiduTask = UIApplication.shared.beginBackgroundTask(withName: "BaiduAPICall") { [weak self] in
        print("🤖 [BackgroundBaidu] Background task expiring")
        self?.endBackgroundBaiduTask()
      }

      // Process on main thread
      DispatchQueue.main.async {
        self.processGeminiRequest(transcript: trimmedTranscript, framePaths: framePaths) { success in
          print("🤖 [BackgroundBaidu] Request completed - success: \(success)")
          self.endBackgroundBaiduTask()
        }
      }
    }
  }

  private func endBackgroundBaiduTask() {
    if backgroundBaiduTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundBaiduTask)
      backgroundBaiduTask = .invalid
    }
  }

  private func processGeminiRequest(transcript: String, framePaths: [String], completion: @escaping (Bool) -> Void) {
    // Set flag to prevent cleanup during processing
    isProcessingBaiduRequest = true
    defer { isProcessingBaiduRequest = false }
    
    guard baiduApiKey != nil && baiduSecretKey != nil else {
      print("⚠️ [BackgroundBaidu] No API credentials available - did you call setBroadcastContext?")
      completion(false)
      return
    }

    // Generate UUID request ID
    let requestId = UUID().uuidString
    activeRequestId = requestId
    
    // Set timeout for the entire operation (25 seconds to leave buffer)
    let operationTimeout: TimeInterval = 25.0
    var hasCompleted = false
    let completionLock = NSLock()
    
    // Timeout timer
    let timeoutTimer = Timer.scheduledTimer(withTimeInterval: operationTimeout, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      completionLock.lock()
      defer { completionLock.unlock() }
      
      if !hasCompleted {
        hasCompleted = true
        print("⚠️ [BackgroundGemini] Operation timeout after \(operationTimeout)s - saving partial state")
        
        // Check if request completed before saving timeout state
        if self.activeRequestId == requestId {
          // Save timeout state to UserDefaults for retry when app comes to foreground
          if let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) {
            userDefaults.set(true, forKey: "geminiRequestTimeout")
            userDefaults.set(transcript, forKey: "geminiTimeoutTranscript")
            userDefaults.set(Date().timeIntervalSince1970, forKey: "geminiTimeoutTime")
            // Save frame paths for retry
            if let framePathsData = try? JSONSerialization.data(withJSONObject: framePaths, options: []),
               let framePathsString = String(data: framePathsData, encoding: .utf8) {
              userDefaults.set(framePathsString, forKey: "geminiTimeoutFramePaths")
            }
            userDefaults.synchronize()
          }
        }
        
        completion(false)
      }
    }

    // Wrap completion to cancel timeout
    let wrappedCompletion: (Bool) -> Void = { [weak self] success in
      guard let self = self else { return }
      completionLock.lock()
      defer { completionLock.unlock() }
      
      if !hasCompleted {
        hasCompleted = true
        timeoutTimer.invalidate()
        if self.activeRequestId == requestId {
          self.activeRequestId = nil
        }
        completion(success)
      }
    }

    print("🤖 [BackgroundGemini] Step 1/4: Retrieving RAG context...")

    // First retrieve RAG context
    retrieveRAGContext(query: transcript) { [weak self] ragContext in
      guard let self = self else {
        print("⚠️ [BackgroundGemini] Self deallocated during RAG retrieval")
        completion(false)
        return
      }

      print("🤖 [BackgroundGemini] Step 2/4: Loading \(framePaths.suffix(10).count) frame images...")
      print("🤖 [BackgroundGemini] Total frame paths received: \(framePaths.count)")

      // Load frame images
      var imageDataArray: [Data] = []
      var loadedCount = 0
      var failedCount = 0
      for path in framePaths.suffix(10) { // Max 10 frames
        if let data = FileManager.default.contents(atPath: path) {
          imageDataArray.append(data)
          loadedCount += 1
        } else {
          print("⚠️ [BackgroundGemini] Failed to load frame at: \(path)")
          failedCount += 1
        }
      }

      if failedCount > 0 {
        print("⚠️ [BackgroundGemini] Failed to load \(failedCount)/\(framePaths.suffix(10).count) frames")
      }
      print("🤖 [BackgroundGemini] Loaded \(loadedCount) frames successfully (total bytes: \(imageDataArray.reduce(0) { $0 + $1.count }))")

      // Build augmented message with RAG context
      var augmentedMessage = transcript
      if !ragContext.isEmpty {
        let contextText = ragContext.joined(separator: "\n---\n")
        augmentedMessage = """
        Here is some relevant context from our past conversations:
        \(contextText)

        Current question/message: \(transcript)
        """
        print("🤖 [BackgroundGemini] Augmented message with \(ragContext.count) RAG context items")
      } else {
        print("🤖 [BackgroundGemini] No RAG context available - using raw transcript")
      }

      print("🤖 [BackgroundBaidu] Step 3/4: Calling Baidu API with \(self.chatHistory.count) history messages...")

      // Make Baidu API call
      self.callBaiduAPI(message: augmentedMessage, images: imageDataArray) { [weak self] response in
        guard let self = self else { return }
        // Check if this request is still active
        guard self.activeRequestId == requestId else {
          print("🤖 [BackgroundGemini] Request was superseded - ignoring response")
          wrappedCompletion(false)
          return
        }
        
        if let response = response {
          print("🤖 [BackgroundBaidu] ✓ Baidu API call successful - response length: \(response.count)")

          // Save response for Flutter to pick up
          if let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) {
            userDefaults.set(response, forKey: "geminiResponse")
            userDefaults.set(transcript, forKey: "geminiOriginalTranscript")
            userDefaults.set(true, forKey: "geminiResponseReady")
            userDefaults.set(Date().timeIntervalSince1970, forKey: "geminiResponseTime")
            userDefaults.synchronize()
            print("🤖 [BackgroundGemini] Saved response to UserDefaults for Flutter sync")
          }

          print("🤖 [BackgroundBaidu] Step 4/4: Speaking response in background...")

          // Speak the response immediately (TTS works in background)
          self.speakInBackground(text: response)

          wrappedCompletion(true)
        } else {
          print("⚠️ [BackgroundBaidu] Baidu API call failed")
          wrappedCompletion(false)
        }
      }
    }
  }

  private func retrieveRAGContext(query: String, completion: @escaping ([String]) -> Void) {
    guard let supabaseUrl = supabaseUrl,
          let supabaseKey = supabaseAnonKey,
          let apiKey = geminiApiKey else {
      print("⚠️ [BackgroundGemini] RAG skipped - missing Supabase credentials")
      completion([])
      return
    }

    print("🤖 [BackgroundGemini] Generating embedding for RAG query...")

    // First generate embedding for the query
    generateEmbedding(text: query, apiKey: apiKey) { [weak self] embedding in
      guard let self = self, let embedding = embedding else {
        print("⚠️ [BackgroundGemini] Failed to generate embedding")
        completion([])
        return
      }

      print("🤖 [BackgroundGemini] Querying Supabase for similar messages across all conversations...")

      // Query Supabase for similar messages
      let url = URL(string: "\(supabaseUrl)/rest/v1/rpc/match_message_embeddings")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

      // Build body without filter_conversation_ids to search all conversations
      var body: [String: Any] = [
        "query_embedding": embedding,
        "match_count": 5,
      ]
      // Only add filter if we want to limit to specific conversations
      // For now, we search across all conversations by omitting the filter

      request.httpBody = try? JSONSerialization.data(withJSONObject: body)

      URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
              let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
          print("🤖 [BackgroundGemini] RAG query failed: \(error?.localizedDescription ?? "unknown")")
          completion([])
          return
        }

        let contextStrings = results.compactMap { $0["chunk_text"] as? String }
        print("🤖 [BackgroundGemini] Retrieved \(contextStrings.count) RAG context items")
        completion(contextStrings)
      }.resume()
    }
  }

  private func generateEmbedding(text: String, apiKey: String, completion: @escaping ([Double]?) -> Void) {
    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=\(apiKey)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
      "model": "models/text-embedding-004",
      "content": ["parts": [["text": text]]]
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let embedding = json["embedding"] as? [String: Any],
            let values = embedding["values"] as? [Double] else {
        print("🤖 [BackgroundGemini] Embedding generation failed: \(error?.localizedDescription ?? "unknown")")
        completion(nil)
        return
      }

      completion(values)
    }.resume()
  }

  private func refreshBaiduAccessToken(completion: @escaping (String?) -> Void) {
    guard let apiKey = baiduApiKey, let secretKey = baiduSecretKey else {
      print("⚠️ [BackgroundBaidu] Missing API credentials")
      completion(nil)
      return
    }
    
    let url = URL(string: "https://aip.baidubce.com/oauth/2.0/token")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    
    let bodyString = "grant_type=client_credentials&client_id=\(apiKey)&client_secret=\(secretKey)"
    request.httpBody = bodyString.data(using: .utf8)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let accessToken = json["access_token"] as? String else {
        print("⚠️ [BackgroundBaidu] Failed to get access token: \(error?.localizedDescription ?? "unknown")")
        completion(nil)
        return
      }
      
      self.baiduAccessToken = accessToken
      // Baidu tokens typically expire in 30 days, refresh after 25 days
      self.baiduTokenExpiry = Date().addingTimeInterval(25 * 24 * 60 * 60)
      print("✅ [BackgroundBaidu] Access token obtained")
      completion(accessToken)
    }.resume()
  }
  
  private func ensureValidBaiduToken(completion: @escaping (String?) -> Void) {
    if let token = baiduAccessToken,
       let expiry = baiduTokenExpiry,
       expiry > Date() {
      completion(token)
      return
    }
    
    refreshBaiduAccessToken(completion: completion)
  }

  private func callBaiduAPI(message: String, images: [Data], completion: @escaping (String?) -> Void) {
    ensureValidBaiduToken { [weak self] accessToken in
      guard let self = self, let token = accessToken else {
        completion(nil)
        return
      }
      
      let url = URL(string: "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions?access_token=\(token)")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      // Build messages array
      var messages: [[String: Any]] = []
      
      // Prepare content parts
      var contentParts: [[String: Any]] = []
      
      // Add images as base64
      for imageData in images {
        let base64 = imageData.base64EncodedString()
        contentParts.append([
          "type": "image_url",
          "image_url": [
            "url": "data:image/jpeg;base64,\(base64)"
          ]
        ])
      }
      
      // Add text content
      var textContent = message
      if !images.isEmpty {
        textContent = "The above images are screenshots from the screen in chronological order. Use them as visual context to understand what the user is looking at.\n\n\(message)"
      }
      
      contentParts.append([
        "type": "text",
        "text": textContent
      ])
      
      messages.append([
        "role": "user",
        "content": contentParts
      ])

      let body: [String: Any] = [
        "messages": messages,
        "temperature": 0.4,
        "max_output_tokens": 1024
      ]

      request.httpBody = try? JSONSerialization.data(withJSONObject: body)

      // Use URLSession with timeout configuration
      let config = URLSessionConfiguration.default
      config.timeoutIntervalForRequest = 20.0  // 20s for request
      config.timeoutIntervalForResource = 25.0  // 25s total
      let urlSession = URLSession(configuration: config)

      urlSession.dataTask(with: request) { data, response, error in
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          print("🤖 [BackgroundBaidu] API call failed: \(error?.localizedDescription ?? "unknown")")
          if let data = data, let responseStr = String(data: data, encoding: .utf8) {
            print("🤖 [BackgroundBaidu] Response: \(responseStr)")
          }
          completion(nil)
          return
        }
        
        // Handle Baidu API response format
        if let result = json["result"] as? String {
          // Log token usage if available
          if let usage = json["usage"] as? [String: Any] {
            let promptTokens = usage["prompt_tokens"] as? Int ?? 0
            let completionTokens = usage["completion_tokens"] as? Int ?? 0
            let totalTokens = usage["total_tokens"] as? Int ?? 0
            print("💰 [Token Usage] Prompt: \(promptTokens) | Response: \(completionTokens) | Total: \(totalTokens) | Images: \(images.count)")
          }
          
          print("🤖 [BackgroundBaidu] Got response: \(result.prefix(100))...")
          completion(result)
        } else if let errorCode = json["error_code"] as? Int {
          let errorMsg = json["error_msg"] as? String ?? "Unknown error"
          print("🤖 [BackgroundBaidu] API error: \(errorCode) - \(errorMsg)")
          
          // Handle token expiry - retry with new token
          if errorCode == 110 || errorCode == 111 {
            self.refreshBaiduAccessToken { newToken in
              if newToken != nil {
                self.callBaiduAPI(message: message, images: images, completion: completion)
              } else {
                completion(nil)
              }
            }
          } else {
            completion(nil)
          }
        } else {
          print("🤖 [BackgroundBaidu] Unexpected response format")
          completion(nil)
        }
      }.resume()
    }
  }

  private func checkForGeminiTimeout() {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
    userDefaults.synchronize()
    
    if userDefaults.bool(forKey: "geminiRequestTimeout") {
      print("⚠️ [BackgroundGemini] Found timeout from background - retrying...")
      guard let transcript = userDefaults.string(forKey: "geminiTimeoutTranscript"),
            let framePathsString = userDefaults.string(forKey: "geminiTimeoutFramePaths"),
            let framePathsData = framePathsString.data(using: .utf8),
            let framePaths = try? JSONSerialization.jsonObject(with: framePathsData) as? [String] else {
        print("⚠️ [BackgroundGemini] Failed to read timeout data")
        // Clear timeout flags even if data is invalid
        userDefaults.set(false, forKey: "geminiRequestTimeout")
        userDefaults.removeObject(forKey: "geminiTimeoutTranscript")
        userDefaults.removeObject(forKey: "geminiTimeoutFramePaths")
        userDefaults.synchronize()
        return
      }
      
      // Validate frame paths still exist before retry
      let validFramePaths = framePaths.filter { FileManager.default.fileExists(atPath: $0) }
      if validFramePaths.isEmpty {
        print("⚠️ [BackgroundGemini] All frames deleted - cannot retry")
        // Clear timeout flags
        userDefaults.set(false, forKey: "geminiRequestTimeout")
        userDefaults.removeObject(forKey: "geminiTimeoutTranscript")
        userDefaults.removeObject(forKey: "geminiTimeoutFramePaths")
        userDefaults.synchronize()
        return
      }
      
      print("🤖 [BackgroundGemini] Retrying with \(validFramePaths.count) valid frames (was \(framePaths.count))")
      
      // Clear timeout flags
      userDefaults.set(false, forKey: "geminiRequestTimeout")
      userDefaults.removeObject(forKey: "geminiTimeoutTranscript")
      userDefaults.removeObject(forKey: "geminiTimeoutFramePaths")
      userDefaults.synchronize()
      
      // Retry the request (now in foreground with more time)
      processGeminiRequest(transcript: transcript, framePaths: validFramePaths) { success in
        print("🔄 [BackgroundGemini] Retry result: \(success)")
      }
    }
  }

  private func speakInBackground(text: String) {
    guard let synthesizer = speechSynthesizer else {
      print("🔊 [BackgroundTTS] No speech synthesizer available")
      return
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: currentLanguageCode)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
    utterance.pitchMultiplier = 1.0
    utterance.volume = 1.0

    synthesizer.speak(utterance)
    print("🔊 [BackgroundTTS] Speaking response in background")
  }

  private func checkGeminiResponse(result: @escaping FlutterResult) {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      result(nil)
      return
    }
    userDefaults.synchronize()

    let isReady = userDefaults.bool(forKey: "geminiResponseReady")
    if isReady {
      let response: [String: Any?] = [
        "response": userDefaults.string(forKey: "geminiResponse"),
        "transcript": userDefaults.string(forKey: "geminiOriginalTranscript"),
        "timestamp": userDefaults.double(forKey: "geminiResponseTime")
      ]
      result(response)
    } else {
      result(nil)
    }
  }

  private func clearGeminiResponse(result: @escaping FlutterResult) {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      result(false)
      return
    }

    // Clear response data
    userDefaults.removeObject(forKey: "geminiResponse")
    userDefaults.removeObject(forKey: "geminiOriginalTranscript")
    userDefaults.removeObject(forKey: "geminiResponseReady")
    userDefaults.removeObject(forKey: "geminiResponseTime")

    // Also clear the request pending flag and data now that Dart has processed it
    userDefaults.set(false, forKey: "geminiRequestPending")
    userDefaults.removeObject(forKey: "extensionTranscript")
    userDefaults.removeObject(forKey: "geminiFramePaths")
    userDefaults.synchronize()

    print("🤖 [BackgroundGemini] Cleared all response and request data after Dart processing")

    result(true)
  }

  // MARK: - Raw Audio Recording Methods

  private func startRawAudioRecording() {
    // If in broadcast mode, don't use AVAudioRecorder - use chunks from extension instead
    if useRawAudioSTT && isBroadcastExtensionActive() {
      print("🎙️ [RawAudio] Using broadcast extension audio chunks (not AVAudioRecorder)")
      isRecordingRawAudio = true
      // Start monitoring for silence detection from extension
      startBroadcastAudioMonitoring()
      return
    }

    guard !isRecordingRawAudio else {
      print("🎙️ [RawAudio] Already recording raw audio")
      return
    }

    print("🎙️ [RawAudio] Starting raw audio recording (background fallback)")

    // Create URL for raw audio file
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    rawAudioURL = documentsPath.appendingPathComponent("raw_audio_\(timestamp).m4a")

    guard let audioURL = rawAudioURL else {
      print("🎙️ [RawAudio] Failed to create audio URL")
      return
    }

    // Configure audio session - use mixWithOthers to work alongside broadcast extension
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      print("🎙️ [RawAudio] Audio session error: \(error.localizedDescription)")
      return
    }

    // Recording settings
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    do {
      audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
      audioRecorder?.isMeteringEnabled = true
      audioRecorder?.record()
      isRecordingRawAudio = true

      // Start monitoring audio levels for silence detection
      startRawAudioSilenceMonitoring()

      print("🎙️ [RawAudio] Recording started at: \(audioURL.path)")
    } catch {
      print("🎙️ [RawAudio] Failed to start recording: \(error.localizedDescription)")
    }
  }

  private func startRawAudioSilenceMonitoring() {
    // Start the initial silence end timer (in case user doesn't speak at all)
    resetRawAudioSilenceEndTimer()

    // Monitor audio levels every 100ms
    rawAudioSilenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }

      recorder.updateMeters()
      let averagePower = recorder.averagePower(forChannel: 0)

      // Convert dB to normalized level (0-1)
      let normalizedLevel = max(0, min(1, (averagePower + 60) / 60))

      // Check for silence (below threshold)
      let silenceThreshold: Float = 0.05
      if normalizedLevel >= silenceThreshold {
        // Sound detected - reset the silence end timer
        self.lastAudioLevel = normalizedLevel
        self.resetRawAudioSilenceEndTimer()
      } else {
        // Silence detected - timer continues running
        self.lastAudioLevel = normalizedLevel
      }
    }
  }

  private var rawAudioSilenceEndTimer: Timer?

  private func resetRawAudioSilenceEndTimer() {
    rawAudioSilenceEndTimer?.invalidate()
    rawAudioSilenceEndTimer = Timer.scheduledTimer(withTimeInterval: rawAudioSilenceThreshold, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      // Silence detected for threshold duration, stop and transcribe
      print("🎙️ [RawAudio] Silence detected, stopping and transcribing")
      self.stopRawAudioAndTranscribe()
    }
  }

  private func stopRawAudioAndTranscribe() {
    guard isRecordingRawAudio, let recorder = audioRecorder else { return }

    print("🎙️ [RawAudio] Stopping raw audio recording")

    // Stop monitoring
    rawAudioSilenceTimer?.invalidate()
    rawAudioSilenceTimer = nil
    rawAudioSilenceEndTimer?.invalidate()
    rawAudioSilenceEndTimer = nil

    // Stop recording
    recorder.stop()
    isRecordingRawAudio = false

    // Transcribe the recorded audio
    guard let audioURL = rawAudioURL else {
      print("🎙️ [RawAudio] No audio URL to transcribe")
      return
    }

    transcribeRawAudio(url: audioURL)
  }

  private func transcribeRawAudio(url: URL) {
    print("🎙️ [RawAudio] Transcribing audio file: \(url.lastPathComponent)")

    // Create speech recognizer with current language
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguageCode)) else {
      print("🎙️ [RawAudio] Speech recognizer not available for \(currentLanguageCode)")
      cleanupRawAudioFile(url: url)
      return
    }

    guard recognizer.isAvailable else {
      print("🎙️ [RawAudio] Speech recognizer not available")
      cleanupRawAudioFile(url: url)
      return
    }

    // Create recognition request from audio file
    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    // Perform transcription
    recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }

      if let error = error {
        print("🎙️ [RawAudio] Transcription error: \(error.localizedDescription)")
        self.cleanupRawAudioFile(url: url)

        // Still restart recording if in broadcast mode
        if self.shouldBeListening && self.useRawAudioSTT {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🎙️ [RawAudio] Restarting raw audio recording after error")
            self.startRawAudioRecording()
          }
        }
        return
      }

      guard let result = result, result.isFinal else { return }

      let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespaces)

      if transcript.isEmpty {
        print("🎙️ [RawAudio] Transcription was empty")
        self.cleanupRawAudioFile(url: url)

        // Still restart recording if in broadcast mode
        if self.shouldBeListening && self.useRawAudioSTT {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🎙️ [RawAudio] Restarting raw audio recording after empty transcription")
            self.startRawAudioRecording()
          }
        }
        return
      }

      print("🎙️ [RawAudio] Transcribed: \(transcript)")

      // Send transcription to Flutter as a segment complete event
      if let sink = self.speechEventSink {
        DispatchQueue.main.async {
          sink(["event": "segmentComplete", "text": transcript, "source": "rawAudio"])
        }
      }

      // Clean up audio file
      self.cleanupRawAudioFile(url: url)

      // If user still wants to be listening, restart appropriate STT method
      if self.shouldBeListening {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          // If in broadcast mode, continue with raw audio recording
          if self.useRawAudioSTT {
            print("🎙️ [RawAudio] Restarting raw audio recording (broadcast mode)")
            self.startRawAudioRecording()
          } else if self.isAppInForeground {
            // Otherwise restart normal speech recognition if in foreground
            self.startFreshRecognition()
          }
        }
      }
    }
  }

  private func cleanupRawAudioFile(url: URL) {
    do {
      try FileManager.default.removeItem(at: url)
      print("🎙️ [RawAudio] Cleaned up audio file")
    } catch {
      print("🎙️ [RawAudio] Failed to cleanup audio file: \(error.localizedDescription)")
    }
    rawAudioURL = nil
  }

  // MARK: - Broadcast Extension Audio Methods

  private var broadcastAudioMonitorTimer: Timer?
  private var lastProcessedSilenceTime: TimeInterval = 0
  private var extensionTranscriptMonitorTimer: Timer?
  private var lastProcessedTranscriptTime: TimeInterval = 0

  private func startBroadcastAudioMonitoring() {
    // Don't create duplicate timers
    guard broadcastAudioMonitorTimer == nil else {
      logToFlutter("Monitor already running", category: "BroadcastAudio")
      return
    }

    logToFlutter("Starting to monitor for silence detection from extension", category: "BroadcastAudio")

    // Check for silence detection flag every 500ms
    broadcastAudioMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      // Check for extension log messages and forward them
      self.checkAndForwardExtensionLogs()
      self.checkBroadcastSilenceDetection()
    }
  }
  
  private func startExtensionTranscriptMonitoring() {
    // Don't create duplicate timers
    guard extensionTranscriptMonitorTimer == nil else {
      logToFlutter("Extension transcript monitor already running", category: "ExtensionSTT")
      return
    }
    
    logToFlutter("Starting to monitor for extension transcripts", category: "ExtensionSTT")
    
    // Stop any existing audio chunk monitoring
    stopBroadcastAudioMonitoring()
    
    // Check for new transcripts every 500ms
    extensionTranscriptMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      // Check for extension log messages and forward them
      self.checkAndForwardExtensionLogs()
      self.checkExtensionTranscript()
    }
  }
  
  private func stopExtensionTranscriptMonitoring() {
    extensionTranscriptMonitorTimer?.invalidate()
    extensionTranscriptMonitorTimer = nil
  }
  
  private func checkExtensionTranscript() {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      logToFlutter("Could not access UserDefaults for transcript check", category: "ExtensionSTT")
      return
    }
    userDefaults.synchronize()
    
    let hasNewTranscript = userDefaults.bool(forKey: "hasNewTranscript")
    let transcriptTime = userDefaults.double(forKey: "extensionTranscriptTime")
    
    // Debug: Log what we're checking
    if hasNewTranscript {
      logToFlutter("Found hasNewTranscript=true, time=\(transcriptTime), lastProcessed=\(lastProcessedTranscriptTime)", category: "ExtensionSTT")
    }
    
    // Only process if this is a new transcript
    if hasNewTranscript && transcriptTime > lastProcessedTranscriptTime {
      lastProcessedTranscriptTime = transcriptTime
      
      // Get the transcript
      guard let transcript = userDefaults.string(forKey: "extensionTranscript"), !transcript.isEmpty else {
        logToFlutter("hasNewTranscript=true but transcript is empty or nil", category: "ExtensionSTT")
        // Clear flag even if transcript is empty
        userDefaults.set(false, forKey: "hasNewTranscript")
        userDefaults.synchronize()
        return
      }
      
      // Clear the flag
      userDefaults.set(false, forKey: "hasNewTranscript")
      userDefaults.synchronize()
      
      logToFlutter("✓ Received transcript: '\(transcript)' - sending to Flutter", category: "ExtensionSTT")
      
      // Send transcription to Flutter as a segment complete event
      if let sink = speechEventSink {
        DispatchQueue.main.async {
          self.logToFlutter("Sending segmentComplete event to Flutter with transcript: '\(transcript)'", category: "ExtensionSTT")
          sink(["event": "segmentComplete", "text": transcript, "source": "extensionSTT"])
        }
      } else {
        logToFlutter("⚠️ speechEventSink is nil - cannot send transcript to Flutter!", category: "ExtensionSTT")
      }
    }
  }

  private func stopBroadcastAudioMonitoring() {
    broadcastAudioMonitorTimer?.invalidate()
    broadcastAudioMonitorTimer = nil
  }

  // Amplitude-based silence detection
  private let quietAmplitudeThreshold: Float = 0.02  // Same threshold as extension uses
  private let consecutiveQuietChunksRequired: Int = 5  // Need 5 quiet chunks to trigger
  private var lastProcessedExtensionLogTime: TimeInterval = 0
  private var lastAmplitudeBasedSilenceTime: TimeInterval = 0  // Prevent duplicate triggers
  
  /// Check for extension log messages and forward them to Flutter
  private func checkAndForwardExtensionLogs() {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
    userDefaults.synchronize()
    
    let logTime = userDefaults.double(forKey: "extensionLogTime")
    
    // Only process if this is a new log message
    if logTime > lastProcessedExtensionLogTime {
      lastProcessedExtensionLogTime = logTime
      
      if let logMessage = userDefaults.string(forKey: "extensionLogMessage"),
         let category = userDefaults.string(forKey: "extensionLogCategory") {
        logToFlutter("🎵 \(logMessage)", category: category)
      }
    }
  }

  private func checkBroadcastSilenceDetection() {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
    userDefaults.synchronize()

    // Check for amplitude-based silence detection from audio chunks
    if checkAmplitudeBasedSilence() {
      let now = Date().timeIntervalSince1970
      // Prevent duplicate triggers within 3 seconds (to avoid processing same chunks multiple times)
      if now - lastAmplitudeBasedSilenceTime > 3.0 {
        lastAmplitudeBasedSilenceTime = now
        logToFlutter("✓ Amplitude-based silence detected (5 consecutive quiet chunks) - triggering transcription", category: "BroadcastAudio")
        aggregateAndTranscribeAudioChunks()
        return
      } else {
        logToFlutter("Amplitude-based silence detected but skipping (triggered recently)", category: "BroadcastAudio")
      }
    }

    // Fallback to old silence detection flag method
    let silenceDetected = userDefaults.bool(forKey: "silenceDetected")
    let silenceTime = userDefaults.double(forKey: "silenceDetectedTime")

    // Only process if this is a new silence detection
    if silenceDetected {
      logToFlutter("Silence detected: \(silenceDetected), time: \(silenceTime), lastProcessed: \(lastProcessedSilenceTime)", category: "BroadcastAudio")
    }
    if silenceDetected && silenceTime > lastProcessedSilenceTime {
      lastProcessedSilenceTime = silenceTime

      // Clear the flag
      userDefaults.set(false, forKey: "silenceDetected")
      userDefaults.synchronize()

      logToFlutter("Silence detected - aggregating and transcribing audio chunks", category: "BroadcastAudio")
      aggregateAndTranscribeAudioChunks()
    }
  }
  
  /// Check if we have 5 consecutive audio chunks with amplitude below threshold
  private func checkAmplitudeBasedSilence() -> Bool {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      return false
    }

    let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDirectory.path) else {
      return false
    }

    // Get all PCM files, sorted by name (which includes timestamp)
    let audioFiles = files.filter { $0.hasSuffix(".pcm") }.sorted()

    // Need at least 5 chunks to check
    guard audioFiles.count >= consecutiveQuietChunksRequired else {
      return false
    }

    // Check the last 5 chunks (most recent)
    let recentChunks = Array(audioFiles.suffix(consecutiveQuietChunksRequired))
    var consecutiveQuiet = 0
    var allQuiet = true

    // Only log every 10th check to avoid spam (check runs every 500ms)
    let shouldLog = Int.random(in: 0..<10) == 0
    if shouldLog {
      logToFlutter("Checking amplitude for last \(recentChunks.count) chunks (total chunks: \(audioFiles.count)):", category: "BroadcastAudio")
    }

    for filename in recentChunks {
      // Extract amplitude from filename: audio_timestamp_seq_ampXXXXX[_silent].pcm
      let amplitude = extractAmplitudeFromFilename(filename)
      
      if shouldLog {
        logToFlutter("  Chunk: \(filename) - Amplitude: \(String(format: "%.4f", amplitude)) (threshold: \(quietAmplitudeThreshold))", category: "BroadcastAudio")
      }

      if amplitude < quietAmplitudeThreshold {
        consecutiveQuiet += 1
      } else {
        allQuiet = false
        if shouldLog {
          logToFlutter("  ✗ Chunk above threshold - breaking check", category: "BroadcastAudio")
        }
        break  // Reset if we find a non-quiet chunk
      }
    }

    if allQuiet && consecutiveQuiet >= consecutiveQuietChunksRequired {
      logToFlutter("✓✓✓ Found \(consecutiveQuiet) consecutive quiet chunks (threshold: \(quietAmplitudeThreshold)) - SILENCE DETECTED", category: "BroadcastAudio")
      return true
    } else if shouldLog {
      logToFlutter("  Only found \(consecutiveQuiet)/\(consecutiveQuietChunksRequired) quiet chunks - not enough", category: "BroadcastAudio")
    }

    return false
  }
  
  /// Extract amplitude from filename
  /// Format: audio_timestamp_seq_ampXXXXX[_silent].pcm
  private func extractAmplitudeFromFilename(_ filename: String) -> Float {
    // Look for _amp followed by digits
    if let ampRange = filename.range(of: "_amp") {
      let afterAmp = filename[ampRange.upperBound...]
      // Find where amplitude number ends (either _silent or .pcm)
      let endRange = afterAmp.range(of: "_") ?? afterAmp.range(of: ".")
      let amplitudeString = String(endRange != nil ? afterAmp[..<endRange!.lowerBound] : afterAmp)
      
      if let amplitudeInt = Int(amplitudeString) {
        // Convert back from integer (was multiplied by 10000)
        return Float(amplitudeInt) / 10000.0
      }
    }
    
    // Fallback: if we can't parse, read the file and calculate
    return calculateAmplitudeFromFile(filename: filename)
  }
  
  /// Calculate amplitude from audio file (fallback if filename parsing fails)
  private func calculateAmplitudeFromFile(filename: String) -> Float {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      return 0.0
    }

    let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)
    let fileURL = audioDirectory.appendingPathComponent(filename)

    guard let audioData = try? Data(contentsOf: fileURL) else {
      return 0.0
    }

    // Calculate RMS amplitude
    let samples = audioData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Int16] in
      let int16Pointer = pointer.bindMemory(to: Int16.self)
      return Array(int16Pointer)
    }

    guard !samples.isEmpty else { return 0.0 }

    let sum = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
    let rms = sqrt(sum / Double(samples.count))
    return Float(rms / 32767.0)
  }

  private func aggregateAndTranscribeAudioChunks() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      print("🎙️ [BroadcastAudio] Could not access App Group container")
      return
    }

    let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDirectory.path) else {
      print("🎙️ [BroadcastAudio] No audio directory found")
      return
    }

    // Get all PCM files, sorted by name (which includes timestamp)
    let audioFiles = files.filter { $0.hasSuffix(".pcm") }.sorted()

    if audioFiles.isEmpty {
      logToFlutter("No audio chunks to process", category: "BroadcastAudio")
      return
    }

    logToFlutter("Found \(audioFiles.count) audio chunks to aggregate", category: "BroadcastAudio")
    
    // Log amplitude for each chunk being aggregated
    for filename in audioFiles {
      let amplitude = extractAmplitudeFromFilename(filename)
      logToFlutter("  Aggregating: \(filename) - Amplitude: \(String(format: "%.4f", amplitude))", category: "BroadcastAudio")
    }

    // Aggregate all audio data
    var aggregatedData = Data()
    for filename in audioFiles {
      let fileURL = audioDirectory.appendingPathComponent(filename)
      if let chunkData = try? Data(contentsOf: fileURL) {
        aggregatedData.append(chunkData)
      }
    }

    guard !aggregatedData.isEmpty else {
      logToFlutter("⚠️ Aggregated data is empty", category: "BroadcastAudio")
      clearBroadcastAudioChunks()
      return
    }

    logToFlutter("✅ Aggregated \(aggregatedData.count) bytes of audio data", category: "BroadcastAudio")

    // Convert PCM to WAV and save to file for transcription
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let wavURL = documentsPath.appendingPathComponent("broadcast_audio_\(timestamp).wav")

    // Write WAV file with header
    if writeWAVFile(pcmData: aggregatedData, to: wavURL) {
      logToFlutter("✅ Written WAV file: \(wavURL.lastPathComponent)", category: "BroadcastAudio")

      // Clear audio chunks after aggregation
      clearBroadcastAudioChunks()

      // Transcribe the audio
      logToFlutter("🎤 Starting transcription of aggregated audio...", category: "BroadcastAudio")
      transcribeBroadcastAudio(url: wavURL)
    } else {
      logToFlutter("❌ Failed to write WAV file", category: "BroadcastAudio")
      clearBroadcastAudioChunks()
    }
  }

  private func writeWAVFile(pcmData: Data, to url: URL) -> Bool {
    // WAV header for 16-bit mono PCM at 44100 Hz
    let sampleRate: UInt32 = 44100
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16

    let dataSize = UInt32(pcmData.count)
    let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
    let blockAlign = channels * (bitsPerSample / 8)

    var header = Data()

    // RIFF header
    header.append(contentsOf: "RIFF".utf8)
    var chunkSize = dataSize + 36
    header.append(Data(bytes: &chunkSize, count: 4))
    header.append(contentsOf: "WAVE".utf8)

    // fmt subchunk
    header.append(contentsOf: "fmt ".utf8)
    var subchunk1Size: UInt32 = 16
    header.append(Data(bytes: &subchunk1Size, count: 4))
    var audioFormat: UInt16 = 1  // PCM
    header.append(Data(bytes: &audioFormat, count: 2))
    var numChannels = channels
    header.append(Data(bytes: &numChannels, count: 2))
    var sampleRateValue = sampleRate
    header.append(Data(bytes: &sampleRateValue, count: 4))
    var byteRateValue = byteRate
    header.append(Data(bytes: &byteRateValue, count: 4))
    var blockAlignValue = blockAlign
    header.append(Data(bytes: &blockAlignValue, count: 2))
    var bitsPerSampleValue = bitsPerSample
    header.append(Data(bytes: &bitsPerSampleValue, count: 2))

    // data subchunk
    header.append(contentsOf: "data".utf8)
    var dataSizeValue = dataSize
    header.append(Data(bytes: &dataSizeValue, count: 4))

    // Combine header and data
    var wavData = header
    wavData.append(pcmData)

    do {
      try wavData.write(to: url)
      return true
    } catch {
      print("🎙️ [BroadcastAudio] Error writing WAV file: \(error)")
      return false
    }
  }

  private func clearBroadcastAudioChunks() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
      return
    }

    let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDirectory.path) else {
      return
    }

    for filename in files.filter({ $0.hasSuffix(".pcm") }) {
      let fileURL = audioDirectory.appendingPathComponent(filename)
      try? FileManager.default.removeItem(at: fileURL)
    }

    print("🎙️ [BroadcastAudio] Cleared audio chunks from shared container")
  }

  private func transcribeBroadcastAudio(url: URL) {
    logToFlutter("🎤 Transcribing audio file: \(url.lastPathComponent)", category: "BroadcastAudio")

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguageCode)) else {
      logToFlutter("❌ Speech recognizer not available for \(currentLanguageCode)", category: "BroadcastAudio")
      cleanupRawAudioFile(url: url)
      return
    }

    guard recognizer.isAvailable else {
      logToFlutter("❌ Speech recognizer not available", category: "BroadcastAudio")
      cleanupRawAudioFile(url: url)
      return
    }

    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    logToFlutter("📝 Starting recognition task for audio file...", category: "BroadcastAudio")

    recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }

      if let error = error {
        let errorCode = (error as NSError).code
        logToFlutter("❌ Transcription error (code \(errorCode)): \(error.localizedDescription)", category: "BroadcastAudio")
        self.cleanupRawAudioFile(url: url)
        return
      }

      guard let result = result, result.isFinal else {
        if result != nil {
          logToFlutter("⏳ Partial transcription result (not final yet)", category: "BroadcastAudio")
        }
        return
      }

      let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespaces)

      if transcript.isEmpty {
        logToFlutter("⚠️ Transcription was empty", category: "BroadcastAudio")
      } else {
        logToFlutter("✅ Transcribed: '\(transcript)' - sending to Flutter", category: "BroadcastAudio")

        // Send transcription to Flutter
        if let sink = self.speechEventSink {
          DispatchQueue.main.async {
            self.logToFlutter("📤 Sending segmentComplete event to Flutter with transcript: '\(transcript)'", category: "BroadcastAudio")
            sink(["event": "segmentComplete", "text": transcript, "source": "broadcastAudio"])
          }
        } else {
          self.logToFlutter("❌ speechEventSink is nil - cannot send transcript to Flutter!", category: "BroadcastAudio")
        }
      }

      self.cleanupRawAudioFile(url: url)
    }
  }

  // MARK: - Audio Interruption Handling

  @objc private func handleAudioInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    switch type {
    case .began:
      // Audio interrupted (e.g., phone call)
      // Stop TTS if speaking
      speechSynthesizer?.stopSpeaking(at: .immediate)
      // Note: Speech recognition will automatically stop

    case .ended:
      // Interruption ended - try to resume
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

      if options.contains(.shouldResume) {
        // Reactivate audio session
        do {
          let audioSession = AVAudioSession.sharedInstance()
          try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

          // If we were listening before, notify Flutter to restart
          if isListening {
            if let sink = speechEventSink {
              DispatchQueue.main.async {
                sink(["event": "interruptionEnded"])
              }
            }
          }
        } catch {
          print("Failed to reactivate audio session after interruption: \(error)")
        }
      }

    @unknown default:
      break
    }
  }

  // Public methods for stream handlers to set event sinks
  func setAudioLevelEventSink(_ sink: FlutterEventSink?) {
    audioLevelEventSink = sink
  }

  func setSpeechEventSink(_ sink: FlutterEventSink?) {
    speechEventSink = sink
  }

  // MARK: - TTS Methods

  private func speakText(text: String, languageCode: String, slowerSpeech: Bool, voiceId: String?, result: @escaping FlutterResult) {
    guard let synthesizer = speechSynthesizer else {
      result(FlutterError(code: "TTS_UNAVAILABLE", message: "Speech synthesizer not available", details: nil))
      return
    }

    // Stop any current speech
    if synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }

    // Configure for TTS
    configureAudioSessionForTTS()

    let utterance = AVSpeechUtterance(string: text)

    // Set language and voice
    let voiceLanguage: String
    if languageCode == "zh-Hans" {
      voiceLanguage = "zh-CN"
    } else {
      voiceLanguage = "en-US"
    }

    // Select best available voice for the language
    let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == voiceLanguage }

    // Debug: Log all available voices
    print("🔊 [TTS] Available voices for \(voiceLanguage):")
    for voice in voices {
      print("  - \(voice.name) (id: \(voice.identifier), quality: \(voice.quality.rawValue))")
    }

    let selectedVoice: AVSpeechSynthesisVoice?

    // First, try to use the user-selected voice if provided
    if let voiceId = voiceId, !voiceId.isEmpty {
      selectedVoice = voices.first { $0.identifier == voiceId }
      if selectedVoice != nil {
        print("🔊 [TTS] Using user-selected voice: \(voiceId)")
      } else {
        print("⚠️ [TTS] User-selected voice not found: \(voiceId), falling back to default selection")
      }
    } else {
      selectedVoice = nil
    }

    // If no user-selected voice or it wasn't found, use automatic selection
    let finalVoice: AVSpeechSynthesisVoice?
    if selectedVoice != nil {
      finalVoice = selectedVoice
    } else if languageCode == "zh-Hans" {
      // Prefer Ting-Ting (enhanced), otherwise fall back to other enhanced Mandarin voices
      let tingTing = voices.first { voice in
        let name = voice.name.lowercased()
        return name.contains("ting-ting") && voice.quality == .enhanced
      }
      let tingTingDefault = voices.first { voice in
        voice.name.lowercased().contains("ting-ting")
      }
      let anyEnhanced = voices.first { $0.quality == .enhanced }
      finalVoice = tingTing ?? tingTingDefault ?? anyEnhanced ?? voices.first
    } else {
      // Prefer Siri Voice 4, then other Siri voices, then Samantha, then default
      let siriVoice4 = voices.first { voice in
        let id = voice.identifier.lowercased()
        let name = voice.name.lowercased()
        return id.contains("sirivoice4") ||
               (id.contains("siri") && id.contains("voice4")) ||
               name.contains("siri voice 4") ||
               name.contains("siri voice4") ||
               id.contains("com.apple.voice.compact.en-us.sirivoice4")
      }

      // Fallback to any Siri voice
      let anySiri = voices.first { voice in
        let id = voice.identifier.lowercased()
        let name = voice.name.lowercased()
        return id.contains("siri") || name.contains("siri")
      }

      // Fallback to Samantha
      let samantha = voices.first {
        let name = $0.name.lowercased()
        let id = $0.identifier.lowercased()
        return name.contains("samantha") || id.contains("samantha")
      }

      finalVoice = siriVoice4 ?? anySiri ?? samantha ?? voices.first
    }

    if let voice = finalVoice {
      utterance.voice = voice
      print("🔊 [TTS] Selected voice: \(voice.name) (id: \(voice.identifier), quality: \(voice.quality.rawValue))")
    } else {
      utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
      print("⚠️ [TTS] Using default voice for \(voiceLanguage) - no matching voice found")
    }

    // Set speech rate
    if slowerSpeech {
      utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8  // Slower
    } else {
      utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.0  // Conversational (default)
    }

    // Keep pitch and volume at defaults
    utterance.pitchMultiplier = 1.0
    utterance.volume = 1.0

    // Set completion handler to notify Flutter when speech finishes
    ttsCompletionHandler = { success in
      result(success)
    }

    synthesizer.speak(utterance)
  }

  // Called by TTSDelegate when speech finishes
  func onSpeechFinished(success: Bool) {
    ttsCompletionHandler?(success)
    ttsCompletionHandler = nil

    // Clear audio chunks when TTS finishes so we only capture user's response
    // This ensures we don't include old audio from before the agent spoke
    if useRawAudioSTT && isBroadcastExtensionActive() {
      // Only clear chunks if we're using file-based approach (not extension STT)
      if extensionTranscriptMonitorTimer == nil {
        logToFlutter("Clearing audio buffer after TTS finished", category: "BroadcastAudio")
        clearBroadcastAudioChunks()

        // Also reset the silence time tracker to avoid processing stale detections
        lastProcessedSilenceTime = Date().timeIntervalSince1970
      } else {
        // Log what the extension has captured (for debugging)
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
          userDefaults.synchronize()
          let hasTranscript = userDefaults.bool(forKey: "hasNewTranscript")
          let transcript = userDefaults.string(forKey: "extensionTranscript") ?? "(empty)"
          logToFlutter("TTS finished - extension buffer: hasNew=\(hasTranscript), text='\(transcript)'", category: "ExtensionSTT")
        }

        logToFlutter("TTS finished - extension will handle new audio", category: "ExtensionSTT")
        // Reset transcript time to avoid processing old transcripts
        // Use a slightly earlier time to ensure we catch transcripts that might have been saved
        // just before TTS finished (with timestamps very close to now)
        lastProcessedTranscriptTime = Date().timeIntervalSince1970 - 1.0

        // Ensure monitoring is still active after TTS
        if extensionTranscriptMonitorTimer == nil {
          logToFlutter("Restarting extension transcript monitoring after TTS", category: "ExtensionSTT")
          startExtensionTranscriptMonitoring()
        }
      }
    }
  }

  // Send TTS audio level to Flutter
  func sendTTSAudioLevel(_ level: Double) {
    DispatchQueue.main.async {
      self.ttsAudioLevelEventSink?(level)
    }
  }

  // Set the TTS audio level event sink
  func setTTSAudioLevelEventSink(_ sink: FlutterEventSink?) {
    ttsAudioLevelEventSink = sink
  }

  // MARK: - Native Log Forwarding

  func setNativeLogEventSink(_ sink: FlutterEventSink?) {
    nativeLogEventSink = sink
  }

  /// Log message to both Xcode console and Flutter terminal
  /// - Parameters:
  ///   - message: The log message
  ///   - category: Optional category tag (e.g., "ExtensionSTT", "BroadcastAudio", "Speech")
  private func logToFlutter(_ message: String, category: String = "") {
    // Always print to Xcode console (existing behavior)
    let formattedMessage = category.isEmpty ? message : "[\(category)] \(message)"
    print(formattedMessage)

    // Send to Flutter if event sink is available
    if let sink = nativeLogEventSink {
      let logData: [String: Any] = [
        "message": message,
        "category": category,
        "timestamp": Date().timeIntervalSince1970
      ]
      DispatchQueue.main.async {
        sink(logData)
      }
    }
  }

  private func stopSpeaking(result: @escaping FlutterResult) {
    if let synthesizer = speechSynthesizer, synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }
    result(nil)
  }

  private func checkEnhancedVoiceAvailable(languageCode: String, result: @escaping FlutterResult) {
    let voiceLanguage = languageCode == "zh-Hans" ? "zh-CN" : "en-US"
    let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == voiceLanguage }

    let hasEnhanced: Bool
    if languageCode == "zh-Hans" {
      hasEnhanced = voices.contains { voice in
        let name = voice.name.lowercased()
        return name.contains("lilian") && (voice.quality == .enhanced || name.contains("premium"))
      }
    } else {
      // Check for Zoe Premium
      hasEnhanced = voices.contains { voice in
        let name = voice.name.lowercased()
        return name.contains("zoe") && (voice.quality == .enhanced || name.contains("premium"))
      }
    }

    // Return info about voice availability
    result([
      "hasEnhanced": hasEnhanced,
      "voiceName": languageCode == "zh-Hans" ? "Lilian Premium" : "Zoe Premium"
    ])
  }

  private func openVoiceSettings(result: @escaping FlutterResult) {
    // Open the app's settings page - this is the only reliable URL scheme
    // Users will need to navigate to: Settings > Accessibility > Spoken Content > Voices
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url, options: [:]) { success in
        result(success)
      }
    } else {
      result(false)
    }
  }

  private func getAvailableVoices(result: @escaping FlutterResult) {
    let allVoices = AVSpeechSynthesisVoice.speechVoices()

    // Get English voices (en-US)
    let englishVoices = allVoices.filter { $0.language == "en-US" }.map { voice -> [String: Any] in
      return [
        "id": voice.identifier,
        "name": voice.name,
        "quality": voice.quality == .enhanced ? "enhanced" : "default"
      ]
    }

    // Get Chinese voices (zh-CN for Simplified Chinese)
    let chineseVoices = allVoices.filter { $0.language == "zh-CN" }.map { voice -> [String: Any] in
      return [
        "id": voice.identifier,
        "name": voice.name,
        "quality": voice.quality == .enhanced ? "enhanced" : "default"
      ]
    }

    result([
      "english": englishVoices,
      "chinese": chineseVoices
    ])
  }
}

// MARK: - Stream Handlers

class AudioLevelStreamHandler: NSObject, FlutterStreamHandler {
  private weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    appDelegate?.setAudioLevelEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    appDelegate?.setAudioLevelEventSink(nil)
    return nil
  }
}

class SpeechEventStreamHandler: NSObject, FlutterStreamHandler {
  private weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    appDelegate?.setSpeechEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    appDelegate?.setSpeechEventSink(nil)
    return nil
  }
}

// MARK: - TTS Delegate

class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate {
  private weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    appDelegate?.sendTTSAudioLevel(0.0)
    appDelegate?.onSpeechFinished(success: true)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    appDelegate?.sendTTSAudioLevel(0.0)
    appDelegate?.onSpeechFinished(success: false)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
    // Generate a synthetic audio level based on the character being spoken
    // This creates a natural-feeling pulsation effect
    let text = utterance.speechString as NSString
    let character = text.substring(with: characterRange)

    // Vary level based on character type for more natural feel
    var level: Double = 0.5
    if character.rangeOfCharacter(from: .punctuationCharacters) != nil {
      level = 0.3  // Quieter for punctuation
    } else if character.rangeOfCharacter(from: .whitespaces) != nil {
      level = 0.2  // Quieter for spaces
    } else if character.uppercased() == character && character.lowercased() != character {
      level = 0.8  // Louder for uppercase
    } else {
      // Add some variation based on position
      level = 0.4 + Double.random(in: 0.0...0.4)
    }

    appDelegate?.sendTTSAudioLevel(level)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    appDelegate?.sendTTSAudioLevel(0.5)
  }
}

// MARK: - TTS Audio Level Stream Handler

class TTSAudioLevelStreamHandler: NSObject, FlutterStreamHandler {
  private weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    appDelegate?.setTTSAudioLevelEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    appDelegate?.setTTSAudioLevelEventSink(nil)
    return nil
  }
}

// MARK: - Native Log Stream Handler

class NativeLogStreamHandler: NSObject, FlutterStreamHandler {
  private weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    appDelegate?.setNativeLogEventSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    appDelegate?.setNativeLogEventSink(nil)
    return nil
  }
}

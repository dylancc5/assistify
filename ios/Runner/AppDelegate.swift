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
  private let rawAudioSilenceThreshold: TimeInterval = 2.5

  // Silence detection properties
  private var silenceTimer: Timer?
  private var lastTranscriptLength: Int = 0
  private var currentLanguageCode: String = "en-US"  // Track current language for restart
  private var speechEventChannel: FlutterEventChannel?
  private var speechEventSink: FlutterEventSink?
  private let silenceThreshold: TimeInterval = 2.5  // seconds of silence to trigger segment end

  // TTS properties
  private var ttsMethodChannel: FlutterMethodChannel?
  private var speechSynthesizer: AVSpeechSynthesizer?
  private var ttsDelegate: TTSDelegate?
  private var ttsCompletionHandler: ((Bool) -> Void)?
  private var ttsAudioLevelEventChannel: FlutterEventChannel?
  private var ttsAudioLevelEventSink: FlutterEventSink?

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
          self.speakText(text: text, languageCode: languageCode, slowerSpeech: slowerSpeech, result: result)
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
        result(false)
        return
      }

      // Create broadcast picker view
      let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
      broadcastPicker.showsMicrophoneButton = true  // Enable mic for raw audio STT

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

      // Return false since broadcast isn't active yet - user needs to select it
      result(false)
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
        print("📺 [ScreenCapture] Status change detected: was=\(wasBroadcasting), now=\(isNowBroadcasting)")
      }

      // If broadcast extension stopped while we were using it
      if wasBroadcasting && !isNowBroadcasting {
        print("📺 [ScreenCapture] Broadcast extension stopped")
        self.isUsingBroadcastExtension = false
        self.isCapturingFrames = false
        self.useRawAudioSTT = false  // Switch back to normal STT

        // Stop broadcast audio monitoring
        self.stopBroadcastAudioMonitoring()
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
            print("🎤 [Speech] Restarting normal speech recognition after broadcast stopped")
            self.startFreshRecognition()
          }
        }
      } else if !wasBroadcasting && isNowBroadcasting {
        // Broadcast extension just started
        print("📺 [ScreenCapture] Broadcast extension started - switching to SYSTEM-WIDE capture + raw audio STT")
        self.isUsingBroadcastExtension = true
        self.isCapturingFrames = true
        self.useRawAudioSTT = true  // Use raw audio recording for STT

        // Reconfigure audio session and switch to raw audio STT after a delay
        // to allow the broadcast extension to fully initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
          guard let self = self else { return }

          // Reconfigure audio session to ensure audio continues working
          self.reconfigureAudioSessionForSpeech()

          // If we were listening before, stop normal recognition and start raw audio recording
          if self.shouldBeListening {
            print("🎙️ [RawAudio] Switching to raw audio STT for broadcast mode...")
            // Stop normal speech recognition if running
            if self.isListening {
              self.stopAudioEngine()
            }
            // Start raw audio recording after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              self.startRawAudioRecording()
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

        // Don't deactivate - just reconfigure with mixWithOthers to allow concurrent audio
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        print("🎤 [Audio] Audio session reconfigured for speech recognition")
      } catch {
        print("🎤 [Audio] Error reconfiguring audio session: \(error.localizedDescription)")
      }
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

    // If we're in broadcast mode, use raw audio STT instead
    if useRawAudioSTT {
      print("🎙️ [RawAudio] Starting raw audio STT (broadcast mode active)")
      startRawAudioRecording()
      result(true)
      return
    }

    // Create or update speech recognizer with the specified language
    let locale = Locale(identifier: languageCode)
    let newRecognizer = SFSpeechRecognizer(locale: locale)

    print("Starting speech recognition with language: \(languageCode)")
    
    guard let recognizer = newRecognizer, recognizer.isAvailable else {
      print("Speech recognition not available for language: \(languageCode)")
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
      print("Stopping current recognition to restart with new language")
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

    // Configure audio session with reset for interrupted state
    do {
      let audioSession = AVAudioSession.sharedInstance()

      // First try to deactivate to reset any interrupted state
      try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

      // Use playAndRecord to allow both TTS and speech recognition
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      print("Audio session error during restart: \(error.localizedDescription)")
      isListening = false
      return
    }

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

    // If we were recording raw audio with AVAudioRecorder, stop and transcribe it
    if isRecordingRawAudio && audioRecorder != nil {
      stopRawAudioAndTranscribe()
    }

    // If in broadcast mode, check for any accumulated audio chunks to process
    if useRawAudioSTT && isBroadcastExtensionActive() {
      print("🎙️ [BroadcastAudio] App returned to foreground - checking for accumulated audio")

      // Restart the monitoring timer if it was stopped
      if broadcastAudioMonitorTimer == nil {
        startBroadcastAudioMonitoring()
      }

      // Process any chunks that accumulated while in background
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        self?.processAccumulatedBroadcastAudio()
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

  private func startBroadcastAudioMonitoring() {
    print("🎙️ [BroadcastAudio] Starting to monitor for silence detection from extension")

    // Check for silence detection flag every 500ms
    broadcastAudioMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.checkBroadcastSilenceDetection()
    }
  }

  private func stopBroadcastAudioMonitoring() {
    broadcastAudioMonitorTimer?.invalidate()
    broadcastAudioMonitorTimer = nil
  }

  private func checkBroadcastSilenceDetection() {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
    userDefaults.synchronize()

    let silenceDetected = userDefaults.bool(forKey: "silenceDetected")
    let silenceTime = userDefaults.double(forKey: "silenceDetectedTime")

    // Only process if this is a new silence detection
    if silenceDetected && silenceTime > lastProcessedSilenceTime {
      lastProcessedSilenceTime = silenceTime

      // Clear the flag
      userDefaults.set(false, forKey: "silenceDetected")
      userDefaults.synchronize()

      print("🎙️ [BroadcastAudio] Silence detected - aggregating and transcribing audio chunks")
      aggregateAndTranscribeAudioChunks()
    }
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
      print("🎙️ [BroadcastAudio] No audio chunks to process")
      return
    }

    print("🎙️ [BroadcastAudio] Found \(audioFiles.count) audio chunks to aggregate")

    // Aggregate all audio data
    var aggregatedData = Data()
    for filename in audioFiles {
      let fileURL = audioDirectory.appendingPathComponent(filename)
      if let chunkData = try? Data(contentsOf: fileURL) {
        aggregatedData.append(chunkData)
      }
    }

    guard !aggregatedData.isEmpty else {
      print("🎙️ [BroadcastAudio] Aggregated data is empty")
      clearBroadcastAudioChunks()
      return
    }

    print("🎙️ [BroadcastAudio] Aggregated \(aggregatedData.count) bytes of audio data")

    // Convert PCM to WAV and save to file for transcription
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let wavURL = documentsPath.appendingPathComponent("broadcast_audio_\(timestamp).wav")

    // Write WAV file with header
    if writeWAVFile(pcmData: aggregatedData, to: wavURL) {
      print("🎙️ [BroadcastAudio] Written WAV file: \(wavURL.lastPathComponent)")

      // Clear audio chunks after aggregation
      clearBroadcastAudioChunks()

      // Transcribe the audio
      transcribeBroadcastAudio(url: wavURL)
    } else {
      print("🎙️ [BroadcastAudio] Failed to write WAV file")
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
    print("🎙️ [BroadcastAudio] Transcribing audio file: \(url.lastPathComponent)")

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguageCode)) else {
      print("🎙️ [BroadcastAudio] Speech recognizer not available for \(currentLanguageCode)")
      cleanupRawAudioFile(url: url)
      return
    }

    guard recognizer.isAvailable else {
      print("🎙️ [BroadcastAudio] Speech recognizer not available")
      cleanupRawAudioFile(url: url)
      return
    }

    let request = SFSpeechURLRecognitionRequest(url: url)
    request.shouldReportPartialResults = false

    recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self = self else { return }

      if let error = error {
        print("🎙️ [BroadcastAudio] Transcription error: \(error.localizedDescription)")
        self.cleanupRawAudioFile(url: url)
        return
      }

      guard let result = result, result.isFinal else { return }

      let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespaces)

      if transcript.isEmpty {
        print("🎙️ [BroadcastAudio] Transcription was empty")
      } else {
        print("🎙️ [BroadcastAudio] Transcribed: \(transcript)")

        // Send transcription to Flutter
        if let sink = self.speechEventSink {
          DispatchQueue.main.async {
            sink(["event": "segmentComplete", "text": transcript, "source": "broadcastAudio"])
          }
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

  private func speakText(text: String, languageCode: String, slowerSpeech: Bool, result: @escaping FlutterResult) {
    guard let synthesizer = speechSynthesizer else {
      result(FlutterError(code: "TTS_UNAVAILABLE", message: "Speech synthesizer not available", details: nil))
      return
    }

    // Stop any current speech
    if synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }

    // Configure audio session for playback and recording
    do {
      let audioSession = AVAudioSession.sharedInstance()
      // Use playAndRecord to allow both TTS and speech recognition
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      print("TTS audio session error: \(error.localizedDescription)")
    }

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

    let selectedVoice: AVSpeechSynthesisVoice?
    if languageCode == "zh-Hans" {
      // Prefer Lilian Premium, otherwise fall back to other enhanced Mandarin voices
      let lilianPremium = voices.first { voice in
        let name = voice.name.lowercased()
        return name.contains("lilian") && (voice.quality == .enhanced || name.contains("premium"))
      }
      let anyEnhanced = voices.first { $0.quality == .enhanced }
      selectedVoice = lilianPremium ?? anyEnhanced ?? voices.first
    } else {
      // Prefer Zoe (Premium), then other Siri voices, then Samantha, then default
      let zoePremium = voices.first { voice in
        let name = voice.name.lowercased()
        return name.contains("zoe") && (voice.quality == .enhanced || name.contains("premium"))
      }
      let anySiri = voices.first { $0.identifier.lowercased().contains("siri") || $0.name.lowercased().contains("siri") }
      let samantha = voices.first {
        let name = $0.name.lowercased()
        let id = $0.identifier.lowercased()
        return name.contains("samantha") || id.contains("samantha")
      }
      selectedVoice = zoePremium ?? anySiri ?? samantha ?? voices.first
    }

    if let voice = selectedVoice {
      utterance.voice = voice
      print("Using voice: \(voice.identifier)")
    } else {
      utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
      print("Using default voice for \(voiceLanguage)")
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
      print("🎙️ [BroadcastAudio] Clearing audio buffer after TTS finished")
      clearBroadcastAudioChunks()

      // Also reset the silence time tracker to avoid processing stale detections
      lastProcessedSilenceTime = Date().timeIntervalSince1970
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

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

  // Speech recognition properties
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var audioEngine: AVAudioEngine?
  private var currentTranscript: String = ""
  private var isListening: Bool = false

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
          let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
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
          let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!

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
      guard let controller = self?.window?.rootViewController else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER",
                           message: "Could not get root view controller",
                           details: nil))
        return
      }

      // Create broadcast picker view
      let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
      broadcastPicker.preferredExtension = "com.assistify.app.BroadcastExtension"
      broadcastPicker.showsMicrophoneButton = true

      // Find the button in the picker and trigger it
      for subview in broadcastPicker.subviews {
        if let button = subview as? UIButton {
          button.sendActions(for: .allTouchEvents)
          break
        }
      }

      result(true)
    }
  }

  private func checkBroadcastStatus(result: @escaping FlutterResult) {
    // Check if broadcast extension is currently active via App Group
    let userDefaults = UserDefaults(suiteName: "group.com.assistify.broadcast")
    let isBroadcasting = userDefaults?.bool(forKey: "isBroadcasting") ?? false
    result(isBroadcasting)
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

    guard let engine = audioEngine else {
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

    // Configure audio session
    do {
      let audioSession = AVAudioSession.sharedInstance()
      // Use playAndRecord to allow both TTS and speech recognition
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      result(FlutterError(code: "AUDIO_SESSION_ERROR",
                         message: "Failed to configure audio session: \(error.localizedDescription)",
                         details: nil))
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

    // Configure audio session
    do {
      let audioSession = AVAudioSession.sharedInstance()
      // Use playAndRecord to allow both TTS and speech recognition
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
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
    } catch {
      isListening = false

      // Notify Flutter that recognition stopped unexpectedly
      if let sink = speechEventSink {
        DispatchQueue.main.async {
          sink(["event": "recognitionStopped", "error": error.localizedDescription])
        }
      }
    }
  }

  private func cancelSilenceTimer() {
    silenceTimer?.invalidate()
    silenceTimer = nil
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
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
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
    appDelegate?.onSpeechFinished(success: true)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    appDelegate?.onSpeechFinished(success: false)
  }
}

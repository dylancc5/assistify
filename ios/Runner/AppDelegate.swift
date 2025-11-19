import Flutter
import UIKit
import ReplayKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenRecorder: RPScreenRecorder?
  private var methodChannel: FlutterMethodChannel?
  private var assetWriter: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var audioInput: AVAssetWriterInput?
  private var outputURL: URL?
  private var recordingStartTime: Date?

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
}

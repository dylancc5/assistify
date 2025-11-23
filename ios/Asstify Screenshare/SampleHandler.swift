//
//  SampleHandler.swift
//  Asstify Screenshare
//
//  Created by Dylan  Chen on 11/21/25.
//

import ReplayKit
import UIKit
import CoreImage
import Speech
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {
    private let appGroupIdentifier = "group.com.dylancc5.assistify.broadcast"
    private let maxFrames = 50
    private let frameCaptureInterval: TimeInterval = 1.0  // 1 second between frames
    private var lastFrameCaptureTime: Date?
    private var frameSequence: Int = 0
    private let frameQueue = DispatchQueue(label: "com.assistify.frameProcessing")
    
    // Memory tracking
    private var totalFrameMemory: Int64 = 0
    private let maxFrameMemory: Int64 = 30_000_000  // 30MB for 50 frames
    private var totalAudioMemory: Int64 = 0
    private let maxAudioMemory: Int64 = 5_000_000  // 5MB

    // Audio chunk properties
    private var audioChunkSequence: Int = 0
    private let maxAudioChunks = 100  // 50 seconds max at 500ms chunks
    private var currentAudioData = Data()
    private let audioChunkDuration: TimeInterval = 0.5  // Save chunk every 500ms
    private var lastAudioChunkTime: Date?
    private var audioFormat: AudioStreamBasicDescription?
    private let audioQueue = DispatchQueue(label: "com.assistify.audioProcessing")

    // Silence detection for audio
    private var consecutiveSilentChunks: Int = 0
    private let silenceThresholdChunks: Int = 5  // 5 chunks = 2.5 seconds of silence

    // Speech recognition in extension
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isRecognizing = false
    private var lastTranscript = ""
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.5  // Same as chunk-based silence detection
    private var lastSavedTranscript: String = ""
    private var lastSavedTranscriptTime: TimeInterval = 0
    
    // File I/O retry tracking
    private var fileRetryCount: [String: Int] = [:]
    private let maxRetriesPerFile = 1
    
    // Concurrent queue for UserDefaults operations
    private let userDefaultsQueue = DispatchQueue(label: "com.assistify.userDefaults", qos: .utility, attributes: .concurrent)
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        print("[BroadcastExtension] Broadcast started")
        
        // Initialize shared container directory
        setupSharedContainer()

        // Clear any existing frames and audio chunks
        clearOldFrames()
        clearOldAudioChunks()

        // Update broadcast status
        updateBroadcastStatus(isBroadcasting: true, frameCount: 0)

        // Initialize speech recognition
        setupSpeechRecognition()
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
        print("[BroadcastExtension] Broadcast paused - aggressive cleanup")
        // Clean up aggressively on pause (may be memory-related)
        cleanupOldFrames(keepCount: 10)
        clearOldAudioChunks()
        totalFrameMemory = 0
        totalAudioMemory = 0
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
        print("[BroadcastExtension] Broadcast resumed")
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        print("[BroadcastExtension] Broadcast finished")

        // Update broadcast status
        updateBroadcastStatus(isBroadcasting: false, frameCount: 0)

        // Clean up old frames and audio
        clearOldFrames()
        clearOldAudioChunks()

        // Stop speech recognition
        stopSpeechRecognition()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // Handle video sample buffer
            processVideoFrame(sampleBuffer)
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            // Not needed for STT
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            // Feed to speech recognizer for real-time STT (primary method)
            feedAudioToRecognizer(sampleBuffer)
            // Also save chunks as fallback (in case extension STT fails)
            processMicAudio(sampleBuffer)
            
            // Periodically check for language changes
            if Int.random(in: 0..<100) == 0 {  // Check ~1% of the time to avoid overhead
                updateSpeechRecognitionLanguage()
            }
            break
        @unknown default:
            // Handle other sample buffer types
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSharedContainer() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("[BroadcastExtension] ERROR: Could not access App Group container")
            return
        }
        
        let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)
        
        // Create frames directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: framesDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true, attributes: nil)
                print("[BroadcastExtension] Created frames directory")
            } catch {
                print("[BroadcastExtension] ERROR: Could not create frames directory: \(error)")
            }
        }
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        // Check if enough time has passed since last capture
        let now = Date()
        if let lastCapture = lastFrameCaptureTime,
           now.timeIntervalSince(lastCapture) < frameCaptureInterval {
            return
        }
        lastFrameCaptureTime = now
        
        // Process frame on background queue
        frameQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Convert CMSampleBuffer to JPEG
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            
            // Get dimensions and calculate scaled size (max 1024px on longest side for Gemini)
            let extent = ciImage.extent
            let maxDimension: CGFloat = 1024
            let scale = min(maxDimension / extent.width, maxDimension / extent.height, 1.0)
            let scaledWidth = Int(extent.width * scale)
            let scaledHeight = Int(extent.height * scale)
            
            guard let cgImage = context.createCGImage(ciImage, from: extent) else {
                return
            }
            
            // Create scaled image
            UIGraphicsBeginImageContextWithOptions(CGSize(width: scaledWidth, height: scaledHeight), true, 1.0)
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // Convert to JPEG with compression
            guard let jpegData = scaledImage?.jpegData(compressionQuality: 0.7) else {
                return
            }
            
            // Write frame to shared container
            self.writeFrameToSharedContainer(jpegData)
        }
    }
    
    private func writeFrameToSharedContainer(_ jpegData: Data) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ [BroadcastExtension] Cannot access App Group container")
            return
        }
        
        // Check memory before writing
        let dataSize = Int64(jpegData.count)
        
        // Check if sampling is in progress (via UserDefaults flag from main app)
        let isSampling = (UserDefaults(suiteName: appGroupIdentifier)?.bool(forKey: "isSamplingFrames") ?? false)
        
        if totalFrameMemory + dataSize > maxFrameMemory && !isSampling {
            // Aggressively clean - keep only 30 frames (was 50)
            let targetKeepCount = 30
            cleanupOldFrames(keepCount: targetKeepCount)
            // Recalculate memory after cleanup
            totalFrameMemory = calculateCurrentFrameMemory()
        }
        
        // Check available space
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: containerURL.path),
           let freeSpace = attributes[.systemFreeSize] as? Int64 {
            if freeSpace < 10_000_000 { // Less than 10MB free
                print("⚠️ [BroadcastExtension] Low disk space (\(freeSpace) bytes) - cleaning up")
                cleanupOldFrames(keepCount: 20)
                clearOldAudioChunks()
            }
        }
        
        let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)
        
        // Create directory if needed (with error handling)
        if !FileManager.default.fileExists(atPath: framesDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ [BroadcastExtension] Cannot create frames directory: \(error)")
                return
            }
        }
        
        // Generate filename with timestamp and sequence
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        frameSequence += 1
        let filename = "frame_\(timestamp)_\(frameSequence).jpg"
        let fileURL = framesDirectory.appendingPathComponent(filename)
        
        // Write with comprehensive error handling
        do {
            try jpegData.write(to: fileURL, options: .atomic)
            
            // Reset retry count on success
            fileRetryCount.removeValue(forKey: filename)
            
            // Update memory tracking AFTER successful write
            totalFrameMemory += dataSize
            
            // Update frame count in UserDefaults
            let frameCount = getFrameCount()
            updateBroadcastStatus(isBroadcasting: true, frameCount: frameCount)
            
            // Manage buffer size - delete oldest frames if over limit
            if frameCount >= maxFrames {
                cleanupOldFrames(keepCount: maxFrames)
            }
        } catch let error as NSError {
            // Handle specific error codes
            let retryCount = fileRetryCount[filename] ?? 0
            
            switch error.code {
            case NSFileWriteNoPermissionError:
                print("❌ [BroadcastExtension] No permission to write file: \(filename)")
                // Don't retry - won't succeed
                return
            case NSFileWriteVolumeReadOnlyError:
                print("❌ [BroadcastExtension] Volume is read-only: \(filename)")
                // Don't retry - won't succeed
                return
            case NSFileWriteOutOfSpaceError:
                print("❌ [BroadcastExtension] Out of disk space - cleaning up aggressively")
                cleanupOldFrames(keepCount: 10)
                clearOldAudioChunks()
                // Don't retry - will fail again
                return
            default:
                print("❌ [BroadcastExtension] File write error (\(error.code)): \(error.localizedDescription)")
                
                // Retry only on transient errors and if under retry limit
                if retryCount < maxRetriesPerFile {
                    fileRetryCount[filename] = retryCount + 1
                    // Attempt recovery once
                    cleanupOldFrames(keepCount: 30)
                    do {
                        try jpegData.write(to: fileURL, options: .atomic)
                        print("✓ [BroadcastExtension] Retry successful for \(filename)")
                        fileRetryCount.removeValue(forKey: filename)
                        
                        // Update memory tracking
                        totalFrameMemory += dataSize
                        
                        // Update frame count
                        let frameCount = getFrameCount()
                        updateBroadcastStatus(isBroadcasting: true, frameCount: frameCount)
                    } catch {
                        print("❌ [BroadcastExtension] Retry failed for \(filename) - giving up")
                    }
                } else {
                    print("❌ [BroadcastExtension] Max retries reached for \(filename)")
                }
            }
        }
    }
    
    private func calculateCurrentFrameMemory() -> Int64 {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return 0
        }
        
        let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: framesDirectory.path) else {
            return 0
        }
        
        var total: Int64 = 0
        for filename in files.filter({ $0.hasSuffix(".jpg") }) {
            let fileURL = framesDirectory.appendingPathComponent(filename)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    private func getFrameCount() -> Int {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return 0
        }
        
        let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: framesDirectory.path) else {
            return 0
        }
        
        return files.filter { $0.hasSuffix(".jpg") }.count
    }
    
    private func cleanupOldFrames(keepCount: Int) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }
        
        let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: framesDirectory.path) else {
            return
        }
        
        // Filter and sort frame files by name (which includes timestamp)
        let frameFiles = files.filter { $0.hasSuffix(".jpg") }.sorted()
        
        // Delete oldest frames, keeping only the most recent ones
        let filesToDelete = frameFiles.dropLast(keepCount)
        
        for filename in filesToDelete {
            let fileURL = framesDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Recalculate memory after cleanup
        totalFrameMemory = calculateCurrentFrameMemory()
    }
    
    private func clearOldFrames() {
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
        
        frameSequence = 0
        totalFrameMemory = 0
    }
    
    private func updateBroadcastStatus(isBroadcasting: Bool, frameCount: Int) {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        userDefaults.set(isBroadcasting, forKey: "isBroadcasting")
        userDefaults.set(frameCount, forKey: "frameCount")
        userDefaults.synchronize()
    }

    // MARK: - Mic Audio Processing

    private func processMicAudio(_ sampleBuffer: CMSampleBuffer) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            // Get audio data from sample buffer
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                return
            }

            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

            guard status == kCMBlockBufferNoErr, let pointer = dataPointer else {
                return
            }

            let audioData = Data(bytes: pointer, count: length)

            // Store format description on first audio buffer
            if self.audioFormat == nil {
                if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
                    self.audioFormat = asbd?.pointee
                }
            }

            // Accumulate audio data (we'll calculate amplitude at chunk level, not buffer level)
            self.currentAudioData.append(audioData)

            // Check if we should save a chunk
            let now = Date()
            let shouldSaveChunk: Bool
            if let lastTime = self.lastAudioChunkTime {
                shouldSaveChunk = now.timeIntervalSince(lastTime) >= self.audioChunkDuration
            } else {
                shouldSaveChunk = self.currentAudioData.count > 0
                self.lastAudioChunkTime = now
            }

            if shouldSaveChunk && self.currentAudioData.count > 0 {
                self.lastAudioChunkTime = now

                // Calculate average amplitude for the entire chunk (more accurate than buffer-level)
                let avgAmplitude = self.calculateAudioLevel(from: self.currentAudioData)
                
                // Determine if this chunk is silent based on its average amplitude
                let isChunkSilent = avgAmplitude < 0.02  // Threshold for silence
                
                // Track consecutive silent chunks for triggering silence detection
                if isChunkSilent {
                    self.consecutiveSilentChunks += 1
                } else {
                    self.consecutiveSilentChunks = 0
                }
                
                // Debug: Log amplitude for each chunk (both print and save to UserDefaults for main app)
                let chunkNumber = self.audioChunkSequence + 1
                let silentStatus = isChunkSilent ? " (SILENT)" : ""
                let logMessage = "Audio chunk #\(chunkNumber) - Avg amplitude: \(String(format: "%.4f", avgAmplitude))\(silentStatus)"
                print("🎵 [BroadcastExtension] \(logMessage)")
                
                // Save to UserDefaults so main app can forward to Flutter
                if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                    let timestamp = Date().timeIntervalSince1970
                    userDefaults.set(logMessage, forKey: "extensionLogMessage")
                    userDefaults.set(timestamp, forKey: "extensionLogTime")
                    userDefaults.set("BroadcastExtension", forKey: "extensionLogCategory")
                    userDefaults.synchronize()
                }

                // Save current chunk with amplitude, marked as silent if chunk-level amplitude is below threshold
                self.writeAudioChunkToSharedContainer(self.currentAudioData, avgAmplitude: avgAmplitude, isSilent: isChunkSilent)
                self.currentAudioData = Data()

                // If we've detected 5 consecutive silent chunks, mark it for the main app
                if self.consecutiveSilentChunks >= self.silenceThresholdChunks {
                    self.markSilenceDetected()
                    self.consecutiveSilentChunks = 0  // Reset after marking
                }
            }
        }
    }

    private func calculateAudioLevel(from data: Data) -> Float {
        // Assume 16-bit PCM audio
        let samples = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Int16] in
            let int16Pointer = pointer.bindMemory(to: Int16.self)
            return Array(int16Pointer)
        }

        guard !samples.isEmpty else { return 0 }

        // Calculate RMS
        let sum = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = sqrt(sum / Double(samples.count))

        // Normalize to 0-1 range (Int16 max is 32767)
        return Float(rms / 32767.0)
    }

    private func writeAudioChunkToSharedContainer(_ audioData: Data, avgAmplitude: Float, isSilent: Bool) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("❌ [BroadcastExtension] Cannot access App Group container for audio")
            return
        }

        // Check available space
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: containerURL.path),
           let freeSpace = attributes[.systemFreeSize] as? Int64 {
            if freeSpace < 10_000_000 { // Less than 10MB free
                print("⚠️ [BroadcastExtension] Low disk space for audio (\(freeSpace) bytes) - cleaning up")
                cleanupOldAudioChunks(keepCount: 20)
            }
        }

        let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

        // Create audio directory if needed (with error handling)
        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ [BroadcastExtension] Cannot create audio directory: \(error)")
                return
            }
        }

        // Generate filename with timestamp, sequence, amplitude, and silence marker
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        audioChunkSequence += 1
        let silenceMarker = isSilent ? "_silent" : ""
        // Store amplitude in filename (multiply by 10000 to preserve precision as integer)
        let amplitudeInt = Int(avgAmplitude * 10000)
        let filename = "audio_\(timestamp)_\(audioChunkSequence)_amp\(amplitudeInt)\(silenceMarker).pcm"
        let fileURL = audioDirectory.appendingPathComponent(filename)

        // Write audio chunk with comprehensive error handling
        do {
            try audioData.write(to: fileURL, options: .atomic)
            
            // Reset retry count on success
            fileRetryCount.removeValue(forKey: filename)

            // Manage buffer size
            let chunkCount = getAudioChunkCount()
            if chunkCount > maxAudioChunks {
                cleanupOldAudioChunks(keepCount: maxAudioChunks)
            }
        } catch let error as NSError {
            // Handle specific error codes
            let retryCount = fileRetryCount[filename] ?? 0
            
            switch error.code {
            case NSFileWriteNoPermissionError:
                print("❌ [BroadcastExtension] No permission to write audio file: \(filename)")
                // Don't retry - won't succeed
                return
            case NSFileWriteVolumeReadOnlyError:
                print("❌ [BroadcastExtension] Volume is read-only for audio: \(filename)")
                // Don't retry - won't succeed
                return
            case NSFileWriteOutOfSpaceError:
                print("❌ [BroadcastExtension] Out of disk space for audio - cleaning up")
                cleanupOldAudioChunks(keepCount: 10)
                // Don't retry - will fail again
                return
            default:
                print("❌ [BroadcastExtension] Audio file write error (\(error.code)): \(error.localizedDescription)")
                
                // Retry only on transient errors and if under retry limit
                if retryCount < maxRetriesPerFile {
                    fileRetryCount[filename] = retryCount + 1
                    // Attempt recovery once
                    cleanupOldAudioChunks(keepCount: maxAudioChunks / 2)
                    do {
                        try audioData.write(to: fileURL, options: .atomic)
                        print("✓ [BroadcastExtension] Audio retry successful for \(filename)")
                        fileRetryCount.removeValue(forKey: filename)
                        
                        // Manage buffer size after retry
                        let chunkCount = getAudioChunkCount()
                        if chunkCount > maxAudioChunks {
                            cleanupOldAudioChunks(keepCount: maxAudioChunks)
                        }
                    } catch {
                        print("❌ [BroadcastExtension] Audio retry failed for \(filename) - giving up")
                    }
                } else {
                    print("❌ [BroadcastExtension] Max retries reached for audio \(filename)")
                }
            }
        }
    }

    private func getAudioChunkCount() -> Int {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return 0
        }

        let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDirectory.path) else {
            return 0
        }

        return files.filter { $0.hasSuffix(".pcm") }.count
    }

    private func cleanupOldAudioChunks(keepCount: Int) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }

        let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: audioDirectory.path) else {
            return
        }

        let audioFiles = files.filter { $0.hasSuffix(".pcm") }.sorted()
        let filesToDelete = audioFiles.dropLast(keepCount)

        for filename in filesToDelete {
            let fileURL = audioDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func clearOldAudioChunks() {
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

        audioChunkSequence = 0
        currentAudioData = Data()
        lastAudioChunkTime = nil
    }

    private func markSilenceDetected() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        // Set a flag that silence was detected - main app will check this
        userDefaults.set(true, forKey: "silenceDetected")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "silenceDetectedTime")
        userDefaults.synchronize()

        print("[BroadcastExtension] Silence detected - marked for main app")
    }

    // MARK: - Speech Recognition in Extension

    private func setupSpeechRecognition() {
        print("[BroadcastExtension] Setting up speech recognition")

        // Read language code from UserDefaults (set by main app)
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("[BroadcastExtension] Could not access App Group UserDefaults")
            return
        }
        
        let languageCode = userDefaults.string(forKey: "speechLanguageCode") ?? "en-US"
        print("[BroadcastExtension] Using language code: \(languageCode)")

        // Initialize recognizer with language from main app
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("[BroadcastExtension] Speech recognizer not available for language: \(languageCode)")
            return
        }

        // Use on-device recognition to reduce memory
        if #available(iOS 13.0, *) {
            recognizer.supportsOnDeviceRecognition = true
        }

        startRecognition()
    }
    
    private func updateSpeechRecognitionLanguage() {
        // Check if language changed and restart recognition if needed
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        
        let newLanguageCode = userDefaults.string(forKey: "speechLanguageCode") ?? "en-US"
        let currentLocale = speechRecognizer?.locale.identifier ?? "en-US"
        
        if newLanguageCode != currentLocale {
            print("[BroadcastExtension] Language changed from \(currentLocale) to \(newLanguageCode) - restarting recognition")
            stopSpeechRecognition()
            
            // Update recognizer
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: newLanguageCode))
            
            if let recognizer = speechRecognizer, recognizer.isAvailable {
                if #available(iOS 13.0, *) {
                    recognizer.supportsOnDeviceRecognition = true
                }
                startRecognition()
            }
        }
    }

    private func startRecognition() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logToUserDefaults("❌ Cannot start recognition - recognizer not available")
            // Mark that extension STT is not active
            if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                userDefaults.set(false, forKey: "extensionSTTActive")
                userDefaults.synchronize()
            }
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let request = recognitionRequest else {
            print("[BroadcastExtension] Could not create recognition request")
            return
        }

        request.shouldReportPartialResults = true

        // Use on-device if available
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }

        // Start recognition task
        print("🎤 [BroadcastExtension] Starting recognition task...")
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcript = result.bestTranscription.formattedString

                // Only process if transcript changed
                if transcript != self.lastTranscript && !transcript.isEmpty {
                    self.lastTranscript = transcript
                    print("🎤 [BroadcastExtension] Partial transcript: \(transcript)")

                    // Reset silence timer on new speech
                    self.resetSilenceTimer()
                }

                // If final result, save it
                if result.isFinal {
                    print("🎤 [BroadcastExtension] ✓ FINAL result received: \(transcript)")
                    // Cancel silence timer since we have a final result
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = nil

                    if !transcript.isEmpty {
                        self.saveTranscription(transcript)
                    }
                    self.lastTranscript = ""
                    // End current request - recognition will restart when new audio arrives
                    self.recognitionRequest?.endAudio()
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isRecognizing = false
                    self.logToUserDefaults("📝 Session ended - waiting for new audio")
                } else {
                    // Log partial results for debugging
                    if Int.random(in: 0..<20) == 0 {  // Log ~5% of partial results to avoid spam
                        print("🎤 [BroadcastExtension] Partial (not final): \(transcript)")
                    }
                }
            }

            if let error = error {
                let errorCode = (error as NSError).code
                print("❌ [BroadcastExtension] Recognition error (code \(errorCode)): \(error.localizedDescription)")

                // Save any partial transcript before error
                if !self.lastTranscript.isEmpty {
                    print("💾 [BroadcastExtension] Saving partial transcript before error: '\(self.lastTranscript)'")
                    self.saveTranscription(self.lastTranscript)
                    self.lastTranscript = ""
                } else {
                    print("⚠️ [BroadcastExtension] Error occurred but no transcript to save")
                }

                // Only restart on specific recoverable errors
                // 216 = cancellation, 203 = end of utterance, 1110 = no speech detected
                // Don't restart on these as they indicate normal end of session
                let nonRecoverableErrors = [216, 203, 1110, 301, 1700]
                if !nonRecoverableErrors.contains(errorCode) {
                    print("🔄 [BroadcastExtension] Restarting recognition after error")
                    self.restartRecognition()
                } else {
                    print("ℹ️ [BroadcastExtension] Not restarting - normal end of session (code \(errorCode))")
                }
            }
        }

        isRecognizing = true

        // Mark that extension STT is active
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            userDefaults.set(true, forKey: "extensionSTTActive")
            userDefaults.synchronize()
        }

        logToUserDefaults("✅ Speech recognition started successfully")
    }

    private func stopSpeechRecognition() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        isRecognizing = false

        // Mark that extension STT is no longer active
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            userDefaults.set(false, forKey: "extensionSTTActive")
            userDefaults.synchronize()
        }

        // Save any remaining transcript
        if !lastTranscript.isEmpty {
            saveTranscription(lastTranscript)
            lastTranscript = ""
        }

        print("[BroadcastExtension] Speech recognition stopped")
    }

    private func restartRecognition() {
        // Ensure we're not recognizing during restart
        isRecognizing = false
        recognitionRequest = nil
        recognitionTask = nil

        // Log restart attempt
        logToUserDefaults("🔄 Restarting recognition in 0.3s...")

        // Delay before restarting to allow the old session to fully complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.logToUserDefaults("🔄 Now calling startRecognition()")
            self?.startRecognition()
        }
    }

    private func logToUserDefaults(_ message: String) {
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let timestamp = Date().timeIntervalSince1970
            userDefaults.set(message, forKey: "extensionLogMessage")
            userDefaults.set(timestamp, forKey: "extensionLogTime")
            userDefaults.set("ExtensionSTT", forKey: "extensionLogCategory")
            userDefaults.synchronize()
        }
        print("📱 [BroadcastExtension] \(message)")
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()

        // Schedule timer on main run loop to ensure it fires
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceTimeout, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                // Silence detected - finalize current transcript
                if !self.lastTranscript.isEmpty {
                    print("🔇 [BroadcastExtension] ⏱️ Silence timeout (2.5s) - saving transcript: '\(self.lastTranscript)'")
                    self.saveTranscription(self.lastTranscript)
                    self.lastTranscript = ""

                    // End current session - will auto-restart on new audio
                    self.recognitionRequest?.endAudio()
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isRecognizing = false
                    self.logToUserDefaults("📝 Silence timeout - waiting for new audio")
                } else {
                    print("🔇 [BroadcastExtension] ⏱️ Silence timeout but no transcript to save")
                }
            }
        }
    }

    private func saveTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            print("⚠️ [BroadcastExtension] Attempted to save empty transcript")
            return
        }

        // Use serial queue to ensure atomic operations
        userDefaultsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Prevent saving duplicate transcripts within 1 second
            let now = Date().timeIntervalSince1970
            guard let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                print("❌ [BroadcastExtension] Could not access UserDefaults")
                return
            }
            
            // Synchronize to get latest values
            userDefaults.synchronize()
            
            let lastSaved = userDefaults.string(forKey: "extensionTranscript") ?? ""
            let lastSavedTime = userDefaults.double(forKey: "extensionTranscriptTime")
            
            // Check for duplicate (same text within 1 second)
            if trimmed == lastSaved && (now - lastSavedTime) < 1.0 {
                print("⚠️ [BroadcastExtension] Skipping duplicate transcript save")
                return
            }
            
            // Atomic update with timestamp
            let timestamp = now
            userDefaults.set(trimmed, forKey: "extensionTranscript")
            userDefaults.set(timestamp, forKey: "extensionTranscriptTime")
            userDefaults.set(true, forKey: "hasNewTranscript")
            userDefaults.set(true, forKey: "extensionSTTActive")
            
            // Get current frame file paths for Gemini processing
            let framePaths = self.getCurrentFramePaths()
            if let framePathsData = try? JSONSerialization.data(withJSONObject: framePaths, options: []),
               let framePathsString = String(data: framePathsData, encoding: .utf8) {
                userDefaults.set(framePathsString, forKey: "geminiFramePaths")
                print("🤖 [BroadcastExtension] Saved \(framePaths.count) frame paths for background Gemini")
            } else {
                print("⚠️ [BroadcastExtension] Failed to serialize frame paths for Gemini")
            }
            
            // Set flag for background Gemini processing (use same timestamp)
            userDefaults.set(true, forKey: "geminiRequestPending")
            userDefaults.set(timestamp, forKey: "geminiRequestTime")
            
            // Final synchronization
            userDefaults.synchronize()
            
            // Update local state
            self.lastSavedTranscript = trimmed
            self.lastSavedTranscriptTime = now
            
            print("💾 [BroadcastExtension] ✓ Saved transcript to UserDefaults: '\(trimmed)' (time: \(timestamp))")
            print("🤖 [BroadcastExtension] Set geminiRequestPending=true - using EXTENSION STT (native Speech Recognition)")
            print("[BroadcastExtension] Saved transcript: \(trimmed) with \(framePaths.count) frame paths")
        }
    }

    private func getCurrentFramePaths() -> [String] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return []
        }

        let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: framesDirectory.path) else {
            return []
        }

        // Get sorted frame files (sorted by timestamp in filename)
        let frameFiles = files.filter { $0.hasSuffix(".jpg") }.sorted()

        // Return full paths
        return frameFiles.map { framesDirectory.appendingPathComponent($0).path }
    }

    private func feedAudioToRecognizer(_ sampleBuffer: CMSampleBuffer) {
        // If not recognizing, start a new recognition session
        if !isRecognizing {
            logToUserDefaults("🎤 Starting new recognition session for incoming audio")
            startRecognition()
        }

        guard isRecognizing else {
            // Log periodically to avoid spam
            if Int.random(in: 0..<1000) == 0 {
                print("⚠️ [BroadcastExtension] Audio feed skipped - not recognizing")
            }
            return
        }

        guard let request = recognitionRequest else {
            if Int.random(in: 0..<1000) == 0 {
                print("⚠️ [BroadcastExtension] Audio feed skipped - no recognition request")
            }
            return
        }

        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard let audioBuffer = convertToPCMBuffer(sampleBuffer) else {
            if Int.random(in: 0..<1000) == 0 {
                print("⚠️ [BroadcastExtension] Audio feed skipped - PCM conversion failed")
            }
            return
        }

        // Append audio buffer to recognition request
        request.append(audioBuffer)
    }
    
    private func convertToPCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        // Get format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        
        // Get audio stream basic description
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return nil
        }
        
        // Create AVAudioFormat from ASBD
        guard let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: asbd.mSampleRate,
                                             channels: UInt32(asbd.mChannelsPerFrame),
                                             interleaved: false) else {
            return nil
        }
        
        // Get audio data from sample buffer
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard status == kCMBlockBufferNoErr, let pointer = dataPointer else {
            return nil
        }
        
        // Calculate number of frames
        let bytesPerFrame = Int(asbd.mBytesPerFrame)
        let frameCount = length / bytesPerFrame
        
        // Create PCM buffer
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Copy audio data to PCM buffer
        // The sample buffer might be in Int16 format, so we need to convert to Float32
        guard let floatChannelData = pcmBuffer.floatChannelData else {
            return nil
        }
        let floatPointer = floatChannelData[0]
        
        // Convert raw pointer to the appropriate type
        let rawPointer = UnsafeRawPointer(pointer)
        
        if asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 {
            // Convert Int16 to Float32
            let int16Pointer = rawPointer.bindMemory(to: Int16.self, capacity: frameCount * Int(asbd.mChannelsPerFrame))
            let sampleCount = frameCount * Int(asbd.mChannelsPerFrame)
            
            for i in 0..<sampleCount {
                floatPointer[i] = Float(int16Pointer[i]) / 32768.0
            }
        } else {
            // Already float format, copy directly
            let sourceFloatPointer = rawPointer.bindMemory(to: Float32.self, capacity: frameCount * Int(asbd.mChannelsPerFrame))
            let sampleCount = frameCount * Int(asbd.mChannelsPerFrame)
            floatPointer.assign(from: sourceFloatPointer, count: sampleCount)
        }
        
        return pcmBuffer
    }
}

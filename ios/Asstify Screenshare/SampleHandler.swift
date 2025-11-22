//
//  SampleHandler.swift
//  Asstify Screenshare
//
//  Created by Dylan  Chen on 11/21/25.
//

import ReplayKit
import UIKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {
    private let appGroupIdentifier = "group.com.dylancc5.assistify.broadcast"
    private let maxFrames = 100
    private let frameCaptureInterval: TimeInterval = 1.0  // 1 second between frames
    private var lastFrameCaptureTime: Date?
    private var frameSequence: Int = 0
    private let frameQueue = DispatchQueue(label: "com.assistify.frameProcessing")

    // Audio chunk properties
    private var audioChunkSequence: Int = 0
    private let maxAudioChunks = 200  // Keep more audio chunks than frames
    private var currentAudioData = Data()
    private let audioChunkDuration: TimeInterval = 0.5  // Save chunk every 500ms
    private var lastAudioChunkTime: Date?
    private var audioFormat: AudioStreamBasicDescription?
    private let audioQueue = DispatchQueue(label: "com.assistify.audioProcessing")

    // Silence detection for audio
    private var consecutiveSilentChunks: Int = 0
    private let silenceThresholdChunks: Int = 5  // 5 chunks = 2.5 seconds of silence
    
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
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
        print("[BroadcastExtension] Broadcast paused")
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
            // Handle audio sample buffer for mic audio - save for STT
            processMicAudio(sampleBuffer)
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
            return
        }
        
        let framesDirectory = containerURL.appendingPathComponent("frames", isDirectory: true)
        
        // Generate filename with timestamp and sequence
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        frameSequence += 1
        let filename = "frame_\(timestamp)_\(frameSequence).jpg"
        let fileURL = framesDirectory.appendingPathComponent(filename)
        
        // Write frame to file
        do {
            try jpegData.write(to: fileURL)
            
            // Update frame count in UserDefaults
            let frameCount = getFrameCount()
            updateBroadcastStatus(isBroadcasting: true, frameCount: frameCount + 1)
            
            // Manage buffer size - delete oldest frames if over limit
            if frameCount >= maxFrames {
                cleanupOldFrames(keepCount: maxFrames)
            }
        } catch {
            print("[BroadcastExtension] ERROR: Could not write frame: \(error)")
        }
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

            // Calculate audio level for silence detection
            let level = self.calculateAudioLevel(from: audioData)
            let isSilent = level < 0.02  // Threshold for silence

            if isSilent {
                self.consecutiveSilentChunks += 1
            } else {
                self.consecutiveSilentChunks = 0
            }

            // Accumulate audio data
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

                // Save current chunk
                self.writeAudioChunkToSharedContainer(self.currentAudioData, isSilent: self.consecutiveSilentChunks >= self.silenceThresholdChunks)
                self.currentAudioData = Data()

                // If we've detected silence, mark it for the main app
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

    private func writeAudioChunkToSharedContainer(_ audioData: Data, isSilent: Bool) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }

        let audioDirectory = containerURL.appendingPathComponent("audio", isDirectory: true)

        // Create audio directory if needed
        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        // Generate filename with timestamp, sequence, and silence marker
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        audioChunkSequence += 1
        let silenceMarker = isSilent ? "_silent" : ""
        let filename = "audio_\(timestamp)_\(audioChunkSequence)\(silenceMarker).pcm"
        let fileURL = audioDirectory.appendingPathComponent(filename)

        // Write audio chunk
        do {
            try audioData.write(to: fileURL)

            // Manage buffer size
            let chunkCount = getAudioChunkCount()
            if chunkCount > maxAudioChunks {
                cleanupOldAudioChunks(keepCount: maxAudioChunks)
            }
        } catch {
            print("[BroadcastExtension] ERROR: Could not write audio chunk: \(error)")
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
}

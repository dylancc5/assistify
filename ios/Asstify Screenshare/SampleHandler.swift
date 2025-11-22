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
    private let frameCaptureInterval: TimeInterval = 0.5  // 500ms between frames
    private var lastFrameCaptureTime: Date?
    private var frameSequence: Int = 0
    private let frameQueue = DispatchQueue(label: "com.assistify.frameProcessing")
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        print("[BroadcastExtension] Broadcast started")
        
        // Initialize shared container directory
        setupSharedContainer()
        
        // Clear any existing frames
        clearOldFrames()
        
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
        
        // Clean up old frames
        clearOldFrames()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // Handle video sample buffer
            processVideoFrame(sampleBuffer)
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            // Not needed for frame capture
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            // Not needed for frame capture
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
}

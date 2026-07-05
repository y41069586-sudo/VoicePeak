import ARKit
import RealityKit
import Combine
import UIKit
import SwiftUI

/// Manages real-time face tracking via ARKit. Provides face mesh, head rotation,
/// and position updates suitable for scan alignment guidance and region extraction.
/// Designed to be independent and swappable; includes graceful fallback if ARKit is unavailable.
@Observable
final class ARKitFaceEngine: NSObject {
    private(set) var isAvailable: Bool = ARFaceTrackingConfiguration.isSupported
    private(set) var isTracking: Bool = false
    
    /// Current face tracking state. Nil if no face detected.
    private(set) var faceTracking: FaceTrackingState?
    
    /// Latest frame timestamp. Used for throttling updates.
    private(set) var lastUpdateTime: CFTimeInterval = 0
    
    private let arSession = ARSession()
    private var displayLink: CADisplayLink?
    
    // Configuration
    private let targetUpdateHz: Int = 15  // 15 Hz for analysis (60 FPS camera, ~4x throttle)
    private let minFrameInterval: CFTimeInterval
    
    override init() {
        self.minFrameInterval = 1.0 / Double(targetUpdateHz)
        super.init()
        
        if isAvailable {
            arSession.delegate = self
        }
    }
    
    deinit {
        stop()
    }
    
    /// Start ARKit face tracking. Safe to call multiple times.
    func start() {
        guard isAvailable, !isTracking else { return }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.providesAudioData = false
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        arSession.run(configuration)
        isTracking = true
        
        // Begin display link for updates
        let displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    /// Stop ARKit session and clean up.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        arSession.pause()
        isTracking = false
        faceTracking = nil
    }
    
    /// Reset the session (for recovery or re-acquisition).
    func reset() {
        stop()
        start()
    }
    
    /// Latest face mesh points transformed to image space (0...1 normalized).
    /// Returns nil if no face is currently tracked.
    var meshPointsInNormalizedImageSpace: [SIMD3<Float>]? {
        faceTracking?.meshPointsNormalized
    }
    
    /// Get mesh points in actual UIImage pixel coordinates.
    func meshPointsInImagePixels(imageSize: CGSize) -> [CGPoint]? {
        guard let points = faceTracking?.meshPointsNormalized else { return nil }
        return points.map { point in
            CGPoint(x: CGFloat(point.x) * imageSize.width,
                    y: CGFloat(point.y) * imageSize.height)
        }
    }
    
    /// Recommended face crop region for analysis (normalized 0...1).
    var faceCropRegion: CGRect? {
        faceTracking?.boundingBoxNormalized
    }
    
    // MARK: - Private
    
    @objc
    private func updateFrame() {
        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= minFrameInterval else { return }
        lastUpdateTime = now
        
        guard let frame = arSession.currentFrame else { return }
        guard let faceAnchor = frame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            // No face detected
            faceTracking = nil
            return
        }
        
        // Convert face anchor to tracking state
        faceTracking = FaceTrackingState(from: faceAnchor, cameraFrame: frame)
    }
}

// MARK: - ARSessionDelegate

extension ARKitFaceEngine: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARKit session failed: \(error)")
        isTracking = false
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        isTracking = false
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Attempt to resume
        if isAvailable {
            start()
        }
    }
}

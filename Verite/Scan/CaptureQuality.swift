import SwiftUI

/// Live, per-frame assessment of whether the current camera framing is
/// *standardized* enough to make scans comparable over time. The AR guide only
/// turns green — and capture only unlocks — when every gate passes. This metadata
/// is stored on the `Scan` (drives the "Verified" badge and keeps scans honest).
struct CaptureQuality: Equatable {
    var faceDetected: Bool = false
    /// Face bounding-box height as a fraction of the frame (proxy for distance).
    var normalizedFaceHeight: Double = 0
    /// Distance of the face center from the frame center (0 = perfectly centered).
    var faceCenterOffset: Double = 1
    /// Average frame luminance, 0...1.
    var brightness: Double = 0

    // Target bands. Forgiving on purpose — guidance, not a lab rig.
    static let minFaceHeight = 0.42
    static let maxFaceHeight = 0.82
    static let maxCenterOffset = 0.14
    static let minBrightness = 0.26
    static let maxBrightness = 0.93

    var distanceOK: Bool {
        faceDetected && normalizedFaceHeight >= Self.minFaceHeight && normalizedFaceHeight <= Self.maxFaceHeight
    }
    var centeredOK: Bool { faceDetected && faceCenterOffset <= Self.maxCenterOffset }
    var lightingOK: Bool { brightness >= Self.minBrightness && brightness <= Self.maxBrightness }
    var isStandardized: Bool { distanceOK && centeredOK && lightingOK }

    /// Continuous 0...1 quality, persisted as `Scan.captureQuality`.
    var overall: Double {
        guard faceDetected else { return 0 }
        let dist = distanceOK ? 1.0 : 0.5
        let cen = centeredOK ? 1.0 : 0.5
        let light = lightingOK ? 1.0 : 0.5
        return ((dist + cen + light) / 3.0).clamped01
    }

    /// The single most important thing to tell the user right now (honest, kind).
    var guidanceKey: LocalizedStringKey {
        if !faceDetected { return "scan.guide.noFace" }
        if normalizedFaceHeight < Self.minFaceHeight { return "scan.guide.moveCloser" }
        if normalizedFaceHeight > Self.maxFaceHeight { return "scan.guide.moveBack" }
        if faceCenterOffset > Self.maxCenterOffset { return "scan.guide.center" }
        if brightness < Self.minBrightness { return "scan.guide.lightingLow" }
        if brightness > Self.maxBrightness { return "scan.guide.lightingHigh" }
        return "scan.guide.ready"
    }
}

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
    /// Both eyes read as open (landmark aspect-ratio heuristic). Used by the
    /// v2 guided capture checklist; not part of `isStandardized` (v1 semantics).
    var eyesOpen: Bool = false

    // Target bands. Forgiving on purpose — guidance, not a lab rig.
    // Distance is the Vision face-box height as a fraction of the FULL frame.
    // The on-screen oval guide (265×360 over a full-bleed aspect-fill preview)
    // frames a face at roughly 0.45–0.6 of frame height, so the old 0.70–0.80
    // window could never be satisfied by following the guide — "Distance"
    // stayed red and the shutter never unlocked. Widened to match the oval
    // (and still reject a face that's too far or cropped-in close).
    static let minFaceHeight = 0.40
    static let maxFaceHeight = 0.92
    static let maxCenterOffset = 0.18
    static let minBrightness = 0.25  // was 0.70 – most indoor lighting sits 0.30-0.55
    static let maxBrightness = 0.97  // allow very bright environments

    var distanceOK: Bool {
        faceDetected && normalizedFaceHeight >= Self.minFaceHeight && normalizedFaceHeight <= Self.maxFaceHeight
    }
    var centeredOK: Bool { faceDetected && faceCenterOffset <= Self.maxCenterOffset }
    var lightingOK: Bool { brightness >= Self.minBrightness && brightness <= Self.maxBrightness }
    var eyesOK: Bool { faceDetected && eyesOpen }
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

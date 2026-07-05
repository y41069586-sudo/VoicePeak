import CoreVideo
import Foundation

/// Strict input contract for skin analysis engine.
/// Encapsulates all data from ARKit, Vision, and quality assessment modules.
struct AnalysisInput: Sendable {
    /// Face mesh points in normalized image space (0...1).
    /// From ARKitFaceEngine - used for structural reference.
    let faceMeshPoints: [SIMD3<Float>]
    
    /// Extracted skin regions with normalized pixel buffers.
    /// From SkinRegionExtractor - ready for analysis.
    let skinRegions: [SkinRegionData]
    
    /// Quality assessment of the capture.
    let captureQuality: CaptureQuality
    
    /// Timestamp of this analysis input.
    let timestamp: Date
    
    // MARK: - Initialization
    
    init(
        faceMeshPoints: [SIMD3<Float>],
        skinRegions: [SkinRegionData],
        captureQuality: CaptureQuality,
        timestamp: Date = Date()
    ) {
        self.faceMeshPoints = faceMeshPoints
        self.skinRegions = skinRegions
        self.captureQuality = captureQuality
        self.timestamp = timestamp
    }
}

/// Data for a single skin region ready for analysis.
struct SkinRegionData: Sendable {
    /// Which region this data represents.
    let region: FaceRegion
    
    /// Normalized pixel buffer (BGRA format).
    /// Already brightness-normalized and resized.
    let pixelBuffer: CVPixelBuffer
    
    /// Dimensions of the pixel buffer.
    let size: CGSize
    
    /// Confidence that this region was accurately extracted (0–1).
    let extractionConfidence: Float
    
    /// Average luminance in this region.
    let avgLuminance: Float
}

/// Quality metrics for the captured frame.
struct CaptureQuality: Sendable {
    /// Overall lighting quality (0–1).
    /// Derived from frame luminance, uniformity, and absence of harsh shadows.
    let lightingQuality: Float
    
    /// Face tracking stability (0–1).
    /// Indicates whether face mesh is steady and high-confidence.
    let faceStability: Float
    
    /// Face alignment quality (0–1).
    /// Measures whether face is frontal and centered in frame.
    let alignmentQuality: Float
    
    /// Combined quality score (0–1).
    var overallQuality: Float {
        (lightingQuality + faceStability + alignmentQuality) / 3.0
    }
    
    // MARK: - Initialization
    
    init(
        lightingQuality: Float,
        faceStability: Float,
        alignmentQuality: Float
    ) {
        self.lightingQuality = clamp(lightingQuality, 0, 1)
        self.faceStability = clamp(faceStability, 0, 1)
        self.alignmentQuality = clamp(alignmentQuality, 0, 1)
    }
}

// MARK: - Helpers

private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
    Swift.max(Swift.min(value, max), min)
}

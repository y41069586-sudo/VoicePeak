import Foundation
import CoreGraphics
import Vision

/// Result returned by the AnalysisGatekeeper containing validation outcome, frame quality, and confidence.
struct GatekeeperResult: Sendable {
    /// True if the frame passes all checks (exposure, blur, centering, motion).
    let isValidFrame: Bool
    /// Estimated confidence score (0...1) used for temporal weighting.
    let confidence: Double
    /// Overall quality score (0...1) of the captured frame.
    let qualityScore: Double
}

/// Dynamic stabilization layer that accepts or rejects frames before a full skin analysis is run.
///
/// Ensures we only analyze standard-conforming frames to prevent metric jumps.
actor AnalysisGatekeeper {
    
    // MARK: - State
    
    private var faceCenterHistory: [CGPoint] = []
    private let maxHistoryLength = 5
    
    // MARK: - API
    
    /// Evaluate frame suitability for analysis. Must be called on a background context.
    func checkFrame(_ cgImage: CGImage) -> GatekeeperResult {
        // 1. Detect face and bounding box center
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([request])
        
        guard let face = (request.results ?? []).max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
            return GatekeeperResult(isValidFrame: false, confidence: 0.0, qualityScore: 0.0)
        }
        
        let box = face.boundingBox
        let center = CGPoint(x: box.midX, y: box.midY)
        
        // 2. Face centering check (offset must be <= 0.14 from frame center)
        let centerOffset = hypot(center.x - 0.5, center.y - 0.5)
        let centeredOk = centerOffset <= 0.14
        
        // 3. Motion stability check
        faceCenterHistory.append(center)
        if faceCenterHistory.count > maxHistoryLength {
            faceCenterHistory.removeFirst()
        }
        let motionUnstable = checkMotionInstability()
        
        // 4. Blur check
        let blurry = LightingNormalizer.isBlurry(cgImage)
        
        // 5. Exposure check (luma within [0.15...0.92])
        let luma = LightingNormalizer.meanLuma(cgImage)
        let exposureOk = luma >= 0.15 && luma <= 0.92
        
        // 6. Uneven lighting check
        let unevenLighting = checkUnevenLighting(cgImage, faceRect: box)
        
        // All gates must pass
        let isValid = centeredOk && !blurry && exposureOk && !motionUnstable && !unevenLighting
        
        // Calculate continuous quality & confidence
        let centerScore = max(0, 1.0 - (centerOffset / 0.14))
        let targetLuma = 0.48
        let lumaScore = max(0, 1.0 - (abs(luma - targetLuma) / 0.35))
        let qualityScore = (centerScore * 0.4 + lumaScore * 0.6).clamped01
        
        // Lower confidence if face center is off, default to 0.8 on valid frame
        let confidence = (isValid ? 0.8 : 0.2) * (1.0 - centerOffset).clamped01
        
        return GatekeeperResult(
            isValidFrame: isValid,
            confidence: confidence,
            qualityScore: qualityScore
        )
    }
    
    /// Reset motion history (call when starting a new session)
    func resetHistory() {
        faceCenterHistory.removeAll()
    }
    
    // MARK: - Private helpers
    
    private func checkMotionInstability() -> Bool {
        guard faceCenterHistory.count >= 3 else { return false }
        var totalDist = 0.0
        for i in 1..<faceCenterHistory.count {
            let p1 = faceCenterHistory[i-1]
            let p2 = faceCenterHistory[i]
            totalDist += hypot(p1.x - p2.x, p1.y - p2.y)
        }
        let avgMove = totalDist / Double(faceCenterHistory.count - 1)
        return avgMove > 0.035
    }
    
    private func checkUnevenLighting(_ cgImage: CGImage, faceRect: CGRect) -> Bool {
        let w = Double(cgImage.width)
        let h = Double(cgImage.height)
        let pixelRect = Sampling.pixelRect(fromVision: faceRect, imageWidth: Int(w), imageHeight: Int(h))
        
        let halfWidth = pixelRect.width / 2
        let leftRect = CGRect(x: pixelRect.minX, y: pixelRect.minY, width: halfWidth, height: pixelRect.height)
        let rightRect = CGRect(x: pixelRect.minX + halfWidth, y: pixelRect.minY, width: halfWidth, height: pixelRect.height)
        
        guard let leftBuffer = Sampling.readPixels(cgImage, rect: leftRect, maxDim: 32),
              let rightBuffer = Sampling.readPixels(cgImage, rect: rightRect, maxDim: 32) else {
            return false
        }
        
        let leftLuma = bufferMeanLuma(leftBuffer)
        let rightLuma = bufferMeanLuma(rightBuffer)
        
        return abs(leftLuma - rightLuma) > 0.22
    }
    
    private func bufferMeanLuma(_ buffer: PixelBuffer) -> Double {
        var sum = 0.0
        let n = buffer.count
        for y in 0..<buffer.height {
            for x in 0..<buffer.width {
                let (r, g, b) = buffer.rgb(x, y)
                sum += 0.299 * r + 0.587 * g + 0.114 * b
            }
        }
        return sum / Double(n) / 255.0
    }
}

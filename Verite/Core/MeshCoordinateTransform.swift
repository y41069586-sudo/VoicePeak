import CoreGraphics
import simd

/// Utilities for transforming mesh points and regions between coordinate spaces.
/// Handles normalized (0...1), pixel, and CGRect transformations.
enum MeshCoordinateTransform {
    
    // MARK: - Normalized → Pixel Space
    
    /// Convert normalized mesh points (0...1) to pixel coordinates.
    static func toPixelSpace(_ points: [SIMD3<Float>], imageSize: CGSize) -> [CGPoint] {
        points.map { point in
            CGPoint(x: CGFloat(point.x) * imageSize.width,
                    y: CGFloat(point.y) * imageSize.height)
        }
    }
    
    /// Convert a single normalized point to pixel space.
    static func toPixelSpace(_ point: SIMD3<Float>, imageSize: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(point.x) * imageSize.width,
                y: CGFloat(point.y) * imageSize.height)
    }
    
    // MARK: - Pixel Space → Normalized
    
    /// Convert pixel-space points to normalized (0...1).
    static func toNormalizedSpace(_ points: [CGPoint], imageSize: CGSize) -> [SIMD3<Float>] {
        points.map { point in
            SIMD3<Float>(
                Float(point.x / imageSize.width),
                Float(point.y / imageSize.height),
                0
            )
        }
    }
    
    /// Convert a single pixel point to normalized space.
    static func toNormalizedSpace(_ point: CGPoint, imageSize: CGSize) -> SIMD3<Float> {
        SIMD3<Float>(
            Float(point.x / imageSize.width),
            Float(point.y / imageSize.height),
            0
        )
    }
    
    // MARK: - Bounding Box Operations
    
    /// Compute bounding box from a set of normalized mesh points.
    static func boundingBox(from points: [SIMD3<Float>], padding: CGFloat = 0.0) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        let xs = points.map { CGFloat($0.x) }
        let ys = points.map { CGFloat($0.y) }
        
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        
        return CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: min(1.0, maxX - minX + 2 * padding),
            height: min(1.0, maxY - minY + 2 * padding)
        )
    }
    
    /// Scale and center a region of interest.
    static func scaleCrop(
        region: CGRect,
        scale: CGFloat = 1.0,
        centerAt: CGPoint? = nil
    ) -> CGRect {
        let center = centerAt ?? CGPoint(x: region.midX, y: region.midY)
        let scaledWidth = region.width * scale
        let scaledHeight = region.height * scale
        
        return CGRect(
            x: center.x - scaledWidth / 2,
            y: center.y - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        ).clamp(to: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    
    // MARK: - Region Alignment Metrics
    
    /// Compute how well-centered and well-framed the face is within a target region.
    /// Returns alignment score 0...1 (1 = perfect alignment).
    static func alignmentScore(
        faceBounds: CGRect,
        targetBounds: CGRect = CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.7)
    ) -> Float {
        let faceCenter = CGPoint(x: faceBounds.midX, y: faceBounds.midY)
        let targetCenter = CGPoint(x: targetBounds.midX, y: targetBounds.midY)
        
        // Distance penalty
        let dx = faceCenter.x - targetCenter.x
        let dy = faceCenter.y - targetCenter.y
        let distancePenalty = Float(sqrt(dx * dx + dy * dy))
        
        // Size penalty (face should fill ~60% of target)
        let optimalArea = targetBounds.width * targetBounds.height * 0.6
        let faceArea = faceBounds.width * faceBounds.height
        let areaPenalty = abs(Float(faceArea - optimalArea) / Float(optimalArea))
        
        // Combined score
        let penalty = min(1.0, distancePenalty * 0.5 + areaPenalty * 0.5)
        return max(0, 1.0 - penalty)
    }
    
    /// Determine if face is within acceptable framing bounds.
    static func isWellFramed(
        faceBounds: CGRect,
        targetBounds: CGRect = CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.7),
        minAlignment: Float = 0.7
    ) -> Bool {
        alignmentScore(faceBounds: faceBounds, targetBounds: targetBounds) >= minAlignment
    }
    
    // MARK: - Head Rotation Angle
    
    /// Determine if head is tilted too much (pitch/roll exceeding threshold).
    /// Returns (isTiltedTooMuch: Bool, angle: Float in degrees)
    static func headTiltMetrics(
        pitch: Float,
        yaw: Float,
        roll: Float,
        maxTiltDegrees: Float = 15
    ) -> (isTiltedTooMuch: Bool, maxAngleDegrees: Float) {
        let toDegrees: Float = 180 / .pi
        let pitchDeg = abs(pitch * toDegrees)
        let yawDeg = abs(yaw * toDegrees)
        let rollDeg = abs(roll * toDegrees)
        
        let maxAngle = max(pitchDeg, max(yawDeg, rollDeg))
        return (maxAngle > maxTiltDegrees, maxAngle)
    }
}

// MARK: - Extensions

extension CGRect {
    /// Clamp a rect to another rect's bounds.
    func clamp(to bounds: CGRect) -> CGRect {
        let x = max(bounds.minX, min(self.minX, bounds.maxX - self.width))
        let y = max(bounds.minY, min(self.minY, bounds.maxY - self.height))
        let width = min(self.width, bounds.maxX - x)
        let height = min(self.height, bounds.maxY - y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

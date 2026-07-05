import Vision
import CoreGraphics
import Foundation

/// Computed regions of the face for skin analysis.
/// All coordinates are normalized to 0...1 face bounding box space.
enum FaceRegion: String, CaseIterable, Identifiable {
    case forehead
    case leftCheek
    case rightCheek
    case chin
    case bridge
    
    var id: String { rawValue }
    
    /// Fractional rect within face bounds (0...1 in face-local coordinates).
    /// Face bounds is assumed to be the axis-aligned bounding box of the face.
    var fractionalRect: (x0: Double, y0: Double, x1: Double, y1: Double) {
        switch self {
        case .forehead:
            // Upper third, full width
            return (x0: 0.1, y0: 0.05, x1: 0.9, y1: 0.25)
        case .leftCheek:
            // Left side, middle section
            return (x0: 0.05, y0: 0.35, x1: 0.45, y1: 0.65)
        case .rightCheek:
            // Right side, middle section
            return (x0: 0.55, y0: 0.35, x1: 0.95, y1: 0.65)
        case .chin:
            // Lower third, centered
            return (x0: 0.2, y0: 0.75, x1: 0.8, y1: 0.95)
        case .bridge:
            // Center vertical strip (nose)
            return (x0: 0.4, y0: 0.3, x1: 0.6, y1: 0.7)
        }
    }
    
    /// Description for UI display.
    var displayName: String {
        switch self {
        case .forehead: return "Forehead"
        case .leftCheek: return "Left Cheek"
        case .rightCheek: return "Right Cheek"
        case .chin: return "Chin"
        case .bridge: return "Bridge"
        }
    }
}

/// Utilities for computing face geometry and region rects.
enum FaceGeometry {
    
    /// Compute pixel-space rect for a region within a face bounding box.
    /// 
    /// - Parameters:
    ///   - faceBounds: Face bounding box in pixel coordinates
    ///   - region: Region fractional coordinates (0...1 within face)
    /// - Returns: Pixel-space CGRect, safe for cropping
    static func regionRect(in faceBounds: CGRect, for region: FaceRegion) -> CGRect {
        regionRect(in: faceBounds, region.fractionalRect)
    }
    
    /// Compute pixel-space rect from fractional coordinates.
    static func regionRect(
        in faceBounds: CGRect,
        _ frac: (x0: Double, y0: Double, x1: Double, y1: Double)
    ) -> CGRect {
        let x = faceBounds.origin.x + faceBounds.width * frac.x0
        let y = faceBounds.origin.y + faceBounds.height * frac.y0
        let width = faceBounds.width * (frac.x1 - frac.x0)
        let height = faceBounds.height * (frac.y1 - frac.y0)
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Clamp a rect to image bounds.
    static func clampToImage(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let x = max(0, min(rect.origin.x, imageSize.width - 1))
        let y = max(0, min(rect.origin.y, imageSize.height - 1))
        let width = min(rect.width, imageSize.width - x)
        let height = min(rect.height, imageSize.height - y)
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Compute a centered crop region of specified size.
    static func centeredCrop(
        in bounds: CGRect,
        targetSize: CGSize
    ) -> CGRect {
        let scale = min(bounds.width / targetSize.width, bounds.height / targetSize.height)
        let scaledWidth = targetSize.width * scale
        let scaledHeight = targetSize.height * scale
        
        let x = bounds.midX - scaledWidth / 2
        let y = bounds.midY - scaledHeight / 2
        
        return CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    }
    
    /// Expand a rect by a given factor (e.g., 1.2 = 20% expansion).
    static func expand(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        let deltaWidth = (rect.width * (factor - 1)) / 2
        let deltaHeight = (rect.height * (factor - 1)) / 2
        
        return CGRect(
            x: rect.origin.x - deltaWidth,
            y: rect.origin.y - deltaHeight,
            width: rect.width + 2 * deltaWidth,
            height: rect.height + 2 * deltaHeight
        )
    }
    
    /// Shrink a rect by a given factor (e.g., 0.8 = 20% shrink).
    static func shrink(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        expand(rect, by: factor)
    }
    
    /// Compute aspect ratio adjustment for a target size.
    static func aspectRatioPreservingResize(
        from sourceSize: CGSize,
        to targetSize: CGSize
    ) -> CGSize {
        let sourceRatio = sourceSize.width / sourceSize.height
        let targetRatio = targetSize.width / targetSize.height
        
        if sourceRatio > targetRatio {
            // Source is wider, fit to height
            let newWidth = targetSize.height * sourceRatio
            return CGSize(width: newWidth, height: targetSize.height)
        } else {
            // Source is taller, fit to width
            let newHeight = targetSize.width / sourceRatio
            return CGSize(width: targetSize.width, height: newHeight)
        }
    }
}

/// Extract and store detected face landmarks.
struct FaceLandmarks {
    /// Bounding box of the detected face (pixel coordinates).
    let boundingBox: CGRect
    
    /// Detected landmark points (pixel coordinates).
    /// Dictionary keys: landmark types (e.g., "leftEye", "rightEye", "nose", etc.)
    let points: [String: CGPoint]
    
    /// Overall detection confidence (0...1).
    let confidence: Float
    
    /// True if landmarks were successfully detected.
    var isValid: Bool { !points.isEmpty && confidence > 0.3 }
    
    // MARK: - Computed Properties
    
    /// Get a specific landmark point.
    func point(for key: String) -> CGPoint? {
        points[key]
    }
    
    /// Approximate left eye center.
    var leftEyeCenter: CGPoint? {
        guard let left = points["leftEye"],
              let right = points["rightEye"] else { return nil }
        return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }
    
    /// Approximate right eye center.
    var rightEyeCenter: CGPoint? {
        guard let left = points["leftEye"],
              let right = points["rightEye"] else { return nil }
        return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }
    
    /// Distance between eyes (pixels).
    var eyeDistance: CGFloat? {
        guard let left = leftEyeCenter, let right = rightEyeCenter else { return nil }
        return hypot(right.x - left.x, right.y - left.y)
    }
    
    /// Approximate nose tip.
    var noseTip: CGPoint? {
        points["noseTip"]
    }
}

/// Extract face landmarks using Vision framework.
enum FaceLandmarkDetector {
    
    /// Detect face landmarks in an image.
    static func detectLandmarks(in cgImage: CGImage) -> FaceLandmarks? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Face landmark detection failed: \(error)")
            return nil
        }
        
        guard let observation = request.results?.first as? VNFaceObservation else {
            return nil
        }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        let bbox = observation.boundingBox
        let boundingBox = CGRect(
            x: bbox.origin.x * imageWidth,
            y: (1 - bbox.origin.y - bbox.height) * imageHeight,
            width: bbox.width * imageWidth,
            height: bbox.height * imageHeight
        )
        
        var points: [String: CGPoint] = [:]
        
        // Extract individual landmark regions if available
        if let landmarks = observation.landmarks {
            // Contour
            if let contour = landmarks.faceContour {
                let contourPoints = contour.normalizedPoints.map { point in
                    CGPoint(
                        x: (bbox.origin.x + point.x * bbox.width) * imageWidth,
                        y: (1 - (bbox.origin.y + (1 - point.y) * bbox.height)) * imageHeight
                    )
                }
                if !contourPoints.isEmpty {
                    points["faceContour"] = contourPoints[contourPoints.count / 2]
                }
            }
            
            // Eyes
            if let leftEye = landmarks.leftEye {
                let eyePoints = leftEye.normalizedPoints
                if !eyePoints.isEmpty {
                    let avgPoint = eyePoints.reduce(CGPoint.zero) { acc, pt in
                        CGPoint(x: acc.x + pt.x, y: acc.y + pt.y)
                    }
                    points["leftEye"] = CGPoint(
                        x: (bbox.origin.x + avgPoint.x / CGFloat(eyePoints.count) * bbox.width) * imageWidth,
                        y: (1 - (bbox.origin.y + (1 - avgPoint.y / CGFloat(eyePoints.count)) * bbox.height)) * imageHeight
                    )
                }
            }
            
            if let rightEye = landmarks.rightEye {
                let eyePoints = rightEye.normalizedPoints
                if !eyePoints.isEmpty {
                    let avgPoint = eyePoints.reduce(CGPoint.zero) { acc, pt in
                        CGPoint(x: acc.x + pt.x, y: acc.y + pt.y)
                    }
                    points["rightEye"] = CGPoint(
                        x: (bbox.origin.x + avgPoint.x / CGFloat(eyePoints.count) * bbox.width) * imageWidth,
                        y: (1 - (bbox.origin.y + (1 - avgPoint.y / CGFloat(eyePoints.count)) * bbox.height)) * imageHeight
                    )
                }
            }
            
            // Nose
            if let nose = landmarks.nose {
                let nosePoints = nose.normalizedPoints
                if !nosePoints.isEmpty {
                    let avgPoint = nosePoints.reduce(CGPoint.zero) { acc, pt in
                        CGPoint(x: acc.x + pt.x, y: acc.y + pt.y)
                    }
                    points["noseTip"] = CGPoint(
                        x: (bbox.origin.x + avgPoint.x / CGFloat(nosePoints.count) * bbox.width) * imageWidth,
                        y: (1 - (bbox.origin.y + (1 - avgPoint.y / CGFloat(nosePoints.count)) * bbox.height)) * imageHeight
                    )
                }
            }
        }
        
        return FaceLandmarks(
            boundingBox: boundingBox,
            points: points,
            confidence: observation.confidence
        )
    }
}

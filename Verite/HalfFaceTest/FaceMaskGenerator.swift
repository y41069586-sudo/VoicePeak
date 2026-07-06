import Vision
import CoreGraphics
import CoreImage
import UIKit

/// Generates landmark-guided, feathered masks for half-face skincare simulation.
///
/// Unlike a straight vertical split, this mask curves naturally with the patient's
/// facial features using nose-bridge, forehead, and chin landmarks, and accounts
/// for head rotation/tilt.
enum FaceMaskGenerator {
    
    /// Generates a CGImage mask representing either the left or right side of the face,
    /// split along the actual face curvature (median line landmarks).
    ///
    /// - Parameters:
    ///   - imageSize: The bounds of the image being masked.
    ///   - face: The VNFaceObservation containing landmarks.
    ///   - side: The side of the face to receive processing (e.g. .left or .right).
    ///   - featherRadius: Blur radius for feathering the transition edge (default 30px).
    /// - Returns: A CGImage mask (grayscale), where white = full treatment, black = original.
    static func generateSplitMask(
        imageSize: CGSize,
        face: VNFaceObservation,
        side: FaceSide,
        featherRadius: CGFloat = 30.0
    ) -> CGImage? {
        guard let landmarks = face.landmarks,
              let contour = landmarks.faceContour,
              let medianLine = landmarks.medianLine else {
            return nil
        }
        
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        // Fill background with black (original side)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: imageSize))
        
        let box = face.boundingBox
        let faceRect = Sampling.pixelRect(fromVision: box, imageWidth: width, imageHeight: height)
        
        // Map normalized coordinates from VNFaceObservation to actual pixel space.
        func mapPoint(_ pt: CGPoint) -> CGPoint {
            let x = faceRect.minX + pt.x * faceRect.width
            let y = faceRect.minY + (1.0 - pt.y) * faceRect.height
            return CGPoint(x: x, y: y)
        }
        
        let contourPts = contour.normalizedPoints.map(mapPoint)
        let medianPts = medianLine.normalizedPoints.map(mapPoint)
        
        guard contourPts.count >= 2, medianPts.count >= 2 else { return nil }
        
        let path = CGMutablePath()
        
        if side == .left {
            // Draw along median line top-to-bottom (forehead -> nose bridge -> chin)
            path.move(to: medianPts.first!)
            for pt in medianPts.dropFirst() {
                path.addLine(to: pt)
            }
            
            // Reconstruct the contour path for visual left side.
            // Contour array represents points running from left temple around chin to right temple.
            let midIndex = contourPts.count / 2
            let leftContour = contourPts[0...midIndex].reversed()
            for pt in leftContour {
                path.addLine(to: pt)
            }
            path.closeSubpath()
        } else if side == .right {
            // Draw along median line top-to-bottom
            path.move(to: medianPts.first!)
            for pt in medianPts.dropFirst() {
                path.addLine(to: pt)
            }
            
            // Reconstruct the contour path for visual right side.
            let midIndex = contourPts.count / 2
            let rightContour = contourPts[midIndex..<contourPts.count]
            for pt in rightContour {
                path.addLine(to: pt)
            }
            path.closeSubpath()
        } else {
            // Full face mask (entire face contour boundary)
            path.move(to: contourPts.first!)
            for pt in contourPts.dropFirst() {
                path.addLine(to: pt)
            }
            path.closeSubpath()
        }
        
        // Draw the mask polygon as solid white
        context.addPath(path)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fillPath()
        
        guard let rawMask = context.makeImage() else { return nil }
        
        // Apply Gaussian blur to create the 20-40px soft feathered edge gradient
        let maskImage = CIImage(cgImage: rawMask)
        if let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: maskImage,
            kCIInputRadiusKey: Float(featherRadius)
        ]), let blurred = blurFilter.outputImage {
            let ciContext = CIContext()
            return ciContext.createCGImage(blurred, from: CGRect(origin: .zero, size: imageSize))
        }
        
        return rawMask
    }
}

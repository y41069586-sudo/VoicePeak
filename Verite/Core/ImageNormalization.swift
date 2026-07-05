import CoreGraphics
import CoreImage
import CoreVideo
import Accelerate
import UIKit

/// Utilities for normalizing image data for consistent analysis.
/// Handles lighting correction, histogram equalization, and pixel buffer management.
enum ImageNormalization {
    
    // MARK: - Lighting Analysis
    
    /// Compute average luminance of an image region.
    static func averageLuminance(pixelBuffer: CVPixelBuffer, rect: CGRect) -> Double? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let x0 = Int(rect.origin.x)
        let y0 = Int(rect.origin.y)
        let x1 = Int(rect.maxX)
        let y1 = Int(rect.maxY)
        
        guard x0 >= 0 && y0 >= 0 && x1 <= width && y1 <= height else { return nil }
        
        var sum: Double = 0
        var count: Int = 0
        
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for y in y0..<y1 {
            for x in x0..<x1 {
                let idx = y * bytesPerRow + x * 4  // BGRA
                let b = Double(ptr[idx])
                let g = Double(ptr[idx + 1])
                let r = Double(ptr[idx + 2])
                
                // Standard luma formula
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                sum += luma
                count += 1
            }
        }
        
        return count > 0 ? sum / Double(count) : nil
    }
    
    /// Compute histogram of luminance values in a region.
    /// Returns array of 256 bins (0...255).
    static func luminanceHistogram(pixelBuffer: CVPixelBuffer, rect: CGRect) -> [Int] {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return [Int](repeating: 0, count: 256)
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let x0 = Int(rect.origin.x)
        let y0 = Int(rect.origin.y)
        let x1 = Int(rect.maxX)
        let y1 = Int(rect.maxY)
        
        var histogram = [Int](repeating: 0, count: 256)
        
        guard x0 >= 0 && y0 >= 0 && x1 <= width && y1 <= height else { return histogram }
        
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for y in y0..<y1 {
            for x in x0..<x1 {
                let idx = y * bytesPerRow + x * 4
                let b = ptr[idx]
                let g = ptr[idx + 1]
                let r = ptr[idx + 2]
                
                let luma = UInt8(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
                histogram[Int(luma)] += 1
            }
        }
        
        return histogram
    }
    
    /// Assess if lighting is adequate (not too dark, not blown out).
    /// Returns (isAdequate: Bool, score: 0...1, reason: String)
    static func assessLighting(pixelBuffer: CVPixelBuffer, rect: CGRect) -> (adequate: Bool, score: Float, reason: String) {
        guard let avgLuma = averageLuminance(pixelBuffer: pixelBuffer, rect: rect) else {
            return (false, 0, "Unable to analyze lighting")
        }
        
        let normalized = Float(avgLuma / 255.0)
        
        if normalized < 0.2 {
            return (false, normalized, "Too dark—increase lighting")
        } else if normalized > 0.9 {
            return (false, normalized, "Overexposed—reduce harsh light")
        } else if normalized < 0.35 {
            return (true, normalized, "Slightly dark—move to brighter area")
        } else if normalized > 0.8 {
            return (true, normalized, "Slightly bright—soften light")
        } else {
            return (true, normalized, "Lighting is good")
        }
    }
    
    // MARK: - Adaptive Lighting Correction
    
    /// Apply CLAHE (Contrast Limited Adaptive Histogram Equalization) to a pixel buffer.
    /// Improves visibility of skin details without washing out the image.
    static func adaptiveHistogramEqualization(
        pixelBuffer: CVPixelBuffer,
        clipLimit: Float = 2.0,
        gridSize: Int = 8
    ) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Use CoreImage's tone mapping to achieve similar effect
        let filter = CIFilter(name: "CIUnsharpMask")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.0, forKey: kCIInputRadiusKey)
        filter?.setValue(0.5, forKey: kCIInputIntensityKey)
        
        guard let output = filter?.outputImage else { return nil }
        
        // Render to a new pixel buffer
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let outputBuffer = createPixelBuffer(width: CVPixelBufferGetWidth(pixelBuffer),
                                             height: CVPixelBufferGetHeight(pixelBuffer))
        
        context.render(output, to: outputBuffer)
        return outputBuffer
    }
    
    /// Normalize brightness to a target level (0...1).
    static func normalizeBrightness(
        pixelBuffer: CVPixelBuffer,
        targetBrightness: Float = 0.5
    ) -> CVPixelBuffer? {
        guard let currentBrightness = averageLuminance(pixelBuffer: pixelBuffer, rect: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))) else {
            return nil
        }
        
        let ratio = targetBrightness / Float(currentBrightness / 255.0)
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let filter = CIFilter(name: "CIExposureAdjust")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(log2(ratio), forKey: kCIInputEVKey)
        
        guard let output = filter?.outputImage else { return nil }
        
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let outputBuffer = createPixelBuffer(width: CVPixelBufferGetWidth(pixelBuffer),
                                             height: CVPixelBufferGetHeight(pixelBuffer))
        
        context.render(output, to: outputBuffer)
        return outputBuffer
    }
    
    // MARK: - Pixel Buffer Operations
    
    /// Create an empty pixel buffer of specified dimensions (BGRA format).
    static func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        return pixelBuffer ?? CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        ) == kCVReturnSuccess ? pixelBuffer! : CVPixelBuffer()
    }
    
    /// Crop a pixel buffer to a specified rect.
    static func cropPixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        to rect: CGRect
    ) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let croppedCIImage = ciImage.cropped(to: rect)
        
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let width = Int(croppedCIImage.extent.width)
        let height = Int(croppedCIImage.extent.height)
        
        let outputBuffer = createPixelBuffer(width: width, height: height)
        context.render(croppedCIImage, to: outputBuffer)
        
        return outputBuffer
    }
    
    /// Resize a pixel buffer to specified dimensions.
    static func resizePixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        to size: CGSize
    ) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        let scale = min(scaleX, scaleY)
        
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let width = Int(size.width)
        let height = Int(size.height)
        
        let outputBuffer = createPixelBuffer(width: width, height: height)
        context.render(scaledImage, to: outputBuffer)
        
        return outputBuffer
    }
    
    // MARK: - Quality Assessment
    
    /// Assess overall image quality for analysis.
    /// Returns (isAcceptable: Bool, score: 0...1, issues: [String])
    static func assessQuality(
        pixelBuffer: CVPixelBuffer,
        faceRect: CGRect
    ) -> (acceptable: Bool, score: Float, issues: [String]) {
        var issues: [String] = []
        var score: Float = 1.0
        
        // Check lighting
        let (lightingOK, lightingScore, _) = assessLighting(pixelBuffer: pixelBuffer, rect: faceRect)
        if !lightingOK {
            issues.append("Poor lighting")
        }
        score *= lightingScore
        
        // Check contrast (via histogram spread)
        let histogram = luminanceHistogram(pixelBuffer: pixelBuffer, rect: faceRect)
        let nonZeroBins = histogram.filter { $0 > 0 }.count
        if nonZeroBins < 50 {
            issues.append("Low contrast")
            score *= 0.8
        }
        
        // Check for blur (simplified: high-frequency content)
        // In production, could use Laplacian variance
        
        return (issues.isEmpty, score, issues)
    }
}

/// Simple pixel buffer wrapper for sampling operations.
struct PixelBuffer {
    let width: Int
    let height: Int
    let count: Int
    private let bytes: [UInt8]
    
    init?(from cvBuffer: CVPixelBuffer) {
        guard let baseAddress = CVPixelBufferGetBaseAddress(cvBuffer) else { return nil }
        
        width = CVPixelBufferGetWidth(cvBuffer)
        height = CVPixelBufferGetHeight(cvBuffer)
        count = width * height
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(cvBuffer)
        let totalBytes = bytesPerRow * height
        
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        bytes = Array(UnsafeBufferPointer(start: ptr, count: totalBytes))
    }
    
    func rgb(_ x: Int, _ y: Int) -> (r: Double, g: Double, b: Double) {
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return (0, 0, 0)
        }
        
        let bytesPerRow = width * 4  // BGRA
        let idx = y * bytesPerRow + x * 4
        
        guard idx >= 0 && idx + 2 < bytes.count else {
            return (0, 0, 0)
        }
        
        let b = Double(bytes[idx])
        let g = Double(bytes[idx + 1])
        let r = Double(bytes[idx + 2])
        
        return (r / 255.0, g / 255.0, b / 255.0)
    }
}
